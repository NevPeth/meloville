cmake_minimum_required(VERSION 3.16)
project(Meloville VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS 
    Core 
    Quick 
    QuickControls2
    Widgets
    Multimedia
    Svg
    DBus
)

find_package(PkgConfig REQUIRED)

pkg_check_modules(TAGLIB REQUIRED taglib)
include_directories(${TAGLIB_INCLUDE_DIRS})
link_directories(${TAGLIB_LIBRARY_DIRS})

qt_add_executable(Meloville
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
    audio/pulseaudioservice.h
    audio/pulseaudioservice.cpp
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

    resources.qrc
)

target_link_libraries(Meloville PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Multimedia
    Qt6::Svg
    Qt6::DBus
    ${TAGLIB_LIBRARIES}
    pulse
)

target_include_directories(Meloville PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/audio
    ${CMAKE_CURRENT_SOURCE_DIR}/scanningLogic
    ${CMAKE_CURRENT_SOURCE_DIR}/svgLogic
    ${CMAKE_CURRENT_SOURCE_DIR}/playlistLogic
    ${CMAKE_CURRENT_SOURCE_DIR}/albumLogic
    ${CMAKE_CURRENT_SOURCE_DIR}/listenAlongServer
)