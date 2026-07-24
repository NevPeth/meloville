#include "mainwindow.h"
#include "metadatareader.h"
#include "playlistmanager.h"
#include "libraryscanner.h"
#include <QFileDialog>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QFileInfo>
#include <QRandomGenerator>
#include <algorithm>

MainWindow::MainWindow(QObject *parent)
    : QObject(parent)
{
    appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    songModel = new SongModel(this);
    playlistManager = new PlaylistManager(this);

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
    
    QDir().mkpath(appDataPath + "/cache");
    
    loadLibrary();
}

MainWindow::~MainWindow()
{
    delete playlistManager;
}

bool MainWindow::songTitleLess(const SongData &a, const SongData &b)
{
    return QString::compare(a.title, b.title, Qt::CaseInsensitive) < 0;
}

void MainWindow::openFolder()
{
    QString folder = QFileDialog::getExistingDirectory(nullptr, "Open Music Folder", "");
    if (folder.isEmpty()) return;

    if (scanning) {
        // Already scanning, ignore new request
        return;
    }

    // Create thread and worker
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
    library = songs;   // already sorted

    // Build view indices
    currentViewSongs.clear();
    for (int i = 0; i < library.size(); ++i) {
        currentViewSongs.push_back(i);
    }
    visibleSongs = currentViewSongs;
    currentPlaybackSongs = currentViewSongs;

    // Update model
    songModel->setSongs(&library, &visibleSongs);

    // Save library
    saveLibrary();

    // Reload playlists (if needed)
    playlistManager->loadPlaylists(library, false);

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

void MainWindow::saveLibrary()
{
    QJsonArray arr;
    for (const SongData &song : library) {
        QJsonObject obj;
        obj["filePath"] = song.filePath;
        obj["title"] = song.title;
        obj["artist"] = song.artist;
        obj["album"] = song.album;
        obj["genre"] = song.genre;
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
        s.title = obj["title"].toString();
        s.artist = obj["artist"].toString();
        s.album = obj["album"].toString();
        s.genre = obj["genre"].toString();
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
        QStringList filters = {"*.mp3", "*.flac", "*.wav", "*.m4a", "*.aac", "*.ogg"};
        QFileInfoList files = dir.entryInfoList(filters, QDir::Files);

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
            song.coverPath = MetadataReader::cacheCoverArt(song.filePath, appDataPath + "/cache", fileInfo.baseName());
            
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
                MetadataReader::removeCachedCoverArt(appDataPath + "/cache", fileInfo.baseName());
                removedAny = true;
            }
        }
        
        if (removedAny) {
            library = std::move(keptSongs);
        }
    }

    currentViewSongs.clear();
    for (int i = 0; i < library.size(); i++) {
        currentViewSongs.push_back(i);
    }
    
    visibleSongs = currentViewSongs;
    currentPlaybackSongs = currentViewSongs;
    songModel->setSongs(&library, &visibleSongs);

    if (addedAny || removedAny) {
        saveLibrary();
    }
}

void MainWindow::loadPlaylistView(const QString &playlistName)
{
    viewingPlaylist = playlistName;
    // Implementation would load the playlist view
}

void MainWindow::playSongAtVisibleIndex(int visibleIndex)
{
    if (visibleIndex < 0 || visibleIndex >= visibleSongs.size())
        return;

    int libraryIndex = visibleSongs[visibleIndex];
    currentPlaybackSongs = currentViewSongs; // or whatever you need
    currentVisibleIndex = visibleIndex;
    currentLibraryIndex = libraryIndex;
    emit currentLibraryIndexChanged();

    // Update model's playing index (if your SongModel supports it)
    // songModel->setPlayingIndex(libraryIndex);

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
    currentPlaybackIndex =
        currentPlaybackSongs.indexOf(
            libraryIndex
        );

    songModel->setPlayingIndex(libraryIndex); 
    currentLibraryIndex = libraryIndex;
    emit currentLibraryIndexChanged();
    emit currentSongChanged();
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

        playSong(previousLibraryIndex);
        return;
    }

    if (!shuffleMode){

        nextUp.push(currentLibraryIndex);

        int previousPlaybackIndex = currentPlaybackIndex - 1;

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

void MainWindow::seekTo(qint64 positionMs){ playbackController->player()->setPosition(positionMs); }

void MainWindow::rebuildShufflePool()
{
    if (shuffleMode)
    {
        unplayedIndices.clear();

        for (int libraryIndex : currentPlaybackSongs)
        {
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

    if (shuffleMode)
        rebuildShufflePool();
}

void MainWindow::toggleRepeat(){
    repeatMode = !repeatMode;
    emit repeatModeChanged();
}

int MainWindow::getVolume() const
{
    return playbackController->volume();
}

void MainWindow::setVolume(int vol)
{
    playbackController->setVolume(vol);
    // volumeChanged will be emitted from playbackController, which will trigger our signal.
}

void MainWindow::setPlaying(bool p)
{
    if (playing != p) {
        playing = p;
        emit playingChanged(playing);
    }
}

void MainWindow::filterSongsAndAlbums(const QString& text)
{
    QString search = text.trimmed().toLower();

    // if(inAlbumsView){
    //     if (search.isEmpty()) {
    //         albumModel->setAlbums(allAlbums);
    //     } else {
    //         QVector<AlbumInfo> filtered;
    //         for (const AlbumInfo& album : allAlbums) {
    //             QString searchable = (album.title + " " + album.artist).toLower();
    //             if (searchable.contains(search)) {
    //                 filtered.push_back(album);
    //             }
    //         }
    //         albumModel->setAlbums(filtered);
    //     }

    //     ui->listViewAlbums->refreshGrid();
    // }
    // else{
        visibleSongs.clear();

        if (search.isEmpty()){
            visibleSongs = currentViewSongs;
        }
        else{
            for (int libraryIndex : currentViewSongs){
                const SongData& song = library[libraryIndex];

                QString searchable = (song.title+" "+song.artist+" " +song.album).toLower();

                if (searchable.contains(search)){
                    visibleSongs.push_back(
                        libraryIndex
                    );
                }
            }
        }
        songModel->setSongs(
            &library,
            &visibleSongs
        );

   // }
}