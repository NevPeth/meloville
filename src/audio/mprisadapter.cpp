#include "mprisadapter.h"

MprisAdapter::MprisAdapter(QObject *parent)
    : QObject(parent)
{
    root   = new MprisRootAdaptor(this);
    player = new MprisPlayerAdaptor(this);

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerService("org.mpris.MediaPlayer2.meloville");
    bus.registerObject("/org/mpris/MediaPlayer2", this);
}