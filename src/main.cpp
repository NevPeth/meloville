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
    app.setApplicationName("Meloville");
    
    QQuickStyle::setStyle("Basic");
    
    MainWindow mainWindow;
    
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