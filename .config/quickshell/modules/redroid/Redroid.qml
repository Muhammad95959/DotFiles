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
    pendingKind = "version"
    pendingVersion = -1
    pendingAvd = ""
    _blockHover = true
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
    { version: 15, name: "Android 15.0", image: "redroid/redroid:15.0.0-latest" },
    { version: 14, name: "Android 14.0", image: "redroid/redroid:14.0.0-latest" },
    { version: 13, name: "Android 13.0", image: "redroid/redroid:13.0.0-latest" },
    { version: 12, name: "Android 12.0", image: "redroid/redroid:12.0.0-latest" },
    { version: 8, name: "Android 08.1", image: "redroid/redroid:8.1.0-latest" }
  ]
  readonly property var versions: versionConfigs.map(c => c.version)

  // AVDs are listed statically so the menu is filled instantly; only their
  // running state and adb serial are refreshed in the background.
  readonly property var avdConfigs: [
    { id: "Android_16.0", name: "Android 16.0", api: "android-36.1", width: 1344, height: 2992, density: 480 },
    { id: "Android_07.0", name: "Android 07.0", api: "android-24", width: 720, height: 1280, density: 320 }
  ]

  readonly property string iconWaydroid: "󰀲"
  readonly property string iconRedroid: "󰡨"
  readonly property string iconAvd: "󰦉"

  function imageFor(v) {
    for (let i = 0; i < versionConfigs.length; i++) {
      if (versionConfigs[i].version === v) return versionConfigs[i].image
    }
    return "redroid/redroid:" + v + ".0.0-latest"
  }

  function nameFor(v) {
    for (let i = 0; i < versionConfigs.length; i++) {
      if (versionConfigs[i].version === v) return versionConfigs[i].name
    }
    return "Android " + v
  }

  property var versionStates: ({})
  property var versionSizes: ({})
  property var emuStates: ({})
  readonly property var emulators: avdConfigs.map(function(c) {
    const s = emuStates[c.id] || ({})
    return {
      id: c.id, name: c.name, api: c.api,
      width: c.width, height: c.height, density: c.density,
      state: s.state || "stopped", serial: s.serial || ""
    }
  })
  property string stage: "versions"
  property string query: ""
  property int selectedIndex: 0
  property string sizeMode: "start"
  property string pendingKind: "version"
  property int pendingVersion: -1
  property string pendingAvd: ""
  readonly property bool pendingWaydroid: pendingKind === "waydroid"
  readonly property bool pendingEmu: pendingKind === "emu"
  property bool _blockHover: false

  readonly property var defaultSize: ({ width: 1080, height: 1920, density: 420 })

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

  readonly property var pendingEmulator: {
    for (let i = 0; i < emulators.length; i++)
      if (emulators[i].id === pendingAvd) return emulators[i]
    return null
  }

  readonly property var deviceActions: {
    if (pendingWaydroid) return waydroidActions
    if (pendingEmu) return emulatorActions
    const running = (versionStates[String(pendingVersion)] || "stopped") === "running"
    if (running) {
      return [
        { key: "open", label: "Open", icon: "󰖯" },
        { key: "resize", label: "Resize screen…", icon: "󰍹" },
        { key: "screenshot", label: "Screenshot", icon: "󰄀" },
        { key: "restart", label: "Restart", icon: "󰑓" },
        { key: "stop", label: "Stop", icon: "󰓛" },
        { key: "kill", label: "Force kill", icon: "󰚌" },
        { key: "logs", label: "Follow logs", icon: "󰈙" },
        { key: "shell", label: "ADB shell", icon: "󰆍" },
        { key: "copy", label: "Copy ADB address", icon: "󰅇" },
        { key: "doctor", label: "Diagnostics report", icon: "󰒓" },
        { key: "clear", label: "Clear data (danger)", icon: "󰃢" }
      ]
    }
    const sz = sizeFor(pendingVersion)
    return [
      { key: "start", label: "Start & open", subtitle: sizeLabel(sz), icon: "󰐥" },
      { key: "start-size", label: "Start with size…", icon: "󰍹" },
      { key: "logs", label: "Follow logs", icon: "󰈙" },
      { key: "doctor", label: "Diagnostics report", icon: "󰒓" },
      { key: "clear", label: "Clear data (danger)", icon: "󰃢" }
    ]
  }

  readonly property var waydroidActions: {
    const running = (versionStates["waydroid"] || "stopped") === "running"
    const all = [
      { key: "start", label: "Start & open", icon: "󰐥", when: "stopped" },
      { key: "open", label: "Open UI", icon: "󰖯", when: "running" },
      { key: "copy", label: "Copy ADB address", icon: "󰅇", when: "running" },
      { key: "stop", label: "Stop", icon: "󰓛", when: "running" },
      { key: "restart", label: "Restart", icon: "󰑓", when: "running" },
      { key: "logs", label: "Follow logs", icon: "󰈙", when: "any" },
      { key: "shell", label: "Android shell", icon: "󰆍", when: "running" },
      { key: "screenshot", label: "Screenshot", icon: "󰄀", when: "running" },
      { key: "doctor", label: "Diagnostics report", icon: "󰒓", when: "any" }
    ]
    return all.filter(a => a.when === "any" || a.when === (running ? "running" : "stopped"))
  }

  readonly property var emulatorActions: {
    const running = pendingEmulator ? pendingEmulator.state === "running" : false
    const all = [
      { key: "start", label: "Start & open", icon: "󰐥", when: "stopped" },
      { key: "cold", label: "Cold boot", icon: "󰜉", when: "stopped" },
      { key: "open", label: "Focus window", icon: "󰖯", when: "running" },
      { key: "screenshot", label: "Screenshot", icon: "󰄀", when: "running" },
      { key: "restart", label: "Restart", icon: "󰑓", when: "running" },
      { key: "stop", label: "Stop", icon: "󰓛", when: "running" },
      { key: "logs", label: "Follow logcat", icon: "󰈙", when: "any" },
      { key: "shell", label: "ADB shell", icon: "󰆍", when: "running" },
      { key: "copy", label: "Copy ADB serial", icon: "󰅇", when: "running" },
      { key: "doctor", label: "Diagnostics report", icon: "󰒓", when: "any" }
    ]
    return all.filter(a => a.when === "any" || a.when === (running ? "running" : "stopped"))
  }

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

  function parseSizeStr(s) {
    const m = /^(\d{2,4})x(\d{2,4})@(\d{2,3})$/.exec(String(s || "").trim())
    if (!m) return null
    return { width: parseInt(m[1]), height: parseInt(m[2]), density: parseInt(m[3]) }
  }

  function sizeFor(v) {
    return parseSizeStr(versionSizes[String(v)]) || defaultSize
  }

  function sizeLabel(s) {
    return s.width + "×" + s.height + " @" + s.density
  }

  // Accepts "1440x3200@560", "1440×3200 560", "1440 3200 560".
  function sizeQuery(q) {
    const m = /^\s*(\d{2,4})\s*(?:[x×*]\s*|\s+)(\d{2,4})\s*[@:\s]\s*(\d{2,3})\s*$/.exec(String(q || ""))
    if (!m) return null
    return { width: parseInt(m[1]), height: parseInt(m[2]), density: parseInt(m[3]) }
  }

  readonly property var currentModel: {
    const q = query.toLowerCase().trim()
    const toks = q === "" ? [] : q.split(/\s+/)
    let out = []

    if (stage === "versions") {
      const wdState = versionStates["waydroid"] || "stopped"
      const wdTitle = "Waydroid"
      const wdSubtitle = "container session"
      if (versionStates["waydroid"] !== undefined && matches(wdTitle + " " + wdSubtitle + " " + wdState + " android", toks))
        out.push({ kind: "waydroid", version: "waydroid", state: wdState, title: wdTitle, subtitle: wdSubtitle, icon: iconWaydroid })
      for (let i = 0; i < versions.length; i++) {
        const v = versions[i]
        const state = versionStates[v] || "stopped"
        const title = nameFor(v)
        const saved = versionSizes[String(v)]
        const subtitle = "redroid" + v + " • " + (saved || "localhost:" + (5500 + v))
        if (!matches(title + " " + subtitle + " " + state, toks)) continue
        out.push({ kind: "version", version: v, state: state, title: title, subtitle: subtitle, icon: iconRedroid })
      }
      for (let i = 0; i < emulators.length; i++) {
        const e = emulators[i]
        const title = e.name || e.id
        const subtitle = "AVD • " + (e.api || "android") +
          (e.width ? " • " + e.width + "×" + e.height : "") +
          (e.serial ? " • " + e.serial : "")
        if (!matches(title + " " + subtitle + " " + e.state + " emulator avd", toks)) continue
        out.push({ kind: "emulator", avd: e.id, state: e.state, title: title, subtitle: subtitle, icon: iconAvd })
      }
    } else if (stage === "sizes") {
      const running = (versionStates[String(pendingVersion)] || "stopped") === "running"
      const saved = parseSizeStr(versionSizes[String(pendingVersion)])
      const current = saved || defaultSize
      out.push({
        kind: "size", key: "last",
        width: current.width, height: current.height, density: current.density,
        title: (saved ? "Last used" : "Default") + " — " + current.width + "×" + current.height,
        subtitle: current.density + " dpi" + (saved ? " • what " + nameFor(pendingVersion) + " ran with" : " • first-run default"),
        icon: "󰄬"
      })
      if (running && sizeMode === "resize")
        out.push({ kind: "size", key: "reset", title: "Container default", subtitle: "wm size reset • native resolution", icon: "󰑓" })

      for (let i = 0; i < sizeOptions.length; i++) {
        const s = sizeOptions[i]
        const subtitle = s.width + "×" + s.height + " • " + s.density + " dpi"
        if (!matches(s.label + " " + subtitle, toks)) continue
        out.push({ kind: "size", key: s.width + "x" + s.height + ":" + s.density, width: s.width, height: s.height, density: s.density, title: s.label, subtitle: subtitle, icon: "󰍹" })
      }

      const parsed = sizeQuery(query)
      if (parsed || matches("custom size resolution", toks)) {
        out.push({
          kind: "size", key: "custom", custom: parsed,
          title: parsed ? "Custom — " + parsed.width + "×" + parsed.height : "Custom size…",
          subtitle: parsed ? parsed.density + " dpi" : "type 1440x3200@560 in the search field",
          icon: "󰌷"
        })
      }
    } else if (stage === "actions") {
      const list = deviceActions
      for (let i = 0; i < list.length; i++) {
        const a = list[i]
        if (!matches(a.label + " " + (a.subtitle || ""), toks)) continue
        out.push({ kind: "action", key: a.key, title: a.label, subtitle: a.subtitle || "", icon: a.icon })
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
    for (let i = 0; i < emulators.length; i++)
      if (emulators[i].state === "running") n++
    if ((versionStates["waydroid"] || "stopped") === "running") n++
    return n
  }

  readonly property string pendingName: pendingWaydroid
    ? "Waydroid"
    : (pendingEmu ? (pendingEmulator ? pendingEmulator.name : pendingAvd) : nameFor(pendingVersion))

  readonly property string stageIcon: {
    if (stage === "sizes") return "󰍹"
    if (stage === "confirm") return "󰃢"
    return "󰀲"
  }

  readonly property string headerTitle: {
    if (stage === "versions") return "Redroid"
    if (stage === "sizes") return (sizeMode === "resize" ? "Resize " : "Start ") + pendingName + " • screen size"
    if (stage === "actions") return pendingName
    if (stage === "confirm") return "Clear " + nameFor(pendingVersion) + " data?"
    return "Redroid"
  }

  readonly property string headerSubtitle: {
    if (stage === "versions") return currentModel.length + " targets • " + runningCount + " running"
    if (stage === "sizes") return sizeMode === "resize" ? "applies live • pick a size" : "pick a size to boot with"
    if (stage === "actions") {
      if (pendingWaydroid)
        return (versionStates["waydroid"] || "stopped") === "running" ? "running • container session" : "stopped • container session"
      if (pendingEmu)
        return (pendingEmulator && pendingEmulator.state === "running"
          ? "running • " + (pendingEmulator.serial || "AVD")
          : "stopped • " + (pendingEmulator ? (pendingEmulator.api || "AVD") : "AVD"))
      return "localhost:" + (5500 + pendingVersion) + " • " + (versionStates[String(pendingVersion)] || "stopped")
    }
    if (stage === "confirm") return "this deletes the container and its data volume"
    return ""
  }

  readonly property string searchPlaceholder: {
    if (stage === "versions") return "Search Android version…"
    if (stage === "sizes") return "Search size — or type 1440x3200@560"
    if (stage === "actions") return "Search action…"
    return "Search…"
  }

  function refresh() {
    if (!listProc.running) listProc.running = true
    if (!emuProc.running) emuProc.running = true
  }

  Process {
    id: listProc
    command: ["bash", root.scriptPath, "status"].concat(root.versions.map(function(v) { return String(v) }))
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const lines = String(text || "").split("\n")
        let map = {}
        let sizes = {}
        for (let i = 0; i < lines.length; i++) {
          const parts = lines[i].trim().split(/\s+/)
          if (parts.length >= 2) {
            map[parts[0]] = parts[1]
            if (parts.length >= 3) sizes[parts[0]] = parts[2]
          }
        }
        root.versionStates = map
        root.versionSizes = sizes
        if (root.selectedIndex >= root.currentModel.length) root.selectedIndex = 0
      }
    }
  }

  Process {
    id: emuProc
    command: ["bash", root.scriptPath, "emulators"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const lines = String(text || "").split("\n")
        let states = {}
        for (let i = 0; i < lines.length; i++) {
          if (lines[i].trim() === "") continue
          const p = lines[i].split("\t")
          if (p.length < 4) continue
          states[p[0]] = { state: p[3], serial: p[4] || "" }
        }
        root.emuStates = states
        if (root.selectedIndex >= root.currentModel.length) root.selectedIndex = 0
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

  function runWaydroid(action) {
    Quickshell.execDetached(["bash", root.scriptPath, "waydroid", action])
  }

  function runEmu(action) {
    Quickshell.execDetached(["bash", root.scriptPath, "emu", action, root.pendingAvd])
  }

  function runV(cmd, v) {
    if (cmd === "restart" || cmd === "start" || cmd === "resize") {
      const img = imageFor(v)
      Quickshell.execDetached(["env", "REDROID_IMAGE=" + img, "bash", scriptPath, cmd, String(v)])
    } else {
      Quickshell.execDetached(["bash", scriptPath, cmd, String(v)])
    }
  }

  function chooseVersion(idx) {
    const list = currentModel
    if (idx < 0 || idx >= list.length) return
    const e = list[idx]
    if (e.kind === "waydroid") {
      pendingKind = "waydroid"
      pendingVersion = -1
      pendingAvd = ""
      stage = "actions"
      selectedIndex = 0
      query = ""
      return
    }
    if (e.kind === "emulator") {
      pendingKind = "emu"
      pendingVersion = -1
      pendingAvd = e.avd
      stage = "actions"
      selectedIndex = 0
      query = ""
      return
    }
    pendingKind = "version"
    pendingVersion = e.version
    pendingAvd = ""
    stage = "actions"
    selectedIndex = 0
    query = ""
  }

  function chooseSize(idx) {
    const list = currentModel
    if (idx < 0 || idx >= list.length) return
    const s = list[idx]
    if (pendingVersion < 0) return
    if (s.key === "reset") {
      runV("size-reset", pendingVersion)
      close()
      return
    }
    let size = s
    if (s.key === "custom") {
      size = s.custom || sizeQuery(query)
      if (!size) return
    }
    run(sizeMode === "resize" ? "resize" : "start", pendingVersion, size)
    close()
  }

  function chooseAction(idx) {
    const list = currentModel
    if (idx < 0 || idx >= list.length) return
    const a = list[idx]
    if (pendingVersion < 0 && !pendingWaydroid && !pendingEmu) return
    if (pendingWaydroid) {
      runWaydroid(a.key)
      close()
      return
    }
    if (pendingEmu) {
      runEmu(a.key)
      close()
      return
    }
    if (a.key === "start-size") {
      sizeMode = "start"
      stage = "sizes"
      selectedIndex = 0
      query = ""
      return
    }
    if (a.key === "resize") {
      sizeMode = "resize"
      stage = "sizes"
      selectedIndex = 0
      query = ""
      return
    }
    if (a.key === "start") {
      run("start", pendingVersion, sizeFor(pendingVersion))
      close()
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
      stage = "actions"
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
    const s = String(vstr || "")
    const isWaydroid = /^waydroid$/i.test(s)
    const isEmu = /^emu[: ]/i.test(s)
    const v = parseInt(s)
    if (!isWaydroid && !isEmu && isNaN(v)) return
    open()
    if (isWaydroid) {
      pendingKind = "waydroid"
      pendingVersion = -1
      pendingAvd = ""
      stage = "actions"
      selectedIndex = 0
      query = ""
      return
    }
    if (isEmu) {
      pendingKind = "emu"
      pendingVersion = -1
      pendingAvd = s.replace(/^emu[: ]\s*/i, "")
      stage = "actions"
      selectedIndex = 0
      query = ""
      return
    }
    pendingKind = "version"
    pendingVersion = v
    pendingAvd = ""
    stage = "actions"
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
                readonly property bool isDeviceRow: modelData.kind === "version" || modelData.kind === "waydroid" || modelData.kind === "emulator"
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
                    color: del.isDeviceRow
                      ? (del.modelData.state === "running" ? Qt.alpha(Theme.accent, 0.2) : Theme.bg)
                      : Qt.alpha(Theme.accent, 0.12)
                    border.color: Theme.border
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                      anchors.centerIn: parent
                      anchors.verticalCenterOffset: 0.5
                      text: del.modelData.icon || "󰀲"
                      color: del.isDeviceRow && del.modelData.state === "running" ? Theme.accent : Theme.fg
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
                    visible: del.isDeviceRow
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
                  if (root.stage === "sizes") return root.sizeMode === "resize" ? "↵ resize" : "↵ start & open"
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
    function fixWaydroid(): string { root.runWaydroid("start"); return "ok" }
    function waydroid(action: string): string { root.runWaydroid(action || "start"); return "ok" }
    function doctor(): string { Quickshell.execDetached(["bash", root.scriptPath, "doctor"]); return "ok" }
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
