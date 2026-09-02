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
#include "listenbrainzscrobbler.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonValue>
#include <QNetworkRequest>
#include <QSettings>
#include <QUrl>
#include <QDebug>
#include <chrono>

using namespace std::chrono_literals;

static constexpr char kApiBase[] = "https://api.listenbrainz.org";
static constexpr char kCacheFile[] = "listenbrainzscrobbler.cache";
static constexpr char kSettingsGroup[] = "ListenBrainz";

ListenBrainzScrobbler::ListenBrainzScrobbler(QObject *parent)
    : QObject(parent)
    , nam_(new QNetworkAccessManager(this))
    , cache_(new ScrobblerCache(QLatin1String(kCacheFile), this))
    , submitTimer_(new QTimer(this))
    , scrobbleTimer_(new QTimer(this))
{
    submitTimer_->setSingleShot(true);
    submitTimer_->setInterval(5000);  // 5 s delay before batch-submitting
    connect(submitTimer_, &QTimer::timeout, this, &ListenBrainzScrobbler::submitScrobbles);

    scrobbleTimer_->setSingleShot(true);
    connect(scrobbleTimer_, &QTimer::timeout, this, &ListenBrainzScrobbler::notifySongScrobble);

    loadSettings();

    if (!token_.isEmpty())
        validateToken();
}

ListenBrainzScrobbler::~ListenBrainzScrobbler() = default;

void ListenBrainzScrobbler::loadSettings()
{
    QSettings s("Meloville", "Meloville");
    s.beginGroup(QLatin1String(kSettingsGroup));
    token_ = s.value(QStringLiteral("userToken")).toString();
    username_ = s.value(QStringLiteral("username")).toString();
    s.endGroup();
    authenticated_ = !token_.isEmpty() && !username_.isEmpty();
}

void ListenBrainzScrobbler::saveSettings()
{
    QSettings s("Meloville", "Meloville");
    s.beginGroup(QLatin1String(kSettingsGroup));
    s.setValue(QStringLiteral("userToken"), token_);
    s.setValue(QStringLiteral("username"),  username_);
    s.endGroup();
}

bool ListenBrainzScrobbler::isAuthenticated() const
{
    return authenticated_;
}

void ListenBrainzScrobbler::setToken(const QString &token)
{
    token_ = token.trimmed();
    username_ = QString();
    authenticated_ = false;
    saveSettings();

    if (!token_.isEmpty())
        validateToken();
    else
        emit authChanged();
}

void ListenBrainzScrobbler::logout()
{
    token_ = QString();
    username_ = QString();
    authenticated_ = false;
    saveSettings();
    emit authChanged();
}

void ListenBrainzScrobbler::notifySongStarted(const QString &title,
                                               const QString &artist,
                                               const QString &album,
                                               int durationSec)
{
    scrobbleTimer_->stop();

    currentTitle_ = title;
    currentArtist_ = artist;
    currentAlbum_ = album;
    currentDurationNsec_ = static_cast<qint64>(durationSec) * 1'000'000'000LL;
    currentTimestamp_ = static_cast<quint64>(QDateTime::currentSecsSinceEpoch());
    scrobbled_ = false;

    if (durationSec > 0) {
        const int thresholdSec = qMin(durationSec / 2, 4 * 60);
        if (thresholdSec >= 30) {
            scrobbleTimer_->setInterval(thresholdSec * 1000);
            scrobbleTimer_->start();
        }
    }

    if (isAuthenticated())
        submitNowPlaying();
}

void ListenBrainzScrobbler::notifySongStopped()
{
    scrobbleTimer_->stop();

    currentTitle_.clear();
    currentArtist_.clear();
    currentAlbum_.clear();
    currentDurationNsec_ = 0;
    currentTimestamp_ = 0;
    scrobbled_ = false;
}

void ListenBrainzScrobbler::notifySongScrobble()
{
    if (scrobbled_ || currentTitle_.isEmpty() || currentArtist_.isEmpty())
        return;

    scrobbled_ = true;

    ScrobbleMetadata meta;
    meta.title = currentTitle_;
    meta.artist = currentArtist_;
    meta.album = currentAlbum_;
    meta.length_nsec = currentDurationNsec_;

    cache_->Add(meta, currentTimestamp_);

    if (isAuthenticated() && !submitTimer_->isActive())
        submitTimer_->start();
}

void ListenBrainzScrobbler::notifySongPaused()
{
    if (paused_ || currentTitle_.isEmpty()) return;
    paused_ = true;
    scrobbleTimerRemainingMs_ = scrobbleTimer_->isActive()
                                ? scrobbleTimer_->remainingTime()
                                : 0;
    scrobbleTimer_->stop();
}

void ListenBrainzScrobbler::notifySongResumed()
{
    if (!paused_ || currentTitle_.isEmpty()) return;
    paused_ = false;
    if (!scrobbled_ && scrobbleTimerRemainingMs_ > 0) {
        scrobbleTimer_->setInterval(scrobbleTimerRemainingMs_);
        scrobbleTimer_->start();
        scrobbleTimerRemainingMs_ = 0;
    }
}

// ── Network helpers ───────────────────────────────────────────────────────

QNetworkReply *ListenBrainzScrobbler::post(const QString &endpoint,
                                            const QJsonDocument &doc)
{
    QNetworkRequest req(QUrl(QStringLiteral("%1%2").arg(QLatin1String(kApiBase), endpoint)));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Authorization", QByteArray("Token ") + token_.toUtf8());
    return nam_->post(req, doc.toJson(QJsonDocument::Compact));
}

QJsonObject ListenBrainzScrobbler::trackMetadata(const QString &title,
                                                   const QString &artist,
                                                   const QString &album,
                                                   qint64 durationNsec) const
{
    QJsonObject meta;
    meta.insert(QStringLiteral("artist_name"), artist);
    meta.insert(QStringLiteral("track_name"),  title);
    if (!album.isEmpty())
        meta.insert(QStringLiteral("release_name"), album);

    if (durationNsec > 0) {
        QJsonObject info;
        info.insert(QStringLiteral("duration_ms"), durationNsec / 1'000'000LL);
        meta.insert(QStringLiteral("additional_info"), info);
    }

    return meta;
}

// ── Token validation ──────────────────────────────────────────────────────

void ListenBrainzScrobbler::validateToken()
{
    QNetworkRequest req(QUrl(QStringLiteral("%1/1/validate-token").arg(QLatin1String(kApiBase))));
    req.setRawHeader("Authorization", QByteArray("Token ") + token_.toUtf8());
    QNetworkReply *reply = nam_->get(req);
    connect(reply, &QNetworkReply::finished,
            this, [this, reply]() { onValidateFinished(reply); });
}

void ListenBrainzScrobbler::onValidateFinished(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "ListenBrainz: token validation network error:" << reply->errorString();
        authenticated_ = false;
        emit authChanged();
        return;
    }

    const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
    const bool valid = obj.value(QStringLiteral("valid")).toBool(false);
    username_ = obj.value(QStringLiteral("user_name")).toString();

    authenticated_ = valid && !username_.isEmpty();
    if (!authenticated_)
        username_.clear();

    saveSettings();
    emit authChanged();

    if (authenticated_ && cache_->Count() > 0 && !submitTimer_->isActive())
        submitTimer_->start();
}

void ListenBrainzScrobbler::submitNowPlaying()
{
    QJsonObject listen;
    listen.insert(QStringLiteral("track_metadata"),
                  trackMetadata(currentTitle_, currentArtist_,
                                currentAlbum_, currentDurationNsec_));

    QJsonObject root;
    root.insert(QStringLiteral("listen_type"), QStringLiteral("playing_now"));
    root.insert(QStringLiteral("payload"), QJsonArray{ listen });

    QNetworkReply *reply = post(QStringLiteral("/1/submit-listens"), QJsonDocument(root));
    connect(reply, &QNetworkReply::finished,
            this, [this, reply]() { onNowPlayingFinished(reply); });
}

void ListenBrainzScrobbler::onNowPlayingFinished(QNetworkReply *reply)
{
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError)
        qWarning() << "ListenBrainz: now-playing error:" << reply->errorString();
}

void ListenBrainzScrobbler::submitScrobbles()
{
    if (!isAuthenticated()) return;

    constexpr int kMaxPerRequest = 10;

    const ScrobblerCacheItemPtrList all = cache_->List();
    ScrobblerCacheItemPtrList batch;
    QJsonArray payload;

    for (const ScrobblerCacheItemPtr &item : all) {
        if (item->sent) continue;
        item->sent = true;
        batch << item;

        QJsonObject listen;
        listen.insert(QStringLiteral("listened_at"), QJsonValue::fromVariant(item->timestamp));

        listen.insert(QStringLiteral("track_metadata"),
                      trackMetadata(item->metadata.title,
                                    item->metadata.artist,
                                    item->metadata.album,
                                    item->metadata.length_nsec));
        payload.append(listen);

        if (batch.size() >= kMaxPerRequest) break;
    }

    if (batch.isEmpty()) return;

    QJsonObject root;
    root.insert(QStringLiteral("listen_type"), QStringLiteral("import"));
    root.insert(QStringLiteral("payload"), payload);

    QNetworkReply *reply = post(QStringLiteral("/1/submit-listens"), QJsonDocument(root));
    connect(reply, &QNetworkReply::finished,
            this, [this, reply, batch]() { onScrobbleFinished(reply, batch); });
}

void ListenBrainzScrobbler::onScrobbleFinished(QNetworkReply *reply,
                                                ScrobblerCacheItemPtrList items)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "ListenBrainz: scrobble error:" << reply->errorString();
        cache_->ClearSent(items);    // will retry next time
        emit errorOccurred(reply->errorString());
        return;
    }

    const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
    const QString status = obj.value(QStringLiteral("status")).toString();
    if (status.compare(QStringLiteral("ok"), Qt::CaseInsensitive) == 0) {
        cache_->Flush(items);
        // Submit remaining items if cache still has entries
        if (cache_->Count() > 0 && !submitTimer_->isActive())
            submitTimer_->start();
    } else {
        cache_->ClearSent(items);
        const QString msg = QStringLiteral("ListenBrainz scrobble failed: %1").arg(status);
        qWarning() << msg;
        emit errorOccurred(msg);
    }
}