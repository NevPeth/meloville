import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: loadedSongsPage
    color: "#121212"

    signal continueButtonClicked()

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

        Button {
            id: continueButton
            text: "Continue"
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumWidth: 220
            Layout.minimumHeight: 42
            enabled: !backend.scanning
            
            background: Rectangle {
                color: continueButton.hovered ? "#2a2a2a" : "#1f1f1f"
                border.color: "#333333"
                border.width: 1
                radius: 8
            }
            
            contentItem: Text {
                text: continueButton.text
                color: "white"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                continueButtonClicked()
            }
            
            // Just sets cursor
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.clicked()
            }
        }
    }
}