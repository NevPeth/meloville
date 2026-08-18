#pragma once

#include <songdata.h>
#include <QObject>
#include <QMap>
#include <QList>

struct PlaylistSong
{
    QString title;
    QString artist;
    QString coverPath;
};

class PlaylistManager : public QObject
{
    Q_OBJECT

public:
    explicit PlaylistManager(QObject* parent = nullptr);
    Q_INVOKABLE QString fullImagePath(const QString& playlistName) const;
    /*Getter Functions:*/
    QString playlistImage(const QString& playlistName) const;
    QStringList playlistNames() const;
    QList<int> getPlaylistSongs(const QString& playlistName) const;
    /*Functions that actually manipulate the playlist contents*/
    Q_INVOKABLE void createPlaylist( const QString& name, const QString& sourceImagePath);
    void addSongToPlaylist(
        const QString& playlistName,
        int libraryIndex,
        const SongData& song
    );
    void removeSongFromPlaylist(
        const QString& playlistName,
        int libraryIndex
    );
    void savePlaylists();
    void loadPlaylists(const QVector<SongData>& library, bool emitSignals = true);
    void setPath(const QString& path);
    void editPlaylist(
        const QString& oldName,
        const QString& newName,
        const QString& imagePath
    );
    void deletePlaylist(const QString& playlistName);
    void editSongFromAllPlaylists(int libraryIndex, const QString& newSongTitle, const QString& newArtist, const QString& imagePath);
    void removeSongFromAllPlaylists(int libraryIndex);

    void reorderPlaylist(const QString& playlistName, int from, int to);
    void changePlaylistToTop(const QString& playlistName);

signals:
    void playlistChanged();

private slots:
    void updateAutoGenSongs(const QString& playlistName);

private:
    QString appDataPath;QString coverPath;
    QStringList playlistOrder;
    QMap<QString, QString> playlistImages;
    QMap<QString, QList<int>> playlists;
    QMap<QString, QList<PlaylistSong>> playlistDefinitions;
    QString playlistPath;

    QMap<QString, bool> playlistAutoGenerate;
    QMap<QString, QList<PlaylistSong>> playlistAutoGenSongs; //stores first 4 songs for each playlist to see if they changed
};