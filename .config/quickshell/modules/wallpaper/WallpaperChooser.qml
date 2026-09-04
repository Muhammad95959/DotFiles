pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

import "."
import "../common"

Scope {
  id: wallpaperRoot
  property bool visible: false

  function toggle() { visible = !visible }
  function open() { visible = true }
  function close() { visible = false }

  // ── Search / category ─────────────────────────────────────────────
  property string query: ""
  property string selectedCategory: "All"
  property int selectedIndex: 0
  property int columns: 5
  property bool _blockHover: false
  function _markKeyboard() { _blockHover = true }
  property string wallpapersPaths: Quickshell.env("HOME") + "/Backgrounds"
  property var allWallpapers: []
  property string thumbCacheDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-thumbs"

  function fileUrl(path) {
    // encode each segment to handle #, unicode, spaces
    return "file://" + path.split("/").map(c => c === "" ? "" : encodeURIComponent(c)).join("/")
  }

  function thumbUrl(path) {
    // use cached thumb if exists, else fallback to fileUrl with sourceSize downscale
    // disk cache key: simple hash via filename + mtime not needed; use fileUrl for now
    // Qt will cache downscaled via sourceSize
    return fileUrl(path)
  }

  readonly property var categories: [
    { key: "All",                label: "All" },
    { key: "Root",               label: "Root" },
    { key: "Arch",               label: "Arch" },
    { key: "Arabic_Calligraphy", label: "Arabic" },
    { key: "Catppuccin",         label: "Catppuccin" }
  ]

  function categoryOf(path) {
    // path like /home/.../Backgrounds/Arch/arch1.jpg -> Arch
    // root files have category Root
    const base = wallpapersPaths
    let rel = path
    if (rel.startsWith(base)) rel = rel.substring(base.length)
    // rel = /arch1.jpg or /Arch/arch1.jpg
    rel = rel.replace(/^\/+/, "")
    const parts = rel.split("/")
    if (parts.length === 1) return "Root"
    return parts[0]
  }

  function matchesCategory(path, cat) {
    if (cat === "All") return true
    return categoryOf(path) === cat
  }

  readonly property var filteredWallpapers: {
    const q = query.toLowerCase().trim()
    const cat = selectedCategory
    let list = []
    for (let i = 0; i < allWallpapers.length; i++) {
      const p = allWallpapers[i]
      if (!matchesCategory(p, cat)) continue
      if (q !== "") {
        const name = p.substring(p.lastIndexOf("/") + 1).toLowerCase()
        const hay = name + " " + p.toLowerCase()
        const toks = q.split(/\s+/)
        let ok = true
        for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) { ok = false; break }
        if (!ok) continue
      }
      list.push(p)
    }
    return list
  }

  onQueryChanged: selectedIndex = 0
  onSelectedCategoryChanged: selectedIndex = 0
  onVisibleChanged: { if (visible) { selectedIndex = 0; _blockHover = true; refreshWallpapers() } }

  function setWallpaper(path) {
    WallpaperManager.setWallpaper(path)
    close()
  }

  function setTransientWallpaper(path) {
    WallpaperManager.setTransientWallpaper(path)
    close()
  }

  // ── Scan wallpapers ───────────────────────────────────────────────
  property string _scanAccum: ""

  function ensureThumbCache() {
    Quickshell.execDetached(["sh", "-c", "mkdir -p \"" + thumbCacheDir + "\""])
  }

  function refreshWallpapers() {
    ensureThumbCache()
    _scanAccum = ""; allWallpapers = []; scanProc.running = true
  }

  Process {
    id: scanProc
    command: ["sh", "-c", "find \"$HOME/Backgrounds\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) ! -path '*/brave/*' ! -path '*/.git/*' ! -name \"active\" 2>/dev/null | sort -u"]
    stdout: SplitParser {
      onRead: data => {
        wallpaperRoot._scanAccum += data + "\n"
      }
    }
    onExited: {
      const raw = wallpaperRoot._scanAccum.split("\n").map(s => s.trim()).filter(s => s.length > 0)
      const uniq = [...new Set(raw)]
      uniq.sort()
      wallpaperRoot.allWallpapers = uniq
      // preselect startup wallpaper (not transient random)
      try {
        const cur = WallpaperManager.startupPath
        if (cur && cur.length > 0) {
          const idx = wallpaperRoot.filteredWallpapers.indexOf(cur)
          if (idx >= 0) wallpaperRoot.selectedIndex = idx
          else if (wallpaperRoot.filteredWallpapers.length > 0) {
            const allIdx = uniq.indexOf(cur)
            if (allIdx >= 0) {
              const cat = wallpaperRoot.categoryOf(cur)
              if (wallpaperRoot.categories.some(c => c.key === cat)) wallpaperRoot.selectedCategory = cat
              Qt.callLater(() => {
                const nIdx = wallpaperRoot.filteredWallpapers.indexOf(cur)
                if (nIdx >= 0) wallpaperRoot.selectedIndex = nIdx
              })
            }
          }
        }
      } catch(e) {}
      if (wallpaperRoot.selectedIndex >= wallpaperRoot.filteredWallpapers.length) wallpaperRoot.selectedIndex = 0
      if (wallpaperRoot.selectedIndex < 0) wallpaperRoot.selectedIndex = 0
    }
  }

  // ── Row-major helpers: Tab cycles, arrows do not ─────────────────
  function moveSelection(delta) {
    _markKeyboard()
    const n = filteredWallpapers.length; if (n === 0) return
    let ni = selectedIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; selectedIndex = ni
  }
  function moveHorizontal(dir) { _markKeyboard(); moveSelection(dir) }
  function moveHorizontalNoWrap(dir) {
    _markKeyboard()
    const n = filteredWallpapers.length; if (n === 0) return
    const cols = columns; const row = Math.floor(selectedIndex / cols)
    const col = selectedIndex % cols
    const rowStart = row * cols; const rowEnd = Math.min(rowStart + cols, n) - 1
    let nc = col + dir; if (nc < 0 || rowStart + nc > rowEnd) return
    selectedIndex = rowStart + nc
  }
  function moveVertical(dir) {
    _markKeyboard()
    const n = filteredWallpapers.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols; const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    let nr = row + dir; if (nr < 0) nr = rows - 1; if (nr >= rows) nr = 0
    let ni = nr * cols + col
    if (ni >= n) { for (let r = rows - 1; r >= 0; r--) { const cand = r * cols + col; if (cand < n) { ni = cand; break } } }
    selectedIndex = ni
  }
  function moveVerticalNoWrap(dir) {
    _markKeyboard()
    const n = filteredWallpapers.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols; const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    let nr = row + dir; if (nr < 0 || nr >= rows) return
    let ni = nr * cols + col; if (ni >= n) return; selectedIndex = ni
  }
  function goHome() { _markKeyboard(); if (filteredWallpapers.length > 0) selectedIndex = 0 }
  function goEnd() { _markKeyboard(); const n = filteredWallpapers.length; if (n > 0) selectedIndex = n - 1 }
  function pageMove(dir) {
    _markKeyboard()
    const n = filteredWallpapers.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols; const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    let pageRows = 3; try { if (grid && grid.height > 0 && grid.cellHeight > 0) pageRows = Math.max(1, Math.floor(grid.height / grid.cellHeight)) } catch(e) {}
    let nr = row + dir * pageRows; if (nr < 0) nr = 0; if (nr >= rows) nr = rows - 1
    let ni = nr * cols + col
    if (ni >= n) { for (let r = rows - 1; r >= 0; r--) { const cand = r * cols + col; if (cand < n) { ni = cand; break } } if (ni >= n) ni = n - 1 }
    selectedIndex = ni
  }

  // ── Window ─────────────────────────────────────────────────────────
  LazyLoader {
    active: wallpaperRoot.visible

    Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      visible: wallpaperRoot.visible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors { top: true; bottom: true; left: true; right: true }

      MouseArea { anchors.fill: parent; onClicked: wallpaperRoot.close() }
      Rectangle { anchors.fill: parent; color: Theme.dim }

      // ── Centered 1600x900 ────────────────────────────────────────
      Rectangle {
        id: container
        width: 1600
        height: 900
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: { if (wallpaperRoot._blockHover) { wallpaperRoot._blockHover = false } }
                onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          // ── Header ─────────────────────────────────────────────────
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
              width: 32; height: 32; radius: 8
              color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; font.family: Theme.nerdFont; font.pixelSize: 14 }
            }
            ColumnLayout {
              spacing: 2
              Text { text: "Wallpaper"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 14; font.bold: true }
              Text { text: wallpaperRoot.filteredWallpapers.length + " wallpapers" + (wallpaperRoot.selectedCategory !== "All" ? " · " + wallpaperRoot.selectedCategory : ""); color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Text {
              text: " Refresh"
              color: Theme.fg; opacity: 0.6; font.family: Theme.monoFont; font.pixelSize: 11
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperRoot.refreshWallpapers() }
            }
            Rectangle {
              width: 28; height: 28; radius: 14; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 11 }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperRoot.close() }
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
                onTextChanged: wallpaperRoot.query = text
                onAccepted: { if (wallpaperRoot.filteredWallpapers.length > 0) wallpaperRoot.setWallpaper(wallpaperRoot.filteredWallpapers[wallpaperRoot.selectedIndex]) }
                Keys.onPressed: event => {
                  if (event.key === Qt.Key_Escape) { wallpaperRoot.close(); event.accepted = true }
                  else if (event.key === Qt.Key_Backtab) { wallpaperRoot.moveHorizontal(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) wallpaperRoot.moveHorizontal(-1); else wallpaperRoot.moveHorizontal(1); event.accepted = true
                  } else if (event.key === Qt.Key_Down) { wallpaperRoot.moveVerticalNoWrap(1); event.accepted = true }
                  else if (event.key === Qt.Key_Up) { wallpaperRoot.moveVerticalNoWrap(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Right) { wallpaperRoot.moveHorizontalNoWrap(1); event.accepted = true }
                  else if (event.key === Qt.Key_Left) { wallpaperRoot.moveHorizontalNoWrap(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Home) { wallpaperRoot.goHome(); event.accepted = true }
                  else if (event.key === Qt.Key_End) { wallpaperRoot.goEnd(); event.accepted = true }
                  else if (event.key === Qt.Key_PageUp) { wallpaperRoot.pageMove(-1); event.accepted = true }
                  else if (event.key === Qt.Key_PageDown) { wallpaperRoot.pageMove(1); event.accepted = true }
                  else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (wallpaperRoot.filteredWallpapers.length > 0) wallpaperRoot.setWallpaper(wallpaperRoot.filteredWallpapers[wallpaperRoot.selectedIndex]); event.accepted = true
                  }
                }
                Text {
                  anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                  text: "Search wallpapers..."; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 14; visible: searchField.text === ""
                }
              }
              Text {
                visible: searchField.text !== ""; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 12
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchField.text = ""; wallpaperRoot.query = "" } }
              }
            }
          }

          // ── Categories ─────────────────────────────────────────────
          Flickable {
            id: catFlick
            Layout.fillWidth: true; height: 32; contentWidth: catRow.width; contentHeight: 32; clip: true
        LayoutMirroring.enabled: false
            flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
            RowLayout {
              id: catRow; height: 32; spacing: 8
              x: Math.max(0, (catFlick.width - width) / 2)
              Repeater {
                model: wallpaperRoot.categories
                Rectangle {
                  required property var modelData
                  height: 28; width: catLabel.width + 22; radius: 14
                  color: wallpaperRoot.selectedCategory === modelData.key ? Theme.fg : Theme.surface
                  border.color: wallpaperRoot.selectedCategory === modelData.key ? Theme.fg : Theme.border; border.width: 1
                  Text { id: catLabel; anchors.centerIn: parent; text: modelData.label; color: wallpaperRoot.selectedCategory === modelData.key ? Theme.bg : Theme.fg; font.family: Theme.monoFont; font.pixelSize: 11; font.bold: wallpaperRoot.selectedCategory === modelData.key }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperRoot.selectedCategory = modelData.key }
                }
              }
            }
          }

          Item {
            id: sepContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            clip: false
            Rectangle {
              id: sepLine
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: 1
              color: Theme.border
              opacity: 0.6
            }
            Rectangle {
              id: sepThumb
              height: 3
              radius: 1.5
              width: Math.max(32, sepContainer.width * (grid ? grid.visibleArea.heightRatio : 0))
              y: (sepContainer.height - height) / 2
              x: {
                if (!grid || grid.contentHeight <= grid.height) return 0
                const maxY = grid.contentHeight - grid.height
                return (grid.contentY / Math.max(1, maxY)) * (sepContainer.width - width)
              }
              color: sepMouse.containsMouse || sepMouse.drag.active ? Theme.fg : Qt.alpha(Theme.fg, 0.55)
              opacity: grid && grid.contentHeight > grid.height ? 1 : 0
              visible: grid && grid.contentHeight > grid.height
              Behavior on color { ColorAnimation { duration: 120 } }
              Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            MouseArea {
              id: sepMouse
              anchors.fill: parent
              hoverEnabled: true
              drag.target: sepThumb
              drag.axis: Drag.XAxis
              drag.minimumX: 0
              drag.maximumX: sepContainer.width - sepThumb.width
              onPositionChanged: if (drag.active) {
                const ratio = sepThumb.x / Math.max(1, sepContainer.width - sepThumb.width)
                if (grid) grid.contentY = ratio * (grid.contentHeight - grid.height)
              }
              onPressed: mouse => {
                if (mouse.x < sepThumb.x || mouse.x > sepThumb.x + sepThumb.width) {
                  const ratio = (mouse.x - sepThumb.width / 2) / Math.max(1, sepContainer.width - sepThumb.width)
                  const clamped = Math.max(0, Math.min(1, ratio))
                  if (grid) grid.contentY = clamped * (grid.contentHeight - grid.height)
                }
              }
              onWheel: wheel => wheel.accepted = false
            }
          }

          // ── Grid ───────────────────────────────────────────────────
          Item {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            GridView {
              id: grid
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.min(parent.width, wallpaperRoot.columns * cellWidth)
              clip: true
              cellWidth: 308; cellHeight: 176
            cacheBuffer: 200
            model: wallpaperRoot.filteredWallpapers
            currentIndex: wallpaperRoot.selectedIndex
            onCurrentIndexChanged: wallpaperRoot.selectedIndex = currentIndex
            highlightMoveDuration: 80

            WheelHandler {
              acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
              onWheel: event => {
                const delta = event.angleDelta.y
                if (delta === 0) return
                const step = grid.cellHeight
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
              readonly property bool _isRight: {
                const cols = wallpaperRoot.columns
                const n = wallpaperRoot.filteredWallpapers.length
                const row = Math.floor(index / cols)
                const rowEnd = Math.min(row * cols + cols, n) - 1
                return index === rowEnd
              }
              width: grid.cellWidth - (_isRight ? 0 : 8); height: grid.cellHeight - 8
              radius: Theme.radiusMd
              color: wallpaperRoot.selectedIndex === index ? Theme.surfaceHover : Theme.surface
              border.color: wallpaperRoot.selectedIndex === index ? Qt.alpha(Theme.fg, 0.33) : Theme.border
              border.width: wallpaperRoot.selectedIndex === index ? 1 : 1
              clip: true

              // thumbnail - cached, downscaled, encoded for #/unicode
              Image {
                id: thumb
                anchors.fill: parent
                anchors.margins: 4
                source: wallpaperRoot.fileUrl(del.modelData)
                asynchronous: true
                cache: true
                mipmap: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                sourceSize.width: 460
                sourceSize.height: 280
              }

              // dim overlay
              Rectangle {
                anchors.fill: parent; radius: parent.radius
                color: "#00000000"
                border.color: "transparent"
              }

              // label bar at bottom - bottom corners rounded to match card
              Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 26
                // bottom only rounded, matches delegate Theme.radiusMd
                radius: Theme.radiusMd
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: Theme.radiusMd
                bottomRightRadius: Theme.radiusMd
                color: wallpaperRoot.selectedIndex === del.index ? Theme.fg : Theme.bg
                opacity: wallpaperRoot.selectedIndex === del.index ? 0.92 : 0.78
                clip: true
                Text {
                  anchors.centerIn: parent
                  width: parent.width - 8
                  text: del.modelData.substring(del.modelData.lastIndexOf("/") + 1)
                  color: wallpaperRoot.selectedIndex === del.index ? Theme.bg : Theme.fg
                  font.family: Theme.monoFont; font.pixelSize: 10; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter
                }
              }

              // selected check
              Rectangle {
                visible: wallpaperRoot.selectedIndex === del.index
                width: 22; height: 22; radius: 11
                color: Theme.fg; border.color: Theme.bg; border.width: 1
                anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: 8; anchors.rightMargin: 8
                Text { anchors.centerIn: parent; text: ""; color: Theme.bg; font.family: Theme.nerdFont; font.pixelSize: 11 }
              }

              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { if (wallpaperRoot.selectedIndex === del.index) wallpaperRoot.setWallpaper(del.modelData); else wallpaperRoot.selectedIndex = del.index }
              }
            }

            Text {
              anchors.centerIn: parent; visible: wallpaperRoot.filteredWallpapers.length === 0
              text: "No wallpapers"; color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 13
            }
          }
          }

        }

        Component.onCompleted: if (wallpaperRoot.visible) searchField.forceActiveFocus()
        Connections { target: wallpaperRoot; function onVisibleChanged() { if (wallpaperRoot.visible) { searchField.text = ""; searchField.forceActiveFocus(); wallpaperRoot.refreshWallpapers() } } }
      }
    }
  }

  // ── IPC ────────────────────────────────────────────────────────────
  }

  IpcHandler {
    target: "wallpaper"
    function toggle() { wallpaperRoot.toggle() }
    function open() { wallpaperRoot.open() }
    function close() { wallpaperRoot.close() }
    function set(wallpaperPath: string) { wallpaperRoot.setTransientWallpaper(wallpaperPath) }
    function random() { WallpaperManager.setRandomWallpaper() }
  }

  GlobalShortcut {
    name: "wallpaperToggle"
    description: "Toggle wallpaper chooser"
    onPressed: wallpaperRoot.toggle()
  }
}
