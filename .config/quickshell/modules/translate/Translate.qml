pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Translate input — drives the shared Qmenu (Oneliner style, free-text
// mode) instead of owning its own PanelWindow. Opens Qmenu with no items;
// the typed text comes back via Qmenu.accepted(text, -1), guarded by
// `active` so unrelated qmenu uses don't trigger a translation.
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
    if (qmenu.visible) qmenu.close()
  }

  function doTranslate(text) {
    const t = String(text||"").trim()
    if (t.length===0) return
    // match brave_translate.sh logic: count Arabic vs English
    // Do detection in JS: Arabic \u0600-\u06FF etc
    let arabic = 0, english = 0
    for (let i=0;i<t.length;i++){
      const c=t.charCodeAt(i)
      if ((c>=0x0600 && c<=0x06FF) || (c>=0x0750&&c<=0x077F) || (c>=0x08A0&&c<=0x08FF) || (c>=0xFB50&&c<=0xFDFF) || (c>=0xFE70&&c<=0xFEFF)) arabic++
      else if ((c>=65&&c<=90)||(c>=97&&c<=122)) english++
    }
    const en_to_ar = "https://translate.google.com.eg/?hl=ar&tab=rT1&sl=en&tl=ar&op=translate"
    const ar_to_en = "https://translate.google.com.eg/?hl=ar&tab=rT1&sl=ar&tl=en&op=translate"
    let url
    let browser = "brave-origin"
    if (arabic > english) {
      url = ar_to_en + "&text=" + encodeURIComponent(t)
    } else {
      url = en_to_ar + "&text=" + encodeURIComponent(t)
    }
    Quickshell.execDetached(["sh","-c","nohup " + browser + " \"--app=" + url.replace(/"/g,"\\\"") + "\" --test-type --password-store=basic >/dev/null 2>&1 &"])
    close()
  }

  Connections {
    target: root.qmenu
    function onAccepted(item, idx) {
      if (!root.active) return
      root.active = false
      const text = typeof item === "string" ? item : String(item ?? "")
      root.doTranslate(text)
    }
    function onCancelled() { root.active = false }
    function onVisibleChanged() { if (!root.qmenu.visible) root.active = false }
  }

  IpcHandler{
    target:"translate"
    function toggle(): string{ root.toggle(); return root.active?"open":"closed"}
    function open(): string{ root.open(); return "ok"}
    function close(): string{ root.close(); return "ok"}
  }
  GlobalShortcut{ name:"translateToggle"; description:"Toggle translate"; onPressed: root.toggle()}
}
