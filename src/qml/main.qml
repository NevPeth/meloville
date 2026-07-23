import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    property int playlistButtonSize: 65
    property int libraryButtonSize: 65
    Component {
        id: mainPageComponent
        Rectangle {
            color: "#121212"

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                spacing: 0
                // margins are 0 by default in QML

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

                                icon.source: "qrc:/icons/libraryIcon.svg"
                                icon.width: libraryButtonSize
                                icon.height: libraryButtonSize

                                contentItem: Image {
                                    source: btnLibrary.icon.source
                                    width: libraryButtonSize
                                    height: libraryButtonSize
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            ListView {
                                id: listWidgetPlaylists
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 60
                                Layout.maximumWidth: 60
                                clip: true
                                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                                delegate: Item { width: 60; height: 48 }
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

                        // libraryHeader
                        Rectangle {
                            id: libraryHeader
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            Layout.minimumHeight: 50
                            Layout.maximumHeight: 50
                            color: "transparent"

                            RowLayout {
                                id: currentLibraryHeader
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                // currentLibraryLabel
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

                        ListView {
                            id: listViewSongs
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 150
                            clip: true
                            ScrollBar.vertical:   ScrollBar { policy: ScrollBar.AsNeeded }
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                            model: backend.songModel

                            property real scrollVelocity: 0

                            Timer {
                                id: momentum
                                interval: 16
                                repeat: true

                                onTriggered: {
                                    listViewSongs.contentY -= listViewSongs.scrollVelocity

                                    // Clamp to valid scroll bounds
                                    var minY = 0
                                    var maxY = Math.max(0, listViewSongs.contentHeight - listViewSongs.height)

                                    if (listViewSongs.contentY < minY) {
                                        listViewSongs.contentY = minY
                                        listViewSongs.scrollVelocity = 0
                                        stop()
                                    } else if (listViewSongs.contentY > maxY) {
                                        listViewSongs.contentY = maxY
                                        listViewSongs.scrollVelocity = 0
                                        stop()
                                    }

                                    listViewSongs.scrollVelocity *= 0.84

                                    if (Math.abs(listViewSongs.scrollVelocity) < 0.04) {
                                        stop()
                                        listViewSongs.scrollVelocity = 0
                                    }
                                }
                            }

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                                onWheel: function(event) {

                                    var delta = event.pixelDelta.y !== 0
                                            ? event.pixelDelta.y
                                            : event.angleDelta.y / 8

                                    listViewSongs.scrollVelocity += delta * 0.44

                                    listViewSongs.scrollVelocity = Math.max(
                                        -1020,
                                        Math.min(1020, listViewSongs.scrollVelocity)
                                    )

                                    if (!momentum.running)
                                        momentum.start()

                                    event.accepted = true
                                }
                            }

                            delegate: Rectangle {
                                id: songRow
                                width: listViewSongs.width
                                height: 62         // matches SongDelegate::sizeHint
                                color: "transparent"

                                // ── state from model roles ──────────────────────────────────────
                                property bool isPlaying: model.isPlaying   // IsPlayingRole
                                property bool isPaused:  model.isPaused    // IsPausedRole
                                property bool isActive:  model.isActive    // IsActiveRole

                                // ── background ─────────────────────────────────────────────────
                                Rectangle {
                                    anchors.fill: parent
                                    color: songRow.isPlaying ? "#2a2a2a"
                                        : songRow.isActive  ? "#2f2f2f"
                                        : hoverHandler.hovered ? "#202020"
                                        : "#181818"
                                }

                                // ── play/pause button area (left 50 px) ─────────────────────────
                                Item {
                                    id: playArea
                                    x: 0; y: 0
                                    width: 50; height: parent.height

                                    // Track number shown when not hovered and not playing
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !songRow.isPlaying && !hoverHandler.hovered
                                        text: (index + 1).toString()
                                        color: "#b3b3b3"
                                        font.pixelSize: 13
                                    }

                                    // Play / pause icon shown on hover or while playing
                                    Image {
                                        anchors.centerIn: parent
                                        visible: songRow.isPlaying || hoverHandler.hovered
                                        width: 22; height: 22
                                        // Show pause icon when actively playing (not paused), play icon otherwise
                                        source: (songRow.isPlaying && !songRow.isPaused)
                                                ? "qrc:/icons/menuPauseIcon.svg"
                                                : "qrc:/icons/menuPlayIcon.svg"
                                        // Tint white — wrap in a ColorOverlay if you use Qt.labs.platform,
                                        // or just keep your SVGs pre-coloured white for the play area.
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (songRow.isPlaying)
                                                backend.playAndPause()          // toggles play/pause
                                            else
                                                backend.playSongAtVisibleIndex(index)
                                        }
                                    }
                                }

                                // ── album cover (left: 50, same margin logic as C++) ────────────
                                Image {
                                    id: coverImage
                                    x: 50
                                    y: (parent.height - height) / 2      // margin = height/10 → centred
                                    width: 50; height: 50
                                    fillMode: Image.PreserveAspectCrop
                                    source: model.coverPath !== "" ? "file://" + model.coverPath
                                                            : "qrc:/images/default_cover.png"
                                }

                                // ── title + artist ──────────────────────────────────────────────
                                Column {
                                    x: coverImage.x + coverImage.width + 10
                                    width: parent.width - x - 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: model.title
                                        color: "white"
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: model.artist
                                        color: "#b3b3b3"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }

                                // ── duration ────────────────────────────────────────────────────
                                Text {
                                    x: parent.width - 105
                                    width: 60
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.duration
                                    color: "#b3b3b3"
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // ── dots / context-menu button ───────────────────────────────────
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
                                            // Map item-local position to global for a context menu,
                                            // mirroring menuRequested() in the C++ delegate.
                                            var globalPos = menuArea.mapToGlobal(0, 0)
                                            backend.showContextMenu(index, globalPos.x, globalPos.y)
                                            // expose a Q_INVOKABLE showContextMenu(int, int, int) in MainWindow
                                        }
                                    }
                                }

                                // ── hover detection for the whole row ───────────────────────────
                                HoverHandler {
                                    id: hoverHandler
                                }
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
                            Layout.preferredWidth: 300
                            Layout.minimumWidth: 300
                            Layout.maximumWidth: 300
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

                                // labelSongInfo
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
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 30
                                        Layout.rightMargin: 0
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

                                        property bool isCurrentlyPlaying: false

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
                                            source: btnPlay.isCurrentlyPlaying
                                                    ? "image://svgicons/pauseButtonIcon"
                                                    : "image://svgicons/playButtonIcon"
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        onClicked: backend.playAndPause()
                                    }

                                    // Connections block to update btnPlay.isCurrentlyPlaying
                                    // from QMediaPlayer's playbackStateChanged signal exposed via
                                    // PlaybackController -> backend.
                                    Connections {
                                        target: backend
                                        function onPlaybackStateChanged(state) {
                                            // QMediaPlayer::PlayingState == 1
                                            btnPlay.isCurrentlyPlaying = (state === 1)
                                        }
                                        // Also reset when no song is selected
                                        function onCurrentLibraryIndexChanged() {
                                            if (backend.currentLibraryIndex < 0)
                                                btnPlay.isCurrentlyPlaying = false
                                        }
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
                                        Layout.preferredWidth: 44
                                        Layout.preferredHeight: 44
                                        Layout.leftMargin: 0
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
                                    value: 50

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