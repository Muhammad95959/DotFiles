pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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
  function isArabic(t) {
    let arabic = 0, english = 0
    for (let i = 0; i < t.length; i++) {
      const c = t.charCodeAt(i)
      if ((c >= 0x0600 && c <= 0x06FF) || (c >= 0x0750 && c <= 0x077F) || (c >= 0x08A0 && c <= 0x08FF) || (c >= 0xFB50 && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF))
        arabic++
      else if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122))
        english++
    }
    return arabic > english
  }
  function doTranslate(text) {
    const t = String(text || "").trim()
    if (t.length === 0)
      return
    const enToAr = "https://translate.google.com.eg/?hl=ar&tab=rT1&sl=en&tl=ar&op=translate"
    const arToEn = "https://translate.google.com.eg/?hl=ar&tab=rT1&sl=ar&tl=en&op=translate"
    const base = isArabic(t) ? arToEn : enToAr
    const url = base + "&text=" + encodeURIComponent(t)
    Quickshell.execDetached(["sh", "-c", "nohup brave-origin \"--app=" + url.replace(/"/g, "\\\"") + "\" --test-type --password-store=basic >/dev/null 2>&1 &"])
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
