pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  id: clipRoot
  property bool visible: false
  property bool _everOpened: false
  property bool _loading: false
  property bool _everLoaded: false
  property var _thumbReady: ({})
  property int _thumbTick: 0
  property var _pendingDecoded: []
  property var _thumbAttempted: ({})
  property var _decodeQueue: []
  property var _decodeBatch: []
  property var _previewCache: ({})
  property var _previewCacheOrder: []
  readonly property int previewCacheMax: 50
  property string _previewRequestId: ""
  property bool _restoreSel: false
  property string _restoreId: ""
  property int _restorePos: 0
  function thumbSource(path) {
    if (!path) return ""
    const tick = _thumbTick
    const ready = tick >= 0 && _thumbReady[path]
    return fileUrl(path) + (ready ? "?r=1" : "")
  }
  function previewCached(id) { return _previewCache[id] !== undefined ? _previewCache[id] : null }
  function previewStore(id, text) {
    if (!id) return
    const c = Object.assign({}, _previewCache)
    const order = _previewCacheOrder.slice()
    c[id] = text
    const at = order.indexOf(id)
    if (at >= 0) order.splice(at, 1)
    order.push(id)
    while (order.length > previewCacheMax) delete c[order.shift()]
    _previewCache = c
    _previewCacheOrder = order
  }
  function previewDrop(id) {
    if (!id || _previewCache[id] === undefined) return
    const c = Object.assign({}, _previewCache)
    delete c[id]
    _previewCache = c
    _previewCacheOrder = _previewCacheOrder.filter(k => k !== id)
  }
  function markThumbsReady(paths) {
    if (!paths || paths.length === 0) return
    const next = Object.assign({}, _thumbReady)
    let changed = false
    for (let i = 0; i < paths.length; i++) {
      const p = paths[i]
      if (p && !next[p]) { next[p] = 1; changed = true }
    }
    if (changed) { _thumbReady = next; _thumbTick++ }
  }
  function toggle() { visible ? close() : open() }
  function open() { _everOpened = true; visible = true; query = ""; selectedIndex = 0; showPreview(); schedulePreview(); refresh() }
  function close() { visible = false }

  property string query: ""
  property int selectedIndex: 0
  property var allEntries: []
  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    if (q === "") return allEntries
    const toks = q.split(/\s+/)
    return allEntries.filter(e => {
      for (let t = 0; t < toks.length; t++) if (!e.hay.includes(toks[t])) return false
      return true
    })
  }

  onQueryChanged: { selectedIndex = 0 }
  onVisibleChanged: if (visible) { showPreview(); schedulePreview() }
  readonly property int maxThumbs: 80
  readonly property int previewDebounceMs: 80
  readonly property int postActivateRefreshMs: 600
  readonly property int drawerHeight: 470
  readonly property int rowHeight: 42
  readonly property int visibleRows: 8
  readonly property int listSpacing: 2
  readonly property int listMargins: 2
  readonly property int contentHeight: visibleRows * rowHeight + (visibleRows - 1) * listSpacing + listMargins * 2
  function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

  property var _lines: []
  property string thumbDir: "/tmp/quickshell-clipboard"
  property string previewFullText: ""
  property string previewImagePath: ""
  property bool previewIsImage: false
  property string previewUpdateId: ""

  Timer {
    id: previewTimer
    interval: clipRoot.previewDebounceMs
    repeat: false
    onTriggered: clipRoot.fetchPreview()
  }
  function schedulePreview() {
    previewTimer.restart()
  }
  Timer {
    id: postActivateTimer
    interval: clipRoot.postActivateRefreshMs
    repeat: false
    onTriggered: clipRoot.refresh()
  }

  function refresh() {
    if (clipProc.running) return
    _lines = []; _pendingDecoded = []; _loading = true; clipProc.running = true
  }
  function decodeId(id) {
    Quickshell.execDetached(["sh", "-c", "cliphist decode " + shQuote(id) + " | wl-copy"])
    close()
    postActivateTimer.restart()
  }
  function deleteId(id) {
    previewDrop(id)
    const lst = filtered
    if (selectedIndex >= 0 && selectedIndex < lst.length) {
      _restoreId = lst[selectedIndex].id
      _restorePos = selectedIndex
    } else {
      _restoreId = ""
      _restorePos = 0
    }
    _restoreSel = true
    Quickshell.execDetached(["sh", "-c", "printf '%s' " + shQuote(id) + " | cliphist delete; rm -f " + shQuote(thumbDir + "/" + id + ".png") + " " + shQuote(thumbDir + "/" + id + ".jpg") + " " + shQuote(thumbDir + "/" + id + ".gif") + " " + shQuote(thumbDir + "/" + id + ".webp") + " " + shQuote(thumbDir + "/" + id + ".bmp") + " 2>/dev/null || true"])
    Qt.callLater(() => { if (clipRoot.visible) refresh() })
  }
  function wipe() {
    _previewCache = ({}); _previewCacheOrder = []
    _restoreSel = false
    Quickshell.execDetached(["sh", "-c", "cliphist wipe; rm -rf " + shQuote(thumbDir) + "/* 2>/dev/null || true"])
    allEntries = []
  }

  Process {
    id: clipProc
    command: ["sh", "-c", "mkdir -p " + clipRoot.shQuote(clipRoot.thumbDir) + "; cliphist list 2>/dev/null"]
    stdout: SplitParser { onRead: data => clipRoot._lines.push(data) }
    onExited: {
      const lines = clipRoot._lines
      let out = []
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]
        if (line.trim().length === 0) continue
        const tab = line.indexOf("\t")
        if (tab < 0) continue
        const id = line.substring(0, tab).trim()
        const preview = line.substring(tab+1).trim()
        if (!id) continue
        if (preview.includes("<meta http-equiv=")) continue
        const isImage = preview.includes("[[ binary data")
        let ext = "png"
        const m = preview.match(/binary data.*(png|jpg|jpeg|bmp|gif|webp)/i)
        if (m) ext = m[1].toLowerCase().replace("jpeg","jpg")
        const thumbPath = isImage ? clipRoot.thumbDir + "/" + id + "." + ext : ""
        out.push({ id: id, preview: preview, isImage: isImage, thumbPath: thumbPath, hay: (preview + " " + id).toLowerCase() })
      }
      let same = false
      try {
        const old = clipRoot.allEntries
        if (old.length === out.length) {
          same = true
          for (let k = 0; k < out.length; k++) {
            if (old[k].id !== out[k].id || old[k].preview !== out[k].preview) { same = false; break }
          }
        }
      } catch (e) { same = false }
      if (!same) clipRoot.allEntries = out
      clipRoot._loading = false
      clipRoot._everLoaded = true
      if (clipRoot._restoreSel) {
        clipRoot._restoreSel = false
        const cur = clipRoot.filtered
        let at = -1
        for (let k = 0; k < cur.length; k++) if (cur[k].id === clipRoot._restoreId) { at = k; break }
        if (at >= 0) {
          clipRoot.selectedIndex = at
        } else if (cur.length > 0) {
          clipRoot.selectedIndex = Math.min(clipRoot._restorePos, cur.length - 1)
        } else {
          clipRoot.selectedIndex = 0
        }
      } else {
        clipRoot.selectedIndex = 0
      }
      clipRoot.schedulePreview()
      const first = []
      for (let v = 0; v < out.length && first.length < 12; v++) if (out[v].isImage) first.push(out[v])
      clipRoot.requestThumbs(first)
    }
  }

  function requestThumbs(entries) {
    if (!entries || entries.length === 0) return
    const q = _decodeQueue.slice()
    let added = false
    for (let i = 0; i < entries.length; i++) {
      const e = entries[i]
      if (!e || !e.isImage || !e.thumbPath) continue
      if (_thumbReady[e.thumbPath] || _thumbAttempted[e.thumbPath]) continue
      _thumbAttempted[e.thumbPath] = 1
      q.push(e.id + ":" + e.thumbPath)
      added = true
    }
    if (!added) return
    if (decodeImagesProc.running) {
      _decodeQueue = q
      return
    }
    _decodeBatch = q.slice(0, maxThumbs)
    _decodeQueue = q.slice(_decodeBatch.length)
    decodeImagesProc.running = true
  }

  Process {
    id: decodeImagesProc
    running: false
    command: ["sh", "-c", "for entry in " + clipRoot._decodeBatch.map(s => "'" + s.replace(/'/g, "'\\''") + "'").join(" ") + "; do id=\"${entry%%:*}\"; path=\"${entry#*:}\"; [ -f \"$path\" ] && continue; if cliphist decode \"$id\" > \"$path\" 2>/dev/null; then echo \"READY:$path\"; else rm -f \"$path\"; fi; done; echo done"]
    stdout: SplitParser { onRead: d => {
      const s = String(d || "")
      if (s.startsWith("READY:")) clipRoot._pendingDecoded.push(s.slice(6).trim())
    } }
    onExited: {
      clipRoot.markThumbsReady(clipRoot._pendingDecoded)
      clipRoot._pendingDecoded = []
      clipRoot._decodeBatch = []
      const rest = clipRoot._decodeQueue
      if (rest.length > 0) {
        clipRoot._decodeBatch = rest.slice(0, clipRoot.maxThumbs)
        clipRoot._decodeQueue = rest.slice(clipRoot._decodeBatch.length)
        decodeImagesProc.running = true
      } else {
        clipRoot.schedulePreview()
      }
    }
  }

  Process {
    id: previewProc
    property string targetId: ""
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let t = String(text||"")
        if (t.endsWith("\n")) t = t.slice(0, -1)
        clipRoot.previewStore(previewProc.targetId, t)
        if (clipRoot.previewIsImage === false && clipRoot._previewRequestId === clipRoot.previewUpdateId) {
          clipRoot.previewFullText = t
        }
      }
    }
  }
  Process {
    id: imagePreviewProc
    property string targetPath: ""
    running: false
    stdout: SplitParser { onRead: d => {
      const s = String(d || "")
      if (s.startsWith("READY:")) clipRoot.markThumbsReady([s.slice(6).trim()])
    } }
    onExited: {
      imagePreviewProc.targetPath = ""
    }
  }

  function fileUrl(path) {
    if (!path) return ""
    return "file://" + String(path).split("/").map(p => p===""?"":encodeURIComponent(p)).join("/")
  }

  function showPreview() {
    if (!clipRoot.visible) return
    const lst = filtered
    if (lst.length === 0 || selectedIndex < 0 || selectedIndex >= lst.length) {
      previewFullText = ""; previewImagePath = ""; previewIsImage = false
      _previewRequestId = ""
      return
    }
    const e = lst[selectedIndex]
    if (e.id === previewUpdateId && ((e.isImage && previewIsImage && previewImagePath === e.thumbPath) || (!e.isImage && !previewIsImage))) return
    previewIsImage = e.isImage
    previewUpdateId = e.id
    _previewRequestId = e.id
    if (e.isImage) {
      previewImagePath = e.thumbPath
      previewFullText = e.preview
    } else {
      previewImagePath = ""
      const hit = previewCached(e.id)
      previewFullText = hit !== null ? hit : e.preview
    }
  }
  function fetchPreview() {
    if (!clipRoot.visible) return
    const lst = filtered
    if (lst.length === 0 || selectedIndex < 0 || selectedIndex >= lst.length) return
    const e = lst[selectedIndex]
    if (e.id !== _previewRequestId) return
    if (e.isImage) {
      if (_thumbReady[e.thumbPath]) return
      if (imagePreviewProc.running && imagePreviewProc.targetPath === e.thumbPath) return
      previewProc.running = false
      imagePreviewProc.targetPath = e.thumbPath
      imagePreviewProc.command = ["sh", "-c", "p=" + shQuote(e.thumbPath) + "; [ -f \"$p\" ] && exit 0; if cliphist decode " + shQuote(e.id) + " > \"$p\" 2>/dev/null; then echo \"READY:$p\"; else rm -f \"$p\"; fi"]
      imagePreviewProc.running = true
    } else {
      if (previewCached(e.id) !== null) return
      if (previewProc.running && previewProc.targetId === e.id) return
      imagePreviewProc.running = false
      previewProc.running = false
      previewProc.targetId = e.id
      previewProc.command = ["sh", "-c", "cliphist decode " + shQuote(e.id) + " 2>/dev/null"]
      previewProc.running = true
    }
  }
  onSelectedIndexChanged: { showPreview(); schedulePreview() }
  onFilteredChanged: { showPreview(); schedulePreview() }

  function move(delta) {
    const n = filtered.length; if(n===0) return
    let ni = selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni
  }
  function moveNoWrap(delta) {
    const n = filtered.length; if(n===0) return
    const ni = selectedIndex+delta; if(ni<0||ni>=n) return; selectedIndex=ni
  }
  function goHome(){ if(filtered.length>0) selectedIndex=0 }
  function goEnd(){ const n=filtered.length; if(n>0) selectedIndex=n-1 }
  function pageMove(dir){
    const n=filtered.length; if(n===0) return
    const page=clipRoot.visibleRows
    let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni
  }
  function activateAt(idx){
    const list=filtered; if(idx<0||idx>=list.length) return; decodeId(list[idx].id)
  }

  LazyLoader {
    active: clipRoot.visible || clipRoot._everOpened

    Variants {
      model: Quickshell.screens
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: clipRoot.visible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "quickshell-clipboard"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors { top:true; bottom:true; left:true; right:true }

      MouseArea { anchors.fill: parent; onClicked: clipRoot.close() }
      Rectangle { anchors.fill: parent; color: Theme.dim }

      Rectangle {
        width: parent.width
        height: clipRoot.drawerHeight
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.left: parent.left
        anchors.right: parent.right
        color: Theme.bg
        border.width: 0
        radius: 0
        clip: true
        LayoutMirroring.enabled: false
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          anchors.topMargin: 0
          spacing: 8

          Rectangle {
            Layout.fillWidth: true
            height: clipRoot.rowHeight
            color: Theme.bg
            Rectangle { anchors.left: parent.left; anchors.right:parent.right; anchors.bottom: parent.bottom; height:2; color: Theme.border; opacity:0.6 }
            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              spacing: 10
              Text { text: " "; color: Theme.fg; opacity:0.85; font.family: Theme.nerdFont; font.pixelSize: 14 }
              TextInput {
                id: searchField
                Layout.fillWidth: true
                color: Theme.fg
                font.family: Theme.monoFont; font.pixelSize: 13
                focus: true; activeFocusOnTab: false
                onTextChanged: clipRoot.query = text
                onAccepted: clipRoot.activateAt(clipRoot.selectedIndex)
                Keys.onPressed: event => {
                  if (event.key === Qt.Key_Escape) { clipRoot.close(); event.accepted=true }
                  else if (event.key === Qt.Key_Backtab) { clipRoot.move(-1); event.accepted=true }
                  else if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier) clipRoot.move(-1)
                    else clipRoot.move(1)
                    event.accepted=true
                  }
                  else if (event.key === Qt.Key_Up) { clipRoot.moveNoWrap(-1); event.accepted=true }
                  else if (event.key === Qt.Key_Down) { clipRoot.moveNoWrap(1); event.accepted=true }
                  else if (event.key === Qt.Key_Left) { clipRoot.moveNoWrap(-1); event.accepted=true }
                  else if (event.key === Qt.Key_Right) { clipRoot.moveNoWrap(1); event.accepted=true }
                  else if (event.key === Qt.Key_Home) { clipRoot.goHome(); event.accepted=true }
                  else if (event.key === Qt.Key_End) { clipRoot.goEnd(); event.accepted=true }
                  else if (event.key === Qt.Key_PageUp) { clipRoot.pageMove(-1); event.accepted=true }
                  else if (event.key === Qt.Key_PageDown) { clipRoot.pageMove(1); event.accepted=true }
                  else if (event.key === Qt.Key_Delete) {
                    if (event.modifiers & Qt.ShiftModifier) { clipRoot.wipe(); event.accepted=true }
                    else {
                      const lst=clipRoot.filtered
                      if(clipRoot.selectedIndex>=0&&clipRoot.selectedIndex<lst.length){ clipRoot.deleteId(lst[clipRoot.selectedIndex].id); event.accepted=true }
                    }
                  } else if (event.key===Qt.Key_Return||event.key===Qt.Key_Enter){ clipRoot.activateAt(clipRoot.selectedIndex); event.accepted=true }
                }
                Text {
                  anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                  text: "Clipboard: search or select..."; color: Theme.fg; opacity:0.45; font.family: Theme.monoFont; font.pixelSize:13; visible: searchField.text===""
                }
              }
              Text {
                visible: searchField.text!==""; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:12
                MouseArea{ anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked:{ searchField.text=""; clipRoot.query="" } }
              }
              Text { text: clipRoot.filtered.length + "/" + clipRoot.allEntries.length; color:Theme.fg; opacity: clipRoot._loading ? 0.25 : 0.45; font.family:Theme.monoFont; font.pixelSize:11 }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: clipRoot.contentHeight
            clip: true
            Row {
              anchors.fill: parent
              spacing: 0
              Item {
                width: (parent.width - 1) / 2
                height: parent.height
                clip: true
                ListView {
                  id: listView
                  anchors.fill: parent
                  anchors.margins: clipRoot.listMargins
                  anchors.rightMargin: 10
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  spacing: clipRoot.listSpacing
                  model: clipRoot.filtered
                  currentIndex: clipRoot.selectedIndex
                  function snapPage(idx) {
                    if (idx < 0 || !clipRoot._everLoaded) return
                    positionViewAtIndex(Math.floor(idx / clipRoot.visibleRows) * clipRoot.visibleRows, ListView.Beginning)
                  }
                  onCurrentIndexChanged:{ snapPage(currentIndex); thumbTimer.restart() }
                  onContentYChanged: thumbTimer.restart()
                  onCountChanged: { if (count > 0) snapPage(currentIndex); thumbTimer.restart() }
                  delegate: Rectangle {
                    id: del
                    required property var modelData
                    required property int index
                    width: listView.width - 15
                    height: clipRoot.rowHeight
                    color: clipRoot.selectedIndex===index ? Theme.surfaceHover : "transparent"
                    border.color: clipRoot.selectedIndex===index ? Theme.border : "transparent"
                    border.width: clipRoot.selectedIndex===index ? 1 : 0
                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: 14; anchors.rightMargin:14
                      spacing: 10
                      Item {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        clip: true
                        Image {
                          id: thumbImg
                          visible: del.modelData.isImage
                          anchors.fill: parent
                          source: del.modelData.isImage ? clipRoot.thumbSource(del.modelData.thumbPath) : ""
                          asynchronous: true; cache: true; smooth: true
                          fillMode: Image.PreserveAspectCrop
                          sourceSize.width: 64; sourceSize.height: 64
                          opacity: status === Image.Ready ? 1 : 0
                          Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                        Text {
                          visible: !del.modelData.isImage || thumbImg.status !== Image.Ready
                          anchors.centerIn: parent
                          text: "󰅍"
                          color: Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:14
                        }
                        Rectangle {
                          visible: del.modelData.isImage
                          anchors.fill: parent
                          color:"transparent"
                          border.color: Theme.border; border.width:1; opacity:0.4
                          radius: 2
                        }
                      }
                      Text {
                        Layout.fillWidth: true
                        text: del.modelData.preview
                        color: Theme.fg; font.family:Theme.monoFont; font.pixelSize:12
                        elide: Text.ElideRight; maximumLineCount:1
                        opacity: del.modelData.isImage?0.80:1
                        horizontalAlignment: Text.AlignLeft
                        LayoutMirroring.enabled: false
                      }
                      Text {
                        visible: del.modelData.isImage
                        text: "IMG"
                        color: Theme.fg; opacity:0.40; font.family:Theme.monoFont; font.pixelSize:9; font.bold:true
                      }
                    }
                    MouseArea {
                      anchors.fill: parent; hoverEnabled:true; cursorShape: Qt.PointingHandCursor
                      acceptedButtons: Qt.LeftButton|Qt.RightButton|Qt.MiddleButton
                      onClicked: mouse=>{
                        if(mouse.button===Qt.RightButton||mouse.button===Qt.MiddleButton) clipRoot.deleteId(del.modelData.id)
                        else if (clipRoot.selectedIndex===del.index) clipRoot.activateAt(del.index)
                        else clipRoot.selectedIndex = del.index
                      }
                    }
                  }
                  Text {
                    anchors.centerIn: parent; visible: clipRoot._everLoaded && clipRoot.filtered.length===0
                    text: clipRoot.allEntries.length===0?"Clipboard empty — copy something first":"No matches for \""+clipRoot.query+"\""
                    color:Theme.fg; opacity:0.50; font.family:Theme.monoFont; font.pixelSize:12
                  }
                  Rectangle {
                    visible: clipRoot.filtered.length>8
                    width:4; radius:2
                    anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                    anchors.rightMargin:2; anchors.topMargin:2; anchors.bottomMargin:2
                    color: Theme.surface; opacity:0.6
                    Rectangle {
                      width:parent.width
                      height: parent.height * Math.min(1, 8/Math.max(1, clipRoot.filtered.length))
                      y: parent.height * (clipRoot.selectedIndex/Math.max(1, clipRoot.filtered.length))
                      radius:2; color: Theme.border
                    }
                  }
                }
                Timer {
                  id: thumbTimer
                  interval: 200
                  repeat: false
                  onTriggered: {
                    const perRow = clipRoot.rowHeight
                    const rows = Math.max(1, Math.floor(listView.height / perRow))
                    const first = Math.max(0, Math.floor(listView.contentY / perRow))
                    const last = Math.min(listView.count - 1, first + rows + 1)
                    const items = []
                    for (let i = first; i <= last; i++) {
                      const e = clipRoot.filtered[i]
                      if (e && e.isImage) items.push(e)
                    }
                    clipRoot.requestThumbs(items)
                  }
                }
              }
              Rectangle { width:1; height: parent.height; color:Theme.border; opacity:0.35 }
              Rectangle {
                width: (parent.width - 1) / 2
                height: parent.height
                color: Theme.surface
                border.color: "transparent"
                clip: true
                Image {
                  id: previewImg
                  visible: clipRoot.previewIsImage && clipRoot.previewImagePath !== ""
                  anchors.fill: parent
                  anchors.margins: 8
                  source: clipRoot.previewIsImage ? clipRoot.thumbSource(clipRoot.previewImagePath) : ""
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true; cache: true; smooth: true
                  sourceSize.width: 512; sourceSize.height: 512
                  opacity: status === Image.Ready ? 1 : 0
                  Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Flickable {
                  visible: !clipRoot.previewIsImage
                  anchors.fill: parent
                  anchors.margins: 10
                  contentHeight: previewText.implicitHeight
                  contentWidth: width
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  Text {
                    id: previewText
                    width: parent.width
                    text: clipRoot.previewFullText || (clipRoot.filtered.length>0 && clipRoot.selectedIndex>=0 ? clipRoot.filtered[clipRoot.selectedIndex].preview : "")
                    color: Theme.fg; font.family:Theme.monoFont; font.pixelSize:12
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    textFormat: Text.PlainText
                  }
                }
                Text {
                  visible: clipRoot._everLoaded && clipRoot.filtered.length===0
                  anchors.centerIn: parent
                  text: "No preview"
                  color: Theme.fg; opacity:0.35; font.family:Theme.monoFont; font.pixelSize:11
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
              Text { text: "↵ Copy"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
              Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
              Text { text: "Del Delete"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
              Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
              Text { text: "Shift+Del Wipe all"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
              Text { text: "•"; color: Theme.fg; opacity: 0.30; font.pixelSize: 10 }
              Text { text: "Esc Close"; color: Theme.fg; opacity: 0.70; font.family: Theme.monoFont; font.pixelSize: 10 }
              Item { Layout.fillWidth: true }
              Text { text: clipRoot.allEntries.length + " items"; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 10 }
            }
          }
        }

        Component.onCompleted: if(clipRoot.visible) searchField.forceActiveFocus()
        Connections{ target:clipRoot; function onVisibleChanged(){ if(clipRoot.visible){ searchField.text=""; searchField.forceActiveFocus() } } }
      }
    }
  }
  }

  IpcHandler {
    target: "clipboard"
    function toggle(){ clipRoot.toggle() }
    function open(){ clipRoot.open() }
    function close(){ clipRoot.close() }
  }
  GlobalShortcut { name:"clipboardToggle"; description:"Toggle clipboard manager"; onPressed: clipRoot.toggle() }
}
