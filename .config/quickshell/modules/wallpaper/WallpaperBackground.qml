pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Wayland

import "."
import "../common"

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

      Component.onCompleted: {
        const p = WallpaperManager.currentPath
        if (p) {
          const url = WallpaperManager.fileUrl(p)
          bottomImage.source = url
          topImage.source = url
          topImage.opacity = 1
        }
      }

      function _crossFadeTo(path) {
        fadeBehavior.enabled = false
        topImage.opacity = 0
        fadeBehavior.enabled = true
        topImage.source = WallpaperManager.fileUrl(path)
        if (topImage.status === Image.Ready) topImage.opacity = 1
      }

      function _instantTo(path) {
        fadeBehavior.enabled = false
        const url = WallpaperManager.fileUrl(path)
        bottomImage.source = url
        topImage.source = url
        topImage.opacity = 1
        fadeBehavior.enabled = true
      }

      Item {
        id: crossFadeContainer
        anchors.fill: parent

        Image {
          id: bottomImage
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          smooth: true
          mipmap: true
          sourceSize.width: win.screen ? win.screen.width : 1920
          sourceSize.height: win.screen ? win.screen.height : 1080
        }

        Image {
          id: topImage
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          smooth: true
          mipmap: true
          sourceSize.width: win.screen ? win.screen.width : 1920
          sourceSize.height: win.screen ? win.screen.height : 1080
          opacity: 0

          Behavior on opacity { id: fadeBehavior; NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

          onStatusChanged: {
            if (status === Image.Ready && !WallpaperManager.skipNextAnimation && opacity === 0)
              opacity = 1
          }

          onOpacityChanged: {
            if (opacity === 1 && status === Image.Ready)
              bottomImage.source = source
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: Theme.bg
        visible: WallpaperManager.currentPath === ""
        z: -1
      }

      Connections {
        target: WallpaperManager
        function onCurrentPathChanged() {
          const p = WallpaperManager.currentPath
          if (!p) return
          if (bottomImage.source === "" && topImage.source === "") {
            _instantTo(p)
            return
          }
          if (WallpaperManager.skipNextAnimation) _instantTo(p)
          else _crossFadeTo(p)
        }
      }
    }
  }
}
