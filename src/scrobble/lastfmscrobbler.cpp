/*
 * Adapted from Strawberry Music Player
 * Copyright 2018-2025, Jonas Kvinge <jonas@jkvinge.net>
 * Original source: https://github.com/strawberrymusicplayer/strawberry
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#include "lastfmscrobbler.h"

#include <algorithm>
#include <memory>

#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QCryptographicHash>
#include <QDateTime>
#include <QSettings>
#include <QDesktopServices>
#include <QTcpServer>
#include <QTcpSocket>
#include <QDebug>

// ---------------------------------------------------------------------------
// Embedded local redirect server — listens on an ephemeral port, reads the
// first HTTP request (the browser redirect from Last.fm), and emits finished().
// ---------------------------------------------------------------------------
class LastFmScrobbler::LocalServer : public QObject {
    Q_OBJECT
public:
    explicit LocalServer(QObject *parent = nullptr) : QObject(parent) {
        server_ = new QTcpServer(this);
        connect(server_, &QTcpServer::newConnection, this, &LocalServer::onNewConnection);
    }

    bool listen() {
        return server_->listen(QHostAddress::LocalHost, 0);  // port 0 → OS picks one
    }

    quint16 port() const { return server_->serverPort(); }

    QString error() const { return server_->errorString(); }

    QUrl redirectUrl() const {
        return QUrl(QStringLiteral("http://localhost:%1/callback").arg(port()));
    }

    QUrlQuery receivedQuery() const { return receivedQuery_; }

signals:
    void finished();

private slots:
    void onNewConnection() {
        QTcpSocket *socket = server_->nextPendingConnection();
        connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
            const QByteArray data = socket->readAll();
            // Parse the GET request line: "GET /callback?token=xxx HTTP/1.1"
            const QByteArray firstLine = data.left(data.indexOf('\n'));
            const int pathStart = firstLine.indexOf(' ') + 1;
            const int pathEnd   = firstLine.indexOf(' ', pathStart);
            const QByteArray path = firstLine.mid(pathStart, pathEnd - pathStart);

            const QUrl url = QUrl(QLatin1String("http://localhost") + QString::fromLatin1(path));
            receivedQuery_ = QUrlQuery(url);

            // Send a minimal HTTP 200 so the browser shows something.
            const QByteArray response =
                "HTTP/1.1 200 OK\r\n"
                "Content-Type: text/html\r\n"
                "Connection: close\r\n\r\n"
                "<html><body><h2>Authenticated! You can close this tab.</h2></body></html>";
            socket->write(response);
            socket->flush();
            socket->disconnectFromHost();
            server_->close();
            emit finished();
        });
    }

private:
    QTcpServer *server_;
    QUrlQuery   receivedQuery_;
};

// We need the LocalServer moc inside this TU since it's a private class.
#include "lastfmscrobbler.moc"

// ---------------------------------------------------------------------------
// Construction / destruction
// ---------------------------------------------------------------------------

LastFmScrobbler::LastFmScrobbler(const QString &apiKey,
                                 const QString &apiSecret,
                                 QObject *parent)
    : QObject(parent)
    , network_(new QNetworkAccessManager(this))
    , cache_(new ScrobblerCache(QLatin1String(kCacheFile), this))
    , apiKey_(apiKey)
    , apiSecret_(apiSecret)
    , scrobbleTimer_(new QTimer(this))
    , submitTimer_(new QTimer(this))
{
    scrobbleTimer_->setSingleShot(true);
    connect(scrobbleTimer_, &QTimer::timeout, this, &LastFmScrobbler::scrobbleCurrentSong);

    submitTimer_->setSingleShot(true);
    connect(submitTimer_, &QTimer::timeout, this, &LastFmScrobbler::submitCache);

    loadSession();

    // Submit any scrobbles left over from a previous session.
    if (isAuthenticated() && cache_->Count() > 0)
        startSubmit(true);
}

LastFmScrobbler::~LastFmScrobbler()
{
    notifyStopped();

    // Cancel open network calls to avoid use-after-free.
    for (QNetworkReply *r : std::as_const(pendingReplies_)) {
        r->abort();
        r->deleteLater();
    }

    if (localServer_) {
        localServer_->deleteLater();
        localServer_ = nullptr;
    }
}

// ---------------------------------------------------------------------------
// Session persistence
// ---------------------------------------------------------------------------

void LastFmScrobbler::loadSession()
{
    QSettings s("Meloville", "Meloville");
    s.beginGroup(QStringLiteral("LastFm"));
    username_   = s.value(QStringLiteral("username")).toString();
    sessionKey_ = s.value(QStringLiteral("session_key")).toString();
    s.endGroup();
}

void LastFmScrobbler::saveSession()
{
    QSettings s("Meloville", "Meloville");
    s.beginGroup(QStringLiteral("LastFm"));
    s.setValue(QStringLiteral("username"),    username_);
    s.setValue(QStringLiteral("session_key"), sessionKey_);
    s.endGroup();
}

void LastFmScrobbler::logout()
{
    username_.clear();
    sessionKey_.clear();

    QSettings s("Meloville", "Meloville");
    s.beginGroup(QStringLiteral("LastFm"));
    s.remove(QString());  // removes all keys in this group
    s.endGroup();
}

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------

void LastFmScrobbler::authenticate()
{
    if (localServer_) return;  // auth already in progress

    localServer_ = new LocalServer(this);
    if (!localServer_->listen()) {
        emitError(QStringLiteral("Could not start local redirect server: ") + localServer_->error());
        delete localServer_;
        localServer_ = nullptr;
        return;
    }

    connect(localServer_, &LocalServer::finished, this, &LastFmScrobbler::onRedirectArrived);

    QUrlQuery q;
    q.addQueryItem(QStringLiteral("api_key"), apiKey_);
    q.addQueryItem(QStringLiteral("cb"), localServer_->redirectUrl().toString());

    QUrl authUrl = QUrl(QLatin1String(kAuthUrl));
    authUrl.setQuery(q);

    QDesktopServices::openUrl(authUrl);
    qDebug() << "LastFmScrobbler: opened auth URL:" << authUrl.toString();
}

void LastFmScrobbler::onRedirectArrived()
{
    if (!localServer_) return;

    const QUrlQuery query = localServer_->receivedQuery();
    localServer_->deleteLater();
    localServer_ = nullptr;

    if (!query.hasQueryItem(QStringLiteral("token"))) {
        emit authenticationComplete(false, QStringLiteral("No token in redirect URL"));
        return;
    }

    requestSession(query.queryItemValue(QStringLiteral("token")));
}

void LastFmScrobbler::requestSession(const QString &token)
{
    ParamList params = {
        { QStringLiteral("api_key"), apiKey_ },
        { QStringLiteral("method"),  QStringLiteral("auth.getSession") },
        { QStringLiteral("token"),   token },
    };
    // Signature is appended inside getRequest
    std::sort(params.begin(), params.end());

    QUrlQuery urlQuery;
    for (const Param &p : params)
        urlQuery.addQueryItem(p.first, p.second);

    const QString sig = buildSignature(params);
    urlQuery.addQueryItem(QStringLiteral("api_sig"), sig);
    urlQuery.addQueryItem(QStringLiteral("format"),  QStringLiteral("json"));

    QUrl url{QLatin1String(kApiUrl)};
    url.setQuery(urlQuery);

    QNetworkReply *reply = getRequest(url);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onSessionReplyFinished(reply);
    });
}

void LastFmScrobbler::onSessionReplyFinished(QNetworkReply *reply)
{
    pendingReplies_.removeAll(reply);
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        emit authenticationComplete(false, reply->errorString());
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (!doc.isObject()) {
        emit authenticationComplete(false, QStringLiteral("Invalid JSON response"));
        return;
    }
    const QJsonObject root = doc.object();
    if (root.contains(QLatin1String("error"))) {
        const QString msg = root[QLatin1String("message")].toString();
        emit authenticationComplete(false, msg);
        return;
    }
    const QJsonObject session = root[QLatin1String("session")].toObject();
    username_   = session[QLatin1String("name")].toString();
    sessionKey_ = session[QLatin1String("key")].toString();

    if (username_.isEmpty() || sessionKey_.isEmpty()) {
        emit authenticationComplete(false, QStringLiteral("Session missing name or key"));
        return;
    }

    saveSession();
    emit authenticationComplete(true);

    // Submit any queued scrobbles now that we have a session.
    startSubmit(/*initial=*/true);
}

// ---------------------------------------------------------------------------
// Playback events
// ---------------------------------------------------------------------------

void LastFmScrobbler::notifySongStarted(const QString &title,
                                        const QString &artist,
                                        const QString &album,
                                        int durationSeconds)
{
    // If a previous song never reached the threshold, check if enough time
    // has elapsed since it started to still count as a scrobble.
    notifyStopped();

    currentTitle_        = title;
    currentArtist_       = artist;
    currentAlbum_        = album;
    currentDurationSec_  = durationSeconds;
    playStartTimestamp_  = QDateTime::currentSecsSinceEpoch();
    scrobbled_           = false;

    if (!isAuthenticated()) return;

    updateNowPlaying();
    scheduleScrobble();
}

void LastFmScrobbler::notifyStopped()
{
    scrobbleTimer_->stop();

    // Last.fm rule: scrobble if played > 30 s AND (> 50% OR > 4 min).
    // The timer already handles the threshold case; this catches the case
    // where the user skips before the timer fires but after 30 s.
    if (!scrobbled_ && !currentTitle_.isEmpty() && !currentArtist_.isEmpty()) {
        const qint64 elapsed = QDateTime::currentSecsSinceEpoch() - playStartTimestamp_;
        const qint64 threshold = std::min<qint64>(currentDurationSec_ / 2, 4 * 60);
        if (elapsed >= threshold && elapsed > 30)
            scrobbleCurrentSong();
    }

    currentTitle_.clear();
    currentArtist_.clear();
    currentAlbum_.clear();
    currentDurationSec_ = 0;
    playStartTimestamp_ = 0;
}

// ---------------------------------------------------------------------------
// Now Playing
// ---------------------------------------------------------------------------

void LastFmScrobbler::updateNowPlaying()
{
    if (!isAuthenticated() || currentTitle_.isEmpty()) return;

    ParamList params = {
        { QStringLiteral("method"), QStringLiteral("track.updateNowPlaying") },
        { QStringLiteral("artist"), currentArtist_ },
        { QStringLiteral("track"),  currentTitle_ },
    };
    if (!currentAlbum_.isEmpty())
        params.append({ QStringLiteral("album"), currentAlbum_ });
    if (currentDurationSec_ > 0)
        params.append({ QStringLiteral("duration"), QString::number(currentDurationSec_) });

    QNetworkReply *reply = postRequest(params);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onNowPlayingReplyFinished(reply);
    });
}

void LastFmScrobbler::onNowPlayingReplyFinished(QNetworkReply *reply)
{
    pendingReplies_.removeAll(reply);
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "LastFmScrobbler: now-playing update failed:" << reply->errorString();
        // Not fatal — now-playing is best-effort.
    }
}

// ---------------------------------------------------------------------------
// Scrobble threshold timer
// ---------------------------------------------------------------------------

void LastFmScrobbler::scheduleScrobble()
{
    if (currentDurationSec_ <= 0) return;

    // Last.fm rule: scrobble after 50% of track length OR 4 minutes, whichever comes first,
    // but not before 30 seconds.
    const int thresholdSec = std::min(currentDurationSec_ / 2, 4 * 60);
    if (thresholdSec < 30) return;  // track too short to scrobble

    scrobbleTimer_->setInterval(thresholdSec * 1000);
    scrobbleTimer_->start();
}

void LastFmScrobbler::scrobbleCurrentSong()
{
    if (scrobbled_ || currentTitle_.isEmpty() || currentArtist_.isEmpty()) return;
    scrobbled_ = true;

    ScrobbleMetadata meta;
    meta.title       = currentTitle_;
    meta.artist      = currentArtist_;
    meta.album       = currentAlbum_;
    meta.length_nsec = static_cast<qint64>(currentDurationSec_) * 1'000'000'000LL;

    cache_->Add(meta, static_cast<quint64>(playStartTimestamp_));

    if (!isAuthenticated()) return;

    startSubmit(/*initial=*/true);
}

// ---------------------------------------------------------------------------
// Submit (batch-send cache to Last.fm)
// ---------------------------------------------------------------------------

void LastFmScrobbler::startSubmit(bool initial)
{
    if (submitPending_ || cache_->Count() == 0) return;

    if (initial && !submitError_) {
        if (submitTimer_->isActive()) submitTimer_->stop();
        submitCache();
    } else if (!submitTimer_->isActive()) {
        // Back-off: 30 s on error, 5 s otherwise.
        submitTimer_->setInterval((submitError_ ? 30 : 5) * 1000);
        submitTimer_->start();
    }
}

void LastFmScrobbler::submitCache()
{
    if (!isAuthenticated() || cache_->Count() == 0) return;

    qDebug() << "LastFmScrobbler: submitting" << cache_->Count() << "scrobble(s)";

    ParamList params = {{ QStringLiteral("method"), QStringLiteral("track.scrobble") }};

    int i = 0;
    ScrobblerCacheItemPtrList toSend;
    for (const ScrobblerCacheItemPtr &item : cache_->List()) {
        if (item->sent) continue;
        item->sent = true;
        toSend << item;

        const QString idx = QString::number(i);
        params.append({ QStringLiteral("artist[%1]").arg(idx),    item->metadata.artist });
        params.append({ QStringLiteral("track[%1]").arg(idx),     item->metadata.title });
        params.append({ QStringLiteral("timestamp[%1]").arg(idx), QString::number(item->timestamp) });
        params.append({ QStringLiteral("duration[%1]").arg(idx),
                        QString::number(item->metadata.length_nsec / 1'000'000'000LL) });
        if (!item->metadata.album.isEmpty())
            params.append({ QStringLiteral("album[%1]").arg(idx), item->metadata.album });

        ++i;
        if (toSend.count() >= kScrobblesPerRequest) break;
    }

    if (toSend.isEmpty()) return;

    submitPending_ = true;

    QNetworkReply *reply = postRequest(params);
    connect(reply, &QNetworkReply::finished, this, [this, reply, toSend]() {
        onScrobbleReplyFinished(reply, toSend);
    });
}

void LastFmScrobbler::onScrobbleReplyFinished(QNetworkReply *reply,
                                              ScrobblerCacheItemPtrList sent)
{
    pendingReplies_.removeAll(reply);
    reply->deleteLater();
    submitPending_ = false;

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "LastFmScrobbler: scrobble POST failed:" << reply->errorString();
        cache_->ClearSent(sent);
        submitError_ = true;
        startSubmit();
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (!doc.isObject()) {
        cache_->ClearSent(sent);
        submitError_ = true;
        startSubmit();
        return;
    }
    const QJsonObject root = doc.object();
    if (root.contains(QLatin1String("error"))) {
        const QString msg = root[QLatin1String("message")].toString();
        emitError(QStringLiteral("Scrobble error: ") + msg);
        cache_->ClearSent(sent);
        submitError_ = true;
        startSubmit();
        return;
    }

    // Success — remove submitted items from cache.
    cache_->Flush(sent);
    submitError_ = false;

    // Log accepted / ignored counts if available.
    const QJsonObject scrobbles = root[QLatin1String("scrobbles")].toObject();
    const QJsonObject attr      = scrobbles[QLatin1String("@attr")].toObject();
    if (!attr.isEmpty()) {
        qDebug() << "LastFmScrobbler: accepted" << attr[QLatin1String("accepted")].toInt()
                 << "ignored" << attr[QLatin1String("ignored")].toInt();
    }

    // Submit again if more items accumulated while this batch was in-flight.
    startSubmit();
}

// ---------------------------------------------------------------------------
// Love
// ---------------------------------------------------------------------------

void LastFmScrobbler::love()
{
    if (!isAuthenticated() || currentTitle_.isEmpty() || currentArtist_.isEmpty()) return;

    qDebug() << "LastFmScrobbler: loving" << currentArtist_ << "-" << currentTitle_;

    const ParamList params = {
        { QStringLiteral("method"), QStringLiteral("track.love") },
        { QStringLiteral("artist"), currentArtist_ },
        { QStringLiteral("track"),  currentTitle_ },
    };

    QNetworkReply *reply = postRequest(params);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onLoveReplyFinished(reply);
    });
}

void LastFmScrobbler::onLoveReplyFinished(QNetworkReply *reply)
{
    pendingReplies_.removeAll(reply);
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError)
        emitError(QStringLiteral("Love failed: ") + reply->errorString());
}

// ---------------------------------------------------------------------------
// Networking helpers
// ---------------------------------------------------------------------------

QByteArray LastFmScrobbler::md5(const QString &data)
{
    return QCryptographicHash::hash(data.toUtf8(), QCryptographicHash::Md5).toHex();
}

QString LastFmScrobbler::buildSignature(const ParamList &params) const
{
    // Last.fm signature: alphabetically sorted key+value pairs, then append secret, then MD5.
    ParamList sorted = params;
    // Remove format/callback params — they must not be part of the signature.
    sorted.erase(std::remove_if(sorted.begin(), sorted.end(), [](const Param &p) {
        return p.first == QLatin1String("format") || p.first == QLatin1String("callback");
    }), sorted.end());
    std::sort(sorted.begin(), sorted.end());

    QString toSign;
    for (const Param &p : std::as_const(sorted))
        toSign += p.first + p.second;
    toSign += apiSecret_;

    return QString::fromLatin1(md5(toSign));
}

QNetworkReply *LastFmScrobbler::postRequest(const ParamList &extraParams)
{
    ParamList params = extraParams;
    params.append({ QStringLiteral("api_key"), apiKey_ });
    params.append({ QStringLiteral("sk"),      sessionKey_ });

    // Signature must be computed before adding "format".
    std::sort(params.begin(), params.end());
    params.append({ QStringLiteral("api_sig"), buildSignature(params) });
    params.append({ QStringLiteral("format"),  QStringLiteral("json") });

    QUrlQuery body;
    for (const Param &p : std::as_const(params))
        body.addQueryItem(p.first, p.second);

    QNetworkRequest req{QUrl(QLatin1String(kApiUrl))};
    req.setHeader(QNetworkRequest::ContentTypeHeader,
                  QStringLiteral("application/x-www-form-urlencoded"));

    QNetworkReply *reply = network_->post(req, body.toString(QUrl::FullyEncoded).toUtf8());
    pendingReplies_.append(reply);
    return reply;
}

QNetworkReply *LastFmScrobbler::getRequest(const QUrl &url)
{
    QNetworkRequest req(url);
    QNetworkReply *reply = network_->get(req);
    pendingReplies_.append(reply);
    return reply;
}

void LastFmScrobbler::emitError(const QString &msg)
{
    qWarning() << "LastFmScrobbler:" << msg;
    emit errorOccurred(msg);
}
