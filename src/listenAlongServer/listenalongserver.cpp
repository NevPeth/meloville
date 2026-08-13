#include "listenalongserver.h"

#include <QRandomGenerator>
#include <QNetworkInterface>
#include <QHostAddress>
#include <QJsonObject>
#include <QJsonDocument>
#include <QFileInfo>
#include <QAbstractSocket>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

ListenAlongServer::ListenAlongServer(QObject *parent)
    : QObject(parent)
    , m_server(new QTcpServer(this))
    , m_pumpTimer(new QTimer(this))
{
    connect(m_server, &QTcpServer::newConnection, this, &ListenAlongServer::handleNewConnection);

    m_pumpTimer->setInterval(20);
    connect(m_pumpTimer, &QTimer::timeout, this, &ListenAlongServer::pumpAudioData);
}

ListenAlongServer::~ListenAlongServer()
{
    stop();
}

bool ListenAlongServer::start(quint16 preferredPort)
{
    if (isRunning())
        stop();

    if (!m_server->listen(QHostAddress::Any, preferredPort)) {
        // Fall back to letting the OS pick any free port.
        if (!m_server->listen(QHostAddress::Any, 0))
            return false;
    }

    // Fresh, unguessable token every session: 16 random bytes -> 32 hex chars.
    QByteArray raw(16, Qt::Uninitialized);
    for (int i = 0; i < raw.size(); ++i)
        raw[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));
    m_token = QString::fromLatin1(raw.toHex());

    m_pumpTimer->start();

    emit sessionStarted(m_token, m_server->serverPort());

    QNetworkAccessManager *manager = new QNetworkAccessManager(this);

    connect(manager, &QNetworkAccessManager::finished,
        this,
        [this, manager](QNetworkReply *reply)
{
    m_publicIp = QString(reply->readAll()).trimmed();
    reply->deleteLater();
    manager->deleteLater();

    // Probe whether our port is actually reachable through the public IP.
    // We open a TCP connection to ourselves; if it connects, the port is
    // forwarded and the public URL is valid. Either way we emit the result.
    quint16 probePort = m_server->serverPort();
    QTcpSocket *probe = new QTcpSocket(this);

    // Give the probe 3 seconds — enough for a LAN hairpin, too short to
    // hang the UI if the router simply drops the SYN.
    QTimer *timeout = new QTimer(this);
    timeout->setSingleShot(true);
    timeout->setInterval(3000);

    auto cleanup = [probe, timeout]() {
        timeout->stop();
        timeout->deleteLater();
        probe->abort();
        probe->deleteLater();
    };

    connect(probe, &QTcpSocket::connected, this, [this, cleanup]() {
        m_publicIpReachable = true;
        cleanup();
        emit candidateUrlsReady(candidateUrls());
    });

    connect(probe, &QTcpSocket::errorOccurred, this, [this, cleanup](QAbstractSocket::SocketError) {
        m_publicIpReachable = false;
        cleanup();
        emit candidateUrlsReady(candidateUrls());
    });

    connect(timeout, &QTimer::timeout, this, [this, cleanup]() {
        m_publicIpReachable = false;  // Timed out = not reachable
        cleanup();
        emit candidateUrlsReady(candidateUrls());
    });

    timeout->start();
    probe->connectToHost(m_publicIp, probePort);
});

    manager->get(QNetworkRequest(QUrl("https://api.ipify.org")));
    emit candidateUrlsReady(candidateUrls());
    return true;
}

void ListenAlongServer::stop()
{
    if (!isRunning())
        return;

    m_pumpTimer->stop();

    QList<Client *> clients = m_clients;
    m_clients.clear();

    for (Client *client : std::as_const(clients)) {
        client->socket->disconnect(this);
        client->socket->disconnectFromHost();
        client->socket->deleteLater();
        delete client;
    }

    if (m_sourceFile.isOpen())
        m_sourceFile.close();

    m_currentFilePath.clear();
    m_currentMime.clear();
    m_bytesSentForCurrentSong = 0;
    m_isPaused = false;

    m_server->close();
    m_token.clear();

    emit sessionStopped();
}

bool ListenAlongServer::isRunning() const
{
    return m_server->isListening();
}

quint16 ListenAlongServer::port() const
{
    return m_server->serverPort();
}

QStringList ListenAlongServer::candidateUrls() const
{
    QStringList urls;
    if (!isRunning())
        return urls;

    // Only include the public URL if the port-forward probe succeeded.
    if (!m_publicIp.isEmpty() && m_publicIpReachable) {
        urls << QString("http://%1:%2/%3")
                    .arg(m_publicIp)
                    .arg(m_server->serverPort())
                    .arg(m_token);
    }

    // Local network addresses always included.
    const auto addresses = QNetworkInterface::allAddresses();
    for (const QHostAddress &addr : addresses) {
        if (addr.protocol() != QAbstractSocket::IPv4Protocol) continue;
        if (addr.isLoopback()) continue;
        urls << QString("http://%1:%2/%3")
                    .arg(addr.toString())
                    .arg(m_server->serverPort())
                    .arg(m_token);
    }

    return urls;
}

void ListenAlongServer::setNowPlaying(const QString &filePath, const QString &title,
                                       const QString &artist, qint64 durationS, QString coverPath)
{
    const QString newMime = mimeTypeForFile(filePath);

    if (m_sourceFile.isOpen())
        m_sourceFile.close();

    m_currentFilePath = filePath;
    m_currentCoverPath = coverPath;
    m_currentTitle = title;
    m_currentArtist = artist;
    m_currentDurationS = durationS > 0 ? durationS : 1;
    m_currentPositionMs = 0;
    m_bytesReadForCurrentSong = 0;
    m_audioBuffer.clear();
    m_currentMime = newMime;
    ++m_trackGeneration;   // <-- deterministic signal a new track is live

    m_sourceFile.setFileName(filePath);
    if (!m_sourceFile.open(QIODevice::ReadOnly)) {
        qWarning() << "ListenAlongServer: failed to open" << filePath
                   << m_sourceFile.errorString();
    }

    // Still tear down stale sockets so they don't keep writing the old
    // buffer to a client that's about to reconnect anyway -- cleanup, not
    // the switch-detection mechanism anymore.
    for (Client *client : std::as_const(m_clients)) {
        if (client->isStreaming) {
            client->socket->disconnectFromHost();
            client->isStreaming = false;
        }
        client->bytesSent = 0;
    }
}

void ListenAlongServer::syncPlaybackPosition(qint64 positionMs)
{
    m_currentPositionMs = positionMs;
}

void ListenAlongServer::setPaused(bool paused)
{
    if (m_isPaused == paused)
        return;

    m_isPaused = paused;

    if (m_isPaused) {
        // Kill every active stream immediately so the client's <audio>
        // element stops output right now instead of finishing whatever
        // audio it already has buffered.
        for (Client *client : std::as_const(m_clients)) {
            if (client->isStreaming) {
                client->socket->disconnectFromHost();
                client->isStreaming = false;
            }
        }
    }
}

void ListenAlongServer::handleNewConnection()
{
    while (m_server->hasPendingConnections()) {
        QTcpSocket *socket = m_server->nextPendingConnection();

        if (m_clients.size() >= maxClients) {
            // Refuse immediately rather than let connections pile up
            // unbounded -- protects file descriptors / socket exhaustion.
            socket->disconnectFromHost();
            socket->deleteLater();
            continue;
        }

        // Disable Nagle's algorithm: without this, small/frequent writes
        // from pumpAudioData can sit buffered by the OS waiting to coalesce,
        // silently adding tens to hundreds of ms of latency per hop.
        socket->setSocketOption(QAbstractSocket::LowDelayOption, 1);

        auto *client = new Client();
        client->socket = socket;
        m_clients.append(client);

        connect(socket, &QTcpSocket::readyRead, this, &ListenAlongServer::handleClientReadyRead);
        connect(socket, &QTcpSocket::disconnected, this, &ListenAlongServer::handleClientDisconnected);
    }
}

void ListenAlongServer::handleClientReadyRead()
{
    auto *socket = qobject_cast<QTcpSocket *>(sender());
    if (!socket)
        return;

    Client *client = clientFor(socket);
    if (!client || client->handledRequest)
        return;

    client->buffer.append(socket->readAll());

    int headerEnd = client->buffer.indexOf("\r\n\r\n");
    if (headerEnd < 0) {
        if (client->buffer.size() > 8192) {
            client->handledRequest = true;
            sendSimpleResponse(socket, 400, "Bad Request", "text/plain", "Request too large.");
        }
        return;
    }

    QByteArray headerBlock = client->buffer.left(headerEnd);
    int lineEnd = headerBlock.indexOf("\r\n");
    QByteArray requestLine = headerBlock.left(lineEnd);
    QList<QByteArray> parts = requestLine.split(' ');

    if (parts.size() < 2) {
        client->handledRequest = true;
        sendSimpleResponse(socket, 400, "Bad Request", "text/plain", "Malformed request.");
        return;
    }

    QString method = QString::fromLatin1(parts[0]);
    QString rawPath = QString::fromLatin1(parts[1]);
    QString path = rawPath.section('?', 0, 0);

    // Pull out "Range: bytes=N-" if present -- Chrome/Blink issues this
    // whenever a seek lands outside the currently buffered region, and
    // needs a real 206 response or it can't complete the seek.
    qint64 rangeStart = -1;
    const QList<QByteArray> headerLines = headerBlock.split('\n');
    for (const QByteArray &rawLine : headerLines) {
        QByteArray line = rawLine.trimmed();
        if (!line.toLower().startsWith("range:"))
            continue;
        int eq = line.indexOf('=');
        int dash = line.indexOf('-', eq);
        if (eq > 0 && dash > eq) {
            bool ok = false;
            qint64 val = line.mid(eq + 1, dash - eq - 1).trimmed().toLongLong(&ok);
            if (ok)
                rangeStart = val;
        }
    }

    client->handledRequest = true;
    handleRequest(client, method, path, rangeStart);
}

void ListenAlongServer::handleRequest(Client *client, const QString &method, const QString &path, qint64 rangeStart)
{
    QTcpSocket *socket = client->socket;

    if (method != "GET") {
        sendSimpleResponse(socket, 405, "Method Not Allowed", "text/plain", "Only GET is supported.");
        return;
    }

    QStringList segments = path.split('/', Qt::SkipEmptyParts);

    if (m_token.isEmpty() || segments.isEmpty() || segments[0] != m_token) {
        sendSimpleResponse(socket, 403, "Forbidden", "text/plain",
                            "Invalid or expired listen-along link.");
        return;
    }

    if (segments.size() == 1) {
        sendSimpleResponse(socket, 200, "OK", "text/html; charset=utf-8",
                            nowPlayingHtml().toUtf8());
        return;
    }

    if (segments.size() == 2 && segments[1] == "stream") {
        beginStreaming(client, rangeStart);
        return;
    }

    if (segments.size() == 2 && segments[1] == "nowplaying") {
        sendSimpleResponse(socket, 200, "OK", "application/json; charset=utf-8",
                            nowPlayingJson().toUtf8());
        return;
    }

    if (segments.size() == 2 && segments[1] == "cover") {
        sendCoverArt(socket);
        return;
    }

    sendSimpleResponse(socket, 404, "Not Found", "text/plain", "Not found.");
}

void ListenAlongServer::sendCoverArt(QTcpSocket *socket)
{
    if (m_currentCoverPath.isEmpty()) {
        sendSimpleResponse(socket,
            404,
            "Not Found",
            "text/plain",
            "No artwork");
        return;
    }

    QFile file(m_currentCoverPath);

    if (!file.open(QIODevice::ReadOnly)) {
        sendSimpleResponse(socket,
            404,
            "Not Found",
            "text/plain",
            "Artwork missing");
        return;
    }

    QByteArray image = file.readAll();

    QByteArray header;
    header += "HTTP/1.1 200 OK\r\n";
    header += "Content-Type: image/png\r\n";      // or detect jpg/png
    header += "Cache-Control: no-store\r\n";
    header += "Content-Length: " + QByteArray::number(image.size()) + "\r\n";
    header += "Connection: close\r\n\r\n";

    socket->write(header);
    socket->write(image);
    socket->disconnectFromHost();
}

void ListenAlongServer::sendSimpleResponse(QTcpSocket *socket, int code, const QString &statusText,
                                            const QString &contentType, const QByteArray &body,
                                            bool closeAfter)
{
    QByteArray response;
    response += "HTTP/1.1 " + QByteArray::number(code) + " " + statusText.toLatin1() + "\r\n";
    response += "Content-Type: " + contentType.toLatin1() + "\r\n";
    response += "Content-Length: " + QByteArray::number(body.size()) + "\r\n";
    response += "Cache-Control: no-store\r\n";
    response += "Access-Control-Allow-Origin: *\r\n";
    response += "Connection: close\r\n\r\n";
    response += body;

    socket->write(response);

    if (closeAfter)
        socket->disconnectFromHost();
}

void ListenAlongServer::beginStreaming(Client *client, qint64 rangeStart)
{
    QTcpSocket *socket = client->socket;

    if (m_isPaused) {
        sendSimpleResponse(socket, 503, "Service Unavailable", "text/plain",
                            "Playback is paused.");
        return;
    }

    if (m_currentFilePath.isEmpty() || !m_sourceFile.isOpen()) {
        sendSimpleResponse(socket, 503, "Service Unavailable", "text/plain",
                            "Nothing is playing right now.");
        return;
    }

    const qint64 fileSize = m_sourceFile.size();
    const bool isRangeRequest = (rangeStart >= 0);
    qint64 startOffset = isRangeRequest ? rangeStart : 0;

    if (startOffset > fileSize) {
        sendSimpleResponse(socket, 416, "Range Not Satisfiable", "text/plain", "");
        return;
    }

    const qint64 remaining = fileSize - startOffset;

    QByteArray header;
    header += "HTTP/1.1 " + QByteArray(isRangeRequest ? "206 Partial Content" : "200 OK") + "\r\n";
    header += "Content-Type: " + m_currentMime.toLatin1() + "\r\n";
    header += "Accept-Ranges: bytes\r\n";
    header += "Content-Length: " + QByteArray::number(remaining) + "\r\n";
    if (isRangeRequest) {
        header += "Content-Range: bytes " + QByteArray::number(startOffset) + "-"
                + QByteArray::number(fileSize - 1) + "/" + QByteArray::number(fileSize) + "\r\n";
    }
    header += "Cache-Control: no-cache, no-store\r\n";
    header += "Access-Control-Allow-Origin: *\r\n";
    header += "icy-name: Meloville Listen Along\r\n";
    header += "Connection: close\r\n\r\n";
    socket->write(header);
    socket->flush();

    // Only flush what's actually been buffered so far -- if the request
    // is for a byte offset ahead of what's been pumped yet, bytesSent
    // starts there and the normal pump loop will catch it up naturally.
    if (startOffset < m_audioBuffer.size()) {
        const char *data = m_audioBuffer.constData() + startOffset;
        constexpr qint64 MaxWrite = 1024 * 1024;
        qint64 len = qMin(MaxWrite, m_audioBuffer.size() - client->bytesSent);
        socket->write(data, len);
        client->bytesSent = startOffset + len;
    } else {
        client->bytesSent = startOffset;
    }

    client->isStreaming = true;
    qDebug() << "Streaming:" << m_currentFilePath << "from offset" << startOffset;
}

void ListenAlongServer::pumpAudioData()
{
    if (m_isPaused)
        return;

    if (m_currentFilePath.isEmpty() || !m_sourceFile.isOpen() || m_currentDurationS <= 0)
        return;

    qint64 fileSize = m_sourceFile.size();
    if (fileSize <= 0)
        return;

    constexpr qint64 PumpChunk = 32 * 1024;

    qint64 targetOffset =qMin(fileSize, m_bytesReadForCurrentSong + PumpChunk);

    if (targetOffset > m_bytesReadForCurrentSong){
        m_sourceFile.seek(m_bytesReadForCurrentSong);

        QByteArray chunk =
            m_sourceFile.read(targetOffset - m_bytesReadForCurrentSong);

        m_audioBuffer.append(chunk);

        m_bytesReadForCurrentSong += chunk.size();
    }

    for (Client *client : std::as_const(m_clients)) {
        if (!client->isStreaming)
            continue;
        if (client->socket->state() != QAbstractSocket::ConnectedState)
            continue;

        constexpr qint64 MaxPending = 256 * 1024;
        constexpr qint64 MaxChunk   = 64 * 1024;

        if (client->socket->bytesToWrite() >= MaxPending)
            continue;

        qint64 available =
            m_audioBuffer.size() - client->bytesSent;

        if (available <= 0)
            continue;

        qint64 len = qMin(available, MaxChunk);

        qint64 written =
            client->socket->write(
                m_audioBuffer.constData() + client->bytesSent,
                len);

        if (written > 0)
            client->bytesSent += written;
    }
}

void ListenAlongServer::handleClientDisconnected()
{
    auto *socket = qobject_cast<QTcpSocket *>(sender());
    if (!socket)
        return;

    for (int i = 0; i < m_clients.size(); ++i) {
        if (m_clients[i]->socket == socket) {
            delete m_clients[i];
            m_clients.removeAt(i);
            break;
        }
    }

    socket->deleteLater();
    emit listenerCountChanged(listenerCount());
}

ListenAlongServer::Client *ListenAlongServer::clientFor(QTcpSocket *socket)
{
    for (Client *client : std::as_const(m_clients)) {
        if (client->socket == socket)
            return client;
    }
    return nullptr;
}

QString ListenAlongServer::mimeTypeForFile(const QString &filePath)
{
    const QString ext = QFileInfo(filePath).suffix().toLower();

    if (ext == "mp3") return "audio/mpeg";
    if (ext == "wav") return "audio/wav";
    if (ext == "flac") return "audio/flac";
    if (ext == "ogg") return "audio/ogg";
    if (ext == "m4a" || ext == "aac") return "audio/aac";

    return "application/octet-stream";
}

QString ListenAlongServer::nowPlayingJson() const
{
    QJsonObject obj;
    obj["title"] = m_currentTitle.isEmpty() ? QStringLiteral("Unknown") : m_currentTitle;
    obj["artist"] = m_currentArtist.isEmpty() ? QStringLiteral("Unknown Artist") : m_currentArtist;
    obj["listeners"] = listenerCount();
    obj["positionMs"] = m_currentPositionMs;
    obj["durationMs"] = m_currentDurationS*1000;
    obj["isPaused"] = m_isPaused;
    obj["trackGeneration"] = qint64(m_trackGeneration);   // <-- new
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

QString ListenAlongServer::nowPlayingHtml() const
{
    QFile file(":/listenAlongServer/listenalong.html");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Failed to load listenalong.html from resources";
        return QString();
    }
    return QString::fromUtf8(file.readAll());
}