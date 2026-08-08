#include "albumlistmodel.h"

AlbumListModel::AlbumListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void AlbumListModel::setAlbums(const QVector<AlbumInfo> &albums)
{
    beginResetModel();
    m_albums = albums;
    endResetModel();
}

const AlbumInfo &AlbumListModel::albumAt(int row) const
{
    return m_albums[row];
}

int AlbumListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_albums.size();
}

QVariant AlbumListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_albums.size())
        return QVariant();

    const AlbumInfo &album = m_albums[index.row()];

    switch (role) {
    case Qt::DisplayRole:
    case TitleRole:
        return album.title;
    case ArtistRole:
        return album.artist;
    case CoverPathRole:
        return album.coverPath;
    case SongCountRole:
        return album.songCount;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> AlbumListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[TitleRole] = "title";
    roles[ArtistRole] = "artist";
    roles[CoverPathRole] = "coverPath";
    roles[SongCountRole] = "songCount";
    return roles;
}
