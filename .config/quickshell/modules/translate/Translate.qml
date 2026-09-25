pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../launcher/logic/match.js" as Match

Scope {
  id: root
  required property var qmenu

  property bool active: false

  function toggle() { active ? close() : open() }
  function open() {
    qmenu.currentStyle = "Oneliner"
    qmenu.prompt = "Translate:"
    qmenu.placeholder = "Translate · Auto AR ↔ EN"
    qmenu.items = []
    active = true
    qmenu.open()
  }
  function close() {
    active = false
    if (qmenu.visible)
      qmenu.close()
  }
  function doTranslate(text) {
    const t = String(text || "").trim()
    if (t.length === 0)
      return
    const enToAr = "https://translate.google.com.eg/?hl=ar&tab=rT1&sl=en&tl=ar&op=translate"
    const arToEn = "https://translate.google.com.eg/?hl=ar&tab=rT1&sl=ar&tl=en&op=translate"
    const base = Match.isArabic(t) ? arToEn : enToAr
    const url = base + "&text=" + encodeURIComponent(t)
    Quickshell.execDetached(["brave-origin", "--app=" + url, "--test-type", "--password-store=basic"])
    close()
  }

  Connections {
    target: root.qmenu
    function onAccepted(item, idx) {
      if (!root.active)
        return
      root.active = false
      root.doTranslate(typeof item === "string" ? item : String(item ?? ""))
    }
    function onCancelled() { root.active = false }
    function onVisibleChanged() { if (!root.qmenu.visible) root.active = false }
  }

  IpcHandler {
    target: "translate"
    function toggle(): string { root.toggle(); return root.active ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  GlobalShortcut { name: "translateToggle"; description: "Toggle translate"; onPressed: root.toggle() }
}
