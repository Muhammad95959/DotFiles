pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../common"
import "../oneliner"

Scope {
  id: root
  property bool visible: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true; Qt.callLater(() => onelinerBar.focusInput()) }
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
      // urlencode od -An -tx1 style
      let enc=""
      const bytes = new TextEncoder().encode(t)
      for (let b of bytes){ enc+= "%"+b.toString(16).toUpperCase().padStart(2,"0") }
      url = ar_to_en + "&text=" + enc
    } else {
      url = en_to_ar + "&text=" + encodeURIComponent(t)
    }
    Quickshell.execDetached(["sh","-c","nohup " + browser + " \"--app=" + url.replace(/"/g,"\\\"") + "\" --test-type --password-store=basic >/dev/null 2>&1 &"])
    close()
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
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
        id: topBar
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
          placeholder: "Type to translate (auto AR ↔ EN)"
          onQueryChangedStr: newQuery => root._query = newQuery
          onAccepted: idx => root.doTranslate(root._query)
          onCancelled: root.close()
          onMoved: delta => {}
          onHovered: idx => {}
        }
      }
      Connections{ target: root; function onVisibleChanged(){ if(root.visible) onelinerBar.focusInput() } }
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
