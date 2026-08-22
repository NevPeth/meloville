#pragma once
#include <QObject>
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>

class MprisRootAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit      READ getCanQuit)
    Q_PROPERTY(bool CanRaise     READ getCanRaise)
    Q_PROPERTY(bool HasTrackList READ getHasTrackList)
    Q_PROPERTY(QString Identity  READ getIdentity)
    Q_PROPERTY(QStringList SupportedUriSchemes READ getSupportedUriSchemes)
    Q_PROPERTY(QStringList SupportedMimeTypes  READ getSupportedMimeTypes)

public:
    explicit MprisRootAdaptor(QObject *parent)
        : QDBusAbstractAdaptor(parent) {}

    bool        getCanQuit()             const { return false; }
    bool        getCanRaise()            const { return false; }
    bool        getHasTrackList()        const { return false; }
    QString     getIdentity()            const { return "Meloville"; }
    QStringList getSupportedUriSchemes() const { return {}; }
    QStringList getSupportedMimeTypes()  const { return {}; }

public slots:
    void Quit()  {}
    void Raise() {}
};

class MprisPlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(bool        CanPlay        READ getCanPlay)
    Q_PROPERTY(bool        CanPause       READ getCanPause)
    Q_PROPERTY(bool        CanGoNext      READ getCanGoNext)
    Q_PROPERTY(bool        CanGoPrevious  READ getCanGoPrevious)
    Q_PROPERTY(bool        CanSeek        READ getCanSeek)
    Q_PROPERTY(bool        CanControl     READ getCanControl)
    Q_PROPERTY(bool        Shuffle        READ getShuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(QString     LoopStatus     READ getLoopStatus WRITE setLoopStatus)
    Q_PROPERTY(QString     PlaybackStatus READ getPlaybackStatus)
    Q_PROPERTY(QVariantMap Metadata       READ getMetadata)

public:
    explicit MprisPlayerAdaptor(QObject *parent)
        : QDBusAbstractAdaptor(parent) {}

    bool        getCanPlay()        const { return true; }
    bool        getCanPause()       const { return true; }
    bool        getCanGoNext()      const { return true; }
    bool        getCanGoPrevious()  const { return true; }
    bool        getCanSeek()        const { return false; }
    bool        getCanControl()     const { return true; }
    bool        getShuffle()        const { return shuffle; }
    QString     getLoopStatus()     const { return loopStatus; }
    QString     getPlaybackStatus() const { return playbackStatus; }
    QVariantMap getMetadata()       const { return metadata; }

    void setMetadata(const QVariantMap &map)
    {
        metadata = map;

        QVariantMap changed;
        changed["Metadata"] = QVariant::fromValue(metadata);

        QDBusMessage signal = QDBusMessage::createSignal(
            "/org/mpris/MediaPlayer2",
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged"
        );
        signal << "org.mpris.MediaPlayer2.Player"
               << changed
               << QStringList{};

        QDBusConnection::sessionBus().send(signal);
    }

    void setPlaybackStatus(const QString &status)
    {
        playbackStatus = status;

        QVariantMap changed;
        changed["PlaybackStatus"] = playbackStatus;

        QDBusMessage signal = QDBusMessage::createSignal(
            "/org/mpris/MediaPlayer2",
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged"
        );
        signal << "org.mpris.MediaPlayer2.Player"
            << changed
            << QStringList{};

        QDBusConnection::sessionBus().send(signal);
    }

    void setLoopStatus(const QString &status)
    {
        loopStatus = status;

        QVariantMap changed;
        changed["LoopStatus"] = loopStatus;
        emit loopStatusChanged(loopStatus != "None");

        QDBusMessage signal = QDBusMessage::createSignal(
            "/org/mpris/MediaPlayer2",
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged"
        );
        signal << "org.mpris.MediaPlayer2.Player"
            << changed
            << QStringList{};

        QDBusConnection::sessionBus().send(signal);
    }

    void setShuffle(bool newShuffle)
    {
        shuffle = newShuffle;
        emit shuffleChanged(shuffle);

        QVariantMap changed;
        changed["Shuffle"] = shuffle;

        QDBusMessage signal = QDBusMessage::createSignal(
            "/org/mpris/MediaPlayer2",
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged"
        );
        signal << "org.mpris.MediaPlayer2.Player"
            << changed
            << QStringList{};

        QDBusConnection::sessionBus().send(signal);
    }

public slots:
    void Next()      { emit nextRequested(); }
    void Previous()  { emit previousRequested(); }
    void PlayPause() { emit playPauseRequested(); }
    void Play()      { emit playPauseRequested(); }
    void Pause()     { emit playPauseRequested(); }
    void Stop()      {}

signals:
    void nextRequested();
    void shuffleChanged(bool shuffle);
    // NOTE: Technically in Mpris there's Track and Playing status, but we only support Track.
    // As a hacky fallback if you set any of them consider it as loop enabled.
    void loopStatusChanged(bool newStatus);
    void previousRequested();
    void playPauseRequested();

private:
    QString     playbackStatus = "Stopped";
    QString     loopStatus     = "None";
    bool        shuffle        = false;
    QVariantMap metadata;
};

class MprisAdapter : public QObject
{
    Q_OBJECT
public:
    explicit MprisAdapter(QObject *parent = nullptr);
    MprisPlayerAdaptor *getPlayer() const { return player; }

private:
    MprisRootAdaptor   *root   = nullptr;
    MprisPlayerAdaptor *player = nullptr;
};
