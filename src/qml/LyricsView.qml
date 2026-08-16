import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    id: lyricsRoot

    property string lyricsPath: ""
    property real positionMs: 0

    property var lines: []
    property int activeLine: -1

    // Minimum height of a lyric row.
    readonly property real minLineHeight: 90

    // Must match the visible Text.
    readonly property real textSidePadding: 32
    readonly property real lyricFontSize: 40
    readonly property bool lyricFontBold: true

    // Active lyric is centered around this percentage of the viewport.
    readonly property real activeCenterRatio: 0.35

    property bool animationsEnabled: true

    // Measured height for every lyric.
    property var lineHeights: []

    property bool measurementsReady: false

    readonly property real textWidth: Math.max(0, width - textSidePadding * 2)

    onLyricsPathChanged: parseLrc()

    onWidthChanged: {
        Qt.callLater(function() {
            rebuildLayout()
        })
    }

    onPositionMsChanged: updateActiveLine()

    function parseLrc() {
        lines = []
        activeLine = -1
        lineHeights = []
        measurementsReady = false

        if (lyricsPath === "")
            return

        var raw = backend.readFileAsString(lyricsPath)

        if (raw === "")
            return

        var rawLines = raw.split("\n")
        var parsed = []
        var re = /^\[(\d{2}):(\d{2})[\.:](\d{2,3})\](.*)/

        for (var i = 0; i < rawLines.length; i++) {
            var m = rawLines[i].trim().match(re)

            if (!m)
                continue

            var minutes = parseInt(m[1], 10)
            var seconds = parseInt(m[2], 10)
            var fracStr = m[3]
            var frac = fracStr.length === 2
                    ? parseInt(fracStr, 10) * 10
                    : parseInt(fracStr, 10)

            var ms = (minutes * 60 + seconds) * 1000 + frac
            var text = m[4].trim()

            if (text !== "")
                parsed.push({timeMs: ms,text: text})
        }

        parsed.sort(function(a, b) {
            return a.timeMs - b.timeMs
        })

        lines = parsed

        // Wait until the measurement Repeater has recreated its delegates.
        Qt.callLater(function() {
            rebuildLayout()
            updateActiveLine()
        })
    }

    function updateActiveLine() {
        if (lines.length === 0) {
            activeLine = -1
            return
        }

        var idx = -1

        for (var i = 0; i < lines.length; i++) {
            if (lines[i].timeMs <= positionMs)
                idx = i
            else
                break
        }

        if (idx !== activeLine)
            activeLine = idx
    }

    // ------------------------------------------------------------
    // Height measurement
    // ------------------------------------------------------------

    Repeater {
        id: measurementRepeater

        model: lyricsRoot.lines.length

        delegate: Item {
            width: lyricsRoot.textWidth
            height: 1
            visible: false

            Text {
                id: measurementText

                width: parent.width

                wrapMode: Text.WordWrap

                text: lyricsRoot.lines[index]
                      ? lyricsRoot.lines[index].text
                      : ""

                font.pixelSize: lyricsRoot.lyricFontSize
                font.bold: lyricsRoot.lyricFontBold
            }
        }
    }

    function rebuildLayout() {
        if (lines.length === 0) {
            lineHeights = []
            measurementsReady = true
            return
        }

        if (measurementRepeater.count !== lines.length) {
            measurementsReady = false

            Qt.callLater(function() { rebuildLayout()})

            return
        }

        var heights = []

        for (var i = 0; i < lines.length; i++) {
            var measurementItem = measurementRepeater.itemAt(i)

            if (!measurementItem)
                return

            var measuredText = measurementItem.children[0]

            if (!measuredText)
                return

            // Actual wrapped height plus vertical breathing room.
            var h = Math.max(
                minLineHeight,
                measuredText.implicitHeight + 40
            )

            heights.push(h)
        }

        lineHeights = heights
        measurementsReady = true

        // Column needs one layout pass after the new heights are applied.
        Qt.callLater(function() {
            updateMargins()

            if (activeLine >= 0)
                positionActiveLine(false)
        })
    }

    function heightForLine(index) {
        if (index < 0 || index >= lineHeights.length)
            return minLineHeight

        return lineHeights[index]
    }

    // ------------------------------------------------------------
    // Exact layout margins
    // ------------------------------------------------------------

    function updateMargins() {
        if (!measurementsReady || lines.length === 0)
            return

        var firstHeight = heightForLine(0)
        var lastHeight = heightForLine(lines.length - 1)

        lyricsView.topMargin = Math.max(
            0,
            lyricsView.height * activeCenterRatio
            - firstHeight / 2
        )

        lyricsView.bottomMargin = Math.max(
            0,
            lyricsView.height * (1.0 - activeCenterRatio)
            - lastHeight / 2
        )
    }

    // ------------------------------------------------------------
    // Exact positioning
    // ------------------------------------------------------------

    function targetYForLine(index) {
        if (!measurementsReady)
            return 0

        if (index < 0 || index >= lines.length)
            return 0

        var item = lyricRepeater.itemAt(index)

        if (!item)
            return 0

        // IMPORTANT:
        // item.y is relative to contentColumn.
        //
        // contentColumn.y is the actual top margin inside the Flickable.
        // Therefore this is the real content-space position of the lyric.
        var itemTop = contentColumn.y + item.y

        return itemTop
             + item.height / 2
             - lyricsView.height * activeCenterRatio
    }

    function positionActiveLine(animated) {
        if (activeLine < 0 || !measurementsReady)
            return

        var target = targetYForLine(activeLine)

        if (animated) {
            scrollAnim.to = target
            scrollAnim.restart()
        } else {
            scrollAnim.stop()
            lyricsView.contentY = target
        }
    }

    onActiveLineChanged: {
        if (activeLine < 0 || !measurementsReady)
            return

        Qt.callLater(function() {
            if (activeLine >= 0 && measurementsReady)
                positionActiveLine(true)
        })
    }

    function snapToActiveLine() {
        if (activeLine < 0 || !measurementsReady)
            return

        var target = targetYForLine(activeLine)

        scrollAnim.stop()
        lyricsView.contentY = target
    }

    function resetToTop() {
        scrollAnim.stop()
        lyricsView.contentY = 0
    }

    Flickable {
        id: lyricsView

        anchors.fill: parent

        clip: true
        interactive: false

        contentWidth: width

        // The column is placed at topMargin inside the content.
        contentHeight:
            topMargin
            + contentColumn.height
            + bottomMargin

        property real topMargin: 0
        property real bottomMargin: 0

        onHeightChanged: {
            if (lyricsRoot.measurementsReady) {
                lyricsRoot.updateMargins()

                Qt.callLater(function() {
                    if (lyricsRoot.activeLine >= 0)
                        lyricsRoot.positionActiveLine(false)
                })
            }
        }

        Column {
            id: contentColumn

            x: 0
            y: lyricsView.topMargin

            width: lyricsView.width

            spacing: 0

            Repeater {
                id: lyricRepeater

                model: lyricsRoot.lines.length

                delegate: Item {
                    id: delegateRoot

                    width: lyricsView.width
                    height: lyricsRoot.heightForLine(index)

                    readonly property bool isActive:
                        index === lyricsRoot.activeLine

                    readonly property int dist:
                        index - lyricsRoot.activeLine

                    readonly property bool isPast:
                        dist < 0

                    readonly property bool isFuture:
                        dist > 0

                    Text {
                        id: lyricText

                        anchors.centerIn: parent

                        width:
                            parent.width
                            - lyricsRoot.textSidePadding * 2

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        wrapMode: Text.WordWrap

                        text: lyricsRoot.lines[index]
                              ? lyricsRoot.lines[index].text
                              : ""

                        color: "#FFFFFFFF"

                        font.pixelSize: lyricsRoot.lyricFontSize
                        font.bold: lyricsRoot.lyricFontBold

                        readonly property real targetScale: {
                            if (isActive)
                                return 1.0

                            if (Math.abs(dist) === 1)
                                return 0.70

                            if (Math.abs(dist) === 2)
                                return 0.58

                            return 0.50
                        }

                        scale: targetScale
                        transformOrigin: Item.Center

                        Behavior on scale {
                            SpringAnimation {
                                spring: 3.25
                                damping: 0.82
                                epsilon: 0.001
                            }
                        }

                        readonly property real targetOpacity: {
                            if (isActive)
                                return 1.0

                            if (isPast) {
                                var d = -dist

                                return Math.max(
                                    0.06,
                                    0.30 - (d - 1) * 0.08
                                )
                            }

                            if (dist === 1)
                                return 0.35

                            if (dist === 2)
                                return 0.22

                            return 0.12
                        }

                        opacity: targetOpacity

                        Behavior on opacity {
                            SpringAnimation {
                                spring: 1.75
                                damping: 0.75
                                epsilon: 0.001
                            }
                        }

                        layer.enabled: true

                        layer.effect: FastBlur {
                            radius: {
                                if (delegateRoot.isActive)
                                    return 0

                                var absDist =
                                    Math.abs(delegateRoot.dist)

                                if (absDist === 1)
                                    return 6

                                if (absDist === 2)
                                    return 14

                                return 22
                            }

                            Behavior on radius {
                                SpringAnimation {
                                    spring: 2.0
                                    damping: 0.80
                                    epsilon: 0.1
                                }
                            }
                        }
                    }
                }
            }
        }

        SpringAnimation {
            id: scrollAnim

            target: lyricsView
            property: "contentY"

            spring: 2.25
            damping: 0.78
            epsilon: 0.5
        }
    }
}