pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia

import Quickshell
import Quickshell.Io
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
      visible: LiveWallManager.currentPath !== ""
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      anchors { top: true; bottom: true; left: true; right: true }

      LazyLoader {
        active: LiveWallManager.isLiveActive

        Item {
          id: crossFadeContainer
          anchors.fill: parent
          opacity: LiveWallManager.isLiveActive ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

          function _crossFadeTo(path) {
            fadeBehavior.enabled = false
            topVideo.opacity = 0
            fadeBehavior.enabled = true
            const url = LiveWallManager.fileUrl(path)
            topVideo.source = url
            topVideo.play()
            if (topVideo.playbackState === MediaPlayer.PlayingState || topVideo.hasVideo) topVideo.opacity = 1
          }

          function _instantTo(path) {
            fadeBehavior.enabled = false
            const url = LiveWallManager.fileUrl(path)
            bottomVideo.source = url
            topVideo.source = url
            topVideo.opacity = 1
            bottomVideo.play()
            topVideo.play()
            fadeBehavior.enabled = true
          }

          Component.onCompleted: {
            const p = LiveWallManager.currentPath
            if (p) {
              const url = LiveWallManager.fileUrl(p)
              bottomVideo.source = url
              topVideo.source = url
              topVideo.opacity = 1
              if (topVideo.playbackState !== MediaPlayer.PlayingState) topVideo.play()
              if (bottomVideo.playbackState !== MediaPlayer.PlayingState) bottomVideo.play()
            }
          }

          Video {
            id: bottomVideo
            anchors.fill: parent
            loops: MediaPlayer.Infinite
            volume: 0
            muted: true
            autoPlay: true
          }

          Video {
            id: topVideo
            anchors.fill: parent
            loops: MediaPlayer.Infinite
            volume: 0
            muted: true
            autoPlay: true
            opacity: 0

            Behavior on opacity { id: fadeBehavior; NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

            onPlaybackStateChanged: {
              if (playbackState === MediaPlayer.PlayingState && !LiveWallManager.skipNextAnimation && opacity === 0)
                opacity = 1
            }

            onOpacityChanged: {
              if (opacity === 1 && playbackState === MediaPlayer.PlayingState) {
                bottomVideo.source = source
                if (bottomVideo.playbackState !== MediaPlayer.PlayingState) bottomVideo.play()
              }
            }
          }

          Timer {
            interval: 1000
            running: LiveWallManager.isLiveActive
            repeat: true
            onTriggered: pauseCheck.running = true
          }

          Process {
            id: pauseCheck
            command: ["sh", "-c",
              "hyprctl clients -j 2>/dev/null | python3 -c \"\nimport json, subprocess, re, sys\ntry:\n    clients=json.load(sys.stdin)\nexcept:\n    sys.exit(0)\ntry:\n    mon=json.loads(subprocess.check_output(['hyprctl','monitors','-j']))\nexcept:\n    mon=[]\nactiveWs=None\nfor m in mon:\n    if m.get('focused'):\n        activeWs=m.get('activeWorkspace',{}).get('id'); break\nif activeWs is None and mon:\n    activeWs=mon[0].get('activeWorkspace',{}).get('id')\nfocused=[c for c in clients if c.get('focusHistoryID')==0]\nactiveClass=focused[0].get('class','') if focused else ''\nfs=set(c.get('workspace',{}).get('id') for c in clients if c.get('fullscreen')!=0)\ntiled=[c for c in clients if not c.get('floating') and c.get('workspace',{}).get('id')==activeWs]\nclasses=[c.get('class','') for c in tiled]\npat=re.compile(r'(kitty|Yazi)')\npause='yes' if (classes and not any(pat.search(x) for x in classes)) or (activeWs in fs and not pat.search(activeClass)) else 'no'\nprint(pause)\n\" 2>/dev/null | tr -d '\\n'"
            ]
            stdout: SplitParser {
              onRead: data => {
                const p = data.trim()
                if (p === "yes") {
                  if (bottomVideo.playbackState === MediaPlayer.PlayingState) bottomVideo.pause()
                  if (topVideo.playbackState === MediaPlayer.PlayingState) topVideo.pause()
                } else if (p === "no") {
                  if (bottomVideo.playbackState === MediaPlayer.PausedState) bottomVideo.play()
                  if (topVideo.playbackState === MediaPlayer.PausedState) topVideo.play()
                }
              }
            }
          }

          Connections {
            target: LiveWallManager
            function onCurrentPathChanged() {
              const p = LiveWallManager.currentPath
              if (!p) return
              if (!LiveWallManager.isLiveActive) return
              if (bottomVideo.source === "" && topVideo.source === "") {
                _instantTo(p)
                return
              }
              if (LiveWallManager.skipNextAnimation) _instantTo(p)
              else _crossFadeTo(p)
            }
            function onIsLiveActiveChanged() {
              if (LiveWallManager.isLiveActive) {
                const p = LiveWallManager.currentPath
                if (!p) return
                if (bottomVideo.source === "" || topVideo.source === "") _instantTo(p)
                else if (LiveWallManager.skipNextAnimation) _instantTo(p)
                else _crossFadeTo(p)
                if (bottomVideo.playbackState !== MediaPlayer.PlayingState) bottomVideo.play()
                if (topVideo.playbackState !== MediaPlayer.PlayingState) topVideo.play()
              } else {
                bottomVideo.pause()
                topVideo.pause()
              }
            }
          }
        }
      }
    }
  }
}
