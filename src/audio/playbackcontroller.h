#pragma once
#include "pulseaudioservice.h"
#include <QObject>
#include <QMediaPlayer>

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

private:
    QMediaPlayer* mediaPlayer;
    QAudioOutput* audioOutput;
    PulseAudioService* pulseAudioService; //Creates variables necessary for correct audio output

    //int currentSongIndex = -1;

    void loadSettings();
    void saveSettings();
};