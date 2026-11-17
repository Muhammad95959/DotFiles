pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

import Quickshell

import "../common"

// Live wallpapers. State and persistence live in WallpaperState;
// this is the public API used by the picker and IPC.
Scope {
  readonly property string activeFile: {
    const p = WallpaperState.livePath
    return p ? p.substring(p.lastIndexOf("/") + 1) : ""
  }
  readonly property bool isLiveActive: WallpaperState.isLiveActive

  function setVideo(file, animate) { WallpaperState.setLiveFile(file, animate, true) }
  // Temporary video: played now, not restored on the next start.
  function previewVideo(file, animate) { WallpaperState.setLiveFile(file, animate, false) }
  function toggleLive() { WallpaperState.toggleMode() }
}
