import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: popup
    modal: false
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    property int currentVisibleIndex: -1
    property var playlistModel: []
    property bool showRemoveAction: false
    property string filterText: ""

    signal addToPlaylist(string playlistName)
    signal removeFromPlaylist()
    signal editSong()

    width: 210
    implicitHeight: columnLayout.implicitHeight
    padding: 0

    background: Rectangle {
        color: "#121212"
    }

    ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        spacing: 0

        // ----- "Add to playlist" -----
        ItemDelegate {
            id: addToPlaylistDelegate
            Layout.fillWidth: true
            leftPadding: 24
            rightPadding: 24
            topPadding: 8
            bottomPadding: 8
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

        // ----- "Edit playlist" -----
        ItemDelegate {
            Layout.fillWidth: true
            leftPadding: 24
            rightPadding: 24
            topPadding: 8
            bottomPadding: 8
            font.pixelSize: 14
            text: "Edit playlist"

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

        // ----- "Remove from this playlist" -----
        ItemDelegate {
            visible: popup.showRemoveAction
            Layout.fillWidth: true
            leftPadding: 24
            rightPadding: 24
            topPadding: 8
            bottomPadding: 8
            font.pixelSize: 14
            text: "Remove from playlist"

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
                popup.removeFromPlaylist()
                popup.close()
            }
        }
    }

    // ---- Submenu ----
    Popup {
        id: subMenu
        modal: false
        closePolicy: Popup.NoAutoClose
        parent: popup.parent
        z: 1

        x: popup.x - width
        y: popup.y - 35

        width: 240
        height: Math.min(400, Math.max(200, subContent.implicitHeight + 20))
        padding: 0

        property bool containsMouse: false

        background: Rectangle {
            color: "#121212"
        }

        ColumnLayout {
            id: subContent
            anchors.fill: parent
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
                    leftPadding: 24
                    rightPadding: 24
                    topPadding: 8
                    bottomPadding: 8
                    font.pixelSize: 14
                    text: modelData

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

        HoverHandler {
            onHoveredChanged: {
                subMenu.containsMouse = hovered
                if (hovered) {
                    closeTimer.stop()
                } else if (!addToPlaylistDelegate.hovered) {
                    closeTimer.start()
                }
            }
        }

        onOpened: closeTimer.stop()
        onClosed: {
            subMenu.containsMouse = false
            closeTimer.stop()
        }

        Timer {
            id: closeTimer
            interval: 300   // FIX #2: slightly more forgiving for quick movements
            onTriggered: {
                // FIX #1: now actually checks the submenu hover state
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