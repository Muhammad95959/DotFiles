pragma ComponentBehavior: Bound
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../common"
import "../oneliner"

Scope {
  id: root
  property bool visible: false
  function toggle(){ visible ? close() : open() }
  function open(){ visible = true; _query=""; selectedIndex=0; Qt.callLater(()=>onelinerBar.focusInput())}
  function close(){ visible=false }

  property string _query: ""
  property int selectedIndex: 0
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
  readonly property var filtered: {
    const q=_query.toLowerCase().trim()
    if(q==="") return options
    return options.filter(o=>{
      const hay=(o.label+" "+o.w+" "+o.h).toLowerCase()
      const toks=q.split(/\s+/); for(let t=0;t<toks.length;t++) if(!hay.includes(toks[t])) return false; return true
    })
  }
  onVisibleChanged: if(visible) selectedIndex=0

  function activateAt(idx){
    const list=filtered; if(idx<0||idx>=list.length) return
    const o=list[idx]
    // match hyprland_resize.sh: float on, resize, center
    Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.window.float({ action = \"on\" })"])
    Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.window.resize({ x = "+o.w+", y = "+o.h+" })"])
    Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.window.center()"])
    close()
  }
  function move(delta){
    const n=filtered.length; if(n===0) return; let ni=selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni
  }
  function moveNoWrap(delta){
    const n=filtered.length; if(n===0) return; const ni=selectedIndex+delta; if(ni<0||ni>=n) return; selectedIndex=ni
  }
  function goHome(){ if(filtered.length>0) selectedIndex=0 }
  function goEnd(){ const n=filtered.length; if(n>0) selectedIndex=n-1 }
  function pageMove(dir){
    const n=filtered.length; if(n===0) return; let page=10; let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.visible
      color:"transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.namespace: "quickshell-resize"
      anchors{ top:true; bottom:true; left:true; right:true}
      MouseArea{ anchors.fill: parent; onClicked: root.close()}
      Rectangle{ anchors.fill: parent; color: Theme.dim}

      Rectangle{
        width: parent.width
        height: Config.barHeight
        anchors.top: parent.top
        anchors.topMargin: 0
        color: Theme.bg
        OnelinerBar{
          id: onelinerBar
          anchors.fill: parent
          prompt: "dimensions:"
          query: root._query
          model: root.filtered
          selectedIndex: root.selectedIndex
          inputOnly: false
          placeholder: "filter size"
          onQueryChangedStr: newQuery=>{ root._query=newQuery; root.selectedIndex=0 }
          onAccepted: idx=>{
            // idx is selectedIndex; if filtered empty ignore
            if(root.filtered.length===0) return
            const effective = idx>=0 ? idx : root.selectedIndex
            root.activateAt(effective)
          }
          onCancelled: root.close()
          onMoved: delta=> root.move(delta)
          onMovedNoWrap: delta=> root.moveNoWrap(delta)
          onHomeRequested: root.goHome()
          onEndRequested: root.goEnd()
          onPageRequested: dir=> root.pageMove(dir)
          onHovered: idx=> root.selectedIndex=idx
        }
        Component.onCompleted: if(root.visible) onelinerBar.focusInput()
        Connections{ target: root; function onVisibleChanged(){ if(root.visible) onelinerBar.focusInput() } }
      }
    }
  }

  IpcHandler {
    target: "resize"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  GlobalShortcut { name: "resizeToggle"; description: "Toggle resize picker"; onPressed: root.toggle() }
}
