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

    int getCurrentSongIndex() const;
    void setCurrentSongIndex(int index);

    bool isPlaying() const;

    void setVolume(int volume);
    int volume() const;

signals:
    void currentSongChanged(int index);

    void playbackStateChanged(
        QMediaPlayer::PlaybackState state
    );

    void songFinished();

    void volumeChanged(int volume);

private:
    QMediaPlayer* mediaPlayer;
    QAudioOutput* audioOutput;
    PulseAudioService* pulseAudioService; //Creates variables necessary for correct audio output

    int currentSongIndex = -1;

    void loadSettings();
    void saveSettings();
};