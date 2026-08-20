#pragma once
#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QMediaDevices>
#include <QAudioDevice>
#include <QTimer>

class PlaybackController : public QObject
{
    Q_OBJECT

public:
    explicit PlaybackController(QObject *parent = nullptr);
    QMediaPlayer* player() const;
    void setPlayer(QMediaPlayer* mediaPlayer);

    bool isPlaying() const;

    void setVolume(int volume);
    int volume() const;

signals:
    void currentSongChanged(int index);
    void playbackStateChanged(QMediaPlayer::PlaybackState state);
    void songFinished();
    void volumeChanged(int volume);
    void positionChanged(qint64 position);
    void durationChanged(qint64 duration);
    void audioOutputDeviceChanged();

private:
    QMediaPlayer* mediaPlayer = nullptr;
    QAudioOutput* audioOutput = nullptr;
    QMediaDevices* mediaDevices = nullptr;

    QTimer defaultAudioOutputTimer;

    void handleDefaultAudioOutputChanged();
    void loadSettings();
    void saveSettings();
};