pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Wayland

import "../common"

Scope {
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      // Never show a stale static wallpaper while the persisted mode says live.
      visible: WallpaperState.restored && WallpaperState.staticPath !== "" && !WallpaperState.isLiveActive
      color: Theme.bg
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Background
      anchors { top: true; bottom: true; left: true; right: true }

      function _crossFadeTo(path) {
        fadeBehavior.enabled = false
        topImage.opacity = 0
        fadeBehavior.enabled = true
        topImage.source = WallpaperState.fileUrl(path)
        if (topImage.status === Image.Ready)
          topImage.opacity = 1
      }
      function _instantTo(path) {
        fadeBehavior.enabled = false
        const url = WallpaperState.fileUrl(path)
        bottomImage.source = url
        topImage.source = url
        topImage.opacity = 1
        fadeBehavior.enabled = true
      }

      Component.onCompleted: {
        const p = WallpaperState.staticPath
        if (p)
          _instantTo(p)
      }

      Item {
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
            if (status === Image.Ready && !WallpaperState.skipNextAnimation && opacity === 0)
              opacity = 1
          }
          onOpacityChanged: {
            if (opacity === 1 && status === Image.Ready)
              bottomImage.source = source
          }
        }
      }

      Connections {
        target: WallpaperState
        function onStaticPathChanged() {
          const p = WallpaperState.staticPath
          if (!p)
            return
          if (bottomImage.source === "" && topImage.source === "") {
            _instantTo(p)
            return
          }
          if (WallpaperState.skipNextAnimation)
            _instantTo(p)
          else
            _crossFadeTo(p)
        }
      }
    }
  }
}
