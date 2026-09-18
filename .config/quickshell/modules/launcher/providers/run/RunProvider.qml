pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import "../../logic/match.js" as Match

// Run: `> cmd` mode plus $PATH binaries merged into unified results.
Scope {
  id: root
  property var allBins: []

  function binHits(nameTok, limit) {
    const ql = String(nameTok || "").toLowerCase()
    const cap = limit > 0 ? limit : 1000000
    let out = []
    function collect(startsWith) {
      for (let i = 0; i < root.allBins.length && out.length < cap; i++) {
        const b = root.allBins[i]
        const n = String(b.name).toLowerCase()
        if (ql === "" || (startsWith ? n.startsWith(ql) : n.includes(ql)))
          out.push({ kind: "bin", title: b.name, subtitle: b.path, icon: "\uf120", path: b.path })
      }
    }
    collect(true)
    if (out.length === 0)
      collect(false)
    return out
  }
  function runItems(rest) {
    const toks = Match.toksOf(rest)
    let out = root.binHits(toks.length > 0 ? toks[0] : "", 0)
    if (rest !== "")
      out.push({ kind: "run", title: "Run: " + rest, subtitle: rest, icon: "\uf120", cmd: rest })
    return out
  }
  function refresh() {
    if (root.allBins.length === 0 && !binProc.running)
      binProc.running = true
  }

  Process {
    id: binProc
    running: false
    command: ["sh", "-c", "printf '%s' \"$PATH\" | tr ':' '\\n' | while IFS= read -r d; do [ -d \"$d\" ] || continue; find \"$d\" -maxdepth 1 \\( -type f -o -type l \\) -executable -printf '%f\\t%p\\n' 2>/dev/null; done | awk -F'\\t' '!seen[$1]++' | sort"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const lines = String(text || "").split("\n")
        let out = []
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i].trim()
          if (!line)
            continue
          const tab = line.indexOf("\t")
          let name = "", path = ""
          if (tab >= 0) {
            name = line.slice(0, tab).trim()
            path = line.slice(tab + 1).trim()
          } else {
            name = line
            path = line
          }
          if (name)
            out.push({ name: name, path: path || name })
        }
        root.allBins = out
      }
    }
  }
}
