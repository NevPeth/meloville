import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQml.Models //2.15

ApplicationWindow {
    id: appWindow
    visible: true
    width: 1280
    height: 720
    title: "Meloville"
    color: "#121212"
    flags: Qt.FramelessWindowHint
    
    // Stack view to manage pages
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: backend.libraryPresent ? mainPageComponent : loadPageComponent

        popEnter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 200
            }
        }

        popExit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 200
            }
        }
    }

    NewPlaylistDialog {
        id: playlistDialog
        anchors.fill: parent
        visible: false   // initially hidden

        onAccepted: {
            // Optionally refresh playlist list or other UI
            // The backend will emit playlistsChanged, so we can update the ListView.
        }
        onRejected: {
            // just close
        }
        onDeleted: {
            // The backend will handle deletion; we might want to close playlist view if editing
        }
    }

    SongContextMenu {
        id: contextMenu

        onAddToPlaylist: function(playlistName) {
            backend.addToPlaylist(currentVisibleIndex, playlistName)
        }
        onRemoveFromPlaylist: backend.removeFromCurrentPlaylist(currentVisibleIndex)
        onEditSong: backend.editCurrentSong(currentVisibleIndex)
    }

    Connections {
        target: backend

        function onOpenContextMenuRequested(visibleIndex, x, y) {
            contextMenu.currentVisibleIndex = visibleIndex
            contextMenu.playlistModel = backend.playlistNames
            contextMenu.showRemoveAction = backend.isInPlaylistView
            contextMenu.filterText = ""

            var local = appWindow.contentItem.mapFromGlobal(x, y)

            var popupWidth = contextMenu.width
            var gap = 8

            var posX = local.x - popupWidth
            var posY = local.y + gap

            contextMenu.x = posX
            contextMenu.y = posY

            contextMenu.open()
        }
    }
    
    Component {
        id: loadPageComponent
        LoadPage {}
    }

    Component {
        id: loadedSongsPageComponent
        LoadedSongsPage {
            onContinueButtonClicked: {
                stackView.replace(mainPageComponent)
            }
        }
    }

    Component {
        id: bigPicturePageComponent
        BigPicturePage {
            onExitBigPicture: stackView.pop()
        }
    }
    property int playlistButtonSize: 65
    property int libraryButtonSize: 65
    property string currentPlaylistName: ""
    property string currentPlaylistCover: ""
    Component {
        id: mainPageComponent
        
        Rectangle {
            id: mainPageRoot
            color: "#121212"
            DelegateModel {
                id: visualModel
                model: backend.songModel
                delegate: songDelegate
            }
            Component {
                id: songDelegate

                // The outer item is the DropArea — it receives drags from other delegates
                DropArea {
                    id: delegateRoot

                    property int visualIndex: DelegateModel.itemsIndex

                    width:  ListView.view ? ListView.view.width : 0
                    height: 62

                    // ── Live visual reorder: fires as the dragged item enters this delegate ──
                    onEntered: function(drag) {
                        var from = drag.source.DelegateModel.itemsIndex
                        var to   = delegateRoot.DelegateModel.itemsIndex
                        visualModel.items.move(from, to)
                    }

                    // ── The draggable content ──
                    Rectangle {
                        id: songRow
                        width:  parent.width
                        height: 62
                        color:  "transparent"

                        // Lift the row visually while dragging
                        Drag.active:     dragArea.held
                        Drag.source:     delegateRoot   // expose DelegateModel.itemsIndex to DropArea.onEntered
                        Drag.hotSpot.x:  width  / 2
                        Drag.hotSpot.y:  height / 2

                        states: State {
                            when: dragArea.held
                            ParentChange {
                                target: songRow
                                parent: listViewSongs   // reparent so it floats above everything
                            }
                            AnchorChanges {
                                target: songRow
                                anchors { horizontalCenter: undefined; verticalCenter: undefined }
                            }
                        }

                        // Background
                        Rectangle {
                            anchors.fill: parent
                            color: isPlaying          ? "#2a2a2a"
                                : isActive           ? "#2f2f2f"
                                : hoverHandler.hovered ? "#202020"
                                : "#181818"
                        }

                        // ── drag handle ──────────────────────────────────────────────────
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            enabled: backend.dragReorderAllowed && !backend.filterText
                            drag.target:         held ? songRow : undefined
                            drag.axis:           Drag.YAxis
                            drag.filterChildren: true
                            drag.threshold:      10
                            property bool held: false
                            property int  startIndex: -1

                            // ── Auto-scroll state ────────────────────────────────────────────────
                            property real scrollSpeed: 0   // px per timer tick; negative = up

                            Timer {
                                id: autoScrollTimer
                                interval: 16               // ~60 fps
                                repeat:   true
                                running:  dragArea.held && dragArea.scrollSpeed !== 0
                                onTriggered: {
                                    var newY = listViewSongs.contentY + dragArea.scrollSpeed
                                    // clamp to valid range
                                    var maxY = listViewSongs.contentHeight - listViewSongs.height
                                    listViewSongs.contentY = Math.max(-270, Math.min(newY, maxY))
                                }
                            }

                            onPressed: {
                                startIndex = delegateRoot.DelegateModel.itemsIndex
                                held = true
                                listViewSongs.interactive = false
                                listViewSongs.dropIndicatorVisible = true
                            }

                            onPositionChanged: {
                                if (!held) return

                                // Update drop indicator
                                var posInList = songRow.mapToItem(listViewSongs, 0, 0)
                                listViewSongs.dropIndicatorY = posInList.y

                                // ── Auto-scroll ──────────────────────────────────────────────────
                                var threshold = 120
                                var viewportY = mapToItem(listViewSongs, mouse.x, mouse.y).y

                                if (viewportY < threshold) {
                                    // Scale speed: faster the closer to the edge
                                    scrollSpeed = -((threshold - viewportY) / threshold) * 15
                                } else if (viewportY > listViewSongs.height - threshold) {
                                    scrollSpeed = ((viewportY - (listViewSongs.height - threshold)) / threshold) * 15
                                } else {
                                    scrollSpeed = 0
                                }
                            }

                            onReleased: {
                                if (held) {
                                    held = false
                                    scrollSpeed = 0
                                    listViewSongs.interactive = true
                                    listViewSongs.dropIndicatorVisible = false

                                    var endIndex = delegateRoot.DelegateModel.itemsIndex
                                    if (startIndex !== endIndex)
                                        backend.reorderPlaylist(startIndex, endIndex)
                                    startIndex = -1
                                }
                            }

                            onCanceled: {
                                held = false
                                scrollSpeed = 0
                                listViewSongs.interactive = true
                                listViewSongs.dropIndicatorVisible = false
                                startIndex = -1
                            }
                        }

                        property bool isPlaying: model.isPlaying
                        property bool isPaused:  model.isPaused
                        property bool isActive:  model.isActive

                        // ── play/pause area ──────────────────────────────────────────────
                        Item {
                            id: playArea
                            x: 0; y: 0; width: 50; height: parent.height

                            Text {
                                anchors.centerIn: parent
                                visible: !songRow.isPlaying && !hoverHandler.hovered
                                text:    (delegateRoot.DelegateModel.itemsIndex + 1).toString()
                                color: "#b3b3b3"; font.pixelSize: 13
                            }
                            Image {
                                anchors.centerIn: parent
                                visible: songRow.isPlaying || hoverHandler.hovered
                                width: 22; height: 22
                                source: (songRow.isPlaying && !songRow.isPaused)
                                        ? "qrc:/icons/menuPauseIcon.svg"
                                        : "qrc:/icons/menuPlayIcon.svg"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (songRow.isPlaying)
                                        backend.playAndPause()
                                    else
                                        backend.playSongAtVisibleIndex(delegateRoot.DelegateModel.itemsIndex)
                                }
                            }
                        }

                        // ── album cover ──────────────────────────────────────────────────
                        Image {
                            id: coverImage
                            x: 50
                            y: (parent.height - height) / 2
                            width: 50; height: 50
                            fillMode: Image.PreserveAspectCrop
                            source: model.coverPath !== ""
                                    ? "file://" + model.coverPath
                                    : "qrc:/images/default_cover.png"
                        }

                        // ── title + artist ───────────────────────────────────────────────
                        Column {
                            x: coverImage.x + coverImage.width + 10
                            width: parent.width - x - 120
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: model.title
                                color: "white"; font.pixelSize: 13; font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: model.artist
                                color: "#b3b3b3"; font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        // ── duration ─────────────────────────────────────────────────────
                        Text {
                            x: parent.width - 105
                            width: 60
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.duration
                            color: "#b3b3b3"; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // ── dots / context menu ──────────────────────────────────────────
                        Item {
                            id: menuArea
                            x: parent.width - 45
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30; height: 30

                            Image {
                                anchors.centerIn: parent
                                width: 18; height: 4
                                source: "image://svgicons/dots"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var gp = menuArea.mapToGlobal(0, 0)
                                    backend.openSongContextMenu(delegateRoot.DelegateModel.itemsIndex, gp.x, gp.y)
                                }
                            }
                        }
                        

                        HoverHandler { id: hoverHandler }

                        }
                    }
                }
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                // margins are 0 by default in QML

                TapHandler {
                    onTapped: searchField.focus = false
                }

                // -------- SIDEBAR + RIGHT CONTENT (horizontal) --------
                RowLayout {
                    id: horizontalLayoutMain
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // --- SIDEBAR (frameSidebar) ---
                    Rectangle {
                        id: frameSidebar
                        Layout.preferredWidth: 65
                        Layout.minimumWidth: 65
                        Layout.maximumWidth: 65
                        Layout.fillHeight: true
                        color: "transparent"
                        
                        ColumnLayout {
                            id: layoutSidebar
                            anchors.fill: parent
                            spacing: 0

                            // Add Playlist button
                            
                            Button {
                                id: btnAddPlaylist

                                Layout.preferredWidth: playlistButtonSize
                                Layout.preferredHeight: playlistButtonSize
                                Layout.maximumWidth: playlistButtonSize
                                Layout.maximumHeight: playlistButtonSize
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

                                background: Item {}

                                icon.width: playlistButtonSize
                                icon.height: playlistButtonSize

                                contentItem: Image {
                                    source: "image://svgicons/addPlaylistsIcon"
                                    width: playlistButtonSize
                                    height: playlistButtonSize
                                    fillMode: Image.PreserveAspectFit
                                }

                                    onClicked: playlistDialog.openCreate()
                            }

                            Button {
                                id: btnLibrary

                                Layout.preferredWidth: libraryButtonSize
                                Layout.preferredHeight: libraryButtonSize
                                Layout.maximumWidth: libraryButtonSize
                                Layout.maximumHeight: libraryButtonSize
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                                Layout.topMargin: -10

                                background: Item {}

                                icon.width: libraryButtonSize
                                icon.height: libraryButtonSize

                                contentItem: Image {
                                    source: "image://svgicons/libraryIcon"
                                    width: libraryButtonSize
                                    height: libraryButtonSize
                                    fillMode: Image.PreserveAspectFit
                                }

                                onClicked: backend.returnToLibrary()
                            }

                            ListView {
                                id: listWidgetPlaylists
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.topMargin: 0
                                Layout.minimumWidth: 60
                                Layout.maximumWidth: 60
                                Layout.leftMargin: 8
                                clip: true
                                spacing: 7
                                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                                delegate: Rectangle {
                                    width: 53
                                    height: 53
                                    radius: 4
                                    color: "transparent"

                                    // Highlight when this playlist is selected (optional)
                                    property bool isSelected: backend.viewingPlaylist === model.name

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: isSelected ? "#2a2a2a" : "transparent"
                                    }

                                    // Image with rounded corners
                                    Image {
                                        id: playlistImage
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        fillMode: Image.PreserveAspectCrop
                                        source: model.imagePath ? model.imagePath : "qrc:/images/default_cover.png"
                                        visible: source !== ""
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: playlistImage.width
                                                height: playlistImage.height
                                                radius: 4
                                            }
                                        }
                                    }

                                    // Click area
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            backend.loadPlaylistView(model.name)
                                        }
                                    }
                                }

                                TapHandler {
                                    onTapped: searchField.focus = false
                                }

                                model: backend.playlistModel
                            }
                        }
                    }

                    // --- RIGHT CONTENT (layoutRightContent) ---
                    ColumnLayout {
                        id: layoutRightContent
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        // playlistInfo — visible: false on startup, omitted

                        // albumInfo — visible: false on startup, omitted

                        Rectangle {
                            id: libraryHeader
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            Layout.minimumHeight: 50
                            Layout.maximumHeight: 50
                            visible: !backend.isInPlaylistView
                            color: "transparent"

                            RowLayout {
                                id: currentLibraryHeader
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                Text {
                                    id: currentLibraryLabel
                                    text: "Library"
                                    font.pixelSize: 22
                                    font.bold: true
                                    color: "white"
                                }

                                // push search right
                                Item { Layout.fillWidth: true }

                                // searchField
                                Rectangle {
                                    Layout.preferredWidth: 500
                                    Layout.preferredHeight: 32
                                    radius: 16
                                    color: "#222222"

                                    TextInput {
                                        id: searchField
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "white"
                                        font.pixelSize: 13

                                        onTextChanged: backend.filterSongsAndAlbums(text)

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 0
                                            verticalAlignment: Text.AlignVCenter
                                            text: "Search songs..."
                                            color: "#888888"
                                            font.pixelSize: 13
                                            visible: searchField.text.length === 0 && !searchField.activeFocus
                                        }
                                    }
                                }
                            }
                        }

                        // ── Sticky playlist bar (overlays the top of listViewSongs) ────────────
                        Rectangle {
                            id: stickyPlaylistBar

                            // Only relevant when in playlist view
                            visible: backend.isInPlaylistView

                            parent: mainPageRoot
                            x: frameSidebar.width
                            y: libraryHeader.visible ? libraryHeader.height : 0
                            width: layoutRightContent.width
                            height: 50

                            readonly property real heroHeight: 270
                            opacity: Math.min(1.0, Math.max(0.0,
                                (listViewSongs.contentY + heroHeight) / 150
                            ))

                            color: "#111111"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 12

                                Text {
                                    text: currentPlaylistName
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 500
                                    Layout.preferredHeight: 32
                                    radius: 16
                                    color: "#222222"

                                    TextInput {
                                        id: stickySearchField
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "white"
                                        font.pixelSize: 13

                                        //onTextChanged: backend.filterSongsAndAlbums(text)

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: "Search playlist..."
                                            color: "#666666"
                                            font.pixelSize: 13
                                            visible: stickySearchField.text.length === 0 && !stickySearchField.activeFocus
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            id: listViewSongs
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 150
                            clip: true
                            ScrollBar.vertical:   ScrollBar { policy: ScrollBar.AsNeeded }
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                            // property int draggedIndex: -1
                            // property int dropIndex: -1

                            // ----- Pixel‑accurate scrolling on Wayland -----
                            pixelAligned: true

                            boundsBehavior: Flickable.StopAtBounds
                            boundsMovement: Flickable.StopAtBounds

                            property real velocity: 0
                            property real threshold: 40

                            property real dropIndicatorY: 0
                            property bool dropIndicatorVisible: false

                            // The indicator itself (place it inside the ListView, but not inside a delegate)
                            Rectangle {
                                id: dropIndicator
                                visible: listViewSongs.dropIndicatorVisible
                                x: 0
                                y: listViewSongs.dropIndicatorY
                                width: listViewSongs.width
                                height: 2
                                color: "white"
                                opacity: 0.85
                                z: 5

                                Behavior on y {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }
                            }

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                                onWheel: function(event) {
                                    var delta = event.pixelDelta.y !== 0
                                            ? event.pixelDelta.y
                                            : event.angleDelta.y / 4

                                    if (Math.abs(delta) < listViewSongs.threshold) {
                                        // Small gestures stop almost immediately.
                                        listViewSongs.velocity += delta
                                    } else {
                                        // Larger gestures get extra momentum.
                                        var excess = Math.abs(delta) - listViewSongs.threshold
                                        listViewSongs.velocity += delta + Math.sign(delta) * excess * 0.8
                                    }

                                    event.accepted = true
                                }
                            }

                            Timer {
                                interval: 8
                                running: true
                                repeat: true

                                onTriggered: {
                                    if (Math.abs(listViewSongs.velocity) < 0.05) {
                                        listViewSongs.velocity = 0
                                        return
                                    }

                                    listViewSongs.contentY -= listViewSongs.velocity

                                    if (Math.abs(listViewSongs.velocity) < listViewSongs.threshold)
                                        listViewSongs.velocity *= 0.55    // stop quickly
                                    else
                                        listViewSongs.velocity *= 0.90    // glide
                                }
                            }

                            // onContentYChanged: {
                            //     if (reorderDrag.active)
                            //         reorderDrag.updateDropTarget()
                            // }

                            Connections {
                                target: backend
                                function onIsInPlaylistViewChanged() {
                                    listViewSongs.contentY = 0
                                }
                            }

                            model: visualModel
                            //model: backend.songModel

                            move: Transition {
                                NumberAnimation { properties: "x,y"; duration: 170; easing.type: Easing.OutCubic }
                            }
                            moveDisplaced: Transition {
                                NumberAnimation { properties: "x,y"; duration: 170; easing.type: Easing.OutCubic }
                            }
                            displaced: Transition {
                                NumberAnimation { properties: "x,y"; duration: 170; easing.type: Easing.OutCubic }
                            }

                            // ── Playlist hero header ─────────────────────────────────────────
                            header: backend.isInPlaylistView ? playlistHeroComponent : null

                            Component {
                                id: playlistHeroComponent

                                Item {
                                    id: playlistHero
                                    width:  ListView.width
                                    height: 270

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#111111"
                                    }

                                    Image {
                                        id: heroCover
                                        x: 30
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 200; height: 200
                                        fillMode: Image.PreserveAspectCrop
                                        source: currentPlaylistCover
                                                ? "file://" + currentPlaylistCover
                                                : "qrc:/images/default_cover.png"
                                        opacity: 1.0// - playlistHero.fadeFraction
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: heroCover.width; height: heroCover.height
                                                radius: 8
                                            }
                                        }
                                    }

                                    Column {
                                        anchors.left:           heroCover.right
                                        anchors.leftMargin:     20
                                        anchors.right:          parent.right
                                        anchors.rightMargin:    20
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        opacity: 1.0

                                        Text {
                                            text: "Playlist"
                                            color: "#888888"
                                            font.pixelSize: 12
                                            font.letterSpacing: 1.5
                                        }
                                        Text {
                                            width: parent.width
                                            text: currentPlaylistName
                                            color: "white"
                                            font.pixelSize: 28
                                            font.bold: true
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                        }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 48
                                        opacity: 1.0
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: "#181818" }
                                        }
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: searchField.focus = false
                            }
                        }
                    }
                }
                // -------- NOW PLAYING BAR (frameNowPlaying) --------
                Rectangle {
                    id: frameNowPlaying
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    color: "#121212"

                    RowLayout {
                        id: layoutNowPlaying
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 4
                        anchors.topMargin: 8
                        anchors.bottomMargin: 4
                        spacing: 0

                        // LEFT — cover art + song info
                        Item {
                            id: leftSection
                            Layout.preferredWidth: 100
                            Layout.minimumWidth: 100
                            Layout.maximumWidth: 100
                            Layout.fillHeight: true

                            RowLayout {
                                id: layoutLeft
                                anchors.fill: parent
                                spacing: 0

                                // labelCoverArt
                                Rectangle {
                                    id: labelCoverArt
                                    width: 64
                                    height: 64
                                    Layout.preferredWidth: 64
                                    Layout.preferredHeight: 64
                                    Layout.maximumWidth: 64
                                    Layout.maximumHeight: 64
                                    color: "#222222"
                                    radius: 4
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: backend.currentSongCoverPath !== ""
                                                ? "file://" + backend.currentSongCoverPath
                                                : "qrc:/images/default_cover.png"
                                        visible: backend.currentLibraryIndex >= 0
                                    }
                                }

                                Text {
                                    id: labelSongInfo
                                    text: backend.currentLibraryIndex >= 0
                                          ? backend.currentSongTitle + "<br><span style='color:#b3b3b3; font-size:11px;'>"
                                            + backend.currentSongArtist + "</span>"
                                          : "Nothing Playing<br><span style='color:#b3b3b3; font-size:11px;'>Unknown Artist</span>"
                                    textFormat: Text.RichText
                                    color: "white"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignLeft
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 8
                                }
                            }
                        }

                        // CENTER — playback controls + seek bar
                        Item {
                            id: centerSection
                            anchors.centerIn: parent
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                id: layoutCenter
                                anchors.fill: parent
                                spacing: 0

                                // Playback buttons row
                                RowLayout {
                                    id: layoutPlaybackButtons
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 0

                                    Button {
                                        id: btnShuffle
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 28
                                        Layout.rightMargin: -5
                                        background: Item {}
                                        contentItem: Image {
                                            source: (btnShuffle.hovered || backend.shuffleMode)
                                                ? "image://svgicons/shuffleIconHovered"
                                                : "image://svgicons/shuffleIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                        onClicked: backend.toggleShuffle()
                                    }

                                    Button {
                                        id: btnReverse
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        Layout.rightMargin: -8
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnReverse.hovered
                                                ? "image://svgicons/reverseIconHovered"
                                                : "image://svgicons/reverseIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                        onClicked: backend.playPreviousSong()
                                    }

                                    Button {
                                        id: btnPlay
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 60
                                        background: Item {}

                                        Connections {
                                            target: backend.songModel
                                            function onDataChanged(topLeft, bottomRight, roles) {
                                                // Re-evaluate playing state whenever the model updates
                                                // We check if any row reports isPlaying && !isPaused.
                                                // A simpler proxy: currentLibraryIndex >= 0 and not paused.
                                                // We drive this via the playbackState signal below instead.
                                            }
                                        }

                                        contentItem: Image {
                                            source: backend.playing
                                                    ? "image://svgicons/pauseButtonIcon"
                                                    : "image://svgicons/playButtonIcon"
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        onClicked: backend.playAndPause()
                                    }

                                    // btnSkip
                                    Button {
                                        id: btnSkip
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        Layout.leftMargin: -8
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnSkip.hovered
                                                ? "image://svgicons/skipIconHovered"
                                                : "image://svgicons/skipIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        onClicked: backend.playNextSong()
                                    }

                                    // btnRepeat
                                    Button {
                                        id: btnRepeat
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        Layout.topMargin: 2
                                        Layout.leftMargin: -5
                                        background: Item {}
                                        contentItem: Image {
                                            source: (btnRepeat.hovered || backend.repeatMode)
                                                ? "image://svgicons/repeatIconHovered"
                                                : "image://svgicons/repeatIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                        onClicked: backend.toggleRepeat()
                                    }
                                }

                                // Seek bar row
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 3

                                    // labelCurrentTime
                                    Text {
                                        id: labelCurrentTime
                                        text: formatTime(backend.playerPosition)
                                        color: "#b3b3b3"
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignRight
                                        Layout.minimumWidth: 32

                                        function formatTime(ms) {
                                            var totalSecs = Math.floor(ms / 1000)
                                            var mins = Math.floor(totalSecs / 60)
                                            var secs = totalSecs % 60
                                            return mins + ":" + (secs < 10 ? "0" : "") + secs
                                        }
                                    }

                                    // sliderPosition
                                    Slider {
                                        id: sliderPosition
                                        Layout.minimumWidth: 320
                                        Layout.maximumWidth: 420
                                        Layout.preferredHeight: 20
                                        from: 0
                                        to: Math.max(1, backend.playerDuration)
                                        // Only update from backend when the user isn't dragging
                                        value: sliderPosition.pressed ? sliderPosition.value : backend.playerPosition

                                        hoverEnabled: true

                                        // Seek when the user releases the handle
                                        onPressedChanged: {
                                            if (!pressed)
                                                backend.seekTo(sliderPosition.value)
                                        }

                                        handle: Rectangle {
                                            implicitWidth: 10
                                            implicitHeight: 10

                                            x: sliderPosition.leftPadding +
                                               sliderPosition.visualPosition * (sliderPosition.availableWidth - width)

                                            y: sliderPosition.topPadding +
                                               sliderPosition.availableHeight / 2 - height / 2

                                            radius: width / 2
                                            color: "white"

                                            visible: sliderPosition.hovered || sliderPosition.pressed
                                            opacity: (sliderPosition.hovered || sliderPosition.pressed) ? 1 : 0
                                        }

                                        background: Rectangle {
                                            x: sliderPosition.leftPadding
                                            y: sliderPosition.topPadding + sliderPosition.availableHeight / 2 - height / 2

                                            width: sliderPosition.availableWidth
                                            height: 4

                                            radius: 2
                                            color: "#555555"

                                            Rectangle {
                                                width: sliderPosition.visualPosition * parent.width
                                                height: parent.height
                                                radius: 2
                                                color: "white"
                                            }
                                        }
                                    }

                                    // labelTotalTime
                                    Text {
                                        id: labelTotalTime
                                        text: formatTime(backend.playerDuration)
                                        color: "#b3b3b3"
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignLeft
                                        Layout.minimumWidth: 32

                                        function formatTime(ms) {
                                            var totalSecs = Math.floor(ms / 1000)
                                            var mins = Math.floor(totalSecs / 60)
                                            var secs = totalSecs % 60
                                            return mins + ":" + (secs < 10 ? "0" : "") + secs
                                        }
                                    }
                                }
                            }
                        }

                        // RIGHT — extra buttons + volume
                        Item {
                            id: rightSection
                            Layout.preferredWidth: 300
                            Layout.minimumWidth: 300
                            Layout.maximumWidth: 300
                            Layout.fillHeight: true

                            RowLayout {
                                id: layoutRight
                                anchors.fill: parent
                                spacing: 0
                                layoutDirection: Qt.RightToLeft
                                anchors.verticalCenter: parent.verticalCenter

                                // Volume slider
                                Slider {
                                    id: sliderVolume

                                    Layout.preferredWidth: 120
                                    Layout.maximumWidth: 120
                                    Layout.preferredHeight: 20

                                    from: 0
                                    to: 100
                                    value: backend.volume
                                    onMoved: backend.volume = value

                                    hoverEnabled: true

                                    handle: Rectangle {
                                        implicitWidth: 10
                                        implicitHeight: 10

                                        x: sliderVolume.leftPadding +
                                        sliderVolume.visualPosition * (sliderVolume.availableWidth - width)

                                        y: sliderVolume.topPadding +
                                        sliderVolume.availableHeight / 2 - height / 2

                                        radius: width / 2
                                        color: "white"

                                        visible: sliderVolume.hovered

                                        opacity: sliderVolume.hovered ? 1 : 0
                                    }

                                    background: Rectangle {
                                        x: sliderVolume.leftPadding
                                        y: sliderVolume.topPadding + sliderVolume.availableHeight / 2 - height / 2

                                        width: sliderVolume.availableWidth
                                        height: 4

                                        radius: 2
                                        color: "#555555"

                                        Rectangle {
                                            width: sliderVolume.visualPosition * parent.width
                                            height: parent.height
                                            radius: 2
                                            color: "white"
                                        }
                                    }
                                }

                                // speakerIcon
                                Button {
                                    id: speakerIcon
                                    enabled: false
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    Layout.rightMargin: -14
                                    background: Item {}
                                    contentItem: Image {
                                        source: speakerIcon.hovered
                                                ? "image://svgicons/speakerIconHovered"
                                                : "image://svgicons/speakerIconNormal"
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                // Extra buttons row

                                RowLayout {
                                    id: layoutBottomButtons
                                    spacing: 0
                                    Layout.rightMargin: 20
                                    Layout.alignment: Qt.AlignVCenter

                                    Button {
                                        id: btnJumpToCurrentSong
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 32
                                        Layout.rightMargin: -10
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnJumpToCurrentSong.hovered
                                                ? "image://svgicons/jumpToCurrentSongIconHovered"
                                                : "image://svgicons/jumpToCurrentSongIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                        onClicked: backend.jumpToCurrentSong()
                                    }

                                    Button {
                                        id: btnGoToAlbums
                                        Layout.preferredWidth: 47
                                        Layout.preferredHeight: 47
                                        Layout.rightMargin: -10
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnGoToAlbums.hovered
                                                ? "image://svgicons/goToAlbumsIconHovered"
                                                : "image://svgicons/goToAlbumsIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    Button {
                                        id: btnGoToBigPicture
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        Layout.rightMargin: -14
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnGoToBigPicture.hovered
                                                ? "image://svgicons/bigPictureIconHovered"
                                                : "image://svgicons/bigPictureIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        onClicked: stackView.push(bigPicturePageComponent, StackView.Immediate)
                                    }

                                    Button {
                                        id: btnListenAlong
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 60
                                        Layout.rightMargin: -20
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnListenAlong.hovered
                                                ? "image://svgicons/listenAlongIconHovered"
                                                : "image://svgicons/listenAlongIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                }
                            }
                        }
                    }
                }
            }

            Connections {
                target: backend
                function onIsInPlaylistViewChanged() {
                    currentPlaylistName = backend.viewingPlaylist
                    if (backend.playlistManager) {
                        currentPlaylistCover = backend.playlistManager.fullImagePath(backend.viewingPlaylist)
                    } else {
                        currentPlaylistCover = ""
                    }
                }
            }
        }
    }
    
    // Connection to switch pages when library is loaded
    Connections {
        target: backend
        function onLibraryLoaded() {
            stackView.push(loadedSongsPageComponent)
        }
    }
}