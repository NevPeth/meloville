#pragma once

#include <QString>

struct SongData {
    QString filePath;
    QString title;
    QString artist;
    QString album;
    QString genre;
    QString coverPath;
    int duration = 0;
    int trackNumber;
};