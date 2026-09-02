pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  id: manager

  // ── Current wallpaper (mirrored single) ────────────────────────────
  property string currentPath: ""
  property string startupPath: "" // persisted, loaded at startup, not changed by random

  // helper for file:// encoding (#, unicode, spaces)
  function fileUrl(path) {
    if (!path) return ""
    return "file://" + path.split("/").map(c => c === "" ? "" : encodeURIComponent(c)).join("/")
  }

  function loadCurrent() {
    loadProc.running = true
  }

  function setWallpaper(path) {
    if (!path) return
    currentPath = path
    startupPath = path
    const esc = path.replace(/'/g, "'\\''")
    // keep awww compat until user deletes it, but native background is primary
    const cmd = "ln -fs '" + esc + "' \"$HOME/.cache/waylandwall\"; "
              + "mkdir -p \"$HOME/.cache\"; "
              + "command -v magick >/dev/null 2>&1 && magick \"$HOME/.cache/waylandwall\" -gravity center -crop 1:1 +repage \"$HOME/.cache/rofiwall\" 2>/dev/null || true; "
              + "if command -v awww >/dev/null 2>&1; then pgrep -x awww-daemon >/dev/null 2>&1 || setsid awww-daemon >/dev/null 2>&1 & sleep 0.2; awww img '" + esc + "' --transition-type none --transition-duration 0 2>/dev/null || true; fi"
    Quickshell.execDetached(["sh", "-c", cmd])
  }

  function setTransientWallpaper(path) {
    if (!path) return
    currentPath = path
    // do NOT update startupPath / waylandwall — transient only
    const esc = path.replace(/'/g, "'\\''")
    const cmd = "if command -v awww >/dev/null 2>&1; then pgrep -x awww-daemon >/dev/null 2>&1 || setsid awww-daemon >/dev/null 2>&1 & sleep 0.2; awww img '" + esc + "' --transition-type none --transition-duration 0 2>/dev/null || true; fi"
    Quickshell.execDetached(["sh", "-c", cmd])
  }

  // read current from symlink on startup
  Process {
    id: loadProc
    command: ["sh", "-c", "readlink -f \"$HOME/.cache/waylandwall\" 2>/dev/null || echo \"\""]
    stdout: SplitParser {
      onRead: data => {
        const p = data.trim()
        if (p.length > 0) { manager.currentPath = p; manager.startupPath = p }
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
        if (p.length > 0) manager.setTransientWallpaper(p)
      }
    }
  }

  function setRandomWallpaper() { randomProc.running = true }

  Component.onCompleted: loadCurrent()
}
