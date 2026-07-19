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
    Q_PROPERTY(SongModel* songModel READ songModel CONSTANT)
    Q_PROPERTY(bool playlistIsInView READ playlistIsInView NOTIFY playlistChanged)

    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

public:
    explicit MainWindow(QObject *parent = nullptr);
    ~MainWindow();

    SongModel* songModel() const { return m_songModel; }
    bool playlistIsInView() const { return m_playlistIsInView; }

    Q_INVOKABLE void openFolder();
    Q_INVOKABLE void saveLibrary();
    Q_INVOKABLE void loadLibrary();

    double progress() const { return m_progress; }
    QString statusMessage() const { return m_statusMessage; }
    bool scanning() const { return m_scanning; }

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

private:
    static bool songTitleLess(const SongData &a, const SongData &b);
    
    QVector<SongData> m_library;
    QVector<int> m_currentViewSongs;
    QVector<int> m_visibleSongs;
    QVector<int> m_currentPlaybackSongs;
    QString m_currentMusicFolder;
    QString m_appDataPath;
    bool m_playlistIsInView = false;
    QString m_viewingPlaylist;
    
    SongModel *m_songModel = nullptr;
    PlaylistManager *m_playlistManager = nullptr;
    
    void loadPlaylistView(const QString &playlistName);

    double m_progress = 0.0;
    QString m_statusMessage;
    bool m_scanning = false;
    QThread *m_scannerThread = nullptr;
};

#endif // MAINWINDOW_H