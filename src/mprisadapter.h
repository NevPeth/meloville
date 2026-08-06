#pragma once
#include <QObject>
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>

class MprisRootAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit      READ canQuit)
    Q_PROPERTY(bool CanRaise     READ canRaise)
    Q_PROPERTY(bool HasTrackList READ hasTrackList)
    Q_PROPERTY(QString Identity  READ identity)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supportedUriSchemes)
    Q_PROPERTY(QStringList SupportedMimeTypes  READ supportedMimeTypes)

public:
    explicit MprisRootAdaptor(QObject *parent)
        : QDBusAbstractAdaptor(parent) {}

    bool        canQuit()             const { return false; }
    bool        canRaise()            const { return false; }
    bool        hasTrackList()        const { return false; }
    QString     identity()            const { return "Meloville"; }
    QStringList supportedUriSchemes() const { return {}; }
    QStringList supportedMimeTypes()  const { return {}; }

public slots:
    void Quit()  {}
    void Raise() {}
};

class MprisPlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(bool CanPlay           READ canPlay)
    Q_PROPERTY(bool CanPause          READ canPause)
    Q_PROPERTY(bool CanGoNext         READ canGoNext)
    Q_PROPERTY(bool CanGoPrevious     READ canGoPrevious)
    Q_PROPERTY(bool CanSeek           READ canSeek)
    Q_PROPERTY(bool CanControl        READ canControl)
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)

public:
    explicit MprisPlayerAdaptor(QObject *parent)
        : QDBusAbstractAdaptor(parent) {}

    bool    canPlay()         const { return true; }
    bool    canPause()        const { return true; }
    bool    canGoNext()       const { return true; }
    bool    canGoPrevious()   const { return true; }
    bool    canSeek()         const { return false; }
    bool    canControl()      const { return true; }
    QString playbackStatus()  const { return m_status; }

    void setPlaybackStatus(const QString &s) { m_status = s; }

public slots:
    // GNOME calls these slots when you press headphone buttons
    void Next()      { emit nextRequested(); }
    void Previous()  { emit previousRequested(); }
    void PlayPause() { emit playPauseRequested(); }
    void Play()      { emit playPauseRequested(); }
    void Pause()     { emit playPauseRequested(); }
    void Stop()      {}

signals:
    void nextRequested();
    void previousRequested();
    void playPauseRequested();

private:
    QString m_status = "Stopped";
};

class MprisAdapter : public QObject
{
    Q_OBJECT
public:
    explicit MprisAdapter(QObject *parent = nullptr);
    MprisPlayerAdaptor *player() const { return m_player; }

private:
    MprisRootAdaptor   *m_root   = nullptr;
    MprisPlayerAdaptor *m_player = nullptr;
};