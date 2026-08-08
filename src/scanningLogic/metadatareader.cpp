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
#include <taglib/id3v2framefactory.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/flacpicture.h>
#include <taglib/mp4coverart.h>

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

    // Sanitize filename for use in a URL
    QString safeFileName = fileName;
    safeFileName.replace("?", "_");

    QPixmap cover = extractCoverArt(filePath);
    QString coverPath = cacheDir + "/" + safeFileName + ".jpg";
    cover.save(coverPath, "JPG", 90);
    return coverPath;
}

bool MetadataReader::removeCachedCoverArt(const QString& cacheDir, const QString& fileName){
    QString safeFileName = fileName;
    safeFileName.replace("?", "_");
    QString coverPath = cacheDir + "/" + safeFileName + ".jpg";
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

    QString coverPath = cacheDir + "/" + fileName + ".jpg";
    image.save(coverPath, "JPG", 90);

    return coverPath;
}

QString MetadataReader::saveTagsToFile(
    const QString& filePath,
    const QString& title,
    const QString& artist,
    const QString& album,
    int trackNumber,
    const QString& cachedImagePath)
{
    if (filePath.isEmpty())
        return {};

    // Read the image bytes once up front
    QByteArray imageData;
    QString suffix;
    if (!cachedImagePath.isEmpty())
    {
        QFile imageFile(cachedImagePath);
        if (imageFile.open(QIODevice::ReadOnly))
        {
            imageData = imageFile.readAll();
            imageFile.close();
            suffix = QFileInfo(cachedImagePath).suffix().toLower();
        }
    }

    const QString ext = QFileInfo(filePath).suffix().toLower();

    // ── MP3 ──────────────────────────────────────────────────────────────────
    if (ext == "mp3")
    {
        TagLib::MPEG::File f(filePath.toUtf8().constData());
        if (!f.isValid()) return {};

        auto* tag = f.ID3v2Tag(true); // create if missing
        tag->setTitle (TagLib::String(title.toUtf8().constData(),  TagLib::String::UTF8));
        tag->setArtist(TagLib::String(artist.toUtf8().constData(), TagLib::String::UTF8));
        tag->setAlbum (TagLib::String(album.toUtf8().constData(),  TagLib::String::UTF8));
        tag->setTrack (trackNumber);

        if (!imageData.isEmpty())
        {
            // Remove existing cover frames
            tag->removeFrames("APIC");

            auto* frame = new TagLib::ID3v2::AttachedPictureFrame();
            frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
            frame->setMimeType(suffix == "png" ? "image/png" : "image/jpeg");
            frame->setPicture(TagLib::ByteVector(imageData.constData(), imageData.size()));
            tag->addFrame(frame);
        }

        f.save();
        return cachedImagePath;
    }

    // ── FLAC ─────────────────────────────────────────────────────────────────
    if (ext == "flac")
    {
        TagLib::FLAC::File f(filePath.toUtf8().constData());
        if (!f.isValid()) return {};

        // Write basic tags via the Xiph comment
        auto* xiphTag = f.xiphComment(true);
        xiphTag->setTitle (TagLib::String(title.toUtf8().constData(),  TagLib::String::UTF8));
        xiphTag->setArtist(TagLib::String(artist.toUtf8().constData(), TagLib::String::UTF8));
        xiphTag->setAlbum (TagLib::String(album.toUtf8().constData(),  TagLib::String::UTF8));
        xiphTag->setTrack (trackNumber);

        if (!imageData.isEmpty())
        {
            // Remove all existing pictures
            f.removePictures();

            auto* picture = new TagLib::FLAC::Picture();
            picture->setType(TagLib::FLAC::Picture::FrontCover);
            picture->setMimeType(suffix == "png" ? "image/png" : "image/jpeg");
            picture->setData(TagLib::ByteVector(imageData.constData(), imageData.size()));
            f.addPicture(picture); // FLAC::File takes ownership
        }

        f.save();
        return cachedImagePath;
    }

    // ── M4A / MP4 / AAC ──────────────────────────────────────────────────────
    if (ext == "m4a" || ext == "mp4" || ext == "aac")
    {
        TagLib::MP4::File f(filePath.toUtf8().constData());
        if (!f.isValid()) return {};

        auto* tag = f.tag();
        tag->setTitle (TagLib::String(title.toUtf8().constData(),  TagLib::String::UTF8));
        tag->setArtist(TagLib::String(artist.toUtf8().constData(), TagLib::String::UTF8));
        tag->setAlbum (TagLib::String(album.toUtf8().constData(),  TagLib::String::UTF8));
        tag->setTrack (trackNumber);

        if (!imageData.isEmpty())
        {
            TagLib::MP4::CoverArt::Format format =
                (suffix == "png") ? TagLib::MP4::CoverArt::PNG
                                  : TagLib::MP4::CoverArt::JPEG;

            TagLib::MP4::CoverArt coverArt(
                format,
                TagLib::ByteVector(imageData.constData(), imageData.size())
            );

            TagLib::MP4::CoverArtList coverList;
            coverList.append(coverArt);

            tag->setItem("covr", TagLib::MP4::Item(coverList));
        }

        f.save();
        return cachedImagePath;
    }

    return {};
}