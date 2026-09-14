pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Io

Scope {
  id: manager

  property string currentPath: ""
  property bool skipNextAnimation: true
  property string startupPath: ""

  // Storage: ~/Backgrounds/active symlink, like LiveWall's ~/Backgrounds/Live/active.
  readonly property string activeLink: Quickshell.env("HOME") + "/Backgrounds/active"

  onSkipNextAnimationChanged: {
    if (skipNextAnimation)
      _resetSkipTimer.restart()
  }

  function fileUrl(path) {
    if (!path)
      return ""
    return "file://" + path.split("/").map(c => c === "" ? "" : encodeURIComponent(c)).join("/")
  }
  function loadCurrent() { loadProc.running = true }
  function setRandomWallpaper() {
    skipNextAnimation = true
    _resetSkipTimer.restart()
    randomProc.running = true
  }
  function setTransientWallpaper(path, skipAnimation) {
    if (!path)
      return
    const skip = skipAnimation === true
    skipNextAnimation = skip
    if (skip)
      _resetSkipTimer.restart()
    currentPath = path
  }
  function setWallpaper(path) {
    if (!path)
      return
    skipNextAnimation = false
    currentPath = path
    startupPath = path
    Quickshell.execDetached(["ln", "-sfnr", path, manager.activeLink])
  }

  Process {
    id: loadProc
    command: ["readlink", "-f", manager.activeLink]
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

  Process {
    id: randomProc
    command: ["sh", "-c", "find \"$HOME/Backgrounds\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' \\) 2>/dev/null | shuf -n1"]
    stdout: SplitParser {
      onRead: data => {
        const p = data.trim()
        if (p.length > 0)
          manager.setTransientWallpaper(p, true)
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
