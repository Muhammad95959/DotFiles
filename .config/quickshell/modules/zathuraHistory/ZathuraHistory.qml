pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  id: root
  property bool visible: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true; refresh() }
  function close() { visible = false }

  property string query: ""
  property int selectedIndex: 0
  property var allEntries: []
  property string _accum: ""
  property bool _blockHover: false
  function _markKeyboard(){ _blockHover=true }

  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    if (q==="") return allEntries
    const toks=q.split(/\s+/)
    return allEntries.filter(p=>{ const hay=String(p).toLowerCase(); for(let t=0;t<toks.length;t++) if(!hay.includes(toks[t])) return false; return true })
  }
  onQueryChanged: selectedIndex=0
  onVisibleChanged: if(visible){ selectedIndex=0; _blockHover=true; refresh() }

  function refresh(){ _accum=""; allEntries=[]; proc.running=true }
  function activateAt(idx){
    const list=filtered; if(idx<0||idx>=list.length) return
    const path=list[idx]
    Quickshell.execDetached(["sh","-c","setsid zathura '" + path.replace(/'/g,"'\\''") + "' >/dev/null 2>&1 &"])
    close()
  }
  function move(delta){ _markKeyboard(); const n=filtered.length; if(n===0) return; let ni=selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni }
  function moveNoWrap(delta){ _markKeyboard(); const n=filtered.length; if(n===0) return; const ni=selectedIndex+delta; if(ni<0||ni>=n) return; selectedIndex=ni }
  function goHome(){ _markKeyboard(); if(filtered.length>0) selectedIndex=0 }
  function goEnd(){ _markKeyboard(); const n=filtered.length; if(n>0) selectedIndex=n-1 }
  function pageMove(dir){ _markKeyboard(); const n=filtered.length; if(n===0) return; let page=10; try{ const h=listView?listView.height:0; if(h>0) page=Math.max(1, Math.floor(h/38))}catch(e){} let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni; try{ if(typeof listView!=="undefined"&&listView) listView.positionViewAtIndex(ni, ListView.Contain)}catch(e){} }

  Process {
    id: proc
    command: ["sh","-c","DB=\"${XDG_DATA_HOME:-$HOME/.local/share}/zathura/bookmarks.sqlite\"; sqlite3 \"$DB\" \"SELECT file FROM fileinfo ORDER BY time DESC\" 2>/dev/null | while read -r path; do [ -e \"$path\" ] && echo \"$path\"; done"]
    stdout: SplitParser { onRead: data => root._accum += data + "\n" }
    onExited: {
      const lines=root._accum.split("\n").map(s=>s.trim()).filter(s=>s.length>0)
      root.allEntries=lines
      if(root.selectedIndex>=root.filtered.length) root.selectedIndex=0
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
      WlrLayershell.namespace: "quickshell-zathura-history"
      anchors { top:true; bottom:true; left:true; right:true }

      MouseArea{ anchors.fill: parent; onClicked: root.close() }
      Rectangle{ anchors.fill: parent; color: Theme.dim }

      Rectangle {
        width: 780; height: 480; anchors.centerIn: parent; radius: Theme.radiusLg; color: Theme.bg; border.color: Theme.border; border.width:1; clip:true
        MouseArea{ anchors.fill: parent; hoverEnabled:true; onPositionChanged: if(root._blockHover) root._blockHover=false; onClicked:{} }

        ColumnLayout {
          anchors.fill: parent; anchors.margins:16; spacing:12
          RowLayout{ Layout.fillWidth:true; spacing:10
            Rectangle{width:32;height:32;radius:8;color:Theme.surface;border.color:Theme.border;border.width:1; Text{anchors.centerIn:parent;text:"";color:Theme.fg;font.family:Theme.nerdFont;font.pixelSize:14}}
            ColumnLayout{spacing:2; Text{text:"Zathura History";color:Theme.fg;font.family:Theme.monoFont;font.pixelSize:14;font.bold:true} Text{text: root.filtered.length+" docs • "+root.allEntries.length+" total";color:Theme.fg;opacity:0.55;font.family:Theme.monoFont;font.pixelSize:11}}
            Item{Layout.fillWidth:true}
            Rectangle{width:28;height:28;radius:14;color:Theme.surface;border.color:Theme.border;border.width:1; Text{anchors.centerIn:parent;text:"";color:Theme.fg;opacity:0.6;font.family:Theme.nerdFont;font.pixelSize:11} MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor; onClicked: root.refresh()}}
            Rectangle{width:28;height:28;radius:14;color:Theme.surface;border.color:Theme.border;border.width:1; Text{anchors.centerIn:parent;text:"";color:Theme.fg;opacity:0.55;font.family:Theme.nerdFont;font.pixelSize:11} MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor; onClicked: root.close()}}
          }
          Rectangle{ Layout.fillWidth:true; height:42; radius:Theme.radiusMd; color:Theme.surface; border.color: searchField.activeFocus?Qt.alpha(Theme.fg,0.40):Theme.border; border.width:1
            RowLayout{ anchors.fill:parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:8
              Text{ text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:14}
              TextInput{ id: searchField; Layout.fillWidth:true; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:14; focus:true; activeFocusOnTab:false; onTextChanged: root.query=text; onAccepted: root.activateAt(root.selectedIndex)
                Keys.onPressed: event=>{ if(event.key===Qt.Key_Escape){root.close();event.accepted=true} else if(event.key===Qt.Key_Backtab){root.move(-1);event.accepted=true} else if(event.key===Qt.Key_Tab){ if(event.modifiers & Qt.ShiftModifier) root.move(-1); else root.move(1); event.accepted=true } else if(event.key===Qt.Key_Up){root.moveNoWrap(-1);event.accepted=true} else if(event.key===Qt.Key_Down){root.moveNoWrap(1);event.accepted=true} else if(event.key===Qt.Key_Left){root.moveNoWrap(-1);event.accepted=true} else if(event.key===Qt.Key_Right){root.moveNoWrap(1);event.accepted=true} else if(event.key===Qt.Key_Home){root.goHome();event.accepted=true} else if(event.key===Qt.Key_End){root.goEnd();event.accepted=true} else if(event.key===Qt.Key_PageUp){root.pageMove(-1);event.accepted=true} else if(event.key===Qt.Key_PageDown){root.pageMove(1);event.accepted=true} else if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter){root.activateAt(root.selectedIndex);event.accepted=true} }
                Text{anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;visible:searchField.text==="";text:"Search document…";color:Theme.fg;opacity:0.45;font.family:Theme.monoFont;font.pixelSize:14}
              }
              Text{ visible: searchField.text!==""; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:12; MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor; onClicked:{searchField.text=""; root.query=""}} }
            }
          }
          ListView{
            id: listView; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; LayoutMirroring.enabled: false; boundsBehavior:Flickable.StopAtBounds; spacing:6; model: root.filtered; currentIndex: root.selectedIndex
            onCurrentIndexChanged:{ root.selectedIndex=currentIndex; if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain)}
            delegate: Rectangle{
              id: del; required property var modelData; required property int index; width:listView.width; height:36; radius:Theme.radiusSm; color: root.selectedIndex===index?Theme.surfaceHover:Theme.surface; border.color: root.selectedIndex===index?Qt.alpha(Theme.fg,0.33):Theme.border; border.width:1
              RowLayout{ anchors.fill:parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:10
                Text{ text:""; color:Theme.fg; opacity:0.7; font.family:Theme.nerdFont; font.pixelSize:12}
                Text{ text: del.modelData.split("/").pop(); color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:12; Layout.fillWidth:true; elide:Text.ElideMiddle; horizontalAlignment: Text.AlignLeft; LayoutMirroring.enabled: false}
              }
              MouseArea{ anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onEntered: if(!root._blockHover) root.selectedIndex=del.index; onClicked: root.activateAt(del.index)}
            }
            Text{ anchors.centerIn:parent; visible: root.filtered.length===0; text: root.allEntries.length===0? "No history yet":"No matches"; color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:13}
          }
          RowLayout{ Layout.alignment:Qt.AlignHCenter; spacing:10; Text{text:"↵ Open";color:Theme.fg;opacity:0.85;font.family:Theme.monoFont;font.pixelSize:10;font.bold:true} Rectangle{width:1;height:10;color:Theme.border;opacity:0.6} Text{text:"Esc Close";color:Theme.fg;opacity:0.85;font.family:Theme.monoFont;font.pixelSize:10;font.bold:true}}
        }
        Component.onCompleted: if(root.visible) searchField.forceActiveFocus()
        Connections{ target: root; function onVisibleChanged(){ if(root.visible){ searchField.text=""; searchField.forceActiveFocus()}}}
      }
    }
  }

  }

  IpcHandler{
    target: "zathuraHistory"
    function toggle(): string{ root.toggle(); return root.visible?"open":"closed"}
    function open(): string{ root.open(); return "ok"}
    function close(): string{ root.close(); return "ok"}
  }
  GlobalShortcut{ name:"zathuraHistoryToggle"; description:"Toggle zathura history"; onPressed: root.toggle()}
}
