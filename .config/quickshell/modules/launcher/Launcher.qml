pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

import "../common"
import "providers/bookmarks"
import "providers/calc"
import "providers/engines"
import "providers/run"
import "providers/translate"
import "logic/match.js" as Match

// Single-window launcher: prefix routing over provider results.
Scope {
  id: launcherRoot
  property bool visible: false
  property bool _everOpened: false
  property bool _suppressHeightAnim: false
  property string query: ""
  property int selectedIndex: 0

  readonly property int rowHeight: 42
  readonly property int visibleRows: 8
  readonly property int listSpacing: 2
  readonly property int listH: Math.min(filtered.length, visibleRows) * rowHeight + Math.max(0, Math.min(filtered.length, visibleRows) - 1) * listSpacing
  readonly property int maxInputLines: 6

  // Prefixes: = and > match on first char, words need `trigger + space`
  property string calcPrefix: "="
  property string runPrefix: ">"
  property string translatePrefix: "@"
  property string bookmarkPrefix: "b"
  property string webPrefix: "w"

  // Browsers whose bookmarks should appear. Sources are normalized to:
  // brave, brave-origin, helium, chrome, chromium, vivaldi, firefox
  property var bookmarkBrowsers: ["brave-origin"]
  // Preferred executables per bookmark source. First found via `command -v` wins, else xdg-open.
  property var browserCommands: ({
    "brave": ["brave", "brave-browser", "brave-browser-stable"],
    "brave-origin": ["brave-origin --test-type"],
    "helium": ["helium", "helium-browser", "helium-bin"],
    "chrome": ["google-chrome", "google-chrome-stable", "chrome"],
    "chromium": ["chromium", "chromium-browser"],
    "vivaldi": ["vivaldi", "vivaldi-stable"],
    "firefox": ["firefox"]
  })

  CalcProvider {
    id: calcProvider
    query: launcherRoot.query
    calcPrefix: launcherRoot.calcPrefix
  }
  BookmarkProvider {
    id: bookmarkProvider
    bookmarkBrowsers: launcherRoot.bookmarkBrowsers
  }
  EngineProvider {
    id: engineProvider
  }
  RunProvider {
    id: runProvider
  }
  TranslateProvider {
    id: translateProvider
    query: launcherRoot.query
    translatePrefix: launcherRoot.translatePrefix
  }

  function toggle() { visible ? close() : open() }
  function open() { _suppressHeightAnim = true; _everOpened = true; visible = true; query = ""; selectedIndex = 0; calcProvider.reset(); translateProvider.reset(); refresh(); Qt.callLater(() => _suppressHeightAnim = false) }
  function close() { _suppressHeightAnim = true; visible = false; query = ""; selectedIndex = 0; calcProvider.reset(); translateProvider.reset() }
  function closeAndClear() { close() }

  function refresh() {
    engineProvider.refresh()
    bookmarkProvider.refresh()
    runProvider.refresh()
    translateProvider.refresh()
  }

  readonly property var filtered: {
    const spaced = String(query || "").replace(/\n/g, " ").replace(/^\s+/, "")
    // Translation keeps the user's line breaks; every other provider wants the
    // flattened form above.
    const lines = String(query || "").replace(/^\s+/, "")
    const raw = spaced.trim()
    if (raw === "") return []

    if (calcPrefix !== "" && spaced.startsWith(calcPrefix)) {
      return [calcProvider.explicitItem(spaced)]
    }
    if (runPrefix !== "" && spaced.startsWith(runPrefix)) return runProvider.runItems(spaced.slice(runPrefix.length).trim())
    if (translatePrefix !== "" && lines.startsWith(translatePrefix)) return translateProvider.translateItems(lines)

    // Websearch mode: `w` searches engines by name.
    if (webPrefix !== "" && spaced.toLowerCase().startsWith(webPrefix.toLowerCase())) {
      let after = spaced.slice(webPrefix.length).replace(/^ +/, "")
      const si = after.indexOf(" ")
      if (si !== -1)
        return []
      const picks = engineProvider.enginePickItems(after)
      if (picks.length > 0)
        return picks
    }

    const sp = spaced.indexOf(" ")
    if (sp > 0) {
      const pre = spaced.slice(0, sp).toLowerCase()
      const rest = spaced.slice(sp + 1).trim()
      if (bookmarkPrefix !== "" && pre === bookmarkPrefix.toLowerCase()) return bookmarkProvider.bookmarkHits(Match.toksOf(rest), 0)
      const eng = engineProvider.engineByTrigger(pre)
      if (eng) return [engineProvider.webItem(eng, rest)]
    }
    const toks = Match.toksOf(raw)
    let out = []

    const calcHit = calcProvider.implicitHit(raw)
    if (calcHit) out.push(calcHit)

    const apps = DesktopEntries.applications.values
    let appHits = []
    for (let i = 0; i < apps.length; i++) {
      const e = apps[i]
      if (e.noDisplay) continue
      const hay = [e.name, e.genericName, e.comment, (e.keywords || []).join(" ")].filter(x => x).join(" ")
      if (!Match.matches(hay, toks)) continue
      const n = String(e.name || "").toLowerCase()
      const q = toks.join(" ")
      let score = n.startsWith(q) ? 0 : n.includes(q) ? 1 : 2
      appHits.push({ e: e, score: score })
    }
    appHits.sort((a, b) => a.score - b.score || String(a.e.name).localeCompare(String(b.e.name)))
    for (let i = 0; i < appHits.length; i++)
      out.push({ kind: "app", title: appHits[i].e.name, subtitle: appHits[i].e.genericName || appHits[i].e.comment || "", icon: "", entry: appHits[i].e })

    const bmHits = bookmarkProvider.bookmarkHits(toks, 0)
    for (let i = 0; i < bmHits.length; i++) out.push(bmHits[i])

    const engHits = engineProvider.engineHits(toks, 0)
    for (let i = 0; i < engHits.length; i++) out.push(engHits[i])

    if (!raw.includes(" ")) {
      const bins = runProvider.binHits(raw.toLowerCase(), 0)
      for (let i = 0; i < bins.length; i++) out.push(bins[i])
    }

    const defEng = engineProvider.defaultEngine()
    if (defEng) out.push(engineProvider.webItem(defEng, raw))
    out.push({ kind: "run", title: "Run: " + raw, subtitle: raw, icon: "", cmd: raw })
    return out
  }

  onQueryChanged: { selectedIndex = 0 }

  function move(delta) { const n = filtered.length; if (n === 0) return; let ni = selectedIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; selectedIndex = ni }
  function moveNoWrap(delta) { const n = filtered.length; if (n === 0) return; const ni = selectedIndex + delta; if (ni < 0 || ni >= n) return; selectedIndex = ni }
  function pageMove(dir) { const n = filtered.length; if (n === 0) return; let ni = selectedIndex + dir * visibleRows; if (ni < 0) ni = 0; if (ni >= n) ni = n - 1; selectedIndex = ni }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["sh", "-c", "xdg-open " + Match.shQuote(url) + " >/dev/null 2>&1 &"])
    closeAndClear()
  }
  function openBookmark(url, source) {
    if (!url) return
    const s = String(source || "").toLowerCase()
    const cmds = (browserCommands && browserCommands[s]) || []
    if (cmds.length > 0) {
      const qurl = Match.shQuote(url)
      let parts = []
      for (let i = 0; i < cmds.length; i++) {
        const b = String(cmds[i] || "").trim()
        if (b === "") continue
        parts.push("command -v " + b + " >/dev/null 2>&1 && exec " + b + " " + qurl)
      }
      parts.push("xdg-open " + qurl + " >/dev/null 2>&1 &")
      Quickshell.execDetached(["sh", "-c", parts.join("; ")])
    } else {
      Quickshell.execDetached(["sh", "-c", "xdg-open " + Match.shQuote(url) + " >/dev/null 2>&1 &"])
    }
    closeAndClear()
  }

  // No -t: the notification server picks its own timeout.
  function notify(msg) {
    Quickshell.execDetached(["sh", "-c", "notify-send 'Launcher' " + Match.shQuote(String(msg))])
  }
  function copySummary(text) {
    const lines = String(text || "").split("\n").filter(x => x.trim() !== "")
    if (lines.length > 1)
      return "Copied " + lines.length + " lines"
    const head = (lines[0] || "").trim()
    return "Copied " + (head.length > 72 ? head.slice(0, 71).trim() + "…" : head)
  }
  function copyToClipboard(text) {
    const t = String(text || "")
    if (t === "")
      return
    Quickshell.execDetached(["sh", "-c", "printf '%s' " + Match.shQuote(t) + " | wl-copy && notify-send 'Launcher' " + Match.shQuote(copySummary(t))])
  }
  function runInTerminal(cmd, workingDirectory) {
    if (!Array.isArray(cmd) || cmd.length === 0)
      return
    const script = 'if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec "$@"; elif command -v kitty >/dev/null 2>&1; then exec kitty -e "$@"; else exec "$@"; fi'
    const argv = ["sh", "-c", script, "sh"].concat(cmd)
    Quickshell.execDetached(workingDirectory ? { command: argv, workingDirectory: workingDirectory } : argv)
  }
  // Right-hand tag on each row; empty means no tag.
  function tagOf(it) {
    if (!it)
      return ""
    if (it.tag)
      return String(it.tag)
    if (it.kind === "bookmark")
      return it.source || "mark"
    if (it.kind === "engine")
      return "engine"
    if (it.kind === "web")
      return "web"
    if (it.kind === "calc")
      return "calc"
    if (it.kind === "translate")
      return "tr"
    if (it.kind === "translate-install" || it.kind === "translate-deps")
      return "setup"
    return ""
  }
  // Engine and models are installed separately, so each missing piece runs its
  // own setup command in a terminal.
  function runTranslateSetup(cmd, message) {
    runInTerminal(cmd)
    translateProvider.noteSetupStarted()
    notify(message)
  }

  function activateAt(idx) {
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    const it = list[idx]
    if (it.kind === "calc") {
      if (calcProvider.calcResult === "") { closeAndClear(); return }
      copyToClipboard(calcProvider.calcResult)
      closeAndClear()
    } else if (it.kind === "translate") {
      if (it.text)
        copyToClipboard(it.text)
      closeAndClear()
    } else if (it.kind === "translate-install") {
      runTranslateSetup(translateProvider.downloadCmd, "Downloading translation models in a terminal — reopen the launcher when it finishes")
      closeAndClear()
    } else if (it.kind === "translate-deps") {
      runTranslateSetup(translateProvider.depsCmd, "Installing the translation engine — reopen the launcher when it finishes")
      closeAndClear()
    } else if (it.kind === "app") {
      const e = it.entry
      if (e.runInTerminal) {
        runInTerminal(e.command, e.workingDirectory)
      } else {
        e.execute()
      }
      closeAndClear()
    } else if (it.kind === "bin") {
      Quickshell.execDetached([it.path])
      closeAndClear()
    } else if (it.kind === "bookmark") {
      openBookmark(it.url, it.source)
    } else if (it.kind === "engine") {
      query = (it.trigger || "") + " "
      selectedIndex = 0
    } else if (it.kind === "web") {
      openUrl(it.url)
    } else if (it.kind === "run") {
      Quickshell.execDetached(["sh", "-c", it.cmd])
      closeAndClear()
    }
  }

  LazyLoader {
    active: launcherRoot.visible || launcherRoot._everOpened

    Variants {
      model: Quickshell.screens
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: launcherRoot.visible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: launcherRoot.close() }
        Rectangle { anchors.fill: parent; color: Theme.dim }

        Rectangle {
          width: 600
          height: mainCol.implicitHeight + 16
          anchors.centerIn: parent
          Behavior on height {
            enabled: launcherRoot.visible && !launcherRoot._suppressHeightAnim
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }
          color: Theme.bg
          border.color: Theme.border
          border.width: 1
          radius: Theme.radiusLg
          clip: true
          LayoutMirroring.enabled: false
          MouseArea { anchors.fill: parent; onClicked: {} }

          ColumnLayout {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 6

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Math.min(Math.max(edit.contentHeight + 24, launcherRoot.rowHeight), launcherRoot.maxInputLines * Math.max(edit.cursorRectangle.height, 16) + 24)
              Layout.minimumHeight: launcherRoot.rowHeight
              color: Theme.bg
              Rectangle { visible: launcherRoot.filtered.length > 0; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 2; color: Theme.border; opacity: 0.6 }
              Text {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 11
                text: "\uf002 "
                color: Theme.fg
                opacity: 0.85
                font.family: Theme.nerdFont
                font.pixelSize: 14
              }
              Text {
                id: countText
                visible: launcherRoot.filtered.length > 0
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 14
                text: launcherRoot.filtered.length
                color: Theme.fg
                opacity: 0.45
                font.family: Theme.monoFont
                font.pixelSize: 11
              }
              Flickable {
                id: inputFlick
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.right: countText.left
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 12
                height: Math.min(edit.contentHeight, launcherRoot.maxInputLines * Math.max(edit.cursorRectangle.height, 16))
                contentWidth: width
                contentHeight: edit.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: true
                // No ScrollBar attached: text scrolls without a visible scrollbar
                  TextEdit {
                    id: edit
                    width: inputFlick.width
                    color: Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 13
                    focus: true
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    horizontalAlignment: TextEdit.AlignLeft
                    onTextChanged: launcherRoot.query = text
                    onCursorRectangleChanged: {
                      const r = cursorRectangle
                      if (r.y < inputFlick.contentY) inputFlick.contentY = r.y
                      else if (r.y + r.height > inputFlick.contentY + inputFlick.height) inputFlick.contentY = r.y + r.height - inputFlick.height
                    }
                    Keys.onPressed: event => {
                      if (event.key === Qt.Key_Escape) { launcherRoot.close(); event.accepted = true }
                      else if (event.key === Qt.Key_Backtab) { launcherRoot.move(-1); event.accepted = true }
                      else if (event.key === Qt.Key_Tab) {
                        if (event.modifiers & Qt.ShiftModifier) launcherRoot.move(-1)
                        else launcherRoot.move(1)
                        event.accepted = true
                      }
                      else if (event.key === Qt.Key_Up) { launcherRoot.moveNoWrap(-1); event.accepted = true }
                      else if (event.key === Qt.Key_Down) { launcherRoot.moveNoWrap(1); event.accepted = true }
                      else if (event.key === Qt.Key_PageUp) { launcherRoot.pageMove(-1); event.accepted = true }
                      else if (event.key === Qt.Key_PageDown) { launcherRoot.pageMove(1); event.accepted = true }
                      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (event.modifiers & Qt.AltModifier) { edit.insert(edit.cursorPosition, "\n"); event.accepted = true }
                        else if (event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier)) return
                        else { launcherRoot.activateAt(launcherRoot.selectedIndex); event.accepted = true }
                      }
                    }
                    Text {
                      text: "Search..."
                      color: Theme.fg
                      opacity: 0.45
                      font.family: Theme.monoFont
                      font.pixelSize: 13
                      visible: edit.text === ""
                    }
                  }
                }
            }

            ListView {
              id: listView
              visible: launcherRoot.filtered.length > 0
              Layout.fillWidth: true
              Layout.preferredHeight: launcherRoot.listH
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              spacing: launcherRoot.listSpacing
              model: launcherRoot.filtered
              currentIndex: launcherRoot.filtered.length > 0 ? Math.min(launcherRoot.selectedIndex, launcherRoot.filtered.length - 1) : -1
              onCurrentIndexChanged: { if (currentIndex >= 0) launcherRoot.selectedIndex = currentIndex; if (currentIndex >= 0) positionViewAtIndex(Math.floor(currentIndex / launcherRoot.visibleRows) * launcherRoot.visibleRows, ListView.Beginning) }
              delegate: Rectangle {
                id: del
                required property var modelData
                required property int index
                width: listView.width
                height: launcherRoot.rowHeight
                color: launcherRoot.selectedIndex === index ? Theme.surfaceHover : "transparent"
                border.color: launcherRoot.selectedIndex === index ? Theme.border : "transparent"
                border.width: launcherRoot.selectedIndex === index ? 1 : 0
                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 12
                  anchors.rightMargin: 12
                  spacing: 10
                  Item {
                    visible: del.modelData.kind !== "app"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    Text {
                      anchors.centerIn: parent
                      text: del.modelData.kind === "bookmark" ? bookmarkProvider.bookmarkIcon(del.modelData.source) : (del.modelData.icon || "•")
                      color: Theme.fg
                      opacity: del.modelData.kind === "calc" ? 1 : 0.65
                      font.family: Theme.nerdFont
                      font.pixelSize: 14
                      horizontalAlignment: Text.AlignHCenter
                      visible: iconImg.status !== Image.Ready
                    }
                    Image {
                      id: iconImg
                      anchors.centerIn: parent
                      width: 18
                      height: 18
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      cache: true
                      source: (del.modelData.iconFile || "") !== "" ? "file://" + del.modelData.iconFile : ""
                      visible: (del.modelData.iconFile || "") !== "" && status !== Image.Error
                    }
                  }
                  IconImage {
                    visible: del.modelData.kind === "app"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    source: del.modelData.kind === "app" && del.modelData.entry ? Quickshell.iconPath(del.modelData.entry.icon, true) : ""
                  }
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                      Layout.fillWidth: true
                      text: del.modelData.title || ""
                      color: Theme.fg
                      font.family: Theme.monoFont
                      font.pixelSize: 12
                      font.bold: launcherRoot.selectedIndex === del.index
                      elide: Text.ElideRight
                      maximumLineCount: 1
                      horizontalAlignment: Text.AlignLeft
                      LayoutMirroring.enabled: false
                    }
                    Text {
                      Layout.fillWidth: true
                      visible: (del.modelData.subtitle || "") !== ""
                      text: del.modelData.subtitle || ""
                      color: Theme.fg
                      opacity: 0.5
                      font.family: Theme.monoFont
                      font.pixelSize: 10
                      elide: Text.ElideMiddle
                      maximumLineCount: 1
                      horizontalAlignment: Text.AlignLeft
                      LayoutMirroring.enabled: false
                    }
                  }
                  Text {
                    visible: launcherRoot.tagOf(del.modelData) !== ""
                    text: launcherRoot.tagOf(del.modelData)
                    color: Theme.fg
                    opacity: 0.4
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.bold: true
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (launcherRoot.selectedIndex === del.index) launcherRoot.activateAt(del.index)
                    else launcherRoot.selectedIndex = del.index
                  }
                }
              }
            }
          }

          Component.onCompleted: if (launcherRoot.visible) edit.forceActiveFocus()
          Connections {
            target: launcherRoot
            function onVisibleChanged() {
              if (launcherRoot.visible) edit.forceActiveFocus()
            }
            function onQueryChanged() {
              if (launcherRoot.query !== edit.text) {
                edit.text = launcherRoot.query
                edit.cursorPosition = edit.text.length
              }
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: "launcher"
    function toggle() { launcherRoot.toggle() }
    function open() { launcherRoot.open() }
    function close() { launcherRoot.close() }
  }
  GlobalShortcut { name: "launcherToggle"; description: "Toggle launcher"; onPressed: launcherRoot.toggle() }
}
