pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  id: root

  // off by default, like wshowkeys (toggled via SHIFT+k in apps submap)
  property bool enabled: false
  property bool opened: false
  property string current: ""
  property var history: []
  property int repeatCount: 1
  property string notice: ""
  property bool noticeOpen: false
  property int maxHistory: 4
  property int timeout: 1000
  property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/modules/showkeys/showkeys.py"

  function toggle() {
    if (enabled) { disable(); setNotice("Disabled") }
    else { enable(); setNotice("Enabled") }
  }
  function enable() { enabled = true }
  function setNotice(text) {
    notice = text
    noticeOpen = true
    noticeTimer.restart()
  }
  function disable() {
    enabled = false
    opened = false
    current = ""
    history = []
    repeatCount = 1
  }
  function push(combo) {
    const t = String(combo || "").trim()
    if (t.length === 0) return
    // a real keypress immediately replaces any Enabled/Disabled notice
    noticeTimer.stop()
    noticeOpen = false
    notice = ""
    let h = history.slice()
    if (h.length > 0 && current === t) {
      // same combo pressed again — bump the ×n badge instead of duplicating
      repeatCount += 1
      h[h.length - 1] = { label: t, count: repeatCount }
    } else {
      repeatCount = 1
      h.push({ label: t, count: 1 })
      while (h.length > maxHistory) h.shift()
    }
    history = h
    current = t
    opened = true
    hideTimer.restart()
  }
  function clear() {
    current = ""
    history = []
    repeatCount = 1
    opened = false
  }

  Process {
    id: keyProc
    running: root.enabled
    command: ["python3", root.scriptPath]
    stdout: SplitParser {
      onRead: data => {
        const line = String(data || "").trim()
        if (line.length > 0) root.push(line)
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("showkeys:", String(data || "").trim())
    }
    onExited: (exitCode, exitStatus) => {
      if (root.enabled) console.warn("showkeys: daemon exited code=" + exitCode + " (in input group? check `groups | grep input`)")
    }
  }

  Timer {
    id: hideTimer
    interval: root.timeout
    onTriggered: root.opened = false
  }

  Timer {
    id: noticeTimer
    interval: 750
    onTriggered: { root.noticeOpen = false; root.notice = "" }
  }

  IpcHandler {
    target: "showkeys"
    function toggle(): string { root.toggle(); return root.enabled ? "enabled" : "disabled" }
    function enable(): string { root.enable(); root.setNotice("Enabled"); return "enabled" }
    function disable(): string { root.disable(); root.setNotice("Disabled"); return "disabled" }
    function push(combo: string): string { root.enable(); root.push(combo); return "ok" }
    function hide(): string { root.opened = false; return "ok" }
    function clear(): string { root.clear(); return "ok" }
    function state(): string { return (root.enabled ? "enabled" : "disabled") + " " + (root.opened ? "open" : "closed") }
    function ping(): string { return "ok" }
  }

  // Lazy like the other modules: no windows exist until showkeys is
  // enabled, so quickshell startup stays fast. Gated on `enabled` (not
  // `opened`) so repeated keystrokes don't pay window-creation cost.
  // `noticeOpen` is included so the Enabled/Disabled flash can show even
  // while the daemon itself is off.
  LazyLoader {
    active: root.enabled || root.noticeOpen

    Variants {
      model: Quickshell.screens
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: (root.opened && root.history.length > 0) || root.noticeOpen
        color: "transparent"
        WlrLayershell.namespace: "quickshell-showkeys"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region {}

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 48
          radius: Theme.radiusLg
          color: Qt.alpha(Theme.bg, 0.667)
          border.color: Qt.alpha(Theme.border, 0.75)
          border.width: 1
          width: Math.max(140, (root.noticeOpen ? noticeRow.implicitWidth : row.implicitWidth) + 40)
          height: 64
          opacity: (root.opened || root.noticeOpen) ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

          Row {
            id: row
            visible: !root.noticeOpen
            anchors.centerIn: parent
            spacing: 10

            Repeater {
              model: root.history
              Row {
                required property var modelData
                required property int index
                property bool isLast: index === root.history.length - 1
                spacing: 4
                Text {
                  text: modelData.label
                  color: isLast ? Theme.fg : Qt.alpha(Theme.fg, 0.55)
                  font.family: Theme.monoFont
                  font.pixelSize: 22
                  font.bold: isLast
                }
                Text {
                  visible: modelData.count > 1
                  text: "×" + modelData.count
                  color: Theme.accent
                  font.family: Theme.monoFont
                  font.pixelSize: 18
                  font.bold: true
                  anchors.baseline: parent.children[0].baseline
                }
                Text {
                  visible: !isLast
                  text: "▸"
                  color: Qt.alpha(Theme.fg, 0.35)
                  font.family: Theme.monoFont
                  font.pixelSize: 18
                }
              }
            }
          }

          Row {
            id: noticeRow
            visible: root.noticeOpen
            anchors.centerIn: parent
            spacing: 10
            Text {
              text: "󰌌"
              color: Theme.accent
              font.family: Theme.nerdFont
              font.pixelSize: 24
            }
            Text {
              text: root.notice
              color: Theme.fg
              font.family: Theme.monoFont
              font.pixelSize: 20
              font.bold: true
            }
          }
        }
      }
    }
  }
}
