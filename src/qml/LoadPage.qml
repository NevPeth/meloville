import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: loadPage
    color: "#121212"
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        
        // Title
        Label {
            text: "Load Your Music"
            font.pixelSize: 24
            font.weight: Font.DemiBold
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Open Folder Button
        Button {
            id: openFolderButton
            text: "Open Music Folder"
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumWidth: 220
            Layout.minimumHeight: 42
            enabled: !backend.scanning
            
            background: Rectangle {
                color: openFolderButton.hovered ? "#2a2a2a" : "#1f1f1f"
                border.color: "#333333"
                border.width: 1
                radius: 8
            }
            
            contentItem: Text {
                text: openFolderButton.text
                color: "white"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                // Call the C++ backend's openFolder method
                if (typeof backend !== 'undefined') {
                    backend.openFolder()
                } else {
                    console.log("Backend not available")
                }
            }
            
            // Set cursor shape using MouseArea
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.clicked()
            }
        }

        ColumnLayout {
            spacing: 5
            visible: backend.scanning
            Layout.fillWidth: true
            Layout.preferredWidth: 300
            Layout.alignment: Qt.AlignHCenter

            ProgressBar {
                id: progressBar
                Layout.fillWidth: true
                value: backend.progress
                background: Rectangle {
                    color: "#2a2a2a"
                    radius: 4
                }
                contentItem: Rectangle {
                    color: "#4CAF50"
                    radius: 4
                    width: progressBar.visualPosition * parent.width
                }
            }
            
            Label {
                text: backend.statusMessage
                color: "#a3a3a3"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
        
        // Supported formats label
        Label {
            text: "Supported formats include MP3, FLAC, WAV, OGG, AAC, and more."
            font.pixelSize: 11
            color: "#a3a3a3"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}