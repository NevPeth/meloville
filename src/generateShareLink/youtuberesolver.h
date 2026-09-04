#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QTimer>

class YouTubeResolver : public QObject
{
    Q_OBJECT

public:
    explicit YouTubeResolver(QObject *parent = nullptr);
    Q_INVOKABLE void search(const QString &artist, const QString &title);

signals:
    void linkCopied();
    void failedToCopyLink();

private:
    void doRequest(const QUrl &url, int redirectsLeft);
    void handleHtml(const QString &html);

    QNetworkAccessManager m_networkManager;

    QTimer *m_timeoutTimer = nullptr;
    static constexpr int RequestTimeoutMs = 10000;

    QString m_artist;
    QString m_title;
};