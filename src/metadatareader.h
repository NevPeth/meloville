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

private:
    static QPixmap extractMp3Cover(const QString& path);
    static QPixmap extractFlacCover(const QString& path);
    static QPixmap extractM4ACover(const QString& path);
    static QPixmap loadPixmap(const QByteArray& imageData);
    static QPixmap fallbackCover();
};