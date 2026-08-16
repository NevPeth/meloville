#include "songmodel.h"
#include <QTime>

SongModel::SongModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int SongModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid() || !visibleSongs)
        return 0;
    return visibleSongs->size();
}

QVariant SongModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || !library || !visibleSongs)
        return QVariant();

    int songIndex = visibleSongs->at(index.row());
    if (songIndex < 0 || songIndex >= library->size())
        return QVariant();

    const SongData &song = library->at(songIndex);

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
        return time.toString("m:ss");
    }
    case FilePathRole:
        return song.filePath;
    case CoverPathRole:
        return song.coverPath;
    case TrackNumberRole:
        return song.trackNumber;
    case IsPlayingRole:
        return (songIndex == playingLibraryIndex);
    case IsPausedRole:
        return (songIndex == playingLibraryIndex && paused);
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
    roles[IsPlayingRole] = "isPlaying";
    roles[IsPausedRole]  = "isPaused";
    return roles;
}

// Changed to non-const pointers
void SongModel::setSongs(QVector<SongData> *newLibrary, QVector<int> *newVisibleSongs)
{
    beginResetModel();
    library = newLibrary;
    visibleSongs = newVisibleSongs;
    rebuildReverseMap();
    endResetModel();
}

void SongModel::setPlayingIndex(int libraryIndex)
{
    int oldIndex = playingLibraryIndex;
    playingLibraryIndex = libraryIndex;
    paused = false;

    auto notify = [&](int libIdx) {
        if (libIdx < 0) return;
        int row = libIndexToRow.value(libIdx, -1);
        if (row < 0) return;
        QModelIndex mi = index(row);
        emit dataChanged(mi, mi, {IsPlayingRole, IsPausedRole});
    };

    notify(oldIndex);
    notify(libraryIndex);
}

void SongModel::setPausedState(bool isPaused)
{
    paused = isPaused;
    if (playingLibraryIndex < 0) return;
    int row = libIndexToRow.value(playingLibraryIndex, -1);
    if (row < 0) return;
    QModelIndex mi = index(row);
    emit dataChanged(mi, mi, {IsPausedRole});
}

void SongModel::moveRow(int from, int to)
{
    if (!visibleSongs || from < 0 || from >= visibleSongs->size() ||
        to < 0 || to >= visibleSongs->size() || from == to)
        return;

    // Destination for beginMoveRows: if moving down, dest is to+1
    int destChild = (to > from) ? to + 1 : to;

    beginMoveRows(QModelIndex(), from, from, QModelIndex(), destChild);

    // Swap elements in visibleSongs
    int temp = (*visibleSongs)[from];
    if (from < to) {
        for (int i = from; i < to; ++i)
            (*visibleSongs)[i] = (*visibleSongs)[i+1];
        (*visibleSongs)[to] = temp;
    } else {
        for (int i = from; i > to; --i)
            (*visibleSongs)[i] = (*visibleSongs)[i-1];
        (*visibleSongs)[to] = temp;
    }

    // Partial remap: only the affected range changed
    int lo = std::min(from, to), hi = std::max(from, to);
    for (int row = lo; row <= hi; ++row)
        libIndexToRow[(*visibleSongs)[row]] = row;

    endMoveRows();
}

void SongModel::rebuildReverseMap()
{
    libIndexToRow.clear();
    if (!visibleSongs) return;
    libIndexToRow.reserve(visibleSongs->size());
    for (int row = 0; row < visibleSongs->size(); ++row)
        libIndexToRow.insert((*visibleSongs)[row], row);
}

int SongModel::visibleRowForLibraryIndex(int libraryIndex) const
{
    return libIndexToRow.value(libraryIndex, -1);
}