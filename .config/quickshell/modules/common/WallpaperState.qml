pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Io

// Single source of truth for which wallpaper layer is showing.
//   mode      -> "static" | "live"   (persisted, restored on start)
//   staticPath/livePath -> backed by the ~/Backgrounds links
Scope {
  id: state

  readonly property string home: Quickshell.env("HOME")
  readonly property string liveDir: home + "/Backgrounds/Live"
  readonly property string staticLink: home + "/Backgrounds/active"
  readonly property string liveLink: liveDir + "/active"
  readonly property string stateDir: {
    const x = Quickshell.env("XDG_STATE_HOME")
    return (x && x.length > 0 ? x : home + "/.local/state") + "/quickshell"
  }
  readonly property string modeFile: stateDir + "/wallpaper-mode"

  property string mode: "static"
  property string staticPath: ""
  property string livePath: ""
  property bool skipNextAnimation: true
  // True once the persisted mode and paths have been read, so the correct layer
  // is picked before anything is painted.
  property bool restored: false
  property int _pendingReads: 0
  // True once the live player has a decoded video frame to show.
  property bool liveReady: false

  // A live mode without a video falls back to the static wallpaper.
  readonly property bool isLiveActive: mode === "live" && livePath !== ""

  function fileUrl(path) {
    if (!path)
      return ""
    return "file://" + path.split("/").map(c => c === "" ? "" : encodeURIComponent(c)).join("/")
  }

  function _skipNext() {
    skipNextAnimation = true
    _resetSkipTimer.restart()
  }

  function _persistMode() {
    Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s\\n' \"$2\" > \"$1/wallpaper-mode\"",
                             "sh", state.stateDir, state.mode])
  }

  function setStatic(path, animate, persist) {
    if (!path)
      return
    staticPath = path
    mode = "static"
    if (animate === false)
      _skipNext()
    else
      skipNextAnimation = false
    if (persist !== false) {
      Quickshell.execDetached(["ln", "-sfnr", path, state.staticLink])
      _persistMode()
    }
  }

  function setLive(path, animate) {
    if (!path)
      return
    livePath = path
    mode = "live"
    if (animate === false)
      _skipNext()
    else
      skipNextAnimation = false
    Quickshell.execDetached(["ln", "-sfnr", path, state.liveLink])
    _persistMode()
  }

  function setLiveFile(fileName, animate) {
    if (!fileName)
      return
    setLive(liveDir + "/" + fileName, animate)
  }

  function toggleMode() {
    if (isLiveActive) {
      mode = "static"
      skipNextAnimation = false
    } else if (livePath) {
      mode = "live"
      skipNextAnimation = false
    } else {
      return
    }
    _persistMode()
  }

  function reload() {
    _pendingReads = 3
    restored = false
    _restoreTimeoutTimer.restart()
    modeProc.running = true
    staticProc.running = true
    liveProc.running = true
  }

  function _readFinished() {
    if (_pendingReads > 0)
      _pendingReads--
    if (_pendingReads === 0) {
      _restoreTimeoutTimer.stop()
      restored = true
    }
  }

  Component.onCompleted: {
    _resetSkipTimer.restart()
    reload()
  }

  Process {
    id: modeProc
    command: ["cat", state.modeFile]
    stdout: SplitParser {
      onRead: data => {
        const m = data.trim()
        if (m === "live" || m === "static") {
          state.mode = m
          state._skipNext()
        }
      }
    }
    onExited: state._readFinished()
  }

  Process {
    id: staticProc
    command: ["readlink", "-e", state.staticLink]
    stdout: SplitParser {
      onRead: data => {
        const p = data.trim()
        if (p.length > 0) {
          state.staticPath = p
          state._skipNext()
        }
      }
    }
    onExited: state._readFinished()
  }

  Process {
    id: liveProc
    command: ["readlink", "-e", state.liveLink]
    stdout: SplitParser {
      onRead: data => {
        const p = data.trim()
        if (p.length > 0) {
          state.livePath = p
          state._skipNext()
        }
      }
    }
    onExited: state._readFinished()
  }

  // Never hold the wallpaper layer back for long, even if a read misbehaves.
  Timer {
    id: _restoreTimeoutTimer
    interval: 500
    onTriggered: state.restored = true
  }

  Timer {
    id: _resetSkipTimer
    interval: 750
    onTriggered: state.skipNextAnimation = false
  }
}
