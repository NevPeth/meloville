#include "pulseaudioservice.h"

#include <QDebug>
#include <QTimer>

PulseAudioService::PulseAudioService(
    QAudioOutput* audioOutput,
    QMediaPlayer* player,
    QObject* parent
)
    : QObject(parent),
      m_audioOutput(audioOutput),
      m_player(player)
{
}

PulseAudioService::~PulseAudioService()
{
    if (m_context) {
        pa_context_disconnect(m_context);
        pa_context_unref(m_context);
    }

    if (m_mainLoop) {
        pa_threaded_mainloop_stop(m_mainLoop);
        pa_threaded_mainloop_free(m_mainLoop);
    }
}

void PulseAudioService::initialize()
{
    m_mainLoop = pa_threaded_mainloop_new();

    pa_threaded_mainloop_lock(m_mainLoop);

    pa_threaded_mainloop_start(m_mainLoop);

    pa_mainloop_api* mainloopApi =
        pa_threaded_mainloop_get_api(m_mainLoop);

    m_context = pa_context_new(
        mainloopApi,
        "QtMusicApp"
    );

    pa_context_set_state_callback(
        m_context,
        contextStateCallback,
        this
    );

    pa_context_connect(
        m_context,
        nullptr,
        PA_CONTEXT_NOFLAGS,
        nullptr
    );

    pa_threaded_mainloop_unlock(m_mainLoop);
}

void PulseAudioService::contextStateCallback(pa_context* context, void* userdata)
{
    auto* self =
        static_cast<PulseAudioService*>(userdata);

    pa_context_state_t state =
        pa_context_get_state(context);

    if (state == PA_CONTEXT_READY) {

        pa_context_get_server_info(
            context,
            serverInfoCallback,
            userdata
        );

        pa_context_set_subscribe_callback(
            context,
            subscribeCallback,
            userdata
        );

        pa_context_subscribe(
            context,
            static_cast<pa_subscription_mask_t>(
                PA_SUBSCRIPTION_MASK_SINK |
                PA_SUBSCRIPTION_MASK_SERVER
            ),
            nullptr,
            nullptr
        );
    }
    else if (state == PA_CONTEXT_FAILED || state == PA_CONTEXT_TERMINATED)
    {
        qWarning() << "PulseAudio context failed";
    }
}

void PulseAudioService::serverInfoCallback(
    pa_context* context,
    const pa_server_info* info,
    void* userdata
)
{
    Q_UNUSED(context);

    auto* self =
        static_cast<PulseAudioService*>(userdata);

    QString defaultSink =
        QString::fromUtf8(info->default_sink_name);

    self->handleDefaultSinkChanged(defaultSink);
}

void PulseAudioService::subscribeCallback(
    pa_context* context,
    pa_subscription_event_type_t type,
    uint32_t idx,
    void* userdata
)
{
    Q_UNUSED(idx);

    auto* self =
        static_cast<PulseAudioService*>(userdata);

    if (
        (type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) == PA_SUBSCRIPTION_EVENT_SINK ||

        (type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) == PA_SUBSCRIPTION_EVENT_SERVER
    ) {
        pa_context_get_server_info(
            context,
            serverInfoCallback,
            userdata
        );
    }
}

void PulseAudioService::handleDefaultSinkChanged(const QString& newSink){

    QTimer::singleShot(500, this, [this]()
        {
            QAudioDevice newDevice =
                QMediaDevices::defaultAudioOutput();

            if (newDevice.isNull()) {
                qWarning()
                    << "No valid audio device";
                return;
            }

            if (m_audioOutput->device() == newDevice)
            {
                return;
            }

            m_audioOutput->setDevice(newDevice);

            if (m_player->playbackState() != QMediaPlayer::PlayingState)
            {
                m_player->play();

                qint64 pos =
                    m_player->position();

                m_player->setPosition(pos + 1);
                m_player->setPosition(pos);
            }
        }
    );
}