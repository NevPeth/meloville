import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQml.Models

ApplicationWindow {
    id: appWindow
    visible: true
    title: "Meloville"
    color: "#121212"
    flags: Qt.FramelessWindowHint

    Component.onCompleted: {
        var geo = backend.loadWindowGeometry()
        appWindow.x      = geo.x
        appWindow.y      = geo.y
        appWindow.width  = geo.width
        appWindow.height = geo.height
    }

    onClosing: function(close) {
        backend.saveSessionAndWindow(
            appWindow.x, appWindow.y,
            appWindow.width, appWindow.height
        )
    }

    Shortcut {
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: backend.playAndPause()
    }

    Shortcut {
        sequence: "Media Next"
        context: Qt.ApplicationShortcut
        onActivated: backend.playNextSong()
    }

    Shortcut {
        sequence: "Media Previous"
        context: Qt.ApplicationShortcut
        onActivated: backend.playPreviousSong()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            var item = stackView.currentItem
            if (item && item.unfocusSearchFields)
                item.unfocusSearchFields()
        }
    }
    
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
        }
        onRejected: {
        }
        onDeleted: {
        }
    }

    EditSongDialog {
        id: editSongDialog
        anchors.fill: parent
        visible: false

        onAccepted: {
            // The backend will handle saving changes; we might want to refresh the song list.
        }
        onRejected: {
            // just close
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
    property string currentPlaylistName: ""
    property string currentPlaylistCover: ""
    property string heroSharedSearchText: ""
    Component {
        id: mainPageComponent
        Rectangle {
            id: mainPageRoot
            color: "#121212"
            function unfocusSearchFields() {
                searchField.focus = false
                stickySearchField.focus = false
                if (listViewSongs.headerItem)
                    listViewSongs.headerItem.forceActiveFocus()
            }
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

                        drag.source.parent.parent.currentIndex = to
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
                            property int  currentIndex: -1

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

                            onPositionChanged: {
                                if (!held) return

                                // Update drop indicator
                                var posInList = songRow.mapToItem(listViewSongs, 0, 0)
                                listViewSongs.dropIndicatorY = posInList.y

                                // ── Auto-scroll ──────────────────────────────────────────────────
                                var threshold = 120

                                // Map through the window instead — survives the ParentChange reparent
                                var globalPos  = dragArea.mapToGlobal(mouse.x, mouse.y)
                                var viewportY  = listViewSongs.mapFromGlobal(globalPos.x, globalPos.y).y

                                if (viewportY < threshold) {
                                    scrollSpeed = -((threshold - viewportY) / threshold) * 15
                                } else if (viewportY > listViewSongs.height - threshold) {
                                    scrollSpeed = ((viewportY - (listViewSongs.height - threshold)) / threshold) * 15
                                } else {
                                    scrollSpeed = 0
                                }
                            }

                            onPressed: {
                                startIndex   = delegateRoot.DelegateModel.itemsIndex
                                currentIndex = startIndex
                                held = true
                                listViewSongs.interactive = false
                                listViewSongs.dropIndicatorVisible = true
                            }

                            onReleased: {
                                if (held) {
                                    held = false
                                    scrollSpeed = 0
                                    listViewSongs.interactive = true
                                    listViewSongs.dropIndicatorVisible = false

                                    // Use startIndex → currentIndex, not itemsIndex on release
                                    if (startIndex !== currentIndex)
                                        backend.reorderPlaylist(startIndex, currentIndex)

                                    startIndex   = -1
                                    currentIndex = -1
                                }
                            }

                            onCanceled: {
                                held = false
                                scrollSpeed = 0
                                listViewSongs.interactive = true
                                listViewSongs.dropIndicatorVisible = false
                                startIndex   = -1
                                currentIndex = -1
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
                            visible: !backend.isInAlbumView
                            source: {
                                if (model.coverPath === "") return "qrc:/icons/default.svg"
                                return "file://" + model.coverPath + "?" + mainPageRoot.coverCacheBuster
                            }
                        }

                        // ── title + artist ───────────────────────────────────────────────
                        Column {
                            x: !backend.isInAlbumView ? coverImage.x + coverImage.width + 10 : coverImage.x
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

                TapHandler {
                    onTapped: unfocusSearchFields()
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

                                Layout.preferredWidth: 65
                                Layout.preferredHeight: 65
                                Layout.maximumWidth: 65
                                Layout.maximumHeight: 65
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

                                background: Item {}

                                icon.width: 65
                                icon.height: 65

                                contentItem: Image {
                                    source: "image://svgicons/addPlaylistsIcon"
                                    width: 65
                                    height: 65
                                    fillMode: Image.PreserveAspectFit
                                }

                                onClicked: playlistDialog.openCreate()
                            }

                            Button {
                                id: btnLibrary

                                Layout.preferredWidth: 65
                                Layout.preferredHeight: 65
                                Layout.maximumWidth: 65
                                Layout.maximumHeight: 65
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                                Layout.topMargin: -10

                                background: Item {}

                                icon.width: 65
                                icon.height: 65

                                contentItem: Image {
                                    source: "image://svgicons/libraryIcon"
                                    width: 65
                                    height: 65
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
                                Layout.leftMargin: 7
                                clip: true
                                spacing: 8
                                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                                delegate: Rectangle {
                                    width: 51
                                    height: 51
                                    radius: 4
                                    color: "transparent"

                                    // Image with rounded corners
                                    Image {
                                        id: playlistImage
                                        anchors.fill: parent
                                        anchors.margins: 0
                                        fillMode: Image.PreserveAspectCrop
                                        source: model.imagePath ? model.imagePath : "qrc:/icons/default.svg"
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
                                    onTapped: unfocusSearchFields()
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

                        Rectangle {
                            id: libraryHeader
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            Layout.minimumHeight: 50
                            Layout.maximumHeight: 50
                            visible: !backend.isInPlaylistView && !backend.isInAlbumView
                            color: "transparent"

                            RowLayout {
                                id: currentLibraryHeader
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                Text {
                                    id: currentLibraryLabel
                                    text: (backend.isInAlbumView || backend.isInAlbumsGridView) ? "Albums" : "Library"
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
                                        onTextEdited: backend.filterSongsAndAlbums(text)

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 0
                                            verticalAlignment: Text.AlignVCenter
                                            text: backend.isInAlbumsGridView ? "Search albums..." : "Search songs..."
                                            color: "#888888"
                                            font.pixelSize: 13
                                            visible: searchField.text.length === 0 && !searchField.activeFocus
                                        }
                                    }
                                }
                            }
                            TapHandler {
                                onTapped: unfocusSearchFields()
                            }
                        }

                        // ── Sticky playlist bar (overlays the top of listViewSongs) ────────────
                        Rectangle {
                            id: stickyPlaylistBar

                            // Only relevant when in playlist view
                            visible: (backend.isInPlaylistView || backend.isInAlbumView)

                            parent: mainPageRoot
                            x: frameSidebar.width
                            y: libraryHeader.visible ? libraryHeader.height : 0
                            width: layoutRightContent.width
                            height: 50

                            opacity: Math.min(1.0, Math.max(0.0,
                                -listViewSongs.heroBottomY / 150
                            ))

                            color: "#111111"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 12

                                Text {
                                    text: backend.isInPlaylistView ? currentPlaylistName : backend.viewingAlbumName
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
                                        text: heroSharedSearchText
                                        onTextEdited: {
                                            heroSharedSearchText = text
                                            backend.filterSongsAndAlbums(text)
                                        }

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: backend.isInPlaylistView ?"Search playlist..." : "Search albums..."
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
                            visible: !backend.isInAlbumsGridView

                            // ----- Pixel‑accurate scrolling on Wayland -----
                            pixelAligned: true

                            boundsBehavior: Flickable.StopAtBounds
                            boundsMovement: Flickable.StopAtBounds

                            property real velocity: 0
                            property real threshold: 40

                            property real heroBottomY: {
                                var item = listViewSongs.headerItem
                                if (!item) return 0
                                // heroHeight minus how far we've scrolled — goes negative once scrolled past the hero
                                return item.height - listViewSongs.contentY - 500
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

                            model: visualModel

                            move: Transition {
                                NumberAnimation { properties: "x,y"; duration: 170; easing.type: Easing.OutCubic }
                            }
                            moveDisplaced: Transition {
                                NumberAnimation { properties: "x,y"; duration: 170; easing.type: Easing.OutCubic }
                            }
                            displaced: Transition {
                                NumberAnimation { properties: "x,y"; duration: 170; easing.type: Easing.OutCubic }
                            }

                            header: (backend.isInPlaylistView || backend.isInAlbumView) ? heroComponent : null

                            Component {
                                id: heroComponent

                                Item {
                                    id: collectionHero
                                    width:  ListView.width
                                    height: 270

                                    // Resolve cover/title/subtitle from whichever context is active
                                    readonly property bool inPlaylist: backend.isInPlaylistView
                                    readonly property string heroCoverSource: {
                                        if (inPlaylist)
                                            return currentPlaylistCover ? "file://" + currentPlaylistCover : "qrc:/icons/default.svg"
                                        var cover = backend.viewingAlbumCover
                                        return cover ? "file://" + cover : "qrc:/icons/default.svg"
                                    }
                                    readonly property string heroLabel:     inPlaylist ? "Playlist" : "Album"
                                    readonly property string heroTitle:     inPlaylist ? currentPlaylistName : backend.viewingAlbumName
                                    readonly property string heroSubtitle:  inPlaylist ? "" : backend.viewingAlbumArtist
                                    property bool coverHovered: false
                                    property bool coverLocked: false

                                    Image {
                                        id: heroCover
                                        x: 30
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 200; height: 200
                                        fillMode: Image.PreserveAspectCrop
                                        source: collectionHero.heroCoverSource
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: heroCover.width; height: heroCover.height
                                                radius: 8
                                            }
                                        }

                                        property bool coverLocked: false
                                        property bool snapOff: false

                                        Timer {
                                            id: snapOffTimer
                                            interval: 1
                                            onTriggered: heroCover.snapOff = false
                                        }

                                        Connections {
                                            target: playlistDialog
                                            function onVisibleChanged() {
                                                if (playlistDialog.visible) {
                                                    heroCover.snapOff = true
                                                    heroCover.coverLocked = false
                                                    snapOffTimer.start()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: hoverOverlay
                                            anchors.fill: parent
                                            color: "#000000"
                                            opacity: (hoverArea.containsMouse || heroCover.coverLocked) && collectionHero.inPlaylist ? 0.7 : 0
                                            radius: 8

                                            Behavior on opacity {
                                                enabled: !heroCover.snapOff
                                                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                            }

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                opacity: (hoverArea.containsMouse || heroCover.coverLocked) && collectionHero.inPlaylist ? 1 : 0

                                                Behavior on opacity {
                                                    enabled: !heroCover.snapOff
                                                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                                }

                                                Image {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: 60; height: 60
                                                    source: "image://svgicons/pencilIcon"
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: hoverArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: collectionHero.inPlaylist ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                if (collectionHero.inPlaylist) {
                                                    heroCover.coverLocked = true
                                                    playlistDialog.openEdit(currentPlaylistName, currentPlaylistCover)
                                                }
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

                                        Text {
                                            text: collectionHero.heroLabel
                                            color: "#888888"
                                            font.pixelSize: 12
                                            font.letterSpacing: 1.5
                                        }
                                        Text {
                                            width: parent.width
                                            text: collectionHero.heroTitle
                                            color: "white"
                                            font.pixelSize: 28
                                            font.bold: true
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (collectionHero.inPlaylist)
                                                        playlistDialog.openEdit(currentPlaylistName, currentPlaylistCover)
                                                }
                                            }
                                        }
                                        // Artist subtitle — only shown for albums
                                        Text {
                                            width: parent.width
                                            text: collectionHero.heroSubtitle
                                            color: "#b3b3b3"
                                            font.pixelSize: 15
                                            font.weight: Font.DemiBold
                                            visible: collectionHero.heroSubtitle !== ""
                                            elide: Text.ElideRight
                                        }
                                        Rectangle {
                                            width: 500
                                            height: 32
                                            radius: 16
                                            color: "#222222"

                                            TextInput {
                                                id: heroSearchField
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: "white"
                                                font.pixelSize: 13
                                                text: heroSharedSearchText
                                                onTextEdited: {
                                                    heroSharedSearchText = text
                                                    backend.filterSongsAndAlbums(text)
                                                    forceActiveFocus()  // 'this' is the TextInput itself
                                                }

                                                Text {
                                                    anchors.fill: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: backend.isInPlaylistView ?"Search playlist..." : "Search albums..."
                                                    color: "#666666"
                                                    font.pixelSize: 13
                                                    visible: heroSearchField.text.length === 0 && !heroSearchField.activeFocus
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: unfocusSearchFields()
                            }
                        }
                        // ── Album grid — shown when backend.isInAlbumsGridView ────────────────
                        GridView {
                            id: albumGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 150
                            clip: true
                            visible: backend.isInAlbumsGridView

                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            model: backend.albumModel

                            // Mirror AlbumGridView::recalculateGrid() maths:
                            // fit as many columns as possible at >= 184 px each,
                            // then stretch them evenly so there's no dead gap.
                            readonly property int minTileWidth: 184
                            readonly property int pad:          12   // kCellPadding
                            readonly property int textBlock:    44   // kTextBlockHeight
                            readonly property int columns:      Math.max(1, Math.floor(width / minTileWidth))
                            readonly property int tileW:        Math.floor(width / columns)
                            readonly property int coverSz:      Math.min(240, Math.max(110, tileW - pad * 2))
                            readonly property int tileH:        coverSz + pad + textBlock + 8

                            cellWidth:  tileW
                            cellHeight: tileH

                            delegate: Item {
                                width:  albumGrid.cellWidth
                                height: albumGrid.cellHeight

                                HoverHandler { id: tileHov }

                                Rectangle {
                                    anchors { fill: parent; margins: 2 }
                                    radius: 10
                                    color:  tileHov.hovered ? "#1e1e1e" : "transparent"
                                }

                                // ── Cover art ─────────────────────────────────────────
                                Item {
                                    id: coverItem
                                    x:      (parent.width - albumGrid.coverSz) / 2
                                    y:      albumGrid.pad
                                    width:  albumGrid.coverSz
                                    height: albumGrid.coverSz

                                    Rectangle {
                                        id: roundMask
                                        anchors.fill: parent
                                        radius: 8
                                        visible: false
                                    }

                                    // Actual cover
                                    Image {
                                        id: coverImg
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: model.coverPath ? "file://" + model.coverPath : ""
                                        visible: status === Image.Ready
                                        layer.enabled: true
                                        layer.effect: OpacityMask { maskSource: roundMask }
                                    }

                                    // Placeholder when no art
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

                                // ── Title ─────────────────────────────────────────────
                                Text {
                                    id: tileTitle
                                    x:     albumGrid.pad / 2
                                    y:     coverItem.y + coverItem.height + 8
                                    width: parent.width - albumGrid.pad
                                    text:  model.title
                                    color: "white"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // ── Artist ────────────────────────────────────────────
                                Text {
                                    x:     albumGrid.pad / 2
                                    y:     tileTitle.y + 18
                                    width: parent.width - albumGrid.pad
                                    text:  model.artist
                                    color: "#b3b3b3"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // ── Tap to enter album ────────────────────────────────
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.loadAlbumView(model.title, model.artist, model.coverPath)
                                }
                            }

                            boundsBehavior: Flickable.StopAtBounds
                            boundsMovement: Flickable.StopAtBounds

                            property real velocity: 0
                            property real threshold: 40

                            // Disable built-in flicking so the WheelHandler is fully in control
                            interactive: false

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                                onWheel: function(event) {
                                    var delta = event.pixelDelta.y !== 0
                                            ? event.pixelDelta.y
                                            : event.angleDelta.y / 4

                                    if (Math.abs(delta) < albumGrid.threshold) {
                                        albumGrid.velocity += delta
                                    } else {
                                        var excess = Math.abs(delta) - albumGrid.threshold
                                        albumGrid.velocity += delta + Math.sign(delta) * excess * 0.8
                                    }

                                    event.accepted = true
                                }
                            }

                            Timer {
                                interval: 8
                                running: true
                                repeat: true

                                onTriggered: {
                                    if (Math.abs(albumGrid.velocity) < 0.05) {
                                        albumGrid.velocity = 0
                                        return
                                    }

                                    albumGrid.contentY -= albumGrid.velocity

                                    if (Math.abs(albumGrid.velocity) < albumGrid.threshold)
                                        albumGrid.velocity *= 0.55
                                    else
                                        albumGrid.velocity *= 0.90
                                }
                            }
                        }
                    }
                }
                // -------- Music Metadata Bar --------
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
                                                : "qrc:/icons/default.svg"
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

                                    // bar for music played
                                    Slider {
                                        id: sliderPosition
                                        Layout.minimumWidth: 320
                                        Layout.maximumWidth: 420
                                        Layout.preferredHeight: 20
                                        from: 0
                                        to: Math.max(1, backend.playerDuration)
                                        // Only update when user isn't dragging otherwise feedback loop
                                        value: sliderPosition.pressed ? sliderPosition.value : backend.playerPosition

                                        hoverEnabled: true

                                        onPressedChanged: {
                                            if (!pressed) //On release go to part in song
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
                                    spacing: 3
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
                                        onClicked: backend.goToAlbums()
                                    }

                                    Button {
                                        id: btnGoToBigPicture
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        Layout.rightMargin: -5
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
                                        id: btnSettings
                                        Layout.preferredWidth: 37
                                        Layout.preferredHeight: 37
                                        Layout.rightMargin: -10
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnSettings.hovered
                                                ? "image://svgicons/settingsIconHovered"
                                                : "image://svgicons/settingsIconNormal"
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
                    heroSharedSearchText = ""
                    if (backend.playlistManager) {
                        currentPlaylistCover = backend.playlistManager.fullImagePath(backend.viewingPlaylist)
                    } else {
                        currentPlaylistCover = ""
                    }
                }
            }

            Connections {
                target: backend
                function onEditSongRequested(libraryIndex, filePath, coverPath,
                                            title, artist, album, trackNumber) {
                    editSongDialog.openEdit(
                        libraryIndex, filePath, coverPath,
                        title, artist, album, trackNumber
                    )
                    editSongDialog.visible = true
                }
            }

            Connections {
                target: backend
                function onJumpToSongIndex(visibleIndex) {
                    // +1 accounts for the playlist hero header item
                    var offset = (backend.isInPlaylistView || backend.isInAlbumView) ? 1 : 0
                    listViewSongs.positionViewAtIndex(visibleIndex + offset, ListView.Center)
                }
            }

            Connections {
                target: backend
                function onReturnedToLibrary() {
                    listViewSongs.contentY = 0
                }
            }
        }
    }
    
    // Connection to switch pages when library is loaded
    Connections {
        target: backend
        function onLibraryLoaded() {
            stackView.push(loadedSongsPageComponent)
            heroSharedSearchText = ""
        }
    }
}