pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Widgets

import "../common"

Scope {
    id: root
    property bool failed: false
    property string errorString: ""
    property string instanceId: String(Quickshell.processId)

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
            root.failed = false
            root.errorString = ""
            root.instanceId = String(Quickshell.processId)
            popupLoader.loading = true
        }
        function onReloadFailed(error: string) {
            Quickshell.inhibitReloadPopup()
            // reset loader so fade restarts correctly
            popupLoader.active = false
            root.failed = true
            root.errorString = error
            root.instanceId = String(Quickshell.processId)
            popupLoader.loading = true
        }
    }

    LazyLoader {
        id: popupLoader

        PanelWindow {
            id: popup
            // ── Position: right side with comfortable margins ──────────
            anchors { right: true; top: true }
            margins { right: 16; top: Config.barHeight + 12 }

            implicitWidth: wrapper.implicitWidth
            implicitHeight: wrapper.implicitHeight

            color: "transparent"

            focusable: failText.focus

            // ── Fade animation – preserved from original ───────────────
            SequentialAnimation on contentItem.opacity {
                id: fadeOutAnim
                NumberAnimation {
                    from: 0.0001; to: 1
                    duration: 250
                    easing.type: Easing.OutQuad
                }
                PauseAnimation { duration: root.failed ? 2000 : 500 }
                NumberAnimation {
                    to: 0
                    duration: root.failed ? 3000 : 800
                    easing.type: Easing.InQuad
                }
            }

            Behavior on contentItem.opacity {
                enabled: !fadeOutAnim.running
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutQuad
                }
            }

            contentItem.onOpacityChanged: {
                if (contentItem.opacity === 0) popupLoader.active = false
            }

            component PopupText: Text {
                color: Theme.fg
            }

            component TopButton: WrapperMouseArea {
                id: buttonMouse
                required property string icon
                required property string fallbackText
                property bool red: false

                hoverEnabled: true

                WrapperRectangle {
                    radius: 5

                    color: {
                        if (buttonMouse.red) {
                            const baseColor = Theme.urgent
                            if (buttonMouse.pressed) return Qt.tint(Theme.surface, Qt.alpha(baseColor, 0.8))
                            if (buttonMouse.containsMouse) return baseColor
                        } else {
                            if (buttonMouse.pressed) return Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.3))
                            if (buttonMouse.containsMouse) return Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.5))
                        }
                        return Theme.surface
                    }

                    border.color: {
                        if (buttonMouse.red) {
                            const baseColor = Theme.urgent
                            if (buttonMouse.pressed) return Qt.tint(Theme.border, Qt.alpha(baseColor, 0.8))
                            if (buttonMouse.containsMouse) return baseColor
                        } else {
                            if (buttonMouse.pressed) return Qt.tint(Theme.border, Qt.alpha(Theme.accent, 0.7))
                            if (buttonMouse.containsMouse) return Theme.accent
                        }
                        return Theme.border
                    }

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    IconImage {
                        id: image
                        source: Quickshell.iconPath(buttonMouse.icon, true)
                        implicitSize: 22
                        visible: source != ""
                    }

                    Text {
                        id: fallback
                        text: buttonMouse.fallbackText
                        color: buttonMouse.red ? "white" : Theme.fg
                    }

                    child: image.visible ? image : fallback
                }
            }

            // ── Copy feedback state ──────────────────────────────────
            property bool copyFeedback: false
            property bool logFeedback: false
            Timer { id: copyReset; interval: 1500; onTriggered: popup.copyFeedback = false }
            Timer { id: logReset; interval: 1500; onTriggered: popup.logFeedback = false }

            WrapperRectangle {
                id: wrapper
                anchors.fill: parent
                color: Theme.bg
                border.color: root.failed ? Theme.urgent : Theme.accent
                border.width: 1

                radius: Theme.radiusMd
                margin: 10

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered && fadeOutAnim.running) {
                            fadeOutAnim.stop()
                            popup.contentItem.opacity = 1
                        }
                    }
                }

                ColumnLayout {
                    RowLayout {
                        PopupText {
                            font.pixelSize: 20
                            fontSizeMode: Text.VerticalFit
                            text: `Quickshell: ${root.failed ? "Config reload failed" : "Config reloaded"}`
                        }

                        Item { Layout.fillWidth: true }

                        // Copy button (only when failed)
                        TopButton {
                            visible: root.failed
                            icon: "edit-copy"
                            fallbackText: "Copy"
                            onClicked: {
                                Quickshell.clipboardText = root.errorString
                                popup.copyFeedback = true
                                copyReset.restart()
                            }
                        }

                        // Close button
                        TopButton {
                            icon: "window-close"
                            fallbackText: "Close"
                            red: true
                            onClicked: {
                                fadeOutAnim.stop()
                                popup.contentItem.opacity = 0
                            }
                        }
                    }

                    // Copy feedback tooltip (replaces internal Tooltip)
                    Rectangle {
                        visible: popup.copyFeedback
                        Layout.fillWidth: true
                        implicitHeight: copyFeedbackText.implicitHeight + 8
                        radius: Theme.radiusSm
                        color: Theme.surfaceHover
                        border.color: Theme.border
                        border.width: 1
                        Text {
                            id: copyFeedbackText
                            anchors.centerIn: parent
                            text: "Copied to clipboard"
                            color: Theme.fg
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                        }
                    }

                    WrapperRectangle {
                        visible: root.failed
                        color: Theme.surface
                        margin: 10
                        radius: Theme.radiusSm

                        TextEdit {
                            id: failText
                            text: root.errorString
                            color: Theme.fg
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.bg
                            readOnly: true
                            font.family: "monospace"
                            wrapMode: TextEdit.Wrap
                        }
                    }

                    RowLayout {
                        PopupText { text: "Run" }

                        WrapperMouseArea {
                            id: logButton
                            Layout.topMargin: -logWrapper.margin
                            Layout.bottomMargin: -logWrapper.margin
                            hoverEnabled: true
                            onClicked: {
                                Quickshell.clipboardText = logText.text
                                popup.logFeedback = true
                                logReset.restart()
                            }

                            WrapperRectangle {
                                id: logWrapper
                                margin: 2
                                radius: 5

                                color: {
                                    if (logButton.pressed) return Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.1))
                                    if (logButton.containsMouse) return Qt.tint(Theme.surface, Qt.alpha(Theme.accent, 0.2))
                                    return Theme.surface
                                }

                                border.color: {
                                    if (logButton.pressed) return Qt.tint(Theme.border, Qt.alpha(Theme.accent, 0.3))
                                    if (logButton.containsMouse) return Qt.tint(Theme.border, Qt.alpha(Theme.accent, 0.5))
                                    return Theme.border
                                }

                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                RowLayout {
                                    PopupText {
                                        id: logText
                                        text: `qs log -i ${root.instanceId}`
                                    }
                                    IconImage {
                                        Layout.fillHeight: true
                                        implicitWidth: height
                                        source: Quickshell.iconPath("edit-copy", true)
                                        visible: source != ""
                                    }
                                }
                            }
                        }

                        PopupText { text: "to view the log." }
                    }

                    // Log copy feedback
                    Rectangle {
                        visible: popup.logFeedback
                        Layout.fillWidth: true
                        implicitHeight: logFeedbackText.implicitHeight + 8
                        radius: Theme.radiusSm
                        color: Theme.surfaceHover
                        border.color: Theme.border
                        border.width: 1
                        Text {
                            id: logFeedbackText
                            anchors.centerIn: parent
                            text: "Copied to clipboard"
                            color: Theme.fg
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
