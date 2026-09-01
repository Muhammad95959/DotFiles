pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../common"
import "."

Scope {
  id: bgRoot

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      visible: WallpaperManager.currentPath !== ""
      color: Theme.bg
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Background
      anchors { top: true; bottom: true; left: true; right: true }

      // mirrored single wallpaper on all outputs
      Image {
        id: bgImage
        anchors.fill: parent
        source: WallpaperManager.fileUrl(WallpaperManager.currentPath)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        // downscale to screen size for cache speed
        sourceSize.width: win.screen ? win.screen.width : 1920
        sourceSize.height: win.screen ? win.screen.height : 1080

        // subtle fade when changing
        opacity: 1
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        onSourceChanged: { opacity = 0; opacity = 1 }
      }

      // fallback solid if no wallpaper yet
      Rectangle {
        anchors.fill: parent
        color: Theme.bg
        visible: WallpaperManager.currentPath === ""
        z: -1
      }
    }
  }
}
