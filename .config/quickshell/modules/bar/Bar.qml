pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets

import "../common"

Scope {
  id: barScope

  // ── Signals ────────────────────────────────────────────────────────
  signal launcherRequested()
  signal powermenuRequested()

  // ── Theme (global) ─────────────────────────────────────────────────
  readonly property color bg: Theme.bg
  readonly property color fg: Theme.fg
  readonly property color urgent: Theme.urgent

  // ── Fonts ──────────────────────────────────────────────────────────
  readonly property string nerdFont: Theme.nerdFont
  readonly property string monoFont: Theme.monoFont

  // ── Audio Binding ──────────────────────────────────────────────────
  PwObjectTracker {
    objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ]
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData

      anchors { top: true; left: true; right: true }
      implicitHeight: bar.barHeight
      exclusiveZone: bar.barExclusiveZone
      color: "transparent"

      // ── Bar Geometry ──────────────────────────────────────────────
      property int barHeight: 24
      property int barExclusiveZone: 24

      // ── Spacing (bar-only, not shared) ─────────────────────────────
      property int pLauncherLeft: 8
      property int mLauncherRight: 8
      property int mWorkspacesOuterPad: 8
      property int pWorkspacesBtnPad: 4
      property int mWorkspacesGap: 4
      property int mSubmapPad: 6
      property int pSubmapInnerPad: 8
      property int mWindowPad: 8
      property int mSepPad: 8
      property int mBandwidthPad: 5
      property int pBandwidthUnitGap: 2
      property int pBandwidthIconGap: 5
      property int mLanguagePad: 5
      property int pLanguageIconGap: 5
      property int mCpuPad: 5
      property int pCpuIconGap: 5
      property int mVolumePad: 5
      property int pVolumeIconGap: 5
      property int mBatteryPad: 5
      property int pBatteryIconGap: 5
      property int mNetworkPad: 5
      property int pNetworkIconGap: 5
      property int mTrayOuterPad: 5
      property int pTrayIconGap: 5
      property int mPowermenuLeft: 5
      property int pPowermenuRight: 8

      // ── Font Sizes ─────────────────────────────────────────────────
      property int fontSizeText: 12
      property int fontSizeLauncherIcon: 14
      property int fontSizeWorkspaceIcon: 12
      property int fontSizePowermenuIcon: 14
      property int fontSizeLanguageIcon: 14
      property int fontSizeCpuIcon: 15
      property int fontSizeNetworkIcon: 13
      property int trayIconSize: 14

      // ── Right-side vertical offsets ────────────────────────────────
      property real bandwidthIconVerticalOffset: 0
      property real bandwidthTextVerticalOffset: 0
      property real languageIconVerticalOffset: 0
      property real languageTextVerticalOffset: 0.3
      property real cpuIconVerticalOffset: 1
      property real cpuTextVerticalOffset: 0
      property real volumeIconVerticalOffset: 1
      property real volumeTextVerticalOffset: 0
      property real batteryIconVerticalOffset: 0.6
      property real batteryTextVerticalOffset: 0
      property real networkContainerVerticalOffset: 0.6
      property real networkIconVerticalOffset: 0.5
      property real networkTextVerticalOffset: 0

      // ── Intervals ──────────────────────────────────────────────────
      property int bandwidthIntervalMs: 1000
      property int cpuIntervalMs: 2000
      property int networkIntervalMs: 10000
      property int bilalIntervalMs: 30000
      property int bilalNotifyDurationMs: 30000

      // ── Commands ───────────────────────────────────────────────────
      property var screenshotCmd: ["flameshot", "gui"]
      property var systemMonitorCmd: ["kitty", "-e", "--hold", "btm"]
      property string bilalScriptPath: "~/Scripts/bilal.sh"

      // ── Window Title ───────────────────────────────────────────────
      property int windowTitleMaxWidth: 260
      property var windowTitleRewrites: ({
        "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default": "whatsapp-web",
        "brave-translate.google.com.eg__-Default": "brave-translate"
      })

      // ── Workspaces ─────────────────────────────────────────────────
      property var workspacePersistentIds: [1,2,3,4,5,6,7,8,9]
      property int workspaceUrgentWidth: 40
      property int workspaceUrgentRadius: 4

      // ── Runtime State ──────────────────────────────────────────────
      property string submapName: ""
      property string kbLayout: ""
      property bool kbLayoutReady: false
      property int _hyprTick: 0

      Rectangle {
        anchors.fill: parent
        color: barScope.bg
      }

      // ── Submap & Layout ────────────────────────────────────────────
      Connections {
        target: Hyprland
        function onRawEvent(event) {
          bar._hyprTick++
          if (event.name === "submap") {
            bar.submapName = event.data
          } else if (event.name === "activelayout") {
            const parts = event.data.split(",")
            if (parts.length >= 2 && parts[0] === "kanata") {
              let full = parts.slice(1).join(",").trim()
              if (full.length > 3) full = bar.shortForLayout(full)
              bar.kbLayout = full
              bar.kbLayoutReady = true
            }
          }
        }
      }

      function shortForLayout(full) {
        const m = full.toLowerCase()
        if (m.includes("english")) return "EN"
        if (m.includes("arabic")) return "AR"
        return full.slice(0,2).toUpperCase()
      }

      Process {
        command: ["sh", "-c", "hyprctl -j devices | python3 -c \"import json,sys; d=json.load(sys.stdin); k=[k for k in d.get('keyboards',[]) if k.get('name')=='kanata'] ; layout=(k[0].get('layout','') if k else '').split(','); idx=k[0].get('active_layout_index',0) if k else 0; print(layout[idx] if idx < len(layout) and layout[idx] else k[0].get('active_keymap','') if k else '')\""]
        running: true
        stdout: SplitParser { onRead: function(data) { let v=data.trim().toLowerCase(); if (v === "us") v = "EN"; else if (v === "eg") v = "AR"; else if (v.length > 3) v = bar.shortForLayout(v); else v = v.toUpperCase(); bar.kbLayout = v; bar.kbLayoutReady = true } }
      }

      // ── Bandwidth ──────────────────────────────────────────────────
      property string bwValue: "000.0"
      property string bwUnit: "KB"
      property double _prevRx: -1
      property double _prevTx: -1
      Timer {
        interval: bar.bandwidthIntervalMs; running: true; repeat: true
        onTriggered: bwProc.running = true
      }
      Process {
        id: bwProc
        command: ["sh", "-c", "awk '/^(eth|enp|wlan|wlp)/ {rx+=$2; tx+=$10} END {print rx\" \"tx}' /proc/net/dev"]
        stdout: SplitParser {
          onRead: function(data) {
            const parts = data.trim().split(" ")
            if (parts.length < 2) return
            const rx = parseFloat(parts[0]); const tx = parseFloat(parts[1])
            if (bar._prevRx >= 0) {
              const drx = rx - bar._prevRx; const dtx = tx - bar._prevTx
              const total = drx + dtx
              let num, unit
              if (total < 1024*1024) { num = (total/1024).toFixed(1); unit = "KB" }
              else if (total < 1024*1024*1024) { num = (total/(1024*1024)).toFixed(1); unit = "MB" }
              else { num = (total/(1024*1024*1024)).toFixed(1); unit = "GB" }
              if (total >= 1024*1000 && total < 1024*1024) { num = "1.0"; unit = "MB" }
              else if (total >= 1024*1024*1000 && total < 1024*1024*1024) { num = "1.0"; unit = "GB" }
              bar.bwValue = num.padStart(5, "0")
              bar.bwUnit = unit
            }
            bar._prevRx = rx; bar._prevTx = tx
          }
        }
      }

      // ── CPU ────────────────────────────────────────────────────────
      property int cpuUsage: 0
      property double _prevIdle: -1
      property double _prevTotal: -1
      Timer { interval: bar.cpuIntervalMs; running: true; repeat: true; onTriggered: cpuProc.running = true }
      Process {
        id: cpuProc
        command: ["sh", "-c", "awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat"]
        stdout: SplitParser {
          onRead: function(data) {
            const v = data.trim().split(" ").map(x=>parseFloat(x))
            if (v.length < 8) return
            const idle = v[3] + v[4]
            const total = v.reduce((a,b)=>a+b,0)
            if (bar._prevIdle >= 0) {
              const dIdle = idle - bar._prevIdle
              const dTotal = total - bar._prevTotal
              if (dTotal > 0) bar.cpuUsage = Math.round(100 * (1 - dIdle/dTotal))
            }
            bar._prevIdle = idle; bar._prevTotal = total
          }
        }
      }

      // ── Network ────────────────────────────────────────────────────
      property int wifiSignal: -1
      property string wifiEssid: ""
      property bool wifiConnected: false
      property string _netAccum: ""
      Timer { interval: bar.networkIntervalMs; running: true; repeat: true; triggeredOnStart: true; onTriggered: { bar._netAccum = ""; netProc.running = true } }
      Process {
        id: netProc
        command: ["sh", "-c", "awk 'NR==3 {if ($3 ~ /\\./) {sig=int($3); if(sig<0) sig=0; if(sig>70) sig=70; pct=int(sig*100/70); print pct } else print -1}' /proc/net/wireless 2>/dev/null; echo '---'; nmcli -t -f IN-USE,SSID,FREQ dev wifi 2>/dev/null | grep '^\\*' | head -n1; echo '---'; nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q 'wifi:connected' && echo connected || echo disconnected"]
        stdout: SplitParser {
          onRead: function(data) {
            bar._netAccum += data + "\n"
            const full = bar._netAccum
            if (!full.includes("connected") && !full.includes("disconnected")) return
            const parts = full.split("---")
            if (parts.length >= 3) {
              const sigStr = parts[0].trim().split("\n").filter(x=>x!=="")[0] || "-1"
              const sig = parseInt(sigStr)
              bar.wifiSignal = isNaN(sig) ? -1 : sig
              const wifiLine = (parts[1] || "").trim().split("\n").filter(x=>x!=="")[0] || ""
              if (wifiLine.startsWith("*")) {
                const segs = wifiLine.split(":")
                bar.wifiEssid = segs[1] || ""
                bar.wifiConnected = true
              } else {
                bar.wifiEssid = ""; bar.wifiConnected = false
              }
              const state = (parts[2] || "").trim().split("\n")[0] || ""
              bar.wifiConnected = state === "connected" && bar.wifiSignal >= 0
              if (!bar.wifiConnected && state !== "connected") bar.wifiSignal = -1
              bar._netAccum = ""
            }
          }
        }
      }

      // ── Bilal ──────────────────────────────────────────────────────
      property string bilalText: ""
      Timer { interval: bar.bilalIntervalMs; running: true; repeat: true; triggeredOnStart: true; onTriggered: bilalProc.running = true }
      Process {
        id: bilalProc
        command: ["sh", "-c", bar.bilalScriptPath + " -r 2>/dev/null || echo ''"]
        stdout: SplitParser { onRead: function(data) { bar.bilalText = data.trim() } }
      }
      Process {
        id: bilalNotifyProc
        command: ["sh", "-c", "notify-send -t " + bar.bilalNotifyDurationMs + " \"$(" + bar.bilalScriptPath + " -a 2>/dev/null)\""]
      }

      // ── Clock ──────────────────────────────────────────────────────
      property bool clockAlt: false
      SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
      }

      // ── Layout ─────────────────────────────────────────────────────
      Item {
        anchors.fill: parent

        // LEFT
        Row {
          spacing: 0
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          // Launcher
          Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              width: launcherText.implicitWidth + bar.pLauncherLeft
              height: bar.implicitHeight
              color: "transparent"
              Text {
                id: launcherText
                anchors.left: parent.left
                anchors.leftMargin: bar.pLauncherLeft
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: barScope.fg
                font.family: barScope.nerdFont
                font.pixelSize: bar.fontSizeLauncherIcon
              }
              MouseArea {
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                anchors.fill: parent
                onClicked: mouse => {
                  if (mouse.button === Qt.LeftButton) barScope.launcherRequested()
                  else if (mouse.button === Qt.RightButton) Quickshell.execDetached(bar.screenshotCmd)
                }
                acceptedButtons: Qt.LeftButton | Qt.RightButton
              }
            }
            Item { width: bar.mLauncherRight; height: 1 }
          }

          Item { width: bar.mWorkspacesOuterPad; height: 1 }
          Row {
            spacing: bar.mWorkspacesGap
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
              model: bar.workspacePersistentIds
              Rectangle {
                id: wsBtn
                required property int modelData
                property var wsObj: {
                  const all = Hyprland.workspaces.values
                  for (let i=0;i<all.length;i++) if (all[i].id === modelData) return all[i]
                  return null
                }
                property bool isActive: {
                  bar._hyprTick
                  const fw = Hyprland.focusedWorkspace
                  if (fw && fw.id === modelData) return true
                  const mon = Hyprland.monitorFor(bar.screen)
                  if (mon && mon.activeWorkspace && mon.activeWorkspace.id === modelData) return true
                  return wsObj ? (wsObj.focused || wsObj.active) : false
                }
                property bool isUrgent: wsObj ? wsObj.urgent : false
                property bool isEmpty: {
                  bar._hyprTick
                  const hasWindow = Hyprland.toplevels.values.some(t => t.workspace && t.workspace.id === modelData)
                  if (hasWindow) return false
                  if (wsObj) return wsObj.toplevels.values.length === 0
                  return true
                }

                width: isUrgent ? bar.workspaceUrgentWidth : Math.max(bar.pWorkspacesBtnPad*2+10, wsLabel.implicitWidth + bar.pWorkspacesBtnPad*2)
                height: bar.implicitHeight - 4
                radius: isUrgent ? bar.workspaceUrgentRadius : 4
                opacity: (!isActive && isEmpty) ? 0.5 : 1
                color: {
                  if (isUrgent) return barScope.urgent
                  if (wsMouse.containsMouse) return Qt.lighter(barScope.bg, 1.8)
                  return "transparent"
                }
                border.color: wsMouse.containsMouse && !isActive ? Theme.border : "transparent"
                border.width: wsMouse.containsMouse && !isActive ? 1 : 0

                Text {
                  id: wsLabel
                  anchors.centerIn: parent
                  text: wsBtn.isActive ? "󱓻" : String(wsBtn.modelData)
                  color: wsBtn.isUrgent ? "white" : barScope.fg
                  font.family: barScope.nerdFont
                  font.pixelSize: bar.fontSizeWorkspaceIcon
                  font.bold: wsBtn.isActive ? false : true
                }
                MouseArea {
                  id: wsMouse
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  anchors.fill: parent
                  onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + String(wsBtn.modelData) + "\" })"])
                }
              }
            }
            Repeater {
              model: Hyprland.workspaces.values.filter(w => w.name.startsWith("special:") && w.name !== "special:minimized" && w.name !== "special:hidden")
              Rectangle {
                required property var modelData
                property bool isActive: modelData.focused || modelData.active
                property bool isUrgent: modelData.urgent
                width: isUrgent ? bar.workspaceUrgentWidth : Math.max(bar.pWorkspacesBtnPad*2+10, sLabel.implicitWidth + bar.pWorkspacesBtnPad*2)
                height: bar.implicitHeight - 4
                radius: isUrgent ? bar.workspaceUrgentRadius : 4
                color: {
                  if (isUrgent) return barScope.urgent
                  if (sMouse.containsMouse) return Qt.lighter(barScope.bg, 1.8)
                  return "transparent"
                }
                border.color: sMouse.containsMouse && !isActive ? Theme.border : "transparent"
                border.width: sMouse.containsMouse && !isActive ? 1 : 0
                Text {
                  id: sLabel
                  anchors.centerIn: parent
                  text: "󰫈"
                  color: parent.isUrgent ? "white" : barScope.fg
                  font.family: barScope.nerdFont
                  font.pixelSize: bar.fontSizeWorkspaceIcon
                }
                MouseArea {
                  id: sMouse
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  anchors.fill: parent; onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + modelData.name + "\" })"]) }
                }
              }
            }
            Item { width: bar.mWorkspacesOuterPad; height: 1 }

            Item { width: bar.submapName !== "" ? bar.mSubmapPad : 0; height: 1 }
            Rectangle {
              visible: bar.submapName !== ""
              width: submapText.implicitWidth + bar.pSubmapInnerPad*2
              height: bar.implicitHeight - 4
              color: barScope.fg
              anchors.verticalCenter: parent.verticalCenter
              radius: 4
              Text {
                id: submapText
                anchors.centerIn: parent
                text: bar.submapName
                color: barScope.bg
                font.family: barScope.monoFont
                font.pixelSize: bar.fontSizeText
                font.bold: true
                bottomPadding: 2
              }
            }
            Item { width: bar.submapName !== "" ? bar.mSubmapPad : 0; height: 1 }

            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              Item { width: bar.mWindowPad; height: 1 }
              Rectangle {
                property var screenToplevel: {
                  bar._hyprTick
                  const mon = Hyprland.monitorFor(bar.screen)
                  const ws = mon ? mon.activeWorkspace : null
                  if (!ws) return null
                  const toplevels = ws.toplevels.values
                  for (let i = 0; i < toplevels.length; i++) {
                    const t = toplevels[i]
                    if (t.activated) return t
                  }
                  return toplevels.length > 0 ? toplevels[0] : null
                }
                width: Math.min(windowTitle.implicitWidth, bar.windowTitleMaxWidth)
                height: bar.implicitHeight
                color: "transparent"
                Text {
                  id: windowTitle
                  anchors.centerIn: parent
                  property string rawClass: {
                    const t = parent.screenToplevel
                    if (!t) return ""
                    const obj = t.lastIpcObject || {}
                    return obj.class || obj.initialClass || (t.wayland ? t.wayland.appId : "") || ""
                  }
                  text: {
                    let c = rawClass
                    if (c === "") return "Desktop"
                    if (bar.windowTitleRewrites[c]) return bar.windowTitleRewrites[c]
                    return c
                  }
                  color: barScope.fg
                  font.family: barScope.monoFont
                  font.pixelSize: bar.fontSizeText
                  font.bold: true
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, bar.windowTitleMaxWidth)
                }
                MouseArea {
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                  onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                      const t = parent.screenToplevel
                      if (t) Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close({ address = \"" + t.address + "\" })"])
                      else Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close()"])
                    }
                  }
                }
              }
              Item { width: bar.mWindowPad; height: 1 }
            }
          }

          // CENTER
          Row {
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              Rectangle {
                height: bar.implicitHeight
                width: clockText.implicitWidth
                color: "transparent"
                Text {
                  id: clockText
                  anchors.centerIn: parent
                  color: barScope.fg
                  font.family: barScope.monoFont
                  font.pixelSize: bar.fontSizeText
                  font.bold: true
                  text: {
                    const d = sysClock.date
                    if (bar.clockAlt) return Qt.formatDateTime(d, "hh:mm:ss")
                    return Qt.formatDateTime(d, "hh:mm AP")
                  }
                }
                MouseArea {
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  anchors.fill: parent
                  onClicked: bar.clockAlt = !bar.clockAlt
                }
              }
            }

            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              Item { width: bar.mSepPad; height: 1 }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "❯"
                color: barScope.fg
                font.family: barScope.monoFont
                font.pixelSize: bar.fontSizeText
                font.bold: true
              }
              Item { width: bar.mSepPad; height: 1 }
            }

            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              Rectangle {
                height: bar.implicitHeight
                width: bilalText.implicitWidth
                color: "transparent"
                Text {
                  id: bilalText
                  anchors.centerIn: parent
                  text: bar.bilalText
                  color: barScope.fg
                  font.family: barScope.monoFont
                  font.pixelSize: bar.fontSizeText
                  font.bold: true
                }
                MouseArea {
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  anchors.fill: parent
                  onClicked: bilalNotifyProc.running = true
                }
              }
            }
          }

          // RIGHT
          Row {
            spacing: 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              Item { width: bar.mBandwidthPad; height: 1 }
              Rectangle {
                height: bar.implicitHeight
                width: bwRow.implicitWidth
                color: "transparent"
                Row {
                  id: bwRow
                  anchors.centerIn: parent
                  spacing: bar.pBandwidthIconGap
                  Text {
                    text: "⇣⇡"
                    color: barScope.fg
                    font.family: barScope.monoFont
                    font.pixelSize: bar.fontSizeText
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bar.bandwidthIconVerticalOffset
                  }
                  Row {
                    spacing: bar.pBandwidthUnitGap
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bar.bandwidthTextVerticalOffset
                    Row {
                      spacing: 0
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        text: {
                          const v = bar.bwValue
                          if (!/[1-9]/.test(v)) return ""
                          let n = 0
                          while (n < v.length && v[n] === "0") n++
                          return v.slice(0, n)
                        }
                        color: barScope.fg
                        opacity: 0.5
                        font.family: barScope.monoFont
                        font.pixelSize: bar.fontSizeText
                        font.bold: true
                      }
                      Text {
                        text: {
                          const v = bar.bwValue
                          if (!/[1-9]/.test(v)) return v
                          let n = 0
                          while (n < v.length && v[n] === "0") n++
                          return v.slice(n)
                        }
                        color: barScope.fg
                        opacity: 0.7
                        font.family: barScope.monoFont
                        font.pixelSize: bar.fontSizeText
                        font.bold: true
                      }
                    }
                    Text {
                      text: bar.bwUnit
                      color: barScope.fg
                      opacity: 0.7
                      font.family: barScope.monoFont
                      font.pixelSize: bar.fontSizeText
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                }
              }
              Item { width: bar.mBandwidthPad; height: 1 }
            }

            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              visible: bar.kbLayoutReady
              Item { width: bar.mLanguagePad; height: 1 }
              Rectangle {
                height: bar.implicitHeight
                width: langText.implicitWidth + 18
                color: "transparent"
                Row {
                  anchors.centerIn: parent
                  spacing: bar.pLanguageIconGap
                  Text { 
                    text: "󰌌"
                    color: barScope.fg
                    font.family: barScope.nerdFont
                    font.pixelSize: bar.fontSizeLanguageIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bar.languageIconVerticalOffset
                  }
                  Text {
                    id: langText
                    text: bar.kbLayout
                    color: barScope.fg
                    opacity: 0.7
                    font.family: barScope.monoFont
                    font.pixelSize: bar.fontSizeText - 1.5
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bar.languageTextVerticalOffset
                  }
                }
                MouseArea {
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  anchors.fill: parent
                  onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
                }
              }
              Item { width: bar.mLanguagePad; height: 1 }
            }

            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              Item { width: bar.mCpuPad; height: 1 }
              Rectangle {
                height: bar.implicitHeight
                width: cpuRow.implicitWidth
                color: "transparent"
                Row {
                  id: cpuRow
                  anchors.centerIn: parent
                  spacing: bar.pCpuIconGap
                  Text { text: ""
                  color: barScope.fg
                  font.family: barScope.nerdFont
                  font.pixelSize: bar.fontSizeCpuIcon
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: bar.cpuIconVerticalOffset
                }
                Text {
                  text: (bar.cpuUsage < 10 ? "0" : "") + bar.cpuUsage + "%"
                  color: barScope.fg
                  opacity: 0.7
                  font.family: barScope.monoFont
                  font.pixelSize: bar.fontSizeText
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: bar.cpuTextVerticalOffset
                }
              }
              MouseArea {
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                anchors.fill: parent; onClicked: Quickshell.execDetached(bar.systemMonitorCmd)
              }
            }
            Item { width: bar.mCpuPad; height: 1 }
          }

          Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            Item { width: bar.mVolumePad; height: 1 }
            Rectangle {
              id: volRect
              height: bar.implicitHeight
              width: volRow.implicitWidth
              color: "transparent"
              opacity: {
                const sink = Pipewire.defaultAudioSink
                if (!sink || !sink.audio) return 1
                return sink.audio.muted ? 0.5 : 1
              }
              property var sink: Pipewire.defaultAudioSink
              property bool isMuted: sink && sink.audio ? sink.audio.muted : false
              property int volPct: {
                const s = volRect.sink
                if (!s || !s.audio) return 0
                return Math.round(s.audio.volume * 100)
              }
              Row {
                id: volRow
                anchors.centerIn: parent
                spacing: bar.pVolumeIconGap
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: bar.volumeIconVerticalOffset
                  color: barScope.fg
                  font.family: barScope.nerdFont
                  font.pixelSize: 15
                  text: {
                    if (volRect.isMuted) return ""
                    const v = volRect.volPct
                    if (v === 0) return ""
                    if (v < 50) return ""
                    return ""
                  }
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: bar.volumeTextVerticalOffset
                  text: (volRect.volPct < 10 ? "0" : "") + volRect.volPct + "%"
                  color: barScope.fg
                  opacity: 0.7
                  font.family: barScope.monoFont
                  font.pixelSize: 12
                  font.bold: true
                }
              }
              MouseArea {
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                  if (mouse.button === Qt.LeftButton) {
                    const s = Pipewire.defaultAudioSink
                    if (s && s.audio) s.audio.muted = !s.audio.muted
                  } else if (mouse.button === Qt.RightButton) {
                    Quickshell.execDetached(["pavucontrol"])
                  }
                }
                onWheel: wheel => {
                  const s = Pipewire.defaultAudioSink
                  if (!s || !s.audio) return
                  const step = 0.05
                  let v = s.audio.volume + (wheel.angleDelta.y > 0 ? step : -step)
                  v = Math.max(0, Math.min(1.5, v))
                  s.audio.volume = v
                }
              }
            }
            Item { width: bar.mVolumePad; height: 1 }
          }

          Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            visible: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
            Item { width: bar.mBatteryPad; height: 1 }
            Rectangle {
              id: batRect
              height: bar.implicitHeight
              width: batRow.implicitWidth
              color: "transparent"
              property var dev: UPower.displayDevice
              property int pct: dev ? Math.round(dev.percentage * 100) : 0
              property bool charging: dev ? dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge : false
              Row {
                id: batRow
                anchors.centerIn: parent
                spacing: bar.pBatteryIconGap
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: bar.batteryIconVerticalOffset
                  font.family: barScope.nerdFont
                  font.pixelSize: 12
                  color: {
                    if (batRect.charging) return barScope.fg
                    if (batRect.pct <= 10) return barScope.urgent
                    return barScope.fg
                  }
                  text: {
                    if (batRect.charging) {
                      let ic = ""
                      const p = batRect.pct
                      if (p < 10) ic = ""
                      else if (p < 25) ic = ""
                      else if (p < 40) ic = ""
                      else if (p < 55) ic = ""
                      else if (p < 70) ic = ""
                      else if (p < 85) ic = ""
                      else ic = ""
                      return "󱐋  " + ic
                    }
                    const p = batRect.pct
                    const idx = Math.min(8, Math.floor(p / 12.5))
                    const icons = ["","","","","","","","",""]
                    return icons[idx]
                  }
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: bar.batteryTextVerticalOffset
                  font.family: barScope.monoFont
                  font.pixelSize: 12
                  font.bold: true
                  color: {
                    if (batRect.pct <= 10) return barScope.urgent
                    return barScope.fg
                  }
                  opacity: 0.7
                  text: (batRect.pct < 10 ? "0" : "") + batRect.pct + "%"
                }
              }
            }
            Item { width: bar.mBatteryPad; height: 1 }
          }

          Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: bar.networkContainerVerticalOffset
            opacity: bar.wifiSignal < 0 ? 0.5 : 1
            Item { width: bar.mNetworkPad; height: 1 }
            Rectangle {
              height: bar.implicitHeight
              width: netRow.implicitWidth
              color: "transparent"
              Row {
                id: netRow
                anchors.centerIn: parent
                spacing: bar.pNetworkIconGap
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: bar.networkIconVerticalOffset
                  font.family: barScope.nerdFont
                  font.pixelSize: bar.fontSizeNetworkIcon
                  color: barScope.fg
                  text: {
                    if (bar.wifiSignal < 0) return "󰤮"
                    const s = bar.wifiSignal
                    if (s < 10) return "󰤯"
                    if (s < 30) return "󰤟"
                    if (s < 50) return "󰤢"
                    if (s < 70) return "󰤥"
                    return "󰤨"
                  }
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: bar.networkTextVerticalOffset
                  font.family: barScope.monoFont
                  font.pixelSize: bar.fontSizeText
                  font.bold: true
                  color: barScope.fg
                  opacity: 0.7
                  text: {
                    if (bar.wifiSignal < 0) return "00%"
                    const v = bar.wifiSignal
                    return (v < 10 ? "0" : "") + v + "%"
                  }
                }
              }
            }
            Item { width: bar.mNetworkPad; height: 1 }
          }

          Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            visible: SystemTray.items.values.length > 0
            Item { width: bar.mTrayOuterPad; height: 1 }
            Rectangle {
              height: bar.implicitHeight
              width: trayRow.implicitWidth
              color: "transparent"
              Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: bar.pTrayIconGap
                Repeater {
                  model: SystemTray.items
                  IconImage {
                    required property SystemTrayItem modelData
                    visible: !modelData.onlyMenu
                    width: visible ? bar.trayIconSize : 0; height: bar.trayIconSize
                    anchors.verticalCenter: parent.verticalCenter
                    source: {
                      if (modelData.id === "TelegramDesktop") return Quickshell.iconPath("telegram", true);
                      return modelData.icon;
                    }
                    implicitSize: bar.trayIconSize
                    MouseArea {
                      cursorShape: Qt.PointingHandCursor
                      hoverEnabled: true
                      anchors.fill: parent
                      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                      onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) modelData.activate()
                        else if (mouse.button === Qt.RightButton) modelData.secondaryActivate()
                        else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
                      }
                    }
                  }
                }
              }
            }
            Item { width: bar.mTrayOuterPad; height: 1 }
          }

          Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            Item { width: bar.mPowermenuLeft; height: 1 }
            Rectangle {
              width: powerText.implicitWidth + bar.pPowermenuRight
              height: bar.implicitHeight
              color: "transparent"
              Text {
                id: powerText
                anchors.right: parent.right
                anchors.rightMargin: bar.pPowermenuRight
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: barScope.fg
                font.family: barScope.nerdFont
                font.pixelSize: bar.fontSizePowermenuIcon
              }
              MouseArea {
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                anchors.fill: parent
                onClicked: barScope.powermenuRequested()
              }
            }
          }
        }
      }
    }
  }
}
