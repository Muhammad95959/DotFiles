pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Io

Scope {
  id: manager

  // ── Current wallpaper (mirrored single) ────────────────────────────
  property string currentPath: ""
  property bool skipNextAnimation: true
  property string startupPath: "" // persisted, loaded at startup, not changed by random

  onSkipNextAnimationChanged: {
    if (skipNextAnimation) _resetSkipTimer.restart()
  }

  function fileUrl(path) {
    if (!path) return ""
    return "file://" + path.split("/").map(c => c === "" ? "" : encodeURIComponent(c)).join("/")
  }

  function loadCurrent() {
    loadProc.running = true
  }

  function setRandomWallpaper() {
    skipNextAnimation = true
    _resetSkipTimer.restart()
    randomProc.running = true
  }

  function setTransientWallpaper(path, skipAnimation) {
    if (!path) return
    const skip = skipAnimation === true
    skipNextAnimation = skip
    if (skip) _resetSkipTimer.restart()
    currentPath = path
  }

  function setWallpaper(path) {
    if (!path) return
    skipNextAnimation = false
    currentPath = path
    startupPath = path
    const esc = path.replace(/'/g, "'\\''")
    Quickshell.execDetached(["sh", "-c", "ln -frs '" + esc + "' \"$HOME/.cache/waylandwall\""])
    Quickshell.execDetached(["sh", "-c", "magick '" + esc + "' -gravity center -crop '1:1' -resize 720x720 \"$HOME/.cache/rofiwall\""])
  }

  // read current from symlink on startup
  Process {
    id: loadProc
    command: ["readlink", "-f", Quickshell.env("HOME") + "/.cache/waylandwall"]
    stdout: SplitParser {
      onRead: data => {
        const p = data.trim()
        if (p.length > 0) {
          manager.skipNextAnimation = true
          _resetSkipTimer.restart()
          manager.currentPath = p
          manager.startupPath = p
        }
      }
    }
  }

  // ── Random (mirrors old awww bind) — transient, does not change startup ─
  Process {
    id: randomProc
    command: ["sh", "-c", "find \"$HOME/Backgrounds\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' \\) 2>/dev/null | shuf -n1"]
    stdout: SplitParser {
      onRead: data => {
        const p = data.trim()
        if (p.length > 0) manager.setTransientWallpaper(p, true)
      }
    }
  }

  Timer {
    id: _resetSkipTimer
    interval: 750
    onTriggered: manager.skipNextAnimation = false
  }

  Component.onCompleted: loadCurrent()
}
