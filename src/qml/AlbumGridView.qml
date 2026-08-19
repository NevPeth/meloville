import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent

    // ── Album grid ──────────────────────────────────────────────────────────
    GridView {
        id: albumGrid
        anchors.fill: parent
        clip: true

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        model: backend.albumModel

        readonly property int minTileWidth: 184
        readonly property int cellPad:      12   // kCellPadding
        readonly property int textBlock:    44   // kTextBlockHeight
        readonly property int columns:      Math.max(1, Math.floor(width / minTileWidth))
        readonly property int tileWidth:    Math.floor(width / columns)
        readonly property int coverSize:    Math.min(240, Math.max(110, tileWidth - cellPad * 2))
        readonly property int tileHeight:   coverSize + cellPad + textBlock + 8

        cellWidth:  tileWidth
        cellHeight: tileHeight

        delegate: Item {
            width:  albumGrid.cellWidth
            height: albumGrid.cellHeight

            HoverHandler { id: hov }

            // hover/selection background
            Rectangle {
                anchors {
                    fill: parent
                    margins: 2
                }
                radius: 10
                color: hov.hovered ? "#0f0f0f" : "transparent"
            }

            // cover art
            Item {
                id: coverItem
                x: (parent.width - albumGrid.coverSize) / 2
                y: albumGrid.cellPad
                width:  albumGrid.coverSize
                height: albumGrid.coverSize

                // Rounded clip mask
                Rectangle {
                    id: roundMask
                    anchors.fill: parent
                    radius: 8
                    visible: false
                }

                Image {
                    id: coverImg
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: model.coverPath
                            ? "file://" + model.coverPath
                            : ""        // triggers the placeholder below
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: roundMask
                    }
                }

                // Placeholder for missing art — matches the ♫ tile in AlbumDelegate
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "#2a2a2a"
                    visible: coverImg.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: "♫"
                        font.pixelSize: 32
                        color: "#666666"
                    }
                }
            }

            // ── title ─────────────────────────────────────────────────────
            Text {
                id: titleText
                x: albumGrid.cellPad / 2
                y: coverItem.y + coverItem.height + 8
                width: parent.width - albumGrid.cellPad
                text: model.title
                color: "white"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            // ── artist ────────────────────────────────────────────────────
            Text {
                x: albumGrid.cellPad / 2
                y: titleText.y + 18
                width: parent.width - albumGrid.cellPad
                text: model.artist
                color: "#b3b3b3"
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            // ── tap to open album ─────────────────────────────────────────
            MouseArea {
                anchors.fill: parent
                onClicked: backend.loadAlbumView(model.title, model.artist, model.coverPath)
            }
        }
    }
}