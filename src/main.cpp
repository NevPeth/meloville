#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtQuickControls2/QQuickStyle>
#include "mainwindow.h"
#include "svgimageprovider.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    
    // Set application metadata
    app.setApplicationName("Meloville");
    
    // Set the Quick style
    QQuickStyle::setStyle("Basic");
    
    // Create the main window (backend logic)
    MainWindow mainWindow;
    
    // Create QML engine
    QQmlApplicationEngine engine;
    
    // Expose MainWindow to QML with a clear name
    engine.rootContext()->setContextProperty("backend", &mainWindow);

    auto* provider = new SvgImageProvider();
    provider->registerDualIcon("addPlaylistsIcon",
        ":/icons/addPlaylistsIcon.svg",
        Qt::white,
        Qt::black,
        QSize(70,70));

    provider->registerIcon("skip",
        ":/icons/skip.svg",
        Qt::white,
        QSize(70, 70));

    engine.addImageProvider("svgicons", provider);
    
    // Load QML
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    
    if (engine.rootObjects().isEmpty())
        return -1;
    
    return app.exec();
}