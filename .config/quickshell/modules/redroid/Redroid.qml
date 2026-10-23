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
  function open() {
    visible = true
    stage = "versions"
    query = ""
    selectedIndex = 0
    sizeMode = "start"
    pendingVersion = -1
    _blockHover = true
    loadPins()
    refresh()
    refreshTimer.restart()
  }
  function close() {
    visible = false
    query = ""
    selectedIndex = 0
    stage = "versions"
    _blockHover = false
  }

  readonly property string scriptPath: Quickshell.shellPath("modules/redroid/redroid.sh")
  // ── Config: Redroid versions and their Docker images ───────────────
  readonly property var versionConfigs: [
    { version: 12, image: "redroid/redroid:12.0.0-latest" },
    { version: 13, image: "redroid/redroid:13.0.0-latest" },
    { version: 14, image: "redroid/redroid:14.0.0-latest" },
    { version: 15, image: "redroid/redroid:15.0.0-latest" }
  ]
  readonly property var versions: versionConfigs.map(c => c.version)

  function imageFor(v) {
    for (let i = 0; i < versionConfigs.length; i++) {
      if (versionConfigs[i].version === v) return versionConfigs[i].image
    }
    return "redroid/redroid:" + v + ".0.0-latest"
  }

  property var versionStates: ({})
  property string stage: "versions"
  property string query: ""
  property int selectedIndex: 0
  property string sizeMode: "start"
  property int pendingVersion: -1
  property bool _blockHover: false
  property var pinnedRatios: []
  readonly property string pinFile: Quickshell.env("HOME") + "/.local/share/quickshell/redroid/pinned-sizes.json"

  readonly property var sizeOptions: [
    { label: "Small Phone — 720×1280", width: 720, height: 1280, density: 320 },
    { label: "Small Phone — 720×1600", width: 720, height: 1600, density: 320 },
    { label: "Medium Phone — 1080×1920", width: 1080, height: 1920, density: 420 },
    { label: "Medium Phone — 1080×2400", width: 1080, height: 2400, density: 420 },
    { label: "Large Phone — 1200×2670", width: 1200, height: 2670, density: 440 },
    { label: "Large Phone — 1440×3200", width: 1440, height: 3200, density: 560 },
    { label: "Foldable (Outer) — 904×2316", width: 904, height: 2316, density: 380 },
    { label: "Foldable (Inner) — 1812×2176", width: 1812, height: 2176, density: 420 },
    { label: "Small Tablet — 1200×1920", width: 1200, height: 1920, density: 240 },
    { label: "Large Tablet — 1600×2560", width: 1600, height: 2560, density: 320 }
  ]

  readonly property var actions: [
    { key: "open", label: "Open", icon: "󰖃" },
    { key: "stop", label: "Stop", icon: "󰐥" },
    { key: "restart", label: "Restart", icon: "󰑓" },
    { key: "kill", label: "Force kill", icon: "󰚌" },
    { key: "screenshot", label: "Screenshot", icon: "󰄀" },
    { key: "logs", label: "Follow logs", icon: "󰈙" },
    { key: "shell", label: "ADB shell", icon: "󰆍" },
    { key: "copy", label: "Copy ADB address", icon: "󰅇" },
    { key: "clear", label: "Clear data (danger)", icon: "󰃢" }
  ]

  readonly property var confirmOptions: [
    { key: "yes", label: "Yes, delete container and data", icon: "󰃢" },
    { key: "no", label: "Cancel", icon: "󰅖" }
  ]

  function matches(hay, toks) {
    const h = String(hay || "").toLowerCase()
    for (let i = 0; i < toks.length; i++)
      if (!h.includes(toks[i])) return false
    return true
  }

  readonly property var currentModel: {
    const q = query.toLowerCase().trim()
    const toks = q === "" ? [] : q.split(/\s+/)
    let out = []

    if (stage === "versions") {
      for (let i = 0; i < versions.length; i++) {
        const v = versions[i]
        const state = versionStates[v] || "stopped"
        const title = "Android " + v
        const subtitle = "redroid" + v + " • localhost:" + (5500 + v)
        if (!matches(title + " " + subtitle + " " + state, toks)) continue
        out.push({ kind: "version", version: v, state: state, title: title, subtitle: subtitle, icon: "󰀲" })
      }
    } else if (stage === "sizes") {
      let pinned = []
      let rest = []
      for (let i = 0; i < sizeOptions.length; i++) {
        const s = sizeOptions[i]
        const subtitle = s.width + "×" + s.height + " • " + s.density + " dpi"
        if (!matches(s.label + " " + subtitle, toks)) continue
        const key = s.width + "x" + s.height + ":" + s.density
        const isPinned = (root.pinnedRatios || []).indexOf(key) >= 0
        const item = { kind: "size", key: key, pinned: isPinned, width: s.width, height: s.height, density: s.density, title: s.label, subtitle: subtitle, icon: "󰍹" }
        if (isPinned) { pinned.push(item) } else { rest.push(item) }
      }
      out = pinned.concat(rest)
    } else if (stage === "actions") {
      for (let i = 0; i < actions.length; i++) {
        const a = actions[i]
        if (!matches(a.label, toks)) continue
        out.push({ kind: "action", key: a.key, title: a.label, subtitle: "", icon: a.icon })
      }
    } else if (stage === "confirm") {
      for (let i = 0; i < confirmOptions.length; i++) {
        const c = confirmOptions[i]
        if (!matches(c.label, toks)) continue
        out.push({ kind: "confirm", key: c.key, title: c.label, subtitle: "", icon: c.icon })
      }
    }
    return out
  }

  readonly property int currentCount: currentModel.length
  readonly property int rowH: 42
  readonly property int rowGap: 6
  readonly property int listMaxHeight: 10 * rowH + 9 * rowGap
  readonly property int listContentHeight: currentCount === 0 ? rowH : currentCount * rowH + (currentCount - 1) * rowGap
  readonly property int listHeight: Math.min(listContentHeight, listMaxHeight)

  readonly property int runningCount: {
    let n = 0
    for (let i = 0; i < versions.length; i++)
      if ((versionStates[versions[i]] || "stopped") === "running") n++
    return n
  }

  readonly property string stageIcon: {
    if (stage === "sizes") return "󰍹"
    if (stage === "confirm") return "󰃢"
    return "󰀲"
  }

  readonly property string headerTitle: {
    if (stage === "versions") return "Redroid"
    if (stage === "sizes") return sizeMode === "resize" ? "Resize Android " + pendingVersion : "Android " + pendingVersion + " • screen size"
    if (stage === "actions") return "Android " + pendingVersion
    if (stage === "confirm") return "Clear Android " + pendingVersion + " data?"
    return "Redroid"
  }

  readonly property string headerSubtitle: {
    if (stage === "versions") return currentModel.length + " versions • " + runningCount + " running"
    if (stage === "sizes") return sizeMode === "resize" ? "pick a new resolution and density" : "pick a resolution and density"
    if (stage === "actions") return "running on localhost:" + (5500 + pendingVersion)
    if (stage === "confirm") return "this deletes the container and its data volume"
    return ""
  }

  readonly property string searchPlaceholder: {
    if (stage === "versions") return "Search Android version…"
    if (stage === "sizes") return "Search resolution…"
    if (stage === "actions") return "Search action…"
    return "Search…"
  }

  function refresh() {
    const vlist = versions.join(" ")
    if (!listProc.running) {
      listProc.command = ["sh", "-c", "for v in " + vlist + "; do port=$((5500+v)); if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q \":$port$\"; then echo \"$v running\"; else echo \"$v stopped\"; fi; done"]
      listProc.running = true
    }
  }

  Process {
    id: listProc
    command: ["sh", "-c", "for v in $(seq 8 20); do port=$((5500+v)); if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q \":$port$\"; then echo \"$v running\"; else echo \"$v stopped\"; fi; done"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const lines = String(text || "").split("\n")
        let map = {}
        for (let i = 0; i < lines.length; i++) {
          const parts = lines[i].trim().split(/\s+/)
          if (parts.length >= 2) map[parts[0]] = parts[1]
        }
        root.versionStates = map
        if (root.selectedIndex >= root.currentModel.length) root.selectedIndex = 0
      }
    }
  }

  Process {
    id: pinLoadProc
    command: ["sh", "-c", "cat '" + root.pinFile + "' 2>/dev/null || echo '[]'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.pinnedRatios = JSON.parse(String(text || "[]").trim() || "[]") }
        catch (e) { root.pinnedRatios = [] }
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 5000
    repeat: true
    running: root.visible
    onTriggered: root.refresh()
  }

  onVisibleChanged: {
    if (visible) {
      _blockHover = true
      refresh()
    }
  }

  function run(cmd, v, size) {
    const img = imageFor(v)
    const args = ["env", "REDROID_IMAGE=" + img, "bash", scriptPath, cmd, String(v)]
    if (size) {
      args.push(String(size.width))
      args.push(String(size.height))
      args.push(String(size.density))
    }
    Quickshell.execDetached(args)
  }

  function runV(cmd, v) {
    if (cmd === "restart" || cmd === "start" || cmd === "resize" || cmd === "open") {
      const img = imageFor(v)
      Quickshell.execDetached(["env", "REDROID_IMAGE=" + img, "bash", scriptPath, cmd, String(v)])
    } else {
      Quickshell.execDetached(["bash", scriptPath, cmd, String(v)])
    }
  }

  function loadPins() {
    pinLoadProc.running = false
    pinLoadProc.running = true
  }

  function savePins() {
    const payload = JSON.stringify(root.pinnedRatios || [])
    const dir = Quickshell.env("HOME") + "/.local/share/quickshell/redroid"
    Quickshell.execDetached(["sh", "-c", "mkdir -p '" + dir + "' && cat > '" + root.pinFile + "' <<'EOF'\n" + payload + "\nEOF\n"])
  }

  function togglePin(key) {
    let arr = (root.pinnedRatios || []).slice()
    const i = arr.indexOf(key)
    if (i >= 0) arr.splice(i, 1)
    else arr.push(key)
    root.pinnedRatios = arr
    savePins()
  }

  function chooseVersion(idx) {
    const list = currentModel
    if (idx < 0 || idx >= list.length) return
    const e = list[idx]
    pendingVersion = e.version
    if (e.state === "running") {
      stage = "actions"
      selectedIndex = 0
      query = ""
    } else {
      sizeMode = "start"
      stage = "sizes"
      selectedIndex = 0
      query = ""
    }
  }

  function chooseSize(idx) {
    const list = currentModel
    if (idx < 0 || idx >= list.length) return
    const s = list[idx]
    if (pendingVersion < 0) return
    run(sizeMode === "resize" ? "resize" : "start", pendingVersion, s)
    close()
  }

  function chooseAction(idx) {
    const list = currentModel
    if (idx < 0 || idx >= list.length) return
    const a = list[idx]
    if (pendingVersion < 0) return
    if (a.key === "open") {
      sizeMode = "resize"
      stage = "sizes"
      selectedIndex = 0
      query = ""
      return
    }
    if (a.key === "clear") {
      stage = "confirm"
      selectedIndex = 0
      query = ""
      return
    }
    runV(a.key, pendingVersion)
    close()
  }

  function chooseConfirm(idx) {
    const list = currentModel
    if (idx < 0 || idx >= list.length) return
    if (list[idx].key === "yes") {
      runV("clear", pendingVersion)
      close()
    } else {
      onBack()
    }
  }

  function onAccepted() {
    if (stage === "versions") chooseVersion(selectedIndex)
    else if (stage === "sizes") chooseSize(selectedIndex)
    else if (stage === "actions") chooseAction(selectedIndex)
    else if (stage === "confirm") chooseConfirm(selectedIndex)
  }

  function onBack() {
    if (stage === "confirm") {
      stage = "actions"
    } else if (stage === "sizes") {
      stage = sizeMode === "resize" ? "actions" : "versions"
    } else if (stage === "actions") {
      stage = "versions"
    } else {
      close()
      return
    }
    selectedIndex = 0
    query = ""
  }

  function move(delta) {
    _blockHover = true
    const n = currentCount
    if (n === 0) return
    let ni = selectedIndex + delta
    if (ni < 0) ni = n - 1
    if (ni >= n) ni = 0
    selectedIndex = ni
  }

  function moveNoWrap(delta) {
    _blockHover = true
    const n = currentCount
    if (n === 0) return
    const ni = selectedIndex + delta
    if (ni < 0 || ni >= n) return
    selectedIndex = ni
  }

  function pageMove(dir) {
    _blockHover = true
    const n = currentCount
    if (n === 0) return
    const page = 8
    let ni = selectedIndex + dir * page
    if (ni < 0) ni = 0
    if (ni >= n) ni = n - 1
    selectedIndex = ni
    try { if (typeof listView !== "undefined" && listView) listView.positionViewAtIndex(ni, ListView.Contain) } catch (e) {}
  }

  function openVersion(vstr, running) {
    const v = parseInt(vstr)
    if (isNaN(v)) return
    open()
    pendingVersion = v
    const isRunning = String(running || "") === "1" || (versionStates[v] || "stopped") === "running"
    if (isRunning) {
      stage = "actions"
    } else {
      sizeMode = "start"
      stage = "sizes"
    }
    selectedIndex = 0
    query = ""
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
        WlrLayershell.namespace: "quickshell-redroid"
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
          anchors.fill: parent
          onClicked: root.onBack()
        }
        Rectangle { anchors.fill: parent; color: Theme.dim }

        Rectangle {
          id: container
          width: 470
          height: Math.min(720, mainCol.implicitHeight + 32)
          anchors.centerIn: parent
          radius: Theme.radiusLg
          color: Theme.bg
          border.color: Theme.border
          border.width: 1
          clip: true
          LayoutMirroring.enabled: false

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: if (root._blockHover) root._blockHover = false
            onClicked: {}
          }

          ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
              Layout.fillWidth: true
              spacing: 10

              Rectangle {
                width: 32; height: 32; radius: 8
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: root.stageIcon
                  color: Theme.fg
                  font.family: Theme.nerdFont
                  font.pixelSize: 14
                }
              }

              ColumnLayout {
                spacing: 2
                Text {
                  text: root.headerTitle
                  color: Theme.fg
                  font.family: Theme.monoFont
                  font.pixelSize: 14
                  font.bold: true
                }
                Text {
                  text: root.headerSubtitle
                  color: Theme.fg
                  opacity: 0.55
                  font.family: Theme.monoFont
                  font.pixelSize: 11
                }
              }

              Item { Layout.fillWidth: true }

              Rectangle {
                visible: root.stage !== "versions"
                width: 28; height: 28; radius: 14
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                Text { anchors.centerIn: parent; text: "󰦛"; color: Theme.fg; font.family: Theme.nerdFont; font.pixelSize: 12 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.onBack() }
              }

              Rectangle {
                width: 28; height: 28; radius: 14
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.6; font.family: Theme.nerdFont; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
              }

              Rectangle {
                width: 28; height: 28; radius: 14
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
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
                  text: root.query
                  onTextChanged: root.query = text
                  onAccepted: root.onAccepted()
                  Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                      if (root.stage === "versions") root.close()
                      else root.onBack()
                      event.accepted = true
                    } else if (event.key === Qt.Key_Backtab) {
                      root.move(-1); event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                      if (event.modifiers & Qt.ShiftModifier) root.move(-1)
                      else root.move(1)
                      event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                      root.moveNoWrap(-1); event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                      root.moveNoWrap(1); event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                      root.moveNoWrap(-1); event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                      root.moveNoWrap(1); event.accepted = true
                    } else if (event.key === Qt.Key_PageUp) {
                      root.pageMove(-1); event.accepted = true
                    } else if (event.key === Qt.Key_PageDown) {
                      root.pageMove(1); event.accepted = true
                    } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                      if (root.stage === "sizes" && root.currentCount > 0) {
                        const it = root.currentModel[root.selectedIndex]
                        if (it && it.key) root.togglePin(it.key)
                      }
                      event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                      root.onAccepted(); event.accepted = true
                    }
                  }
                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text === ""
                    text: root.searchPlaceholder
                    color: Theme.fg
                    opacity: 0.45
                    font.family: Theme.monoFont
                    font.pixelSize: 14
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
                    onClicked: { searchField.text = ""; root.query = "" }
                  }
                }
              }
            }

            ListView {
              id: listView
              Layout.fillWidth: true
              Layout.preferredHeight: root.listHeight
              Layout.fillHeight: false
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              spacing: root.rowGap
              model: root.currentModel
              currentIndex: root.selectedIndex
              onCurrentIndexChanged: {
                root.selectedIndex = currentIndex
                if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
              }

              delegate: Rectangle {
                id: del
                required property var modelData
                required property int index
                width: listView.width
                height: root.rowH
                radius: Theme.radiusSm
                color: root.selectedIndex === index ? Theme.surfaceHover : Theme.surface
                border.color: root.selectedIndex === index ? Qt.alpha(Theme.fg, 0.33) : Theme.border
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 12
                  anchors.rightMargin: 12
                  spacing: 12

                  Rectangle {
                    width: 28; height: 28; radius: 6
                    color: del.modelData.kind === "version"
                      ? (del.modelData.state === "running" ? Qt.alpha(Theme.accent, 0.2) : Theme.bg)
                      : Qt.alpha(Theme.accent, 0.12)
                    border.color: Theme.border
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                      anchors.centerIn: parent
                      anchors.verticalCenterOffset: 0.5
                      text: del.modelData.icon || "󰀲"
                      color: del.modelData.kind === "version" && del.modelData.state === "running" ? Theme.accent : Theme.fg
                      font.family: Theme.nerdFont
                      font.pixelSize: 12
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                      text: del.modelData.title || ""
                      color: Theme.fg
                      font.family: Theme.monoFont
                      font.pixelSize: 12
                      font.bold: root.selectedIndex === del.index
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                      horizontalAlignment: Text.AlignLeft
                      LayoutMirroring.enabled: false
                      verticalAlignment: Text.AlignVCenter
                      lineHeight: 1.0
                      lineHeightMode: Text.FixedHeight
                    }

                    Text {
                      text: del.modelData.subtitle || ""
                      visible: text !== ""
                      color: Theme.fg
                      opacity: 0.5
                      font.family: Theme.monoFont
                      font.pixelSize: 10
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                      horizontalAlignment: Text.AlignLeft
                      LayoutMirroring.enabled: false
                      verticalAlignment: Text.AlignVCenter
                    }
                  }

                  Rectangle {
                    visible: del.modelData.kind === "size" && del.modelData.pinned
                    width: 24; height: 24; radius: 6
                    color: Qt.alpha(Theme.accent, 0.2)
                    border.color: Qt.alpha(Theme.accent, 0.5)
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                      anchors.centerIn: parent
                      text: "󰐃"
                      color: Theme.accent
                      font.family: Theme.nerdFont
                      font.pixelSize: 11
                    }
                  }

                  Rectangle {
                    visible: del.modelData.kind === "version"
                    width: stateText.implicitWidth + 14
                    height: 18
                    radius: 9
                    color: del.modelData.state === "running" ? Qt.alpha(Theme.accent, 0.15) : Qt.alpha(Theme.fg, 0.06)
                    border.color: del.modelData.state === "running" ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.fg, 0.15)
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                      id: stateText
                      anchors.centerIn: parent
                      text: del.modelData.state === "running" ? "running" : "stopped"
                      color: del.modelData.state === "running" ? Theme.accent : Theme.fg
                      opacity: del.modelData.state === "running" ? 1 : 0.55
                      font.family: Theme.monoFont
                      font.pixelSize: 9
                      font.bold: del.modelData.state === "running"
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.selectedIndex === del.index) root.onAccepted()
                    else root.selectedIndex = del.index
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                visible: root.currentCount === 0
                text: root.stage === "versions"
                  ? (root.versions.length === 0 ? "No versions" : "No matching versions")
                  : (root.stage === "sizes" ? "No matching sizes" : "No matching actions")
                color: Theme.fg
                opacity: 0.55
                font.family: Theme.monoFont
                font.pixelSize: 13
              }
            }

            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: 8

              Text {
                text: {
                  if (root.stage === "versions") return "↵ select"
                  if (root.stage === "sizes") return root.sizeMode === "resize" ? "↵ resize & open" : "↵ start & open"
                  if (root.stage === "actions") return "↵ run"
                  return "↵ confirm"
                }
                color: Theme.fg
                opacity: 0.85
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.bold: true
              }
              Rectangle { width: 1; height: 10; color: Theme.border; opacity: 0.6 }
              Text { text: root.stage === "versions" ? "Esc close" : "Esc back"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
              Rectangle { width: 1; height: 10; color: Theme.border; opacity: 0.6; visible: root.stage === "sizes" }
              Text { text: "Ctrl+P pin"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true; visible: root.stage === "sizes" }
              Rectangle { width: 1; height: 10; color: Theme.border; opacity: 0.6; visible: root.stage === "versions" }
              Text { text: root.runningCount + " running"; color: Theme.accent; font.family: Theme.monoFont; font.pixelSize: 9; visible: root.stage === "versions" }
            }
          }

          Component.onCompleted: if (root.visible) searchField.forceActiveFocus()
          Connections {
            target: root
            function onVisibleChanged() {
              if (root.visible) {
                searchField.text = ""
                root.query = ""
                searchField.forceActiveFocus()
              }
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: "redroid"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function openVersion(version: string): string { root.openVersion(version, ""); return "ok" }
    function openRunning(version: string): string { root.openVersion(version, "1"); return "ok" }
    function start(version: string, width: string, height: string, density: string): string {
      root.run("start", parseInt(version), { width: parseInt(width), height: parseInt(height), density: parseInt(density) })
      return "ok"
    }
    function stop(version: string): string { root.runV("stop", parseInt(version)); return "ok" }
    function dismiss(version: string): string {
      Quickshell.execDetached(["qs", "ipc", "call", "notifications", "dismissApp", "Redroid " + version])
      return "ok"
    }
    function status(): string { return JSON.stringify(root.versionStates) }
  }

  GlobalShortcut {
    name: "redroidToggle"
    description: "Toggle Redroid manager"
    onPressed: root.toggle()
  }
}
