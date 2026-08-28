#pragma once
#include <QString>

struct AlbumInfo
{
    QString title;
    QString artist;
    QString coverPath;
    int songCount = 0;
    QVector<int> libraryIndices;
};
