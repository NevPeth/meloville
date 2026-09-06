cmake_minimum_required(VERSION 3.16)
project(Meloville VERSION 1.1.5 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

include(GNUInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS 
    Core 
    Quick 
    QuickControls2
    Widgets
    Multimedia
    Svg
    DBus
    Concurrent
)

find_package(PkgConfig REQUIRED)

pkg_check_modules(TAGLIB REQUIRED taglib)
include_directories(${TAGLIB_INCLUDE_DIRS})
link_directories(${TAGLIB_LIBRARY_DIRS})

qt_add_executable(meloville
    main.cpp
    mainwindow.h
    mainwindow.cpp
    songdata.h
    songmodel.h
    songmodel.cpp

    scanningLogic/libraryscanner.h
    scanningLogic/libraryscanner.cpp
    scanningLogic/metadatareader.h
    scanningLogic/metadatareader.cpp

    audio/mprisadapter.h
    audio/mprisadapter.cpp
    audio/playbackcontroller.h
    audio/playbackcontroller.cpp

    playlistLogic/playlistmanager.h
    playlistLogic/playlistmanager.cpp
    playlistLogic/playlistmodel.h
    playlistLogic/playlistmodel.cpp

    albumLogic/albumlistmodel.h
    albumLogic/albumlistmodel.cpp
    albumLogic/albuminfo.h

    svgLogic/svgcreator.h
    svgLogic/svgcreator.cpp
    svgLogic/svgimageprovider.h
    svgLogic/seticons.h

    listenAlongServer/listenalongserver.h
    listenAlongServer/listenalongserver.cpp

    scrobble/scrobblercache.h
    scrobble/scrobblercache.cpp
    scrobble/scrobblercacheitem.h
    scrobble/lastfmscrobbler.h
    scrobble/lastfmscrobbler.cpp
    scrobble/listenbrainzscrobbler.h
    scrobble/listenbrainzscrobbler.cpp

    generateShareLink/youtuberesolver.h
    generateShareLink/youtuberesolver.cpp

    resources.qrc
)

target_link_libraries(meloville PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Multimedia
    Qt6::Svg
    Qt6::DBus
    Qt6::Concurrent
    ${TAGLIB_LIBRARIES}
)

target_include_directories(meloville PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/audio
    ${CMAKE_CURRENT_SOURCE_DIR}/scanningLogic
    ${CMAKE_CURRENT_SOURCE_DIR}/svgLogic
    ${CMAKE_CURRENT_SOURCE_DIR}/playlistLogic
    ${CMAKE_CURRENT_SOURCE_DIR}/albumLogic
    ${CMAKE_CURRENT_SOURCE_DIR}/listenAlongServer
    ${CMAKE_CURRENT_SOURCE_DIR}/scrobble
    ${CMAKE_CURRENT_SOURCE_DIR}/generateShareLink
)

# Installation
install(
    TARGETS meloville
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(
    FILES meloville.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

install(
    FILES icons/meloville.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
)

install(
    FILES ../LICENSE
    DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/meloville
)