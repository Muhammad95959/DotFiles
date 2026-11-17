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

  function setVideo(fileName, animate) { WallpaperState.setLiveFile(fileName, animate) }
  function toggleLive() { WallpaperState.toggleMode() }
}
