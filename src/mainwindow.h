#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include "songdata.h"
#include "songmodel.h"
#include "libraryscanner.h"
#include "playbackcontroller.h"
#include "playlistmanager.h"
#include "playlistmodel.h"
#include "albuminfo.h"
#include "albumlistmodel.h"
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
    Q_PROPERTY(double progress READ getProgress NOTIFY progressChanged)
    Q_PROPERTY(QString statusMessage READ getStatusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(bool scanning READ getScanning NOTIFY scanningChanged)
    Q_PROPERTY(bool libraryPresent READ getLibraryPresent NOTIFY libraryPresentChanged)
    Q_PROPERTY(int currentLibraryIndex READ getCurrentLibraryIndex NOTIFY currentLibraryIndexChanged)
    Q_PROPERTY(QString currentSongTitle READ getCurrentSongTitle NOTIFY currentSongChanged)
    Q_PROPERTY(QString currentSongArtist READ getCurrentSongArtist NOTIFY currentSongChanged)
    Q_PROPERTY(QString currentSongCoverPath READ getCurrentSongCoverPath NOTIFY currentSongChanged)
    Q_PROPERTY(int currentSongDuration READ getCurrentSongDuration NOTIFY currentSongChanged)
    Q_PROPERTY(qint64 playerPosition READ getPlayerPosition NOTIFY playerPositionChanged)
    Q_PROPERTY(qint64 playerDuration READ getPlayerDuration NOTIFY playerDurationChanged)
    Q_PROPERTY(bool repeatMode READ getRepeatMode NOTIFY repeatModeChanged)
    Q_PROPERTY(bool shuffleMode READ getShuffleMode NOTIFY shuffleModeChanged)
    Q_PROPERTY(int volume READ getVolume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool playing READ getPlaying NOTIFY playingChanged)
    Q_PROPERTY(QString viewingPlaylist READ getViewingPlaylist NOTIFY viewingPlaylistChanged)
    Q_PROPERTY(PlaylistManager* playlistManager READ getPlaylistManager CONSTANT)
    Q_PROPERTY(PlaylistModel* playlistModel READ getPlaylistModel CONSTANT)
    Q_PROPERTY(QStringList playlistNames READ getPlaylistNames NOTIFY playlistNamesChanged)
    Q_PROPERTY(bool isInPlaylistView READ getIsInPlaylistView NOTIFY isInPlaylistViewChanged)
    Q_PROPERTY(bool dragReorderAllowed READ getDragReorderAllowed NOTIFY dragReorderAllowedChanged)

    Q_PROPERTY(bool isInAlbumsGridView READ getIsInAlbumsGridView NOTIFY albumViewStateChanged)
    Q_PROPERTY(bool isInAlbumView READ getIsInAlbumView NOTIFY albumViewStateChanged)
    Q_PROPERTY(QString viewingAlbumName READ getViewingAlbum NOTIFY albumViewStateChanged)
    Q_PROPERTY(QString viewingAlbumArtist READ getViewingAlbumArtist NOTIFY albumViewStateChanged)
    Q_PROPERTY(QString viewingAlbumCover READ getViewingAlbumCover NOTIFY albumViewStateChanged)
    Q_PROPERTY(QObject* albumModel READ getAlbumModel CONSTANT)

public:
    explicit MainWindow(QObject *parent = nullptr);
    ~MainWindow();

    SongModel* getSongModel() const { return songModel; }

    Q_INVOKABLE void openFolder();
    Q_INVOKABLE void saveLibrary();
    Q_INVOKABLE void loadLibrary();
    Q_INVOKABLE void playSongAtVisibleIndex(int visibleIndex);
    Q_INVOKABLE void playAndPause();
    Q_INVOKABLE void playNextSong();
    Q_INVOKABLE void playPreviousSong();
    Q_INVOKABLE void seekTo(qint64 positionMs);
    Q_INVOKABLE void toggleShuffle();
    Q_INVOKABLE void toggleRepeat();
    Q_INVOKABLE void filterSongsAndAlbums(const QString &text);
    Q_INVOKABLE void createPlaylistFromDialog(const QString& name, const QString& sourceImagePath);
    Q_INVOKABLE void loadPlaylistView(const QString& playlistName);
    Q_INVOKABLE void returnToLibrary();
    Q_INVOKABLE void openSongContextMenu(int visibleIndex, int x, int y);
    Q_INVOKABLE void editPlaylist(const QString& oldName, const QString& newName, const QString& imagePath);
    Q_INVOKABLE void deletePlaylist(const QString& playlistName);
    Q_INVOKABLE void addToPlaylist(int visibleIndex, const QString& playlistName);
    Q_INVOKABLE void removeFromCurrentPlaylist(int visibleIndex);
    Q_INVOKABLE void saveSongEdits(int libraryIndex, const QString& title, const QString& artist, const QString& album, int trackNumber, const QString& imagePath);
    Q_INVOKABLE void jumpToCurrentSong();
    Q_INVOKABLE void reorderPlaylist(int from, int to);
    Q_INVOKABLE void editCurrentSong(int visibleIndex);
    Q_INVOKABLE void goToAlbums();
    Q_INVOKABLE void loadAlbumView(QString albumName, QString artist, QString coverPath);
    Q_INVOKABLE void returnFromAlbumToGrid();
    Q_INVOKABLE QRect loadWindowGeometry() const;
    Q_INVOKABLE void  saveSessionAndWindow(int x, int y, int w, int h);

    double getProgress() const { return progress; }
    PlaylistModel* getPlaylistModel() const { return playlistModel; }
    QString getStatusMessage() const { return statusMessage; }
    bool getScanning() const { return scanning; }
    bool getLibraryPresent() const { return libraryPresent; }
    int getCurrentLibraryIndex() const { return currentLibraryIndex; }
    QString getCurrentSongTitle() const {
        if (currentLibraryIndex < 0 || currentLibraryIndex >= library.size()) return QString();
        return library[currentLibraryIndex].title.toHtmlEscaped();
    }
    QString getCurrentSongArtist() const {
        if (currentLibraryIndex < 0 || currentLibraryIndex >= library.size()) return QString();
        return library[currentLibraryIndex].artist.toHtmlEscaped();
    }
    QString getCurrentSongCoverPath() const {
        if (currentLibraryIndex < 0 || currentLibraryIndex >= library.size()) return QString();
        return library[currentLibraryIndex].coverPath;
    }
    bool getRepeatMode() const { return repeatMode; }
    bool getShuffleMode() const { return shuffleMode; }
    int getCurrentSongDuration() const {
        if (currentLibraryIndex < 0 || currentLibraryIndex >= library.size()) return 0;
        return library[currentLibraryIndex].duration;
    }
    qint64 getPlayerPosition() const { return playerPosition; }
    qint64 getPlayerDuration() const { return playerDuration; }
    int getVolume() const;
    void setVolume(int vol);
    bool getPlaying() const { return playing; }
    void setPlaying(bool p);
    QString getViewingPlaylist() const { return viewingPlaylist; }
    PlaylistManager* getPlaylistManager() const { return playlistManager; }
    QStringList getPlaylistNames() const { return playlistNames; }
    bool getIsInPlaylistView() const { return isInPlaylistView; }
    bool getDragReorderAllowed() const { return isInPlaylistView && filterText.isEmpty(); }
    bool getIsInAlbumsGridView() const { return isInAlbumsGridView; }
    bool getIsInAlbumView() const { return isInAlbumView; }
    QString getViewingAlbum() const { return viewingAlbum; }
    QString getViewingAlbumArtist() const { return viewingAlbumArtist; }
    QString getViewingAlbumCover() const { return viewingAlbumCoverPath; }
    QObject* getAlbumModel() const { return albumModel; }

public slots:
    void onScanProgress(int current, int total);
    void onScanFinished(const QVector<SongData>& songs, const QString& folderPath);
    void onScanError(const QString& message);

private slots:
    static bool songTitleLess(const SongData &a, const SongData &b);
    void playSong(int libraryIndex);
    void rebuildShufflePool();
    void rebuildPlaybackMap();
    void updatePlaylistNames();
    QVector<AlbumInfo> buildAlbumList() const;
    void leaveAlbumView();
    void saveWindowGeometry(int x, int y, int w, int h);
    void saveSessionState();
    void loadSessionState();

signals:
    void playlistChanged();
    void libraryLoaded();
    void progressChanged();
    void statusMessageChanged();
    void scanningChanged();
    void libraryPresentChanged();
    void currentLibraryIndexChanged();
    void currentSongChanged();
    void playerPositionChanged(qint64 position);
    void playerDurationChanged(qint64 duration);
    void playbackStateChanged(int state);
    void repeatModeChanged();
    void shuffleModeChanged();
    void volumeChanged(int vol);
    void playingChanged(bool playing);
    void viewingPlaylistChanged();
    void playlistNamesChanged();
    void isInPlaylistViewChanged();
    void openContextMenuRequested(int visibleIndex, int x, int y);
    void jumpToSongIndex(int visibleIndex);
    void dragReorderAllowedChanged();
    void editSongRequested(int libraryIndex,const QString& filePath,const QString& coverPath,
                        const QString& title,const QString& artist,const QString& album, int trackNumber);
    void songCoverUpdated(int libraryIndex, const QString& newCoverPath);
    void albumViewStateChanged();
    void returnedToLibrary();
    void sessionRestored(qint64 position);

private:
    QVector<SongData> library;
    QVector<int> currentViewSongs;
    QVector<int> visibleSongs;
    QVector<int> currentPlaybackSongs;
    QString currentMusicFolder;
    QString appDataPath;
    bool isInPlaylistView = false;
    QString viewingPlaylist;
    SongModel *songModel = nullptr;
    PlaylistManager *playlistManager = nullptr;
    double progress = 0.0;
    QString statusMessage;
    bool scanning = false;
    QThread *scannerThread = nullptr;
    bool libraryPresent = false;

    PlaybackController *playbackController = nullptr;
    int currentLibraryIndex = -1;
    int currentVisibleIndex = -1;
    int currentPlaybackIndex = -1;
    qint64 playerPosition = 0;
    qint64 playerDuration = 0;
    QVector<int> playHistory;
    QStack<int> nextUp;
    QVector<int> unplayedIndices;
    bool shuffleMode = false;
    bool repeatMode = false;
    bool playing = false;
    PlaylistModel *playlistModel = nullptr;
    QString currentlyPlayingPlaylist;
    QVector<QString> playlistNames;

    QString filterText;

    QString currentlyPlayingAlbum;
    QString currentlyPlayingAlbumArtist;
    QString currentlyPlayingAlbumCoverPath;
    QString viewingAlbum;
    QString viewingAlbumArtist;
    QString viewingAlbumCoverPath;
    bool isInAlbumsGridView = false;
    bool isInAlbumView = false;
    AlbumListModel *albumModel = nullptr;
    QVector<AlbumInfo> allAlbums;

    QHash<int,int> libraryIndexToPlaybackPos;
};

#endif // MAINWINDOW_H