#pragma once

#include "svgimageprovider.h"

inline void registerIcons(SvgImageProvider& provider)
{
    provider.registerDualIcon(
        "addPlaylistsIcon",
        ":/icons/addPlaylistsIcon.svg",
        QColor("#2a2a2a"),
        Qt::white,
        QSize(60, 60));

    provider.registerIcon("shuffleIconNormal",":/icons/shuffle.svg",QColor("#535353"), QSize(42, 30));
    provider.registerIcon("shuffleIconHovered",":/icons/shuffle.svg",Qt::white,QSize(42, 30));

    provider.registerIcon("reverseIconNormal", ":/icons/reverse.svg",QColor("#b3b3b3"),QSize(48, 48));
    provider.registerIcon("reverseIconHovered",":/icons/reverse.svg",Qt::white,QSize(48, 48));

    provider.registerDualIcon(
        "playButtonIcon",
        ":/icons/playButton.svg",
        Qt::white,
        Qt::black,
        QSize(60, 60));

    provider.registerIcon("skipIconNormal",":/icons/skip.svg",QColor("#b3b3b3"),QSize(48, 48));
    provider.registerIcon("skipIconHovered",":/icons/skip.svg",Qt::white, QSize(48, 48));

    provider.registerIcon("repeatIconNormal",":/icons/repeat.svg",QColor("#535353"), QSize(44, 44));
    provider.registerIcon("repeatIconHovered",":/icons/repeat.svg",Qt::white,QSize(44, 44));

    provider.registerIcon("speakerIconNormal",":/icons/speakerLowVolume.svg",QColor("#b3b3b3"), QSize(48, 48));
    provider.registerIcon("speakerIconHovered",":/icons/speakerLowVolume.svg",Qt::white,QSize(48, 48));

    provider.registerIcon("listenAlongIconNormal",":/icons/connectIcon.svg",QColor("#535353"), QSize(60, 60));
    provider.registerIcon("listenAlongIconHovered",":/icons/connectIcon.svg",Qt::white,QSize(60, 60));

    provider.registerIcon("bigPictureIconNormal",":/icons/bigPictureIcon.svg",QColor("#b3b3b3"), QSize(40, 40));
    provider.registerIcon("bigPictureIconHovered",":/icons/bigPictureIcon.svg",Qt::white,QSize(40, 40));

    provider.registerIcon("goToAlbumsIconNormal",":/icons/albumIcon.svg",QColor("#b3b3b3"), QSize(60, 60));
    provider.registerIcon("goToAlbumsIconHovered",":/icons/albumIcon.svg",Qt::white,QSize(60, 60));

    provider.registerIcon("jumpToCurrentSongIconNormal",":/icons/jumpToIcon.svg",QColor("#b3b3b3"), QSize(60, 40));
    provider.registerIcon("jumpToCurrentSongIconHovered",":/icons/jumpToIcon.svg",Qt::white,QSize(60, 40));
}