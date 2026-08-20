#include "playbackcontroller.h"

#include <QSettings>
#include <QDebug>
#include <algorithm>

PlaybackController::PlaybackController(QObject *parent)
    : QObject(parent)
{
    mediaPlayer = new QMediaPlayer(this);

    audioOutput = new QAudioOutput(this);
    mediaPlayer->setAudioOutput(audioOutput);

    mediaDevices = new QMediaDevices(this);

    loadSettings();

    defaultAudioOutputTimer.setSingleShot(true);
    defaultAudioOutputTimer.setInterval(500);

    connect(
        mediaDevices,
        &QMediaDevices::audioOutputsChanged,
        this,
        [this]()
        {
            defaultAudioOutputTimer.start();
        }
    );

    connect(
        &defaultAudioOutputTimer,
        &QTimer::timeout,
        this,
        &PlaybackController::handleDefaultAudioOutputChanged
    );

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
        [this](qint64 position)
        {
            emit positionChanged(position);
        }
    );

    connect(
        mediaPlayer,
        &QMediaPlayer::durationChanged,
        this,
        [this](qint64 duration)
        {
            emit durationChanged(duration);
        }
    );
}

QMediaPlayer* PlaybackController::player() const{
    return mediaPlayer;
}

void PlaybackController::setPlayer(QMediaPlayer* player){
    mediaPlayer = player;
}

bool PlaybackController::isPlaying() const
{
    return mediaPlayer &&
        mediaPlayer->playbackState() == QMediaPlayer::PlayingState;
}

void PlaybackController::setVolume(int volume){
    volume = std::clamp(volume, 0, 100);
    audioOutput->setVolume(volume / 100.0);

    emit volumeChanged(volume);
    saveSettings();
}

int PlaybackController::volume() const
{
    return static_cast<int>(
        audioOutput->volume() * 100.0
    );
}

void PlaybackController::handleDefaultAudioOutputChanged()
{
    if (!audioOutput)
        return;

    QAudioDevice newDevice = QMediaDevices::defaultAudioOutput();

    if (newDevice.isNull()) {
        qWarning() << "No valid default audio output device";
        return;
    }

    if (audioOutput->device() == newDevice)
        return;

    qDebug()
        << "Default audio output changed to:"
        << newDevice.description();

    // Pause before switching the output device.
    const bool wasPlaying = isPlaying();

    if (wasPlaying) {
        mediaPlayer->pause();
    }

    audioOutput->setDevice(newDevice);

    // Telling MainWindow that the device changed and playback
    // should be considered stopped/paused.
    emit audioOutputDeviceChanged();
}

void PlaybackController::loadSettings()
{
    QSettings settings("Meloville","Meloville");

    int volume = settings.value("audio/volume", 30).toInt();
    audioOutput->setVolume(volume / 100.0);
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