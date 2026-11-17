pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Io

import "../common"

// Static wallpapers. State and persistence live in WallpaperState;
// this is the public API used by the chooser and IPC.
Scope {
  id: manager

  readonly property string startupPath: WallpaperState.staticPath

  function setWallpaper(path) { WallpaperState.setStatic(path, true) }
  // Temporary wallpaper: shown now, not restored on the next start.
  function previewWallpaper(path, animate) { WallpaperState.setStatic(path, animate !== false, false) }
  function setRandomWallpaper() { randomProc.running = true }

  Process {
    id: randomProc
    command: ["sh", "-c", "find \"$HOME/Backgrounds\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' \\) 2>/dev/null | shuf -n1"]
    stdout: SplitParser {
      onRead: data => {
        const p = data.trim()
        if (p.length > 0)
          manager.previewWallpaper(p, false)
      }
    }
  }
}
