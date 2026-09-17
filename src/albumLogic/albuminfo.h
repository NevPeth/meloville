#pragma once
#include <QString>

struct AlbumInfo
{
    QString title;
    QString artist;
    QString coverPath;
    int songCount = 0;
    int releaseYear;
    QVector<int> libraryIndices;
};
