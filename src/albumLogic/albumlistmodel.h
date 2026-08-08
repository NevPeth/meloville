#pragma once
#include <QAbstractListModel>
#include <QVector>
#include "albuminfo.h"

class AlbumListModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum AlbumRoles {
        TitleRole = Qt::UserRole + 1,
        ArtistRole,
        CoverPathRole,
        SongCountRole
    };

    explicit AlbumListModel(QObject *parent = nullptr);

    void setAlbums(const QVector<AlbumInfo> &albums);
    const AlbumInfo &albumAt(int row) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    QVector<AlbumInfo> m_albums;
};
