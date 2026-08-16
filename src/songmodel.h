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
        IsPlayingRole,
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
    int visibleRowForLibraryIndex(int libraryIndex) const;

    Q_INVOKABLE void moveRow(int from, int to);

private slots:
    void rebuildReverseMap();

private:
    QVector<SongData> *library = nullptr;
    QVector<int> *visibleSongs = nullptr;
    QHash<int, int> libIndexToRow;
    int  playingLibraryIndex = -1;
    bool paused = false;
};

#endif // SONGMODEL_H