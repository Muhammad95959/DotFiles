pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"
import "../oneliner"

Scope {
  id: root
  property bool visible: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true }
  function close() { visible = false; _query="" }

  property string _query: ""

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
      WlrLayershell.namespace: "quickshell-translate"
      anchors { top:true; bottom:true; left:true; right:true }

      MouseArea{ anchors.fill: parent; onClicked: root.close() }
      Rectangle{ anchors.fill: parent; color: Theme.dim }

      Rectangle {
        width: parent.width
        height: Config.barHeight
        anchors.top: parent.top
        anchors.topMargin: 0 // absolute top, overlaying bar
        color: Theme.bg
        OnelinerBar {
          id: onelinerBar
          anchors.fill: parent
          prompt: "Translate:"
          query: root._query
          model: []
          selectedIndex: 0
          inputOnly: true
          placeholder: "Translate · Auto AR ↔ EN"
          onQueryChangedStr: newQuery => root._query = newQuery
          onAccepted: (index, query) => { if (index === -1) root.doTranslate(query) }
          onCancelled: root.close()
        }
      }
      Connections{ target: root; function onVisibleChanged(){ if(root.visible) onelinerBar.focusInput() } }
    }
  }

  }

  IpcHandler{
    target:"translate"
    function toggle(): string{ root.toggle(); return root.visible?"open":"closed"}
    function open(): string{ root.open(); return "ok"}
    function close(): string{ root.close(); return "ok"}
  }
  GlobalShortcut{ name:"translateToggle"; description:"Toggle translate"; onPressed: root.toggle()}
}
