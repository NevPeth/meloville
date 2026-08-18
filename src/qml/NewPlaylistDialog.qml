import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects

Item {
    id: root

    // Properties
    property string mode: "create"   // "create" or "edit"
    property string editName: ""
    property string editImagePath: ""  // absolute path or qrc

    // Signals to notify parent when closed
    signal accepted()
    signal rejected()
    signal deleted()

    // Internal state
    property string selectedImagePath: ""  // local file path from file dialog
    property string playlistName: ""

    function normalizeImageSource(path) {
        if (!path)
            return ""
        if (path.startsWith("file://"))
            return path
        if (path.startsWith("/"))
            return "file://" + path
        return path
    }

    // Overlay (dim background)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.7

        // Click outside dialog closes it
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
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) { event.accepted = true }
        }
    }

    // Main dialog frame
    Rectangle {
        id: dialogArea
        width: 650
        height: 440
        radius: 12
        color: "#121212"
        anchors.centerIn: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18

            // Title
            Text {
                text: mode === "create" ? "New Playlist" : "Edit Playlist"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Cover widget (image preview + upload button)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 200

                Rectangle {
                    id: imagePreview
                    width: 200
                    height: 200
                    radius: 12
                    color: "#222222"
                    border.color: "#444444"
                    border.width: 1
                    anchors.centerIn: parent

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: imagePreview.width
                            height: imagePreview.height
                            radius: imagePreview.radius
                        }
                    }

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: {
                            if (selectedImagePath !== "") {
                                return selectedImagePath
                            }
                            if (mode === "edit" && editImagePath !== "") {
                                return normalizeImageSource(editImagePath)
                            }
                            return "qrc:/icons/default.svg"
                        }
                        visible: source !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: coverImage.source === ""
                        text: "No Image"
                        color: "#888888"
                        font.pixelSize: 14
                    }
                }

                // Upload button (positioned outside image, like C++ version)
                Button {
                    id: uploadButton
                    anchors.right: imagePreview.right
                    anchors.bottom: imagePreview.bottom
                    anchors.rightMargin: -52
                    anchors.bottomMargin: -9
                    background: Item {}
                    width: 50
                    height: 50

                    contentItem: Image {
                        source: "image://svgicons/uploadIcon"
                        fillMode: Image.PreserveAspectFit
                    }

                    onClicked: fileDialog.open()
                }
            }

            // Playlist name input
            Text {
                text: "Playlist name"
                color: "white"
                font.pixelSize: 14
            }
            TextField {
                id: nameInput
                Layout.fillWidth: true
                placeholderText: "My Playlist"
                color: "white"
                background: Rectangle {
                    color: "#222222"
                    radius: 6
                }
                text: mode === "edit" ? editName : ""
                selectByMouse: true
            }

            Item { Layout.fillHeight: true } // spacer

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    id: deleteButton
                    text: "Delete"
                    visible: mode === "edit"
                    Layout.alignment: Qt.AlignLeft
                    background: Rectangle {
                        color: "#B3261E"
                        radius: 10
                    }
                    contentItem: Text {
                        text: deleteButton.text
                        color: "white"
                        font.bold: true
                    }
                    onClicked: {
                        backend.deletePlaylist(editName)
                        root.deleted()
                        closeDialog()
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    background: Rectangle {
                        color: "transparent"
                        radius: 10
                    }
                    contentItem: Text {
                        text: "Cancel"
                        color: "white"
                        font.bold: true
                    }
                    onClicked: closeDialog()
                }

                Button {
                    id: confirmButton
                    text: mode === "create" ? "Create" : "Save"
                    Layout.minimumWidth: 80
                    Layout.minimumHeight: 30
                    background: Rectangle {
                        color: "white"
                        radius: 10
                    }
                    contentItem: Text {
                        text: confirmButton.text
                        color: "black"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (nameInput.text.trim() === "") return
                        if (mode === "create") {
                            backend.playlistManager.createPlaylist(nameInput.text.trim(), selectedImagePath)
                        } else {
                            backend.editPlaylist(editName, nameInput.text.trim(), selectedImagePath)
                        }
                        root.accepted()
                        closeDialog()
                    }
                }
            }
        }
    }

    // File dialog for selecting image
    FileDialog {
        id: fileDialog
        title: "Choose Playlist Image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp)"]
        onAccepted: {
            selectedImagePath = selectedFile.toString()
        }
    }

    function closeDialog() {
        // Reset state
        selectedImagePath = ""
        nameInput.text = ""
        root.visible = false
        // Optionally emit rejected if not already
    }

    // When dialog becomes visible, focus the name input
    onVisibleChanged: {
        if (visible) {
            nameInput.forceActiveFocus()
            nameInput.selectAll()
            if (mode === "edit") {
                nameInput.text = editName
                // set selectedImagePath to empty so we know we haven't changed image
                selectedImagePath = ""
            } else {
                nameInput.text = ""
                selectedImagePath = ""
            }
        }
    }

    // Helper to open in create mode
    function openCreate() {
        mode = "create"
        visible = true
    }

    // Helper to open in edit mode
    function openEdit(name, imagePath) {
        mode = "edit"
        editName = name
        editImagePath = imagePath   // relative path stored in playlistManager
        visible = true
    }
}