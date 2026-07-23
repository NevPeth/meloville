#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include "songdata.h"
#include "songmodel.h"
#include "libraryscanner.h"
#include "playbackcontroller.h"
#include <pulse/pulseaudio.h>
#include <QMainWindow>
#include <QQuickView>
#include <QStackedWidget>
#include <QVector>
#include <QSet>
#include <QThread>
#include <QStack>

class PlaylistManager;

class MainWindow : public QObject
{
    Q_OBJECT
    Q_PROPERTY(SongModel* songModel READ getSongModel CONSTANT)
    Q_PROPERTY(bool playlistIsInView READ getPlaylistIsInView NOTIFY playlistChanged)
    Q_PROPERTY(double progress READ getProgress NOTIFY progressChanged)
    Q_PROPERTY(QString statusMessage READ getStatusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(bool scanning READ getScanning NOTIFY scanningChanged)
    Q_PROPERTY(bool libraryPresent READ getLibraryPresent NOTIFY libraryPresentChanged)
    Q_PROPERTY(int currentPlayingIndex READ getCurrentPlayingIndex NOTIFY currentPlayingIndexChanged)

    Q_PROPERTY(QString currentSongTitle READ getCurrentSongTitle NOTIFY currentSongChanged)
    Q_PROPERTY(QString currentSongArtist READ getCurrentSongArtist NOTIFY currentSongChanged)
    Q_PROPERTY(QString currentSongCoverPath READ getCurrentSongCoverPath NOTIFY currentSongChanged)
    Q_PROPERTY(int currentSongDuration READ getCurrentSongDuration NOTIFY currentSongChanged)
    Q_PROPERTY(qint64 playerPosition READ getPlayerPosition NOTIFY playerPositionChanged)
    Q_PROPERTY(qint64 playerDuration READ getPlayerDuration NOTIFY playerDurationChanged)

public:
    explicit MainWindow(QObject *parent = nullptr);
    ~MainWindow();

    SongModel* getSongModel() const { return songModel; }
    bool getPlaylistIsInView() const { return playlistIsInView; }

    Q_INVOKABLE void openFolder();
    Q_INVOKABLE void saveLibrary();
    Q_INVOKABLE void loadLibrary();
    Q_INVOKABLE void playSongAtVisibleIndex(int visibleIndex);
    Q_INVOKABLE void playAndPause();
    Q_INVOKABLE void playNextSong();
    Q_INVOKABLE void playPreviousSong();
    Q_INVOKABLE void seekTo(qint64 positionMs);

    double getProgress() const { return progress; }
    QString getStatusMessage() const { return statusMessage; }
    bool getScanning() const { return scanning; }
    bool getLibraryPresent() const { return libraryPresent; }
    int getCurrentPlayingIndex() const { return currentPlayingIndex; }
    QString getCurrentSongTitle() const {
        if (currentPlayingIndex < 0 || currentPlayingIndex >= library.size()) return QString();
        return library[currentPlayingIndex].title;
    }
    QString getCurrentSongArtist() const {
        if (currentPlayingIndex < 0 || currentPlayingIndex >= library.size()) return QString();
        return library[currentPlayingIndex].artist;
    }
    QString getCurrentSongCoverPath() const {
        if (currentPlayingIndex < 0 || currentPlayingIndex >= library.size()) return QString();
        return library[currentPlayingIndex].coverPath;
    }
    int getCurrentSongDuration() const {
        if (currentPlayingIndex < 0 || currentPlayingIndex >= library.size()) return 0;
        return library[currentPlayingIndex].duration;
    }
    qint64 getPlayerPosition() const { return playerPosition; }
    qint64 getPlayerDuration() const { return playerDuration; }

public slots:
    void onScanProgress(int current, int total);
    void onScanFinished(const QVector<SongData>& songs, const QString& folderPath);
    void onScanError(const QString& message);

private slots:
    void playSong(int libraryIndex);

signals:
    void playlistChanged();
    void libraryLoaded();
    void progressChanged();
    void statusMessageChanged();
    void scanningChanged();
    void libraryPresentChanged();
    void currentPlayingIndexChanged();
    void currentSongChanged();
    void playerPositionChanged(qint64 position);
    void playerDurationChanged(qint64 duration);
    void playbackStateChanged(int state);

private:
    static bool songTitleLess(const SongData &a, const SongData &b);
    void loadPlaylistView(const QString &playlistName);
    
    QVector<SongData> library;
    QVector<int> currentViewSongs;
    QVector<int> visibleSongs;
    QVector<int> currentPlaybackSongs;
    QString currentMusicFolder;
    QString appDataPath;
    bool playlistIsInView = false;
    QString viewingPlaylist;
    SongModel *songModel = nullptr;
    PlaylistManager *playlistManager = nullptr;
    double progress = 0.0;
    QString statusMessage;
    bool scanning = false;
    QThread *scannerThread = nullptr;
    bool libraryPresent = false;

    PlaybackController *playbackController = nullptr;
    int currentPlayingIndex = -1;
    int currentVisibleIndex = -1;
    int currentPlaybackIndex = -1;
    qint64 playerPosition = 0;
    qint64 playerDuration = 0;
    QVector<int> playHistory;
    QStack<int> nextUp;
    QVector<int> unplayedIndices;
    bool shuffleMode = false;
    bool repeatMode = false;
};

#endif // MAINWINDOW_H