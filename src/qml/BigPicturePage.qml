import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool closing: false
    visible: !root.closing

    property string lyricsPath: backend.currentSongLyricsPath ?? ""
    property bool hasLyrics: lyricsPath !== ""
    property int layoutShift: 70
    readonly property real coverSize: root.hasLyrics
        ? Math.min(root.width * 0.38, 380)
        : Math.min(root.width * 0.45, 420)

    signal exitBigPicture()

    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    // ── 1. Low‑resolution source (loses fine detail) ──
    Item {
        id: blurSource
        width:  root.width          // tiny → only broad colour areas remain after blur
        height: root.height
        visible: false       // we don't need to see it directly

        Image {
            anchors.fill: parent
            source: backend.currentSongCoverPath !== ""
                    ? "file://" + backend.currentSongCoverPath
                    : "qrc:/icons/default.svg"
            fillMode: Image.PreserveAspectCrop
            smooth: true      // smooth scaling keeps colour blending clean
        }
    }

    // ── 2. Three heavy blur passes (combined radius ~192 on a 100‑px image) ──
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

    // ── 5. Dim overlay (unchanged) ──
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 45 / 255.0)
    }
    // ─────────────────────────────────────────────────────────────
    // CONTENT — proportional layout that works at any window height
    // ─────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin:   5
        anchors.rightMargin:  5
        anchors.topMargin:    5
        anchors.bottomMargin: 0
        spacing: 0

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: !root.hasLyrics
            Layout.preferredWidth: root.hasLyrics ? root.width * 0.45 : root.width
            Layout.bottomMargin: 70
            spacing: 0

            // ── TOP BAR ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: false
                Layout.preferredHeight: 30
                Layout.minimumHeight: 30
                Layout.maximumHeight: 30
                spacing: 0

                Button {
                    id: btnExitBigPicture
                    Layout.preferredWidth:  50
                    Layout.preferredHeight: 50
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

            // Flexible gap above album art (takes 1 share of remaining space)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 8
            }

            // ── ALBUM ART ─────────────────────────────────────────────
            // Sized to fit the available height proportionally — never overflows
            Item {
                Layout.alignment: Qt.AlignHCenter
                // Square: use the smaller of available width or 420
                Layout.preferredWidth:  root.coverSize
                Layout.preferredHeight: root.coverSize
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0

                // Placeholder background — transparent, so nothing shows when no song
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
                            
                    visible: false  // OpacityMask renders it; this stays hidden
                    smooth: true

                    onSourceChanged: {
                        coverReveal.opacity = 0
                        coverReveal.scale   = 0.92
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
                Layout.minimumHeight: 6
                Layout.maximumHeight: 24
            }

            // ── SONG TITLE + ARTIST ───────────────────────────────────
            Column {
                Layout.fillWidth: true
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0
                spacing: 4

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: backend.currentLibraryIndex >= 0 ? backend.currentSongTitle : "Nothing Playing"
                    color: "#E6FFFFFF"
                    font.pixelSize: 32
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: backend.currentLibraryIndex >= 0 ? backend.currentSongArtist : "Unknown Artist"
                    color: "#96FFFFFF"
                    font.pixelSize: 20
                    elide: Text.ElideRight
                }
            }

            // Gap between text and seek bar — also flexible but capped
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.hasLyrics ? 20 : 6
                Layout.maximumHeight: root.hasLyrics ? 30 : 20
            }

            // ── SEEK BAR ──────────────────────────────────────────────
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
                    font.pixelSize: 13
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
                    Layout.preferredWidth: root.hasLyrics ? root.coverSize + 96 : Math.min(root.width * 0.65, 900)
                    Layout.preferredHeight: 20
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
                    font.pixelSize: 13
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
                Layout.minimumHeight: root.hasLyrics ? 20 : 12
            }

            // ── PLAYBACK BUTTONS ──────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0
                spacing: 20

                Item { Layout.fillWidth: true }

                Button {
                    id: btnShuffleBig
                    Layout.preferredWidth:  40
                    Layout.preferredHeight: 40
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
                    Layout.preferredWidth:  60
                    Layout.preferredHeight: 60
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
                    Layout.preferredWidth:  70
                    Layout.preferredHeight: 70
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
                    Layout.preferredWidth:  60
                    Layout.preferredHeight: 60
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
                    Layout.preferredWidth:  40
                    Layout.preferredHeight: 40
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
                Layout.minimumHeight: root.hasLyrics ? 20 : 12
            }

            // ── VOLUME ROW ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Layout.leftMargin: root.hasLyrics ? root.layoutShift : 0
                spacing: 0

                Item { Layout.fillWidth: true }

                Button {
                    id: speakerLeftBigIcon
                    Layout.preferredWidth:  40
                    Layout.preferredHeight: 40
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
                    Layout.preferredWidth: root.hasLyrics ? Math.min(root.coverSize, 340) : Math.min(root.width * 0.45, 500)
                    Layout.minimumWidth:   200
                    Layout.preferredHeight: 20
                    from: 0
                    to:   100
                    value: backend.volume
                    onMoved: backend.volume = value
                    hoverEnabled: true

                    handle: Rectangle {
                        implicitWidth:  12
                        implicitHeight: 12
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
                    Layout.preferredWidth:  40
                    Layout.preferredHeight: 40
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

            // Bottom flexible gap (1 share — same as top, keeps content centred)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 8
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