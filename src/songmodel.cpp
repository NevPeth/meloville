#include "songmodel.h"
#include <QTime>

SongModel::SongModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int SongModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid() || !m_visibleSongs)
        return 0;
    return m_visibleSongs->size();
}

QVariant SongModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || !m_library || !m_visibleSongs)
        return QVariant();

    int songIndex = m_visibleSongs->at(index.row());
    if (songIndex < 0 || songIndex >= m_library->size())
        return QVariant();

    const SongData &song = m_library->at(songIndex);

    switch (role) {
    case TitleRole:
        return song.title;
    case ArtistRole:
        return song.artist;
    case AlbumRole:
        return song.album;
    case DurationRole: {
        QTime time(0, 0);
        time = time.addSecs(song.duration);
        return time.toString("mm:ss");
    }
    case FilePathRole:
        return song.filePath;
    case CoverPathRole:
        return song.coverPath;
    case TrackNumberRole:
        return song.trackNumber;
    case GenreRole:
        return song.genre;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> SongModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[TitleRole] = "title";
    roles[ArtistRole] = "artist";
    roles[AlbumRole] = "album";
    roles[DurationRole] = "duration";
    roles[FilePathRole] = "filePath";
    roles[CoverPathRole] = "coverPath";
    roles[TrackNumberRole] = "trackNumber";
    roles[GenreRole] = "genre";
    return roles;
}

void SongModel::setSongs(const QVector<SongData> *library, const QVector<int> *visibleSongs)
{
    beginResetModel();
    m_library = library;
    m_visibleSongs = visibleSongs;
    endResetModel();
}