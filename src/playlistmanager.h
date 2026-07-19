#pragma once

#include <songdata.h>
#include <QObject>
#include <QMap>
#include <QList>

struct PlaylistSong
{
    QString title;
    QString artist;
};

class PlaylistManager : public QObject
{
    Q_OBJECT

public:
    explicit PlaylistManager(QObject* parent = nullptr);
    /*Getter Functions:*/
    QString playlistImage(const QString& playlistName) const;
    QStringList playlistNames() const;
    QList<int> getPlaylistSongs(const QString& playlistName) const;
    int playlistTitleFontSize(const QString& playlist) const;
    /*Functions that actually manipulate the playlist contents*/
    void createPlaylist(
        const QString& name,
        const QString& imagePath
    );
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
    int calculateTitleSize(const QString& text);
    void editSongFromAllPlaylists(int libraryIndex, const QString& newSongTitle, const QString& newArtist);
    void removeSongFromAllPlaylists(int libraryIndex);

signals:
    void playlistCreated(const QString& playlistName);

private:
    QStringList playlistOrder;
    QMap<QString, QString> playlistImages;
    QMap<QString, QList<int>> playlists;
    QMap<QString, QList<PlaylistSong>> playlistDefinitions;
    QString playlistPath;
    QMap<QString, int> playlistTitleFontSizes;
};