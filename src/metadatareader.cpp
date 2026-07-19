#include "metadatareader.h"

#include <QFileInfo>
#include <QDir>
#include <QRegularExpression>

#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/audioproperties.h>
#include <taglib/tfile.h>
#include <taglib/flacfile.h>
#include <taglib/mp4file.h>
#include <taglib/oggflacfile.h>
#include <taglib/flacpicture.h>

SongData MetadataReader::readSong(const QString& filePath)
{
    SongData song;
    song.filePath = filePath;

    TagLib::FileRef file(
        filePath.toStdString().c_str()
    );

    if (!file.isNull()) {
        if (file.tag()) {
            song.title =
                QString::fromStdWString(
                    file.tag()->title().toWString()
                );

            song.artist =
                QString::fromStdWString(
                    file.tag()->artist().toWString()
                );

            song.album =
                QString::fromStdWString(
                    file.tag()->album().toWString()
                );

            song.genre =
                QString::fromStdWString(
                    file.tag()->genre().toWString()
                );

            song.trackNumber = static_cast<int>(file.tag()->track());
        }
        if (file.audioProperties()) {
            song.duration = file.audioProperties()->lengthInSeconds();
        }
    }
    bool artistAndTitleTagsWereMissing = !file.isNull() && file.tag() && song.title.isEmpty() && song.artist.isEmpty();
    // Fallbacks
    if (artistAndTitleTagsWereMissing) {
        QFileInfo fileInfo(filePath);
        QString baseName = fileInfo.completeBaseName(); // filename without extension

        // Match "artist - title", tolerant of missing/extra spaces around the dash,
        // and allowing hyphen, en-dash, or em-dash as the separator.
        static const QRegularExpression separatorRegex(
            QStringLiteral("\\s*[-\u2013\u2014]\\s*")
        );

        QRegularExpressionMatch match = separatorRegex.match(baseName);

        if (match.hasMatch()) {
            QString left = baseName.left(match.capturedStart()).trimmed();
            QString right = baseName.mid(match.capturedEnd()).trimmed();

            if (!left.isEmpty() && !right.isEmpty()) {
                song.artist = left;
                song.title = right;
            } else {
                // Only one side had content, treat whole thing as title
                song.title = baseName.trimmed();
            }
        } else {
            // No separator found, use the whole filename as the title
            song.title = baseName.trimmed();
        }
        file.tag()->setTitle(TagLib::String(song.title.toStdWString()));
        file.tag()->setArtist(TagLib::String(song.artist.toStdWString()));
        if (!file.save())
            qWarning() << "Failed to save guessed tags for" << filePath;
    }
    if (song.title.isEmpty())
        song.title = "Unknown";

    if (song.artist.isEmpty())
        song.artist = "Unknown Artist";

    return song;
}

QString MetadataReader::cacheCoverArt(
    const QString& filePath,
    const QString& cacheDir,
    const QString& fileName
)
{
    QDir().mkpath(cacheDir);

    QPixmap cover = extractCoverArt(filePath);

    QString coverPath = cacheDir + "/" + fileName + ".png";

    cover.save(
        coverPath,
        "JPG",
        90
    );

    return coverPath;
}

bool MetadataReader::removeCachedCoverArt(const QString& cacheDir, const QString& fileName){
    QString coverPath = cacheDir + "/" + fileName + ".png";
    return QFile::remove(coverPath);
}

QPixmap MetadataReader::extractCoverArt(
    const QString& filePath
)
{
    const QString extension =
        QFileInfo(filePath)
            .suffix()
            .toLower();

    if (extension == "mp3")
        return extractMp3Cover(filePath);

    if (extension == "flac")
        return extractFlacCover(filePath);

    if (extension == "m4a" || extension == "mp4" || extension == "aac"){
        return extractM4ACover(filePath);
    }

    return fallbackCover();
}

QPixmap MetadataReader::extractMp3Cover(const QString& filePath){
    TagLib::MPEG::File file(
        filePath.toStdString().c_str()
    );

    auto* tag = file.ID3v2Tag();

    if (!tag)
        return fallbackCover();

    auto frames = tag->frameListMap()["APIC"];

    if (frames.isEmpty())
        return fallbackCover();

    auto* pictureFrame =
        static_cast<
            TagLib::ID3v2::AttachedPictureFrame*
        >(frames.front());

    QByteArray imageData(
        pictureFrame->picture().data(),
        pictureFrame->picture().size()
    );

    QPixmap cover;

    if (!cover.loadFromData(imageData))
        return fallbackCover();

    return cover;
}

QPixmap MetadataReader::extractFlacCover(const QString& filePath){
    TagLib::FLAC::File file(
        filePath.toStdString().c_str()
    );

    // Try native FLAC picture blocks first
    auto pictures = file.pictureList();
    if (!pictures.isEmpty()) {
        auto* picture = pictures.front();
        QByteArray imageData(
            picture->data().data(),
            picture->data().size()
        );
        QPixmap cover;
        if (cover.loadFromData(imageData))
            return cover;
    }

    // Fall back to ID3v2 tag (some encoders embed art here instead)
    auto* id3tag = file.ID3v2Tag();
    if (id3tag) {
        auto frames = id3tag->frameListMap()["APIC"];
        if (!frames.isEmpty()) {
            auto* pictureFrame =
                static_cast<TagLib::ID3v2::AttachedPictureFrame*>(frames.front());
            QByteArray imageData(
                pictureFrame->picture().data(),
                pictureFrame->picture().size()
            );
            QPixmap cover;
            if (cover.loadFromData(imageData))
                return cover;
        }
    }

    return fallbackCover();
}

QPixmap MetadataReader::extractM4ACover(const QString& filePath){
    TagLib::MP4::File file(
        filePath.toStdString().c_str()
    );

    auto* tag = file.tag();

    if (!tag)
        return fallbackCover();

    auto items =
        tag->itemMap();

    if (!items.contains("covr"))
        return fallbackCover();

    auto covers = items["covr"].toCoverArtList();

    if (covers.isEmpty())
        return fallbackCover();

    QByteArray imageData(
        covers.front().data().data(),
        covers.front().data().size()
    );

    QPixmap cover;

    if (!cover.loadFromData(imageData))
        return fallbackCover();

    return cover;
}

QPixmap MetadataReader::loadPixmap(const QByteArray& imageData){
    QPixmap cover;

    if (!cover.loadFromData(imageData))
        return fallbackCover();

    return cover;
}

QPixmap MetadataReader::fallbackCover(){
    static QPixmap fallback(
        ":/images/default_cover.png"
    );

    return fallback;
}

QString MetadataReader::cacheUserImage(
    const QString& imagePath,
    const QString& cacheDir,
    const QString& fileName
)
{
    QDir().mkpath(cacheDir);

    QPixmap image(imagePath);
    if (image.isNull())
        return QString();

    QString coverPath = cacheDir + "/" + fileName + ".png";
    image.save(coverPath, "JPG", 90);   // note: still worth fixing the JPG/.png mismatch below

    return coverPath;
}