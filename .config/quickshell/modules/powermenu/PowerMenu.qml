pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  id: pmRoot
  property bool visible: false

  function toggle() { visible = !visible }
  function open() { visible = true }
  function close() { visible = false }

  // ── Selection ──────────────────────────────────────────────────────
  property int selectedIndex: 0
  property int columns: 3
  property bool _blockHover: false
  function _markKeyboard() { _blockHover = true }

  function activate(idx) {
    if (idx < 0 || idx >= actions.length) return
    const a = actions[idx]
    Quickshell.execDetached(a.cmd)
    close()
  }

  readonly property var actions: [
    { label: "Lock",      icon: "", hint: "K", key: Qt.Key_K, cmd: ["loginctl", "lock-session"] },
    { label: "Suspend",   icon: "󰒲", hint: "U", key: Qt.Key_U, cmd: ["systemctl", "suspend"] },
    { label: "Logout",    icon: "󰍃", hint: "L", key: Qt.Key_L, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
    { label: "Hibernate", icon: "󰤄", hint: "H", key: Qt.Key_H, cmd: ["systemctl", "hibernate"] },
    { label: "Reboot",    icon: "", hint: "R", key: Qt.Key_R, cmd: ["systemctl", "reboot"] },
    { label: "Shutdown",  icon: "", hint: "S", key: Qt.Key_S, cmd: ["systemctl", "poweroff"] }
  ]

  function move(dir) {
    _markKeyboard()
    const n = actions.length
    let ni = selectedIndex + dir
    if (ni < 0) ni = n - 1
    if (ni >= n) ni = 0
    selectedIndex = ni
  }
  function moveHorizontal(dir) { _markKeyboard(); move(dir) } // wrapping for Tab
  function moveHorizontalNoWrap(dir) {
    _markKeyboard()
    const n = actions.length; if (n === 0) return
    const cols = columns; const row = Math.floor(selectedIndex / cols)
    const col = selectedIndex % cols
    const rowStart = row * cols; const rowEnd = Math.min(rowStart + cols, n) - 1
    let nc = col + dir; if (nc < 0 || rowStart + nc > rowEnd) return
    selectedIndex = rowStart + nc
  }
  function moveVerticalNoWrap(dir) {
    _markKeyboard()
    const n = actions.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols
    const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    let nr = row + dir; if (nr < 0 || nr >= rows) return
    let ni = nr * cols + col; if (ni >= n) return
    selectedIndex = ni
  }
  function goHome() { _markKeyboard(); if (actions.length > 0) selectedIndex = 0 }
  function goEnd() { _markKeyboard(); const n = actions.length; if (n > 0) selectedIndex = n - 1 }
  function pageMove(dir) {
    _markKeyboard()
    const n = actions.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols
    const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    const pageRows = 2
    let nr = row + dir * pageRows; if (nr < 0) nr = 0; if (nr >= rows) nr = rows - 1
    let ni = nr * cols + col
    if (ni >= n) { for (let r = rows - 1; r >= 0; r--) { const cand = r * cols + col; if (cand < n) { ni = cand; break } } if (ni >= n) ni = n - 1 }
    selectedIndex = ni
  }

  onVisibleChanged: { if (visible) { selectedIndex = 0; _blockHover = true } }

  // ── Windows ────────────────────────────────────────────────────────
  LazyLoader {
    active: pmRoot.visible

    Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: pmRoot.visible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors { top: true; bottom: true; left: true; right: true }

      MouseArea { anchors.fill: parent; onClicked: pmRoot.close() }
      Rectangle { anchors.fill: parent; color: Theme.dim }

// ── Centered container ──────────────────────────────────────
        Rectangle {
          id: box
          width: 640
          height: 360
          anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bg
        LayoutMirroring.enabled: false
        border.color: Theme.border
        border.width: 1
        focus: true

        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: { if (pmRoot._blockHover) { pmRoot._blockHover = false } }
                onClicked: {} }

        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) { pmRoot.close(); event.accepted = true; return }
          if (event.key === Qt.Key_Backtab) { pmRoot.moveHorizontal(-1); event.accepted = true; return }
          if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ShiftModifier) pmRoot.moveHorizontal(-1)
            else pmRoot.moveHorizontal(1)
            event.accepted = true; return
          }
          if (event.key === Qt.Key_Left) { pmRoot.moveHorizontalNoWrap(-1); event.accepted = true; return }
          if (event.key === Qt.Key_Right) { pmRoot.moveHorizontalNoWrap(1); event.accepted = true; return }
          if (event.key === Qt.Key_Up) { pmRoot.moveVerticalNoWrap(-1); event.accepted = true; return }
          if (event.key === Qt.Key_Down) { pmRoot.moveVerticalNoWrap(1); event.accepted = true; return }
          if (event.key === Qt.Key_Home) { pmRoot.goHome(); event.accepted = true; return }
          if (event.key === Qt.Key_End) { pmRoot.goEnd(); event.accepted = true; return }
          if (event.key === Qt.Key_PageUp) { pmRoot.pageMove(-1); event.accepted = true; return }
          if (event.key === Qt.Key_PageDown) { pmRoot.pageMove(1); event.accepted = true; return }
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { pmRoot.activate(pmRoot.selectedIndex); event.accepted = true; return }
          for (let i = 0; i < pmRoot.actions.length; i++) {
            if (event.key === pmRoot.actions[i].key) { pmRoot.activate(i); event.accepted = true; return }
          }
          if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
            const idx = event.key - Qt.Key_1
            pmRoot.activate(idx); event.accepted = true
          }
        }

        Component.onCompleted: if (pmRoot.visible) forceActiveFocus()
        Connections {
          target: pmRoot
          function onVisibleChanged() { if (pmRoot.visible) box.forceActiveFocus() }
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 18
          spacing: 16

          // ── Header ─────────────────────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
              width: 32; height: 32
              radius: 8
              color: Theme.surface
              border.color: Theme.border
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: ""
                color: Theme.fg
                font.family: Theme.nerdFont
                font.pixelSize: 14
              }
            }

            ColumnLayout {
              spacing: 2
              Text {
                text: "Power Menu"
                color: Theme.fg
                font.family: Theme.monoFont
                font.pixelSize: 14
                font.bold: true
              }
              Text {
                text: "Select an action"
                color: Theme.fg
                opacity: 0.55
                font.family: Theme.monoFont
                font.pixelSize: 11
              }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: 28; height: 28
              radius: 14
              color: Theme.surface
              border.color: Theme.border
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: ""
                color: Theme.fg
                opacity: 0.55
                font.family: Theme.nerdFont
                font.pixelSize: 11
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: pmRoot.close()
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
            opacity: 0.6
          }

          // ── Grid - 3x2, fills remaining height ─────────────────────
          GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
              model: pmRoot.actions

              Rectangle {
                id: btn
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLg
                color: pmRoot.selectedIndex === index ? Theme.surfaceHover : Theme.surface
                border.color: pmRoot.selectedIndex === index ? Theme.fg : Theme.border
                border.width: pmRoot.selectedIndex === index ? 1.4 : 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
                scale: pmRoot.selectedIndex === index ? 1.02 : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                // subtle selected glow - uses fg, not green/blue accent
                Rectangle {
                  anchors.fill: parent
                  radius: parent.radius
                  color: "transparent"
                  border.color: Theme.fg
                  border.width: pmRoot.selectedIndex === btn.index ? 1 : 0
                  opacity: 0.10
                  visible: pmRoot.selectedIndex === btn.index
                }

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 10

                  Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 56; height: 56
                    radius: 16
                    color: pmRoot.selectedIndex === btn.index ? Qt.alpha(Theme.fg, 0.08) : Theme.bg
                    border.color: pmRoot.selectedIndex === btn.index ? Qt.alpha(Theme.fg, 0.33) : Theme.border
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: btn.modelData.icon
                      color: Theme.fg
                      font.family: Theme.nerdFont
                      font.pixelSize: 26
                    }
                  }

                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: btn.modelData.label
                    color: Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    font.bold: pmRoot.selectedIndex === btn.index
                  }
                }

                // ── Hint badge at top-right (not overlapping label) ───────
                Rectangle {
                  width: 22; height: 18
                  radius: 4
                  color: pmRoot.selectedIndex === btn.index ? Theme.fg : Theme.surfaceHover
                  border.color: pmRoot.selectedIndex === btn.index ? Theme.fg : Theme.border
                  border.width: 1
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.topMargin: 8
                  anchors.rightMargin: 8
                  Text {
                    anchors.centerIn: parent
                    text: btn.modelData.hint
                    color: pmRoot.selectedIndex === btn.index ? Theme.bg : Theme.fg
                    opacity: pmRoot.selectedIndex === btn.index ? 1 : 0.6
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    font.bold: true
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { if (pmRoot.selectedIndex === btn.index) pmRoot.activate(btn.index); else pmRoot.selectedIndex = btn.index }
                }
              }
            }
          }
        }
      }
    }
  }

  // ── IPC ────────────────────────────────────────────────────────────
  }

  IpcHandler {
    target: "powermenu"
    function toggle() { pmRoot.toggle() }
    function open() { pmRoot.open() }
    function close() { pmRoot.close() }
  }

  GlobalShortcut {
    name: "powermenuToggle"
    description: "Toggle power menu"
    onPressed: pmRoot.toggle()
  }
}
