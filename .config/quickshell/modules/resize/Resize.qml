pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Resize picker — drives the shared Qmenu (Oneliner style) instead of
// owning its own PanelWindow. Options are pushed into Qmenu on open;
// the choice comes back via Qmenu.accepted, guarded by `active` so
// unrelated qmenu uses don't trigger a resize.
Scope {
  id: root
  required property var qmenu

  property bool active: false

  function toggle(){ active ? close() : open() }
  function open(){
    qmenu.currentStyle = "Oneliner"
    qmenu.prompt = "dimensions:"
    qmenu.placeholder = ""
    qmenu.items = options.map(o => o.label)
    active = true
    qmenu.open()
  }
  function close(){
    active = false
    if (qmenu.visible) qmenu.close()
  }

  property var options: [
    { label:"(a) 1800 x 825", w:1800, h:825 },
    { label:"(s) 1600 x 900", w:1600, h:900 },
    { label:"(d) 1280 x 720", w:1280, h:720 },
    { label:"(f) 960 x 600", w:960, h:600 },
    { label:"(g) 840 x 525", w:840, h:525 },
    { label:"(h) 800 x 450", w:800, h:450 },
    { label:"(j) 640 x 360", w:640, h:360 },
    { label:"(k) 480 x 270", w:480, h:270 },
    { label:"(l) 432 x 243", w:432, h:243 },
    { label:"(;) 320 x 180", w:320, h:180 }
  ]

  function activateAt(idx){
    if (idx < 0 || idx >= options.length) return
    const o = options[idx]
    // match hyprland_resize.sh: float on, resize, center
    Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.window.float({ action = \"on\" })"])
    Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.window.resize({ x = "+o.w+", y = "+o.h+" })"])
    Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.window.center()"])
    close()
  }

  Connections {
    target: root.qmenu
    function onAccepted(item, idx) {
      if (!root.active) return
      root.active = false
      root.activateAt(idx)
    }
    function onCancelled() { root.active = false }
    function onVisibleChanged() { if (!root.qmenu.visible) root.active = false }
  }

  IpcHandler {
    target: "resize"
    function toggle(): string { root.toggle(); return root.active ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  GlobalShortcut { name: "resizeToggle"; description: "Toggle resize picker"; onPressed: root.toggle() }
}
