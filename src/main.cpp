#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtQuickControls2/QQuickStyle>
#include "mainwindow.h"
#include "svgimageprovider.h"
#include "seticons.h"

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

    registerIcons(*provider); //function can be found in the seticons.h

    engine.addImageProvider("svgicons", provider);
    
    // Load QML
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    
    if (engine.rootObjects().isEmpty())
        return -1;
    
    return app.exec();
}