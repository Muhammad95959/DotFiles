pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../common"

Scope {
  id: launcherRoot
  property bool visible: false

  function toggle() { visible = !visible }
  function open() { visible = true }
  function close() { visible = false }

  // ── Search / category state ────────────────────────────────────────
  property string query: ""
  property string selectedCategory: "All"
  property int selectedIndex: 0
  property int columns: 3
  // ── Hover block after keyboard/page ─────────────────────────────────
  property bool _blockHover: false
  function _markKeyboard() { _blockHover = true }

  // freedesktop main categories + All
  readonly property var categories: [
    { key: "All",        label: "All"        },
    { key: "Development",label: "Dev"        },
    { key: "Office",     label: "Office"     },
    { key: "Graphics",   label: "Graphics"   },
    { key: "Network",    label: "Internet"   },
    { key: "AudioVideo", label: "Multimedia" },
    { key: "Game",       label: "Games"      },
    { key: "System",     label: "System"     },
    { key: "Utility",    label: "Utility"    },
    { key: "Settings",   label: "Settings"   }
  ]

  function matchesCategory(entry, cat) {
    if (cat === "All") return true
    const cats = entry.categories || []
    const lc = cat.toLowerCase()
    for (let i = 0; i < cats.length; i++) {
      const c = String(cats[i]).toLowerCase()
      if (c === lc) return true
      // aliases: Network <-> Internet, AudioVideo <-> Multimedia
      if (lc === "network" && (c === "internet" || c === "network")) return true
      if (lc === "audiovideo" && (c === "audiovideo" || c === "audio" || c === "video")) return true
    }
    return false
  }

  readonly property var filteredApps: {
    const q = query.toLowerCase().trim()
    const cat = selectedCategory
    const all = DesktopEntries.applications.values
    let list = []
    for (let i = 0; i < all.length; i++) {
      const e = all[i]
      if (e.noDisplay) continue
      if (!matchesCategory(e, cat)) continue
      if (q !== "") {
        const hay = [e.name, e.genericName, e.comment, (e.keywords||[]).join(" ")].join(" ").toLowerCase()
        const toks = q.split(/\s+/)
        let ok = true
        for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) { ok = false; break }
        if (!ok) continue
      }
      list.push(e)
    }
    list.sort((a,b) => {
      if (q === "") return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
      const an = a.name.toLowerCase(); const bn = b.name.toLowerCase()
      const aS = an.startsWith(q) ? 0 : an.includes(q) ? 1 : 2
      const bS = bn.startsWith(q) ? 0 : bn.includes(q) ? 1 : 2
      if (aS !== bS) return aS - bS
      return an.localeCompare(bn)
    })
    return list.slice(0, 120)
  }

  onQueryChanged: selectedIndex = 0
  onSelectedCategoryChanged: selectedIndex = 0
  onVisibleChanged: {
    if (visible) { query = ""; selectedCategory = "All"; selectedIndex = 0; _blockHover = true }
  }

  function launchAt(idx) {
    const arr = filteredApps
    if (idx < 0 || idx >= arr.length) return
    const e = arr[idx]
    if (e.runInTerminal) {
      // Quickshell's DesktopEntry.execute() ignores runInTerminal (see
      // https://quickshell.org/docs/v0.3.0/types/Quickshell/DesktopEntry/).
      // Wrap Terminal=true entries in a terminal emulator.
      // Prefer xdg-terminal-exec (freedesktop default-terminal-spec), fall
      // back to common terminals. The installed terminal on this system is
      // kitty, but we try a chain for portability.
      const cmd = e.command
      Quickshell.execDetached({
        // sh wrapper probes for available terminals at launch time
        command: ["sh", "-c", 'if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec "$@"; elif command -v kitty >/dev/null 2>&1; then exec kitty -e "$@"; elif command -v ghostty >/dev/null 2>&1; then exec ghostty -e "$@"; elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e "$@"; elif command -v foot >/dev/null 2>&1; then exec foot "$@"; elif command -v gnome-terminal >/dev/null 2>&1; then exec gnome-terminal -- "$@"; elif command -v xterm >/dev/null 2>&1; then exec xterm -e "$@"; else exec "$@"; fi', "sh"].concat(cmd),
        workingDirectory: e.workingDirectory
      })
    } else {
      e.execute()
    }
    close()
  }

  function moveSelection(delta) {
    _markKeyboard()
    const n = filteredApps.length
    if (n === 0) return
    let ni = selectedIndex + delta
    if (ni < 0) ni = n - 1
    if (ni >= n) ni = 0
    selectedIndex = ni
  }
  // ── Row-major helpers: Tab cycles, arrows do not ─────────────────
  function moveHorizontal(dir) { _markKeyboard(); moveSelection(dir) } // wrapping for Tab
  function moveHorizontalNoWrap(dir) {
    _markKeyboard()
    const n = filteredApps.length; if (n === 0) return
    const ni = selectedIndex + dir; if (ni < 0 || ni >= n) return
    selectedIndex = ni
  }
  function moveVerticalNoWrap(dir) {
    _markKeyboard()
    const n = filteredApps.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols
    const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    let nr = row + dir; if (nr < 0 || nr >= rows) return
    let ni = nr * cols + col; if (ni >= n) return
    selectedIndex = ni
  }
  function goHome() { _markKeyboard(); if (filteredApps.length > 0) selectedIndex = 0 }
  function goEnd() { _markKeyboard(); const n = filteredApps.length; if (n > 0) selectedIndex = n - 1 }
  function pageMove(dir) {
    _markKeyboard()
    const n = filteredApps.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols
    const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    let pageRows = 4; try { if (grid && grid.height > 0 && grid.cellHeight > 0) pageRows = Math.max(1, Math.floor(grid.height / grid.cellHeight)) } catch(e) {}
    let nr = row + dir * pageRows; if (nr < 0) nr = 0; if (nr >= rows) nr = rows - 1
    let ni = nr * cols + col
    if (ni >= n) { // incomplete last row -> stay in column if possible else clamp
      for (let r = rows - 1; r >= 0; r--) { const cand = r * cols + col; if (cand < n) { ni = cand; break } }
      if (ni >= n) ni = n - 1
    }
    selectedIndex = ni
  }

  // ── Windows ────────────────────────────────────────────────────────
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: launcherRoot.visible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      anchors { top: true; bottom: true; left: true; right: true }

      MouseArea {
        anchors.fill: parent
        onClicked: launcherRoot.close()
      }

      Rectangle {
        anchors.fill: parent
        color: Theme.dim
      }

      // ── Left tall container (below bar) ─────────────────────────────
      Rectangle {
        width: 454
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.topMargin: Config.barHeight + 12
        anchors.bottomMargin: 12
        radius: Theme.radiusLg
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: { if (launcherRoot._blockHover) { launcherRoot._blockHover = false } }
                onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          // ── Search ─────────────────────────────────────────────────
          Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: searchField.activeFocus ? Qt.alpha(Theme.fg, 0.40) : Theme.border
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 8

              Text {
                text: ""
                color: Theme.fg
                opacity: 0.55
                font.family: Theme.nerdFont
                font.pixelSize: 14
              }

              TextInput {
                id: searchField
                Layout.fillWidth: true
                color: Theme.fg
                font.family: Theme.monoFont
                font.pixelSize: 14
                focus: true
                activeFocusOnTab: false
                onTextChanged: launcherRoot.query = text
                onAccepted: launcherRoot.launchAt(launcherRoot.selectedIndex)

                Keys.onPressed: event => {
                  if (event.key === Qt.Key_Escape) { launcherRoot.close(); event.accepted = true }
                  else if (event.key === Qt.Key_Backtab) { launcherRoot.moveHorizontal(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) launcherRoot.moveHorizontal(-1)
                    else launcherRoot.moveHorizontal(1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Down) { launcherRoot.moveVerticalNoWrap(1); event.accepted = true }
                  else if (event.key === Qt.Key_Up) { launcherRoot.moveVerticalNoWrap(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Right) { launcherRoot.moveHorizontalNoWrap(1); event.accepted = true }
                  else if (event.key === Qt.Key_Left) { launcherRoot.moveHorizontalNoWrap(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Home) { launcherRoot.goHome(); event.accepted = true }
                  else if (event.key === Qt.Key_End) { launcherRoot.goEnd(); event.accepted = true }
                  else if (event.key === Qt.Key_PageUp) { launcherRoot.pageMove(-1); event.accepted = true }
                  else if (event.key === Qt.Key_PageDown) { launcherRoot.pageMove(1); event.accepted = true }
                  else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { launcherRoot.launchAt(launcherRoot.selectedIndex); event.accepted = true }
                }

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Search apps..."
                  color: Theme.fg
                  opacity: 0.45
                  font.family: Theme.monoFont
                  font.pixelSize: 14
                  visible: searchField.text === ""
                }
              }

              Text {
                visible: searchField.text !== ""
                text: ""
                color: Theme.fg
                opacity: 0.55
                font.family: Theme.nerdFont
                font.pixelSize: 12
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { searchField.text = ""; launcherRoot.query = "" }
                }
              }
            }
          }

          // ── Categories ─────────────────────────────────────────────
          Flickable {
            Layout.fillWidth: true
            height: 32
            contentWidth: catRow.width
            contentHeight: 32
            clip: true
        LayoutMirroring.enabled: false
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            RowLayout {
              id: catRow
              height: 32
              spacing: 8

              Repeater {
                model: launcherRoot.categories
                Rectangle {
                  required property var modelData
                  required property int index
                  height: 28
                  width: catLabel.width + 22
                  radius: 14
                  color: launcherRoot.selectedCategory === modelData.key ? Theme.fg : Theme.surface
                  border.color: launcherRoot.selectedCategory === modelData.key ? Theme.fg : Theme.border
                  border.width: 1

                  Text {
                    id: catLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    color: launcherRoot.selectedCategory === modelData.key ? Theme.bg : Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.bold: launcherRoot.selectedCategory === modelData.key
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcherRoot.selectedCategory = modelData.key
                  }
                }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; opacity: 0.6 }

          Text {
            text: launcherRoot.filteredApps.length + " apps" + (launcherRoot.selectedCategory !== "All" ? " · " + launcherRoot.selectedCategory : "")
            color: Theme.fg
            opacity: 0.55
            font.family: Theme.monoFont
            font.pixelSize: 11
          }

          // ── Grid ───────────────────────────────────────────────────
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridView {
              id: grid
              anchors.fill: parent
              anchors.rightMargin: 14
              clip: true
              cellWidth: 136
              cellHeight: 92
              model: launcherRoot.filteredApps
              currentIndex: launcherRoot.selectedIndex
              onCurrentIndexChanged: launcherRoot.selectedIndex = currentIndex
              highlightMoveDuration: 80
              boundsBehavior: Flickable.StopAtBounds
              flickDeceleration: 6000
              maximumFlickVelocity: 4800

              // Faster mouse-wheel: ~1.7 rows per notch vs default ~0.4
              WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                  const delta = event.angleDelta.y
                  if (delta === 0) return
                  const step = grid.cellHeight * 1.7
                  const dir = delta > 0 ? -1 : 1
                  const maxY = Math.max(0, grid.contentHeight - grid.height)
                  let nextY = grid.contentY + dir * step
                  nextY = Math.max(0, Math.min(maxY, nextY))
                  grid.contentY = nextY
                  event.accepted = true
                }
              }

              delegate: Rectangle {
                id: del
                required property var modelData
                required property int index
                width: grid.cellWidth - 8
                height: grid.cellHeight - 8
                radius: Theme.radiusMd
                color: launcherRoot.selectedIndex === index ? Theme.surfaceHover : "transparent"
                border.color: launcherRoot.selectedIndex === index ? Qt.alpha(Theme.fg, 0.33) : "transparent"
                border.width: launcherRoot.selectedIndex === index ? 1 : 0

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 6
                  width: parent.width - 12

                  IconImage {
                    Layout.alignment: Qt.AlignHCenter
                    implicitSize: 34
                    source: Quickshell.iconPath(del.modelData.icon, true)
                  }

                  Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: del.modelData.name
                    color: Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.bold: launcherRoot.selectedIndex === del.index
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: if (!launcherRoot._blockHover) launcherRoot.selectedIndex = del.index
                  onClicked: launcherRoot.launchAt(del.index)
                }
              }

              Text {
                anchors.centerIn: parent
                visible: launcherRoot.filteredApps.length === 0
                text: "No results"
                color: Theme.fg
                opacity: 0.55
                font.family: Theme.monoFont
                font.pixelSize: 13
              }
            }

            // Subtle overlay scrollbar (theme-aware) — gutter outside icons
            Rectangle {
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.right: parent.right
              width: 10
              radius: 3
              color: "transparent"
              visible: grid.contentHeight > grid.height

              Rectangle {
                id: sbThumb
                width: 6
                radius: 3
                x: (parent.width - width) / 2
                color: (sbDrag.drag.active || sbDrag.containsMouse || sbHover.containsMouse) ? Theme.fg : Qt.alpha(Theme.fg, 0.22)
                opacity: grid.moving || sbDrag.containsMouse || sbHover.containsMouse || sbDrag.drag.active ? 1 : 0.85
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                height: Math.max(28, grid.height * grid.visibleArea.heightRatio)
                y: grid.visibleArea.yPosition * grid.height
                visible: grid.contentHeight > grid.height
              }

              MouseArea {
                id: sbHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
              }

              MouseArea {
                id: sbDrag
                anchors.fill: parent
                hoverEnabled: true
                drag.target: sbThumb
                drag.axis: Drag.YAxis
                drag.minimumY: 0
                drag.maximumY: grid.height - sbThumb.height
                onPositionChanged: if (drag.active) {
                  const ratio = sbThumb.y / Math.max(1, grid.height - sbThumb.height)
                  grid.contentY = ratio * (grid.contentHeight - grid.height)
                }
                onPressed: mouse => {
                  if (mouse.y < sbThumb.y || mouse.y > sbThumb.y + sbThumb.height) {
                    const ratio = (mouse.y - sbThumb.height / 2) / Math.max(1, grid.height - sbThumb.height)
                    const clamped = Math.max(0, Math.min(1, ratio))
                    grid.contentY = clamped * (grid.contentHeight - grid.height)
                  }
                }
                onWheel: wheel => wheel.accepted = false
              }
            }
          }
        }

        Component.onCompleted: {
          if (launcherRoot.visible) searchField.forceActiveFocus()
        }
        Connections {
          target: launcherRoot
          function onVisibleChanged() {
            if (launcherRoot.visible) {
              searchField.text = ""
              searchField.forceActiveFocus()
            }
          }
        }
      }
    }
  }

  // ── IPC / Shortcut ─────────────────────────────────────────────────
  IpcHandler {
    target: "launcher"
    function toggle() { launcherRoot.toggle() }
    function open() { launcherRoot.open() }
    function close() { launcherRoot.close() }
  }

  GlobalShortcut {
    name: "launcherToggle"
    description: "Toggle app launcher"
    onPressed: launcherRoot.toggle()
  }
}
