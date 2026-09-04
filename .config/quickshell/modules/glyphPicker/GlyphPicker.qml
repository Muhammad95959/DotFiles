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
  function open() { visible = true; query = ""; selectedIndex = 0; _altHeld = false; _blockHover = true; ensureData() }
  function openEmoji() { currentTab = "emoji"; sectionEmoji = "All"; visible = true; query = ""; selectedIndex = 0; _altHeld = false; _blockHover = true; ensureData() }
  function openNerd() { currentTab = "nerd"; sectionNerd = "All"; visible = true; query = ""; selectedIndex = 0; _altHeld = false; _blockHover = true; ensureData() }
  function openGlyphs() { currentTab = "unicode"; sectionUnicode = "All"; visible = true; query = ""; selectedIndex = 0; _altHeld = false; _blockHover = true; ensureData() }
  function close() { visible = false; _altHeld = false }

  property string currentTab: "emoji"
  property string query: ""
  property int selectedIndex: 0
  property bool _altHeld: false
  property bool _blockHover: false
  property int columns: 7

  readonly property var tabs: [
    { key: "emoji", label: "Emoji" },
    { key: "nerd", label: "Nerd" },
    { key: "unicode", label: "Unicode" }
  ]

  property var emojiEntries: []
  property var nerdEntries: []
  property var unicodeEntries: []
  property bool _emojiLoaded: false
  property bool _nerdLoaded: false
  property bool _unicodeLoaded: false

  property string sectionEmoji: "All"
  property string sectionNerd: "All"
  property string sectionUnicode: "All"

  readonly property var emojiCategories: {
    let set = {}
    for (let i = 0; i < emojiEntries.length; i++) set[emojiEntries[i].category] = true
    let cats = Object.keys(set).sort()
    cats.unshift("All")
    let out = []
    for (let i = 0; i < cats.length; i++) out.push({ key: cats[i], label: cats[i] })
    return out.length > 1 ? out : [{ key: "All", label: "All" }]
  }

  readonly property var nerdCategories: {
    let set = {}
    for (let i = 0; i < nerdEntries.length; i++) set[nerdEntries[i].prefix] = true
    let cats = Object.keys(set).sort()
    cats.unshift("All")
    let out = []
    for (let i = 0; i < cats.length; i++) out.push({ key: cats[i], label: cats[i] })
    return out.length > 1 ? out : [{ key: "All", label: "All" }]
  }

  readonly property var unicodeBlocks: {
    let set = {}
    for (let i = 0; i < unicodeEntries.length; i++) set[unicodeEntries[i].block] = true
    let blocks = Object.keys(set).sort()
    if (blocks.length === 0) return [{ key: "All", label: "All" }]
    blocks.unshift("All")
    let out = []
    for (let i = 0; i < blocks.length; i++) out.push({ key: blocks[i], label: blocks[i] })
    return out
  }

  property var currentSectionList: {
    if (currentTab === "emoji") return emojiCategories
    if (currentTab === "nerd") return nerdCategories
    return unicodeBlocks
  }

  property string _currentSectionKey: {
    if (currentTab === "emoji") return sectionEmoji
    if (currentTab === "nerd") return sectionNerd
    return sectionUnicode
  }

  readonly property var _activeSource: {
    if (currentTab === "emoji") return emojiEntries
    if (currentTab === "nerd") return nerdEntries
    return unicodeEntries
  }

  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    const toks = q === "" ? [] : q.split(/\s+/)
    let section = _currentSectionKey
    let src = _activeSource
    if (!src || src.length === 0) return []
    let pre = []
    if (section === "All") {
      pre = src
    } else {
      if (currentTab === "emoji") {
        for (let i = 0; i < src.length; i++) if (src[i].category === section) pre.push(src[i])
      } else if (currentTab === "nerd") {
        for (let i = 0; i < src.length; i++) if (src[i].prefix === section) pre.push(src[i])
      } else {
        for (let i = 0; i < src.length; i++) if (src[i].block === section) pre.push(src[i])
      }
    }
    if (toks.length === 0) return pre
    let out = []
    for (let i = 0; i < pre.length; i++) {
      const e = pre[i]
      const hay = (e.char + " " + (e.name || "") + " " + (e.detail || "") + " " + (e.category || "") + " " + (e.block || "")).toLowerCase()
      let ok = true
      for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) { ok = false; break }
      if (ok) out.push(e)
    }
    return out
  }

  function _markKeyboard() { _blockHover = true }

  onQueryChanged: selectedIndex = 0
  onCurrentTabChanged: { selectedIndex = 0; _blockHover = true; ensureData() }
  onSectionEmojiChanged: selectedIndex = 0
  onSectionNerdChanged: selectedIndex = 0
  onSectionUnicodeChanged: selectedIndex = 0
  onVisibleChanged: { if (visible) { selectedIndex = 0; _blockHover = true; _altHeld = false } else { _altHeld = false } }

  function ensureData() {
    if (currentTab === "emoji" && !_emojiLoaded) { _emojiLoaded = true; emojiProc.running = true }
    else if (currentTab === "nerd" && !_nerdLoaded) { _nerdLoaded = true; nerdProc.running = true }
    else if (currentTab === "unicode" && !_unicodeLoaded) { _unicodeLoaded = true; unicodeProc.running = true }
  }

  function copyAt(idx, doType) {
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    const e = list[idx]
    const ch = e.char
    if (!ch) return
    if (doType) {
      Quickshell.execDetached(["sh", "-c", "printf '%s' '" + ch.replace(/'/g, "'\\''") + "' | wl-copy 2>/dev/null; wtype -- '" + ch.replace(/'/g, "'\\''") + "' 2>/dev/null || ydotool type -- '" + ch.replace(/'/g, "'\\''") + "' 2>/dev/null || true"])
    } else {
      Quickshell.execDetached(["sh", "-c", "printf '%s' '" + ch.replace(/'/g, "'\\''") + "' | wl-copy 2>/dev/null; notify-send -t 1200 'Copied' '" + ch.replace(/'/g, "'\\''") + "  '\"$(printf '%s' '" + (e.name || "").replace(/'/g, "'\\''") + "' | head -c 40)\" 2>/dev/null || true"])
    }
    close()
  }

  function move(delta) { _markKeyboard(); const n = filtered.length; if (n === 0) return; let ni = selectedIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; selectedIndex = ni }
  function moveNoWrap(delta) { _markKeyboard(); const n = filtered.length; if (n === 0) return; const ni = selectedIndex + delta; if (ni < 0 || ni >= n) return; selectedIndex = ni }
  function moveHorizontalNoWrap(dir) {
    _markKeyboard()
    const n = filtered.length; if (n === 0) return
    const ni = selectedIndex + dir; if (ni < 0 || ni >= n) return
    selectedIndex = ni
  }
  function moveVerticalNoWrap(dir) {
    _markKeyboard()
    const n = filtered.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols
    const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    let nr = row + dir; if (nr < 0 || nr >= rows) return
    let ni = nr * cols + col; if (ni >= n) return
    selectedIndex = ni
  }
  function goHome() { _markKeyboard(); if (filtered.length > 0) selectedIndex = 0 }
  function goEnd() { _markKeyboard(); const n = filtered.length; if (n > 0) selectedIndex = n - 1 }
  function pageMove(dir) {
    _markKeyboard()
    const n = filtered.length; if (n === 0) return
    const cols = columns; const col = selectedIndex % cols
    const row = Math.floor(selectedIndex / cols); const rows = Math.ceil(n / cols)
    let pageRows = 4; try { if (grid && grid.height > 0 && grid.cellHeight > 0) pageRows = Math.max(1, Math.floor(grid.height / grid.cellHeight)) } catch (e) {}
    let nr = row + dir * pageRows; if (nr < 0) nr = 0; if (nr >= rows) nr = rows - 1
    let ni = nr * cols + col
    if (ni >= n) {
      for (let r = rows - 1; r >= 0; r--) { const cand = r * cols + col; if (cand < n) { ni = cand; break } }
      if (ni >= n) ni = n - 1
    }
    selectedIndex = ni
  }

  Process {
    id: emojiProc
    running: false
    command: ["cat", Quickshell.shellDir + "/modules/glyphPicker/data/emojis.json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.emojiEntries = JSON.parse(text) } catch (e) { root.emojiEntries = [] }
      }
    }
  }

  Process {
    id: nerdProc
    running: false
    command: ["cat", Quickshell.shellDir + "/modules/glyphPicker/data/nerdfonts.json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.nerdEntries = JSON.parse(text) } catch (e) { root.nerdEntries = [] }
      }
    }
  }

  Process {
    id: unicodeProc
    running: false
    command: ["cat", Quickshell.shellDir + "/modules/glyphPicker/data/unicode.json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.unicodeEntries = JSON.parse(text) } catch (e) { root.unicodeEntries = [] }
      }
    }
  }

  LazyLoader {
    active: root.visible

    Variants {
      model: Quickshell.screens

      PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        visible: root.visible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "quickshell-glyphPicker"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors { top: true; bottom: true; left: true; right: true }

      MouseArea { anchors.fill: parent; onClicked: root.close() }
      Rectangle { anchors.fill: parent; color: Theme.dim }

      Rectangle {
        id: container
        width: 960
        height: 720
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        clip: true
        focus: true
        LayoutMirroring.enabled: false

        Keys.onPressed: event => {
          const hasAlt = (event.modifiers & Qt.AltModifier) || event.key === Qt.Key_Alt
          if (hasAlt) root._altHeld = true
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_E) { root.currentTab = "emoji"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_N) { root.currentTab = "nerd"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_U) { root.currentTab = "unicode"; event.accepted = true; return }
          if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
          else if (event.key === Qt.Key_Alt) root._altHeld = true
        }
        Keys.onReleased: event => {
          if (event.key === Qt.Key_Alt) root._altHeld = false
          else root._altHeld = Boolean(event.modifiers & Qt.AltModifier)
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: if (root._blockHover) root._blockHover = false; onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle { width: 32; height: 32; radius: 8; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: root.currentTab === "emoji" ? "😀" : root.currentTab === "nerd" ? "󰀻" : "󰈚"; color: Theme.fg; font.family: root.currentTab === "emoji" ? "Noto Color Emoji" : Theme.nerdFont; font.pixelSize: 16 }
            }
            ColumnLayout {
              spacing: 2
              Text { text: root.currentTab === "emoji" ? "Emoji" : root.currentTab === "nerd" ? "Nerd Fonts" : "Unicode"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 14; font.bold: true }
              Text { text: root.filtered.length + " shown • " + root._activeSource.length + " in tab • " + root._currentSectionKey; color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Rectangle { width: 28; height: 28; radius: 14; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 11 }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
          }

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
              Text { text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 14 }
              TextInput {
                id: searchField
                Layout.fillWidth: true
                color: Theme.fg
                font.family: Theme.monoFont
                font.pixelSize: 14
                focus: true
                activeFocusOnTab: false
                onTextChanged: root.query = text
                onAccepted: root.copyAt(root.selectedIndex, false)
                Keys.onPressed: event => {
                  const hasAlt = (event.modifiers & Qt.AltModifier) || event.key === Qt.Key_Alt
                  if (hasAlt) root._altHeld = true
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_E) { root.currentTab = "emoji"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_N) { root.currentTab = "nerd"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_U) { root.currentTab = "unicode"; event.accepted = true; return }
                  if (event.key === Qt.Key_Escape) { if (text.length > 0) { text = ""; root.query = ""; event.accepted = true } else { root.close(); event.accepted = true } }
                  else if (event.key === Qt.Key_Backtab) { root.move(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Tab) { if (event.modifiers & Qt.ShiftModifier) root.move(-1); else root.move(1); event.accepted = true }
                  else if (event.key === Qt.Key_Up) { root.moveVerticalNoWrap(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Down) { root.moveVerticalNoWrap(1); event.accepted = true }
                  else if (event.key === Qt.Key_Left) { root.moveHorizontalNoWrap(-1); event.accepted = true }
                  else if (event.key === Qt.Key_Right) { root.moveHorizontalNoWrap(1); event.accepted = true }
                  else if (event.key === Qt.Key_Home) { root.goHome(); event.accepted = true }
                  else if (event.key === Qt.Key_End) { root.goEnd(); event.accepted = true }
                  else if (event.key === Qt.Key_PageUp) { root.pageMove(-1); event.accepted = true }
                  else if (event.key === Qt.Key_PageDown) { root.pageMove(1); event.accepted = true }
                  else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    const doType = Boolean(event.modifiers & Qt.ShiftModifier) || Boolean(event.modifiers & Qt.AltModifier)
                    root.copyAt(root.selectedIndex, doType); event.accepted = true
                  }
                  if (event.key === Qt.Key_Alt) root._altHeld = true
                }
                Keys.onReleased: event => {
                  if (event.key === Qt.Key_Alt) root._altHeld = false
                  else root._altHeld = Boolean(event.modifiers & Qt.AltModifier)
                }
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; visible: searchField.text === ""; text: "Search glyphs…"; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 14 }
              }
              Text { visible: searchField.text !== ""; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 12
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchField.text = ""; root.query = "" } }
              }
            }
          }

          Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            contentWidth: tabRow.width
            contentHeight: 34
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            RowLayout {
              id: tabRow
              height: 34
              spacing: 8
              Repeater {
                model: root.tabs
                Rectangle {
                  required property var modelData
                  height: 28
                  width: tabLabel.width + 26
                  radius: 14
                  color: root.currentTab === modelData.key ? Theme.fg : Theme.surface
                  border.color: root.currentTab === modelData.key ? Theme.fg : Theme.border
                  border.width: 1
                  Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: {
                      if (!root._altHeld) return modelData.label
                      if (modelData.key === "emoji") return "<u>E</u>moji"
                      if (modelData.key === "nerd") return "<u>N</u>erd"
                      if (modelData.key === "unicode") return "<u>U</u>nicode"
                      return modelData.label
                    }
                    textFormat: root._altHeld ? Text.RichText : Text.PlainText
                    color: root.currentTab === modelData.key ? Theme.bg : Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.bold: root.currentTab === modelData.key
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = modelData.key }
                }
              }
              Item { Layout.preferredWidth: 12 }
              Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 18; color: Theme.border; opacity: 0.5 }
              Item { Layout.preferredWidth: 4 }
              Text { text: "Alt+E/N/U switch • hold Alt for hints"; color: Theme.fg; opacity: 0.40; font.family: Theme.monoFont; font.pixelSize: 10; Layout.alignment: Qt.AlignVCenter }
            }
          }

          Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            contentWidth: sectionRow.width
            contentHeight: 32
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            RowLayout {
              id: sectionRow
              height: 32
              spacing: 8
              Repeater {
                model: root.currentSectionList
                Rectangle {
                  required property var modelData
                  height: 26
                  width: secLabel.width + 20
                  radius: 13
                  color: root._currentSectionKey === modelData.key ? Theme.accent : Theme.surface
                  border.color: root._currentSectionKey === modelData.key ? Theme.accent : Theme.border
                  border.width: 1
                  Text {
                    id: secLabel
                    anchors.centerIn: parent
                    text: modelData.label.length > 22 ? modelData.label.slice(0, 22) + "…" : modelData.label
                    color: root._currentSectionKey === modelData.key ? Theme.bg : Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.bold: root._currentSectionKey === modelData.key
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.currentTab === "emoji") root.sectionEmoji = modelData.key
                      else if (root.currentTab === "nerd") root.sectionNerd = modelData.key
                      else root.sectionUnicode = modelData.key
                    }
                  }
                }
              }
              Item { Layout.preferredWidth: 8 }
              Text { text: root.filtered.length + " / " + root._activeSource.length; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 11; Layout.alignment: Qt.AlignVCenter }
            }
          }

          Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; opacity: 0.6 }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            GridView {
              id: grid
              anchors.fill: parent
              anchors.rightMargin: 8
              clip: true
              cellWidth: 153
              cellHeight: 153
              model: root.filtered
              currentIndex: root.selectedIndex
              onCurrentIndexChanged: { root.selectedIndex = currentIndex; if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain) }
              highlightMoveDuration: 80
              boundsBehavior: Flickable.StopAtBounds
              flickDeceleration: 6000
              maximumFlickVelocity: 4800
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
                width: grid.cellWidth - 10
                height: grid.cellHeight - 10
                radius: Theme.radiusMd
                color: root.selectedIndex === index ? Theme.surfaceHover : "transparent"
                border.color: root.selectedIndex === index ? Qt.alpha(Theme.fg, 0.33) : "transparent"
                border.width: root.selectedIndex === index ? 1 : 0
                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 5
                  width: parent.width - 8
                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: del.modelData.char
                    color: Theme.fg
                    font.family: root.currentTab === "emoji" ? "Noto Color Emoji" : Theme.nerdFont
                    font.pixelSize: 72
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: del.modelData.name
                    color: Theme.fg
                    opacity: 0.75
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: if (!root._blockHover) root.selectedIndex = del.index
                  onClicked: root.copyAt(del.index, false)
                }
              }
              Text {
                anchors.centerIn: parent
                visible: root.filtered.length === 0
                text: root._activeSource.length === 0 ? "Loading…" : "No matches for \"" + root.query + "\""
                color: Theme.fg
                opacity: 0.55
                font.family: Theme.monoFont
                font.pixelSize: 13
              }
            }
            Rectangle {
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.right: parent.right
              width: 8
              radius: 3
              color: "transparent"
              visible: grid.contentHeight > grid.height
              Rectangle {
                id: thumb
                width: 5
                radius: 3
                x: (parent.width - width) / 2
                color: Theme.fg
                opacity: 0.35
                height: Math.max(24, grid.height * grid.visibleArea.heightRatio)
                y: grid.visibleArea.yPosition * grid.height
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: Theme.surface
            radius: Theme.radiusSm
            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 10
              Text { text: "↵ Copy"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
              Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
              Text { text: "⇧+↵ Type"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
              Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
              Text { text: "Alt+E/N/U Tabs"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
              Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
              Text { text: "Esc Close"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
              Item { Layout.fillWidth: true }
              Text { text: root.filtered.length + " shown"; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 10 }
            }
          }
        }
        Component.onCompleted: if (root.visible) searchField.forceActiveFocus()
        Connections { target: root; function onVisibleChanged() { if (root.visible) { searchField.text = ""; searchField.forceActiveFocus(); container.forceActiveFocus(); searchField.forceActiveFocus() } } }
      }
    }
  }
  }

  IpcHandler {
    target: "glyphPicker"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function openEmoji(): string { root.openEmoji(); return "ok" }
    function openNerd(): string { root.openNerd(); return "ok" }
    function openUnicode(): string { root.openGlyphs(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  IpcHandler { target: "emoji"; function toggle(): string { root.openEmoji(); return "ok" } function open(): string { root.openEmoji(); return "ok" } function close(): string { root.close(); return "ok" } }
  IpcHandler { target: "nerdfont"; function toggle(): string { root.openNerd(); return "ok" } function open(): string { root.openNerd(); return "ok" } function close(): string { root.close(); return "ok" } }
  IpcHandler { target: "unicode"; function toggle(): string { root.openGlyphs(); return "ok" } function open(): string { root.openGlyphs(); return "ok" } function close(): string { root.close(); return "ok" } }

  GlobalShortcut { name: "glyphPickerToggle"; description: "Toggle glyph picker"; onPressed: root.toggle() }
  GlobalShortcut { name: "emojiToggle"; description: "Toggle emoji picker"; onPressed: root.openEmoji() }
  GlobalShortcut { name: "nerdToggle"; description: "Toggle nerd picker"; onPressed: root.openNerd() }
  GlobalShortcut { name: "unicodeToggle"; description: "Toggle unicode picker"; onPressed: root.openGlyphs() }
}
