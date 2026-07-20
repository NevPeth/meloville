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
        GenreRole
    };

    explicit SongModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setSongs(const QVector<SongData> *library, const QVector<int> *visibleSongs);

private:
    const QVector<SongData> *library = nullptr;
    const QVector<int> *visibleSongs = nullptr;
};

#endif // SONGMODEL_H