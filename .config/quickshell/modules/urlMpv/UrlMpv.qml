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
  function open() { visible = true; fetchClipboard() }
  function close() { visible = false }

  property string clipboardUrl: ""
  property string shortUrl: ""
  property int selectedIndex: 4 // default 720p
  property var qualities: ["144p","240p","360p","480p","720p","1080p"]
  property bool _blockHover: false
  function _markKeyboard(){ _blockHover=true }

  readonly property string currentQuality: qualities[selectedIndex] ?? "720p"
  readonly property string heightVal: currentQuality.replace("p","")

  function fetchClipboard() {
    _accum = ""; clipProc.running = true
  }
  property string _accum: ""
  Process {
    id: clipProc
    command: ["sh","-c","wl-paste 2>/dev/null | head -c 2048 | tr -d '\\n' | head -c 2048"]
    stdout: SplitParser { onRead: data => root._accum += data }
    onExited: {
      const url = root._accum.trim()
      root.clipboardUrl = url
      const maxLen = 55
      let s = url.slice(0, maxLen)
      if (url.length > maxLen) s += "…"
      root.shortUrl = s
      if (url.length === 0) root.shortUrl = "Clipboard empty — copy a URL first"
    }
  }

  function activate() {
    if (clipboardUrl.trim().length === 0) return
    const h = heightVal
    const url = clipboardUrl
    Quickshell.execDetached(["sh","-c","mpv --ytdl-format=\"bestvideo[height<=" + h + "]+bestaudio/best[height<=" + h + "]\" '" + url.replace(/'/g,"'\\''") + "' >/dev/null 2>&1 &"])
    close()
  }
  function move(delta){
    _markKeyboard(); const n=qualities.length; let ni=selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni
  }
  function moveNoWrap(delta){
    _markKeyboard(); const n=qualities.length; const ni=selectedIndex+delta; if(ni<0||ni>=n) return; selectedIndex=ni
  }
  function goHome(){ _markKeyboard(); selectedIndex=0 }
  function goEnd(){ _markKeyboard(); selectedIndex=qualities.length-1 }
  function pageMove(dir){
    _markKeyboard(); const n=qualities.length; let page=6; try{ const h=qList? qList.height:0; if(h>0) page=Math.max(1, Math.floor(h/38))}catch(e){} let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni
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
      WlrLayershell.namespace: "quickshell-url-mpv"
      anchors { top:true; bottom:true; left:true; right:true }

      MouseArea{ anchors.fill: parent; onClicked: root.close() }
      Rectangle{ anchors.fill: parent; color: Theme.dim }

      Rectangle {
        id: container
        focus: true
        Keys.onPressed: event => {
          if (event.key===Qt.Key_Escape){ root.close(); event.accepted=true}
          else if (event.key===Qt.Key_Backtab){ root.move(-1); event.accepted=true}
          else if (event.key===Qt.Key_Tab){
            if (event.modifiers & Qt.ShiftModifier) root.move(-1); else root.move(1); event.accepted=true
          }
          else if (event.key===Qt.Key_Up){ root.moveNoWrap(-1); event.accepted=true}
          else if (event.key===Qt.Key_Down){ root.moveNoWrap(1); event.accepted=true}
          else if (event.key===Qt.Key_Left){ root.moveNoWrap(-1); event.accepted=true}
          else if (event.key===Qt.Key_Right){ root.moveNoWrap(1); event.accepted=true}
          else if (event.key===Qt.Key_Home){ root.goHome(); event.accepted=true}
          else if (event.key===Qt.Key_End){ root.goEnd(); event.accepted=true}
          else if (event.key===Qt.Key_PageUp){ root.pageMove(-1); event.accepted=true}
          else if (event.key===Qt.Key_PageDown){ root.pageMove(1); event.accepted=true}
          else if (event.key===Qt.Key_Return||event.key===Qt.Key_Enter){ root.activate(); event.accepted=true}
        }
        Component.onCompleted: if(root.visible) forceActiveFocus()
        Connections{ target: root; function onVisibleChanged(){ if(root.visible) container.forceActiveFocus() } }
        width: 640
        height: 460
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        clip: true
        LayoutMirroring.enabled: false
        MouseArea{ anchors.fill: parent; hoverEnabled:true; onPositionChanged: if(root._blockHover) root._blockHover=false; onClicked:{} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          // ── Header ───────────────────────────────────────────────
          RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle { width:32; height:32; radius:8; color:Theme.surface; border.color:Theme.border; border.width:1
              Text { anchors.centerIn: parent; text:"󰛨"; color:Theme.accent; font.family:Theme.nerdFont; font.pixelSize:14 }
            }
            ColumnLayout { spacing:2
              Text { text:"Open URL in MPV"; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:14; font.bold:true }
              Text { text: root.clipboardUrl==="" ? "No URL" : root.currentQuality + " • " + qualities.length + " qualities"; color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:11 }
            }
            Item { Layout.fillWidth:true }
            Rectangle { width:28; height:28; radius:14; color:Theme.surface; border.color:Theme.border; border.width:1
              Text { anchors.centerIn: parent; text:""; color:Theme.fg; opacity:0.6; font.family:Theme.nerdFont; font.pixelSize:11 }
              MouseArea { anchors.fill: parent; cursorShape:Qt.PointingHandCursor; onClicked: root.fetchClipboard() }
            }
            Rectangle { width:28; height:28; radius:14; color:Theme.surface; border.color:Theme.border; border.width:1
              Text { anchors.centerIn: parent; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:11 }
              MouseArea { anchors.fill: parent; cursorShape:Qt.PointingHandCursor; onClicked: root.close() }
            }
          }

          // ── URL preview (the -mesg) ──────────────────────────────
          Rectangle {
            Layout.fillWidth:true; height:42; radius:Theme.radiusMd; color:Theme.surface; border.color: Theme.border; border.width:1
            RowLayout {
              anchors.fill: parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:8
              Text { text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:14; Layout.alignment: Qt.AlignVCenter }
              Text {
                Layout.fillWidth:true
                text: root.shortUrl
                color: root.clipboardUrl==="" ? Qt.alpha(Theme.fg,0.5) : Theme.fg
                font.family:Theme.monoFont; font.pixelSize:12
                elide: Text.ElideMiddle; maximumLineCount:1
                verticalAlignment: Text.AlignVCenter
              }
              Rectangle {
                visible: root.clipboardUrl!==""
                width: copyText.implicitWidth+12; height:22; radius:6; color: Qt.alpha(Theme.accent,0.15); border.color: Qt.alpha(Theme.accent,0.3); border.width:1
                Text { id: copyText; anchors.centerIn: parent; text:"URL"; color:Theme.accent; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true }
              }
            }
          }
          Text { Layout.fillWidth:true; text: "Select quality → mpv --ytdl-format"; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:10; horizontalAlignment: Text.AlignHCenter; visible: root.clipboardUrl!=="" }

          // ── Quality list ─────────────────────────────────────────
          ListView {
            id: qList
            Layout.fillWidth:true; Layout.fillHeight:true; clip:true; spacing:6
            boundsBehavior: Flickable.StopAtBounds
            model: root.qualities
            currentIndex: root.selectedIndex
            onCurrentIndexChanged:{ root.selectedIndex=currentIndex; if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain)}
            delegate: Rectangle {
              id: del; required property var modelData; required property int index
              width: qList.width; height:40; radius:Theme.radiusSm
              color: root.selectedIndex===index ? Theme.surfaceHover : Theme.surface
              border.color: root.selectedIndex===index ? Qt.alpha(Theme.accent,0.5) : Theme.border
              border.width:1
              RowLayout{
                anchors.fill: parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:10
                Rectangle { width:26; height:26; radius:6; color: root.selectedIndex===del.index ? Qt.alpha(Theme.accent,0.18) : Qt.alpha(Theme.fg,0.06); border.color: root.selectedIndex===del.index ? Qt.alpha(Theme.accent,0.3) : "transparent"; border.width:1
                  Text { anchors.centerIn: parent; text:""; color: root.selectedIndex===del.index ? Theme.accent : Theme.fg; opacity: root.selectedIndex===del.index ? 1 : 0.6; font.family:Theme.nerdFont; font.pixelSize:11 }
                }
                ColumnLayout { spacing:0; Layout.preferredWidth: 70
                  Text{ text: del.modelData; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:12; font.bold: true; lineHeight: 1 }
                  Text{
                    text: {
                      if(del.modelData==="1080p") return "1920×1080"
                      if(del.modelData==="720p") return "1280×720"
                      if(del.modelData==="480p") return "854×480"
                      if(del.modelData==="360p") return "640×360"
                      if(del.modelData==="240p") return "426×240"
                      return "256×144"
                    }
                    color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:9; lineHeight:1
                  }
                }
                Item { Layout.fillWidth:true }
                Rectangle {
                  Layout.preferredWidth: labelText.implicitWidth + 14; Layout.preferredHeight: 22; radius:11
                  color: root.selectedIndex===del.index ? Theme.accent : Qt.alpha(Theme.fg,0.08)
                  border.color: root.selectedIndex===del.index ? Theme.accent : Qt.alpha(Theme.fg,0.12)
                  border.width:1
                  Text { id: labelText; anchors.centerIn: parent; text: del.modelData==="1080p" ? "Full HD" : del.modelData==="720p" ? "HD" : del.modelData==="480p" ? "SD" : del.modelData==="360p" ? "nHD" : del.modelData==="240p" ? "Low" : "Min"; color: root.selectedIndex===del.index ? Theme.bg : Theme.fg; opacity: root.selectedIndex===del.index ? 1 : 0.7; font.family:Theme.monoFont; font.pixelSize:10; font.bold: root.selectedIndex===del.index }
                }
                Text { text:"󰄬"; color:Theme.accent; font.family:Theme.nerdFont; font.pixelSize:14; visible: root.selectedIndex===del.index; Layout.alignment: Qt.AlignVCenter }
              }
              MouseArea{ anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onClicked: { if (root.selectedIndex === del.index) root.activate(); else root.selectedIndex = del.index } }
            }
          }

          RowLayout { Layout.alignment:Qt.AlignHCenter; spacing:10
            Text { text:"↵ Play"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true}
            Rectangle{width:1;height:10;color:Theme.border;opacity:0.6}
            Text { text:"Esc Close"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true}
          }
        }
      }
    }
  }

  }

  IpcHandler{
    target:"urlMpv"
    function toggle(): string{ root.toggle(); return root.visible?"open":"closed"}
    function open(): string{ root.open(); return "ok"}
    function close(): string{ root.close(); return "ok"}
  }
  GlobalShortcut{ name:"urlMpvToggle"; description:"Toggle url→mpv"; onPressed: root.toggle()}
}
