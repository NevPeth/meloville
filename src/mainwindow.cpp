#include "mainwindow.h"
#include "metadatareader.h"
#include "playlistmanager.h"
#include "libraryscanner.h"
#include "albuminfo.h"
#include "albumlistmodel.h"
#include "mprisadapter.h"
#include "listenalongserver.h"
#include "lastfmscrobbler.h"
#include "listenbrainzscrobbler.h"
#include <QFileDialog>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QTimer>
#include <QSettings>
#include <algorithm>


MainWindow::MainWindow(QObject *parent)
    : QObject(parent)
{
    //Standard path for storing data for programs. On linux these files can be found at .local/share/Meloville
    appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    songModel = new SongModel(this); //This is the model for managing how the songs actually look like in the listViewSongs located in the qml
    // Manages all playlist logic that can be abstracted away from the mainwindow (although a lot of calls
    // are directly tied into mainwindow, it can be helped but it's a pain and the existing architecture works
    // well enough. But if you just want low hanging fruit you can go do that. It's just busy work.)
    playlistManager = new PlaylistManager(this); 
    albumModel = new AlbumListModel(this);

    connect(playlistManager, &PlaylistManager::playlistChanged,
            this, &MainWindow::updatePlaylistNames);

    // The playback controller controls all audio playback that actually gets sent to the user
    playbackController = new PlaybackController(this);
    connect(playbackController, &PlaybackController::songFinished,
            this, &MainWindow::playNextSong);

    connect(playbackController, &PlaybackController::positionChanged,
            this, [this](qint64 pos) {
                playerPosition = pos;
                emit playerPositionChanged(pos);
            });

    connect(playbackController, &PlaybackController::durationChanged,
            this, [this](qint64 dur) {
                playerDuration = dur;
                emit playerDurationChanged(dur);
            });

    connect(playbackController, &PlaybackController::playbackStateChanged,
            this, [this](QMediaPlayer::PlaybackState state) {
                emit playbackStateChanged(static_cast<int>(state));
            });

    connect(playbackController, &PlaybackController::volumeChanged,
        this, &MainWindow::volumeChanged);

    connect(
        playbackController,
        &PlaybackController::audioOutputDeviceChanged,
        this,
        [this]() {
            songModel->setPausedState(true);
            setPlaying(false);
        }
    );

    //Sets up bluetooth headphone media controls and gives the system knowledge of currently playing song
    mpris = new MprisAdapter(this);
    connect(mpris->getPlayer(), &MprisPlayerAdaptor::nextRequested, this, &MainWindow::playNextSong);
    connect(mpris->getPlayer(), &MprisPlayerAdaptor::previousRequested, this, &MainWindow::playPreviousSong);
    connect(mpris->getPlayer(), &MprisPlayerAdaptor::playPauseRequested, this, &MainWindow::playAndPause);

    connect(this, &MainWindow::currentSongChanged, this, [this]() {
        if (currentLibraryIndex < 0 || currentLibraryIndex >= library.size())
            return;

        const SongData &song = library[currentLibraryIndex];

        QVariantMap md;
        md["mpris:trackid"] = QVariant::fromValue(
            QDBusObjectPath("/org/meloville/track/" + QString::number(currentLibraryIndex))
        );
        md["mpris:length"]  = static_cast<qint64>(song.duration) * 1000000LL;
        md["xesam:title"]   = song.title;
        md["xesam:artist"]  = QStringList{ song.artist };
        md["xesam:album"]   = song.album;
        if (!song.coverPath.isEmpty())
            md["mpris:artUrl"] = QUrl::fromLocalFile(song.coverPath).toString();

        mpris->getPlayer()->setMetadata(md);
    });

    connect(playbackController, &PlaybackController::positionChanged,
        this, [this](qint64 pos) {
            mpris->getPlayer()->setPosition(pos);
        });

    connect(mpris->getPlayer(), &MprisPlayerAdaptor::seekRequested,
        this, [this](qint64 positionMs) {
            seekTo(positionMs);
        });

    connect(this, &MainWindow::playingChanged, this, [this](bool isPlaying) {
        mpris->getPlayer()->setPlaybackStatus(isPlaying ? "Playing" : "Paused");
    });

    connect(mpris->getPlayer(), &MprisPlayerAdaptor::shuffleRequested,
        this, [this](bool enabled) {
            if (enabled != shuffleMode)
                toggleShuffle();
        });

    connect(mpris->getPlayer(), &MprisPlayerAdaptor::repeatRequested,
            this, [this](bool enabled) {
                if (enabled != repeatMode)
                    toggleRepeat();
            });

    connect(this, &MainWindow::shuffleModeChanged, this, [this]() {
        mpris->getPlayer()->updateShuffle(shuffleMode);
    });

    connect(this, &MainWindow::repeatModeChanged, this, [this]() {
        mpris->getPlayer()->updateLoopStatus(repeatMode);
    });
    
    // makes cache folder in .local/share/Meloville (on Linux)
    QDir().mkpath(appDataPath + "/cache");
    
    loadLibrary();
    playlistManager->setPath(appDataPath);
    playlistManager->loadPlaylists(library, true);
    updatePlaylistNames();
    playlistModel = new PlaylistModel(playlistManager, this);
    // Scrobble logic
    lFmScrobbler = new LastFmScrobbler("e990f4f5655cd2f176e831ffe87ee9d8", "e9fff39f6b35f42e6fa887c7f947883d", this);

    connect(lFmScrobbler, &LastFmScrobbler::errorOccurred,
    this, [this](const QString &msg) {
        emit scrobblingError(msg);
    });

    if (!lFmScrobbler->isAuthenticated()) {
        lFmScrobbler->authenticate();
    }

    connect(lFmScrobbler, &LastFmScrobbler::authenticationComplete,
        this, [this](bool, const QString &) {
        emit scrobblingAuthChanged();
    });

    lbzScrobbler = new ListenBrainzScrobbler(this);

    connect(lbzScrobbler, &ListenBrainzScrobbler::authChanged,
            this, [this]() { emit lbzAuthChanged(); });

    connect(lbzScrobbler, &ListenBrainzScrobbler::errorOccurred,
            this, [this](const QString &msg) { emit scrobblingError(msg); });

    loadSessionState();

    // There is an option to set a server on Meloville to listen along, be reassured that
    // until listenAlongServer->start is called, there is no connection to the internet whatsoever
    listenAlongServer = new ListenAlongServer(this);

    connect(listenAlongServer, &ListenAlongServer::candidateUrlsReady,
            this, &MainWindow::listenAlongUrlsReady);

    connect(listenAlongServer, &ListenAlongServer::sessionStopped,
            this, &MainWindow::listenAlongStopped);

    connect(listenAlongServer, &ListenAlongServer::listenerCountChanged,
            this, &MainWindow::listenAlongListenerCountChanged);

    connect(playbackController, &PlaybackController::positionChanged,
        this, [this](qint64 pos) {
            if (listenAlongServer->isRunning())
                listenAlongServer->syncPlaybackPosition(pos);
        });

    connect(playbackController, &PlaybackController::playbackStateChanged,
        this, [this](QMediaPlayer::PlaybackState state) {
            if (listenAlongServer->isRunning())
                listenAlongServer->setPaused(state != QMediaPlayer::PlayingState);
        });
}

MainWindow::~MainWindow()
{
}

// Simply a helper function to compare two strings to more easily do sorting by title
bool MainWindow::songTitleLess(const SongData &a, const SongData &b)
{
    return QString::compare(a.title, b.title, Qt::CaseInsensitive) < 0;
}

void MainWindow::openFolder()
{
    QString folder = QFileDialog::getExistingDirectory(nullptr, "Open Music Folder", "");
    if (folder.isEmpty()) return;
    if (scanning) return;

    // Create a new thread and worker to scan library so the main thread can still update UI
    scannerThread = new QThread(this);
    LibraryScanner *scanner = new LibraryScanner();
    scanner->setFolderPath(folder);
    scanner->setCacheDir(appDataPath + "/cache");

    // Move to thread
    scanner->moveToThread(scannerThread);

    // Connect signals
    connect(scanner, &LibraryScanner::progress, this, &MainWindow::onScanProgress);
    connect(scanner, &LibraryScanner::finished, this, &MainWindow::onScanFinished);
    connect(scanner, &LibraryScanner::error, this, &MainWindow::onScanError);

    // Cleanup
    connect(scannerThread, &QThread::finished, scanner, &QObject::deleteLater);
    connect(scannerThread, &QThread::finished, this, [this]() {
        scannerThread->deleteLater();
        scannerThread = nullptr;
    });

    // Start
    scanning = true;
    emit scanningChanged();
    progress = 0.0;
    emit progressChanged();
    statusMessage = tr("Starting scan...");
    emit statusMessageChanged();

    scannerThread->start();
    QMetaObject::invokeMethod(scanner, "start", Qt::QueuedConnection);
}

// Simply helps display scanning progress
void MainWindow::onScanProgress(int current, int total)
{
    progress = static_cast<double>(current) / total;
    emit progressChanged();
    statusMessage = tr("Scanning song %1 of %2").arg(current).arg(total);
    emit statusMessageChanged();
}

void MainWindow::onScanFinished(const QVector<SongData>& songs, const QString& folderPath)
{
    currentMusicFolder = folderPath;
    library = songs; // already sorted

    // Build view indices
    currentViewSongs.clear();
    for (int i = 0; i < library.size(); ++i) {
        currentViewSongs.push_back(i);
    }
    visibleSongs = currentViewSongs;
    currentPlaybackSongs = currentViewSongs;
    rebuildPlaybackMap();

    // Important note: visibleSongs is always directly tied to songModel (which means visibleSongs==songs visible to User)
    songModel->setSongs(&library, &visibleSongs);

    saveLibrary();

    // Reload playlists
    playlistManager->loadPlaylists(library, false);

    //Load categorize albums (instead of saving them, just load them)
    allAlbums = buildAlbumList();
    albumModel->setAlbums(allAlbums);

    // Switch UI state
    scanning = false;
    emit scanningChanged();
    emit libraryLoaded();   // triggers QML page switch

    // Stop thread (will auto-delete via connections)
    if (scannerThread) {
        scannerThread->quit();
    }
}

void MainWindow::onScanError(const QString& message)
{
    // Handle error (show message, reset state)
    scanning = false;
    emit scanningChanged();
    statusMessage = tr("Error: %1").arg(message);
    emit statusMessageChanged();
    if (scannerThread) {
        scannerThread->quit();
    }
}

// Saves library in .local/share/Meloville/library.json
void MainWindow::saveLibrary()
{
    QJsonArray arr;
    for (const SongData &song : library) {
        QJsonObject obj;
        obj["filePath"] = song.filePath;
        obj["lyricsPath"] = song.lyricsPath;
        obj["title"] = song.title;
        obj["artist"] = song.artist;
        obj["album"] = song.album;
        obj["coverPath"] = song.coverPath;
        obj["duration"] = song.duration;
        obj["trackNumber"] = song.trackNumber;
        arr.append(obj);
    }

    QJsonObject root;
    root["musicFolder"] = currentMusicFolder;
    root["songs"] = arr;

    QJsonDocument doc(root);
    QFile file(appDataPath + "/library.json");
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson());
        file.close();
    }
}

/*
Loads library but there are a lot of things to consider.
    - Did user add new songs?
        - Did you sort them properly in the list?
    - Did the user remove a song?
        - Did you remove it from the library put the rest of the songs back?
    - Did the user add new lyrics files?
    - Did the user remove lyrics files?
*/ 
void MainWindow::loadLibrary()
{
    QFile file(appDataPath + "/library.json");
    if (!file.exists()) return;
    if (!file.open(QIODevice::ReadOnly)) return;

    libraryPresent = true;
    emit libraryPresentChanged();
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    QJsonObject root = doc.object();
    currentMusicFolder = root["musicFolder"].toString();

    QJsonArray arr = root["songs"].toArray();

    library.clear();
    for (const QJsonValue &val : arr) {
        QJsonObject obj = val.toObject();
        SongData s;
        s.filePath = obj["filePath"].toString();
        s.lyricsPath = obj["lyricsPath"].toString();
        s.title = obj["title"].toString();
        s.artist = obj["artist"].toString();
        s.album = obj["album"].toString();
        s.coverPath = obj["coverPath"].toString();
        s.duration = obj["duration"].toInt();
        s.trackNumber = obj["trackNumber"].toInt();
        library.append(s);
    }

    // Rescan-on-load logic
    bool addedAny = false;
    bool removedAny = false;
    
    if (!currentMusicFolder.isEmpty()) {
        QDir dir(currentMusicFolder);
        static const QStringList filters = {"*.mp3", "*.flac", "*.wav", "*.m4a", "*.aac", "*.ogg", "*.opus"};

        // This recursively goes through all subdirectories to scan for music files
        std::function<QFileInfoList(const QString &)> collectFiles;
        collectFiles = [&](const QString &dirPath) -> QFileInfoList {
            QFileInfoList result;
            QDir d(dirPath);
            result += d.entryInfoList(filters, QDir::Files);
            const QFileInfoList subdirs = d.entryInfoList(
                QDir::Dirs | QDir::NoDotAndDotDot | QDir::NoSymLinks //No sym links avoids infinite loops in case of circular links
            );
            for (const QFileInfo &sub : subdirs)
                result += collectFiles(sub.absoluteFilePath());
            return result;
        };

        QFileInfoList files = collectFiles(currentMusicFolder);

        QSet<QString> existingPaths;
        for (const SongData &song : library) {
            existingPaths.insert(song.filePath);
        }

        // Addition pass
        QSet<QString> diskPaths;
        for (const QFileInfo &fileInfo : files) {
            QString absPath = fileInfo.absoluteFilePath();
            diskPaths.insert(absPath);
            if (existingPaths.contains(absPath)) continue;

            SongData song = MetadataReader::readSong(absPath);
            song.coverPath = MetadataReader::cacheCoverArt(song.filePath, appDataPath + "/cache", MetadataReader::cacheKeyForPath(song.filePath));
            song.lyricsPath = MetadataReader::findLrcFile(fileInfo.absolutePath(), fileInfo.completeBaseName(), currentMusicFolder);
            
            auto pos = std::lower_bound(library.begin(), library.end(), song, songTitleLess);
            library.insert(pos, song);
            addedAny = true;
        }

        // Removal pass
        QVector<SongData> keptSongs;
        keptSongs.reserve(library.size());
        for (const SongData &song : library) {
            if (diskPaths.contains(song.filePath)) {
                keptSongs.append(song);
            } else {
                QFileInfo fileInfo(song.filePath);
                MetadataReader::removeCachedCoverArt(appDataPath + "/cache", MetadataReader::cacheKeyForPath(song.filePath));
                removedAny = true;
            }
        }
        
        if (removedAny) {
            library = std::move(keptSongs);
        }
    }

    // Double checks for missing lyrics files
    bool addedLyrics = false;
    for (SongData &song : library) {
        QFileInfo fi(song.filePath);
        QString previousLyricsPath = song.lyricsPath;
        song.lyricsPath = MetadataReader::findLrcFile(fi.absolutePath(), fi.completeBaseName(), currentMusicFolder);
        if (song.lyricsPath != previousLyricsPath) {
            addedLyrics = true;
        }
    }

    currentViewSongs.clear();
    for (int i = 0; i < library.size(); i++) {
        currentViewSongs.push_back(i);
    }
    
    visibleSongs = currentViewSongs;
    currentPlaybackSongs = currentViewSongs;
    rebuildPlaybackMap();
    songModel->setSongs(&library, &visibleSongs);

    allAlbums = buildAlbumList();
    albumModel->setAlbums(allAlbums);

    if (addedAny || removedAny || addedLyrics) {
        saveLibrary();
    }
}

void MainWindow::playSongAtVisibleIndex(int visibleIndex)
{
    if (visibleIndex < 0 || visibleIndex >= visibleSongs.size())
        return;

    int libraryIndex = visibleSongs[visibleIndex];
    currentPlaybackSongs = currentViewSongs;
    rebuildPlaybackMap();
    currentVisibleIndex = visibleIndex;
    currentLibraryIndex = libraryIndex;
    emit currentLibraryIndexChanged();

    if (isInPlaylistView) {
        currentlyPlayingPlaylist = viewingPlaylist;
        if (playlistRenewal)
            playlistManager->changePlaylistToTop(viewingPlaylist);
        currentlyPlayingAlbum.clear();
        currentlyPlayingAlbumArtist.clear();
        currentlyPlayingAlbumCoverPath.clear();
    } else if (isInAlbumView) {
        currentlyPlayingAlbum = viewingAlbum;
        currentlyPlayingAlbumArtist  = viewingAlbumArtist;
        currentlyPlayingAlbumCoverPath = viewingAlbumCoverPath;
        currentlyPlayingPlaylist.clear();
    } else {
        currentlyPlayingPlaylist.clear();
        currentlyPlayingAlbum.clear();
        currentlyPlayingAlbumArtist.clear();
        currentlyPlayingAlbumCoverPath.clear();
    }
    
    while (!playHistory.isEmpty())
        playHistory.pop_back();

    while (!nextUp.isEmpty())
        nextUp.pop();

    rebuildShufflePool();

    playSong(libraryIndex);
}

void MainWindow::playSong(int libraryIndex)
{
    if (libraryIndex < 0 || libraryIndex >= library.size())
        return;

    const SongData &song = library[libraryIndex];
    playbackController->player()->setSource(QUrl::fromLocalFile(song.filePath));
    playbackController->player()->play();
    setPlaying(true);
    currentPlaybackIndex = libraryIndexToPlaybackPos.value(libraryIndex, -1);
    songModel->setPlayingIndex(libraryIndex); 
    currentLibraryIndex = libraryIndex;

    //Server is running, set the playing info
    if (listenAlongServer->isRunning()) {
        listenAlongServer->setNowPlaying(
            song.filePath,
            song.title,
            song.artist,
            song.duration,
            song.coverPath
        );
        listenAlongServer->syncPlaybackPosition(0);
        listenAlongServer->setPaused(false);
    }
    mpris->getPlayer()->emitSeeked(0);
    emit currentLibraryIndexChanged();
    emit currentSongChanged();

    if (lFmScrobbler) {
        lFmScrobbler->notifySongStarted(
            song.title,
            song.artist,
            song.album,
            song.duration
        );
    }
    if (lbzScrobbler) {
        lbzScrobbler->notifySongStarted(
            song.title, song.artist, song.album, song.duration);
    }
}

void MainWindow::rebuildPlaybackMap()
{
    libraryIndexToPlaybackPos.clear();
    libraryIndexToPlaybackPos.reserve(currentPlaybackSongs.size());
    for (int i = 0; i < currentPlaybackSongs.size(); ++i)
        libraryIndexToPlaybackPos.insert(currentPlaybackSongs[i], i);
}

void MainWindow::playNextSong()
{
    if (visibleSongs.isEmpty())
        return;

    if (currentLibraryIndex >= 0){
        playHistory.append(currentLibraryIndex);
    }

    int nextLibraryIndex = currentLibraryIndex;

    if (!repeatMode){
        if (!nextUp.isEmpty()){
            nextLibraryIndex = nextUp.pop();
        }
        else if (shuffleMode){
            if (unplayedIndices.isEmpty()){
                for (int libraryIndex : currentPlaybackSongs){
                    unplayedIndices.append(
                        libraryIndex
                    );
                }
            }

            unplayedIndices.removeAll(currentLibraryIndex);

            int randomIndex =
                QRandomGenerator::global()->bounded(
                    unplayedIndices.size()
                );

            nextLibraryIndex = unplayedIndices[randomIndex];

            unplayedIndices.removeAt(randomIndex);

            currentVisibleIndex =
                visibleSongs.indexOf(
                    nextLibraryIndex
                );
        }
        else{
            int nextPlaybackIndex = currentPlaybackIndex + 1;

            if (nextPlaybackIndex >= currentPlaybackSongs.size()){
                nextPlaybackIndex = 0;
            }
            currentPlaybackIndex = nextPlaybackIndex;

            nextLibraryIndex = currentPlaybackSongs[nextPlaybackIndex];
        }
    }
    playSong(nextLibraryIndex);
}

void MainWindow::playPreviousSong()
{
    if (library.isEmpty())
        return;

    if (playbackController->player()->position() > 5000){
        playbackController->player()->setPosition(0);
        return;
    }

    if (!playHistory.isEmpty()){
        int previousLibraryIndex = playHistory.takeLast();
        nextUp.push(currentLibraryIndex);
        playSong(previousLibraryIndex);
        return;
    }

    if (!shuffleMode){
        int previousPlaybackIndex = currentPlaybackIndex - 1;
        nextUp.push(currentLibraryIndex);
        if (previousPlaybackIndex < 0)
            previousPlaybackIndex = currentPlaybackSongs.size()-1;


        playSong(
            currentPlaybackSongs[
                previousPlaybackIndex
            ]
        );
    }
}

void MainWindow::playAndPause()
{
    if (playbackController->player()->playbackState() == QMediaPlayer::PlayingState) {
        playbackController->player()->pause();
        songModel->setPausedState(true);
        setPlaying(false);
    } else {
        playbackController->player()->play();
        songModel->setPausedState(false);
        setPlaying(true);
    }
}

int MainWindow::getVolume() const{ return playbackController->volume(); }
void MainWindow::setVolume(int vol){ playbackController->setVolume(vol); }

void MainWindow::seekTo(qint64 positionMs){
    playbackController->player()->setPosition(positionMs); 
    mpris->getPlayer()->emitSeeked(positionMs);
}

void MainWindow::rebuildShufflePool()
{
    if (shuffleMode){
        unplayedIndices.clear();

        for (int libraryIndex : currentPlaybackSongs){
            unplayedIndices.append(
                libraryIndex
            );
        }

        unplayedIndices.removeAll(
            currentLibraryIndex
        );
    }
}

void MainWindow::toggleShuffle(){
    shuffleMode = !shuffleMode;
    emit shuffleModeChanged();

    while (!nextUp.isEmpty())
        nextUp.pop();

    rebuildShufflePool();
}

void MainWindow::toggleRepeat(){
    repeatMode = !repeatMode;
    emit repeatModeChanged();
}

void MainWindow::setPlaying(bool p){
    if (playing != p) {
        playing = p;
        emit playingChanged(playing);
    }
}

void MainWindow::filterSongsAndAlbums(const QString& text)
{
    filterText = text.trimmed();
    emit dragReorderAllowedChanged();

    QString search = text.trimmed().toLower();

    if(isInAlbumsGridView){
        if (search.isEmpty()) {
            albumModel->setAlbums(allAlbums);
        } else {
            QVector<AlbumInfo> filtered;
            for (const AlbumInfo& album : allAlbums) {
                QString searchable = (album.title + " " + album.artist).toLower();
                if (searchable.contains(search)) {
                    filtered.push_back(album);
                }
            }
            albumModel->setAlbums(filtered);
        }
    }
    else{
        visibleSongs.clear();

        if (search.isEmpty()){
            visibleSongs = currentViewSongs;
        } else{
            for (int libraryIndex : currentViewSongs){
                const SongData& song = library[libraryIndex];

                QString searchable = (song.title+" "+song.artist+" " +song.album).toLower();

                if (searchable.contains(search))
                    visibleSongs.push_back(libraryIndex);
            }
        }
        songModel->setSongs(
            &library,
            &visibleSongs
        );

   }
}

// Whenever a playlist is pressed this runs
void MainWindow::loadPlaylistView(const QString& playlistName)
{
    isInPlaylistView = true;
    viewingPlaylist = playlistName;
    emit viewingPlaylistChanged();
    emit isInPlaylistViewChanged();

    isInAlbumsGridView = false;
    leaveAlbumView();
    emit albumViewStateChanged();
    
    filterText.clear();
    emit dragReorderAllowedChanged();
    
    QString coverPath = appDataPath + 
        playlistManager->playlistImage(
            playlistName
        );

    QList<int> songs = playlistManager->getPlaylistSongs(playlistName);
    currentViewSongs.clear();
    for (int libraryIndex : songs){
        currentViewSongs.push_back(
            libraryIndex
        );
    }

    visibleSongs = currentViewSongs;

    songModel->setSongs(
        &library,
        &visibleSongs
    );
    rebuildShufflePool();
}

// Whenever btnLibrary is pressed this runs
void MainWindow::returnToLibrary(){
    currentViewSongs.clear();
    viewingPlaylist = QString();
    emit viewingPlaylistChanged();
    isInPlaylistView = false;
    emit isInPlaylistViewChanged();
    filterText.clear();
    emit dragReorderAllowedChanged();

    isInAlbumsGridView = false;
    leaveAlbumView();
    emit albumViewStateChanged();

    for (int i = 0; i < library.size(); i++){
        currentViewSongs.push_back(i);
    }

    visibleSongs = currentViewSongs;

    songModel->setSongs(
        &library,
        &visibleSongs
    );
    rebuildShufflePool();
    emit returnedToLibrary();
}

void MainWindow::openSongContextMenu(int visibleIndex, int x, int y)
{
    if (visibleIndex < 0 || visibleIndex >= visibleSongs.size())
        return;
    
    updatePlaylistNames();
    
    // Ask QML to open the popup with the visible index and position
    emit openContextMenuRequested(visibleIndex, x, y);
}

void MainWindow::addToPlaylist(int visibleIndex, const QString& playlistName)
{
    if (visibleIndex < 0 || visibleIndex >= visibleSongs.size())
        return;
    
    int libraryIndex = visibleSongs[visibleIndex];
    const SongData& song = library[libraryIndex];
    
    playlistManager->addSongToPlaylist(playlistName, libraryIndex, song);
    
    if (playlistName == currentlyPlayingPlaylist)
        currentPlaybackSongs.push_back(libraryIndex);
    if (shuffleMode)
        unplayedIndices.append(libraryIndex);
}

// Used in album making, find the string with smallest len and returns it to be the key
// so a song like "Artist1 feat Artist2" in album "Album1" and "Artist" in "Album1" will
// be in the same album while "Artist2" in "Album1" would still be separate
static QString artistKey(const QString &artist)
{
    QString low = artist.trimmed().toLower();
    // Walk until we hit a non-letter that isn't part of the name itself
    for (int i = 0; i < low.length(); ++i) {
        if (!low[i].isLetter()) {
            return low.left(i).trimmed();
        }
    }
    return low;
}

void MainWindow::saveSongEdits(
    int libraryIndex,
    const QString& title,
    const QString& artist,
    const QString& album,
    int trackNumber,
    const QString& imagePath
)
{
    if (libraryIndex < 0 || libraryIndex >= library.size())
        return;

    const SongData oldSong = library[libraryIndex];
    const QString songFilePath = oldSong.filePath;

    // Cache the new cover image.
    QString selectedImagePath = oldSong.coverPath;

    if (!imagePath.isEmpty()) {
        QString uniqueKey = MetadataReader::cacheKeyForPath(songFilePath);
        MetadataReader::removeCachedCoverArt(appDataPath + "/cache", uniqueKey);
        selectedImagePath = MetadataReader::cacheUserImage(imagePath, appDataPath + "/cache", uniqueKey);
    }

    // Save metadata
    MetadataReader::saveTagsToFile(songFilePath, title, artist, album, trackNumber, selectedImagePath);

    // Construct the finalized SongData.
    SongData newSong = oldSong;
    newSong.title = title;
    newSong.artist = artist;
    newSong.album = album;
    newSong.trackNumber = trackNumber;
    newSong.coverPath = selectedImagePath;

    const bool titleChanged = oldSong.title != title;
    const bool wasCurrentSong = (currentLibraryIndex == libraryIndex);

    int newLibraryIndex = libraryIndex;

    if (titleChanged) {
        const int oldLibraryIndex = libraryIndex;

        library.removeAt(oldLibraryIndex);

        auto pos = std::lower_bound(
            library.begin(),
            library.end(),
            newSong,
            songTitleLess
        );

        newLibraryIndex = std::distance(library.begin(), pos);

        library.insert(pos, newSong);

        // Every stored library index may have shifted.
        auto remapIndex = [oldLibraryIndex, newLibraryIndex](int index) -> int {
            if (index == oldLibraryIndex)
                return newLibraryIndex;

            int shifted =
                (index > oldLibraryIndex)
                    ? index - 1
                    : index;

            if (shifted >= newLibraryIndex)
                shifted++;

            return shifted;
        };

        for (int &index : playHistory) index = remapIndex(index);
        for (int i = 0; i < nextUp.size(); ++i) nextUp[i] = remapIndex(nextUp[i]);
        for (int &index : currentPlaybackSongs) index = remapIndex(index);
        for (int &index : unplayedIndices) index = remapIndex(index);
        for (int &index : currentViewSongs) index = remapIndex(index);

        if (wasCurrentSong) {
            currentLibraryIndex = newLibraryIndex;
            emit currentLibraryIndexChanged();
        }
    } 
    else {
        library[libraryIndex] = newSong;
    }

    playlistManager->editSongFromAllPlaylists(
        libraryIndex,
        title,
        artist,
        selectedImagePath,
        newLibraryIndex
    );

    libraryIndex = newLibraryIndex;

    if (titleChanged)
        playlistManager->loadPlaylists(library, false);

    // After library has been finalized we can rebuild the albums
    allAlbums = buildAlbumList();
    albumModel->setAlbums(allAlbums);

    if (wasCurrentSong)
        emit currentSongChanged();

    // Rebuild the currently visible view.
    if (isInAlbumView) {
        currentViewSongs.clear();

        for (const AlbumInfo &albumInfo : allAlbums) {
            if (albumInfo.title.compare(
                    viewingAlbum,
                    Qt::CaseInsensitive) != 0)
                continue;

            if (artistKey(albumInfo.artist) !=
                artistKey(viewingAlbumArtist))
                continue;

            currentViewSongs = albumInfo.libraryIndices;

            viewingAlbumArtist = albumInfo.artist;
            viewingAlbumCoverPath = albumInfo.coverPath;

            break;
        }

        std::sort(
            currentViewSongs.begin(),
            currentViewSongs.end(),
            [this](int a, int b) {
                return library[a].trackNumber <
                       library[b].trackNumber;
            }
        );

        visibleSongs = currentViewSongs;

        songModel->setSongs( &library, &visibleSongs);

        // Only change playback ordering when playback is coming from
        // this album rather than a playlist.
        if (currentlyPlayingPlaylist.isEmpty() && currentlyPlayingAlbum == viewingAlbum){
            currentPlaybackSongs = currentViewSongs;

            rebuildPlaybackMap();

            if (currentLibraryIndex >= 0) {
                currentPlaybackIndex = libraryIndexToPlaybackPos.value(currentLibraryIndex, -1);
            }

            rebuildShufflePool();
        }

        emit albumViewStateChanged();
    }
    else if (isInAlbumsGridView) {
        filterSongsAndAlbums(filterText);
    }
    else if (isInPlaylistView) {
        visibleSongs = currentViewSongs;
        songModel->setSongs(&library, &visibleSongs);

        if (currentlyPlayingPlaylist == viewingPlaylist) {
            currentPlaybackSongs = currentViewSongs;
            rebuildPlaybackMap();

            if (currentLibraryIndex >= 0) {
                currentPlaybackIndex = libraryIndexToPlaybackPos.value(currentLibraryIndex, -1);
            }

            rebuildShufflePool();
        }
    }
    else {
        visibleSongs = currentViewSongs;

        if (currentlyPlayingPlaylist.isEmpty() && currentlyPlayingAlbum.isEmpty()){
            currentPlaybackSongs = currentViewSongs;
            rebuildPlaybackMap();

            if (currentLibraryIndex >= 0) {
                currentPlaybackIndex = libraryIndexToPlaybackPos.value(currentLibraryIndex, -1);
            }
            rebuildShufflePool();
        }
        songModel->setSongs(&library, &visibleSongs);
        filterSongsAndAlbums(filterText);
    }

    if (currentLibraryIndex >= 0) {
        currentPlaybackIndex = libraryIndexToPlaybackPos.value(currentLibraryIndex, -1);
    }

    songModel->setPlayingIndex(libraryIndex);

    emit songCoverUpdated(currentLibraryIndex, selectedImagePath);
    saveLibrary();
}

void MainWindow::removeFromCurrentPlaylist(int visibleIndex)
{
    if (!isInPlaylistView) return;
    if (visibleIndex < 0 || visibleIndex >= visibleSongs.size()) return;
    
    int libraryIndex = visibleSongs[visibleIndex];
    QTimer::singleShot(0, this, [this, visibleIndex, libraryIndex]() {
        playlistManager->removeSongFromPlaylist(viewingPlaylist, libraryIndex);

        currentViewSongs.removeOne(libraryIndex);
        currentPlaybackSongs.removeOne(libraryIndex);
        unplayedIndices.removeOne(libraryIndex);
        playHistory.removeAll(libraryIndex);
        nextUp.removeOne(libraryIndex);

        rebuildPlaybackMap();

        if (currentLibraryIndex >= 0)
            currentPlaybackIndex = libraryIndexToPlaybackPos.value(currentLibraryIndex, -1);

        songModel->removeRow(visibleIndex);

        updatePlaylistNames();
    });
}

void MainWindow::updatePlaylistNames()
{
    playlistNames = playlistManager->playlistNames();
    emit playlistNamesChanged();
}

void MainWindow::jumpToCurrentSong()
{
    if (currentLibraryIndex < 0)
        return;

    if (!currentlyPlayingPlaylist.isEmpty())
        loadPlaylistView(currentlyPlayingPlaylist);
    else if(!currentlyPlayingAlbum.isEmpty())
        loadAlbumView(currentlyPlayingAlbum, currentlyPlayingAlbumArtist, currentlyPlayingAlbumCoverPath);
    else
        returnToLibrary();

    int visibleIndex = songModel->visibleRowForLibraryIndex(currentLibraryIndex);
    if (visibleIndex < 0)
        return;

    emit jumpToSongIndex(visibleIndex);
}

void MainWindow::reorderPlaylist(int from, int to)
{
    if (!isInPlaylistView || !filterText.isEmpty() || from == to)
        return;

    if (from < 0 || from >= visibleSongs.size() || to < 0 || to >= visibleSongs.size())
        return;

    songModel->moveRow(from, to);

    playlistManager->reorderPlaylist(viewingPlaylist, from, to);
    currentViewSongs = visibleSongs;

    currentPlaybackSongs = currentViewSongs;
    rebuildPlaybackMap();

    if (currentLibraryIndex >= 0)
        currentPlaybackIndex = libraryIndexToPlaybackPos.value(currentLibraryIndex, -1);

    rebuildShufflePool();
}

void MainWindow::editPlaylist(
    const QString& oldName,
    const QString& newName,
    const QString& imagePath
)
{
    QString selectedImagePath = imagePath;
    if (!selectedImagePath.isEmpty()) {
        QString localSource = selectedImagePath;
        if (localSource.startsWith("file://")) {
            localSource = QUrl(localSource).toLocalFile();
        }

        QFileInfo info(localSource);
        if (!info.exists()) {
            selectedImagePath.clear();
        } else {
            QDir().mkpath(appDataPath + "/playlistCovers");
            selectedImagePath = "/playlistCovers/" +
                QUuid::createUuid().toString(QUuid::WithoutBraces) +
                "." + info.suffix();

            QFile::copy(localSource, appDataPath + selectedImagePath);
        }
    }

    playlistManager->editPlaylist(oldName, newName, selectedImagePath);

    if (isInPlaylistView && viewingPlaylist == oldName) {
        loadPlaylistView(newName);
    } else {
        viewingPlaylist = newName;
        emit viewingPlaylistChanged();
    }

    updatePlaylistNames();
    emit playlistChanged();
    emit isInPlaylistViewChanged();
}

void MainWindow::deletePlaylist(const QString& playlistName)
{
    playlistManager->deletePlaylist(playlistName);

    if (isInPlaylistView && viewingPlaylist == playlistName) {
        returnToLibrary();
    } else {
        updatePlaylistNames();
        emit viewingPlaylistChanged();
    }
}

void MainWindow::editCurrentSong(int visibleIndex)
{
    if (visibleIndex < 0 || visibleIndex >= visibleSongs.size())
        return;

    int libraryIndex = visibleSongs[visibleIndex];
    if (libraryIndex < 0 || libraryIndex >= library.size())
        return;

    const SongData& song = library[libraryIndex];

    emit editSongRequested(
        libraryIndex,
        song.filePath,
        song.coverPath,
        song.title,
        song.artist,
        song.album,
        song.trackNumber
    );
}

QVector<AlbumInfo> MainWindow::buildAlbumList() const
{
    // key: (albumTitle.toLower(), artistKey) -> index into result
    QHash<QPair<QString, QString>, int> indexMap;
    QVector<AlbumInfo> result;

    for (int libraryIndex = 0; libraryIndex < library.size(); ++libraryIndex) {
        const SongData &song = library[libraryIndex];

        if (song.album.isEmpty())
            continue;

        QString albumKey = song.album.trimmed().toLower();
        QString artKey = artistKey(song.artist);
        auto key = qMakePair(albumKey, artKey);

        auto it = indexMap.find(key);

        if (it == indexMap.end()) {
            AlbumInfo info;
            info.title = song.album;
            info.artist = song.artist;
            info.coverPath = song.coverPath;
            info.libraryIndices.append(libraryIndex);
            info.songCount = 1;

            indexMap.insert(key, result.size());
            result.append(info);
        } else {
            AlbumInfo &album = result[it.value()];

            album.libraryIndices.append(libraryIndex);
            album.songCount = album.libraryIndices.size();

            // Prefer shorter display name.
            if (song.artist.length() < album.artist.length())
                album.artist = song.artist;

            // Preserve your old behavior of taking the first non-empty cover.
            if (album.coverPath.isEmpty() && !song.coverPath.isEmpty())
                album.coverPath = song.coverPath;
        }
    }

    for (AlbumInfo &album : result)
        album.songCount = album.libraryIndices.size();

    std::sort(
        result.begin(),
        result.end(),
        [](const AlbumInfo &a, const AlbumInfo &b) {
            return QString::compare(
                a.title,
                b.title,
                Qt::CaseInsensitive
            ) < 0;
        }
    );

    return result;
}

void MainWindow::goToAlbums(){
    currentViewSongs.clear();
    viewingPlaylist = QString();
    emit viewingPlaylistChanged();
    isInPlaylistView = false;
    emit isInPlaylistViewChanged();
    filterText.clear();
    emit dragReorderAllowedChanged();

    leaveAlbumView();
    isInAlbumsGridView = true;
    emit albumViewStateChanged();
}

void MainWindow::leaveAlbumView()
{
    isInAlbumView = false;
    viewingAlbum.clear();
    viewingAlbumArtist.clear();
    viewingAlbumCoverPath.clear();
    emit albumViewStateChanged();
}

void MainWindow::loadAlbumView(QString albumName,
                               QString artist,
                               QString coverPath)
{
    if (isInPlaylistView) {
        isInPlaylistView = false;
        viewingPlaylist.clear();
        emit viewingPlaylistChanged();
        emit isInPlaylistViewChanged();
    }

    isInAlbumsGridView = false;

    viewingAlbum = albumName;
    viewingAlbumArtist = artist;
    viewingAlbumCoverPath = coverPath;
    isInAlbumView = true;

    filterText.clear();
    emit dragReorderAllowedChanged();
    emit albumViewStateChanged();

    currentViewSongs.clear();

    // AlbumInfo already contains the library indices.
    for (const AlbumInfo &album : allAlbums) {
        if (album.title.compare(albumName, Qt::CaseInsensitive) != 0)
            continue;

        if (artistKey(album.artist) != artistKey(artist))
            continue;

        currentViewSongs = album.libraryIndices;

        // Use the canonical album metadata.
        viewingAlbumArtist = album.artist;
        viewingAlbumCoverPath = album.coverPath;

        break;
    }

    // AlbumInfo stores library indices, but the album should still
    // be displayed in track-number order.
    std::sort(
        currentViewSongs.begin(),
        currentViewSongs.end(),
        [this](int a, int b) {
            return library[a].trackNumber < library[b].trackNumber;
        }
    );

    visibleSongs = currentViewSongs;

    songModel->setSongs(
        &library,
        &visibleSongs
    );

    rebuildShufflePool();
}

void MainWindow::returnFromAlbumToGrid(){
    leaveAlbumView();
    goToAlbums();
}
void MainWindow::saveWindowGeometry(int x, int y, int w, int h)
{
    QSettings settings("Meloville", "Meloville");
    settings.setValue("window/geometry", QRect(x, y, w, h));
}

QRect MainWindow::loadWindowGeometry() const
{
    QSettings settings("Meloville", "Meloville");
    return settings.value("window/geometry", QRect(100, 100, 1280, 720)).toRect();
}

void MainWindow::saveSessionAndWindow(int x, int y, int w, int h)
{
    saveWindowGeometry(x, y, w, h);
    saveSessionState();
}

void MainWindow::saveSessionState()
{
    QSettings settings("Meloville", "Meloville");

    if (currentLibraryIndex < 0 || currentLibraryIndex >= library.size()) {
        settings.remove("session");
        return;
    }

    const SongData &song = library[currentLibraryIndex];

    settings.setValue("session/position", playbackController->player()->position());
    settings.setValue("session/title", song.title);
    settings.setValue("session/artist", song.artist);
    settings.setValue("session/coverPath", song.coverPath);
    settings.setValue("session/duration", song.duration);
    settings.setValue("session/wasPlaying", playbackController->isPlaying());
    settings.setValue("session/shuffleMode", shuffleMode);
    settings.setValue("session/repeatMode", repeatMode);
    settings.setValue("session/currentlyPlayingPlaylist", currentlyPlayingPlaylist);
    settings.setValue("session/currentlyPlayingAlbum", currentlyPlayingAlbum);
    settings.setValue("session/currentlyPlayingAlbumArtist", currentlyPlayingAlbumArtist);
    settings.setValue("session/currentlyPlayingAlbumCoverPath", currentlyPlayingAlbumCoverPath);
    settings.setValue("ui/delegateHeight", delegateHeight);
    settings.setValue("ui/isCompact", isCompact);
    settings.setValue("ui/playlistRenewal", playlistRenewal);
    settings.setValue("ui/closeToTray", closeToTray);
    settings.setValue("ui/customResizing", customResizing);
    settings.setValue("ui/nativeResizing", nativeResizing);

    QJsonArray playbackArr;
    for (int idx : currentPlaybackSongs) {
        if (idx >= 0 && idx < library.size()) {
            QJsonObject o;
            o["title"]  = library[idx].title;
            o["artist"] = library[idx].artist;
            playbackArr.append(o);
        }
    }
    settings.setValue("session/currentPlaybackSongs", QJsonDocument(playbackArr).toJson(QJsonDocument::Compact));

    QJsonArray historyArr;
    for (int idx : playHistory) {
        if (idx >= 0 && idx < library.size()) {
            QJsonObject o;
            o["title"]  = library[idx].title;
            o["artist"] = library[idx].artist;
            historyArr.append(o);
        }
    }
    settings.setValue("session/playHistory", QJsonDocument(historyArr).toJson(QJsonDocument::Compact));

    QJsonArray nextUpArr;
    for (int i = 0; i < nextUp.size(); ++i) {
        int idx = nextUp[i];
        if (idx >= 0 && idx < library.size()) {
            QJsonObject o;
            o["title"]  = library[idx].title;
            o["artist"] = library[idx].artist;
            nextUpArr.append(o);
        }
    }
    settings.setValue("session/nextUp", QJsonDocument(nextUpArr).toJson(QJsonDocument::Compact));
}

void MainWindow::loadSessionState()
{
    QSettings settings("Meloville", "Meloville");

    delegateHeight = settings.value("ui/delegateHeight", 62.0).toReal();
    isCompact = settings.value("ui/isCompact", false).toBool();
    playlistRenewal = settings.value("ui/playlistRenewal", true).toBool();
    closeToTray = settings.value("ui/closeToTray", false).toBool();
    customResizing = settings.value("ui/customResizing", true).toBool();
    nativeResizing = settings.value("ui/nativeResizing", false).toBool();

    QString savedTitle  = settings.value("session/title",  QString()).toString();
    QString savedArtist = settings.value("session/artist", QString()).toString();
    if (savedTitle.isEmpty())
        return;

    // Binary search for now until I make it constant time, but I just rehashed the logic from my playlist to at least not be O(n*m) and instead O(log(n)*m)
    auto resolveIndex = [&](const QString &title, const QString &artist) -> int {
        int lo = 0, hi = library.size() - 1, found = -1;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            int cmp = QString::compare(library[mid].title, title, Qt::CaseInsensitive);
            if (cmp < 0) lo = mid + 1;
            else if (cmp > 0) hi = mid - 1;
            else {
                for (int i = mid; i >= lo && QString::compare(library[i].title, title, Qt::CaseInsensitive) == 0; --i)
                    if (library[i].artist.compare(artist, Qt::CaseInsensitive) == 0) { found = i; break; }
                if (found < 0)
                    for (int i = mid + 1; i <= hi && QString::compare(library[i].title, title, Qt::CaseInsensitive) == 0; ++i)
                        if (library[i].artist.compare(artist, Qt::CaseInsensitive) == 0) { found = i; break; }
                break;
            }
        }
        return found;
    };

    int libraryIndex = resolveIndex(savedTitle, savedArtist);
    if (libraryIndex < 0)
        return;

    shuffleMode = settings.value("session/shuffleMode", false).toBool();
    repeatMode  = settings.value("session/repeatMode",  false).toBool();
    mpris->getPlayer()->updateShuffle(shuffleMode);
    mpris->getPlayer()->updateLoopStatus(repeatMode);

    currentlyPlayingPlaylist = settings.value("session/currentlyPlayingPlaylist", QString()).toString();
    currentlyPlayingAlbum = settings.value("session/currentlyPlayingAlbum", QString()).toString();
    currentlyPlayingAlbumArtist = settings.value("session/currentlyPlayingAlbumArtist", QString()).toString();
    currentlyPlayingAlbumCoverPath = settings.value("session/currentlyPlayingAlbumCoverPath", QString()).toString();

    auto restoreList = [&](const QString &key) -> QVector<int> {
        QVector<int> result;
        QJsonArray arr = QJsonDocument::fromJson(settings.value(key).toByteArray()).array();
        for (const QJsonValue &v : arr) {
            QJsonObject o = v.toObject();
            int idx = resolveIndex(o["title"].toString(), o["artist"].toString());
            if (idx >= 0)
                result.append(idx);
        }
        return result;
    };

    currentPlaybackSongs = restoreList("session/currentPlaybackSongs");
    if (currentPlaybackSongs.isEmpty())
        for (int i = 0; i < library.size(); ++i)
            currentPlaybackSongs.append(i);

    rebuildPlaybackMap();

    playHistory = restoreList("session/playHistory");

    QVector<int> nextUpVec = restoreList("session/nextUp");
    while (!nextUp.isEmpty()) nextUp.pop();
    for (int idx : nextUpVec)
        nextUp.push(idx);

    const SongData &song = library[libraryIndex];
    playbackController->player()->setSource(QUrl::fromLocalFile(song.filePath));

    currentLibraryIndex  = libraryIndex;
    currentPlaybackIndex = libraryIndexToPlaybackPos.value(libraryIndex, -1);
    songModel->setPlayingIndex(libraryIndex);
    songModel->setPausedState(true);

    emit currentLibraryIndexChanged();
    emit currentSongChanged();

    qint64 savedPos = settings.value("session/position", 0).toLongLong();
    QTimer::singleShot(300, this, [this, savedPos]() {
        playbackController->player()->setPosition(savedPos);
        // After restoring session, notify the scrobbler so it tracks this song.
        if (lFmScrobbler && currentLibraryIndex >= 0 && currentLibraryIndex < library.size()) {
            const SongData &song = library[currentLibraryIndex];
            int remainingSec = song.duration - static_cast<int>(savedPos / 1000);
            if (remainingSec > 0) {
                lFmScrobbler->notifySongStarted(
                    song.title,
                    song.artist,
                    song.album,
                    remainingSec
                );
            }
        }
        if (lbzScrobbler && currentLibraryIndex >= 0 && currentLibraryIndex < library.size()) {
            const SongData &song = library[currentLibraryIndex];
            int remainingSec = song.duration - static_cast<int>(savedPos / 1000);
            if (remainingSec > 0)
                lbzScrobbler->notifySongStarted(song.title, song.artist, song.album, remainingSec);
        }
        emit sessionRestored(savedPos);
    });
}

void MainWindow::startListenAlongServer(int port)
{
    if (!listenAlongServer->start(static_cast<quint16>(port))) {
        emit listenAlongUrlsReady({}); // empty list signals failure to QML
        return;
    }

    // If a song is already loaded, tell the server about it
    if (currentLibraryIndex >= 0 && currentLibraryIndex < library.size()) {
        const SongData &song = library[currentLibraryIndex];
        listenAlongServer->setNowPlaying(
            song.filePath,
            song.title,
            song.artist,
            song.duration,
            song.coverPath
        );
        listenAlongServer->syncPlaybackPosition(playerPosition);
        listenAlongServer->setPaused(!playing);
    }
}

void MainWindow::stopListenAlongServer()
{
    listenAlongServer->stop();
}

bool MainWindow::isListenAlongRunning() const
{
    return listenAlongServer->isRunning();
}

QString MainWindow::readFileAsString(const QString& path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    QTextStream in(&file);
    return in.readAll();
}

void MainWindow::selectMusicFolder()
{
    QString folder = QFileDialog::getExistingDirectory(
        nullptr,
        tr("Select Music Folder"),
        currentMusicFolder.isEmpty() ? QDir::homePath() : currentMusicFolder,
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks
    );

    if (folder.isEmpty())
        return;

    if (scanning)
        return;

    //Clearing all cached images
    QDir cacheDir(appDataPath + "/cache");
    cacheDir.removeRecursively();
    QDir().mkpath(appDataPath + "/cache");

    currentMusicFolder = folder;

    scannerThread = new QThread(this);
    LibraryScanner *scanner = new LibraryScanner();
    scanner->setFolderPath(folder);
    scanner->setCacheDir(appDataPath + "/cache");
    scanner->moveToThread(scannerThread);

    connect(scanner, &LibraryScanner::progress, this, &MainWindow::onScanProgress);
    connect(scanner, &LibraryScanner::error,    this, &MainWindow::onScanError);

    // Custom finish handler for folder-change (not onScanFinished,
    // which replaces the library entirely and switches UI pages)
    connect(scanner, &LibraryScanner::finished, this,
        [this](const QVector<SongData> &scannedSongs, const QString &folderPath)
    {
        // Replace library with the freshly scanned songs
        library = scannedSongs;

        currentViewSongs.clear();
        for (int i = 0; i < library.size(); ++i)
            currentViewSongs.push_back(i);
        visibleSongs = currentViewSongs;
        currentPlaybackSongs = currentViewSongs;
        rebuildPlaybackMap();

        songModel->setSongs(&library, &visibleSongs);
        saveLibrary();

        // Library is fully populated — safe to load playlists now
        playlistManager->loadPlaylists(library, false);
        updatePlaylistNames();

        allAlbums = buildAlbumList();
        albumModel->setAlbums(allAlbums);

        scanning = false;
        emit scanningChanged();
        emit musicFolderChanged(folderPath);

        if (scannerThread)
            scannerThread->quit();

    });

    connect(scannerThread, &QThread::finished, scanner, &QObject::deleteLater);
    connect(scannerThread, &QThread::finished, this, [this]() {
        scannerThread->deleteLater();
        scannerThread = nullptr;
    });

    scanning = true;
    emit scanningChanged();
    progress = 0.0;
    emit progressChanged();
    statusMessage = tr("Starting scan...");
    emit statusMessageChanged();

    scannerThread->start();
    QMetaObject::invokeMethod(scanner, "start", Qt::QueuedConnection);
}

// Setters for settings options, called in Settings.qml
void MainWindow::setDelegateHeight(qreal h){ delegateHeight = h; emit delegateHeightChanged(); }
void MainWindow::setCompactMode(bool compact){ isCompact = compact; emit isCompactChanged(); }
void MainWindow::setPlaylistRenewalMode(bool renewal){ playlistRenewal = renewal; emit playlistRenewalChanged(); }
void MainWindow::setCloseToTray(bool close){ closeToTray = close; emit closeToTrayChanged(); }
void MainWindow::setCustomResizing(bool custom){ customResizing = custom; emit customResizingChanged(); }
void MainWindow::setNativeResizing(bool native){ nativeResizing = native; emit nativeResizingChanged(); }

void MainWindow::scrobblerAuthenticate() {
    if (lFmScrobbler) 
        lFmScrobbler->authenticate();
}
void MainWindow::scrobblerLogout() {
    if (lFmScrobbler) { 
        lFmScrobbler->logout(); 
        emit scrobblingAuthChanged(); 
    }
}

void MainWindow::lbzSetToken(const QString &token)
{
    if (lbzScrobbler)
        lbzScrobbler->setToken(token);
}

void MainWindow::lbzLogout()
{
    if (lbzScrobbler) {
        lbzScrobbler->logout();
        emit lbzAuthChanged();
    }
}