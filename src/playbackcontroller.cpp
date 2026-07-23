#include "playbackcontroller.h"
#include "pulseaudioservice.h"
#include <QSettings>

PlaybackController::PlaybackController(QObject *parent)
    : QObject(parent)
{
    mediaPlayer = new QMediaPlayer(this);

    audioOutput = new QAudioOutput(this);
    mediaPlayer->setAudioOutput(audioOutput);
    loadSettings();

    pulseAudioService = new PulseAudioService(audioOutput, mediaPlayer, this);
    pulseAudioService->initialize();

    connect(
        mediaPlayer,
        &QMediaPlayer::playbackStateChanged,
        this,
        &PlaybackController::playbackStateChanged
    );

    connect(
        mediaPlayer,
        &QMediaPlayer::mediaStatusChanged,
        this,
        [this](QMediaPlayer::MediaStatus status)
        {
            if (status == QMediaPlayer::EndOfMedia) {
                emit songFinished();
            }
        }
    );

    connect(
        mediaPlayer,
        &QMediaPlayer::positionChanged,
        this,
        [this](qint64 pos)
        {
            emit positionChanged(pos);
        }
    );

    connect(
        mediaPlayer,
        &QMediaPlayer::durationChanged,
        this,
        [this](qint64 dur)
        {
            emit durationChanged(dur);
        }
    );
}

QMediaPlayer* PlaybackController::player() const
{
    return mediaPlayer;
}

int PlaybackController::getCurrentSongIndex() const
{
    return currentSongIndex;
}

void PlaybackController::setCurrentSongIndex(int index)
{
    if (currentSongIndex == index)
        return;

    currentSongIndex = index;

    emit currentSongChanged(index);
}

bool PlaybackController::isPlaying() const
{
    return mediaPlayer && mediaPlayer->playbackState() == QMediaPlayer::PlayingState;
}

void PlaybackController::setVolume(
    int volume
)
{
    volume =
        std::clamp(volume, 0, 100);

    audioOutput->setVolume(
        volume / 100.0
    );

    saveSettings();
}

int PlaybackController::volume() const
{
    return static_cast<int>(
        audioOutput->volume() * 100.0
    );
}

void PlaybackController::loadSettings()
{
    QSettings settings("Meloville","Meloville");

    int volume =
        settings
            .value("audio/volume", 30)
            .toInt();

    audioOutput->setVolume(
        volume / 100.0
    );

    emit volumeChanged(volume);
}

void PlaybackController::saveSettings()
{
    QSettings settings(
        "Meloville",
        "Meloville"
    );

    settings.setValue(
        "audio/volume",
        volume()
    );
}