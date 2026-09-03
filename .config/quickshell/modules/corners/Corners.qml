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
  function toggle(){ visible?close():open()}
  function open(){ visible=true; _query=""; selectedIndex=0; Qt.callLater(()=>onelinerBar.focusInput())}
  function close(){ visible=false}

  property string _query:""
  property int selectedIndex:0
  property var options: [
    { label:"(1) topleft", key:"topleft" },
    { label:"(2) topright", key:"topright" },
    { label:"(3) bottomleft", key:"bottomleft" },
    { label:"(4) bottomright", key:"bottomright" }
  ]
  readonly property var filtered: {
    const q=_query.toLowerCase().trim()
    if(q==="") return options
    return options.filter(o=>{ const hay=(o.label+" "+o.key).toLowerCase(); const toks=q.split(/\s+/); for(let t=0;t<toks.length;t++) if(!hay.includes(toks[t])) return false; return true })
  }
  onVisibleChanged: if(visible) selectedIndex=0

  function activateAt(idx){
    const list=filtered; if(idx<0||idx>=list.length) return
    const corner=list[idx].key
    moveToCorner(corner)
  }
  // cached monitor geometry — query via hyprctl if needed, else use screen
  function moveToCorner(corner){
    // Use quickshell screen + hyprctl for window size
    // Do async via Process to get window size then dispatch move
    pendingCorner = corner
    addrProc.running = true
  }
  property string pendingCorner:""
  property string windowAddress:""
  property string _accumAddr:""
  property string _accumClients:""

  Process{
    id: addrProc
    command: ["sh","-c","hyprctl activewindow -j 2>/dev/null | jq -r '.address' 2>/dev/null"]
    stdout: SplitParser{ onRead: data=> root._accumAddr += data }
    onExited: {
      const addr=root._accumAddr.trim()
      root._accumAddr=""
      if(addr.length===0 || addr==="null"){ root.close(); return}
      root.windowAddress=addr
      // ensure float
      Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.window.float({ action = \"on\" })"])
      // get clients for size
      root._accumClients=""
      clientsProc.running=true
    }
  }
  Process{
    id: clientsProc
    command: ["sh","-c","hyprctl clients -j 2>/dev/null"]
    stdout: StdioCollector{ waitForEnd:true; onStreamFinished: { root._accumClients = String(text||"") } }
    onExited: {
      try{
        const clients=JSON.parse(root._accumClients||"[]")
        let w=800, h=450
        for(let c of clients){ if(c.address===root.windowAddress){ w=c.size[0]; h=c.size[1]; break}}
        // Use screen geometry instead of hardcoded 1920x1080
        let screenW=1920, screenH=1080
        try{
          // find screen for this window — fallback to primary screen
          const scr=Quickshell.screens[0]
          if(scr && scr.width) { screenW=scr.width; screenH=scr.height }
        }catch(e){}
        let x=10, y=30
        const corner=root.pendingCorner
        if(corner==="topright") x=screenW-w-10
        else if(corner==="bottomleft") y=screenH-h-10
        else if(corner==="bottomright"){ x=screenW-w-10; y=screenH-h-10}
        Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.window.move({ x = "+x+", y = "+y+" })"])
      }catch(e){ console.warn("corners parse fail",e)}
      root.close()
    }
  }

  function move(delta){ const n=filtered.length; if(n===0) return; let ni=selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni }
  function moveNoWrap(delta){ const n=filtered.length; if(n===0) return; const ni=selectedIndex+delta; if(ni<0||ni>=n) return; selectedIndex=ni }
  function goHome(){ if(filtered.length>0) selectedIndex=0 }
  function goEnd(){ const n=filtered.length; if(n>0) selectedIndex=n-1 }
  function pageMove(dir){ const n=filtered.length; if(n===0) return; let page=10; let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni }

  LazyLoader {
    active: root.visible

    Variants {
    model: Quickshell.screens
    PanelWindow{
      required property var modelData; screen: modelData; visible: root.visible; color:"transparent"; exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive; WlrLayershell.namespace:"quickshell-corners"
      anchors{ top:true; bottom:true; left:true; right:true}
      MouseArea{ anchors.fill: parent; onClicked: root.close()}
      Rectangle{ anchors.fill: parent; color: Theme.dim}
      Rectangle{
        width: parent.width; height: Config.barHeight; anchors.top: parent.top; anchors.topMargin: 0; color: Theme.bg
        OnelinerBar{
          id: onelinerBar; anchors.fill: parent; prompt:"corner:"; query: root._query; model: root.filtered; selectedIndex: root.selectedIndex; inputOnly:false; placeholder:"filter"
          onQueryChangedStr: newQuery=>{ root._query=newQuery; root.selectedIndex=0}
          onAccepted: idx=>{ const eff= idx>=0?idx:root.selectedIndex; root.activateAt(eff)}
          onCancelled: root.close()
          onMoved: delta=> root.move(delta)
          onMovedNoWrap: delta=> root.moveNoWrap(delta)
          onHomeRequested: root.goHome()
          onEndRequested: root.goEnd()
          onPageRequested: dir=> root.pageMove(dir)
          onHovered: idx=> root.selectedIndex=idx
        }
        Component.onCompleted: if(root.visible) onelinerBar.focusInput()
        Connections{ target: root; function onVisibleChanged(){ if(root.visible) onelinerBar.focusInput()}}
      }
    }
  }

  }

  IpcHandler {
    target: "corners"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function moveTo(corner: string): string { root.moveToCorner(corner); return "ok" }
  }
  GlobalShortcut { name: "cornersToggle"; description: "Toggle corners picker"; onPressed: root.toggle() }
}
