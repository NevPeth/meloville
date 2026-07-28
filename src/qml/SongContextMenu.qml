// SongContextMenu.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: popup
    modal: false
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    property int currentVisibleIndex: -1
    property var playlistModel: []
    property bool showRemoveAction: false   // kept for compatibility
    property string filterText: ""

    signal addToPlaylist(string playlistName)
    signal removeFromPlaylist()
    signal editSong()

    width: 240
    implicitHeight: columnLayout.implicitHeight + 20

    background: Rectangle {
        color: "#121212"
        radius: 4
        border.color: "#333333"
        border.width: 1
    }

    ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        // "Add to playlist" – hover opens submenu
        ItemDelegate {
            id: addToPlaylistDelegate
            Layout.fillWidth: true
            height: 32
            font.pixelSize: 14

            contentItem: RowLayout {
                spacing: 8
                Text {
                    text: "Add to playlist"
                    color: "white"
                    font: addToPlaylistDelegate.font
                    Layout.fillWidth: true
                }
                Text {
                    text: "◀"
                    color: "#888888"
                    font.pixelSize: 12
                }
            }

            background: Rectangle {
                color: parent.hovered ? "#222222" : "transparent"
            }

            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop()
                    subMenu.open()
                } else {
                    closeTimer.start()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#333333"
        }

        // "Edit playlist" – click action
        ItemDelegate {
            Layout.fillWidth: true
            height: 32
            text: "Edit playlist"
            font.pixelSize: 14

            contentItem: Text {
                text: parent.text
                font: parent.font
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: "white"
            }

            background: Rectangle {
                color: parent.hovered ? "#222222" : "transparent"
            }

            onClicked: {
                popup.editSong()
                popup.close()
            }
        }
    }

    // ---- Submenu (playlist list) ----
    Popup {
        id: subMenu
        modal: false
        closePolicy: Popup.NoAutoClose
        parent: popup.parent
        z: 1

        x: popup.x - width - 2
        y: popup.y + 4

        width: 240
        height: Math.min(400, Math.max(200, subContent.implicitHeight + 20))

        background: Rectangle {
            color: "#121212"
            radius: 4
            border.color: "#333333"
            border.width: 1
        }

        ColumnLayout {
            id: subContent
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.margins: 4
                placeholderText: "Search playlists..."
                color: "white"
                font.pixelSize: 14

                background: Rectangle {
                    color: "#2a2a2a"
                    radius: 4
                }

                Image {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    source: "qrc:/icons/closeIcon.svg"
                    visible: parent.text.length > 0
                    opacity: 0.5
                    MouseArea {
                        anchors.fill: parent
                        onClicked: parent.parent.text = ""
                    }
                }

                onTextChanged: popup.filterText = text
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                property var filteredModel: {
                    if (popup.filterText === "")
                        return popup.playlistModel
                    return popup.playlistModel.filter(function(name) {
                        return name.toLowerCase().indexOf(popup.filterText.toLowerCase()) !== -1
                    })
                }

                model: filteredModel
                delegate: ItemDelegate {
                    width: listView.width
                    height: 32
                    text: modelData
                    font.pixelSize: 14

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        color: "white"
                    }

                    background: Rectangle {
                        color: parent.hovered ? "#222222" : "transparent"
                    }

                    onClicked: {
                        popup.addToPlaylist(modelData)
                        popup.close()
                        subMenu.close()
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 8
                }

                Text {
                    anchors.centerIn: parent
                    text: "No playlists found"
                    color: "#666666"
                    font.pixelSize: 14
                    visible: listView.count === 0 && popup.playlistModel.length > 0
                }
                Text {
                    anchors.centerIn: parent
                    text: "No playlists yet"
                    color: "#666666"
                    font.pixelSize: 14
                    visible: popup.playlistModel.length === 0
                }
            }
        }

        // Mouse area to detect hover inside the submenu without blocking clicks
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: false
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton   // do not consume mouse button events

            onEntered: closeTimer.stop()
            onExited: closeTimer.start()
        }

        Timer {
            id: closeTimer
            interval: 200
            onTriggered: {
                if (!addToPlaylistDelegate.hovered && !subMenu.containsMouse) {
                    subMenu.close()
                }
            }
        }

        Connections {
            target: popup
            function onClosed() {
                subMenu.close()
            }
        }
    }
}