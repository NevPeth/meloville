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
    property int playlistButtonSize: 60
    property int libraryButtonSize: 70
    Component {
        id: mainPageComponent
        Rectangle {
            color: "#121212"

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                spacing: 5
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
                        Layout.preferredWidth: 60
                        Layout.minimumWidth: 60
                        Layout.maximumWidth: 60
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
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                        }

                        // listViewAlbums (AlbumGridView)
                        ListView {
                            id: listViewAlbums
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 150
                            clip: true
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
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
                                }

                                // labelSongInfo

                                Text {
                                    id: labelSongInfo
                                    text: "Nothing Playing<br><span style='color:#b3b3b3; font-size:11px;'>Unknown Artist</span>"
                                    textFormat: Text.RichText
                                    color: "white"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.NoWrap
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

                                    // btnShuffle
                                    Button {
                                        id: btnShuffle
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 30
                                        Layout.rightMargin: 0
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnShuffle.hovered
                                                ? "image://svgicons/shuffleIconHovered"
                                                : "image://svgicons/shuffleIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    // btnReverse
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
                                    }

                                    // btnPlay
                                    Button {
                                        id: btnPlay
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 60
                                        background: Item {}
                                        contentItem: Image {
                                            source: "image://svgicons/playButtonIcon"
                                            fillMode: Image.PreserveAspectFit
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
                                    }

                                    // btnRepeat
                                    Button {
                                        id: btnRepeat
                                        Layout.preferredWidth: 44
                                        Layout.preferredHeight: 44
                                        Layout.leftMargin: 0
                                        background: Item {}
                                        contentItem: Image {
                                            source: btnRepeat.hovered
                                                ? "image://svgicons/repeatIconHovered"
                                                : "image://svgicons/repeatIconNormal"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }
                                }

                                // Seek bar row
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 3

                                    // labelCurrentTime
                                    Text {
                                        id: labelCurrentTime
                                        text: "0:00"
                                        color: "#b3b3b3"
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignRight
                                        Layout.minimumWidth: 32
                                    }

                                    // sliderPosition
                                    Slider {
                                        id: sliderPosition
                                        Layout.minimumWidth: 320
                                        Layout.maximumWidth: 420
                                        Layout.preferredHeight: 20
                                        from: 0; to: 100; value: 0

                                        hoverEnabled: true

                                        handle: Rectangle {
                                            implicitWidth: 10
                                            implicitHeight: 10

                                            x: sliderPosition.leftPadding +
                                               sliderPosition.visualPosition * (sliderPosition.availableWidth - width)

                                            y: sliderPosition.topPadding +
                                               sliderPosition.availableHeight / 2 - height / 2

                                            radius: width / 2
                                            color: "white"

                                            visible: sliderPosition.hovered
                                            opacity: sliderPosition.hovered ? 1 : 0
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
                                        text: "0:00"
                                        color: "#b3b3b3"
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignLeft
                                        Layout.minimumWidth: 32
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