pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  id: root
  // Set once the shell has painted; the video layer waits for it.
  property bool started: false
  // Auto-pause state is shared by every screen, so it is polled once here.
  property bool holdPlay: false
  readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

  Timer {
    interval: 1000
    running: WallpaperState.isLiveActive
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
        const ws = root.focusedWorkspaceId
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
      root.holdPlay = pause
    }
  }

  // Poll immediately (instead of up to 1s later) whenever the live layer comes back.
  Connections {
    target: WallpaperState
    function onIsLiveActiveChanged() {
      if (!WallpaperState.isLiveActive)
        return
      root.holdPlay = false
      clientsProc.running = true
    }
  }

  LazyLoader {
    active: root.started && WallpaperState.isLiveActive
    Variants {
      model: Quickshell.screens
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: true
        // Transparent so the layer appears without a colour jump; the first decoded
        // frame fades in on top of it.
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        anchors { top: true; bottom: true; left: true; right: true }

        Item {
          id: crossFadeContainer
          anchors.fill: parent

          // Mirrors the scope-wide auto-pause state.
          readonly property bool holdPlay: root.holdPlay
          // True between the start of a crossfade and the new video becoming visible.
          property bool transitioning: false

          function _syncPlayback() {
            // Never pause before a frame exists: a paused decoder shows nothing.
            if (holdPlay && !transitioning && topVideo.hasVideo) {
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

          // Startup / first appearance: the layer stays empty and fades in once a
          // frame has been decoded, instead of popping in.
          function _reveal(path) {
            const url = WallpaperState.fileUrl(path)
            if (url === "")
              return
            fadeBehavior.enabled = false
            topVideo.source = url
            topVideo.opacity = 0
            fadeBehavior.enabled = true
            transitioning = false
            topVideo.play()
            _syncPlayback()
            _settleTimer.restart()
          }

          Component.onCompleted: {
            const p = WallpaperState.livePath
            if (p)
              _reveal(p)
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
              if (!hasVideo)
                return
              // A frame exists now, so an auto-pause can finally freeze it.
              crossFadeContainer._syncPlayback()
              // First frame of a fresh source: fade it in when nothing is showing.
              if (opacity === 0 && !crossFadeContainer.transitioning)
                opacity = 1
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

  // Starting the media backend blocks the GUI thread for ~1s, so wait until the
  // rest of the shell has painted before mounting the video player.
  Timer {
    interval: 300
    running: true
    onTriggered: root.started = true
  }
}
