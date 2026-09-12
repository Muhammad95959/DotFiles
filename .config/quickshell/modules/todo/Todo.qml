pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

// Todo list. Storage: todolist.txt next to this file ("<0|1><TAB><text>").
Scope {
  id: root
  property bool visible: false
  property bool _loading: false
  property bool _everLoaded: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true; query = ""; selectedIndex = 0; clearHold(); resetEditState(); refresh() }
  function close() { visible = false; query = ""; selectedIndex = 0; clearHold(); resetEditState() }

  property string query: ""
  property int selectedIndex: 0
  property var allEntries: []
  property int _pendingSel: -1
  property int _wantCy: -1
  property int _editFilteredIdx: -1
  property bool _editIsNew: false
  property string _editDraft: ""
  property var _editRef: null
  function resetEditState() { _editFilteredIdx = -1; _editIsNew = false; _editDraft = ""; _editRef = null }

  readonly property int drawerHeight: 470
  readonly property int rowHeight: 42
  readonly property int visibleRows: 8
  readonly property int listSpacing: 2
  readonly property int listMargins: 2
  readonly property int contentHeight: visibleRows * rowHeight + (visibleRows - 1) * listSpacing + listMargins * 2

  readonly property int pendingCount: {
    let n = 0
    for (let i = 0; i < allEntries.length; i++) if (!allEntries[i].done) n++
    return n
  }

  readonly property var filtered: {
    const toks = query.toLowerCase().trim().split(/\s+/).filter(t => t.length > 0)
    let out = []
    for (let i = 0; i < allEntries.length; i++) {
      const e = allEntries[i]
      const text = e.text || ""
      if (text === "" || toks.length === 0) { out.push(e); continue }
      const hay = text.toLowerCase()
      let ok = true
      for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) { ok = false; break }
      if (ok) out.push(e)
    }
    return out
  }

  onQueryChanged: { clearHold(); settleEdit(); selectedIndex = 0 }
  onVisibleChanged: {
    if (visible) { query = ""; selectedIndex = 0; clearHold(); resetEditState(); refresh() }
    else { query = ""; selectedIndex = 0; clearHold(); resetEditState() }
  }

  function shellEscape(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
  function notify(msg, body) {
    Quickshell.execDetached(["sh", "-c", "notify-send -t 2000 -a 'Todo' " + shellEscape(msg) + " " + shellEscape(body || "")])
  }
  function sanitize(s) { return String(s == null ? "" : s).replace(/[\t\r\n]+/g, " ") }

  readonly property string todoFilePy: "os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.join(os.path.expanduser('~'),'.config'),'quickshell/modules/todo/todolist.txt')"

  function refresh() {
    if (loadProc.running) return
    _loading = true
    loadProc.running = true
  }

  function save() {
    const lines = []
    for (let i = 0; i < allEntries.length; i++) {
      const t = sanitize(allEntries[i].text).trim()
      if (t === "") continue
      lines.push((allEntries[i].done ? "1" : "0") + "\t" + t)
    }
    saveProc.command = ["python3", "-c", "import os,sys\np=" + todoFilePy + "\nos.makedirs(os.path.dirname(p),exist_ok=True)\ndata=sys.argv[1] if len(sys.argv)>1 else ''\nopen(p,'w').write(data+('\\n' if data else ''))\n", lines.join("\n")]
    saveProc.running = true
  }

  Process {
    id: loadProc
    running: false
    command: ["python3", "-c", "import os\np=" + root.todoFilePy + "\ntry:\n    os.makedirs(os.path.dirname(p),exist_ok=True)\n    open(p,'a').close()\n    print(open(p,errors='replace').read(),end='')\nexcept Exception:\n    pass\n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const raw = String(text || "").split("\n")
        let out = []
        for (let i = 0; i < raw.length; i++) {
          let line = raw[i]
          if (line.endsWith("\r")) line = line.slice(0, -1)
          if (line === "") continue
          if ((line[0] === "0" || line[0] === "1") && line[1] === "\t") {
            const t = line.slice(2).trim()
            if (t !== "") out.push({ done: line[0] === "1", text: t })
          } else if (line.trim() !== "") {
            out.push({ done: false, text: line.trim() })
          }
        }
        root.allEntries = out
        root._loading = false
        root._everLoaded = true
        root.resetEditState()
        root.clearHold()
        if (root.selectedIndex >= root.filtered.length) root.selectedIndex = Math.max(0, root.filtered.length - 1)
      }
    }
    onExited: { root._loading = false; root._everLoaded = true }
  }

  Process {
    id: saveProc
    running: false
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: {} }
    onExited: { if (exitCode !== 0) root.notify("Todo", "Failed to save list") }
  }

  function realIndexOf(entry) { return allEntries.indexOf(entry) }

  function setEntry(ri, entry) {
    const next = allEntries.slice()
    next[ri] = entry
    allEntries = next
    save()
  }

  function removeAt(ri) {
    const next = allEntries.slice()
    next.splice(ri, 1)
    allEntries = next
  }

  // Holds a filtered index across the coming model swap, synchronously so
  // the highlight never flashes row 0. Pair with onCurrentIndexChanged.
  function holdSelection(target) {
    const n = filtered.length
    if (n === 0) { clearHold(); selectedIndex = 0; return }
    const t = Math.max(0, Math.min(target, n - 1))
    _pendingSel = t
    _wantCy = Math.floor(t / root.visibleRows) * root.visibleRows * (root.rowHeight + root.listSpacing)
    selectedIndex = t
  }
  function clearHold() { _pendingSel = -1; _wantCy = -1 }

  function toggleAt(idx) {
    idx = settleAndRetarget(idx)
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    const ri = realIndexOf(list[idx])
    if (ri < 0) return
    setEntry(ri, { done: !allEntries[ri].done, text: allEntries[ri].text })
    holdSelection(idx)
  }

  function deleteAt(idx) {
    let list = filtered
    if (idx < 0 || idx >= list.length) return
    if (_editFilteredIdx === idx) {
      resetEditState()
      list = filtered
    } else {
      const target = list[idx]
      settleEdit()
      list = filtered
      idx = list.indexOf(target)
      if (idx < 0) return
    }
    const ri = realIndexOf(list[idx])
    if (ri < 0) return
    removeAt(ri)
    save()
    holdSelection(idx)
  }

  function clearDone() {
    settleEdit()
    let n = 0
    const next = []
    for (let i = 0; i < allEntries.length; i++) {
      if (allEntries[i].done) n++
      else next.push(allEntries[i])
    }
    if (n === 0) { notify("Todo", "Nothing completed"); return }
    const keep = selectedIndex
    allEntries = next
    save()
    holdSelection(keep)
    notify("Todo", "Cleared " + n + " completed")
  }

  function copyAt(idx) {
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    const t = list[idx].text
    Quickshell.execDetached(["sh", "-c", "printf '%s' " + shellEscape(t) + " | wl-copy && notify-send -t 2000 -a 'Todo' 'Copied to clipboard' " + shellEscape(t)])
    close()
  }

  function moveItem(idx, dir) {
    idx = settleAndRetarget(idx)
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    const ri = realIndexOf(list[idx])
    const ni = ri + dir
    if (ri < 0 || ni < 0 || ni >= allEntries.length) return
    const next = allEntries.slice()
    const tmp = next[ri]
    next[ri] = next[ni]
    next[ni] = tmp
    allEntries = next
    save()
    holdSelection(filtered.indexOf(next[ni]))
  }

  function appendEmptyRow() {
    settleEdit()
    const next = allEntries.slice()
    const item = { done: false, text: "" }
    next.push(item)
    allEntries = next
    _editRef = item
    _editDraft = ""
    _editIsNew = true
    _editFilteredIdx = filtered.indexOf(item)
    holdSelection(_editFilteredIdx)
  }

  function startEdit(fidx) {
    if (_editFilteredIdx === fidx) return
    settleEdit()
    const list = filtered
    if (fidx < 0 || fidx >= list.length) return
    _editRef = list[fidx]
    _editDraft = list[fidx].text
    _editIsNew = false
    clearHold()
    selectedIndex = fidx
    _editFilteredIdx = fidx
  }

  function commitEditText(fidx, text) {
    if (_editFilteredIdx !== fidx) return
    const t = sanitize(text).trim()
    if (t === "") return
    const list = filtered
    if (fidx < 0 || fidx >= list.length) { resetEditState(); return }
    const ri = realIndexOf(list[fidx])
    if (ri < 0) { resetEditState(); return }
    setEntry(ri, { done: allEntries[ri].done, text: t })
    resetEditState()
    holdSelection(fidx)
  }

  function escapeEdit(fidx) {
    if (_editFilteredIdx !== fidx) return
    if (_editIsNew) {
      const ri = allEntries.indexOf(_editRef)
      resetEditState()
      if (ri >= 0) removeAt(ri)
      holdSelection(fidx)
    } else {
      resetEditState()
    }
  }

  // Returns the surviving object, or null when the row is gone.
  function settleEdit() {
    if (_editFilteredIdx < 0) return null
    const f = filtered
    const t = sanitize(_editDraft).trim()
    if (_editIsNew) {
      const ri = allEntries.indexOf(_editRef)
      let kept = null
      if (ri >= 0) {
        if (t === "") {
          removeAt(ri)
        } else {
          setEntry(ri, { done: allEntries[ri].done, text: t })
          kept = allEntries[ri]
        }
      }
      resetEditState()
      return kept
    }
    if (_editFilteredIdx >= f.length) { resetEditState(); return null }
    const entry = f[_editFilteredIdx]
    const ri = realIndexOf(entry)
    if (ri < 0) { resetEditState(); return null }
    if (t !== "" && t !== allEntries[ri].text) {
      setEntry(ri, { done: allEntries[ri].done, text: t })
      resetEditState()
      return allEntries[ri]
    }
    resetEditState()
    return entry
  }

  function settleAndRetarget(idx) {
    const f = filtered
    const target = (idx >= 0 && idx < f.length) ? f[idx] : null
    const wasEditing = _editFilteredIdx >= 0
    const kept = settleEdit()
    if (!wasEditing) return target ? filtered.indexOf(target) : -1
    if (!kept) return -1
    return filtered.indexOf(kept)
  }

  function move(delta) {
    clearHold()
    const n = filtered.length; if (n === 0) return
    let ni = selectedIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; selectedIndex = ni
  }
  function moveNoWrap(delta) {
    clearHold()
    const n = filtered.length; if (n === 0) return
    const ni = selectedIndex + delta; if (ni < 0 || ni >= n) return; selectedIndex = ni
  }
  function goHome() { clearHold(); if (filtered.length > 0) selectedIndex = 0 }
  function goEnd() { clearHold(); const n = filtered.length; if (n > 0) selectedIndex = n - 1 }
  function pageMove(dir) {
    clearHold()
    const n = filtered.length; if (n === 0) return
    const page = root.visibleRows
    let ni = selectedIndex + dir * page; if (ni < 0) ni = 0; if (ni >= n) ni = n - 1; selectedIndex = ni
  }
  function snapPage(list, idx) {
    if (!list || idx < 0 || !root._everLoaded) return
    try { list.positionViewAtIndex(Math.floor(idx / root.visibleRows) * root.visibleRows, ListView.Beginning) } catch (e) {}
  }

  function handleKey(event) {
    const alt = Boolean(event.modifiers & Qt.AltModifier)
    if (alt && event.key === Qt.Key_N) { appendEmptyRow(); event.accepted = true; return true }
    if (alt && event.key === Qt.Key_E) { startEdit(selectedIndex); event.accepted = true; return true }
    if (alt && event.key === Qt.Key_D) { deleteAt(selectedIndex); event.accepted = true; return true }
    if (alt && event.key === Qt.Key_C) { clearDone(); event.accepted = true; return true }
    if (alt && event.key === Qt.Key_Y) { copyAt(selectedIndex); event.accepted = true; return true }
    if (alt && event.key === Qt.Key_J) { moveItem(selectedIndex, 1); event.accepted = true; return true }
    if (alt && event.key === Qt.Key_K) { moveItem(selectedIndex, -1); event.accepted = true; return true }
    if (alt && event.key === Qt.Key_Down) { moveItem(selectedIndex, 1); event.accepted = true; return true }
    if (alt && event.key === Qt.Key_Up) { moveItem(selectedIndex, -1); event.accepted = true; return true }
    return false
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
        WlrLayershell.namespace: "quickshell-todo"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: root.close() }
        Rectangle { anchors.fill: parent; color: Theme.dim }

        Rectangle {
          width: parent.width
          height: root.drawerHeight
          anchors.top: parent.top
          anchors.topMargin: 0
          anchors.left: parent.left
          anchors.right: parent.right
          color: Theme.bg
          border.width: 0
          radius: 0
          clip: true
          LayoutMirroring.enabled: false
          focus: true
          property int editIdxMirror: root._editFilteredIdx
          onEditIdxMirrorChanged: { if (editIdxMirror < 0 && root.visible) Qt.callLater(() => searchField.forceActiveFocus()) }
          Keys.onPressed: event => {
            if (root.handleKey(event)) return
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
            else if (event.key === Qt.Key_R && !(event.modifiers & Qt.AltModifier) && !(event.modifiers & Qt.ControlModifier)) { root.refresh(); event.accepted = true }
          }
          MouseArea { anchors.fill: parent; onClicked: {} }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            anchors.topMargin: 0
            spacing: 8

            Rectangle {
              Layout.fillWidth: true
              height: root.rowHeight
              color: Theme.bg
              Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 2; color: Theme.border; opacity: 0.6 }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10
                Rectangle {
                  Layout.preferredWidth: addBtnRow.implicitWidth + 28
                  Layout.preferredHeight: 28; radius: 14
                  color: addMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                  border.color: addMouse.containsMouse ? Theme.fg : Theme.border; border.width: 1
                  RowLayout {
                    id: addBtnRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: ""; color: Theme.fg; font.family: Theme.nerdFont; font.pixelSize: 12 }
                    Text { text: "Add Task"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 11; font.bold: true }
                  }
                  MouseArea {
                    id: addMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.appendEmptyRow()
                  }
                }
                Text { text: ""; color: Theme.fg; opacity: 0.85; font.family: Theme.nerdFont; font.pixelSize: 14 }
                TextInput {
                  id: searchField
                  Layout.fillWidth: true
                  color: Theme.fg
                  font.family: Theme.monoFont; font.pixelSize: 13
                  focus: true; activeFocusOnTab: false
                  onTextChanged: root.query = text
                  onAccepted: root.toggleAt(root.selectedIndex)
                  Keys.onPressed: event => {
                    if (root.handleKey(event)) return
                    if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
                    else if (event.key === Qt.Key_Backtab) { root.move(-1); event.accepted = true }
                    else if (event.key === Qt.Key_Tab) {
                      if (event.modifiers & Qt.ShiftModifier) root.move(-1)
                      else root.move(1)
                      event.accepted = true
                    }
                    else if (event.key === Qt.Key_Up) { root.moveNoWrap(-1); event.accepted = true }
                    else if (event.key === Qt.Key_Down) { root.moveNoWrap(1); event.accepted = true }
                    else if (event.key === Qt.Key_Left) { root.moveNoWrap(-1); event.accepted = true }
                    else if (event.key === Qt.Key_Right) { root.moveNoWrap(1); event.accepted = true }
                    else if (event.key === Qt.Key_Home) { root.goHome(); event.accepted = true }
                    else if (event.key === Qt.Key_End) { root.goEnd(); event.accepted = true }
                    else if (event.key === Qt.Key_PageUp) { root.pageMove(-1); event.accepted = true }
                    else if (event.key === Qt.Key_PageDown) { root.pageMove(1); event.accepted = true }
                    else if (event.key === Qt.Key_Delete) {
                      if (event.modifiers & Qt.ShiftModifier) root.clearDone()
                      else root.deleteAt(root.selectedIndex)
                      event.accepted = true
                    }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.toggleAt(root.selectedIndex); event.accepted = true }
                  }
                  Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Search: Todo"; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 13; visible: searchField.text === ""
                  }
                }
                Text {
                  visible: searchField.text !== ""; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 12
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchField.text = ""; root.query = "" } }
                }
                Text { text: root.filtered.length + "/" + root.allEntries.length; color: Theme.fg; opacity: root._loading ? 0.25 : 0.45; font.family: Theme.monoFont; font.pixelSize: 11 }
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: root.contentHeight
              clip: true
              ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: root.listMargins
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: root.listSpacing
                model: root.filtered
                currentIndex: root.selectedIndex
                onCountChanged: { if (count > 0) root.snapPage(listView, root.selectedIndex) }
                onContentHeightChanged: {
                  if (root._wantCy > 0) root.snapPage(listView, root.selectedIndex)
                }
                onContentYChanged: {
                  if (root._wantCy > 0 && Math.round(contentY) === 0) root.snapPage(listView, root.selectedIndex)
                  else if (root._wantCy >= 0 && Math.round(contentY) === root._wantCy) root._wantCy = -1
                }
                footer: Item {
                  width: listView.width
                  height: {
                    const n = root.filtered.length
                    if (n <= root.visibleRows) return 0
                    const pitch = root.rowHeight + root.listSpacing
                    const lastPageStart = Math.floor((n - 1) / root.visibleRows) * root.visibleRows
                    const content = n * root.rowHeight + (n - 1) * root.listSpacing
                    const viewport = root.contentHeight - root.listMargins * 2
                    return Math.max(0, lastPageStart * pitch + viewport - content)
                  }
                }
                onCurrentIndexChanged: {
                  if (root._pendingSel >= 0) {
                    if (currentIndex !== root._pendingSel) root.selectedIndex = root._pendingSel
                  } else {
                    root.selectedIndex = currentIndex
                  }
                  root.snapPage(listView, currentIndex)
                }
                delegate: Rectangle {
                  id: del
                  required property var modelData
                  required property int index
                  readonly property bool isEditing: root._editFilteredIdx === index
                  width: listView.width - 15
                  height: root.rowHeight
                  color: root.selectedIndex === index ? Theme.surfaceHover : "transparent"
                  border.color: root.selectedIndex === index ? Theme.border : "transparent"
                  border.width: root.selectedIndex === index ? 1 : 0
                  function primeEditor() {
                    editor.text = del.modelData.text
                    editor.cursorPosition = editor.text.length
                    Qt.callLater(() => editor.forceActiveFocus())
                  }
                  onIsEditingChanged: { if (isEditing) primeEditor() }
                  Component.onCompleted: { if (isEditing) primeEditor() }
                  onVisibleChanged: { if (visible && del.isEditing) primeEditor() }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14; anchors.rightMargin: 14
                    spacing: 10
                    Text {
                      text: del.modelData.done ? "󰄵" : "󰄱"
                      color: del.modelData.done ? Theme.accent : Theme.fg
                      opacity: del.modelData.done ? 1 : 0.7
                      font.family: Theme.nerdFont; font.pixelSize: 15
                      Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                      visible: !del.isEditing
                      text: del.modelData.text
                      color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 12
                      font.strikeout: del.modelData.done
                      opacity: del.modelData.done ? 0.45 : 1
                      elide: Text.ElideRight; Layout.fillWidth: true
                      horizontalAlignment: Text.AlignLeft; LayoutMirroring.enabled: false
                      font.bold: root.selectedIndex === del.index
                    }
                    TextInput {
                      id: editor
                      visible: del.isEditing
                      Layout.fillWidth: true
                      color: Theme.fg
                      font.family: Theme.monoFont; font.pixelSize: 12
                      activeFocusOnTab: false
                      onTextChanged: root._editDraft = text
                      onAccepted: root.commitEditText(del.index, text)
                      Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { root.escapeEdit(del.index); event.accepted = true }
                        else if (event.key === Qt.Key_Up) { root.commitEditText(del.index, editor.text); if (root._editFilteredIdx < 0) root.moveNoWrap(-1); event.accepted = true }
                        else if (event.key === Qt.Key_Down) { root.commitEditText(del.index, editor.text); if (root._editFilteredIdx < 0) root.moveNoWrap(1); event.accepted = true }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.commitEditText(del.index, editor.text); event.accepted = true }
                      }
                    }
                  }
                  MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                      if (root._editFilteredIdx === del.index) return
                      if (mouse.button === Qt.RightButton) { root.clearHold(); root.startEdit(del.index) }
                      else if (mouse.button === Qt.MiddleButton) { root.clearHold(); root.settleEdit(); root.deleteAt(del.index) }
                      else if (root.selectedIndex === del.index) root.toggleAt(del.index)
                      else { root.clearHold(); root.settleEdit(); root.selectedIndex = del.index }
                    }
                  }
                }
                Text {
                  anchors.centerIn: parent; visible: root._everLoaded && root.filtered.length === 0
                  text: root.allEntries.length === 0 ? "No todos yet — Alt+N to add" : "No matches"
                  color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 13
                }
                Rectangle {
                  visible: listView.contentHeight > listView.height + 1
                  width: 4; radius: 2
                  anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                  anchors.rightMargin: 2; anchors.topMargin: 2; anchors.bottomMargin: 2
                  color: Theme.surface; opacity: 0.6
                  Rectangle {
                    width: parent.width
                    height: Math.max(8, parent.height * (listView.height / Math.max(1, listView.contentHeight)))
                    y: (parent.height - height) * (listView.contentY / Math.max(1, listView.contentHeight - listView.height))
                    radius: 2; color: Theme.border
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 28
              color: Theme.surface
              radius: Theme.radiusSm
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Text { text: "↵ Toggle"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
                Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
                Text { text: "Alt+N Add"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
                Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
                Text { text: "Alt+E Edit"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
                Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
                Text { text: "Alt+D Delete"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
                Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
                Text { text: "Alt+C Clear done"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
                Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
                Text { text: "Alt+Y Copy"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
                Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
                Text { text: "Alt+J/K Move"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
                Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
                Text { text: "Esc Close"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: root.pendingCount + " pending"; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 10 }
              }
            }
          }

          Component.onCompleted: if (root.visible) searchField.forceActiveFocus()
          Connections { target: root; function onVisibleChanged() { if (root.visible) { searchField.text = ""; root.query = ""; root.resetEditState(); searchField.forceActiveFocus() } } }
        }
      }
    }
  }

  IpcHandler {
    target: "todo"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  GlobalShortcut { name: "todoToggle"; description: "Toggle todo list"; onPressed: root.toggle() }
}
