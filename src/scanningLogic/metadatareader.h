#pragma once

#include <QString>
#include <QPixmap>

#include "songdata.h"

class MetadataReader
{
public:
    // Read metadata from audio file
    static SongData readSong(const QString& filePath);

    // Extract embedded album art
    static QPixmap extractCoverArt(const QString& filePath);

    // Extract + save album art to cache
    static QString cacheCoverArt(
        const QString& filePath,
        const QString& cacheDir,
        const QString& fileName
    );

    static bool removeCachedCoverArt(
        const QString& cacheDir,
        const QString& fileName
    );
    
    static QString cacheUserImage(const QString& imagePath, const QString& cacheDir, const QString& fileName);

    static QString saveTagsToFile(
        const QString& filePath,
        const QString& title,
        const QString& artist,
        const QString& album,
        int trackNumber,
        const QString& cachedImagePath
    );

    static QString cacheKeyForPath(const QString &absPath);

    static QString findLrcFile(const QString& dir, const QString& baseName, const QString& musicFolder);

private:
    static QPixmap extractMp3Cover(const QString& path);
    static QPixmap extractFlacCover(const QString& path);
    static QPixmap extractM4ACover(const QString& path);
    static QPixmap extractOggCover(const QString& filePath);
    static QPixmap extractOpusCover(const QString& filePath);
    static QPixmap loadPixmap(const QByteArray& imageData);
    static QPixmap fallbackCover();
};