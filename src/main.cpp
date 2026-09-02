#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtQuickControls2/QQuickStyle>
#include "mainwindow.h"
#include "svgimageprovider.h"
#include "seticons.h"
#include "youtuberesolver.h"

/*
    Just sets up the mainWindow to be called from the main.qml (unlike their name, main.qml is the frontend while mainWindow is the backend logic).
*/
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("Meloville");
    
    QQuickStyle::setStyle("Basic");
    
    MainWindow mainWindow;
    
    QQmlApplicationEngine engine;
    
    // Although this is the main.cpp, all music player logic and 
    // really the "backend" of this code is mainwindow.cpp
    engine.rootContext()->setContextProperty("backend", &mainWindow);

    YouTubeResolver youtubeResolver;

    engine.rootContext()->setContextProperty("youtubeResolver",&youtubeResolver);

    auto* provider = new SvgImageProvider();

    registerIcons(*provider); //function can be found in the seticons.h

    engine.addImageProvider("svgicons", provider);
    
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    
    if (engine.rootObjects().isEmpty())
        return -1;
    
    return app.exec();
}