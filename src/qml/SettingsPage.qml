import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    signal closed()

    // ── Internal state ──────────────────────────────────────────────────────
    property int activeSection: 0   // 0 = General, 1 = ListenAlong
    property bool serverRunning: false
    property string serverUrl: "" 
    property bool urlCopied: false
    property bool scrobbleAuthPending: false

    Connections {
        target: backend

        function onListenAlongUrlsReady(urls) {
            if (urls.length === 0) {
                // Start failed
                root.serverRunning = false
                root.serverUrl = "Failed to start server."
                return
            }
            root.serverRunning = true
            // Prefer the first URL (public IP if available, else LAN)
            root.serverUrl = urls[0]
        }

        function onListenAlongStopped() {
            root.serverRunning = false
            root.serverUrl = ""
            root.urlCopied = false
        }

        function onScrobblingAuthChanged() {
            root.scrobbleAuthPending = false
        }
    }

    // ── Overlay ─────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.75

        MouseArea {
            id: overlayMouseArea
            hoverEnabled: true
            anchors.fill: parent
            onClicked: function(mouse) {
                var p = settingsPanel.mapFromItem(overlayMouseArea, mouse.x, mouse.y)
                if (!settingsPanel.contains(p))
                    root.closed()
                mouse.accepted = true
            }
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) { event.accepted = true }
        }
    }

    // ── Main panel ──────────────────────────────────────────────────────────
    Rectangle {
        id: settingsPanel
        anchors.centerIn: parent
        width: Math.min(860, root.width-50)
        height: Math.min(560, root.height-50)
        radius: 12
        color: "#111111"
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── LEFT SIDEBAR ─────────────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: Math.min(220, root.width/4)
                Layout.fillHeight: true
                color: "#0d0d0d"
                radius: 12

                // Right-side square corners
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 12
                    color: parent.color
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 24
                    anchors.bottomMargin: 16
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 2

                    // SETTINGS header label
                    Text {
                        text: "SETTINGS"
                        color: "#666666"
                        font.pixelSize: 10
                        font.letterSpacing: 1.8
                        font.bold: true
                        Layout.leftMargin: 8
                        Layout.bottomMargin: 6
                    }

                    // Tab button component
                    component TabButton: Rectangle {
                        id: tab
                        property string label: ""
                        property int sectionIndex: 0
                        property bool active: root.activeSection === sectionIndex

                        Layout.fillWidth: true
                        height: 34
                        radius: 6
                        color: active ? "#1e1e1e" : (hov.containsMouse ? "#181818" : "transparent")

                        Behavior on color { ColorAnimation { duration: 80 } }

                        // Active indicator bar
                        Rectangle {
                            width: 3
                            height: 18
                            radius: 2
                            color: "#ffffff"
                            anchors.left: parent.left
                            anchors.leftMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tab.active
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            text: tab.label
                            color: tab.active ? "white" : (hov.containsMouse ? "#cccccc" : "#888888")
                            font.pixelSize: 13
                            font.bold: tab.active

                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        HoverHandler { id: hov }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeSection = tab.sectionIndex
                                contentFlick.scrollToSection(tab.sectionIndex)
                            }
                        }
                    }
                    TabButton { label: "General";      sectionIndex: 0 }
                    TabButton { label: "Listen Along"; sectionIndex: 1 }
                    TabButton { label: "Scrobbling";   sectionIndex: 2 }

                    Item { Layout.fillHeight: true }
                }
            }

            // ── RIGHT CONTENT ────────────────────────────────────────────────
            Flickable {
                id: contentFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: contentCol.implicitHeight + 80
                boundsBehavior: Flickable.StopAtBounds

                contentWidth: width

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                // Track active section by scroll position
                onContentYChanged: {
                    var midScroll = contentY + height / 3
                    if (scrobblingSection.y !== undefined && midScroll >= scrobblingSection.y) {
                        root.activeSection = 2
                    } else if (listenAlongSection.y !== undefined && midScroll >= listenAlongSection.y) {
                        root.activeSection = 1
                    } else {
                        root.activeSection = 0
                    }
                }

                function scrollToSection(idx) {
                    if (idx === 0) {
                        contentFlick.contentY = 0
                    } else if (idx === 1) {
                        contentFlick.contentY = Math.min(
                            listenAlongSection.y,
                            contentFlick.contentHeight - contentFlick.height
                        )
                    } else if (idx === 2) {
                        contentFlick.contentY = Math.min(
                            scrobblingSection.y,
                            contentFlick.contentHeight - contentFlick.height
                        )
                    }
                }

                ColumnLayout {
                    id: contentCol
                    width: contentFlick.width
                    spacing: 0

                    // ── Shared section header component ─────────────────────────────
                    component SectionHeader: ColumnLayout {
                        property string title: ""
                        property string subtitle: ""
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: parent.title
                            color: "white"
                            font.pixelSize: 20
                            font.bold: true
                        }
                        Text {
                            text: parent.subtitle
                            color: "#888888"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.maximumWidth: root.width/2
                            visible: text !== ""
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#222222"
                            Layout.topMargin: 10
                            Layout.bottomMargin: 4
                        }
                    }

                    // ── Shared toggle row component ─────────────────────────────────
                    component ToggleRow: RowLayout {
                        property string label: ""
                        property string description: ""
                        property bool toggled: false
                        signal toggledChanged2(bool val)

                        Layout.fillWidth: true
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: parent.parent.label
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                                Layout.maximumWidth: root.width/3
                            }
                            Text {
                                text: parent.parent.description
                                color: "#888888"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                Layout.maximumWidth: root.width/3
                                visible: text !== ""
                            }
                        }

                        // Custom toggle switch
                        Rectangle {
                            id: toggleTrack
                            width: 42
                            height: 24
                            radius: 12
                            color: parent.toggled ? "#5a5a5a" : "#272727"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Rectangle {
                                id: toggleThumb
                                width: 18
                                height: 18
                                radius: 9
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                                x: 3

                                states: [
                                    State {
                                        name: "on"
                                        when: toggleTrack.parent.toggled
                                        PropertyChanges { target: toggleThumb; x: toggleTrack.width - toggleThumb.width - 3 }
                                    },
                                    State {
                                        name: "off"
                                        when: !toggleTrack.parent.toggled
                                        PropertyChanges { target: toggleThumb; x: 3 }
                                    }
                                ]

                                transitions: [
                                    Transition {
                                        NumberAnimation {
                                            property: "x"
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                ]
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    parent.parent.toggled = !parent.parent.toggled
                                    parent.parent.toggledChanged2(parent.parent.toggled)
                                }
                            }
                        }
                    }

                    // ── Animated slider component ───────────────────────────────────
                    component AnimatedSlider: ColumnLayout {
                        property string label: ""
                        property string unit: ""
                        property real from: 0
                        property real to: 100
                        property real value: 50
                        property real stepSize: 1
                        property string displayValue: Math.round(sliderInner.value) + " " + unit
                        property bool hoverEnabled: true
                        signal sliderMoved(real val)

                        id: animSliderRoot
                        Layout.fillWidth: true
                        Layout.maximumWidth: root.width/2
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: animSliderRoot.label
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: animSliderRoot.displayValue
                                color: "#888888"
                                font.pixelSize: 12

                                Behavior on text {
                                    // Subtle fade on value change
                                    SequentialAnimation {
                                        NumberAnimation { target: sliderValueLabel; property: "opacity"; to: 0.4; duration: 60 }
                                        NumberAnimation { target: sliderValueLabel; property: "opacity"; to: 1.0; duration: 120 }
                                    }
                                }

                                id: sliderValueLabel
                            }
                        }

                        Slider {
                            id: sliderInner
                            Layout.fillWidth: true
                            from: animSliderRoot.from
                            to: animSliderRoot.to
                            value: animSliderRoot.value
                            stepSize: animSliderRoot.stepSize
                            onValueChanged: animSliderRoot.sliderMoved(value)

                            handle: Rectangle {
                                implicitWidth: 16
                                implicitHeight: 16
                                x: sliderInner.leftPadding +
                                   sliderInner.visualPosition * (sliderInner.availableWidth - width)
                                y: sliderInner.topPadding +
                                   sliderInner.availableHeight / 2 - height / 2
                                radius: 8
                                color: "white"
                                scale: (sliderInner.pressed && hoverEnabled) ? 1.25 : (sliderInner.hovered && hoverEnabled ? 1.1 : 1.0)

                                Behavior on scale {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                                Behavior on x {
                                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                                }
                            }

                            background: Rectangle {
                                x: sliderInner.leftPadding
                                y: sliderInner.topPadding + sliderInner.availableHeight / 2 - height / 2
                                width: sliderInner.availableWidth
                                height: 4
                                radius: 2
                                color: "#333333"

                                Rectangle {
                                    width: sliderInner.visualPosition * parent.width
                                    height: parent.height
                                    radius: 2
                                    color: "white"

                                    Behavior on width {
                                        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                                    }
                                }
                            }
                        }
                    }

                    // ════════════════════════════════════════════════════════
                    //  SECTION 0 — GENERAL
                    // ════════════════════════════════════════════════════════
                    Item {
                        id: generalSection
                        Layout.fillWidth: true
                        implicitHeight: generalCol.implicitHeight

                        ColumnLayout {
                            id: generalCol
                            anchors.fill: parent
                            anchors.margins: 32
                            anchors.topMargin: 16
                            spacing: 20

                            Item { height: 10 }

                            SectionHeader {
                                title: "General"
                                subtitle: ""
                            }

                            ToggleRow {
                                label: "Compact mode"
                                description: "Reduce the height of each song row for a denser list."
                                toggled: backend.isCompact
                                onToggledChanged2: function(val) { backend.setCompactMode(val) }
                            }

                            AnimatedSlider {
                                label: "Song height"
                                unit: "px"
                                from: 32
                                to: 150
                                value: backend.delegateHeight
                                stepSize: 1
                                onSliderMoved: function(val) { backend.setDelegateHeight(val) }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#1a1a1a"
                            }

                            ToggleRow {
                                label: "Automatic playlist renewal"
                                description: "When playing a playlist, move it to the top of the list."
                                toggled: backend.playlistRenewal
                                onToggledChanged2: function(val) { backend.setPlaylistRenewalMode(val) }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#1a1a1a"
                            }

                            ToggleRow {
                                label: "Close to tray icon"
                                description: "If you want to fully close Meloville, there will be an option in the tray icon or you can use the keybind Ctrl + Q"
                                toggled: backend.closeToTray
                                onToggledChanged2: function(val) { backend.setCloseToTray(val) }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#1a1a1a"
                            }

                            ToggleRow {
                                label: "Custom window positioning and resizing"
                                description: "While active the window will move by dragging the library/album header or playlist/album descriptors. In big picture mode, dragging the cover art will move the window."
                                toggled: backend.customResizing
                                onToggledChanged2: function(val) { backend.setCustomResizing(val) }
                            }

                            ToggleRow {
                                label: "Native window decorations"
                                description: "Shows all the window decorations your native environment provides"
                                toggled: backend.nativeResizing
                                onToggledChanged2: function(val) { backend.setNativeResizing(val) }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#1a1a1a"
                            }

                            // Music folder
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: "Music folder"
                                        color: "white"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        text: "Choose the folder where your music is stored."
                                        color: "#888888"
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        id: currentFolderLabel
                                        text: backend.currentMusicFolder || "No folder selected"
                                        color: "#AAAAAA"
                                        font.pixelSize: 11
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true

                                        Connections {
                                            target: backend
                                            function onMusicFolderChanged(path) {
                                                currentFolderLabel.text = path || "No folder selected"
                                            }
                                        }
                                    }

                                    // ── Scan progress (visible only while scanning) ──────────────────
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        visible: backend.scanning

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            // Track bar
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 4
                                                radius: 2
                                                color: "#222222"

                                                Rectangle {
                                                    width: parent.width * backend.progress
                                                    height: parent.height
                                                    radius: 2
                                                    color: "white"

                                                    Behavior on width {
                                                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                                    }
                                                }
                                            }

                                            // Percentage label
                                            Text {
                                                text: Math.round(backend.progress * 100) + "%"
                                                color: "#888888"
                                                font.pixelSize: 11
                                            }
                                        }

                                        Text {
                                            text: backend.statusMessage
                                            color: "#AAAAAA"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 110
                                    height: 34
                                    radius: 6
                                    // Dim the button while scanning so it's clear it's locked
                                    opacity: backend.scanning ? 0.35 : 1.0
                                    color: folderButtonHover.hovered && !backend.scanning ? "#f0f0f0" : "white"

                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: backend.scanning ? "Scanning…" : "Change folder"
                                        color: "#111111"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    HoverHandler { id: folderButtonHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: backend.scanning ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (!backend.scanning)
                                                backend.selectMusicFolder()
                                        }
                                    }
                                }
                            }
                            Item { height: 40 }
                        }
                    }

                    // ════════════════════════════════════════════════════════
                    //  SECTION 1 — LISTEN ALONG SECTION
                    // ════════════════════════════════════════════════════════
                    Item {
                        id: listenAlongSection
                        Layout.fillWidth: true
                        implicitHeight: listenAlongCol.implicitHeight

                        ColumnLayout {
                            id: listenAlongCol
                            anchors.fill: parent
                            anchors.margins: 32
                            spacing: 20

                            SectionHeader {
                                title: "Listen Along"
                                subtitle: "Share your listening session and let others tune in to what you're playing."
                            }

                            // ── How it works ───────────────────────────────────────────────────
                            Text {
                                text: "THINGS TO NOTE"
                                color: "#555555"
                                font.pixelSize: 10
                                font.letterSpacing: 1.5
                                font.bold: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Repeater {
                                    model: [
                                        "Starts a local server on your machine.",
                                        "Only reachable by devices on the same Wi-Fi unless port-forwarded.",
                                        "Anyone with your link can tune in if they are on the same network."
                                    ]
                                    delegate: Text {
                                        Layout.fillWidth: true
                                        text: modelData
                                        color: index === 2 ? "#cc4444" : "#888888"
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.3
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#1a1a1a" }

                            // ── Port number ────────────────────────────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: "Port number"
                                        color: "white"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Optional — leave blank and we'll pick an available port for you."
                                        color: "#888888"
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // Port input
                                Rectangle {
                                    width: 90
                                    height: 34
                                    radius: 6
                                    color: portField.activeFocus ? "#1e1e1e" : "#161616"
                                    border.color: portField.activeFocus ? "#555555" : "#2a2a2a"
                                    border.width: 1

                                    Behavior on border.color { ColorAnimation { duration: 100 } }

                                    TextInput {
                                        id: portField
                                        anchors {
                                            fill: parent
                                            leftMargin: 10
                                            rightMargin: 10
                                        }
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "white"
                                        font.pixelSize: 13
                                        maximumLength: 5
                                        validator: IntValidator { bottom: 1; top: 65535 }
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        selectByMouse: true
                                    }
                                }
                            }

                            // ── Start button ───────────────────────────────────────────────────
                            Rectangle {
                                id: startBtn
                                width: startBtnText.implicitWidth + 28
                                height: 36
                                radius: 6
                                property bool hovered: false
                                color: root.serverRunning
                                    ? (hovered ? "#e06060" : "#cc4444")
                                    : (hovered ? "#f0f0f0" : "white")

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: startBtnText
                                    anchors.centerIn: parent
                                    text: root.serverRunning ? "Stop Server" : "Start Server"
                                    color: root.serverRunning ? "white" : "#111111"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                HoverHandler { onHoveredChanged: startBtn.hovered = hovered }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.serverRunning) {
                                            var portNum = parseInt(portField.text) || 0
                                            backend.startListenAlongServer(portNum)
                                        } else {
                                            backend.stopListenAlongServer()
                                            root.serverRunning = false
                                            root.serverUrl = ""
                                            root.urlCopied = false
                                        }
                                    }
                                }
                            }

                            // ── URL display ────────────────────────────────────────────────────────
                            ColumnLayout {
                                visible: root.serverUrl !== ""
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    radius: 6
                                    color: "#1a1a1a"
                                    border.color: "#2a2a2a"
                                    border.width: 1

                                    TextEdit {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: Text.AlignVCenter
                                        text: root.serverUrl
                                        color: "#cccccc"
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            Item { height: 200 }
                        }
                    }

                    // ════════════════════════════════════════════════════════
                    //  SECTION 2 — SCROBBLING
                    // ════════════════════════════════════════════════════════
                    Item {
                        id: scrobblingSection
                        Layout.fillWidth: true
                        implicitHeight: scrobblingCol.implicitHeight

                        ColumnLayout {
                            id: scrobblingCol
                            anchors.fill: parent
                            anchors.margins: 32
                            spacing: 20

                            SectionHeader {
                                title: "Scrobbling"
                                subtitle: "Track your listening history on Last.fm. Songs are scrobbled after you've listened to at least half the track or four minutes, whichever comes first."
                            }

                            // ── Status card ───────────────────────────────────────────────
                            Rectangle {
                                Layout.fillWidth: true
                                height: statusCardCol.implicitHeight + 24
                                radius: 8
                                color: "#0d0d0d"
                                border.color: "#222222"
                                border.width: 1

                                ColumnLayout {
                                    id: statusCardCol
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 16; rightMargin: 16
                                    }
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            color: backend.scrobblingAuthenticated ? "#4caf74" : "#666666"
                                            Behavior on color { ColorAnimation { duration: 300 } }
                                        }

                                        Text {
                                            text: backend.scrobblingAuthenticated
                                                ? "Connected as " + backend.scrobblingUsername
                                                : "Not connected"
                                            color: backend.scrobblingAuthenticated ? "#dddddd" : "#888888"
                                            font.pixelSize: 13
                                            font.bold: backend.scrobblingAuthenticated
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Text {
                                        visible: !backend.scrobblingAuthenticated
                                        text: "Sign in to start scrobbling your plays to Last.fm."
                                        color: "#666666"
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            // ── How it works (only shown when not authenticated) ──────────
                            ColumnLayout {
                                visible: !backend.scrobblingAuthenticated
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: "HOW IT WORKS"
                                    color: "#555555"
                                    font.pixelSize: 10
                                    font.letterSpacing: 1.5
                                    font.bold: true
                                }

                                Repeater {
                                    model: [
                                        "Clicking \"Connect\" opens Last.fm in your browser.",
                                        "Log in and approve access — you'll be redirected back automatically.",
                                        "Your session is saved locally; you won't need to sign in again."
                                    ]
                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Rectangle {
                                            width: 18; height: 18; radius: 9
                                            color: "#1e1e1e"
                                            Text {
                                                anchors.centerIn: parent
                                                text: (index + 1).toString()
                                                color: "#888888"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            text: modelData
                                            color: "#888888"
                                            font.pixelSize: 12
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            lineHeight: 1.3
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#1a1a1a" }

                            // ── Scrobble timing reference ─────────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "SCROBBLE TIMING"
                                    color: "#555555"
                                    font.pixelSize: 10
                                    font.letterSpacing: 1.5
                                    font.bold: true
                                }

                                Repeater {
                                    model: [
                                        { label: "Now Playing", detail: "Sent immediately when a song starts." },
                                        { label: "Scrobble",    detail: "Submitted after 50% of the track or 4 minutes, whichever is sooner." },
                                        { label: "Skip",        detail: "If you skip after 30 s and past the threshold, the play still counts." },
                                        { label: "Offline",     detail: "Plays are queued on disk and submitted the next time a session is available." }
                                    ]
                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Text {
                                            text: modelData.label
                                            color: "#aaaaaa"
                                            font.pixelSize: 12
                                            font.bold: true
                                            Layout.minimumWidth: 90
                                        }

                                        Text {
                                            text: modelData.detail
                                            color: "#666666"
                                            font.pixelSize: 12
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            lineHeight: 1.3
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#1a1a1a" }

                            // ── Action button ─────────────────────────────────────────────
                            RowLayout {
                                spacing: 12

                                Rectangle {
                                    id: scrobbleAuthBtn
                                    property bool hovered: false
                                    opacity: root.scrobbleAuthPending ? 0.45 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    width: scrobbleAuthBtnText.implicitWidth + 28
                                    height: 36
                                    radius: 6
                                    color: backend.scrobblingAuthenticated
                                        ? (hovered ? "#e06060" : "#cc4444")
                                        : (hovered ? "#f0f0f0" : "white")
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        id: scrobbleAuthBtnText
                                        anchors.centerIn: parent
                                        text: backend.scrobblingAuthenticated ? "Disconnect" : "Connect to Last.fm"
                                        color: backend.scrobblingAuthenticated ? "white" : "#111111"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    HoverHandler { onHoveredChanged: scrobbleAuthBtn.hovered = hovered }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !root.scrobbleAuthPending
                                        cursorShape: root.scrobbleAuthPending ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (backend.scrobblingAuthenticated) {
                                                backend.scrobblerLogout()
                                            } else {
                                                root.scrobbleAuthPending = true
                                                backend.scrobblerAuthenticate()
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.scrobbleAuthPending
                                    text: "Browser opened — sign in to Last.fm…"
                                    color: "#666666"
                                    font.pixelSize: 12
                                }
                            }

                            Item { height: 40 }
                        }
                    }
                }
            }
        }
    }
}