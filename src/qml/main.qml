import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQml.Models
import QtQuick.Effects
import Qt.labs.platform

ApplicationWindow {
    id: appWindow
    visible: true
    title: "Meloville"
    color: "#121212"
    flags: backend.nativeResizing ? Qt.Window : Qt.FramelessWindowHint
    minimumHeight: 300
    minimumWidth: 500
    
    property bool reallyQuit: false

    SystemTrayIcon {
        id: trayIcon

        visible: true
        icon.source: "qrc:/icons/meloville.svg"

        tooltip: backend.currentSongTitle !== ""
                 ? backend.currentSongTitle + " — " + backend.currentSongArtist
                 : "Meloville"

        menu: Menu {
            MenuItem {
                text: backend.currentSongTitle !== ""
                      ? backend.currentSongTitle
                      : "Nothing Playing"
                enabled: false
            }

            MenuItem {
                text: backend.currentSongArtist !== ""
                      ? backend.currentSongArtist
                      : ""
                enabled: false
            }

            MenuSeparator {}

            MenuItem {
                text: "Previous"
                enabled: backend.currentSongTitle !== ""

                onTriggered: {
                    backend.playPreviousSong()
                }
            }

            MenuItem {
                text: backend.playing ? "Pause" : "Play"
                enabled: backend.currentSongTitle !== ""

                onTriggered: {
                    backend.playAndPause()
                }
            }

            MenuItem {
                text: "Next"
                enabled: backend.currentSongTitle !== ""

                onTriggered: {
                    backend.playNextSong()
                }
            }

            MenuSeparator {}

            MenuItem {
                text: appWindow.visible
                      ? "Hide Meloville"
                      : "Show Meloville"

                onTriggered: {
                    if (appWindow.visible) {
                        appWindow.hide()
                    } else {
                        appWindow.show()
                        appWindow.raise()
                        appWindow.requestActivate()
                    }
                }
            }

            MenuSeparator {}

            MenuItem {
                text: "Quit"

                onTriggered: {
                    appWindow.reallyQuit = true
                    Qt.quit()
                }
            }
        }

        onActivated: function(reason) {
            if (reason === SystemTrayIcon.Trigger ||
                reason === SystemTrayIcon.DoubleClick) {

                if (appWindow.visible) {
                    appWindow.hide()
                } else {
                    appWindow.show()
                    appWindow.raise()
                    appWindow.requestActivate()
                }
            }
        }
    }

    // Ctrl+Q completely quits Meloville. So people without a in-built
    // Alt-F4 can still close the app as it doesn't have a app close button
    Shortcut {
        sequence: "Ctrl+Q"
        context: Qt.ApplicationShortcut

        onActivated: {
            backend.saveSessionAndWindow(
                appWindow.x, appWindow.y,
                appWindow.width, appWindow.height
            )
            appWindow.reallyQuit = true
            Qt.quit()
        }
    }

    Component.onCompleted: {
        var geo = backend.loadWindowGeometry()
        appWindow.x = geo.x
        appWindow.y = geo.y
        appWindow.width = geo.width
        appWindow.height = geo.height
    }

    // Clicking the normal window close button hides to tray.
    // Ctrl+Q and Tray -> Quit bypass this.
    onClosing: function(close) {
        backend.saveSessionAndWindow(
            appWindow.x, appWindow.y,
            appWindow.width, appWindow.height
        )

        if (appWindow.reallyQuit || !backend.closeToTray) {
            close.accepted = true
            Qt.quit()
        } else {
            close.accepted = false
            appWindow.hide()
        }
    }

    // Keep the tray tooltip synchronized with the current song.
    Connections {
        target: backend

        function onCurrentSongChanged() {
            trayIcon.tooltip =
                backend.currentSongTitle !== ""
                ? backend.currentSongTitle + " — " + backend.currentSongArtist
                : "Meloville"
        }
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

    PlaylistDialog {
        id: playlistDialog
        anchors.fill: parent
        visible: false
    }

    EditSongDialog {
        id: editSongDialog
        anchors.fill: parent
        visible: false
    }

    SettingsPage {
        id: settingsPage
        anchors.fill: parent
        visible: false
        onClosed: settingsPage.visible = false
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

        function onOpenContextMenuRequested(visibleIndex, x, y, title, artist) {
            contextMenu.currentVisibleIndex = visibleIndex
            contextMenu.playlistModel = backend.playlistNames
            contextMenu.showRemoveAction = backend.isInPlaylistView
            contextMenu.filterText = ""
            contextMenu.currentSongTitle = title
            contextMenu.currentSongArtist = artist

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
    property real delegateHeight: backend.delegateHeight
    property real delegateScale: delegateHeight / 62
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
            // These "delegates" are just a fancy way of saying items in the list
            // So this DelegateModel governs the items while the songDelegate which
            // comes right after the actually layout and logic for each item in the main
            // song list in this program
            DelegateModel {
                id: visualModel
                model: backend.songModel
                delegate: songDelegate
            }
            // Again, because this is techinically a part of listViewSongs a lot of the parenting may seem
            // nonsensical but it is required to properly switch songs in a playlist.
            Component {
                id: songDelegate

                // The outer item is the DropArea — it receives drags from other delegates
                DropArea {
                    id: delegateRoot

                    property int visualIndex: DelegateModel.itemsIndex

                    width: ListView.view ? ListView.view.width : 0
                    // This is so it relatively keeps the size the user would want the height to be if they picked compact mode
                    // so that it's not jarring from compact to normal or vice versa
                    height: backend.isCompact ? delegateHeight/2 : delegateHeight

                    // ── Live visual reorder: fires as the dragged item enters this delegate ──
                    onEntered: function(drag) {
                        var from = drag.source.DelegateModel.itemsIndex
                        var to   = delegateRoot.DelegateModel.itemsIndex
                        visualModel.items.move(from, to)
                    }

                    // ── The draggable content ──
                    Rectangle {
                        id: songRow
                        width: parent.width
                        height: backend.isCompact ? delegateHeight/2 : delegateHeight
                        color: "transparent"

                        // Lifts the row visually while dragging
                        Drag.active: dragArea.held
                        Drag.source: delegateRoot
                        Drag.hotSpot.x: width  / 2
                        Drag.hotSpot.y: height / 2

                        states: State {
                            when: dragArea.held
                            ParentChange {
                                target: songRow
                                parent: listViewSongs // reparented so it floats above 
                                // everything which is important while dragging
                            }
                            AnchorChanges {
                                target: songRow
                                anchors { horizontalCenter: undefined; verticalCenter: undefined }
                            }
                        }

                        // Background color of delegate (so basically song row background color)
                        Rectangle {
                            anchors.fill: parent
                            color: isPlaying ? "#2a2a2a"
                                : hoverHandler.hovered ? "#202020"
                                : "#181818"
                        }

                        // ── drag handle ──────────────────────────────────────────────────
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            enabled: backend.dragReorderAllowed && !backend.filterText
                            drag.target: held ? songRow : undefined
                            drag.axis: Drag.YAxis
                            drag.filterChildren: true
                            drag.threshold: 10
                            property bool held: false
                            property int startIndex: -1

                            // ── Auto-scroll state ────────────────────────────────────────────────
                            property real scrollSpeed: 0   // px per timer tick; negative = up

                            Timer {
                                id: autoScrollTimer
                                interval: 16 // ~60 fps
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
                                // Auto-scroll threshold
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
                                startIndex = delegateRoot.DelegateModel.itemsIndex
                                held = true
                                listViewSongs.interactive = false
                            }

                            onReleased: {
                                if (held) {
                                    backend.reorderPlaylist(startIndex, delegateRoot.DelegateModel.itemsIndex)

                                    held = false
                                    scrollSpeed = 0
                                    listViewSongs.interactive = true

                                    startIndex = -1
                                }
                            }

                            onCanceled: {
                                held = false
                                scrollSpeed = 0
                                listViewSongs.interactive = true
                                startIndex = -1
                            }
                        }

                        property bool isPlaying: model.isPlaying
                        property bool isPaused:  model.isPaused

                        // ── play/pause area ──────────────────────────────────────────────
                        Item {
                            id: playArea
                            x: 0
                            y: 0
                            width: 50 * delegateScale
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                visible: !songRow.isPlaying && !hoverHandler.hovered
                                text: (delegateRoot.DelegateModel.itemsIndex + 1).toString()
                                color: "#b3b3b3"
                                font.pixelSize: Math.round(13*delegateScale)
                            }
                            Image {
                                anchors.centerIn: parent
                                visible: songRow.isPlaying || hoverHandler.hovered
                                width: 22 * delegateScale
                                height: 22 * delegateScale
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
                            x: 50 * delegateScale
                            y: (parent.height - height) / 2
                            width: 50 * delegateScale
                            height: 50 * delegateScale
                            fillMode: Image.PreserveAspectCrop
                            visible: !backend.isInAlbumView && !backend.isCompact
                            mipmap: true
                            smooth: true
                            source: {
                                if (model.coverPath === "") return "qrc:/icons/default.svg"
                                return "file://" + model.coverPath + "?" + mainPageRoot.coverCacheBuster
                            }
                        }

                        // ── title + artist ───────────────────────────────────────────────
                        //When not compact (stacked on top of each other)
                        Column {
                            visible: !backend.isCompact
                            x: !backend.isInAlbumView ? coverImage.x + coverImage.width + 10 : coverImage.x
                            width: parent.width - x - 120
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4 * delegateScale

                            Text {
                                width: parent.width
                                text: model.title
                                color: "white"
                                font.pixelSize: Math.round(13 * delegateScale)
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: model.artist
                                color: "#b3b3b3"
                                font.pixelSize: Math.round(12 * delegateScale)
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            visible: backend.isCompact
                            x: 50 * delegateScale
                            width: parent.width - x - 120
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                text: model.title
                                color: "white"
                                font.pixelSize: Math.round(13 * delegateScale)
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, parent.width * 0.55)
                            }
                            Text {
                                text: "  ·  "
                                color: "#555555"
                                font.pixelSize: Math.round(12 * delegateScale)
                            }
                            Text {
                                text: model.artist
                                color: "#b3b3b3"
                                font.pixelSize: Math.round(12 * delegateScale)
                                elide: Text.ElideRight
                                width: parent.width - parent.children[0].width - parent.children[1].implicitWidth
                            }
                        }

                        // ── duration ─────────────────────────────────────────────────────
                        Text {
                            // - 45*delegateScale is just the menuArea, and then I need go more right and since delegateScale can
                            // get pretty small and lower values, if I actually add it to (120*delegateScale) makes look smaller due
                            // to integer rounding.
                            x: parent.width - 30*delegateScale - 45*delegateScale - (45*delegateScale)
                            width: 60
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.duration
                            color: "#b3b3b3"
                            font.pixelSize: Math.round(12 * delegateScale)
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // ── dots / context menu ──────────────────────────────────────────
                        Item {
                            id: menuArea
                            x: parent.width - (45*delegateScale)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30 * delegateScale
                            height: 30 * delegateScale

                            Image {
                                anchors.centerIn: parent
                                width: 18 * delegateScale
                                height: 4 * delegateScale
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

                // I have a lot of tap handlers like this since for some reason
                // Qt doesn't handle unfocusing search fields in a way most
                // users would expect so I had to get creative
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

                            Button {
                                id: btnAddPlaylist

                                Layout.preferredWidth: 65
                                Layout.preferredHeight: 65
                                Layout.maximumWidth: 65
                                Layout.maximumHeight: 65
                                Layout.leftMargin: -2
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
                                Layout.leftMargin: -2

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
                                Layout.topMargin: 2
                                Layout.minimumWidth: 60
                                Layout.maximumWidth: 60
                                Layout.leftMargin: 8
                                clip: true
                                spacing: 10
                                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                                
                                delegate: Rectangle {
                                    width: 50
                                    height: 50
                                    radius: 4
                                    color: "transparent"

                                    // Image with rounded corners
                                    Image {
                                        id: playlistImage
                                        anchors.fill: parent
                                        anchors.margins: 0
                                        fillMode: Image.PreserveAspectCrop
                                        source: model.imagePath ? model.imagePath : "qrc:/icons/default.svg"
                                        mipmap: true
                                        smooth: true
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
                                            listViewSongs.contentY = 0
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

                            DragHandler {
                                target: null
                                grabPermissions: PointerHandler.TakeOverForbidden
                                onActiveChanged: if (active && backend.customResizing) appWindow.startSystemMove()
                            }

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
                                    Layout.preferredWidth: Math.min(500, libraryHeader.width-150)
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
                                        clip: true
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

                        // ── Sticky bar (overlays the top of listViewSongs) ────────────
                        Rectangle {
                            id: stickyBar

                            // Only relevant when in playlist view
                            visible: (backend.isInPlaylistView || backend.isInAlbumView)

                            parent: mainPageRoot
                            x: frameSidebar.width
                            y: libraryHeader.visible ? libraryHeader.height : 0
                            width: layoutRightContent.width
                            height: 50

                            opacity: Math.min(1.0, Math.max(0.0,
                                (-listViewSongs.heroBottomY-100) / 100
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
                                    Layout.preferredWidth: Math.min(500, stickyBar.width-150)
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
                                        clip: true
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

                        // Main content for all songs that will be seen throughout the program
                        // Please refer to the top for the delegate as it needed to be seperated
                        // while adding the logic to switch songs
                        ListView {
                            id: listViewSongs
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 150
                            highlightFollowsCurrentItem: false
                            clip: true
                            ScrollBar.vertical:   ScrollBar { policy: ScrollBar.AsNeeded }
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                            visible: !backend.isInAlbumsGridView

                            // *should* get pixel‑accurate scrolling on Wayland
                            pixelAligned: true

                            boundsBehavior: Flickable.StopAtBounds
                            boundsMovement: Flickable.StopAtBounds

                            // CUSTOM SCROLLING BECAUSE DEFAULT SUCKS BRO
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
                            // -------CUSTOM SCROLLING END-----------------

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

                            // This is the "hero" or "playlistInfo" so to speak when in playlist or album view
                            // Made it it called "hero" since there's no good specific name as it displays
                            // both playlist and album info
                            header: (backend.isInPlaylistView || backend.isInAlbumView) ? heroComponent : null

                            Component {
                                id: heroComponent

                                Item {
                                    id: collectionHero
                                    width:  ListView.view.width
                                    height: 270

                                    DragHandler {
                                        target: null
                                        grabPermissions: PointerHandler.TakeOverForbidden
                                        onActiveChanged: if (active && backend.customResizing) appWindow.startSystemMove()
                                    }

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
                                    }
                                    Rectangle {
                                        id: heroSearchContainer
                                        width: Math.min(400, appWindow.width/3)
                                        height: 32
                                        radius: 16
                                        color: "#222222"

                                        // Bottom-right of the actual ListView header.
                                        x: collectionHero.width - width - 20
                                        y: collectionHero.height - height - 35

                                        TextInput {
                                            id: heroSearchField

                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10

                                            verticalAlignment: TextInput.AlignVCenter
                                            color: "white"
                                            font.pixelSize: 13

                                            text: heroSharedSearchText
                                            clip: true

                                            onTextEdited: {
                                                heroSharedSearchText = text
                                                backend.filterSongsAndAlbums(text)
                                                forceActiveFocus()
                                            }

                                            Text {
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter

                                                text: backend.isInPlaylistView
                                                    ? "Search playlist..."
                                                    : "Search albums..."

                                                color: "#666666"
                                                font.pixelSize: 13

                                                visible: heroSearchField.text.length === 0
                                                        && !heroSearchField.activeFocus
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

                            // Fits as many columns as possible at >= 184 px each,
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
                                    x: (parent.width - albumGrid.coverSz) / 2
                                    y: albumGrid.pad
                                    width: albumGrid.coverSz
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
                                    }
                                }

                                // ── Title ─────────────────────────────────────────────
                                Text {
                                    id: tileTitle
                                    x: albumGrid.pad / 2
                                    y: coverItem.y + coverItem.height + 8
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
                                    x: albumGrid.pad / 2
                                    y: tileTitle.y + 18
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
                // -------- Bottom bar on the screen for playing song info, play controls, etc --------
                Rectangle {
                    id: bottomBar
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
                            Layout.preferredWidth: 450
                            Layout.minimumWidth: 170
                            Layout.maximumWidth: Math.min(450, parent.width/3)
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            RowLayout {
                                id: layoutLeft
                                anchors.fill: parent
                                spacing: 0

                                Rectangle {
                                    id: bottomCoverArt
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
                                        mipmap: true
                                        smooth: true
                                        source: backend.currentSongCoverPath !== ""
                                                ? "file://" + backend.currentSongCoverPath
                                                : "qrc:/icons/default.svg"
                                        visible: backend.currentLibraryIndex >= 0
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.leftMargin: 8
                                    spacing: 2

                                    // ── TITLE ROW ──────────────────────────────────────────────
                                    Item {
                                        id: titleClip
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: titleText.implicitHeight
                                        clip: true

                                        // Gap between the two copies when looping (px)
                                        readonly property int loopGap: 48

                                        Text {
                                            id: titleText
                                            text: backend.currentLibraryIndex >= 0
                                                ? backend.currentSongTitle
                                                : "Nothing Playing"
                                            color: "white"
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            wrapMode: Text.NoWrap

                                            property bool overflows: contentWidth > titleClip.width

                                            // The scroll distance is one "unit" = text width + gap
                                            property real loopUnit: contentWidth + titleClip.loopGap

                                            onTextChanged: {
                                                x = 0
                                                titleScrollAnim.stop()
                                                titleStartTimer.restart()
                                            }

                                            onOverflowsChanged: {
                                                if (!overflows) {
                                                    titleScrollAnim.stop()
                                                    x = 0
                                                }
                                            }

                                            // Second copy — sits exactly one loopUnit to the right
                                            Text {
                                                x: titleText.loopUnit
                                                text: titleText.text
                                                color: titleText.color
                                                font: titleText.font
                                                wrapMode: Text.NoWrap
                                                visible: titleText.overflows
                                            }

                                            SequentialAnimation {
                                                id: titleScrollAnim
                                                loops: Animation.Infinite

                                                PauseAnimation { duration: 1500 }

                                                NumberAnimation {
                                                    target: titleText
                                                    property: "x"
                                                    from: 0
                                                    to: -titleText.loopUnit
                                                    // ~22ms per pixel so longer titles scroll a touch slower
                                                    duration: Math.max(3000, titleText.loopUnit * 22)
                                                    easing.type: Easing.Linear
                                                }
                                                // Silent reset — x jumps back to 0, which looks identical
                                                // because the second copy was pixel-perfect at that position
                                                ScriptAction { script: titleText.x = 0 }
                                            }

                                            Timer {
                                                id: titleStartTimer
                                                interval: 200
                                                onTriggered: if (titleText.overflows) titleScrollAnim.restart()
                                            }
                                        }
                                    }

                                    // ── ARTIST ROW ─────────────────────────────────────────────
                                    Item {
                                        id: artistClip
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: artistText.implicitHeight
                                        clip: true

                                        readonly property int loopGap: 48

                                        Text {
                                            id: artistText
                                            text: backend.currentLibraryIndex >= 0
                                                ? backend.currentSongArtist
                                                : "Unknown Artist"
                                            color: "#b3b3b3"
                                            font.pixelSize: 11
                                            wrapMode: Text.NoWrap

                                            property bool overflows: contentWidth > artistClip.width
                                            property real loopUnit: contentWidth + artistClip.loopGap

                                            onTextChanged: {
                                                x = 0
                                                artistScrollAnim.stop()
                                                artistStartTimer.restart()
                                            }

                                            onOverflowsChanged: {
                                                if (!overflows) {
                                                    artistScrollAnim.stop()
                                                    x = 0
                                                }
                                            }

                                            Text {
                                                x: artistText.loopUnit
                                                text: artistText.text
                                                color: artistText.color
                                                font: artistText.font
                                                wrapMode: Text.NoWrap
                                                visible: artistText.overflows
                                            }

                                            SequentialAnimation {
                                                id: artistScrollAnim
                                                loops: Animation.Infinite

                                                PauseAnimation { duration: 1500 }

                                                NumberAnimation {
                                                    target: artistText
                                                    property: "x"
                                                    from: 0
                                                    to: -artistText.loopUnit
                                                    duration: Math.max(3000, artistText.loopUnit * 22)
                                                    easing.type: Easing.Linear
                                                }

                                                ScriptAction { script: artistText.x = 0 }
                                            }

                                            Timer {
                                                id: artistStartTimer
                                                interval: 200
                                                onTriggered: if (artistText.overflows) artistScrollAnim.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // CENTER — playback controls + seek bar
                        Item {
                            id: centerSection
                            anchors.centerIn: parent
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: -10 - ((1280 - bottomBar.width) / 200) * 30

                            readonly property real btnScale: Math.min(1.0, Math.max(0.8, parent.width / 700))

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
                                        Layout.preferredWidth: 40 * centerSection.btnScale
                                        Layout.preferredHeight: 28 * centerSection.btnScale
                                        Layout.rightMargin: -5
                                        background: Item {}
                                        contentItem: Image {
                                            source: {
                                                if(backend.shuffleMode){
                                                    return "image://svgicons/shuffleIconActive"
                                                }
                                                if(btnShuffle.hovered){
                                                    return "image://svgicons/shuffleIconHovered"
                                                }
                                                return "image://svgicons/shuffleIconNormal"
                                            }
                                            fillMode: Image.PreserveAspectFit
                                        }
                                        onClicked: backend.toggleShuffle()
                                    }

                                    Button {
                                        id: btnReverse
                                        Layout.preferredWidth: 48 * centerSection.btnScale
                                        Layout.preferredHeight: 48 * centerSection.btnScale
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
                                        Layout.preferredWidth: 60 * centerSection.btnScale
                                        Layout.preferredHeight: 60 * centerSection.btnScale
                                        background: Item {}

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
                                        Layout.preferredWidth: 48 * centerSection.btnScale
                                        Layout.preferredHeight: 48 * centerSection.btnScale
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
                                        Layout.preferredWidth: 40 * centerSection.btnScale
                                        Layout.preferredHeight: 40 * centerSection.btnScale
                                        Layout.topMargin: 2
                                        Layout.leftMargin: -5
                                        background: Item {}
                                        contentItem: Image {
                                            source: {
                                                if (backend.repeatMode){
                                                    return "image://svgicons/repeatIconActive"
                                                }
                                                if (btnRepeat.hovered){
                                                    return "image://svgicons/repeatIconHovered"
                                                }
                                                return "image://svgicons/repeatIconNormal"
                                            }
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
                                        Layout.maximumWidth: Math.min(480, bottomBar.width/4)
                                        Layout.preferredHeight: 20
                                        from: 0
                                        to: Math.max(1, backend.playerDuration)
                                        // Only update when user isn't dragging otherwise feedback loop
                                        value: sliderPosition.pressed ? sliderPosition.value : backend.playerPosition

                                        hoverEnabled: true

                                        onPressedChanged: {
                                            if (!pressed) //This acts like an "onReleased"
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

                        Item {
                            id: rightSection
                            Layout.preferredWidth: 260
                            Layout.minimumWidth: 200
                            Layout.maximumWidth: 300
                            Layout.fillHeight: true

                            readonly property real btnScale: Math.min(1.0, Math.max(0.8, parent.width / 700))

                            GridLayout {
                                id: rightGrid
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                columns: 2
                                rows: 2
                                rowSpacing: 0
                                columnSpacing: 0

                                // ------------------------------------------------------------
                                // Volume + speaker
                                // ------------------------------------------------------------
                                RowLayout {
                                    id: audioControls

                                    Layout.column: 1
                                    Layout.row: 0
                                    Layout.alignment: Qt.AlignVCenter

                                    spacing: 0
                                    layoutDirection: Qt.RightToLeft

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
                                            sliderVolume.visualPosition *
                                            (sliderVolume.availableWidth - width)

                                            y: sliderVolume.topPadding +
                                            sliderVolume.availableHeight / 2 -
                                            height / 2

                                            radius: width / 2
                                            color: "white"

                                            visible: sliderVolume.hovered
                                            opacity: sliderVolume.hovered ? 1 : 0
                                        }

                                        background: Rectangle {
                                            x: sliderVolume.leftPadding
                                            y: sliderVolume.topPadding +
                                            sliderVolume.availableHeight / 2 -
                                            height / 2

                                            width: sliderVolume.availableWidth
                                            height: 4

                                            radius: 2
                                            color: "#555555"

                                            Rectangle {
                                                width: sliderVolume.visualPosition *
                                                    parent.width
                                                height: parent.height
                                                radius: 2
                                                color: "white"
                                            }
                                        }
                                    }

                                    Button {
                                        id: speakerIcon

                                        enabled: false

                                        Layout.preferredWidth: 40 * rightSection.btnScale
                                        Layout.preferredHeight: 40 * rightSection.btnScale
                                        Layout.rightMargin: -14

                                        background: Item {}

                                        contentItem: Image {
                                            source: speakerIcon.hovered
                                                    ? "image://svgicons/speakerIconHovered"
                                                    : "image://svgicons/speakerIconNormal"

                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }
                                }

                                RowLayout {
                                    id: layoutBottomButtons

                                    Layout.column: 0
                                    Layout.row: 0
                                    Layout.alignment: Qt.AlignVCenter

                                    spacing: 3
                                    layoutDirection: Qt.RightToLeft

                                    Button {
                                        id: btnSettings

                                        Layout.preferredWidth: 37 * rightSection.btnScale
                                        Layout.preferredHeight: 37 * rightSection.btnScale
                                        Layout.rightMargin: 0

                                        background: Item {}

                                        contentItem: Image {
                                            source: btnSettings.hovered
                                                    ? "image://svgicons/settingsIconHovered"
                                                    : "image://svgicons/settingsIconNormal"

                                            fillMode: Image.PreserveAspectFit
                                        }

                                        onClicked: settingsPage.visible = true
                                    }

                                    Button {
                                        id: btnGoToBigPicture

                                        Layout.preferredWidth: 40 * rightSection.btnScale
                                        Layout.preferredHeight: 40 * rightSection.btnScale
                                        Layout.rightMargin: -5

                                        background: Item {}

                                        contentItem: Image {
                                            source: btnGoToBigPicture.hovered
                                                    ? "image://svgicons/bigPictureIconHovered"
                                                    : "image://svgicons/bigPictureIconNormal"

                                            fillMode: Image.PreserveAspectFit
                                        }

                                        onClicked: stackView.push(
                                            bigPicturePageComponent,
                                            StackView.Immediate
                                        )
                                    }

                                    Button {
                                        id: btnGoToAlbums

                                        Layout.preferredWidth: 47 * rightSection.btnScale
                                        Layout.preferredHeight: 47 * rightSection.btnScale
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
                                        id: btnJumpToCurrentSong

                                        Layout.preferredWidth: 48 * rightSection.btnScale
                                        Layout.preferredHeight: 32 * rightSection.btnScale
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
                                }

                                states: [
                                    State {
                                        name: "narrow"
                                        when: bottomBar.width < 900

                                        PropertyChanges {
                                            target: layoutBottomButtons
                                            Layout.column: 0
                                            Layout.row: 0
                                        }

                                        PropertyChanges {
                                            target: audioControls
                                            Layout.column: 0
                                            Layout.row: 1
                                        }

                                        // Both rows use the full available width when stacked.
                                        PropertyChanges {
                                            target: layoutBottomButtons
                                            Layout.fillWidth: true
                                            Layout.bottomMargin: -10
                                        }

                                        PropertyChanges {
                                            target: audioControls
                                            Layout.fillWidth: true
                                        }
                                    },

                                    State {
                                        name: "wide"
                                        when: bottomBar.width >= 900

                                        PropertyChanges {
                                            target: layoutBottomButtons
                                            Layout.column: 0
                                            Layout.row: 0
                                            Layout.bottomMargin: 0
                                        }

                                        PropertyChanges {
                                            target: audioControls
                                            Layout.column: 1
                                            Layout.row: 0
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }

            Connections {
                target: backend
                function onPlaylistNamesChanged() {
                    if (backend.playlistManager) {
                        currentPlaylistCover = backend.playlistManager.fullImagePath(backend.viewingPlaylist)
                    } else {
                        currentPlaylistCover = ""
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
                    listViewSongs.positionViewAtIndex(visibleIndex, ListView.Center)
                }
            }

            Connections {
                target: backend
                function onReturnedToLibrary() {
                    listViewSongs.contentY = 0
                    searchField.clear()
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

    // ── Resize handles (frameless window) ──────────────────────────
    Repeater {
        model: [
            // edges
            { edge: Qt.LeftEdge,   cursor: Qt.SizeHorCursor,  x: 0,                    y: 4,                    w: 4,                h: appWindow.height - 8 },
            { edge: Qt.RightEdge,  cursor: Qt.SizeHorCursor,  x: appWindow.width - 4,  y: 4,                    w: 4,                h: appWindow.height - 8 },
            { edge: Qt.TopEdge,    cursor: Qt.SizeVerCursor,  x: 4,                    y: 0,                    w: appWindow.width - 8, h: 4 },
            { edge: Qt.BottomEdge, cursor: Qt.SizeVerCursor,  x: 4,                    y: appWindow.height - 4, w: appWindow.width - 8, h: 4 },
            // corners
            { edge: Qt.TopEdge | Qt.LeftEdge,     cursor: Qt.SizeFDiagCursor, x: 0,                     y: 0,                    w: 8, h: 8 },
            { edge: Qt.TopEdge | Qt.RightEdge,    cursor: Qt.SizeBDiagCursor, x: appWindow.width - 8,   y: 0,                    w: 8, h: 8 },
            { edge: Qt.BottomEdge | Qt.LeftEdge,  cursor: Qt.SizeBDiagCursor, x: 0,                     y: appWindow.height - 8, w: 8, h: 8 },
            { edge: Qt.BottomEdge | Qt.RightEdge, cursor: Qt.SizeFDiagCursor, x: appWindow.width - 8,   y: appWindow.height - 8, w: 8, h: 8 }
        ]

        Item {
            parent: appWindow.contentItem
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            HoverHandler { cursorShape: if(backend.customResizing && appWindow.visibility != Window.Maximized && !backend.nativeResizing) modelData.cursor }

            DragHandler {
                grabPermissions: TapHandler.CanTakeOverFromAnything
                onActiveChanged: if (active && backend.customResizing && !backend.nativeResizing) appWindow.startSystemResize(modelData.edge)
            }
        }
    }
}