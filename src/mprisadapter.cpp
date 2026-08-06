#include "mprisadapter.h"

MprisAdapter::MprisAdapter(QObject *parent)
    : QObject(parent)
{
    // Both adaptors attach themselves to 'this' as the D-Bus object
    m_root   = new MprisRootAdaptor(this);
    m_player = new MprisPlayerAdaptor(this);

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerService("org.mpris.MediaPlayer2.meloville");
    bus.registerObject("/org/mpris/MediaPlayer2", this);
}