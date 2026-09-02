#include "youtuberesolver.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QUrl>
#include <QUrlQuery>
#include <QProcess>

namespace
{

constexpr int MaxRedirects = 5;

// search parameter for "Videos only".
constexpr auto VideoSearchParams = "EgIQAfABAQ==";

// Recursively search a JSON object/array for the first video ID.
//
// YouTube has changed the shape of search results several times.
// Older responses use:
//
//   videoRenderer.videoId
//
// Newer responses can use:
//
//   lockupViewModel.contentId
//   lockupViewModel.contentType == LOCKUP_CONTENT_TYPE_VIDEO
//
QString findFirstVideoId(const QJsonValue &value)
{
    if (value.isObject())
    {
        const QJsonObject object = value.toObject();

        // Traditional search result.
        const QJsonValue videoRendererValue = object.value("videoRenderer");
        if (videoRendererValue.isObject())
        {
            const QString videoId =
                videoRendererValue.toObject().value("videoId").toString();

            if (!videoId.isEmpty())
                return videoId;
        }

        // Newer YouTube "lockupViewModel".
        const QJsonValue lockupValue = object.value("lockupViewModel");
        if (lockupValue.isObject())
        {
            const QJsonObject lockup = lockupValue.toObject();

            if (lockup.value("contentType").toString()
                == "LOCKUP_CONTENT_TYPE_VIDEO")
            {
                const QString videoId =
                    lockup.value("contentId").toString();

                if (!videoId.isEmpty())
                    return videoId;
            }

            // Some responses nest the actual model further down.
            const QString nestedId = findFirstVideoId(lockupValue);
            if (!nestedId.isEmpty())
                return nestedId;
        }

        for (auto it = object.constBegin(); it != object.constEnd(); ++it)
        {
            const QString result = findFirstVideoId(it.value());

            if (!result.isEmpty())
                return result;
        }
    }
    else if (value.isArray())
    {
        const QJsonArray array = value.toArray();

        for (const QJsonValue &entry : array)
        {
            const QString result = findFirstVideoId(entry);

            if (!result.isEmpty())
                return result;
        }
    }

    return {};
}

// Extract a quoted value from ytInitialPlayerResponse / ytcfg.
//
// For example:
//
// "INNERTUBE_API_KEY":"xxxxxxxx"
//
// or:
//
// 'INNERTUBE_API_KEY': 'xxxxxxxx'
//
QString extractYtConfigValue(const QString &html, const QString &name)
{
    const QString escapedName = QRegularExpression::escape(name);

    const QString pattern =
        QStringLiteral(R"((?:"|')%1(?:"|')\s*:\s*(?:"|')([^"']+)(?:"|'))")
            .arg(escapedName);

    const QRegularExpression regex(pattern);
    const QRegularExpressionMatch match = regex.match(html);

    if (!match.hasMatch())
        return {};

    return match.captured(1);
}

// Find a useful YouTube initial-data JSON block if it exists.
//
// This is not the primary search mechanism; the Innertube API response is.
// This helper is here mainly to make the implementation tolerant of changes
// to YouTube's surrounding HTML.
QByteArray extractInitialData(const QString &html)
{
    const QString marker = QStringLiteral("ytInitialData =");

    const qsizetype markerPos = html.indexOf(marker);

    if (markerPos < 0)
        return {};

    const qsizetype objectStart = html.indexOf('{', markerPos);

    if (objectStart < 0)
        return {};

    int depth = 0;
    bool inString = false;
    bool escaped = false;

    for (qsizetype i = objectStart; i < html.size(); ++i)
    {
        const QChar c = html.at(i);

        if (inString)
        {
            if (escaped)
            {
                escaped = false;
            }
            else if (c == '\\')
            {
                escaped = true;
            }
            else if (c == '"')
            {
                inString = false;
            }

            continue;
        }

        if (c == '"')
        {
            inString = true;
            continue;
        }

        if (c == '{')
        {
            ++depth;
        }
        else if (c == '}')
        {
            --depth;

            if (depth == 0)
                return html.mid(objectStart, i - objectStart + 1).toUtf8();
        }
    }

    return {};
}

} // namespace

YouTubeResolver::YouTubeResolver(QObject *parent)
    : QObject(parent)
{
}

void YouTubeResolver::search(const QString &artist, const QString &title)
{
    m_artist = artist.trimmed();
    m_title = title.trimmed();

    if (m_artist.isEmpty() || m_title.isEmpty())
    {
        emit error(QStringLiteral("Artist and title are required."));
        return;
    }

    /*
     * Match yt-dlp's basic search strategy:
     *
     *     ytsearch1:"artist title"
     *
     * yt-dlp ultimately sends the query to YouTube's Innertube search API.
     *
     * We first load YouTube itself so that we can obtain the current
     * INNERTUBE_API_KEY and INNERTUBE client configuration instead of
     * baking those values into the application.
     */
    QUrl url(QStringLiteral("https://www.youtube.com/"));

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("hl"), QStringLiteral("en"));
    url.setQuery(query);

    doRequest(url, MaxRedirects);
}

void YouTubeResolver::doRequest(const QUrl &url, int redirectsLeft)
{
    if (!url.isValid())
    {
        emit error(QStringLiteral("Invalid YouTube URL."));
        return;
    }

    QNetworkRequest request(url);

    request.setAttribute(
        QNetworkRequest::RedirectPolicyAttribute,
        QNetworkRequest::NoLessSafeRedirectPolicy);

    request.setHeader(
        QNetworkRequest::UserAgentHeader,
        QStringLiteral(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/140.0.0.0 Safari/537.36"));

    request.setRawHeader(
        "Accept-Language",
        "en-US,en;q=0.9");

    QNetworkReply *reply = m_networkManager.get(request);

    connect(
        reply,
        &QNetworkReply::finished,
        this,
        [this, reply, redirectsLeft]()
        {
            reply->deleteLater();

            if (reply->error() != QNetworkReply::NoError)
            {
                emit error(
                    QStringLiteral("YouTube request failed: %1")
                        .arg(reply->errorString()));
                return;
            }

            const QVariant redirect =
                reply->attribute(QNetworkRequest::RedirectionTargetAttribute);

            if (redirect.isValid() && redirectsLeft > 0)
            {
                const QUrl redirectedUrl =
                    reply->url().resolved(redirect.toUrl());

                doRequest(redirectedUrl, redirectsLeft - 1);
                return;
            }

            const QByteArray data = reply->readAll();

            if (data.isEmpty())
            {
                emit error(QStringLiteral("YouTube returned an empty response."));
                return;
            }

            handleHtml(QString::fromUtf8(data));
        });
}

void YouTubeResolver::handleHtml(const QString &html)
{
    /*
     * yt-dlp reads the current YouTube ytcfg and obtains the Innertube
     * client configuration from it. The current source uses a WEB client
     * for normal YouTube search. See yt-dlp's youtube/_base.py.
     */

    const QString apiKey =
        extractYtConfigValue(html, QStringLiteral("INNERTUBE_API_KEY"));

    if (apiKey.isEmpty())
    {
        emit error(
            QStringLiteral(
                "Could not find YouTube's Innertube API key."));
        return;
    }

    QString clientVersion =
        extractYtConfigValue(
            html,
            QStringLiteral("INNERTUBE_CLIENT_VERSION"));

    /*
     * YouTube normally exposes the client version in ytcfg. This fallback
     * is only there for pages where that field is absent.
     *
     * Do not depend on this value remaining valid forever.
     */
    if (clientVersion.isEmpty())
    {
        clientVersion = QStringLiteral("2.20260708.00.00");
    }

    const QString query =
        m_artist + QStringLiteral(" ") + m_title;

    QJsonObject client;
    client.insert(QStringLiteral("clientName"), QStringLiteral("WEB"));
    client.insert(QStringLiteral("clientVersion"), clientVersion);
    client.insert(QStringLiteral("hl"), QStringLiteral("en"));

    QJsonObject context;
    context.insert(QStringLiteral("client"), client);

    QJsonObject body;
    body.insert(QStringLiteral("context"), context);
    body.insert(QStringLiteral("query"), query);

    // Same "videos only" filter used by yt-dlp.
    body.insert(
        QStringLiteral("params"),
        QString::fromLatin1(VideoSearchParams));

    const QByteArray payload =
        QJsonDocument(body).toJson(QJsonDocument::Compact);

    const QUrl searchUrl(
        QStringLiteral(
            "https://www.youtube.com/youtubei/v1/search?key=%1"
            "&prettyPrint=false")
            .arg(QString(QUrl::toPercentEncoding(apiKey))));

    QNetworkRequest request(searchUrl);

    request.setHeader(
        QNetworkRequest::ContentTypeHeader,
        QStringLiteral("application/json"));

    request.setRawHeader(
        "Accept",
        "application/json");

    request.setRawHeader(
        "Accept-Language",
        "en-US,en;q=0.9");

    request.setRawHeader(
        "Origin",
        "https://www.youtube.com");

    request.setRawHeader(
        "X-YouTube-Client-Name",
        "1");

    request.setRawHeader(
        "X-YouTube-Client-Version",
        clientVersion.toUtf8());

    request.setHeader(
        QNetworkRequest::UserAgentHeader,
        QStringLiteral(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/140.0.0.0 Safari/537.36"));

    QNetworkReply *reply =
        m_networkManager.post(request, payload);

    connect(
        reply,
        &QNetworkReply::finished,
        this,
        [this, reply]()
        {
            reply->deleteLater();

            if (reply->error() != QNetworkReply::NoError)
            {
                emit error(
                    QStringLiteral("YouTube search failed: %1")
                        .arg(reply->errorString()));
                return;
            }

            const QByteArray data = reply->readAll();

            QJsonParseError parseError;
            const QJsonDocument document =
                QJsonDocument::fromJson(data, &parseError);

            if (parseError.error != QJsonParseError::NoError)
            {
                emit error(
                    QStringLiteral(
                        "Could not parse YouTube's search response: %1")
                        .arg(parseError.errorString()));
                return;
            }

            /*
             * Search for the first actual VIDEO result.
             *
             * This deliberately walks the whole response rather than
             * assuming a fixed sectionListRenderer path. YouTube has
             * changed the response hierarchy several times, which is one
             * reason yt-dlp has generalized traversal logic around these
             * renderers.
             */
            const QString videoId =
                findFirstVideoId(document.object());

            if (videoId.isEmpty())
            {
                /*
                 * As a fallback, try ytInitialData if YouTube happened to
                 * return a normal search page structure in the response.
                 */
                const QByteArray initialData =
                    extractInitialData(QString::fromUtf8(data));

                if (!initialData.isEmpty())
                {
                    const QJsonDocument fallbackDocument =
                        QJsonDocument::fromJson(initialData);

                    if (!fallbackDocument.isNull())
                    {
                        const QString fallbackId =
                            findFirstVideoId(fallbackDocument.object());

                        if (!fallbackId.isEmpty())
                        {
                            const QString url =
                                QStringLiteral(
                                    "https://www.youtube.com/watch?v=%1")
                                    .arg(fallbackId);

                            QClipboard *clipboard =
                                QGuiApplication::clipboard();

                            if (!clipboard)
                            {
                                emit error(
                                    QStringLiteral(
                                        "No system clipboard is available."));
                                return;
                            }

                            clipboard->setText(url);
                            emit linkCopied();
                            return;
                        }
                    }
                }

                emit error(
                    QStringLiteral(
                        "No YouTube video was found for \"%1\" by \"%2\".")
                        .arg(m_title, m_artist));
                return;
            }

            const QString youtubeUrl =
                QStringLiteral(
                    "https://www.youtube.com/watch?v=%1")
                    .arg(videoId);

            qDebug() << "YouTubeResolver: Found video ID" << youtubeUrl;

            QClipboard *clipboard = QGuiApplication::clipboard();

            if (!clipboard)
            {
                qDebug() << "Clipboard error";
                emit error(
                    QStringLiteral(
                        "No system clipboard is available."));
                return;
            }

            clipboard->setText(youtubeUrl);

            emit linkCopied();
        });
}