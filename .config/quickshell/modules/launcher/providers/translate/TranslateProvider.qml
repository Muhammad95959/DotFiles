pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../logic/match.js" as Match

// Offline Arabic <-> English translation via local CTranslate2 models.
// The engine (ctranslate2 + sentencepiece) and the models are installed
// separately, so each missing piece gets its own prompt and its own remedy.
Scope {
  id: root
  required property string query
  required property string translatePrefix

  // Output for root._pendingText, mirroring CalcProvider's calcResult/calcError.
  property string result: ""
  property string error: ""
  property string _pendingText: ""
  // Which direction to translate; also drives nothing else, rows stay left-aligned.
  property bool _arabicSource: false

  // 0 = not probed, 1 = usable, 2 = engine missing, 3 = models missing.
  property int _modelState: 0
  // Setup-poll budget so a failed install cannot spawn python forever.
  property int _rechecks: 0

  readonly property string scriptPath: Quickshell.shellDir + "/modules/launcher/providers/translate/translate.py"
  readonly property var downloadCmd: ["python3", root.scriptPath, "--install"]
  readonly property var depsCmd: ["python3", root.scriptPath, "--install-deps"]
  // Separator is U+00B7, present in the mono font; U+2194 is not, so the
  // "both directions" phrasing avoids a fallback glyph.
  readonly property string modelMissing: "~170 MB download · both directions"
  readonly property string depsMissing: "~41 MB · python-ctranslate2-bin + sentencepiece-bin"

  // Newlines are kept: they mark the user's line structure, which the model
  // preserves and the clipboard should receive.
  function sourceTextOf(q) {
    const s = String(q || "").replace(/^\s+/, "")
    return (root.translatePrefix !== "" && s.startsWith(root.translatePrefix)) ? s.slice(root.translatePrefix.length).trim() : s.trim()
  }
  // The result row is a single line, so it shows the tail; `text` keeps it all.
  function lastLineOf(s) {
    const lines = String(s || "").split("\n")
    for (let i = lines.length - 1; i >= 0; i--) {
      const t = lines[i].trim()
      if (t !== "")
        return t
    }
    return ""
  }
  function reset() {
    trTimer.stop()
    root.result = ""
    root.error = ""
    root._pendingText = ""
    root._arabicSource = false
  }
  function refresh() {
    if (!checkProc.running)
      checkProc.running = true
  }
  // A setup command is running in a terminal; poll until it lands or we give up.
  function noteSetupStarted() {
    root._modelState = 0
    root.result = ""
    root.error = ""
    root._pendingText = ""
    root._rechecks = 0
    rechkTimer.restart()
  }

  // Reads model state and the last result so the launcher's `filtered`
  // binding re-evaluates on its own.
  function translateItems(spaced) {
    const text = root.sourceTextOf(spaced)
    const echo = root.lastLineOf(text)
    if (text === "")
      return [{ kind: "translate", title: "Translate", subtitle: "Alt+Enter for a new line", icon: "󰗼" }]
    if (root._modelState === 2)
      return [{ kind: "translate-deps", title: "Install translation engine", subtitle: root.depsMissing, icon: "" }]
    if (root._modelState === 3)
      return [{ kind: "translate-install", title: "Download translation models", subtitle: root.modelMissing, icon: "" }]
    if (root._modelState !== 1)
      return [{ kind: "translate", title: "Checking models…", subtitle: echo, icon: "󰗼" }]
    // Only show output that belongs to the current input; an in-flight
    // translation for the previous keystroke would read as the answer.
    const settled = root._pendingText === text
    if (root.error !== "" && settled)
      return [{ kind: "translate", title: root.error, subtitle: echo, icon: "󰗼" }]
    if (!settled || root.result === "")
      return [{ kind: "translate", title: "Translating…", subtitle: echo, icon: "󰗼" }]
    // title shows only the tail so the row stays one line; text carries the
    // whole translation for the clipboard.
    return [{ kind: "translate", title: root.lastLineOf(root.result), subtitle: echo, icon: "󰗼", text: root.result }]
  }

  onQueryChanged: trTimer.restart()

  Timer {
    id: trTimer
    interval: 150
    repeat: false
    onTriggered: {
      const text = root.sourceTextOf(root.query)
      if (text === "" || text.length > 2000) {
        root.result = ""
        root.error = ""
        root._pendingText = ""
        return
      }
      // Wait for the probe; checkProc re-arms this timer once usable.
      if (root._modelState !== 1)
        return
      if (root._pendingText === text && (root.result !== "" || root.error !== ""))
        return
      if (trProc.running) {
        trTimer.restart()
        return
      }
      root._pendingText = text
      root.result = ""
      root.error = ""
      root._arabicSource = Match.isArabic(text)
      trProc.command = ["python3", root.scriptPath, "--from", root._arabicSource ? "ar" : "en", "--to", root._arabicSource ? "en" : "ar", text]
      trProc.running = true
    }
  }

  // A setup command runs in a terminal and can take minutes, so poll until the
  // verdict is ok or the budget runs out. Reopening the launcher also re-probes.
  Timer {
    id: rechkTimer
    interval: 3000
    repeat: true
    onTriggered: {
      if (root._modelState === 1) { rechkTimer.stop(); return }
      if (root._rechecks >= 100) { rechkTimer.stop(); return }
      root._rechecks++
      root.refresh()
    }
  }

  Process {
    id: checkProc
    running: false
    command: ["python3", root.scriptPath, "--check"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const v = String(text || "").trim()
        root._modelState = v === "ok" ? 1 : (v === "no-deps" ? 2 : 3)
        if (root._modelState === 1) {
          rechkTimer.stop()
          trTimer.restart()
        }
      }
    }
  }

  Process {
    id: trProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const t = String(text || "").trim()
        if (t !== "")
          root.result = t
        else
          root.error = "Translation unavailable"
      }
    }
  }
}
