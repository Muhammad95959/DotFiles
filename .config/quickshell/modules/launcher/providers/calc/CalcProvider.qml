pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Calculator: explicit `= expr` mode plus implicit math detection.
Scope {
  id: root
  property string query: ""
  property string calcPrefix: "="
  property string calcResult: ""
  property string calcExpr: ""
  property string calcError: ""
  property string _pendingExpr: ""

  function calcExprOf(q) {
    const s = String(q || "").replace(/\n/g, " ").replace(/^\s+/, "")
    return (root.calcPrefix !== "" && s.startsWith(root.calcPrefix)) ? s.slice(root.calcPrefix.length).trim() : s.trim()
  }
  function isMathCandidate(s) {
    const t = String(s || "").trim()
    if (t.length < 2 || t.length > 120)
      return false
    if (/[;`$\\{}[\]]/.test(t))
      return false
    if (!/\d/.test(t))
      return false
    if (/^(https?:|ftp:|file:|\/|[a-zA-Z]:\\)/.test(t))
      return false
    if (/^[a-z]{2,}\s+\S/.test(t) && !/^(sqrt|sin|cos|tan|log|ln|exp|abs|round|min|max|pow)\s*\(/.test(t))
      return false
    return /^[\d\s+\-*/%().,^a-zA-Z_!]+$/.test(t) && /[+\-*/%^(),]/.test(t)
  }
  function isMathCandidateExplicit(s) {
    const t = String(s || "").trim()
    if (t.length < 1 || t.length > 120)
      return false
    if (/[;`$\\{}[\]]/.test(t))
      return false
    if (!/\d/.test(t))
      return false
    if (/^(https?:|ftp:|file:|\/|[a-zA-Z]:\\)/.test(t))
      return false
    return /^[\d\s+\-*/%().,^a-zA-Z_!]+$/.test(t)
  }
  function explicitItem(spaced) {
    const expr = String(spaced || "").slice(root.calcPrefix.length).trim()
    if (expr === "")
      return { kind: "calc", title: "Calculator", subtitle: "Type an expression", icon: "󰪚" }
    if (root.calcExpr === expr && root.calcResult !== "")
      return { kind: "calc", title: "= " + root.calcResult, subtitle: expr, icon: "󰪚" }
    if (root.calcExpr === expr && root.calcError !== "")
      return { kind: "calc", title: "= " + root.calcError, subtitle: expr, icon: "󰪚" }
    return { kind: "calc", title: "= " + expr, subtitle: "Calculating…", icon: "󰪚" }
  }
  // Implicit hits only surface successful evaluations, never error text.
  function implicitHit(raw) {
    if (root.calcResult !== "" && root.calcExpr === raw)
      return { kind: "calc", title: "= " + root.calcResult, subtitle: raw, icon: "󰪚" }
    return null
  }
  function reset() {
    calcTimer.stop()
    root.calcResult = ""
    root.calcExpr = ""
    root.calcError = ""
    root._pendingExpr = ""
  }
  function schedule() {
    calcTimer.restart()
  }

  onQueryChanged: schedule()

  Timer {
    id: calcTimer
    interval: 150
    repeat: false
    onTriggered: {
      const raw = String(root.query || "").replace(/\n/g, " ").replace(/^\s+/, "")
      const isExplicit = root.calcPrefix !== "" && raw.startsWith(root.calcPrefix)
      const expr = root.calcExprOf(root.query)
      const ok = isExplicit ? root.isMathCandidateExplicit(expr) : root.isMathCandidate(expr)
      if (expr === "" || !ok) {
        root.calcResult = ""
        root.calcExpr = ""
        root.calcError = ""
        root._pendingExpr = ""
        return
      }
      if (root.calcExpr === expr && (root.calcResult !== "" || root.calcError !== ""))
        return
      if (calcProc.running) {
        calcTimer.restart()
        return
      }
      root._pendingExpr = expr
      calcProc.command = ["python3", "-c", "import math,sys,re\ne=sys.argv[1].replace('^','**')\ne=re.sub(r'(\\d+)!',r'factorial(\\1)',e)\nns={k:getattr(math,k) for k in dir(math) if not k.startswith('_')}\nns.update({'abs':abs,'round':round,'min':min,'max':max})\ntry:\n v=eval(e,{'__builtins__':{}},ns)\n print(v)\nexcept Exception as ex:\n print('ERR:'+str(ex))", expr]
      calcProc.running = true
    }
  }

  Process {
    id: calcProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const expr = root._pendingExpr
        let t = String(text || "").trim()
        if (t.startsWith("ERR:")) {
          root.calcResult = ""
          root.calcError = (t.slice(4).trim() || "Error").slice(0, 80)
          root.calcExpr = expr
        } else if (t !== "") {
          root.calcResult = t.slice(0, 80)
          root.calcError = ""
          root.calcExpr = expr
        } else if (root.calcExpr === expr) {
          root.calcResult = ""
          root.calcError = ""
          root.calcExpr = ""
        }
      }
    }
  }
}
