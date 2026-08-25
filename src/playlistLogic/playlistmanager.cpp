#include "playlistmanager.h"
#include "songdata.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QList>
#include <QFont>
#include <QFontMetrics>
#include <QImage>
#include <QPainter>
#include <QUuid>
#include <QDir>
#include <QStandardPaths>
#include <QUrl>
#include <QFileInfo>
#include <QtConcurrent/QtConcurrent>
#include <QFutureWatcher>

PlaylistManager::PlaylistManager(QObject *parent): QObject(parent)
{
    appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

void PlaylistManager::createPlaylist(
    const QString& name,
    const QString& sourceImagePath
)
{
    QDir().mkpath(appDataPath + "/playlistCovers");

    QFileInfo info(sourceImagePath);

    QString imagePath = "";
    if (!sourceImagePath.isEmpty()){
        imagePath = "/playlistCovers/" + QUuid::createUuid().toString(QUuid::WithoutBraces) + "." + info.suffix();
    
        QString localSource = sourceImagePath;
        if (localSource.startsWith("file://"))
            localSource = QUrl(localSource).toLocalFile();

        QFile::copy(localSource, appDataPath + imagePath);
    }

    if (playlists.contains(name))
        return;

    playlists[name] = {};
    playlistDefinitions[name] = {};
    playlistImages[name] = imagePath;
    playlistAutoGenerate[name] = imagePath.isEmpty();
    playlistAutoGenSongs[name] = {}; 

    playlistOrder.prepend(name);

    savePlaylists();
    emit playlistChanged();
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
    playlistSong.coverPath = song.coverPath;

    playlistDefinitions[playlistName].append(playlistSong);

    if (playlistAutoGenerate.value(playlistName)) {
        int newSize = playlistDefinitions[playlistName].size();
        if (newSize == 4)
            updateAutoGenSongs(playlistName);
    }

    savePlaylists();
}

void PlaylistManager::removeSongFromPlaylist(
    const QString& playlistName,
    int libraryIndex)
{
    if (!playlists.contains(playlistName))
        return;

    int index = playlists[playlistName].indexOf(libraryIndex);

    if (index < 0)
        return;

    playlists[playlistName].removeAt(index);
    playlistDefinitions[playlistName].removeAt(index);

    if (playlistAutoGenerate.value(playlistName) && index < 4)
        updateAutoGenSongs(playlistName);

    savePlaylists();
}

void PlaylistManager::editSongFromAllPlaylists(
    int libraryIndex, 
    const QString& newSongTitle, 
    const QString& newArtist, 
    const QString& imagePath
){
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
        playlistSong.coverPath = imagePath;

        if (playlistAutoGenerate.value(playlistName) && index < 4)
            updateAutoGenSongs(playlistName);
    }
    savePlaylists();
}

void PlaylistManager::removeSongFromAllPlaylists(int libraryIndex)
{
    for(const QString& playlistName : playlistOrder)
        removeSongFromPlaylist(playlistName, libraryIndex);
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
        playlistObject["autoGenerate"] = playlistAutoGenerate.value(playlist);
        QJsonArray songs;
        for (const PlaylistSong& song : playlistDefinitions.value(playlist)){
            QJsonObject songObject;

            songObject["title"] = song.title;
            songObject["artist"] = song.artist;
            songObject["coverPath"] = song.coverPath;

            songs.append(songObject);
        }
        playlistObject["songs"] = songs;
        playlistsObject[playlist] = playlistObject;
    }
    root["playlists"] = playlistsObject;

    QFile file(playlistPath+ + "/playlists.json");

    if (!file.open(QIODevice::WriteOnly))
        return;

    file.write( QJsonDocument(root).toJson() );
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
    playlistAutoGenerate.clear();
    playlistAutoGenSongs.clear();

    QHash<QString, int> songLookup;
    songLookup.reserve(library.size());
    for (int i = 0; i < library.size(); ++i) {
        QString key = library[i].title.toLower() + '\t' + library[i].artist.toLower();
        songLookup.insert(key, i);
    }

    QJsonArray orderArray = root["playlistOrder"].toArray();
    QJsonObject playlistsObject = root["playlists"].toObject();

    for (const QJsonValue& value : orderArray)
        playlistOrder.append(value.toString());

    for (const QString& playlist : playlistOrder)
    {
        QJsonObject playlistObject = playlistsObject[playlist].toObject();

        playlistImages[playlist] = playlistObject["image"].toString();
        playlistAutoGenerate[playlist] = playlistObject["autoGenerate"].toBool();

        QList<int> indices;
        QList<PlaylistSong> songs;

        QJsonArray songArray = playlistObject["songs"].toArray();

        for (const QJsonValue& value : songArray){
            QJsonObject obj = value.toObject();

            PlaylistSong playlistSong;
            playlistSong.title = obj["title"].toString();
            playlistSong.artist = obj["artist"].toString();
            playlistSong.coverPath = obj["coverPath"].toString();

            songs.append(playlistSong);

            QString key = playlistSong.title.toLower() + '\t' + playlistSong.artist.toLower();
            int found = songLookup.value(key, -1);

            if (found >= 0)
                indices.append(found);
        }

        playlistDefinitions[playlist] = songs;
        playlists[playlist] = indices;

        if (playlistAutoGenerate.value(playlist) && songs.size() >= 4)
            playlistAutoGenSongs[playlist] = songs.mid(0, 4);
        else
            playlistAutoGenSongs[playlist] = {};

        if (emitSignals)
            emit playlistChanged();
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
        playlistAutoGenerate[newName] = playlistAutoGenerate.take(oldName);
        playlistAutoGenSongs[newName] = playlistAutoGenSongs.take(oldName);

        QString oldImage = playlistImages.take(oldName);
        playlistImages[newName] = oldImage;

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
            playlistImages[newName] = imagePath;
            playlistAutoGenerate[newName] = false;
        }
        changed = true;
    }
    
    if (changed){
        savePlaylists();
        emit playlistChanged();
    }
}

void PlaylistManager::deletePlaylist(
    const QString& playlistName
)
{
    if (!playlists.contains(playlistName))
        return;

    QString cover = playlistImages.value(playlistName);

    if (!cover.isEmpty())
    {
        QFile::remove(playlistPath + cover);
    }

    playlists.remove(playlistName);
    playlistDefinitions.remove(playlistName);
    playlistImages.remove(playlistName);
    playlistOrder.removeAll(playlistName);
    playlistAutoGenerate.remove(playlistName);
    playlistAutoGenSongs.remove(playlistName);

    savePlaylists();
    emit playlistChanged();
}

QString PlaylistManager::fullImagePath(const QString& playlistName) const
{
    QString relative = playlistImages.value(playlistName);
    if (relative.isEmpty())
        return QString();
    return playlistPath + relative;
}

void PlaylistManager::reorderPlaylist(const QString& playlistName, int from, int to)
{
    if (!playlists.contains(playlistName) || from == to)
        return;

    auto &list = playlists[playlistName];
    auto &defs = playlistDefinitions[playlistName];

    if (from < 0 || from >= list.size() || to < 0 || to >= list.size())
        return;

    // Move library index
    int idx = list.takeAt(from);
    list.insert(to, idx);

    // Move corresponding playlist song definition
    PlaylistSong song = defs.takeAt(from);
    defs.insert(to, song);

    if (playlistAutoGenerate.value(playlistName) && (from < 4 || to < 4))
        updateAutoGenSongs(playlistName);

    savePlaylists();
    emit playlistChanged();
}

void PlaylistManager::changePlaylistToTop(const QString& playlistName)
{
    if (playlistOrder[0] == playlistName)
        return;

    playlistOrder.removeAll(playlistName);
    playlistOrder.prepend(playlistName);

    savePlaylists();
    emit playlistChanged();
}

static QString generateCompositeImage(
    const QList<PlaylistSong>& four,
    const QString& appDataPath,
    const QString& oldRelative
)
{
    const int half = 500;
    const int full = half * 2;
    QImage images[4];
    for (int i = 0; i < 4; ++i) {
        if (four[i].coverPath.isEmpty()) return {};
        images[i] = QImage(four[i].coverPath);
        if (images[i].isNull()) return {};
    }

    QImage composite(full, full, QImage::Format_RGB32);
    composite.fill(Qt::black);
    QPainter painter(&composite);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    const QRect rects[4] = {
        QRect(0,    0,    half, half),
        QRect(half, 0,    half, half),
        QRect(0,    half, half, half),
        QRect(half, half, half, half),
    };
    for (int i = 0; i < 4; ++i)
        painter.drawImage(rects[i], images[i]);
    painter.end();

    if (!oldRelative.isEmpty())
        QFile::remove(appDataPath + oldRelative);

    QDir().mkpath(appDataPath + "/playlistCovers");
    QString newRelative = "/playlistCovers/"
        + QUuid::createUuid().toString(QUuid::WithoutBraces)
        + ".png";
    composite.save(appDataPath + newRelative);
    return newRelative;
}

void PlaylistManager::updateAutoGenSongs(const QString& playlistName)
{
    const QList<PlaylistSong>& defs = playlistDefinitions.value(playlistName);

    if (defs.size() < 4) {
        playlistAutoGenSongs[playlistName] = {};
        QString old = playlistImages.value(playlistName);
        if (!old.isEmpty()) {
            QFile::remove(appDataPath + old);
            playlistImages[playlistName] = "";
        }
        return;
    }

    QList<PlaylistSong> four = defs.mid(0, 4);
    QString oldRelative = playlistImages.value(playlistName);

    auto* watcher = new QFutureWatcher<QString>(this);

    connect(watcher, &QFutureWatcher<QString>::finished, this,
        [this, watcher, playlistName, four]() {
            QString newRelative = watcher->result();
            watcher->deleteLater();

            if (newRelative.isEmpty()) {
                playlistAutoGenSongs[playlistName] = {};
                return;
            }

            playlistImages[playlistName]       = newRelative;
            playlistAutoGenSongs[playlistName] = four;
            savePlaylists();
            emit playlistChanged();
        }
    );

    watcher->setFuture(
        QtConcurrent::run(generateCompositeImage, four, appDataPath, oldRelative)
    );
}