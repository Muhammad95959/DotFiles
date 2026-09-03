pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Io

Scope {
  id: manager

  property string currentPath: ""
  property string activeFile: ""
  property bool isLiveActive: false
  property bool skipNextAnimation: true

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

  function setVideo(fileName, animate) {
    if (!fileName) return
    const full = Quickshell.env("HOME") + "/Backgrounds/Live/" + fileName
    const esc = fileName.replace(/["$`\\]/g, "\\$&")
    Quickshell.execDetached(["sh", "-c", "ln -frs \"$HOME/Backgrounds/Live/" + esc + "\" \"$HOME/Backgrounds/Live/active\""])
    const shouldAnimate = animate !== false
    skipNextAnimation = !shouldAnimate
    if (skipNextAnimation) _resetSkipTimer.restart()
    currentPath = full
    activeFile = fileName
    isLiveActive = true
  }

  function setActivePath(fullPath, animate) {
    if (!fullPath) return
    const base = fullPath.substring(fullPath.lastIndexOf("/") + 1)
    setVideo(base, animate)
  }

  function toggleLive() {
    if (isLiveActive) {
      skipNextAnimation = false
      isLiveActive = false
    } else {
      if (!activeFile && !currentPath) {
        const link = Quickshell.env("HOME") + "/Backgrounds/Live/active"
        // fallback handled by loadProc; just try to load
        loadCurrent()
        return
      }
      skipNextAnimation = false
      isLiveActive = true
      if (!currentPath && activeFile) currentPath = Quickshell.env("HOME") + "/Backgrounds/Live/" + activeFile
    }
  }

  Process {
    id: loadProc
    command: ["sh", "-c", "readlink -f \"$HOME/Backgrounds/Live/active\" 2>/dev/null || echo \"\""]
    stdout: SplitParser {
      onRead: data => {
        const p = data.trim()
        if (p.length > 0) {
          manager.skipNextAnimation = true
          _resetSkipTimer.restart()
          manager.currentPath = p
          const base = p.substring(p.lastIndexOf("/") + 1)
          manager.activeFile = base
        }
      }
    }
  }

  Timer {
    id: _resetSkipTimer
    interval: 750
    onTriggered: manager.skipNextAnimation = false
  }

  Component.onCompleted: {
    loadCurrent()
    Quickshell.execDetached(["sh", "-c", "pkill -9 -x mpvpaper 2>/dev/null; rm -f /tmp/mpv-socket 2>/dev/null || true"])
  }
}
