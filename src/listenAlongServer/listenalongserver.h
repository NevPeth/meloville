#ifndef LISTENALONGSERVER_H
#define LISTENALONGSERVER_H

#include <QObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QFile>
#include <QTimer>
#include <QList>
#include <QString>
#include <QStringList>

class ListenAlongServer : public QObject
{
    Q_OBJECT

public:
    explicit ListenAlongServer(QObject *parent = nullptr);
    ~ListenAlongServer() override;

    // Starts a fresh session: new token, fresh listening socket.
    // preferredPort == 0 lets the OS pick a free port.
    bool start(quint16 preferredPort = 0);

    // Tears down the session: disconnects all listeners, closes the socket,
    // and clears the token so old links stop working immediately.
    void stop();

    bool isRunning() const;
    quint16 port() const;
    QString token() const { return m_token; }

    // Best-effort list of URLs a listener on your LAN could use.
    // (No external "what is my IP" service is ever contacted.)
    QStringList candidateUrls() const;

    int listenerCount() const { return m_clients.size(); }
    void setPaused(bool paused);
    void sendCoverArt(QTcpSocket *socket);

public slots:
    // Call this whenever MainWindow starts playing a new song.
    void setNowPlaying(
        const QString &filePath,
        const QString &title,
        const QString &artist,
        qint64 durationMs,
        QString coverPath
    );

    // Call this from MainWindow::updatePosition() so the live stream tracks
    // real playback position (and effectively pauses when you pause).
    void syncPlaybackPosition(qint64 positionMs);

signals:
    void sessionStarted(const QString &token, quint16 port);
    void sessionStopped();
    void listenerCountChanged(int count);
    void candidateUrlsReady(QStringList urls);

private slots:
    void handleNewConnection();
    void handleClientReadyRead();
    void handleClientDisconnected();
    void pumpAudioData();

private:
    struct Client{
        QTcpSocket *socket = nullptr;
        QByteArray buffer;          // incoming request bytes, until headers complete
        bool handledRequest = false;
        bool isStreaming = false;   // true once we've replied on /<token>/stream
        qint64 bytesSent = 0; // per-client offset into m_audioBuffer
    };

    //void handleRequest(Client *client, const QString &method, const QString &path);
    void handleRequest(
        Client *client, 
        const QString &method, 
        const QString &path, 
        qint64 rangeStart = -1
    );
    void sendSimpleResponse(
        QTcpSocket *socket, 
        int code,
        const QString &statusText,
        const QString &contentType, 
        const QByteArray &body,
        bool closeAfter = true
    );
    void beginStreaming(Client *client, qint64 rangeStart = -1);
    //void beginStreaming(Client *client);
    QString nowPlayingHtml() const;
    QString nowPlayingJson() const;
    static QString mimeTypeForFile(const QString &filePath);
    Client *clientFor(QTcpSocket *socket);

    QTcpServer *m_server = nullptr;
    QString m_token;
    QList<Client *> m_clients;

    // Currently playing song, mirrored from MainWindow.
    QString m_currentFilePath;
    QString m_currentCoverPath;
    QString m_currentTitle;
    QString m_currentArtist;
    qint64 m_currentDurationS = 0;
    qint64 m_currentPositionMs = 0;
    qint64 m_bytesSentForCurrentSong = 0;
    quint64 m_trackGeneration = 0;
    QString m_currentMime;

    QString m_publicIp;
    bool m_publicIpReachable = false;
    

    QFile m_sourceFile;
    QTimer *m_pumpTimer = nullptr;

    QByteArray m_audioBuffer;              // accumulated bytes for current song, from offset 0
    qint64 m_bytesReadForCurrentSong = 0;  // how far we've read from disk (replaces global sent counter)
    bool m_isPaused = false;

    static constexpr int maxClients = 32;
};

#endif // LISTENALONGSERVER_H