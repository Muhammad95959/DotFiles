pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ShellRoot {
  id: root

  // ── Colors ───────────────────────────────────────────────────────────
  readonly property color bg: "#1a1b26"
  readonly property color fg: "#e1e2e7"
  readonly property color muted: "#e1e2e7aa"
  readonly property color urgent: "#e60053"
  readonly property color warning: "#ff9e64"

  // ── Fonts ────────────────────────────────────────────────────────────
  readonly property string nerdFont: "Symbols Nerd Font"
  readonly property string monoFont: "RobotoMono Nerd Font"

  // ── Audio Binding ────────────────────────────────────────────────────
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

      // ── Bar Geometry & Shadow ──────────────────────────────────────
      property int barHeight: 24
      property int barExclusiveZone: 24
      property color shadowColor: "#80000000"
      property real shadowBlur: 0.8
      property int shadowVerticalOffset: 3
      property int shadowHorizontalOffset: 0

      // ── Spacing (Margins & Padding) ──────────────────────────────
      // m* = margin (outside the clickable hitbox)
      // p* = padding (inside the clickable hitbox)
      property int pLauncherLeft: 8
      property int mLauncherRight: 8
      property int mWorkspacesOuterPad: 8
      property int pWorkspacesBtnPad: 2
      property int mWorkspacesGap: 8
      property int mSubmapPad: 6
      property int pSubmapInnerPad: 8
      property int mWindowPad: 8
      property int mClockPad: 5
      property int mSepPad: 8
      property int mBilalPad: 5
      property int mBandwidthPad: 5
      property int pBandwidthUnitGap: 1
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

      // ── Font Sizes ────────────────────────────────────────────────
      property int fontSizeText: 12
      property int fontSizeLauncherIcon: 14
      property int fontSizeWorkspaceIcon: 12
      property int fontSizePowermenuIcon: 14
      property int fontSizeLanguageIcon: 14
      property int fontSizeCpuIcon: 15
      property int fontSizeVolumeIcon: 15
      property int fontSizeBatteryIcon: 12
      property int fontSizeNetworkIcon: 13
      property int trayIconSize: 14

      // ── Thresholds ────────────────────────────────────────────────
      property int batteryUrgentPct: 10
      property int batteryWarningPct: 20

      // ── Update Intervals (ms) ────────────────────────────────────
      property int bandwidthIntervalMs: 1000
      property int cpuIntervalMs: 2000
      property int networkIntervalMs: 10000
      property int bilalIntervalMs: 30000
      property int bilalNotifyDurationMs: 30000

      // ── External Commands ────────────────────────────────────────
      property var launcherCmd: ["nwg-drawer"]
      property var screenshotCmd: ["flameshot", "gui"]
      property var systemMonitorCmd: ["kitty", "-e", "--hold", "btm"]
      property var volumeMixerCmd: ["pavucontrol"]
      property var powermenuCmd: ["wlogout", "-b", "5"]
      property string bilalScriptPath: "~/Scripts/bilal.sh"

      // ── Window Title ──────────────────────────────────────────────
      property int windowTitleMaxWidth: 260
      property var windowTitleRewrites: ({
        "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default": "whatsapp-web",
        "brave-translate.google.com.eg__-Default": "brave-translate"
      })

      // ── Workspaces ────────────────────────────────────────────────
      property var workspacePersistentIds: [1,2,3,4,5,6,7,8,9]
      property int workspaceUrgentWidth: 40
      property int workspaceUrgentRadius: 4

      // ── Runtime State ─────────────────────────────────────────────
      property string submapName: ""
      property string kbLayout: ""
      property bool kbLayoutReady: false
      property int _hyprTick: 0

      // Bar background + drop shadow
      Rectangle {
        id: barBg
        anchors.fill: parent
        color: root.bg
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: bar.shadowColor
          shadowBlur: bar.shadowBlur
          shadowVerticalOffset: bar.shadowVerticalOffset
          shadowHorizontalOffset: bar.shadowHorizontalOffset
        }
      }

      // ── Submap & Keyboard Layout Tracking ─────────────────────────
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
        id: kbInit
        command: ["sh", "-c", "hyprctl -j devices | python3 -c \"import json,sys; d=json.load(sys.stdin); k=[k for k in d.get('keyboards',[]) if k.get('name')=='kanata'] ; layout=(k[0].get('layout','') if k else '').split(','); idx=k[0].get('active_layout_index',0) if k else 0; print(layout[idx] if idx < len(layout) and layout[idx] else k[0].get('active_keymap','') if k else '')\""]
        running: true
        stdout: SplitParser { onRead: function(data) { let v=data.trim().toLowerCase(); if (v === "us") v = "EN"; else if (v === "eg") v = "AR"; else if (v.length > 3) v = bar.shortForLayout(v); else v = v.toUpperCase(); bar.kbLayout = v; bar.kbLayoutReady = true } }
      }

      // ── Bandwidth Monitor ─────────────────────────────────────────
      property string bwText: "000.0" + " ".repeat(pBandwidthUnitGap) + "KB"
      onPBandwidthUnitGapChanged: {
        const parts = bwText.trim().split(/\s+/)
        if (parts.length >= 2) bwText = parts[0] + " ".repeat(pBandwidthUnitGap) + parts[1]
      }
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
              function fmt(b) {
                let num, unit
                if (b < 1024*1024) { num = (b/1024).toFixed(1); unit = "KB" }
                else if (b < 1024*1024*1024) { num = (b/(1024*1024)).toFixed(1); unit = "MB" }
                else { num = (b/(1024*1024*1024)).toFixed(1); unit = "GB" }
                return num.padStart(5, "0") + " ".repeat(bar.pBandwidthUnitGap) + unit
              }
              bar.bwText = fmt(total)
            }
            bar._prevRx = rx; bar._prevTx = tx
          }
        }
      }

      // ── CPU Monitor ───────────────────────────────────────────────
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

      // ── Network (WiFi) Monitor ────────────────────────────────────
      property int wifiSignal: -1
      property string wifiEssid: ""
      property string wifiFreq: ""
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
                bar.wifiFreq = segs.slice(2).join(":").trim() || ""
                bar.wifiConnected = true
              } else {
                bar.wifiEssid = ""; bar.wifiFreq = ""; bar.wifiConnected = false
              }
              const state = (parts[2] || "").trim().split("\n")[0] || ""
              bar.wifiConnected = state === "connected" && bar.wifiSignal >= 0
              if (!bar.wifiConnected && state !== "connected") bar.wifiSignal = -1
              bar._netAccum = ""
            }
          }
        }
      }

      // ── Prayer Time (Bilal) ───────────────────────────────────────
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

      // ── Clock ─────────────────────────────────────────────────────
      property bool clockAlt: false
      SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
      }

      // ── Layout ────────────────────────────────────────────────────
      Item {
        anchors.fill: parent

        // LEFT side
        Row {
          id: leftRow
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
                color: root.fg
                font.family: root.nerdFont
                font.pixelSize: bar.fontSizeLauncherIcon
              }
              MouseArea {
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                anchors.fill: parent
                onClicked: mouse => {
                  if (mouse.button === Qt.LeftButton) Quickshell.execDetached(bar.launcherCmd)
                  else if (mouse.button === Qt.RightButton) Quickshell.execDetached(bar.screenshotCmd)
                }
                acceptedButtons: Qt.LeftButton | Qt.RightButton
              }
            }
            Item { width: bar.mLauncherRight; height: 1 }
          }

          // Workspaces
          Item { width: bar.mWorkspacesOuterPad; height: 1 }
          Row {
            id: wsRow
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
                radius: isUrgent ? bar.workspaceUrgentRadius : 0
                opacity: (!isActive && isEmpty) ? 0.5 : 1
                color: {
                  if (isUrgent) return root.urgent
                  if (wsMouse.containsMouse) return Qt.lighter(root.bg, 1.8)
                  return "transparent"
                }
                border.color: wsMouse.containsMouse && !isActive ? root.muted : "transparent"
                border.width: wsMouse.containsMouse && !isActive ? 1 : 0

                Text {
                  id: wsLabel
                  anchors.centerIn: parent
                  text: wsBtn.isActive ? "󱓻" : String(wsBtn.modelData)
                  color: wsBtn.isUrgent ? "white" : root.fg
                  font.family: root.nerdFont
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
            // Special (scratchpad-style) workspaces
            Repeater {
              model: Hyprland.workspaces.values.filter(w => w.name.startsWith("special:") && w.name !== "special:minimized" && w.name !== "special:hidden")
              Rectangle {
                required property var modelData
                property bool isActive: modelData.focused || modelData.active
                property bool isUrgent: modelData.urgent
                width: isUrgent ? bar.workspaceUrgentWidth : Math.max(bar.pWorkspacesBtnPad*2+10, sLabel.implicitWidth + bar.pWorkspacesBtnPad*2)
                height: bar.implicitHeight - 4
                radius: isUrgent ? bar.workspaceUrgentRadius : 0
                color: {
                  if (isUrgent) return root.urgent
                  if (sMouse.containsMouse) return Qt.lighter(root.bg, 1.8)
                  return "transparent"
                }
                border.color: sMouse.containsMouse && !isActive ? root.muted : "transparent"
                border.width: sMouse.containsMouse && !isActive ? 1 : 0
                Text {
                  id: sLabel
                  anchors.centerIn: parent
                  text: "󰫈"
                  color: parent.isUrgent ? "white" : root.fg
                  font.family: root.nerdFont
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

            // Submap indicator pill
            Item { width: bar.submapName !== "" ? bar.mSubmapPad : 0; height: 1 }
            Rectangle {
              visible: bar.submapName !== ""
              width: submapText.implicitWidth + bar.pSubmapInnerPad*2
              height: bar.implicitHeight - 4
              color: root.urgent
              anchors.verticalCenter: parent.verticalCenter
              radius: 4
              Text {
                id: submapText
                anchors.centerIn: parent
                text: bar.submapName
                color: "white"
                font.family: root.monoFont
                font.pixelSize: bar.fontSizeText
                font.bold: true
                bottomPadding: 2
              }
            }
            Item { width: bar.submapName !== "" ? bar.mSubmapPad : 0; height: 1 }

            // Active window title
            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              Item { width: bar.mWindowPad; height: 1 }
              Rectangle {
                property var screenToplevel: {
                  bar._hyprTick
                  const all = Hyprland.toplevels.values
                  void all.length; void Hyprland.activeToplevel
                  for (let i = 0; i < all.length; i++) {
                    const t = all[i]
                    if (t.activated && t.monitor && t.monitor.name === bar.screen.name) return t
                  }
                  for (let i = 0; i < all.length; i++) {
                    const t = all[i]
                    if (t.activated && t.workspace && t.workspace.monitor && t.workspace.monitor.name === bar.screen.name) return t
                  }
                  return Hyprland.activeToplevel
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
                  color: root.fg
                  font.family: root.monoFont
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
                      if (t) Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + t.address])
                      else Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close()"])
                    }
                  }
                }
              }
              Item { width: bar.mWindowPad; height: 1 }
            }
          }

          // CENTER: clock | separator | prayer time
          Row {
            id: centerRow
            spacing: 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            // Clock
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
                  color: root.fg
                  font.family: root.monoFont
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

            // Separator
            Row {
              spacing: 0
              anchors.verticalCenter: parent.verticalCenter
              Item { width: bar.mSepPad; height: 1 }
              Text {
                id: sepText
                anchors.verticalCenter: parent.verticalCenter
                text: "❯"
                color: root.fg
                font.family: root.monoFont
                font.pixelSize: bar.fontSizeText
                font.bold: true
              }
              Item { width: bar.mSepPad; height: 1 }
            }

            // Prayer time
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
                  color: root.fg
                  font.family: root.monoFont
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

          // RIGHT side
          Row {
            id: rightRow
            spacing: 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            // Bandwidth
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
                    color: root.fg
                    font.family: root.monoFont
                    font.pixelSize: bar.fontSizeText
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: bar.bwText
                    color: root.fg
                    opacity: 0.7
                    font.family: root.monoFont
                    font.pixelSize: bar.fontSizeText
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
              Item { width: bar.mBandwidthPad; height: 1 }
            }

            // Keyboard layout
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
                    color: root.fg
                    font.family: root.nerdFont
                    font.pixelSize: bar.fontSizeLanguageIcon
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    id: langText
                    text: bar.kbLayout
                    color: root.fg
                    opacity: 0.7
                    font.family: root.monoFont
                    font.pixelSize: bar.fontSizeText - 1.5
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 0.3
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

            // CPU usage
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
                  color: root.fg
                  font.family: root.nerdFont
                  font.pixelSize: bar.fontSizeCpuIcon
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: 1 
                }
                Text {
                  text: (bar.cpuUsage < 10 ? "0" : "") + bar.cpuUsage + "%"
                  color: root.fg
                  opacity: 0.7
                  font.family: root.monoFont
                  font.pixelSize: bar.fontSizeText
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
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

          // Volume (Pipewire)
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
                  id: volIcon
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: 1
                  color: root.fg
                  font.family: root.nerdFont
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
                  text: (volRect.volPct < 10 ? "0" : "") + volRect.volPct + "%"
                  color: root.fg
                  opacity: 0.7
                  font.family: root.monoFont
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

          // Battery
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
                  anchors.verticalCenterOffset: 0.6
                  font.family: root.nerdFont
                  font.pixelSize: 12
                  color: {
                    if (batRect.charging) return root.fg
                    if (batRect.pct <= 10) return root.urgent
                    if (batRect.pct <= 20) return root.warning
                    return root.fg
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
                  font.family: root.monoFont
                  font.pixelSize: 12
                  font.bold: true
                  color: {
                    if (batRect.pct <= 10) return root.urgent
                    if (batRect.pct <= 20) return root.warning
                    return root.fg
                  }
                  opacity: 0.7
                  text: (batRect.pct < 10 ? "0" : "") + batRect.pct + "%"
                }
              }
            }
            Item { width: bar.mBatteryPad; height: 1 }
          }

          // Network signal
          Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 0.6
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
                  anchors.verticalCenterOffset: 0.5
                  font.family: root.nerdFont
                  font.pixelSize: bar.fontSizeNetworkIcon
                  color: bar.wifiSignal < 0 ? root.fg : root.fg
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
                  font.family: root.monoFont
                  font.pixelSize: bar.fontSizeText
                  font.bold: true
                  color: root.fg
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

          // System tray
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

          // Power menu
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
                color: root.fg
                font.family: root.nerdFont
                font.pixelSize: bar.fontSizePowermenuIcon
              }
              MouseArea {
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                anchors.fill: parent
                onClicked: Quickshell.execDetached(bar.powermenuCmd) 
              }
            }
          }
        }
      }
    }
  }
}
