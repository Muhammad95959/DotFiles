pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../common"

Scope {
  id: killerRoot
  property bool visible: false
  function toggle() { visible = !visible }
  function open() { visible = true; refresh() }
  function close() { visible = false }

  // ── Search state ───────────────────────────────────────────────────
  property string query: ""
  property int selectedIndex: 0
  property var allApps: [] // {pid, mem, comm, raw}

  readonly property var filteredApps: {
    const q = query.toLowerCase().trim()
    if (q === "") return allApps
    const toks = q.split(/\s+/)
    return allApps.filter(a => {
      const hay = (a.pid + " " + a.mem + " " + a.comm).toLowerCase()
      for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) return false
      return true
    })
  }

  onQueryChanged: selectedIndex = 0
  onVisibleChanged: { if (visible) { selectedIndex = 0; _blockHover = true; refresh() } }

  function refresh() {
    _accum = ""; allApps = []; psProc.running = true
  }

  function killAt(idx) {
    const list = filteredApps
    if (idx < 0 || idx >= list.length) return
    const app = list[idx]
    const pid = app.pid
    Quickshell.execDetached(["sh", "-c", "kill '" + pid.replace(/'/g,"'\\''") + "'"])
    close()
    Qt.callLater(() => { if (!visible) refresh() })
  }
  function killAllAt(idx) {
    const list = filteredApps
    if (idx < 0 || idx >= list.length) return
    const app = list[idx]
    const comm = app.comm
    Quickshell.execDetached(["sh", "-c", "killall '" + comm.replace(/'/g,"'\\''") + "'"])
    close()
    Qt.callLater(() => { if (!visible) refresh() })
  }

  // ── Scan processes ─────────────────────────────────────────────────
  property string _accum: ""
  Process {
    id: psProc
    // ps sorted by mem, skip header, keep pid mem comm
    command: ["sh", "-c", "ps -eo pid,%mem,comm --sort=-%mem | tail -n +2 | head -n 200"]
    stdout: SplitParser {
      onRead: data => {
        killerRoot._accum += data + "\n"
      }
    }
    onExited: {
      const lines = killerRoot._accum.split("\n").filter(s => s.trim().length > 0)
      let out = []
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim()
        // split by whitespace: pid, mem, comm (comm may have no spaces)
        const parts = line.trim().split(/\s+/)
        if (parts.length < 3) continue
        const pid = parts[0]
        const mem = parts[1]
        const comm = parts.slice(2).join(" ")
        if (pid === "PID") continue
        out.push({ pid: pid, mem: mem, comm: comm, raw: line })
      }
      killerRoot.allApps = out
      if (killerRoot.selectedIndex >= killerRoot.filteredApps.length) killerRoot.selectedIndex = 0
    }
  }

  // ── Helpers for keyboard (block hover after page) ────────────────
  property bool _blockHover: false
  function _markKeyboard() { _blockHover = true }
  function move(delta) {
    _markKeyboard()
    const n = filteredApps.length; if (n===0) return
    let ni = selectedIndex + delta; if (ni < 0) ni = n-1; if (ni >= n) ni = 0; selectedIndex = ni
  }
  function moveNoWrap(delta) {
    _markKeyboard()
    const n = filteredApps.length; if (n===0) return
    const ni = selectedIndex + delta; if (ni<0||ni>=n) return; selectedIndex = ni
  }
  function goHome() { _markKeyboard(); if(filteredApps.length>0) selectedIndex=0 }
  function goEnd() { _markKeyboard(); const n=filteredApps.length; if(n>0) selectedIndex=n-1 }
  function pageMove(dir) {
    _markKeyboard()
    const n=filteredApps.length; if(n===0) return
    let page = 10
    try {
      const h = listView ? listView.height : 0
      if (h > 0) page = Math.max(1, Math.floor(h / 42))
      else page = Math.max(1, Math.floor(400 / 42))
    } catch(e) { page = 10 }
    let ni = selectedIndex + dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni
    try { if (typeof listView !== "undefined" && listView) listView.positionViewAtIndex(ni, ListView.Contain) } catch(e) {}
  }

  // ── Window ─────────────────────────────────────────────────────────
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      visible: killerRoot.visible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors { top: true; bottom: true; left: true; right: true }

      MouseArea { anchors.fill: parent; onClicked: killerRoot.close() }
      Rectangle { anchors.fill: parent; color: Theme.dim }

      // ── Centered 900x600 ──────────────────────────────────────────
      Rectangle {
        id: container
        width: 900
        height: 600
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        clip: true
        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: { if (killerRoot._blockHover) { killerRoot._blockHover = false } }
                onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          // ── Header ─────────────────────────────────────────────────
          RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle { width: 32; height: 32; radius: 8; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: "󰽉"; color: Theme.fg; font.family: Theme.nerdFont; font.pixelSize: 14 }
            }
            ColumnLayout { spacing: 2
              Text { text: "Kill Application"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 14; font.bold: true }
              Text { text: filteredApps.length + " processes • sorted by %MEM"; color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
              width: 28; height: 28; radius: 14; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.6; font.family: Theme.nerdFont; font.pixelSize: 11 }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: killerRoot.refresh() }
            }
            Rectangle {
              width: 28; height: 28; radius: 14; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 11 }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: killerRoot.close() }
            }
          }

          // ── Search ─────────────────────────────────────────────────
          Rectangle {
            Layout.fillWidth: true; height: 42; radius: Theme.radiusMd; color: Theme.surface; border.color: searchField.activeFocus ? Qt.alpha(Theme.fg, 0.40) : Theme.border; border.width: 1
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
              Text { text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 14 }
              TextInput {
                id: searchField
                Layout.fillWidth: true; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 14
                focus: true; activeFocusOnTab: false
                onTextChanged: killerRoot.query = text
                onAccepted: killerRoot.killAt(killerRoot.selectedIndex)
                Keys.onPressed: event => {
                  if (event.key === Qt.Key_Escape) { killerRoot.close(); event.accepted = true }
                  else if (event.key === Qt.Key_Backtab) { killerRoot.move(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) killerRoot.move(-1); else killerRoot.move(1); event.accepted = true
                  } else if (event.key === Qt.Key_Up) { killerRoot.moveNoWrap(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Down) { killerRoot.moveNoWrap(1); event.accepted = true }
                  else if (event.key === Qt.Key_Home) { killerRoot.goHome(); event.accepted = true }
                  else if (event.key === Qt.Key_End) { killerRoot.goEnd(); event.accepted = true }
                  else if (event.key === Qt.Key_PageUp) { killerRoot.pageMove(-1); event.accepted = true }
                  else if (event.key === Qt.Key_PageDown) { killerRoot.pageMove(1); event.accepted = true }
                  else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.modifiers & Qt.ControlModifier) killerRoot.killAllAt(killerRoot.selectedIndex)
                    else killerRoot.killAt(killerRoot.selectedIndex)
                    event.accepted = true
                  }
                }
                Text {
                  anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                  text: "Search pid / name..."; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 14; visible: searchField.text === ""
                }
              }
              Text {
                visible: searchField.text !== ""; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 12
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchField.text = ""; killerRoot.query = "" } }
              }
            }
          }

          // ── Column header ──────────────────────────────────────────
          Rectangle {
            Layout.fillWidth: true; height: 28; radius: Theme.radiusSm; color: Theme.surface; border.color: Theme.border; border.width: 1
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
              Text { text: "PID"; color: Theme.fg; opacity: 0.7; font.family: Theme.monoFont; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 80 }
              Text { text: "%MEM"; color: Theme.fg; opacity: 0.7; font.family: Theme.monoFont; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 60 }
              Text { text: "COMMAND"; color: Theme.fg; opacity: 0.7; font.family: Theme.monoFont; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
            }
          }

          // ── List ───────────────────────────────────────────────────
          // clip + StopAtBounds prevents scrolling out of visible boundaries
          ListView {
            id: listView
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 120
            keyNavigationWraps: false
            model: killerRoot.filteredApps
            currentIndex: killerRoot.selectedIndex
            onCurrentIndexChanged: {
              killerRoot.selectedIndex = currentIndex
              if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            }
            onCountChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            spacing: 6
            delegate: Rectangle {
              id: del
              required property var modelData
              required property int index
              width: listView.width
              height: 36
              radius: Theme.radiusSm
              color: killerRoot.selectedIndex === index ? Theme.surfaceHover : Theme.surface
              border.color: killerRoot.selectedIndex === index ? Qt.alpha(Theme.fg, 0.33) : Theme.border
              border.width: 1

              RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                Text {
                  text: del.modelData.pid
                  color: Theme.fg; opacity: killerRoot.selectedIndex === del.index ? 1 : 0.8
                  font.family: Theme.monoFont; font.pixelSize: 12; font.bold: killerRoot.selectedIndex === del.index
                  Layout.preferredWidth: 80
                }
                Text {
                  text: del.modelData.mem + "%"
                  color: {
                    const m = parseFloat(del.modelData.mem)
                    if (m > 10) return Theme.urgent
                    return Theme.fg
                  }
                  opacity: 0.9
                  font.family: Theme.monoFont; font.pixelSize: 12; Layout.preferredWidth: 60
                }
                Text {
                  text: del.modelData.comm
                  color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 12
                  Layout.fillWidth: true; elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onEntered: if (!killerRoot._blockHover) killerRoot.selectedIndex = del.index
                onClicked: mouse => {
                  if (mouse.button === Qt.RightButton) killerRoot.killAllAt(del.index)
                  else killerRoot.killAt(del.index)
                }
              }
            }

            Text {
              anchors.centerIn: parent; visible: killerRoot.filteredApps.length === 0
              text: "No processes"; color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 13
            }
          }

          // ── Footer options ─────────────────────────────────────────
          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Text { text: "Enter: kill"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
            Rectangle { width: 1; height: 10; color: Theme.border; opacity: 0.6 }
            Text { text: "Ctrl+Enter: killall"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
            Rectangle { width: 1; height: 10; color: Theme.border; opacity: 0.6 }
            Text { text: "Esc: close"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
          }
        }

        Component.onCompleted: if (killerRoot.visible) searchField.forceActiveFocus()
        Connections { target: killerRoot; function onVisibleChanged() { if (killerRoot.visible) { searchField.text = ""; searchField.forceActiveFocus() } } }
      }
    }
  }

  // ── IPC ────────────────────────────────────────────────────────────
  IpcHandler {
    target: "appkiller"
    function toggle() { killerRoot.toggle() }
    function open() { killerRoot.open() }
    function close() { killerRoot.close() }
  }

  GlobalShortcut {
    name: "appkillerToggle"
    description: "Toggle app killer"
    onPressed: killerRoot.toggle()
  }
}
