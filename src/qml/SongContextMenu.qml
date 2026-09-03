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
    property string currentSongArtist: ""
    property string currentSongTitle: ""
    property string shareState: "idle"  // "idle" | "fetching" | "copied" | "failed" (for the "Share song" action)

    signal addToPlaylist(string playlistName)
    signal removeFromPlaylist()
    signal editSong()

    Connections {
        target: youtubeResolver

        function onLinkCopied() {
            popup.shareState = "copied"
            autoCloseTimer.start()
        }
    }

    Connections {
        target: youtubeResolver

        function onFailedToCopyLink() {
            popup.shareState = "failed"
            autoCloseTimer.start()
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 500
        onTriggered: popup.close()
    }

    onClosed: popup.shareState = "idle"

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
                    subMenu.positionSubMenu()
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

        ItemDelegate {
            id: shareSongDelegate
            Layout.fillWidth: true
            leftPadding: 24
            rightPadding: 24
            topPadding: 8
            bottomPadding: 8
            font.pixelSize: 14
            enabled: popup.shareState === "idle"

            contentItem: RowLayout {
                spacing: 8

                // Spinner (only visible while fetching)
                Item {
                    width: 14
                    height: 14
                    visible: popup.shareState === "fetching"

                    Canvas {
                        id: spinnerCanvas
                        anchors.fill: parent
                        antialiasing: true

                        // t goes 0 → 1 continuously, driving everything
                        property real t: 0

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()

                            var cx = width / 2
                            var cy = height / 2
                            var r  = width / 2 - 1.0   // radius, inset by stroke/2

                            // --- Replicate the CSS dash keyframe exactly ---
                            // At t=0:   dashoffset=187  → arc ≈ 0  (tiny sliver)
                            // At t=0.5: dashoffset=~47  → arc ≈ 270° (3/4 circle)
                            // At t=1:   dashoffset=187  → arc ≈ 0  (tiny sliver)
                            // Arc fraction: offset/187 → sweep = (1 - frac) * 2π
                            // Using ease-in-out sine to match CSS ease-in-out
                            var ease = t < 0.5
                                ? 2 * t * t
                                : 1 - Math.pow(-2 * t + 2, 2) / 2  // ease-in-out quad

                            // sweep oscillates 5° → 270° → 5°
                            var minSweep = 5  * Math.PI / 180
                            var maxSweep = 270 * Math.PI / 180
                            var sweep = minSweep + (maxSweep - minSweep) * Math.sin(ease * Math.PI)

                            // The arc also self-rotates 0→135° in first half, 135→450° total
                            // This keeps the HEAD advancing while the tail chases
                            var arcSelfRotate = (ease * 450) * Math.PI / 180

                            // Container rotation: 0 → 270° per cycle (linear)
                            var containerRot = t * 270 * Math.PI / 180

                            // Start at top (−π/2) + both rotations
                            var startAngle = -Math.PI / 2 + containerRot + arcSelfRotate
                            var endAngle   = startAngle + sweep

                            ctx.beginPath()
                            ctx.arc(cx, cy, r, startAngle, endAngle, false)
                            ctx.strokeStyle  = "white"
                            ctx.lineWidth    = 1.5
                            ctx.lineCap      = "round"
                            ctx.stroke()
                        }

                        NumberAnimation on t {
                            from: 0
                            to: 1
                            duration: 1400   // matches the canonical 1.4s
                            loops: Animation.Infinite
                            running: popup.shareState === "fetching"
                        }

                        onTChanged: requestPaint()
                    }
                }

                Text {
                    text: popup.shareState === "idle"    ? "Share song"
                        : popup.shareState === "fetching" ? "Fetching song..."
                        : popup.shareState === "copied"   ? "Link copied!"
                        :                                   "Failed to fetch link"
                    color: popup.shareState === "copied"  ? "#1db954"
                        : popup.shareState === "failed"  ? "#e05555"
                        : "white"
                    font: shareSongDelegate.font
                    Layout.fillWidth: true
                }
            }

            background: Rectangle {
                color: parent.hovered && popup.shareState === "idle" ? "#222222" : "transparent"
            }

            onClicked: {
                popup.shareState = "fetching"
                youtubeResolver.search(popup.currentSongArtist, popup.currentSongTitle)
            }
        }

        ItemDelegate {
            Layout.fillWidth: true
            leftPadding: 24
            rightPadding: 24
            topPadding: 8
            bottomPadding: 8
            font.pixelSize: 14
            text: "Edit song info"

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
        implicitHeight: subContent.implicitHeight
        height: implicitHeight
        padding: 0

        function positionSubMenu() {
            var parentItem = popup.parent
            var newX = popup.x - width
            var newY = popup.y - 35
            // If it would go off the left edge, open to the right instead.
            if (newX < 0)
                newX = popup.x + popup.width
            // Clamp horizontally.
            if (newX + width > parentItem.width)
                newX = parentItem.width - width
            // Clamp vertically.
            if (newY < 74)
                newY = 74

            if (newY + height > parentItem.height - 95)
                newY = parentItem.height - height - 95

            x = newX
            y = newY
        }

        property bool containsMouse: false

        background: Rectangle {
            color: "#121212"
        }

        ColumnLayout {
            id: subContent
            width: parent.width
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
                }

                Image {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    source: "image://svgicons/closeIcon"
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

                readonly property int delegateHeight: 33
                readonly property int maxListHeight: 270 - (searchField.height + 4 /*margins*/ * 2)

                implicitHeight: Math.min(count===0 ? delegateHeight+5 : count * delegateHeight, maxListHeight)

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