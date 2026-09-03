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
  property string sourceFilter: "All"
  property int selectedIndex: 0
  property var allEntries: []
  property bool _altHeld: false
  property bool _blockHover: false

  readonly property var sourceFilters: [
    { key: "All", label: "All" },
    { key: "File", label: "Files" },
    { key: "Url", label: "URL" }
  ]

  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    const f = sourceFilter
    let list = []
    for (let i = 0; i < allEntries.length; i++) {
      const e = allEntries[i]
      const isUrl = e.isUrl
      if (f === "File" && isUrl) continue
      if (f === "Url" && !isUrl) continue
      if (q !== "") {
        const hay = (e.title + " " + e.path).toLowerCase()
        const toks = q.split(/\s+/)
        let ok = true
        for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) { ok = false; break }
        if (!ok) continue
      }
      list.push(e)
    }
    return list
  }

  function _markKeyboard() { _blockHover = true }

  onQueryChanged: selectedIndex = 0
  onSourceFilterChanged: selectedIndex = 0
  onVisibleChanged: { _altHeld = false; if (visible) { selectedIndex = 0; _blockHover = true; refresh() } }

  function refresh() {
    allEntries = []; proc.running = true
  }
  function activateAt(idx) {
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    const e = list[idx]
    Quickshell.execDetached(["mpv", e.path])
    close()
  }
  function move(delta) {
    _markKeyboard(); const n = filtered.length; if (n===0) return
    let ni = selectedIndex + delta; if (ni < 0) ni = n-1; if (ni >= n) ni = 0; selectedIndex = ni
  }
  function moveNoWrap(delta) {
    _markKeyboard(); const n = filtered.length; if (n===0) return
    const ni = selectedIndex + delta; if (ni < 0 || ni >= n) return; selectedIndex = ni
  }
  function goHome() { _markKeyboard(); if (filtered.length>0) selectedIndex=0 }
  function goEnd() { _markKeyboard(); const n=filtered.length; if(n>0) selectedIndex=n-1 }
  function pageMove(dir) {
    _markKeyboard(); const n=filtered.length; if(n===0) return
    let page = 10; try { const h=listView?listView.height:0; if(h>0) page=Math.max(1, Math.floor(h/38))} catch(e){}
    let ni = selectedIndex + dir*page; if (ni<0) ni=0; if (ni>=n) ni=n-1; selectedIndex=ni
    try { if (typeof listView!=="undefined"&&listView) listView.positionViewAtIndex(ni, ListView.Contain)} catch(e){}
  }

  Process {
    id: proc
    command: ["python3", "-c", "import os, re\np=os.path.expanduser('~/.config/mpv/history.log')\nout=[]\ntry:\n    lines=open(p, errors='ignore').read().splitlines()\n    for raw in reversed(lines):\n        m=re.match(r'^\\[.*?\\] \"(.*)\" \\| (.*)$', raw)\n        if not m: continue\n        title, path=m.group(1).strip(), m.group(2).strip()\n        if not path: continue\n        is_url=path.startswith('http://') or path.startswith('https://') or path.startswith('ytdl://')\n        if not is_url and not os.path.exists(os.path.expanduser(path)): continue\n        if not title: title=os.path.basename(path)\n        out.append((title, path, is_url))\nexcept Exception as e: pass\nfor t,p,u in out:\n    print(t.replace(chr(9),' ') + '  󰛂  ' + p)\n"]
    stdout: StdioCollector{ waitForEnd:true; onStreamFinished: {
      const lines=String(text||"").split("\n").map(s=>s.trim()).filter(s=>s.length>0)
      let out=[]
      for(let line of lines){
        const sep="  󰛂  "; const idx=line.indexOf(sep)
        let title="", path=""
        if(idx>=0){ title=line.slice(0,idx).trim(); path=line.slice(idx+sep.length).trim() }
        else { title=line; path=line }
        if(!path) continue
        const isUrl=path.startsWith("http://")||path.startsWith("https://")||path.startsWith("ytdl://")
        if(!title) title=path.split("/").pop()
        out.push({ title: title, path: path, isUrl: isUrl })
      }
      root.allEntries=out
      if(root.selectedIndex>=root.filtered.length) root.selectedIndex=0
    }}
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
        WlrLayershell.namespace: "quickshell-mpv-history"
      anchors { top:true; bottom:true; left:true; right:true }

      MouseArea { anchors.fill: parent; onClicked: root.close() }
      Rectangle { anchors.fill: parent; color: Theme.dim }

      Rectangle {
        id: container
        width: 780
        height: 520
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        clip: true
        LayoutMirroring.enabled: false
        focus: true
        Keys.onPressed: event => {
          const hasAlt = (event.modifiers & Qt.AltModifier) || event.key === Qt.Key_Alt
          if (hasAlt) root._altHeld = true
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_F) { root.sourceFilter = "File"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_U) { root.sourceFilter = "Url"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_A) { root.sourceFilter = "All"; event.accepted = true; return }
          const inSearch = searchField.activeFocus
          if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
          else if (event.key === Qt.Key_Slash && !inSearch && !(event.modifiers & Qt.AltModifier)) { searchField.forceActiveFocus(); event.accepted = true }
          else if (event.key === Qt.Key_R && !inSearch && !(event.modifiers & Qt.AltModifier) && !(event.modifiers & Qt.ControlModifier)) { root.refresh(); event.accepted = true }
          if (event.key === Qt.Key_Alt) root._altHeld = true
        }
        Keys.onReleased: event => {
          if (event.key === Qt.Key_Alt) root._altHeld = false
          else root._altHeld = Boolean(event.modifiers & Qt.AltModifier)
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: if(root._blockHover) root._blockHover=false; onClicked:{} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle { width:32; height:32; radius:8; color:Theme.surface; border.color:Theme.border; border.width:1
              Text { anchors.centerIn: parent; text:"󰎁"; color:Theme.fg; font.family:Theme.nerdFont; font.pixelSize:14 }
            }
            ColumnLayout { spacing:2
              Text { text:"MPV History"; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:14; font.bold:true }
              Text { text: root.filtered.length + " videos • " + root.allEntries.length + " total • " + root.sourceFilter; color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:11 }
            }
            Item { Layout.fillWidth:true }
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
            Layout.fillWidth:true; Layout.preferredHeight:42; radius:Theme.radiusMd; color:Theme.surface; border.color: searchField.activeFocus ? Qt.alpha(Theme.fg,0.40) : Theme.border; border.width:1
            RowLayout {
              anchors.fill: parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:8
              Text { text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:14 }
              TextInput {
                id: searchField
                Layout.fillWidth:true; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:14; focus:true; activeFocusOnTab:false
                onTextChanged: root.query = text
                onAccepted: root.activateAt(root.selectedIndex)
                Keys.onPressed: event => {
                  const hasAlt = (event.modifiers & Qt.AltModifier) || event.key === Qt.Key_Alt
                  if (hasAlt) root._altHeld = true
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_F) { root.sourceFilter = "File"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_U) { root.sourceFilter = "Url"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_A) { root.sourceFilter = "All"; event.accepted = true; return }
                  if (event.key===Qt.Key_Escape){ if(text.length>0){ text=""; root.query=""; event.accepted=true } else { root.close(); event.accepted=true } }
                  else if (event.key===Qt.Key_Backtab){ root.move(-1); event.accepted=true}
                  else if (event.key===Qt.Key_Tab){ if (event.modifiers & Qt.ShiftModifier) root.move(-1); else root.move(1); event.accepted=true }
                  else if (event.key===Qt.Key_Up){ root.moveNoWrap(-1); event.accepted=true}
                  else if (event.key===Qt.Key_Down){ root.moveNoWrap(1); event.accepted=true}
                  else if (event.key===Qt.Key_Left){ root.moveNoWrap(-1); event.accepted=true}
                  else if (event.key===Qt.Key_Right){ root.moveNoWrap(1); event.accepted=true}
                  else if (event.key===Qt.Key_Home){ root.goHome(); event.accepted=true}
                  else if (event.key===Qt.Key_End){ root.goEnd(); event.accepted=true}
                  else if (event.key===Qt.Key_PageUp){ root.pageMove(-1); event.accepted=true}
                  else if (event.key===Qt.Key_PageDown){ root.pageMove(1); event.accepted=true}
                  else if (event.key===Qt.Key_Return||event.key===Qt.Key_Enter){ root.activateAt(root.selectedIndex); event.accepted=true}
                  if (event.key === Qt.Key_Alt) root._altHeld = true
                }
                Keys.onReleased: event => {
                  if (event.key === Qt.Key_Alt) root._altHeld = false
                  else root._altHeld = Boolean(event.modifiers & Qt.AltModifier)
                }
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; visible: searchField.text===""; text:"Search video…"; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:14 }
              }
              Text { visible: searchField.text!==""; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:12
                MouseArea{anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{searchField.text=""; root.query=""}}
              }
              Text { visible: searchField.text===""; text:"/"; color:Theme.fg; opacity:0.35; font.family:Theme.monoFont; font.pixelSize:11
                MouseArea{anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: searchField.forceActiveFocus()}
              }
            }
          }

          Flickable {
            Layout.fillWidth: true; Layout.preferredHeight: 32; contentWidth: filterRow.width; contentHeight: 32; clip: true
            flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
            RowLayout {
              id: filterRow; height: 32; spacing: 8
              Repeater {
                model: root.sourceFilters
                Rectangle {
                  required property var modelData
                  height: 28; width: chipLabel.width + 22; radius: 14
                  color: root.sourceFilter === modelData.key ? Theme.fg : Theme.surface
                  border.color: root.sourceFilter === modelData.key ? Theme.fg : Theme.border; border.width: 1
                  Text {
                    id: chipLabel; anchors.centerIn: parent
                    text: {
                      if (!root._altHeld) return modelData.label
                      if (modelData.key === "File") return "<u>F</u>iles"
                      if (modelData.key === "Url") return "<u>U</u>RL"
                      if (modelData.key === "All") return "<u>A</u>ll"
                      return modelData.label
                    }
                    textFormat: root._altHeld ? Text.RichText : Text.PlainText
                    color: root.sourceFilter === modelData.key ? Theme.bg : Theme.fg; font.family:Theme.monoFont; font.pixelSize:11; font.bold: root.sourceFilter === modelData.key
                  }
                  MouseArea { anchors.fill: parent; cursorShape:Qt.PointingHandCursor; onClicked: root.sourceFilter = modelData.key }
                }
              }
              Item { Layout.preferredWidth: 8 }
              Text { text: root.filtered.length + " / " + root.allEntries.length; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:11; Layout.alignment: Qt.AlignVCenter }
            }
          }

          ListView {
            id: listView
            Layout.fillWidth:true; Layout.fillHeight:true; clip:true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 6
            model: root.filtered
            currentIndex: root.selectedIndex
            onCurrentIndexChanged:{ root.selectedIndex=currentIndex; if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain)}
            delegate: Rectangle {
              id: del
              required property var modelData
              required property int index
              width: listView.width
              height: 40
              radius: Theme.radiusSm
              color: root.selectedIndex===index ? Theme.surfaceHover : Theme.surface
              border.color: root.selectedIndex===index ? Qt.alpha(Theme.fg,0.33) : Theme.border
              border.width:1
              RowLayout {
                anchors.fill: parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:10
                Text { text: del.modelData.isUrl ? "" : ""; color:Theme.fg; opacity:0.7; font.family:Theme.nerdFont; font.pixelSize:12; Layout.alignment:Qt.AlignVCenter }
                ColumnLayout { Layout.fillWidth:true; spacing:1
                  Text { text: del.modelData.title; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:12; elide:Text.ElideRight; Layout.fillWidth:true; horizontalAlignment: Text.AlignLeft; LayoutMirroring.enabled: false; font.bold: root.selectedIndex===del.index }
                  Text { text: del.modelData.path; color:Theme.fg; opacity:0.45; horizontalAlignment: Text.AlignLeft; LayoutMirroring.enabled: false; font.family:Theme.monoFont; font.pixelSize:10; elide:Text.ElideMiddle; Layout.fillWidth:true; visible: !del.modelData.isUrl || root.filtered.length<40 }
                }
                Text { text: del.modelData.isUrl ? "URL" : "FILE"; color: del.modelData.isUrl ? Theme.accent : Theme.fg; opacity: del.modelData.isUrl ? 1 : 0.45; font.family:Theme.monoFont; font.pixelSize:9; font.bold: del.modelData.isUrl }
              }
              MouseArea{ anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onEntered: if(!root._blockHover) root.selectedIndex=del.index; onClicked: root.activateAt(del.index) }
            }
            Text { anchors.centerIn: parent; visible: root.filtered.length===0; text: root.allEntries.length===0? "No history yet" : "No matches"; color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:13 }
          }

          RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 10
            Text { text:"󰘳+F Files"; color:Theme.fg; opacity:0.85; font.family:Theme.nerdFont; font.pixelSize:10; font.bold:true }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 10; color:Theme.border; opacity:0.6 }
            Text { text:"󰘳+U URLs"; color:Theme.fg; opacity:0.85; font.family:Theme.nerdFont; font.pixelSize:10; font.bold:true }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 10; color:Theme.border; opacity:0.6 }
            Text { text:"󰘳+A All"; color:Theme.fg; opacity:0.85; font.family:Theme.nerdFont; font.pixelSize:10; font.bold:true }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 10; color:Theme.border; opacity:0.6 }
            Text { text:"↵ Open"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 10; color:Theme.border; opacity:0.6 }
            Text { text:"Esc Close"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true }
          }
        }
        Component.onCompleted: if(root.visible) searchField.forceActiveFocus()
        Connections{ target: root; function onVisibleChanged(){ if(root.visible){ searchField.text=""; searchField.forceActiveFocus(); container.forceActiveFocus(); searchField.forceActiveFocus() } } }
      }
    }
  }
  }

  IpcHandler {
    target: "mpvHistory"
    function toggle(): string { root.toggle(); return root.visible?"open":"closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  GlobalShortcut { name:"mpvHistoryToggle"; description:"Toggle mpv history"; onPressed: root.toggle() }
}
