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
  function toggle(){ visible?close():open()}
  function open(){ visible=true; _query=""; selectedIndex=0; refresh(); Qt.callLater(()=>onelinerBar.focusInput())}
  function close(){ visible=false}

  property string _query:""
  property int selectedIndex:0
  property var allEntries: [] // {name, url, folder}
  property string _accum:""

  readonly property var filtered: {
    const q=_query.toLowerCase().trim()
    if(q==="") return allEntries
    const toks=q.split(/\s+/)
    return allEntries.filter(e=>{
      const hay=(e.name+" "+(e.folder||"")+" "+e.url).toLowerCase()
      for(let t=0;t<toks.length;t++) if(!hay.includes(toks[t])) return false
      return true
    })
  }
  onVisibleChanged: if(visible) selectedIndex=0

  function refresh(){
    _accum=""; allEntries=[]; proc.running=true
  }
  function activateAt(idx){
    const list=filtered; if(idx<0||idx>=list.length) return
    const url=list[idx].url
    Quickshell.execDetached(["brave-origin","--test-type","--password-store=basic",url])
    close()
  }
  function move(delta){
    const n=filtered.length; if(n===0) return; let ni=selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni
  }

  Process {
    id: proc
    command: ["sh","-c","python3 -c \"\nimport json,os\np=os.path.expanduser('~/.config/BraveSoftware/Brave-Origin/Default/Bookmarks')\nimport sys\ntry:\n    d=json.load(open(p))\n    out=[]\n    for ch in d.get('roots',{}).get('bookmark_bar',{}).get('children',[]):\n        if 'children' in ch:\n            folder=ch.get('name','')\n            for c in ch.get('children',[]):\n                out.append({'name':c.get('name',''), 'url':c.get('url',''), 'folder':folder})\n        else:\n            out.append({'name':ch.get('name',''), 'url':ch.get('url',''), 'folder':''})\n    import json as j\n    print(j.dumps(out))\nexcept Exception as e:\n    print('[]')\n\""]
    stdout: StdioCollector{ waitForEnd:true; onStreamFinished: {
      try{
        const arr=JSON.parse(String(text||"[]"))
        let out=[]
        for(let e of arr){ if(e.url && e.name) out.push(e)}
        root.allEntries=out
        if(root.selectedIndex>=root.filtered.length) root.selectedIndex=0
      }catch(e){ root.allEntries=[]}
    }}
  }

  Variants{
    model: Quickshell.screens
    PanelWindow{
      id: win; required property var modelData; screen: modelData; visible: root.visible; color:"transparent"; exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive; WlrLayershell.namespace:"quickshell-bookmarks"
      anchors{ top:true; bottom:true; left:true; right:true}
      MouseArea{ anchors.fill: parent; onClicked: root.close()}
      Rectangle{ anchors.fill: parent; color: Theme.dim}
      Rectangle{
        id: topBar; width: parent.width; height: Config.barHeight; anchors.top: parent.top; anchors.topMargin: 0; color: Theme.bg
        OnelinerBar{
          id: onelinerBar; anchors.fill: parent; prompt:"Bookmark:"; query: root._query; model: root.filtered; selectedIndex: root.selectedIndex; inputOnly:false; placeholder:"search bookmarks…"
          onQueryChangedStr: newQuery=>{ root._query=newQuery; root.selectedIndex=0}
          onAccepted: idx=>{ const eff= idx>=0?idx:root.selectedIndex; if(root.filtered.length>0) root.activateAt(eff)}
          onCancelled: root.close()
          onMoved: delta=> root.move(delta)
          onHovered: idx=> root.selectedIndex=idx
        }
        Component.onCompleted: if(root.visible) onelinerBar.focusInput()
        Connections{ target: root; function onVisibleChanged(){ if(root.visible){ onelinerBar.clear(); onelinerBar.focusInput()}}}
      }
      // Tooltip for selected URL (below bar, like rofi but quick)
      Rectangle{
        visible: root.visible && root.filtered.length>0 && root.selectedIndex>=0 && root.selectedIndex < root.filtered.length
        width: Math.min(parent.width-32, urlText.implicitWidth+24)
        height: 28
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.topMargin: 6
        radius: Theme.radiusSm
        color: Qt.alpha(Theme.bg,0.95)
        border.color: Theme.border
        border.width:1
        Text{
          id: urlText
          anchors.centerIn: parent
          text: {
            if(root.filtered.length===0) return ""
            const e=root.filtered[root.selectedIndex]
            if(!e) return ""
            return (e.folder? e.folder+" › ":"") + e.url
          }
          color: Theme.fg
          opacity:0.85
          font.family: Theme.monoFont
          font.pixelSize:11
          elide: Text.ElideMiddle
          width: Math.min(implicitWidth, parent.width-24)
        }
      }
    }
  }

  IpcHandler {
    target: "bookmarks"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  GlobalShortcut { name: "bookmarksToggle"; description: "Toggle bookmarks"; onPressed: root.toggle() }
}
