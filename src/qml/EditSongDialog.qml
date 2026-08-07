import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects

Item {
    id: root

    // ── Public API ────────────────────────────────────────────────────────────
    property int    libraryIndex:    -1
    property string songFilePath:    ""
    property string editTitle:       ""
    property string editArtist:      ""
    property string editAlbum:       ""
    property int    editTrackNumber: 0
    property string editCoverPath:   ""

    signal accepted()
    signal rejected()

    // ── Internal ──────────────────────────────────────────────────────────────
    property string selectedImagePath: ""

    function normalizeImageSource(path) {
        if (!path)                      return ""
        if (path.startsWith("file://")) return path
        if (path.startsWith("/"))       return "file://" + path
        return path
    }

    function openEdit(index, filePath, coverPath, title, artist, album, trackNumber) {
        libraryIndex       = index
        songFilePath       = filePath
        editCoverPath      = coverPath
        editTitle          = title
        editArtist         = artist
        editAlbum          = album
        editTrackNumber    = trackNumber
        selectedImagePath  = ""
        root.visible       = true
    }

    function closeDialog() {
        selectedImagePath = ""
        titleInput.text   = ""
        artistInput.text  = ""
        albumInput.text   = ""
        trackInput.text   = ""
        root.visible      = false
    }

    onVisibleChanged: {
        if (visible) {
            titleInput.text  = editTitle
            artistInput.text = editArtist
            albumInput.text  = editAlbum
            trackInput.text  = editTrackNumber > 0 ? editTrackNumber.toString() : ""
            selectedImagePath = ""
            titleInput.forceActiveFocus()
            titleInput.selectAll()
        }
    }

    // ── Dim overlay ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        "#000000"
        opacity:      0.6

        MouseArea {
            id: overlayMouseArea
            anchors.fill: parent
            hoverEnabled: true

            onClicked: function(mouse) {
                var p = dialogArea.mapFromItem(overlayMouseArea, mouse.x, mouse.y)
                if (!dialogArea.contains(p))
                    closeDialog()
                mouse.accepted = true
            }
        }
    }

    // ── Dialog box ────────────────────────────────────────────────────────────
    Rectangle {
        id: dialogArea
        width:  650
        height: 560
        radius: 12
        color:  "#121212"
        anchors.centerIn: parent

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 24
            spacing:         18

            // Title
            Text {
                text:             "Edit Song"
                color:            "white"
                font.pixelSize:   16
                font.bold:        true
                Layout.alignment: Qt.AlignHCenter
            }

            // ── Cover image + upload button ───────────────────────────────────
            Item {
                Layout.fillWidth:       true
                Layout.preferredHeight: 200

                Rectangle {
                    id: imagePreview
                    width:  200
                    height: 200
                    radius: 12
                    color:  "#222222"
                    border.color: "#444444"
                    border.width: 1
                    anchors.centerIn: parent

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width:  imagePreview.width
                            height: imagePreview.height
                            radius: imagePreview.radius
                        }
                    }

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        fillMode:     Image.PreserveAspectCrop
                        source: {
                            if (selectedImagePath !== "")
                                return selectedImagePath
                            if (editCoverPath !== "")
                                return normalizeImageSource(editCoverPath)
                            return ""
                        }
                        visible: source !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible:          coverImage.source === ""
                        text:             "No Image"
                        color:            "#888888"
                        font.pixelSize:   14
                    }
                }

                // Upload button — mirrors playlist dialog placement
                Button {
                    id: uploadButton
                    anchors.right:        imagePreview.right
                    anchors.bottom:       imagePreview.bottom
                    anchors.rightMargin:  -52
                    anchors.bottomMargin: -9
                    background: Item {}
                    width:  50
                    height: 50

                    contentItem: Image {
                        source:   "image://svgicons/uploadIcon"
                        fillMode: Image.PreserveAspectFit
                    }

                    onClicked: fileDialog.open()
                }
            }

            // ── Row 1: Title + Artist ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           "Title"
                        color:          "white"
                        font.pixelSize: 14
                    }
                    TextField {
                        id:               titleInput
                        Layout.fillWidth: true
                        placeholderText:  "Song title"
                        color:            "white"
                        selectByMouse:    true
                        background: Rectangle { color: "#222222"; radius: 6 }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           "Artist"
                        color:          "white"
                        font.pixelSize: 14
                    }
                    TextField {
                        id:               artistInput
                        Layout.fillWidth: true
                        placeholderText:  "Artist name"
                        color:            "white"
                        selectByMouse:    true
                        background: Rectangle { color: "#222222"; radius: 6 }
                    }
                }
            }

            // ── Row 2: Album + Track number ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text:           "Album"
                        color:          "white"
                        font.pixelSize: 14
                    }
                    TextField {
                        id:               albumInput
                        Layout.fillWidth: true
                        placeholderText:  "Album name"
                        color:            "white"
                        selectByMouse:    true
                        background: Rectangle { color: "#222222"; radius: 6 }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 140
                    spacing: 4

                    Text {
                        text:           "Track Number"
                        color:          "white"
                        font.pixelSize: 14
                    }
                    TextField {
                        id:               trackInput
                        Layout.fillWidth: true
                        placeholderText:  "1"
                        color:            "white"
                        selectByMouse:    true
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator:        IntValidator { bottom: 0; top: 9999 }
                        background: Rectangle { color: "#222222"; radius: 6 }
                    }
                }
            }

            Item { Layout.fillHeight: true } // spacer

            // ── Action buttons ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    background: Rectangle {
                        color:  "transparent"
                        radius: 10
                    }
                    contentItem: Text {
                        text:                "Cancel"
                        color:               "white"
                        font.bold:           true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    onClicked: {
                        root.rejected()
                        closeDialog()
                    }
                }

                Button {
                    id: saveButton
                    text: "Save"
                    Layout.minimumWidth:  80
                    Layout.minimumHeight: 30
                    background: Rectangle {
                        color:  "white"
                        radius: 10
                    }
                    contentItem: Text {
                        text:                saveButton.text
                        color:               "black"
                        font.bold:           true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    onClicked: {
                        if (titleInput.text.trim() === "") return

                        function toLocalPath(uri) {
                            if (!uri) return ""
                            var s = uri.toString()
                            if (s.startsWith("file:///"))
                                return s.startsWith("file:////") ? s.slice(7) : s.slice(7)
                            if (s.startsWith("file://"))
                                return s.slice(7)
                            return s
                        }

                        var cleanImagePath = toLocalPath(root.selectedImagePath)
                        var cleanFilePath  = toLocalPath(root.songFilePath)

                        backend.saveSongEdits(
                            root.libraryIndex,
                            titleInput.text.trim(),
                            artistInput.text.trim(),
                            albumInput.text.trim(),
                            parseInt(trackInput.text) || 0,
                            cleanImagePath
                        )

                        root.accepted()
                        closeDialog()
                    }
                }
            }
        }
    }

    // ── File picker ───────────────────────────────────────────────────────────
    FileDialog {
        id:          fileDialog
        title:       "Choose Song Cover Image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp)"]
        onAccepted:  root.selectedImagePath = selectedFile.toString()
    }
}