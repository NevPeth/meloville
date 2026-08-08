#pragma once

#include <QObject>

#include <QAudioOutput>
#include <QMediaPlayer>
#include <QMediaDevices>
#include <QAudioDevice>

#include <pulse/pulseaudio.h>

class PulseAudioService : public QObject
{
    Q_OBJECT

public:
    explicit PulseAudioService(
        QAudioOutput* audioOutput,
        QMediaPlayer* player,
        QObject* parent = nullptr
    );

    ~PulseAudioService();

    void initialize();

private:
    static void contextStateCallback(
        pa_context* context,
        void* userdata
    );

    static void serverInfoCallback(
        pa_context* context,
        const pa_server_info* info,
        void* userdata
    );

    static void subscribeCallback(
        pa_context* context,
        pa_subscription_event_type_t type,
        uint32_t idx,
        void* userdata
    );

    void handleDefaultSinkChanged(
        const QString& newSink
    );

private:
    pa_threaded_mainloop* m_mainLoop = nullptr;
    pa_context* m_context = nullptr;

    QAudioOutput* m_audioOutput = nullptr;
    QMediaPlayer* m_player = nullptr;
};