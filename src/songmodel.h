#ifndef SONGMODEL_H
#define SONGMODEL_H

#include <QAbstractListModel>
#include <QVector>
#include "songdata.h"

class SongModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum SongRoles {
        TitleRole = Qt::UserRole + 1,
        ArtistRole,
        AlbumRole,
        DurationRole,
        FilePathRole,
        CoverPathRole,
        TrackNumberRole,
        GenreRole,
        IsPlayingRole,
        IsActiveRole,
        IsPausedRole
    };

    explicit SongModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Change to non-const pointers so we can modify visibleSongs
    void setSongs(QVector<SongData> *library, QVector<int> *visibleSongs);
    void setPlayingIndex(int libraryIndex);
    void setPausedState(bool paused);

    // New method for reordering
    Q_INVOKABLE void moveRow(int from, int to);

private:
    QVector<SongData> *library = nullptr;      // non-const
    QVector<int> *visibleSongs = nullptr;      // non-const
    int  playingLibraryIndex = -1;
    bool paused = false;
};

#endif // SONGMODEL_H
// #ifndef SONGMODEL_H
// #define SONGMODEL_H

// #include <QAbstractListModel>
// #include <QVector>
// #include "songdata.h"

// class SongModel : public QAbstractListModel
// {
//     Q_OBJECT

// public:
//     enum SongRoles {
//         TitleRole = Qt::UserRole + 1,
//         ArtistRole,
//         AlbumRole,
//         DurationRole,
//         FilePathRole,
//         CoverPathRole,
//         TrackNumberRole,
//         GenreRole,
//         IsPlayingRole,
//         IsActiveRole,
//         IsPausedRole
//     };

//     explicit SongModel(QObject *parent = nullptr);

//     int rowCount(const QModelIndex &parent = QModelIndex()) const override;
//     QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
//     QHash<int, QByteArray> roleNames() const override;

//     void setSongs(const QVector<SongData> *library, const QVector<int> *visibleSongs);
//     void setPlayingIndex(int libraryIndex);
//     void setPausedState(bool paused);

// private:
//     const QVector<SongData> *library = nullptr;
//     const QVector<int> *visibleSongs = nullptr;
//     int  playingLibraryIndex = -1;
//     bool paused = false;
// };

// #endif // SONGMODEL_H