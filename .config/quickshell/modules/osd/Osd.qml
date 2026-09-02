pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "../common"

Scope {
  id: osdRoot

  property bool opened: false
  property string icon: ""
  property string message: ""
  property int value: 0
  property int maxValue: 100
  property bool hasProgress: true
  property int duration: 1400
  property string iconKey: ""
  property bool mutedTint: false // for volume muted tint

  PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }

  // ── Icon resolution with steps ─────────────────────────────────────
  function iconFor(name, percent) {
    const n = String(name || "").toLowerCase()
    if (n === "volume-muted" || n === "muted" || n === "mute") return ""
    if (n === "caps-on" || n === "capslock-on" || n === "caps") return "󰪛"
    if (n === "caps-off" || n === "capslock-off") return "󰪛"
    if (n === "num-on" || n === "numlock-on" || n === "num") return "󰎣"
    if (n === "num-off" || n === "numlock-off") return "󰎣"
    if (n === "volume-low") return ""
    if (n === "volume-medium") return ""
    if (n === "volume-high" || n === "volume") return ""
    if (n === "microphone-muted" || n === "mic-muted" || n === "mic-off") return "󰍭"
    if (n === "microphone" || n === "mic") return "󰍬"
    if (n === "keyboard") return "󰌌"
    if (n === "brightness" || n === "display") {
      if (percent <= 33) return "󰃞"
      if (percent <= 66) return "󰃟"
      return "󰃠"
    }
    if (n === "brightness-low") return "󰃞"
    if (n === "brightness-medium") return "󰃟"
    if (n === "brightness-high") return "󰃠"
    if (n.length > 0) return name
    if (percent <= 0) return ""
    if (percent <= 33) return ""
    if (percent <= 66) return ""
    return ""
  }

  // ── capslock / numlock monitor ─────────────────────────────────────
  property bool capsOn: false
  property bool numOn: false
  property bool _capsInit: false
  property bool _numInit: false
  Process {
    id: capsProc
    command: ["sh", "-c", "c=$(cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | head -n1); if [ -z \"$c\" ]; then xset q 2>/dev/null | grep -q 'Caps Lock:\\s*on' && c=1 || c=0; fi; echo $c"]
    stdout: SplitParser {
      onRead: data => {
        const v = data.trim() === "1"
        if (!osdRoot._capsInit) { osdRoot.capsOn = v; osdRoot._capsInit = true; return }
        if (v !== osdRoot.capsOn) {
          osdRoot.capsOn = v
          osdRoot.showCaps(v)
        }
      }
    }
  }
  Process {
    id: numProc
    command: ["sh", "-c", "c=$(cat /sys/class/leds/input*::numlock/brightness 2>/dev/null | head -n1); if [ -z \"$c\" ]; then xset q 2>/dev/null | grep -q 'Num Lock:\\s*on' && c=1 || c=0; fi; echo $c"]
    stdout: SplitParser {
      onRead: data => {
        const v = data.trim() === "1"
        if (!osdRoot._numInit) { osdRoot.numOn = v; osdRoot._numInit = true; return }
        if (v !== osdRoot.numOn) {
          osdRoot.numOn = v
          osdRoot.showNum(v)
        }
      }
    }
  }
  Timer { interval: 350; running: true; repeat: true; triggeredOnStart: true; onTriggered: { capsProc.running = true; numProc.running = true } }

  function showCaps(on) {
    // tint indicates state like volume/mic — no :On/Off text
    show(on ? "caps-on" : "caps-off", "Caps Lock", "", "", "", "1300")
    // override tint to show active vs inactive
    mutedTint = !on
  }
  function showNum(on) {
    show(on ? "num-on" : "num-off", "Num Lock", "", "", "", "1300")
    mutedTint = !on
  }

  // ── Show / hide ────────────────────────────────────────────────────
  function show(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration) {
    let maxV = Math.max(1, parseInt(rawMax || "100", 10))
    if (isNaN(maxV)) maxV = 100
    let parsed = parseInt(rawValue || "0", 10)
    const hasProg = rawValue !== "" && !isNaN(parsed) && (rawMessage === "" || rawMessage === undefined)
    let val = hasProg ? Math.max(0, Math.min(maxV, parsed)) : 0
    let pct = hasProg ? Math.round(val * 100 / maxV) : -1
    let dur = parseInt(rawDuration || "1400", 10)
    if (isNaN(dur)) dur = 1400

    iconKey = String(iconName || "").toLowerCase()
    maxValue = maxV
    hasProgress = hasProg
    value = val
    mutedTint = (iconKey === "volume-muted" || iconKey === "mic-muted" || iconKey === "microphone-muted")
    let displayPct = hasProg ? (maxV === 150 ? val : pct) : -1
    let isCaps = iconKey.includes("caps")
    let isNum = iconKey.includes("num")
    if (isCaps || isNum) {
      message = String(rawMessage || "")
      hasProgress = false
      mutedTint = false
    } else if (iconKey === "volume-muted" || iconKey === "mic-muted" || iconKey === "microphone-muted") {
      hasProgress = true
      message = displayPct + "%"
    } else {
      message = String(rawMessage || (hasProg ? (rawProgressText || displayPct + "%") : ""))
    }
    let stepPct = hasProg ? (maxV === 150 ? Math.round(val * 100 / 150) : pct) : -1
    if (iconKey === "brightness" || iconKey === "display") stepPct = pct
    if (iconKey === "volume" || iconKey === "volume-muted") stepPct = Math.round(val * 100 / 150)
    if (iconKey === "mic" || iconKey === "mic-muted" || iconKey === "microphone" || iconKey === "microphone-muted") stepPct = pct
    icon = iconFor(iconName, isCaps || isNum ? -1 : stepPct)
    duration = Math.max(0, dur)
    opened = true
    if (duration > 0) hideTimer.restart()
    else hideTimer.stop()
  }

  function open(payloadJson) {
    try {
      const p = JSON.parse(payloadJson || "{}")
      show(p.icon || "", p.message || "", p.value === undefined ? "" : String(p.value), p.max === undefined ? "100" : String(p.max), p.progressText || "", p.duration === undefined ? "1400" : String(p.duration))
    } catch (e) { console.warn("OSD open parse failed:", e) }
  }
  function close() { opened = false }

  // ── Auto-show on volume/mute and mic ───────────────────────────────
  property int _lastVol: -1
  property bool _lastMuted: false
  property bool _initialized: false
  property int _lastMicVol: -1
  property bool _lastMicMuted: false
  property bool _micInitialized: false

  Connections {
    target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    ignoreUnknownSignals: true
    function onVolumeChanged() { osdRoot.volumeChanged() }
    function onMutedChanged() { osdRoot.volumeChanged() }
  }
  Connections {
    target: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
    ignoreUnknownSignals: true
    function onVolumeChanged() { osdRoot.micChanged() }
    function onMutedChanged() { osdRoot.micChanged() }
  }

  function volumeChanged() {
    const sink = Pipewire.defaultAudioSink
    if (!sink || !sink.audio) return
    const vol = Math.round(sink.audio.volume * 100)
    const muted = sink.audio.muted
    if (!_initialized) { _lastVol = vol; _lastMuted = muted; _initialized = true; return }
    if (vol !== _lastVol || muted !== _lastMuted) {
      _lastVol = vol; _lastMuted = muted
      if (muted) show("volume-muted", "", String(Math.min(vol,150)), "150", "", "1400")
      else show("volume", "", String(Math.min(vol,150)), "150", "", "1400")
    }
  }
  function micChanged() {
    const src = Pipewire.defaultAudioSource
    if (!src || !src.audio) return
    const vol = Math.round(src.audio.volume * 100)
    const muted = src.audio.muted
    if (!_micInitialized) { _lastMicVol = vol; _lastMicMuted = muted; _micInitialized = true; return }
    if (vol !== _lastMicVol || muted !== _lastMicMuted) {
      _lastMicVol = vol; _lastMicMuted = muted
      if (muted) show("mic-muted", "", String(vol), "100", "", "1400")
      else show("mic", "", String(vol), "100", "", "1400")
    }
  }
  function showBrightness(pct) {
    const v = Math.max(0, Math.min(100, parseInt(pct,10)||0))
    show("brightness", "", String(v), "100", "", "1400")
  }

  Timer { id: hideTimer; interval: osdRoot.duration; onTriggered: osdRoot.opened = false }

  IpcHandler {
    target: "osd"
    function show(payloadJson: string): string { osdRoot.open(payloadJson); return "ok" }
    function close(): string { osdRoot.close(); return "ok" }
    function state(): string { return osdRoot.opened?"open":"closed" }
    function ping(): string { return "ok" }
    function volume(level: string): string { osdRoot.show("volume","",level,"150","","1400"); return "ok" }
    function brightness(level: string): string { osdRoot.showBrightness(level); return "ok" }
    function muted(): string { osdRoot.show("volume-muted","",String(_lastVol>=0?_lastVol:0),"150","","1400"); return "ok" }
    function mic(level: string): string { osdRoot.show("mic","",level,"100","","1400"); return "ok" }
    function micmuted(): string { osdRoot.show("mic-muted","",String(_lastMicVol>=0?_lastMicVol:0),"100","","1400"); return "ok" }
    function caps(state: string): string {
      const on = String(state||"").toLowerCase()
      const isOn = on==="on"||on==="1"||on==="true"
      osdRoot.showCaps(isOn); return "ok"
    }
    function num(state: string): string {
      const on = String(state||"").toLowerCase()
      const isOn = on==="on"||on==="1"||on==="true"
      osdRoot.showNum(isOn); return "ok"
    }
  }

  // ── Visual — fixed percent width, fg bar color, over-100 segment ───
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      visible: osdRoot.opened
      color: "transparent"
      WlrLayershell.namespace: "quickshell-osd"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      anchors { top:true; bottom:true; left:true; right:true }
      mask: Region {}

      Rectangle {
        id: card
        width: osdRoot.hasProgress ? Math.max(340, row.implicitWidth + 32) : Math.max(260, row.implicitWidth + 32)
        height: 72
        radius: Theme.radiusLg
        color: Qt.alpha(Theme.bg, 0.867)
        border.color: Qt.alpha(Theme.border, 0.75)
        border.width: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        opacity: osdRoot.opened?1:0
        Behavior on opacity { NumberAnimation { duration:140; easing.type:Easing.OutCubic } }

        Row {
          id: row
          anchors.centerIn: parent
          spacing: 16

          Text {
            id: iconText
            text: osdRoot.icon
            color: osdRoot.mutedTint ? Qt.alpha(Theme.fg, 0.45) : Theme.fg
            font.family: Theme.nerdFont
            font.pixelSize: 28
            width: 36
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
          }

          Rectangle {
            visible: osdRoot.hasProgress
            width: 160
            height: 6
            radius: 3
            color: Qt.alpha(Theme.fg, 0.22)
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            Rectangle {
              height: parent.height
              width: {
                if (!osdRoot.hasProgress) return 0
                if (osdRoot.maxValue === 150) {
                  const pct100 = 100/150 * parent.width
                  const filled = parent.width * (osdRoot.value / osdRoot.maxValue)
                  return Math.min(filled, pct100)
                }
                return parent.width * (osdRoot.value / osdRoot.maxValue)
              }
              radius: 3
              color: osdRoot.mutedTint ? Qt.alpha(Theme.fg, 0.45) : Theme.fg
              Behavior on width { enabled: osdRoot.opened; NumberAnimation { duration:140; easing.type:Easing.OutCubic } }
            }
            Rectangle {
              visible: osdRoot.hasProgress && osdRoot.maxValue===150 && osdRoot.value>100
              height: parent.height
              width: parent.width * (Math.max(0, osdRoot.value-100) / osdRoot.maxValue)
              x: parent.width * (100 / 150)
              radius: 3
              color: osdRoot.mutedTint ? Qt.alpha(Theme.fg, 0.25) : Theme.urgent
              Behavior on width { enabled: osdRoot.opened; NumberAnimation { duration:140; easing.type:Easing.OutCubic } }
            }
          }

          // message: fixed width for progress (percent) — consistent for muted/normal
          Text {
            visible: osdRoot.message !== "" && osdRoot.hasProgress
            text: osdRoot.message
            color: osdRoot.mutedTint ? Qt.alpha(Theme.fg, 0.60) : Theme.fg
            font.family: Theme.monoFont
            font.pixelSize: 15
            font.bold: true
            width: 36
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            visible: osdRoot.message !== "" && !osdRoot.hasProgress
            text: osdRoot.message
            color: Theme.fg
            font.family: Theme.monoFont
            font.pixelSize: 13
            font.bold: true
            // dynamic width, not fixed, to avoid cut
            horizontalAlignment: Text.AlignLeft
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
