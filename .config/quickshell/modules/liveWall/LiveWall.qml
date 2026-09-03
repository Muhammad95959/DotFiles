pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "."
import "../common"

Scope {
  id: root
  property bool visible: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true; query = ""; selectedIndex = 0; refresh() }
  function close() { visible = false }

  property string query: ""
  property int selectedIndex: 0
  property var allFiles: []
  property string _accum: ""
  property bool _blockHover: false
  function _markKeyboard() { _blockHover = true }

  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    if (q === "") return allFiles
    const toks = q.split(/\s+/)
    return allFiles.filter(n => {
      const hay = n.toLowerCase()
      for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) return false
      return true
    })
  }

  onQueryChanged: selectedIndex = 0
  onVisibleChanged: if (visible) { selectedIndex = 0; _blockHover = true }

  function refresh() {
    _accum = ""; allFiles = []; scanProc.running = true
  }

  function activateAt(idx) {
    const list = filtered; if (idx < 0 || idx >= list.length) return
    const chosen = list[idx]
    LiveWallManager.setVideo(chosen, true)
    close()
  }

  function toggleLive() {
    LiveWallManager.toggleLive()
  }

  function move(d) { _markKeyboard(); const n=filtered.length; if(n===0) return; let ni=selectedIndex+d; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni }
  function moveNoWrap(d) { _markKeyboard(); const n=filtered.length; if(n===0) return; const ni=selectedIndex+d; if(ni<0||ni>=n) return; selectedIndex=ni }
  function goHome() { _markKeyboard(); if(filtered.length>0) selectedIndex=0 }
  function goEnd() { _markKeyboard(); if(filtered.length>0) selectedIndex=filtered.length-1 }
  function pageMove(dir) {
    _markKeyboard(); const n=filtered.length; if(n===0) return
    let page=8; try{ const h=listView?listView.height:0; if(h>0) page=Math.max(1, Math.floor(h/40))}catch(e){}
    let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni
    try{ if(typeof listView!=="undefined"&&listView) listView.positionViewAtIndex(ni, ListView.Contain)}catch(e){}
  }

  Process {
    id: scanProc
    command: ["sh", "-c", "find \"$HOME/Backgrounds/Live\" -type f ! -name \"active\" -exec basename {} \\; 2>/dev/null | sort -u"]
    stdout: SplitParser { onRead: d => root._accum += d + "\n" }
    onExited: {
      const lines = root._accum.split("\n").map(s => s.trim()).filter(s => s.length > 0)
      root.allFiles = lines
      if (root.selectedIndex >= root.filtered.length) root.selectedIndex = 0
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
        WlrLayershell.namespace: "quickshell-livewall"
      anchors { top:true; bottom:true; left:true; right:true }

      MouseArea { anchors.fill: parent; onClicked: root.close() }
      Rectangle { anchors.fill: parent; color: Theme.dim }

      Rectangle {
        width: 720; height: 500; anchors.centerIn: parent
        radius: Theme.radiusLg; color: Theme.bg; border.color: Theme.border; border.width: 1; clip: true
        LayoutMirroring.enabled: false
        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: if(root._blockHover) root._blockHover = false; onClicked:{} }

        ColumnLayout {
          anchors.fill: parent; anchors.margins: 16; spacing: 12

          RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle { width:32; height:32; radius:8; color:Theme.surface; border.color:Theme.border; border.width:1
              Text { anchors.centerIn: parent; text:""; color:Theme.fg; font.family:Theme.nerdFont; font.pixelSize:14 }
            }
            ColumnLayout { spacing:2
              Text { text:"Live Wallpaper"; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:14; font.bold:true }
              Text { text: LiveWallManager.activeFile==="" ? "no active" : "active: " + LiveWallManager.activeFile + (LiveWallManager.isLiveActive ? " • live" : " • static"); color: LiveWallManager.isLiveActive?Theme.accent:Theme.fg; opacity:0.7; font.family:Theme.monoFont; font.pixelSize:11 }
            }
            Item { Layout.fillWidth:true }
            Rectangle {
              width: 90; height:28; radius:14
              color: LiveWallManager.isLiveActive ? Theme.accent : Theme.surface
              border.color: LiveWallManager.isLiveActive ? Theme.accent : Theme.border; border.width:1
              RowLayout { anchors.centerIn: parent; spacing:6
                Rectangle { width:10; height:10; radius:5; color: LiveWallManager.isLiveActive ? Theme.bg : Qt.alpha(Theme.fg,0.3) }
                Text { text: LiveWallManager.isLiveActive ? "Live" : "Static"; color: LiveWallManager.isLiveActive ? Theme.bg : Theme.fg; font.family:Theme.monoFont; font.pixelSize:11; font.bold:true }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleLive() }
            }
            Rectangle { width:28; height:28; radius:14; color:Theme.surface; border.color:Theme.border; border.width:1
              Text { anchors.centerIn: parent; text:""; color:Theme.fg; opacity:0.6; font.family:Theme.nerdFont; font.pixelSize:11 }
              MouseArea { anchors.fill: parent; cursorShape:Qt.PointingHandCursor; onClicked: root.refresh() }
            }
            Rectangle { width:28; height:28; radius:14; color:Theme.surface; border.color:Theme.border; border.width:1
              Text { anchors.centerIn: parent; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:11 }
              MouseArea { anchors.fill: parent; cursorShape:Qt.PointingHandCursor; onClicked: root.close() }
            }
          }

          Rectangle {
            Layout.fillWidth:true; height:42; radius:Theme.radiusMd; color:Theme.surface; border.color: searchField.activeFocus?Qt.alpha(Theme.fg,0.40):Theme.border; border.width:1
            RowLayout {
              anchors.fill: parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:8
              Text { text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:14 }
              TextInput {
                id: searchField
                Layout.fillWidth:true; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:14
                focus: true; activeFocusOnTab: false
                onTextChanged: root.query=text
                onAccepted: { if(root.filtered.length>0) root.activateAt(root.selectedIndex) }
                Keys.onPressed: event=>{
                  if(event.key===Qt.Key_Escape){ root.close(); event.accepted=true}
                  else if(event.key===Qt.Key_Backtab){ root.move(-1); event.accepted=true}
                  else if(event.key===Qt.Key_Tab){ if(event.modifiers & Qt.ShiftModifier) root.move(-1); else root.move(1); event.accepted=true }
                  else if(event.key===Qt.Key_Up){ root.moveNoWrap(-1); event.accepted=true}
                  else if(event.key===Qt.Key_Down){ root.moveNoWrap(1); event.accepted=true}
                  else if(event.key===Qt.Key_Left){ root.moveNoWrap(-1); event.accepted=true}
                  else if(event.key===Qt.Key_Right){ root.moveNoWrap(1); event.accepted=true}
                  else if(event.key===Qt.Key_Home){ root.goHome(); event.accepted=true}
                  else if(event.key===Qt.Key_End){ root.goEnd(); event.accepted=true}
                  else if(event.key===Qt.Key_PageUp){ root.pageMove(-1); event.accepted=true}
                  else if(event.key===Qt.Key_PageDown){ root.pageMove(1); event.accepted=true}
                  else if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter){ root.activateAt(root.selectedIndex); event.accepted=true}
                }
                Text { anchors.left:parent.left; anchors.verticalCenter:parent.verticalCenter; visible: searchField.text===""; text:"Search live…"; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:14 }
              }
              Text { visible: searchField.text!==""; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:12
                MouseArea{anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{ searchField.text=""; root.query="" } }
              }
            }
          }

          Text {
            Layout.fillWidth:true; visible: LiveWallManager.isLiveActive
            text: "auto-pause when tiled (not kitty/Yazi) / fullscreen"
            color:Theme.fg; opacity:0.4; font.family:Theme.monoFont; font.pixelSize:10
            horizontalAlignment: Text.AlignHCenter
          }

          ListView {
            id: listView
            Layout.fillWidth:true; Layout.fillHeight:true; clip:true
            boundsBehavior: Flickable.StopAtBounds; spacing:6
            model: root.filtered; currentIndex: root.selectedIndex
            onCurrentIndexChanged:{ root.selectedIndex=currentIndex; if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain) }
            delegate: Rectangle {
              id: del; required property var modelData; required property int index
              width:listView.width; height:40; radius:Theme.radiusSm
              color: root.selectedIndex===index ? Theme.surfaceHover : Theme.surface
              border.color: root.selectedIndex===index ? Qt.alpha(Theme.fg,0.33) : Theme.border; border.width:1
              RowLayout {
                anchors.fill:parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:10
                Rectangle{
                  width:28; height:28; radius:6
                  color: modelData===LiveWallManager.activeFile ? Qt.alpha(Theme.accent,0.18) : Qt.alpha(Theme.fg,0.06)
                  border.color: modelData===LiveWallManager.activeFile ? Theme.accent : Theme.border; border.width:1
                  Text{ anchors.centerIn:parent; text: modelData===LiveWallManager.activeFile ? "" : ""; color: modelData===LiveWallManager.activeFile ? Theme.accent : Theme.fg; opacity:0.8; font.family:Theme.nerdFont; font.pixelSize:11 }
                }
                Text{
                  text: modelData; color: Theme.fg; font.family:Theme.monoFont; font.pixelSize:12
                  Layout.fillWidth:true; elide:Text.ElideMiddle
                  font.bold: root.selectedIndex===del.index || modelData===LiveWallManager.activeFile; horizontalAlignment: Text.AlignLeft; LayoutMirroring.enabled: false
                }
                Text{ text: modelData===LiveWallManager.activeFile ? "active" : ""; color:Theme.accent; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true; visible: modelData===LiveWallManager.activeFile }
              }
              MouseArea{ anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onEntered: if(!root._blockHover) root.selectedIndex=del.index; onClicked: root.activateAt(del.index) }
            }
            Text{
              anchors.centerIn:parent; visible: root.filtered.length===0
              text: root.allFiles.length===0 ? "No live wallpapers in ~/Backgrounds/Live" : "No match"
              color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:13
            }
          }

          RowLayout {
            Layout.alignment:Qt.AlignHCenter; spacing:10
            Text{ text:"↵ Set active"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true }
            Rectangle{ width:1; height:10; color:Theme.border; opacity:0.6 }
            Text{ text:"Live toggle"; color:Theme.fg; opacity:0.65; font.family:Theme.monoFont; font.pixelSize:10 }
            Rectangle{ width:1; height:10; color:Theme.border; opacity:0.6 }
            Text{ text:"Esc Close"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true }
          }
        }

        Component.onCompleted: if(root.visible) searchField.forceActiveFocus()
        Connections{ target: root; function onVisibleChanged(){ if(root.visible){ searchField.text=""; searchField.forceActiveFocus() } } }
      }
    }
  }
  }

  IpcHandler {
    target: "liveWall"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function toggleLive(): string { root.toggleLive(); return LiveWallManager.isLiveActive ? "live" : "static" }
    function set(fileName: string): string { LiveWallManager.setVideo(fileName, true); return "ok " + fileName }
  }
  GlobalShortcut { name: "liveWallToggle"; description: "Toggle live wall"; onPressed: root.toggle() }
}
