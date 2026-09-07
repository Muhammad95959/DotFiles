pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  id: root
  property bool visible: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true; selectedIndex = -1 }
  function close() { visible = false }

  // -1 = nothing highlighted (no mouse yet / mouse on empty space)
  property int selectedIndex: -1

  // ── 9-zone snap grid on home-row keys ──────────────────────────────
  // spatial layout matches the 3x3 grid on screen:
  //   a s d
  //   f g h
  //   j k l
  readonly property var zones: [
    { key: "topleft",     label: "top left",     hint: "a", qt: Qt.Key_A, icon: "↖", col: 0, row: 0 },
    { key: "top",         label: "top",          hint: "s", qt: Qt.Key_S, icon: "↑", col: 1, row: 0 },
    { key: "topright",    label: "top right",    hint: "d", qt: Qt.Key_D, icon: "↗", col: 2, row: 0 },
    { key: "left",        label: "left",         hint: "f", qt: Qt.Key_F, icon: "←", col: 0, row: 1 },
    { key: "center",      label: "center",       hint: "g", qt: Qt.Key_G, icon: "●", col: 1, row: 1 },
    { key: "right",       label: "right",        hint: "h", qt: Qt.Key_H, icon: "→", col: 2, row: 1 },
    { key: "bottomleft",  label: "bottom left",  hint: "j", qt: Qt.Key_J, icon: "↙", col: 0, row: 2 },
    { key: "bottom",      label: "bottom",       hint: "k", qt: Qt.Key_K, icon: "↓", col: 1, row: 2 },
    { key: "bottomright", label: "bottom right", hint: "l", qt: Qt.Key_L, icon: "↘", col: 2, row: 2 }
  ]

  function zoneAt(idx) {
    if (idx < 0 || idx >= zones.length) return null
    return zones[idx]
  }

  function indexForKey(eventKey) {
    for (let i = 0; i < zones.length; i++) if (zones[i].qt === eventKey) return i
    return -1
  }

  // target zone rect (for the on-screen preview) on a screen of sw x sh
  function geomFor(idx, sw, sh) {
    const z = zoneAt(idx)
    if (!z) return { x: 0, y: 0, w: 100, h: 100 }
    const gx = 10, gt = Config.barHeight + 10, gb = 10, gap = 8
    const uw = sw - gx * 2
    const uh = sh - gt - gb
    const hw = Math.round((uw - gap) / 2)
    const hh = Math.round((uh - gap) / 2)
    const ux = gx, uy = gt
    switch (z.key) {
    case "topleft":     return { x: ux,          y: uy,          w: hw, h: hh }
    case "top":         return { x: ux,          y: uy,          w: uw, h: hh }
    case "topright":    return { x: ux + hw + 8, y: uy,          w: hw, h: hh }
    case "left":        return { x: ux,          y: uy,          w: hw, h: uh }
    case "center":      return { x: Math.round((sw - 900) / 2), y: Math.round((sh - 600) / 2), w: 0, h: 0 }
    case "right":       return { x: ux + hw + 8, y: uy,          w: hw, h: uh }
    case "bottomleft":  return { x: ux,          y: uy + hh + 8, w: hw, h: hh }
    case "bottom":      return { x: ux,          y: uy + hh + 8, w: uw, h: hh }
    case "bottomright": return { x: ux + hw + 8, y: uy + hh + 8, w: hw, h: hh }
    default:            return { x: ux,          y: uy,          w: hw, h: hh }
    }
  }

  // hint circle center for a zone on a screen of sw x sh
  function hintPos(idx, sw, sh) {
    const z = zoneAt(idx)
    if (!z) return { x: sw / 2, y: sh / 2 }
    const ex = 112
    const eyTop = Config.barHeight + 112
    const eyBot = sh - 112
    const cx = z.col === 0 ? ex : (z.col === 1 ? sw / 2 : sw - ex)
    const cy = z.row === 0 ? eyTop : (z.row === 1 ? sh / 2 : eyBot)
    return { x: cx, y: cy }
  }

  // ── move-only placement ──────────────────────────────────────────
  // Floating windows are never resized — we query the live window size
  // and only move the window so it sits in the chosen zone.
  property int pendingIdx: -1
  property real pendingSW: 0
  property real pendingSH: 0
  property string _accumWin: ""

  Process {
    id: winProc
    command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { root._accumWin = String(text || "") } }
    onExited: root.placeWindow()
  }

  function snapAt(idx, sw, sh) {
    const z = zoneAt(idx)
    if (!z) return
    if (z.key === "center") {
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.float({ action = \"on\" })"])
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.center()"])
      close()
      return
    }
    pendingIdx = idx
    pendingSW = sw
    pendingSH = sh
    _accumWin = ""
    winProc.running = true
  }

  function placeWindow() {
    try {
      const info = JSON.parse(_accumWin || "{}")
      if (!info.address) { close(); return }
      const z = zoneAt(pendingIdx)
      if (!z) { close(); return }
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.float({ action = \"on\" })"])
      if (info.floating) {
        // already floating: move only, never touch its size
        const sz = info.size || [800, 450]
        const p = anchorFor(z.key, sz[0], sz[1], pendingSW, pendingSH)
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ x = " + Math.round(p.x) + ", y = " + Math.round(p.y) + " })"])
      } else {
        // tiled: true snap — resize to the zone and move it there
        const g = geomFor(pendingIdx, pendingSW, pendingSH)
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.resize({ x = " + Math.round(g.w) + ", y = " + Math.round(g.h) + " })"])
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ x = " + Math.round(g.x) + ", y = " + Math.round(g.y) + " })"])
      }
    } catch (e) { console.warn("corners place fail", e) }
    close()
  }

  // top-left corner where a w×h window must go to sit in `key`,
  // clamped so it always stays fully on screen
  function anchorFor(key, w, h, sw, sh) {
    const gx = 10, gt = Config.barHeight + 10, gb = 10
    let x = gx, y = gt
    switch (key) {
    case "topleft":     x = gx;            y = gt;            break
    case "top":         x = (sw - w) / 2;  y = gt;            break
    case "topright":    x = sw - gx - w;   y = gt;            break
    case "left":        x = gx;            y = (sh - h) / 2;  break
    case "right":       x = sw - gx - w;   y = (sh - h) / 2;  break
    case "bottomleft":  x = gx;            y = sh - gb - h;   break
    case "bottom":      x = (sw - w) / 2;  y = sh - gb - h;   break
    case "bottomright": x = sw - gx - w;   y = sh - gb - h;   break
    default:            x = gx;            y = gt;            break
    }
    x = Math.min(Math.max(Math.round(x), gx), Math.max(sw - gx - w, gx))
    // never slide under the bar (top) or off the bottom
    y = Math.min(Math.max(Math.round(y), gt), Math.max(sh - gb - h, gt))
    return { x: x, y: y }
  }

  // keyboard nav across the 3x3 grid
  function step(dr, dc) {
    const z = zoneAt(selectedIndex)
    if (!z) { selectedIndex = 4; return }
    let nr = Math.min(2, Math.max(0, z.row + dr))
    let nc = Math.min(2, Math.max(0, z.col + dc))
    for (let i = 0; i < zones.length; i++) {
      if (zones[i].row === nr && zones[i].col === nc) { selectedIndex = i; return }
    }
  }

  LazyLoader {
    active: root.visible

    Variants {
      model: Quickshell.screens
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: root.visible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-corners"
        anchors { top: true; bottom: true; left: true; right: true }

        Item {
          id: overlay
          anchors.fill: parent
          focus: true
          // Becomes true on the first real mouse movement. Until then no
          // hint is highlighted — we never assume the cursor's position
          // (items appearing under a stationary cursor must not select).
          property bool mouseArmed: false
          // Uniform entrance fade for all hints (no stagger).
          property real enterFade: 0
          NumberAnimation {
            id: enterAnim
            target: overlay
            property: "enterFade"
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
          }

          // ── dim (fade in) ──────────────────────────────────
          Rectangle {
            anchors.fill: parent
            color: Theme.dim
            opacity: root.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onPositionChanged: overlay.mouseArmed = true
              onClicked: root.close()
            }
          }

          // ── faint 3x3 grid lines ───────────────────────────
          Rectangle { x: parent.width / 3; y: Config.barHeight; width: 1; height: parent.height - Config.barHeight; color: Theme.fg; opacity: 0.07 }
          Rectangle { x: parent.width * 2 / 3; y: Config.barHeight; width: 1; height: parent.height - Config.barHeight; color: Theme.fg; opacity: 0.07 }
          Rectangle { x: 0; y: Config.barHeight + (parent.height - Config.barHeight) / 3; width: parent.width; height: 1; color: Theme.fg; opacity: 0.07 }
          Rectangle { x: 0; y: Config.barHeight + (parent.height - Config.barHeight) * 2 / 3; width: parent.width; height: 1; color: Theme.fg; opacity: 0.07 }

          // ── snap preview (pops in place, never slides) ──────
          // NOTE: deliberately no x/y/w/h Behaviors here — sliding one
          // rect across the screen sweeps over unrelated zones and reads
          // as other hints flashing. Jump + pop instead.
          Rectangle {
            id: preview
            property var g: root.geomFor(root.selectedIndex, overlay.width, overlay.height)
            property bool isCenter: root.zoneAt(root.selectedIndex) && root.zoneAt(root.selectedIndex).key === "center"
            // unbound pop value so the animation never fights a binding
            property real pop: 1
            visible: root.selectedIndex >= 0
            x: isCenter ? (overlay.width - width) / 2 : g.x
            y: isCenter ? (overlay.height - height) / 2 : g.y
            width: isCenter ? 420 : g.w
            height: isCenter ? 260 : g.h
            radius: Theme.radiusLg
            color: Qt.alpha(Theme.accent, 0.16)
            border.color: Theme.accent
            border.width: 2
            opacity: 0.9 * pop
            scale: 0.94 + 0.06 * pop
            SequentialAnimation {
              id: previewPop
              PropertyAction { target: preview; property: "pop"; value: 0.35 }
              NumberAnimation { target: preview; property: "pop"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }
            Connections {
              target: root
              function onSelectedIndexChanged() { if (root.selectedIndex >= 0) previewPop.restart() }
            }
          }

          // ── circular hints ─────────────────────────────────
          Repeater {
            model: root.zones
            delegate: Item {
              id: hintRoot
              required property var modelData
              required property int index
              property var pos: root.hintPos(index, overlay.width, overlay.height)
              property bool isSel: root.selectedIndex === index
              property bool isCenter: modelData.key === "center"
              // generous hover area around the visible circle
              width: 140; height: 140
              x: pos.x - width / 2
              y: pos.y - height / 2

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // onEntered also fires when the overlay pops up under a
                // stationary cursor — ignore that until the mouse moves.
                onEntered: if (overlay.mouseArmed) root.selectedIndex = hintRoot.index
                // ... but a real movement inside the area always counts.
                onPositionChanged: { overlay.mouseArmed = true; root.selectedIndex = hintRoot.index }
                onClicked: root.snapAt(hintRoot.index, overlay.width, overlay.height)
              }

              Item {
                id: popper
                anchors.centerIn: parent
                width: 64; height: 64
                scale: hintRoot.isSel ? 1.14 : 1
                opacity: overlay.enterFade
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                // glow behind selected
                Rectangle {
                  anchors.centerIn: parent
                  width: parent.width + 22; height: parent.height + 22
                  radius: (parent.width + 22) / 2
                  color: "transparent"
                  border.color: Theme.accent
                  border.width: hintRoot.isSel ? 2 : 0
                  opacity: hintRoot.isSel ? 0.55 : 0
                  Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                Rectangle {
                  id: circle
                  anchors.centerIn: parent
                  width: hintRoot.isCenter ? 74 : 64
                  height: hintRoot.isCenter ? 74 : 64
                  radius: width / 2
                  color: hintRoot.isSel ? Theme.fg : Theme.bg
                  border.color: hintRoot.isSel ? Theme.fg : Theme.border
                  border.width: hintRoot.isSel ? 2 : 1.4
                  Behavior on color { ColorAnimation { duration: 120 } }

                  Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: hintRoot.modelData.icon
                      color: hintRoot.isSel ? Theme.bg : Theme.fg
                      font.family: Theme.monoFont
                      font.pixelSize: hintRoot.isCenter ? 20 : 18
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: hintRoot.modelData.hint
                      color: hintRoot.isSel ? Theme.bg : Theme.fg
                      opacity: hintRoot.isSel ? 1 : 0.55
                      font.family: Theme.monoFont
                      font.pixelSize: 11
                      font.bold: true
                    }
                  }
                }

                // label under circle
                Text {
                  anchors.top: circle.bottom
                  anchors.topMargin: 6
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: hintRoot.modelData.label
                  color: Theme.fg
                  opacity: hintRoot.isSel ? 0.95 : 0.5
                  font.family: Theme.monoFont
                  font.pixelSize: 11
                  style: Text.Outline
                  styleColor: "#80000000"
                }
              }
            }
          }

          Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return }
            if (event.key === Qt.Key_Left) { root.step(0, -1); event.accepted = true; return }
            if (event.key === Qt.Key_Right) { root.step(0, 1); event.accepted = true; return }
            if (event.key === Qt.Key_Up) { root.step(-1, 0); event.accepted = true; return }
            if (event.key === Qt.Key_Down) { root.step(1, 0); event.accepted = true; return }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
              root.snapAt(root.selectedIndex, overlay.width, overlay.height); event.accepted = true; return
            }
            const idx = root.indexForKey(event.key)
            if (idx >= 0) { root.selectedIndex = idx; root.snapAt(idx, overlay.width, overlay.height); event.accepted = true; return }
          }

          Component.onCompleted: if (root.visible) { overlay.enterFade = 1; forceActiveFocus() }
          Connections {
            target: root
            function onVisibleChanged() {
              if (root.visible) {
                overlay.mouseArmed = false
                overlay.enterFade = 0
                enterAnim.restart()
                overlay.forceActiveFocus()
              }
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: "corners"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function moveTo(corner: string): string {
      const names = { topleft: 0, top: 1, topright: 2, left: 3, center: 4, right: 5, bottomleft: 6, bottom: 7, bottomright: 8 }
      const idx = names[corner.toLowerCase()]
      if (idx === undefined) return "unknown corner: " + corner
      const scr = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
      const sw = scr && scr.width ? scr.width : 1920
      const sh = scr && scr.height ? scr.height : 1080
      root.snapAt(idx, sw, sh)
      return "ok"
    }
  }
  GlobalShortcut { name: "cornersToggle"; description: "Toggle corners picker"; onPressed: root.toggle() }
}
