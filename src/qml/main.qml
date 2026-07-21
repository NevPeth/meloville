import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: appWindow
    visible: true
    width: 900
    height: 600
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
    // Main page component (placeholder for when music is loaded)
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

                                Layout.preferredWidth: playlistButtonSize
                                Layout.preferredHeight: playlistButtonSize
                                Layout.maximumWidth: playlistButtonSize
                                Layout.maximumHeight: playlistButtonSize
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

                                background: Item {}

                                icon.source: "qrc:/icons/libraryIcon.svg"
                                icon.width: playlistButtonSize
                                icon.height: playlistButtonSize

                                contentItem: Image {
                                    source: btnLibrary.icon.source
                                    width: playlistButtonSize
                                    height: playlistButtonSize
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Button {
                                id: btnSkip

                                Layout.preferredWidth: playlistButtonSize
                                Layout.preferredHeight: playlistButtonSize
                                Layout.maximumWidth: playlistButtonSize
                                Layout.maximumHeight: playlistButtonSize
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

                                background: Item {}

                                icon.width: playlistButtonSize
                                icon.height: playlistButtonSize

                                contentItem: Image {
                                    source: "image://svgicons/skip"
                                    width: playlistButtonSize
                                    height: playlistButtonSize
                                    fillMode: Image.PreserveAspectFit
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