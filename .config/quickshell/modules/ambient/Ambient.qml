pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtMultimedia

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  id: root

  // ── State ──────────────────────────────────────────────────────────
  property bool enabled: false
  property string filePath: ""
  property real volume: 0.75
  property bool otherPlaying: false
  property string lastError: ""
  property bool pathOk: true

  // ── UI ─────────────────────────────────────────────────────────────
  property bool visible: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true }
  function close() { visible = false }

  readonly property string status: {
    if (!enabled) return "off"
    if (filePath === "") return "no file"
    if (otherPlaying) return "paused"
    return "playing"
  }

  // True only when audio is actually needed. Used to gate expensive work
  // (MediaPlayer/AudioOutput creation, playerctl polling) so quickshell
  // doesn't pay the cost at startup when ambient is disabled.
  readonly property bool _audioActive: enabled && filePath !== ""

  // ── Paste from clipboard ───────────────────────────────────────────
  function _paste() {
    pasteProc.running = true
  }
  Process {
    id: pasteProc
    command: ["sh", "-c", "wl-paste 2>/dev/null | head -c 2048"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: {
      const p = String(text || "").trim()
      if (p) root._setFile(p)
    }}
  }

  // ── Persistence ────────────────────────────────────────────────────
  readonly property string _configPath: Quickshell.env("HOME") + "/.config/quickshell/ambient.json"

  function _save() {
    const payload = JSON.stringify({
      enabled: enabled,
      filePath: filePath,
      volume: volume
    })
    Quickshell.execDetached(["sh", "-c", "cat > ~/.config/quickshell/ambient.json <<'EOF'\n" + payload + "\nEOF\n"])
  }

  function _load() {
    loadProc.running = true
  }

  function _setFile(p) {
    if (p === filePath) return
    lastError = ""
    filePath = p // onFilePathChanged handles stopping playback, setting the
                 // source, re-checking the path and re-applying playback
    _save()
  }

  function _setVolume(v) {
    volume = Math.max(0, Math.min(1, v))
    _save()
  }

  function _normalize(p) {
    if (!p) return ""
    let s = p
    if (s.startsWith("~/")) s = Quickshell.env("HOME") + s.substring(1)
    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(s)) return s // already a URL (file://, http://, ...)
    // Percent-encode each path segment (handles spaces, Arabic/unicode, etc.)
    // while keeping the "/" separators intact, so QUrl/MediaPlayer resolve
    // it correctly instead of choking on raw special characters.
    const encoded = s.split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded
  }

  // ── Playback control ───────────────────────────────────────────────
  // Access the lazy MediaPlayer via audioLoader.item (the LazyLoader's
  // loaded child). The id `player` is local to the LazyLoader's sub-
  // component and not visible to the outer Scope under pragma
  // ComponentBehavior: Bound.
  function _player() { return audioLoader.item }
  function _applyPlayback() {
    const p = _player()
    if (!p) return
    if (enabled && filePath !== "" && !otherPlaying) {
      if (p.playbackState !== MediaPlayer.PlayingState) {
        p.play()
      }
    } else {
      if (p.playbackState === MediaPlayer.PlayingState) {
        p.pause()
      }
    }
  }

  onEnabledChanged: { _save(); _applyPlayback(); if (root.visible || enabled) _startPolling(); else _stopPolling() }
  onOtherPlayingChanged: _applyPlayback()

  // ── Audio engine ───────────────────────────────────────────────────
  // Lazy-instantiated: QtMultimedia's MediaPlayer/AudioOutput are expensive
  // to create and aren't needed when ambient is disabled / has no file.
  // Mirrors the "open-on-demand" pattern used by MpvHistory/BraveHistory.
  LazyLoader {
    id: audioLoader
    active: root._audioActive

    // When the loader activates (e.g. on first launch with enabled=true),
    // its child is created fresh and has no source — kick off playback so
    // the saved audio actually starts playing.
    onActiveChanged: if (active) root._startPlayback()

    MediaPlayer {
      id: player
      loops: -1
      audioOutput: AudioOutput {
        id: audioOut
        volume: root.volume
      }
      onMediaStatusChanged: {
        if (!root.pathOk) return
        root.lastError = (mediaStatus === MediaPlayer.InvalidMedia) ? "Invalid media" : ""
      }
    }
  }

  function _startPlayback() {
    const p = _player()
    if (!p) return
    if (filePath === "") return
    p.source = _normalize(filePath)
    statCheckTimer.restart()
    if (enabled && !otherPlaying) p.play()
  }

  onFilePathChanged: {
    statCheckTimer.restart()
    const p = _player()
    if (!p) return
    if (p.playbackState === MediaPlayer.PlayingState) p.stop()
    p.source = _normalize(filePath)
    _applyPlayback()
  }

  Timer {
    id: statCheckTimer
    interval: 150
    repeat: false
    onTriggered: root._runStat(root.filePath)
  }
  Process {
    id: statProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: {
      const r = String(text || "").trim()
      if (r === "EMPTY") {
        root.pathOk = true
        if (root.lastError === "File not found or unreadable") root.lastError = ""
        return
      }
      root.pathOk = (r === "OK")
      if (r === "BAD") {
        root.lastError = "File not found or unreadable"
      } else if (root.lastError === "File not found or unreadable") {
        root.lastError = ""
      }
    }}
  }
  function _runStat(p) {
    if (!p) {
      statProc.command = ["python3", "-c", "print('EMPTY')"]
      statProc.running = true
      return
    }
    // Pass the path as a genuine argv element (no shell, no base64, no
    // string-building/quoting at all - Quickshell's Process.command execs
    // argv directly). Python receives it via sys.argv, already correctly
    // decoded from the OS's raw bytes, so spaces, Arabic/unicode, quotes,
    // etc. all just work, regardless of what's in the path.
    statProc.command = ["python3", "-c",
      "import os,sys\np=sys.argv[1]\nprint('OK' if (p and os.path.isfile(p) and os.access(p, os.R_OK)) else 'BAD')",
      p]
    statProc.running = true
  }

  // ── External player polling (playerctl) ────────────────────────────
  // Only poll while the panel is open or audio is actively playing. The
  // initial playerctl spawn at startup was the main ambient-related
  // contributor to slow quickshell boot.
  Timer {
    id: pollTimer
    interval: 500
    repeat: true
    running: false
    triggeredOnStart: false
    onTriggered: pollProc.running = true
  }

  // Start/stop polling on demand.
  function _startPolling() { if (!pollTimer.running) pollTimer.start() }
  function _stopPolling() { if (pollTimer.running) pollTimer.stop() }

  onVisibleChanged: { if (visible) _startPolling(); else if (!enabled) _stopPolling() }

  Process {
    id: pollProc
    command: ["sh", "-c", "timeout 1 players=$(playerctl -l 2>/dev/null); if [ -z \"$players\" ]; then echo IDLE; else for p in $players; do s=$(timeout 1 playerctl -s -p \"$p\" status 2>/dev/null); if [ \"$s\" = \"Playing\" ]; then echo BUSY; exit 0; fi; done; echo IDLE; fi"]
    stdout: SplitParser {
      onRead: data => {
        const v = String(data).trim()
        if (v === "BUSY") {
          if (!root.otherPlaying) root.otherPlaying = true
        } else if (v === "IDLE") {
          if (root.otherPlaying) root.otherPlaying = false
        }
      }
    }
  }

  // ── Config load / save ─────────────────────────────────────────────
  Process {
    id: loadProc
    command: ["python3", "-c", "import json,os,sys\np=os.path.expanduser('~/.config/quickshell/ambient.json')\ntry:\n    d=json.load(open(p))\n    print(json.dumps(d))\nexcept Exception:\n    print('{}')\n"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: {
      try {
        const d = JSON.parse(String(text || "{}"))
        if (typeof d.enabled === "boolean") root.enabled = d.enabled
        if (typeof d.filePath === "string") root.filePath = d.filePath
        if (typeof d.volume === "number") root.volume = Math.max(0, Math.min(1, d.volume))
        // Setting filePath (when it actually changes) already triggers
        // onFilePathChanged, which sets player.source, restarts the stat
        // check timer and re-applies playback - no need to duplicate that
        // here. Duplicating it caused two concurrent stat checks to race
        // against each other.
      } catch (e) {
        // ignore
      }
    }}
  }

  // ── File browse helper ─────────────────────────────────────────────
  Component.onCompleted: _load()

  // ── Popup UI ───────────────────────────────────────────────────────
  LazyLoader {
    active: root.visible

    Variants {
      model: Quickshell.screens
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: root.visible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-ambient"
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: root.close() }
        Rectangle { anchors.fill: parent; color: Theme.dim }

        Rectangle {
          id: container
          width: 400
          height: 300
          anchors.centerIn: parent
          radius: Theme.radiusLg
          color: Theme.bg
          border.color: Theme.border
          border.width: 1
          clip: true
          focus: true
          LayoutMirroring.enabled: false

          Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.close(); event.accepted = true }
            else if (event.key === Qt.Key_Space) { root.enabled = !root.enabled; event.accepted = true }
            else if (event.key === Qt.Key_Left) { root._setVolume(root.volume - 0.05); event.accepted = true }
            else if (event.key === Qt.Key_Right) { root._setVolume(root.volume + 0.05); event.accepted = true }
            else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { root._paste(); event.accepted = true }
          }
          Component.onCompleted: forceActiveFocus()
          Connections { target: root; function onVisibleChanged() { if (root.visible) container.forceActiveFocus() } }

          // Swallows clicks inside the dialog so they don't fall through to
          // the full-screen MouseArea behind it (which closes the popup).
          MouseArea { anchors.fill: parent }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Header ───────────────────────────────────────────────
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              Rectangle { width: 32; height: 32; radius: 8; color: Theme.surface; border.color: Theme.border; border.width: 1
                Text { anchors.centerIn: parent; text: "󰝚"; color: Theme.accent; font.family: Theme.nerdFont; font.pixelSize: 14 }
              }
              ColumnLayout { spacing: 2
                Text { text: "Ambient Audio"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 14; font.bold: true }
                Text {
                  text: "Status: " + root.status + (!root.pathOk && root.filePath !== "" ? " (broken)" : "")
                  color: !root.pathOk && root.filePath !== "" ? Theme.urgent : (root.status === "playing" ? Theme.accent : (root.status === "paused" ? Theme.urgent : Theme.fg))
                  opacity: 0.7
                  font.family: Theme.monoFont
                  font.pixelSize: 11
                }
              }
              Item { Layout.fillWidth: true }
              Rectangle { width: 28; height: 28; radius: 14; color: Theme.surface; border.color: Theme.border; border.width: 1
                Text { anchors.centerIn: parent; text: "󰅖"; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
              }
            }

            // ── Enable row ──────────────────────────────────────────
            Rectangle {
              Layout.fillWidth: true
              height: 44
              radius: Theme.radiusMd
              color: Theme.surface
              border.color: Theme.border
              border.width: 1
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 10
                Text { text: "Enable"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 12; font.bold: true; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.fillWidth: true }
                Rectangle {
                  width: 44; height: 24; radius: 12
                  color: root.enabled ? Theme.accent : Qt.alpha(Theme.fg, 0.15)
                  border.color: root.enabled ? Theme.accent : Theme.border
                  border.width: 1
                  Rectangle {
                    width: 18; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.enabled ? parent.width - width - 3 : 3
                    color: root.enabled ? Theme.bg : Theme.fg
                    Behavior on x { NumberAnimation { duration: 120 } }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.enabled = !root.enabled }
                }
              }
            }

            // ── File path row ───────────────────────────────────────
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 6
              Text { text: "Audio file"; color: Theme.fg; opacity: 0.7; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                  Layout.fillWidth: true
                  height: 40
                  radius: Theme.radiusMd
                  color: Theme.surface
                  border.color: !root.pathOk ? Theme.urgent : (pathField.activeFocus ? Qt.alpha(Theme.fg, 0.4) : Theme.border)
                  border.width: 1
                  clip: true // keep long paths (e.g. long unicode filenames) from
                             // rendering past the rounded box edges
                  TextInput {
                    id: pathField
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    text: root.filePath
                    activeFocusOnTab: false
                    onTextChanged: {
                      if (text !== root.filePath) root._setFile(text)
                    }
                    Keys.onPressed: event => {
                      if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
                      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.close(); event.accepted = true }
                    }
                  }
                  Text {
                    visible: pathField.text === ""
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "/path/to/audio.mp3"
                    color: Theme.fg
                    opacity: 0.4
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                  }
                }
              }
              Text {
                visible: root.lastError !== ""
                text: root.lastError
                color: Theme.urgent
                font.family: Theme.monoFont
                font.pixelSize: 10
              }
            }

            // ── Volume row ──────────────────────────────────────────
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 6
              RowLayout {
                Layout.fillWidth: true
                Text { text: "Volume"; color: Theme.fg; opacity: 0.7; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(root.volume * 100) + "%"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 11 }
              }
              Rectangle {
                id: volSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                radius: 4
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                property real trackWidth: width
                readonly property real _pct: root.volume
                Rectangle {
                  height: parent.height
                  width: Math.max(2, parent.width * parent._pct)
                  radius: 3
                  color: Theme.accent
                }
                Rectangle {
                  x: Math.max(0, Math.min(parent.width - 8, parent.width * parent._pct - 8))
                  y: 1
                  width: 16
                  height: parent.height - 2
                  radius: 4
                  color: Theme.fg
                  opacity: 0.9
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onPressed: mouse => root._setVolume(mouse.x / width)
                  onPositionChanged: mouse => {
                    if (pressed) root._setVolume(Math.max(0, Math.min(1, mouse.x / width)))
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }

            // ── Footer hint ─────────────────────────────────────────
            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: 10
              Text { text: "Space Toggle"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
              Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 10; color: Theme.border; opacity: 0.6 }
              Text { text: "←/→ Vol"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
              Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 10; color: Theme.border; opacity: 0.6 }
              Text { text: "Ctrl+V Paste"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
              Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 10; color: Theme.border; opacity: 0.6 }
              Text { text: "↵ Apply"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
              Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 10; color: Theme.border; opacity: 0.6 }
              Text { text: "Esc Close"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
            }
          }
        }
      }
    }
  }

  // ── IPC & Global shortcut ──────────────────────────────────────────
  IpcHandler {
    target: "ambient"
    function toggle() { root.toggle(); return root.visible ? "open" : "closed" }
    function open() { root.open(); return "ok" }
    function close() { root.close(); return "ok" }
    function enable() { root.enabled = true; return "ok" }
    function disable() { root.enabled = false; return "ok" }
    function status() { return root.status + " file=" + root.filePath + " vol=" + root.volume.toFixed(2) }
    function setFile(p: string) { root._setFile(p); return "ok" }
    function setVolume(v: double) { root._setVolume(v); return "ok" }
  }

  GlobalShortcut {
    name: "ambientToggle"
    description: "Toggle ambient audio panel"
    onPressed: root.toggle()
  }
}
