import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects   // for GaussianBlur / layer.effect

Item {
    id: lyricsRoot

    property string lyricsPath: ""
    property real   positionMs: 0

    property var lines: []
    property int activeLine: -1

    readonly property int lineHeight: 104   // generous breathing room at max scale
    property bool animationsEnabled: true

    onLyricsPathChanged: {
        parseLrc()
    }
    onPositionMsChanged: updateActiveLine()

    function parseLrc() {
        lines = []
        activeLine = -1
        if (lyricsPath === "") return

        var raw = backend.readFileAsString(lyricsPath)
        if (raw === "") return

        var rawLines = raw.split("\n")
        var parsed = []
        var re = /^\[(\d{2}):(\d{2})[\.:](\d{2,3})\](.*)/

        for (var i = 0; i < rawLines.length; i++) {
            var m = rawLines[i].trim().match(re)
            if (!m) continue

            var minutes = parseInt(m[1], 10)
            var seconds = parseInt(m[2], 10)
            var fracStr = m[3]
            var frac = fracStr.length === 2
                       ? parseInt(fracStr, 10) * 10
                       : parseInt(fracStr, 10)

            var ms   = (minutes * 60 + seconds) * 1000 + frac
            var text = m[4].trim()
            if (text !== "")
                parsed.push({ timeMs: ms, text: text })
        }

        parsed.sort(function(a, b) { return a.timeMs - b.timeMs })
        lines = parsed
        updateActiveLine()
    }

    function updateActiveLine() {
        if (lines.length === 0) { 
            activeLine = -1;
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

    function targetYForLine(line) {
        return line * lineHeight
            - lyricsView.height * 0.35
            + lineHeight / 2
    }

    onActiveLineChanged: {
        if (activeLine < 0)
            return

        scrollAnim.to = targetYForLine(activeLine)
        scrollAnim.restart()
    }

    function snapToActiveLine() {
        if (activeLine < 0)
            return

        scrollAnim.stop()
        lyricsView.contentY = targetYForLine(activeLine)
    }

    function resetToTop() {
        scrollAnim.stop()
        lyricsView.contentY = -130
    }

    ListView {
        id: lyricsView
        anchors.fill: parent
        model: lyricsRoot.lines.length
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds

        topMargin: Math.max(
            0,
            lyricsRoot.targetY - lyricsRoot.lineHeight / 2
        )

        bottomMargin: Math.max(
            0,
            lyricsView.height
            - lyricsRoot.targetY
            - lyricsRoot.lineHeight / 2
        )

        // ── Spring scroll — Apple Music uses a spring for the list position ──
        SpringAnimation {
            id: scrollAnim
            target: lyricsView
            property: "contentY"

            spring: 2.25
            damping: 0.78
            epsilon: 0.5
        }

        delegate: Item {
            id: delegateRoot
            width: lyricsView.width
            height: lyricsRoot.lineHeight

            readonly property bool isActive:  index === lyricsRoot.activeLine
            readonly property int  dist:      index - lyricsRoot.activeLine
            readonly property bool isPast:    dist < 0
            readonly property bool isFuture:  dist > 0

            // ── Sizer (invisible, always at max font so height never reflows) ─
            Text {
                id: sizer
                visible: false
                width: parent.width - 64
                wrapMode: Text.WordWrap
                font.pixelSize: 40
                font.bold: true
                text: lyricsRoot.lines[index] ? lyricsRoot.lines[index].text : ""
            }

            // ── Visible text with layer-based blur ───────────────────────────
            Text {
                id: lyricText
                anchors.centerIn: parent
                width: parent.width - 64
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: lyricsRoot.lines[index] ? lyricsRoot.lines[index].text : ""

                color: "#FFFFFFFF"
                font.pixelSize: 40
                font.bold: true

                // ── Scale via SpringAnimation for organic Apple-style feel ──
                readonly property real targetScale: {
                    if (isActive)               return 1.0
                    if (Math.abs(dist) === 1)   return 0.70
                    if (Math.abs(dist) === 2)   return 0.58
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

                // ── Opacity: past lines fade harder than future ─────────────
                readonly property real targetOpacity: {
                    if (isActive) return 1.0
                    // Past lines dim more aggressively (they've been sung)
                    if (isPast) {
                        var d = -dist   // positive distance behind
                        return Math.max(0.06, 0.30 - (d - 1) * 0.08)
                    }
                    // Future lines slightly brighter — anticipation
                    if (dist === 1) return 0.35
                    if (dist === 2) return 0.22
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

                // ── Blur: inactive lines get a subtle depth-of-field blur ───
                // blur radius scales with distance from active; active = 0
                layer.enabled: true
                layer.effect: FastBlur {
                    radius: {
                        if (delegateRoot.isActive) return 0
                        var absDist = Math.abs(delegateRoot.dist)
                        if (absDist === 1) return 6
                        if (absDist === 2) return 14
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