#pragma once

#include <QObject>
#include <QNetworkAccessManager>

class YouTubeResolver : public QObject
{
    Q_OBJECT

public:
    explicit YouTubeResolver(QObject *parent = nullptr);
    Q_INVOKABLE void search(const QString &artist, const QString &title);

signals:
    void linkCopied();
    void error(const QString &message);

private:
    void doRequest(const QUrl &url, int redirectsLeft);
    void handleHtml(const QString &html);

    QNetworkAccessManager m_networkManager;

    QString m_artist;
    QString m_title;
};