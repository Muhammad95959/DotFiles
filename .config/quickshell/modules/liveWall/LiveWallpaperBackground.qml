pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  LazyLoader {
    active: WallpaperState.isLiveActive
    Variants {
      model: Quickshell.screens
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: true
        // Opaque until the first frame is decoded: no stale static wallpaper, no black gap.
        color: WallpaperState.liveReady ? "transparent" : Theme.bg
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        anchors { top: true; bottom: true; left: true; right: true }

        Item {
          id: crossFadeContainer
          anchors.fill: parent

          // True while a window occupies the focused workspace (auto-pause).
          property bool holdPlay: false
          // True between the start of a crossfade and the new video becoming visible.
          property bool transitioning: false

          readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

          function _syncPlayback() {
            if (holdPlay && !transitioning) {
              topVideo.pause()
              bottomVideo.pause()
              return
            }
            if (topVideo.source !== "" && topVideo.playbackState !== MediaPlayer.PlayingState)
              topVideo.play()
            if (transitioning && bottomVideo.source !== "")
              bottomVideo.play()
          }

          function _crossFadeTo(path) {
            const url = WallpaperState.fileUrl(path)
            if (url === "" || url === topVideo.source)
              return
            transitioning = true
            if (bottomVideo.source !== topVideo.source)
              bottomVideo.source = topVideo.source
            bottomVideo.play()
            fadeBehavior.enabled = false
            topVideo.opacity = 0
            fadeBehavior.enabled = true
            topVideo.source = url
            topVideo.play()
          }

          function _instantTo(path) {
            const url = WallpaperState.fileUrl(path)
            fadeBehavior.enabled = false
            bottomVideo.source = url
            topVideo.source = url
            topVideo.opacity = 1
            fadeBehavior.enabled = true
            transitioning = false
            _syncPlayback()
            _settleTimer.restart()
          }

          Component.onCompleted: {
            WallpaperState.liveReady = false
            const p = WallpaperState.livePath
            if (p)
              _instantTo(p)
          }

          Video {
            id: bottomVideo
            anchors.fill: parent
            loops: MediaPlayer.Infinite
            muted: true
            autoPlay: true
          }

          Video {
            id: topVideo
            anchors.fill: parent
            loops: MediaPlayer.Infinite
            muted: true
            autoPlay: true
            opacity: 0

            Behavior on opacity { id: fadeBehavior; NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

            onHasVideoChanged: {
              if (hasVideo)
                WallpaperState.liveReady = true
            }
            onPlaybackStateChanged: {
              if (playbackState === MediaPlayer.PlayingState && !WallpaperState.skipNextAnimation && opacity === 0)
                opacity = 1
            }
            onOpacityChanged: {
              if (opacity !== 1 || playbackState !== MediaPlayer.PlayingState)
                return
              // Fade finished: refresh the backdrop player, then settle into the right
              // play state (a window on the focused workspace should pause both).
              crossFadeContainer.transitioning = false
              bottomVideo.source = source
              crossFadeContainer._syncPlayback()
              _settleTimer.restart()
            }
          }

          // Keeps the backdrop decoder warm (one frame ready) without decoding it forever.
          Timer {
            id: _settleTimer
            interval: 700
            onTriggered: {
              if (!crossFadeContainer.transitioning)
                bottomVideo.pause()
            }
          }

          Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clientsProc.running = true
          }

          Process {
            id: clientsProc
            property string _out: ""
            command: ["hyprctl", "-j", "clients"]
            stdout: SplitParser { onRead: data => clientsProc._out += data + "\n" }
            onExited: {
              const raw = clientsProc._out
              clientsProc._out = ""
              let pause = false
              try {
                const list = JSON.parse(raw)
                const ws = crossFadeContainer.focusedWorkspaceId
                for (let i = 0; ws >= 0 && i < list.length; i++) {
                  const c = list[i]
                  if (!c.workspace || c.workspace.id !== ws)
                    continue
                  if (!c.floating || c.fullscreen !== 0) {
                    pause = true
                    break
                  }
                }
              } catch (e) {}
              crossFadeContainer.holdPlay = pause
            }
          }

          onHoldPlayChanged: _syncPlayback()

          Connections {
            target: WallpaperState
            function onLivePathChanged() {
              const p = WallpaperState.livePath
              if (!p)
                return
              if (bottomVideo.source === "" && topVideo.source === "") {
                crossFadeContainer._instantTo(p)
                return
              }
              if (WallpaperState.skipNextAnimation)
                crossFadeContainer._instantTo(p)
              else
                crossFadeContainer._crossFadeTo(p)
            }
          }
        }
      }
    }
  }
}
