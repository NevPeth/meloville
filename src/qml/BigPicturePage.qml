import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool closing: false
    visible: !root.closing

    property string lyricsPath: backend.currentSongLyricsPath ?? ""
    property bool hasLyrics: lyricsPath !== "" && root.width >= 700
    property int layoutShift: Math.min(70, root.width/32)
    readonly property int coverSize: Math.min(root.hasLyrics ? 380 : 440, root.hasLyrics ? root.width/4 : root.width-90, 12*root.height/24)
    readonly property real normalWidth: 1280
    readonly property real normalHeight: 720

    signal exitBigPicture()

    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    Item {
        id: blurSource
        width:  root.width
        height: root.height
        visible: false

        Image {
            anchors.fill: parent
            source: backend.currentSongCoverPath !== ""
                    ? "file://" + backend.currentSongCoverPath
                    : ""
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }
    }

    // Three heavy blur passes otherwise it still looks too crsip
    // I know it's hella graphic intensive but like, I need it to look good to, y'know?
    GaussianBlur {
        id: pass1
        anchors.fill: blurSource
        source: blurSource
        radius: 64
        samples: 63
        deviation: 24
        visible: true
        cached: true
    }
    GaussianBlur {
        id: pass2
        anchors.fill: blurSource
        source: pass1
        radius: 64
        samples: 63
        deviation: 24
        visible: true
        cached: true
    }
    GaussianBlur {
        id: pass3
        anchors.fill: blurSource
        source: pass2
        radius: 64
        samples: 63
        deviation: 24
        visible: true
        cached: true
    }

    // Dim overlay so that user can actually see play controls
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 67 / 255.0)
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.min(5, root.height/200)
        anchors.rightMargin: Math.min(5, root.height/200)
        anchors.topMargin: Math.min(5, root.height/200)
        anchors.bottomMargin: Math.min(5, root.height/200)
        spacing: 0

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: !root.hasLyrics
            Layout.preferredWidth: root.hasLyrics ? root.width * 0.45 : root.width
            spacing: 0

            // ---- TOP BAR ----------------------------------------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: false
                Layout.preferredHeight: Math.min(30, root.height/20)
                Layout.minimumHeight: Math.min(30, root.height/20)
                spacing: 0

                Button {
                    id: btnExitBigPicture
                    Layout.preferredWidth: Math.min(50, root.height/10)
                    Layout.preferredHeight: Math.min(50, root.height/10)
                    background: Item {}
                    contentItem: Image {
                        source: btnExitBigPicture.hovered
                                ? "image://svgicons/closeIconBigHovered"
                                : "image://svgicons/closeIconBigNormal"
                        fillMode: Image.PreserveAspectFit
                    }
                    onClicked: {
                        root.closing = true; 
                        root.exitBigPicture()
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 8
            }

            // -- ALBUM ART -----------------------
            // Sized to fit the available height proportionally — never overflows
            Item {
                id: albumCover
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.coverSize
                Layout.preferredHeight: root.coverSize
                Layout.minimumHeight: 20
                Layout.minimumWidth: 20
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0

                DragHandler {
                    target: null
                    grabPermissions: PointerHandler.TakeOverForbidden
                    onActiveChanged: if (active && backend.customResizing) appWindow.startSystemMove()
                }

                // Placeholder background so nothing shows when no song
                Rectangle {
                    id: coverPlaceholder
                    anchors.fill: parent
                    radius: 16
                    color: "transparent"
                }

                // Clip mask shape (rounded rect) for the animation
                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: 16
                    visible: false
                }

                Image {
                    id: labelCoverArtBig
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: backend.currentLibraryIndex >= 0 && backend.currentSongCoverPath !== ""
                            ? "file://" + backend.currentSongCoverPath
                            : "qrc:/icons/default.svg"
                            
                    visible: false
                    smooth: true

                    onSourceChanged: {
                        coverReveal.opacity = 0
                        coverReveal.scale = 0.92
                        coverAppearAnim.restart()
                    }
                }

                // The visible cover: masked to rounded rect so corners stay
                // rounded throughout the scale-in animation
                OpacityMask {
                    id: coverReveal
                    anchors.fill: parent
                    source: labelCoverArtBig
                    maskSource: coverMask
                    visible: backend.currentLibraryIndex >= 0
                    opacity: 0
                    scale: 0.92
                    transformOrigin: Item.Center
                }

                ParallelAnimation {
                    id: coverAppearAnim
                    NumberAnimation {
                        target: coverReveal
                        property: "opacity"
                        to: 1.0
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: coverReveal
                        property: "scale"
                        to: 1.0
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Gap between art and text — smaller than the top gap
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 8
                Layout.maximumHeight: 24
            }

            // -- SONG TITLE + ARTIST -----------------------------------------
            Column {
                Layout.fillWidth: true
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0
                spacing: 4

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: backend.currentLibraryIndex >= 0 ? backend.currentSongTitle : "Nothing Playing"
                    color: "#E6FFFFFF"
                    font.pixelSize: Math.min(32, root.height/20)
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: backend.currentLibraryIndex >= 0 ? backend.currentSongArtist : "Unknown Artist"
                    color: "#96FFFFFF"
                    font.pixelSize: Math.min(20, root.height/32)
                    elide: Text.ElideRight
                }
            }

            // Gap between text and seek bar - also flexible but capped
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.hasLyrics ? 3 : 2
                Layout.maximumHeight: root.hasLyrics ? 30 : 20
            }

            // -- SEEK BAR --------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0
                spacing: 6

                Item { Layout.fillWidth: true }

                Text {
                    id: labelCurrentTimeBig
                    text: formatTime(backend.playerPosition)
                    color: Qt.rgba(1, 1, 1, 150 / 255.0)
                    font.pixelSize: Math.min(13, root.height/32)
                    Layout.minimumWidth: 38
                    horizontalAlignment: Text.AlignRight

                    function formatTime(ms) {
                        var s = Math.floor(ms / 1000)
                        var m = Math.floor(s / 60)
                        s = s % 60
                        return m + ":" + (s < 10 ? "0" : "") + s
                    }
                }

                Slider {
                    id: sliderPositionBig
                    Layout.preferredWidth: root.hasLyrics ? albumCover.width + 96 : Math.min(root.width * 0.65, 900)
                    Layout.preferredHeight: Math.min(20, root.height/32)
                    from: 0
                    to: Math.max(1, backend.playerDuration)
                    value: sliderPositionBig.pressed ? sliderPositionBig.value : backend.playerPosition
                    hoverEnabled: true

                    onPressedChanged: {
                        if (!pressed){
                            backend.seekTo(sliderPositionBig.value)
                            lyricsViewBig.snapToActiveLine()
                        }
                    }

                    handle: Rectangle {
                        implicitWidth:  14
                        implicitHeight: 14
                        x: sliderPositionBig.leftPadding +
                            sliderPositionBig.visualPosition * (sliderPositionBig.availableWidth - width)
                        y: sliderPositionBig.topPadding +
                            sliderPositionBig.availableHeight / 2 - height / 2
                        radius: width / 2
                        color: "white"
                        visible: sliderPositionBig.hovered || sliderPositionBig.pressed
                    }

                    background: Rectangle {
                        x: sliderPositionBig.leftPadding
                        y: sliderPositionBig.topPadding + sliderPositionBig.availableHeight / 2 - height / 2
                        width:  sliderPositionBig.availableWidth
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.3)

                        Rectangle {
                            width:  sliderPositionBig.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color:  "white"
                        }
                    }
                }

                Text {
                    id: labelTotalTimeBig
                    text: formatTime(backend.playerDuration)
                    color: Qt.rgba(1, 1, 1, 150 / 255.0)
                    font.pixelSize: Math.min(13, root.height/32)
                    Layout.minimumWidth: 38
                    horizontalAlignment: Text.AlignLeft

                    function formatTime(ms) {
                        var s = Math.floor(ms / 1000)
                        var m = Math.floor(s / 60)
                        s = s % 60
                        return m + ":" + (s < 10 ? "0" : "") + s
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Small fixed gap
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.hasLyrics ? Math.min(40, root.height/16) : Math.min(32, root.height/20)
                Layout.minimumHeight: 0
            }

            // -- PLAYBACK BUTTONS -----------------------------------
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0
                Layout.topMargin: -15
                spacing: Math.min(20, root.width/100)

                Item { Layout.fillWidth: true }

                Button {
                    id: btnShuffleBig
                    Layout.preferredWidth: Math.min(40, root.height/10)
                    Layout.preferredHeight: Math.min(40, root.height/10)
                    background: Item {}
                    contentItem: Image {
                        source: (btnShuffleBig.hovered || backend.shuffleMode)
                                ? "image://svgicons/shuffleIconBigHovered"
                                : "image://svgicons/shuffleIconBigNormal"
                        fillMode: Image.PreserveAspectFit
                    }
                    onClicked: backend.toggleShuffle()
                }

                Button {
                    id: btnReverseBig
                    Layout.preferredWidth: Math.min(60, root.height/8)
                    Layout.preferredHeight: Math.min(60, root.height/8)
                    background: Item {}
                    contentItem: Image {
                        source: "image://svgicons/reverseIconBig"
                        fillMode: Image.PreserveAspectFit
                    }
                    onClicked: {
                        backend.playPreviousSong()
                        lyricsViewBig.resetToTop()
                    }
                }

                Button {
                    id: btnPlayBig
                    Layout.preferredWidth: Math.min(70, root.height/7)
                    Layout.preferredHeight: Math.min(70, root.height/7)
                    background: Item {}
                    contentItem: Image {
                        source: backend.playing
                                ? "image://svgicons/pauseIconBig"
                                : "image://svgicons/playIconBig"
                        fillMode: Image.PreserveAspectFit
                    }
                    onClicked: backend.playAndPause()
                }

                Button {
                    id: btnSkipBig
                    Layout.preferredWidth: Math.min(60, root.height/8)
                    Layout.preferredHeight: Math.min(60, root.height/8)
                    background: Item {}
                    contentItem: Image {
                        source: "image://svgicons/skipIconBig"
                        fillMode: Image.PreserveAspectFit
                    }
                    onClicked: {
                        backend.playNextSong()
                        lyricsViewBig.resetToTop()
                    }
                }

                Button {
                    id: btnRepeatBig
                    Layout.preferredWidth: Math.min(40, root.height/10)
                    Layout.preferredHeight: Math.min(40, root.height/10)
                    background: Item {}
                    contentItem: Image {
                        source: (btnRepeatBig.hovered || backend.repeatMode)
                                ? "image://svgicons/repeatIconBigHovered"
                                : "image://svgicons/repeatIconBigNormal"
                        fillMode: Image.PreserveAspectFit
                    }
                    onClicked: backend.toggleRepeat()
                }

                Item { Layout.fillWidth: true }
            }

            // Small fixed gap
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.hasLyrics ? Math.min(40, root.height/16) : Math.min(32, root.height/20)
                Layout.minimumHeight: 0
            }

            // -- VOLUME ROW -----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0
                Layout.topMargin: -20
                spacing: 0

                Item { Layout.fillWidth: true }

                Button {
                    id: speakerLeftBigIcon
                    Layout.preferredWidth: Math.min(40, root.height/12)
                    Layout.preferredHeight: Math.min(40, root.height/12)
                    Layout.rightMargin: -10
                    enabled: false
                    background: Item {}
                    contentItem: Image {
                        source: speakerLeftBigIcon.hovered
                                ? "image://svgicons/speakerLeftIconHovered"
                                : "image://svgicons/speakerLeftIconNormal"
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Slider {
                    id: sliderVolumeBig
                    Layout.preferredWidth: root.hasLyrics ? Math.min(albumCover.width, 340) : Math.min(root.width * 0.45, 500)
                    Layout.minimumWidth: 50
                    Layout.preferredHeight: Math.min(20, root.height/32)
                    from: 0
                    to: 100
                    value: backend.volume
                    onMoved: backend.volume = value
                    hoverEnabled: true

                    handle: Rectangle {
                        implicitWidth:  12
                        implicitHeight: Math.min(12, root.height/40)
                        x: sliderVolumeBig.leftPadding +
                        sliderVolumeBig.visualPosition * (sliderVolumeBig.availableWidth - width)
                        y: sliderVolumeBig.topPadding +
                        sliderVolumeBig.availableHeight / 2 - height / 2
                        radius: width / 2
                        color: "white"
                        visible: sliderVolumeBig.hovered
                    }

                    background: Rectangle {
                        x: sliderVolumeBig.leftPadding
                        y: sliderVolumeBig.topPadding + sliderVolumeBig.availableHeight / 2 - height / 2
                        width:  sliderVolumeBig.availableWidth
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.3)

                        Rectangle {
                            width:  sliderVolumeBig.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color:  "white"
                        }
                    }
                }

                Button {
                    id: speakerRightBigIcon
                    Layout.preferredWidth: Math.min(40, root.height/12)
                    Layout.preferredHeight: Math.min(40, root.height/12)
                    Layout.leftMargin: -10
                    enabled: false
                    background: Item {}
                    contentItem: Image {
                        source: speakerRightBigIcon.hovered
                                ? "image://svgicons/speakerRightIconHovered"
                                : "image://svgicons/speakerRightIconNormal"
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // When default it should be 105, when height is decreasing, the spacer should decrease
            // but if width is decreasing and height is the same, the spacer should increase it to
            // make the content look centered.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: {
                    if (root.height < root.normalHeight) {
                        return Math.min(105, root.height / 7)
                    } else if (root.width < root.normalWidth) {
                        return root.hasLyrics ? 105 * (root.normalWidth / root.width) : 105 * (root.normalWidth / root.width)/2
                    } else {
                        return 105
                    }
                }
                Layout.minimumHeight: 0
            }
        }
        Item {
            visible: root.hasLyrics
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: root.hasLyrics ? root.width * 0.45 : 0
            Layout.topMargin: -55

            LyricsView {
                id: lyricsViewBig
                anchors.fill: parent
                anchors.topMargin: 48
                anchors.bottomMargin: 8
                lyricsPath: root.lyricsPath
                positionMs: backend.playerPosition
                Component.onCompleted: {
                    snapToActiveLine()
                }
            }
        }
    }
}