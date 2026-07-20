#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include "songdata.h"
#include "songmodel.h"
#include "libraryscanner.h"
#include <QMainWindow>
#include <QQuickView>
#include <QStackedWidget>
#include <QVector>
#include <QSet>
#include <QThread>

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

public:
    explicit MainWindow(QObject *parent = nullptr);
    ~MainWindow();

    SongModel* getSongModel() const { return songModel; }
    bool getPlaylistIsInView() const { return playlistIsInView; }

    Q_INVOKABLE void openFolder();
    Q_INVOKABLE void saveLibrary();
    Q_INVOKABLE void loadLibrary();

    double getProgress() const { return progress; }
    QString getStatusMessage() const { return statusMessage; }
    bool getScanning() const { return scanning; }
    bool getLibraryPresent() const { return libraryPresent; }

public slots:
    void onScanProgress(int current, int total);
    void onScanFinished(const QVector<SongData>& songs, const QString& folderPath);
    void onScanError(const QString& message);

signals:
    void playlistChanged();
    void libraryLoaded();
    void progressChanged();
    void statusMessageChanged();
    void scanningChanged();
    void libraryPresentChanged();

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
};

#endif // MAINWINDOW_H