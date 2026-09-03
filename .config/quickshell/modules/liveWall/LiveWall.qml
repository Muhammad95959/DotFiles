pragma ComponentBehavior: Bound
import Quickshell.Hyprland
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../common"

Scope {
  id: root
  property bool visible: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true; query = ""; selectedIndex = 0; refresh() }
  function close() { visible = false }

  // ── State ──────────────────────────────────────────────────────────
  property string query: ""
  property int selectedIndex: 0
  property var allFiles: [] // basenames in ~/Backgrounds/Live
  property string activeFile: ""
  property string _accum: ""
  property bool _blockHover: false
  property bool isLiveActive: false
  function _markKeyboard() { _blockHover = true }

  // liveDir/activeLink/mpvSocket inlined as hardcoded paths (previously dead props)

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

  // ── Scan live wallpapers ─────────────────────────────────────────
  function refresh() {
    _accum = ""; allFiles = []; scanProc.running = true
  }
  function checkActive() {
    activeProc.running = true
    isLiveProc.running = true
  }

  Process {
    id: scanProc
    command: ["sh", "-c", "find \"$HOME/Backgrounds/Live\" -type f ! -name \"active\" -exec basename {} \\; 2>/dev/null | sort -u"]
    stdout: SplitParser { onRead: d => root._accum += d + "\n" }
    onExited: {
      const lines = root._accum.split("\n").map(s => s.trim()).filter(s => s.length > 0)
      root.allFiles = lines
      root.checkActive()
      if (root.selectedIndex >= root.filtered.length) root.selectedIndex = 0
    }
  }
  Process {
    id: activeProc
    command: ["sh", "-c", "basename \"$(readlink -f \"$HOME/Backgrounds/Live/active\" 2>/dev/null)\" 2>/dev/null || echo \"\""]
    stdout: SplitParser { onRead: d => root.activeFile = d.trim() }
  }
  Process {
    id: isLiveProc
    command: ["sh", "-c", "pgrep -x mpvpaper >/dev/null 2>&1 && echo yes || echo no"]
    stdout: SplitParser { onRead: d => root.isLiveActive = d.trim() === "yes" }
  }

  // ── Actions (no awww) ────────────────────────────────────────────
  // Static wallpapers are handled by WallpaperBackground (Quickshell native).
  // Live wallpapers are mpvpaper on eDP-1 with mpv ipc socket.
  function activateAt(idx) {
    const list = filtered; if (idx < 0 || idx >= list.length) return
    const chosen = list[idx]
    const esc = chosen.replace(/["$`\\]/g, "\\$&")
    Quickshell.execDetached(["sh", "-c",
      "ln -frs \"$HOME/Backgrounds/Live/" + esc + "\" \"$HOME/Backgrounds/Live/active\" 2>/dev/null; " +
      "pkill -9 -x mpvpaper 2>/dev/null; rm -f /tmp/mpv-socket 2>/dev/null; sleep 0.25; " +
      "if [ -f \"$HOME/Backgrounds/Live/active\" ]; then " +
      "  mpvpaper eDP-1 -fo \"input-ipc-server=/tmp/mpv-socket no-audio loop no-config\" \"$HOME/Backgrounds/Live/active\" 2>/dev/null & " +
      "  sleep 0.35; if pgrep -x mpvpaper >/dev/null 2>&1; then notify-send \"LiveWall\" \"" + esc + " → active (live)\" -t 1500 2>/dev/null; else notify-send \"LiveWall\" \"Failed to start\" -t 1500 2>/dev/null; fi; " +
      "else notify-send \"LiveWall\" \"No active file\" -t 1500 2>/dev/null; fi"
    ])
    activeFile = chosen; isLiveActive = true; syncTimer.restart(); close()
  }

  function toggleLive() {
    // QML state drives toggle (deterministic for IPC return), shell uses pkill -9 (SIGTERM ignored).
    if (isLiveActive) {
      Quickshell.execDetached(["sh", "-c", "pkill -9 -x mpvpaper 2>/dev/null; rm -f /tmp/mpv-socket 2>/dev/null; notify-send \"LiveWall\" \"Static\" -t 1200 2>/dev/null"])
      isLiveActive = false
    } else {
      Quickshell.execDetached(["sh", "-c",
        "if [ ! -e \"$HOME/Backgrounds/Live/active\" ]; then notify-send \"LiveWall\" \"No active video — pick one first\" -t 1500 2>/dev/null; exit 0; fi; " +
        "pkill -9 -x mpvpaper 2>/dev/null; sleep 0.2; " +
        "mpvpaper eDP-1 -fo \"input-ipc-server=/tmp/mpv-socket no-audio loop no-config\" \"$HOME/Backgrounds/Live/active\" 2>/dev/null & " +
        "sleep 0.4; if pgrep -x mpvpaper >/dev/null 2>&1; then notify-send \"LiveWall\" \"Live (mpvpaper)\" -t 1200 2>/dev/null; else notify-send \"LiveWall\" \"Failed to start mpvpaper\" -t 1500 2>/dev/null; fi"
      ])
      isLiveActive = true
    }
    syncTimer.restart()
  }
  Timer { id: syncTimer; interval: 650; repeat: false; onTriggered: isLiveProc.running = true }

  // ── Navigation helpers ───────────────────────────────────────────
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

  // ── Auto-pause: pause mpvpaper when tiled content is visible ────
  // Replaces livewall_auto_pause.sh (1s poll → socat /tmp/mpv-socket).
  // Uses Hyprland IPC via hyprctl + python for now; could be migrated to Quickshell.Hyprland later.
  Timer {
    interval: 1000; running: root.isLiveActive; repeat: true
    onTriggered: pauseCheck.running = true
  }
  Process {
    id: pauseCheck
    command: ["sh", "-c",
      "hyprctl clients -j 2>/dev/null | python3 -c \"\nimport json, subprocess, re, sys\ntry:\n    clients=json.load(sys.stdin)\nexcept:\n    sys.exit(0)\ntry:\n    mon=json.loads(subprocess.check_output(['hyprctl','monitors','-j']))\nexcept:\n    mon=[]\nactiveWs=None\nfor m in mon:\n    if m.get('focused'):\n        activeWs=m.get('activeWorkspace',{}).get('id'); break\nif activeWs is None and mon:\n    activeWs=mon[0].get('activeWorkspace',{}).get('id')\nfocused=[c for c in clients if c.get('focusHistoryID')==0]\nactiveClass=focused[0].get('class','') if focused else ''\nfs=set(c.get('workspace',{}).get('id') for c in clients if c.get('fullscreen')!=0)\ntiled=[c for c in clients if not c.get('floating') and c.get('workspace',{}).get('id')==activeWs]\nclasses=[c.get('class','') for c in tiled]\npat=re.compile(r'(kitty|Yazi)')\npause='yes' if (classes and not any(pat.search(x) for x in classes)) or (activeWs in fs and not pat.search(activeClass)) else 'no'\nprint(pause)\n\" 2>/dev/null | tr -d '\\n' | xargs -I{} sh -c 'test -S /tmp/mpv-socket && echo \"set pause {}\" | socat - /tmp/mpv-socket 2>/dev/null || true'"
    ]
  }

  // ── UI ─────────────────────────────────────────────────────────────
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
              Text { text: root.activeFile==="" ? "no active" : "active: " + root.activeFile + (root.isLiveActive ? " • live" : " • static"); color: root.isLiveActive?Theme.accent:Theme.fg; opacity:0.7; font.family:Theme.monoFont; font.pixelSize:11 }
            }
            Item { Layout.fillWidth:true }
            Rectangle {
              width: 90; height:28; radius:14
              color: root.isLiveActive ? Theme.accent : Theme.surface
              border.color: root.isLiveActive ? Theme.accent : Theme.border; border.width:1
              RowLayout { anchors.centerIn: parent; spacing:6
                Rectangle { width:10; height:10; radius:5; color: root.isLiveActive ? Theme.bg : Qt.alpha(Theme.fg,0.3) }
                Text { text: root.isLiveActive ? "Live" : "Static"; color: root.isLiveActive ? Theme.bg : Theme.fg; font.family:Theme.monoFont; font.pixelSize:11; font.bold:true }
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
            Layout.fillWidth:true; visible: root.isLiveActive
            text: "mpvpaper eDP-1 — auto-pause when tiled (not kitty/Yazi) / fullscreen"
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
                  color: modelData===root.activeFile ? Qt.alpha(Theme.accent,0.18) : Qt.alpha(Theme.fg,0.06)
                  border.color: modelData===root.activeFile ? Theme.accent : Theme.border; border.width:1
                  Text{ anchors.centerIn:parent; text: modelData===root.activeFile ? "" : ""; color: modelData===root.activeFile ? Theme.accent : Theme.fg; opacity:0.8; font.family:Theme.nerdFont; font.pixelSize:11 }
                }
                Text{
                  text: modelData; color: Theme.fg; font.family:Theme.monoFont; font.pixelSize:12
                  Layout.fillWidth:true; elide:Text.ElideMiddle
                  font.bold: root.selectedIndex===del.index || modelData===root.activeFile
                }
                Text{ text: modelData===root.activeFile ? "active" : ""; color:Theme.accent; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true; visible: modelData===root.activeFile }
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

  IpcHandler {
    target: "liveWall"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function toggleLive(): string { root.toggleLive(); return root.isLiveActive ? "live" : "static" }
  }
  GlobalShortcut { name: "liveWallToggle"; description: "Toggle live wall"; onPressed: root.toggle() }
}
