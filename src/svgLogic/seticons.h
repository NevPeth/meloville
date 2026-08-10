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

    provider.registerIcon("repeatIconNormal",":/icons/repeat.svg",QColor("#535353"), QSize(44, 44));
    provider.registerIcon("repeatIconHovered",":/icons/repeat.svg",Qt::white,QSize(44, 44));

    provider.registerDualIcon(
        "playButtonIcon",
        ":/icons/playButton.svg",
        Qt::white,
        Qt::black,
        QSize(60, 60));

    provider.registerDualIcon(
        "pauseButtonIcon",
        ":/icons/pauseButton.svg",
        Qt::white,
        Qt::black,
        QSize(60, 60));

    provider.registerIcon("skipIconNormal",":/icons/skip.svg",QColor("#b3b3b3"),QSize(48, 48));
    provider.registerIcon("skipIconHovered",":/icons/skip.svg",Qt::white, QSize(48, 48));

    provider.registerIcon("reverseIconNormal", ":/icons/reverse.svg",QColor("#b3b3b3"),QSize(48, 48));
    provider.registerIcon("reverseIconHovered",":/icons/reverse.svg",Qt::white,QSize(48, 48));

    provider.registerIcon("speakerIconNormal",":/icons/speakerLowVolume.svg",QColor("#b3b3b3"), QSize(48, 48));
    provider.registerIcon("speakerIconHovered",":/icons/speakerLowVolume.svg",Qt::white,QSize(48, 48));

    provider.registerIcon("settingsIconNormal",":/icons/settings.svg",QColor("#b3b3b3"), QSize(40, 40));
    provider.registerIcon("settingsIconHovered",":/icons/settings.svg",Qt::white,QSize(40, 40));

    provider.registerIcon("bigPictureIconNormal",":/icons/bigPictureIcon.svg",QColor("#b3b3b3"), QSize(40, 40));
    provider.registerIcon("bigPictureIconHovered",":/icons/bigPictureIcon.svg",Qt::white,QSize(40, 40));

    provider.registerIcon("goToAlbumsIconNormal",":/icons/albumIcon.svg",QColor("#b3b3b3"), QSize(60, 60));
    provider.registerIcon("goToAlbumsIconHovered",":/icons/albumIcon.svg",Qt::white,QSize(60, 60));

    provider.registerIcon("jumpToCurrentSongIconNormal",":/icons/jumpToIcon.svg",QColor("#b3b3b3"), QSize(60, 40));
    provider.registerIcon("jumpToCurrentSongIconHovered",":/icons/jumpToIcon.svg",Qt::white,QSize(60, 40));

    provider.registerIcon("dots", ":/icons/dots.svg", QColor("#b3b3b3"), QSize(18,4));

    provider.registerDualIcon(
        "uploadIcon",
        ":/icons/uploadIcon.svg",
        QColor("#2d2d2d"),
        Qt::white,
        QSize(60, 60));

    provider.registerGradientIcon(
        "libraryIcon",
        ":/icons/libraryIcon.svg",
        QColor("#2a2a2a"),
        QColor("#666666"),
        QSize(60, 60)
    );

    provider.registerIcon("closeIcon", ":/icons/closeIcon.svg", Qt::white, QSize(30,30));
    provider.registerIcon("pencilIcon",":/icons/pencil.svg",Qt::white,QSize(60, 60));

    //Now icons that are for the big picture page
    provider.registerIcon("shuffleIconBigNormal",":/icons/shuffle.svg",QColor(255,255,255,50), QSize(60, 42));
    provider.registerIcon("shuffleIconBigHovered",":/icons/shuffle.svg", QColor(255,255,255,170),QSize(60, 42));
    provider.registerIcon("reverseIconBig",":/icons/reverseBig.svg",QColor(255, 255, 255, 230),QSize(70, 70));
    provider.registerIcon("playIconBig",":/icons/menuPlayIcon.svg",QColor(255, 255, 255, 230),QSize(70, 70));
    provider.registerIcon("pauseIconBig",":/icons/menuPauseIcon.svg",QColor(255, 255, 255, 230),QSize(70, 70));
    provider.registerIcon("skipIconBig",":/icons/skipBig.svg",QColor(255, 255, 255, 230),QSize(70, 70));
    provider.registerIcon("repeatIconBigNormal",":/icons/repeat.svg",QColor(255,255,255,50), QSize(60, 60));
    provider.registerIcon("repeatIconBigHovered",":/icons/repeat.svg", QColor(255, 255, 255, 170),QSize(60, 60));
    provider.registerIcon("speakerLeftIconNormal", ":/icons/speakerLowVolume.svg", QColor(255,255,255,50), QSize(40,40));
    provider.registerIcon("speakerLeftIconHovered", ":/icons/speakerLowVolume.svg", QColor(255,255,255,170), QSize(40,40));
    provider.registerIcon("speakerRightIconNormal", ":/icons/speakerFullVolume.svg", QColor(255,255,255,50), QSize(40,40));
    provider.registerIcon("speakerRightIconHovered", ":/icons/speakerFullVolume.svg", QColor(255,255,255,170), QSize(40,40));

    provider.registerIcon("closeIconBigNormal", ":/icons/closeIcon.svg", QColor(255, 255, 255, 50), QSize(50,50));
    provider.registerIcon("closeIconBigHovered", ":/icons/closeIcon.svg", QColor(255, 255, 255, 170), QSize(50,50));
    
}