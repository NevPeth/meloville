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
#include <algorithm>

MainWindow::MainWindow(QObject *parent)
    : QObject(parent)
{
    m_appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    m_songModel = new SongModel(this);
    m_playlistManager = new PlaylistManager(this);
    
    QDir().mkpath(m_appDataPath + "/cache");
    
    loadLibrary();
}

MainWindow::~MainWindow()
{
    delete m_playlistManager;
}

bool MainWindow::songTitleLess(const SongData &a, const SongData &b)
{
    return QString::compare(a.title, b.title, Qt::CaseInsensitive) < 0;
}

void MainWindow::openFolder()
{
    QString folder = QFileDialog::getExistingDirectory(nullptr, "Open Music Folder", "");
    if (folder.isEmpty()) return;

    if (m_scanning) {
        // Already scanning, ignore new request
        return;
    }

    // Create thread and worker
    m_scannerThread = new QThread(this);
    LibraryScanner *scanner = new LibraryScanner();
    scanner->setFolderPath(folder);
    scanner->setCacheDir(m_appDataPath + "/cache");

    // Move to thread
    scanner->moveToThread(m_scannerThread);

    // Connect signals
    connect(scanner, &LibraryScanner::progress, this, &MainWindow::onScanProgress);
    connect(scanner, &LibraryScanner::finished, this, &MainWindow::onScanFinished);
    connect(scanner, &LibraryScanner::error, this, &MainWindow::onScanError);

    // Cleanup
    connect(m_scannerThread, &QThread::finished, scanner, &QObject::deleteLater);
    connect(m_scannerThread, &QThread::finished, this, [this]() {
        m_scannerThread->deleteLater();
        m_scannerThread = nullptr;
    });

    // Start
    m_scanning = true;
    emit scanningChanged();
    m_progress = 0.0;
    emit progressChanged();
    m_statusMessage = tr("Starting scan...");
    emit statusMessageChanged();

    m_scannerThread->start();
    QMetaObject::invokeMethod(scanner, "start", Qt::QueuedConnection);
}

void MainWindow::onScanProgress(int current, int total)
{
    m_progress = static_cast<double>(current) / total;
    emit progressChanged();
    m_statusMessage = tr("Scanning song %1 of %2").arg(current).arg(total);
    emit statusMessageChanged();
}

void MainWindow::onScanFinished(const QVector<SongData>& songs, const QString& folderPath)
{
    m_currentMusicFolder = folderPath;
    m_library = songs;   // already sorted

    // Build view indices
    m_currentViewSongs.clear();
    for (int i = 0; i < m_library.size(); ++i) {
        m_currentViewSongs.push_back(i);
    }
    m_visibleSongs = m_currentViewSongs;
    m_currentPlaybackSongs = m_currentViewSongs;

    // Update model
    m_songModel->setSongs(&m_library, &m_visibleSongs);

    // Save library
    saveLibrary();

    // Reload playlists (if needed)
    m_playlistManager->loadPlaylists(m_library, false);

    // Switch UI state
    m_scanning = false;
    emit scanningChanged();
    emit libraryLoaded();   // triggers QML page switch

    // Stop thread (will auto-delete via connections)
    if (m_scannerThread) {
        m_scannerThread->quit();
    }
}

void MainWindow::onScanError(const QString& message)
{
    // Handle error (show message, reset state)
    m_scanning = false;
    emit scanningChanged();
    m_statusMessage = tr("Error: %1").arg(message);
    emit statusMessageChanged();
    if (m_scannerThread) {
        m_scannerThread->quit();
    }
}

// void MainWindow::openFolder()
// {
//     QString folder = QFileDialog::getExistingDirectory(nullptr, "Open Music Folder", "");
//     if (folder.isEmpty()) return;

//     m_currentMusicFolder = folder;

//     QDir dir(folder);
//     QStringList filters = {"*.mp3", "*.flac", "*.wav", "*.m4a", "*.aac", "*.ogg"};
//     QFileInfoList files = dir.entryInfoList(filters, QDir::Files);
//     m_library.clear();
//     m_currentViewSongs.clear();
    
//     for (const QFileInfo &file : files) {
//         SongData song = MetadataReader::readSong(file.absoluteFilePath());
//         song.coverPath = MetadataReader::cacheCoverArt(song.filePath, m_appDataPath + "/cache", file.baseName());
//         m_library.append(song);
//     }

//     std::sort(m_library.begin(), m_library.end(), songTitleLess);
//     saveLibrary();

//     m_playlistManager->loadPlaylists(m_library, false);
    
//     for (int i = 0; i < m_library.size(); i++) {
//         m_currentViewSongs.push_back(i);
//     }
    
//     m_visibleSongs = m_currentViewSongs;
//     m_currentPlaybackSongs = m_currentViewSongs;
//     m_songModel->setSongs(&m_library, &m_visibleSongs);
    
//     if (m_playlistIsInView) {
//         loadPlaylistView(m_viewingPlaylist);
//     }
    
//     emit libraryLoaded();
// }

void MainWindow::saveLibrary()
{
    QJsonArray arr;
    for (const SongData &song : m_library) {
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
    root["musicFolder"] = m_currentMusicFolder;
    root["songs"] = arr;

    QJsonDocument doc(root);
    QFile file(m_appDataPath + "/library.json");
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson());
        file.close();
    }
}

void MainWindow::loadLibrary()
{
    QFile file(m_appDataPath + "/library.json");
    if (!file.exists()) return;
    if (!file.open(QIODevice::ReadOnly)) return;
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    QJsonObject root = doc.object();
    m_currentMusicFolder = root["musicFolder"].toString();

    QJsonArray arr = root["songs"].toArray();

    m_library.clear();
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
        m_library.append(s);
    }

    // Rescan-on-load logic
    bool addedAny = false;
    bool removedAny = false;
    
    if (!m_currentMusicFolder.isEmpty()) {
        QDir dir(m_currentMusicFolder);
        QStringList filters = {"*.mp3", "*.flac", "*.wav", "*.m4a", "*.aac", "*.ogg"};
        QFileInfoList files = dir.entryInfoList(filters, QDir::Files);

        QSet<QString> existingPaths;
        for (const SongData &song : m_library) {
            existingPaths.insert(song.filePath);
        }

        // Addition pass
        QSet<QString> diskPaths;
        for (const QFileInfo &fileInfo : files) {
            QString absPath = fileInfo.absoluteFilePath();
            diskPaths.insert(absPath);
            if (existingPaths.contains(absPath)) continue;

            SongData song = MetadataReader::readSong(absPath);
            song.coverPath = MetadataReader::cacheCoverArt(song.filePath, m_appDataPath + "/cache", fileInfo.baseName());
            
            auto pos = std::lower_bound(m_library.begin(), m_library.end(), song, songTitleLess);
            m_library.insert(pos, song);
            addedAny = true;
        }

        // Removal pass
        QVector<SongData> keptSongs;
        keptSongs.reserve(m_library.size());
        for (const SongData &song : m_library) {
            if (diskPaths.contains(song.filePath)) {
                keptSongs.append(song);
            } else {
                QFileInfo fileInfo(song.filePath);
                MetadataReader::removeCachedCoverArt(m_appDataPath + "/cache", fileInfo.baseName());
                removedAny = true;
            }
        }
        
        if (removedAny) {
            m_library = std::move(keptSongs);
        }
    }

    m_currentViewSongs.clear();
    for (int i = 0; i < m_library.size(); i++) {
        m_currentViewSongs.push_back(i);
    }
    
    m_visibleSongs = m_currentViewSongs;
    m_currentPlaybackSongs = m_currentViewSongs;
    m_songModel->setSongs(&m_library, &m_visibleSongs);

    if (addedAny || removedAny) {
        saveLibrary();
    }
    
    emit libraryLoaded();
}

void MainWindow::loadPlaylistView(const QString &playlistName)
{
    m_viewingPlaylist = playlistName;
    // Implementation would load the playlist view
}