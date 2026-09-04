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
  function toggle() { visible ? close() : open() }
  function open() { visible = true; refresh() }
  function close() { visible = false }

  property string query: ""
  property int selectedIndex: 0
  property var allEntries: []
  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    if (q === "") return allEntries
    const toks = q.split(/\s+/)
    return allEntries.filter(e => {
      const hay = (e.preview + " " + e.id).toLowerCase()
      for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) return false
      return true
    })
  }

  onQueryChanged: { selectedIndex = 0; updatePreview() }
  onVisibleChanged: if (visible) { selectedIndex = 0; updatePreview() }

  property string _accum: ""
  property string thumbDir: "/tmp/quickshell-clipboard"
  property var _imageIds: []
  property string previewFullText: ""
  property string previewImagePath: ""
  property bool previewIsImage: false
  property string previewUpdateId: ""

  function refresh() {
    _accum = ""; _imageIds = []; allEntries = []; clipProc.running = true
    previewFullText = ""; previewImagePath = ""; previewIsImage = false
  }
  function decodeId(id) {
    Quickshell.execDetached(["sh", "-c", "cliphist decode '" + id.replace(/'/g,"'\\''") + "' | wl-copy"])
    close()
  }
  function deleteId(id) {
    Quickshell.execDetached(["sh", "-c", "printf '%s' '" + id.replace(/'/g,"'\\''") + "' | cliphist delete"])
    Qt.callLater(() => { if (clipRoot.visible) refresh() })
  }
  function wipe() {
    Quickshell.execDetached(["sh", "-c", "cliphist wipe; rm -rf '" + thumbDir + "'/* 2>/dev/null || true"])
    allEntries = []
  }

  Process {
    id: clipProc
    command: ["sh", "-c", "mkdir -p '" + clipRoot.thumbDir + "'; cliphist list 2>/dev/null"]
    stdout: SplitParser { onRead: data => clipRoot._accum += data + "\n" }
    onExited: {
      const lines = clipRoot._accum.split("\n").filter(s => s.trim().length > 0)
      let out = []
      let imgIds = []
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]
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
        if (isImage) imgIds.push({id: id, path: thumbPath})
        out.push({ id: id, preview: preview, isImage: isImage, thumbPath: thumbPath })
      }
      clipRoot.allEntries = out
      clipRoot._imageIds = imgIds
      if (clipRoot.selectedIndex >= clipRoot.filtered.length) clipRoot.selectedIndex = 0
      clipRoot.updatePreview()
      if (imgIds.length > 0) decodeImagesProc.running = true
    }
  }

  Process {
    id: decodeImagesProc
    running: false
    command: ["sh", "-c", "for entry in " + clipRoot._imageIds.slice(0,80).map(e => "'" + e.id + ":" + e.path + "'").join(" ") + "; do id=\"${entry%%:*}\"; path=\"${entry#*:}\"; [ -f \"$path\" ] && continue; cliphist decode \"$id\" > \"$path\" 2>/dev/null || rm -f \"$path\"; done; echo done"]
    stdout: SplitParser { onRead: d => {} }
    onExited: {
      const cur = clipRoot.allEntries
      clipRoot.allEntries = []
      clipRoot.allEntries = cur
      updatePreview()
    }
  }

  Process {
    id: previewProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Preserve internal new lines exactly; only strip a single trailing newline added by shell
        let t = String(text||"")
        if (t.endsWith("\n")) t = t.slice(0, -1)
        // Do not trim interior spaces/newlines — preview must show them
        if (clipRoot.previewIsImage === false) {
          // Only apply if still on same id (avoid race when user moves fast)
          clipRoot.previewFullText = t
        }
      }
    }
  }
  Process {
    id: imagePreviewProc
    running: false
    stdout: SplitParser { onRead: d => {} }
    onExited: {
      // bust cache for preview image after decode
      clipRoot.previewUpdateId = clipRoot.previewUpdateId + "_"
    }
  }

  function fileUrl(path) {
    if (!path) return ""
    return "file://" + String(path).split("/").map(p => p===""?"":encodeURIComponent(p)).join("/")
  }

  function updatePreview() {
    const lst = filtered
    if (lst.length === 0 || selectedIndex < 0 || selectedIndex >= lst.length) {
      previewFullText = ""; previewImagePath = ""; previewIsImage = false
      return
    }
    const e = lst[selectedIndex]
    previewIsImage = e.isImage
    if (e.isImage) {
      previewImagePath = e.thumbPath
      previewFullText = e.preview
      previewUpdateId = e.id
      imagePreviewProc.command = ["sh", "-c", "[ -f '" + e.thumbPath.replace(/'/g,"'\\''") + "' ] || cliphist decode '" + e.id.replace(/'/g,"'\\''") + "' > '" + e.thumbPath.replace(/'/g,"'\\''") + "' 2>/dev/null"]
      imagePreviewProc.running = true
    } else {
      previewImagePath = ""
      previewUpdateId = e.id
      // Show truncated preview immediately, then replace with full decode (preserves \n)
      previewFullText = e.preview
      // Fetch full content with new lines intact
      previewProc.command = ["sh", "-c", "cliphist decode '" + e.id.replace(/'/g,"'\\''") + "' 2>/dev/null"]
      previewProc.running = true
    }
  }
  onSelectedIndexChanged: updatePreview()
  onFilteredChanged: updatePreview()

  function move(delta) {
    const n = filtered.length; if(n===0) return
    let ni = selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni; updatePreview()
  }
  function moveNoWrap(delta) {
    const n = filtered.length; if(n===0) return
    const ni = selectedIndex+delta; if(ni<0||ni>=n) return; selectedIndex=ni; updatePreview()
  }
  function goHome(){ if(filtered.length>0) { selectedIndex=0; updatePreview() } }
  function goEnd(){ const n=filtered.length; if(n>0) { selectedIndex=n-1; updatePreview() } }
  function pageMove(dir){
    const n=filtered.length; if(n===0) return
    let page=8
    try{ const h=listView?listView.height:0; if(h>0) page=Math.max(1, Math.floor(h/42)) }catch(e){}
    let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni; updatePreview()
    try{ if(typeof listView!=="undefined"&&listView) listView.positionViewAtIndex(ni, ListView.Contain) }catch(e){}
  }
  function activateAt(idx){
    const list=filtered; if(idx<0||idx>=list.length) return; decodeId(list[idx].id)
  }

  LazyLoader {
    active: clipRoot.visible

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
        height: 470
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
            height: 42
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
              Text { text: clipRoot.filtered.length + "/" + clipRoot.allEntries.length; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:11 }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 360
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
                  anchors.margins: 2
                  anchors.rightMargin: 10
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  spacing: 2
                  model: clipRoot.filtered
                  currentIndex: clipRoot.selectedIndex
                  onCurrentIndexChanged:{ clipRoot.selectedIndex=currentIndex; if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain); clipRoot.updatePreview() }
                  onCountChanged: if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain)
                  delegate: Rectangle {
                    id: del
                    required property var modelData
                    required property int index
                    width: listView.width - 15
                    height: 42
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
                        Text {
                          visible: !del.modelData.isImage
                          anchors.centerIn: parent
                          text: "󰅍"
                          color: Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:14
                        }
                        Image {
                          visible: del.modelData.isImage
                          anchors.fill: parent
                          source: del.modelData.isImage ? clipRoot.fileUrl(del.modelData.thumbPath) : ""
                          asynchronous: true; cache: true; smooth: true
                          fillMode: Image.PreserveAspectCrop
                          sourceSize.width: 64; sourceSize.height: 64
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
                        else { clipRoot.selectedIndex=del.index; clipRoot.updatePreview() }
                      }
                    }
                  }
                  Text {
                    anchors.centerIn: parent; visible: clipRoot.filtered.length===0
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
              }
              Rectangle { width:1; height: parent.height; color:Theme.border; opacity:0.35 }
              Rectangle {
                width: (parent.width - 1) / 2
                height: parent.height
                color: Theme.surface
                border.color: "transparent"
                clip: true
                Image {
                  visible: clipRoot.previewIsImage && clipRoot.previewImagePath !== ""
                  anchors.fill: parent
                  anchors.margins: 8
                  source: clipRoot.previewIsImage ? clipRoot.fileUrl(clipRoot.previewImagePath) + (clipRoot.previewUpdateId ? "?t=" + clipRoot.previewUpdateId : "") : ""
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true; cache: false; smooth: true
                  sourceSize.width: 512; sourceSize.height: 512
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
                  visible: clipRoot.filtered.length===0
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
