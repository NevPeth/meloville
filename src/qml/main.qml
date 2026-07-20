import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: appWindow
    visible: true
    width: 900
    height: 600
    title: "Meloville"
    color: "#121212"
    flags: Qt.FramelessWindowHint
    
    // Stack view to manage pages
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: loadPageComponent
    }
    
    Component {
        id: loadPageComponent
        LoadPage {}
    }
    
    // Main page component (placeholder for when music is loaded)
    Component {
        id: mainPageComponent
        Rectangle {
            color: "#121212"
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    text: "Music Player"
                    color: "white"
                    font.pixelSize: 24
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "Your music is loaded!"
                    color: "#a3a3a3"
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
    
    // Connection to switch pages when library is loaded
    Connections {
        target: backend
        function onLibraryLoaded() {
            stackView.push(mainPageComponent)
        }
    }
}