#include "playlistmanager.h"
#include "songdata.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QList>
#include <QFont>
#include <QFontMetrics>

PlaylistManager::PlaylistManager(QObject *parent): QObject(parent)
{
}

void PlaylistManager::createPlaylist(
    const QString& name,
    const QString& imagePath
)
{
    if (playlists.contains(name))
        return;

    playlists[name] = {};
    playlistDefinitions[name] = {};
    playlistImages[name] = imagePath;
    playlistTitleFontSizes[name] = calculateTitleSize(name);

    playlistOrder.append(name);

    savePlaylists();
    emit playlistCreated(name);
}

void PlaylistManager::addSongToPlaylist(
    const QString& playlistName,
    int libraryIndex,
    const SongData& song
)
{
    if (playlists[playlistName].contains(libraryIndex))
        return;
    playlists[playlistName].append(libraryIndex);

    PlaylistSong playlistSong;
    playlistSong.title = song.title;
    playlistSong.artist = song.artist;

    playlistDefinitions[playlistName].append(
        playlistSong
    );

    savePlaylists();
}

void PlaylistManager::removeSongFromPlaylist(
    const QString& playlistName,
    int libraryIndex)
{
    if (!playlists.contains(playlistName))
        return;

    int index =
        playlists[playlistName].indexOf(
            libraryIndex
        );

    if (index < 0)
        return;

    playlists[playlistName].removeAt(index);
    playlistDefinitions[playlistName].removeAt(index);

    savePlaylists();
}

void PlaylistManager::editSongFromAllPlaylists(int libraryIndex, const QString& newSongTitle, const QString& newArtist){
    for(const QString& playlistName : playlistOrder){
        int index =
            playlists[playlistName].indexOf(
                libraryIndex
            );

        if (index < 0)
            continue;

        PlaylistSong& playlistSong = playlistDefinitions[playlistName][index];
        playlistSong.title = newSongTitle;
        playlistSong.artist = newArtist;
    }
    savePlaylists();
}

void PlaylistManager::removeSongFromAllPlaylists(int libraryIndex)
{
    for(const QString& playlistName : playlistOrder){
        int index =
            playlists[playlistName].indexOf(
                libraryIndex
            );

        if (index < 0)
            continue;

        playlists[playlistName].removeAt(index);
        playlistDefinitions[playlistName].removeAt(index);
    }
    savePlaylists();
}

QStringList PlaylistManager::playlistNames() const
{
    return playlistOrder;
}

QList<int> PlaylistManager::getPlaylistSongs(
    const QString& playlistName
) const
{
    return playlists.value(
        playlistName
    );
}

QString PlaylistManager::playlistImage(
    const QString& playlistName
) const
{
    return playlistImages.value(
        playlistName
    );
}

int PlaylistManager::playlistTitleFontSize(const QString& playlist) const{
    return playlistTitleFontSizes.value(playlist, 60);
}

void PlaylistManager::setPath(const QString& path){
    playlistPath = path;
}

void PlaylistManager::savePlaylists()
{
    QJsonObject root;

    // Saves the playlist order
    QJsonArray orderArray;
    for (const QString& playlist : playlistOrder){
        orderArray.append(playlist);
    }
    root["playlistOrder"] = orderArray;

    //Saves the songs that are currently in the playlist
    QJsonObject playlistsObject;
    for (const QString& playlist : playlistOrder){
        QJsonObject playlistObject;
        playlistObject["image"] = playlistImages.value(playlist);
        playlistObject["titleFontSize"] = playlistTitleFontSizes.value(playlist);
        QJsonArray songs;
        for (const PlaylistSong& song : playlistDefinitions.value(playlist)){
            QJsonObject songObject;

            songObject["title"] = song.title;
            songObject["artist"] = song.artist;

            songs.append(songObject);
        }
        playlistObject["songs"] = songs;
        playlistsObject[playlist] = playlistObject;
    }
    root["playlists"] = playlistsObject;

    QFile file(playlistPath+ + "/playlists.json");

    if (!file.open(QIODevice::WriteOnly))
        return;

    file.write(
        QJsonDocument(root).toJson()
    );
}

void PlaylistManager::loadPlaylists(
    const QVector<SongData>& library,
    bool emitSignals
)
{
    QFile file(playlistPath + "/playlists.json");

    if (!file.open(QIODevice::ReadOnly))
        return;

    QJsonObject root =
        QJsonDocument::fromJson(
            file.readAll()
        ).object();

    playlists.clear();
    playlistDefinitions.clear();
    playlistImages.clear();
    playlistOrder.clear();

    QJsonArray orderArray = root["playlistOrder"].toArray();
    QJsonObject playlistsObject = root["playlists"].toObject();

    for (const QJsonValue& value : orderArray)
        playlistOrder.append(value.toString());

    for (const QString& playlist : playlistOrder)
    {
        QJsonObject playlistObject = playlistsObject[playlist].toObject();

        playlistImages[playlist] = playlistObject["image"].toString();
        playlistTitleFontSizes[playlist] = playlistObject["titleFontSize"].toInt();

        QList<int> indices;
        QList<PlaylistSong> songs;

        QJsonArray songArray = playlistObject["songs"].toArray();

        for (const QJsonValue& value : songArray)
        {
            QJsonObject obj = value.toObject();

            PlaylistSong playlistSong;
            playlistSong.title = obj["title"].toString();
            playlistSong.artist = obj["artist"].toString();

            songs.append(playlistSong);

            // Binary search by title using the same comparator as the sort
            int lo = 0, hi = library.size() - 1, found = -1;
            while (lo <= hi)
            {
                int mid = lo + (hi - lo) / 2;
                int cmp = QString::compare(
                    library[mid].title,
                    playlistSong.title,
                    Qt::CaseInsensitive
                );

                if (cmp < 0)       lo = mid + 1;
                else if (cmp > 0)  hi = mid - 1;
                else
                {
                    // Title matched — scan the equal-title block for the right artist
                    // Scan left
                    for (int i = mid; i >= lo && QString::compare(library[i].title, playlistSong.title, Qt::CaseInsensitive) == 0; --i)
                    {
                        if (library[i].artist.compare(playlistSong.artist, Qt::CaseInsensitive) == 0)
                        {
                            found = i;
                            break;
                        }
                    }
                    // Scan right if not yet found
                    if (found < 0)
                    {
                        for (int i = mid + 1; i <= hi && QString::compare(library[i].title, playlistSong.title, Qt::CaseInsensitive) == 0; ++i)
                        {
                            if (library[i].artist.compare(playlistSong.artist, Qt::CaseInsensitive) == 0)
                            {
                                found = i;
                                break;
                            }
                        }
                    }
                    break;
                }
            }

            if (found >= 0)
                indices.append(found);
        }

        playlistDefinitions[playlist] = songs;
        playlists[playlist] = indices;

        if (emitSignals)
            emit playlistCreated(playlist);
    }
}

void PlaylistManager::editPlaylist(
    const QString& oldName,
    const QString& newName,
    const QString& imagePath
)
{
    if (!playlists.contains(oldName))
        return;

    bool changed = false;

    if (oldName != newName){
        playlists[newName] = playlists.take(oldName);
        playlistDefinitions[newName] = playlistDefinitions.take(oldName);

        QString oldImage = playlistImages.take(oldName);
        playlistImages[newName] = oldImage;
        playlistTitleFontSizes[newName] = playlistTitleFontSizes.take(oldName);
        playlistTitleFontSizes[newName] = calculateTitleSize(newName);

        int index = playlistOrder.indexOf(oldName);
        if (index >= 0){
            playlistOrder[index] = newName;
        }
        changed = true;
    }

    if (!imagePath.isEmpty()){
        QString currentImage = playlistImages.value(newName);

        if (currentImage != imagePath){
            if (!currentImage.isEmpty()){
                QFile::remove(playlistPath+currentImage);
            }

            playlistImages[newName] = imagePath;
        }
        changed = true;
    }
    
    if (changed){
        savePlaylists();
        emit playlistChanged(newName);
    }
}

void PlaylistManager::deletePlaylist(
    const QString& playlistName
)
{
    if (!playlists.contains(playlistName))
        return;

    emit playlistDeleted(playlistName);

    QString cover = playlistImages.value(playlistName);

    if (!cover.isEmpty())
    {
        QFile::remove(playlistPath+cover);
    }

    playlists.remove(playlistName);
    playlistDefinitions.remove(playlistName);
    playlistImages.remove(playlistName);
    playlistOrder.removeAll(playlistName);

    savePlaylists();
}

int PlaylistManager::calculateTitleSize(const QString& text)
{
    constexpr int maxSize = 65;
    constexpr int minSize = 1;
    constexpr int maxWidth = 1200; // Available label width

    for (int size = maxSize; size >= minSize; --size)
    {
        QFont font;
        font.setPixelSize(size);
        font.setBold(true);

        QFontMetrics fm(font);

        if (fm.horizontalAdvance(text) <= maxWidth)
            return size;
    }

    return minSize;
}

QString PlaylistManager::fullImagePath(const QString& playlistName) const
{
    QString relative = playlistImages.value(playlistName);
    if (relative.isEmpty())
        return QString();
    return playlistPath + relative;
}