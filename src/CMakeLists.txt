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
    metadatareader.h
    metadatareader.cpp
    songmodel.h
    songmodel.cpp
    playlistmanager.h
    playlistmanager.cpp
    libraryscanner.h
    libraryscanner.cpp
    pulseaudioservice.h
    pulseaudioservice.cpp
    playbackcontroller.h
    playbackcontroller.cpp
    playlistmodel.h
    playlistmodel.cpp
    mprisadapter.h
    mprisadapter.cpp

    svgLogic/svgcreator.h
    svgLogic/svgcreator.cpp
    svgLogic/svgimageprovider.h
    svgLogic/seticons.h

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
    ${CMAKE_CURRENT_SOURCE_DIR}/svgLogic
)