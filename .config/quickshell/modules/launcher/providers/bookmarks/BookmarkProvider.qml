pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import "../../logic/match.js" as Match

// Bookmarks: `b <query>` mode plus matches merged into unified results.
Scope {
  id: root
  required property var bookmarkBrowsers
  property var allBookmarks: []

  function bookmarkAllowed(src) {
    if (!root.bookmarkBrowsers || root.bookmarkBrowsers.length === 0)
      return false
    const s = String(src || "").toLowerCase()
    for (let i = 0; i < root.bookmarkBrowsers.length; i++)
      if (String(root.bookmarkBrowsers[i] || "").toLowerCase() === s)
        return true
    return false
  }
  function bookmarkIcon(src) {
    const s = String(src || "").toLowerCase()
    if (s === "firefox")
      return "\uf269"
    return "\uf268"
  }
  function bookmarkHits(toks, limit) {
    const cap = limit > 0 ? limit : 1000000
    let out = []
    for (let i = 0; i < root.allBookmarks.length && out.length < cap; i++) {
      const b = root.allBookmarks[i]
      if (!root.bookmarkAllowed(b.source))
        continue
      if (toks.length === 0 || Match.matches(b.hay, toks))
        out.push({ kind: "bookmark", title: b.title, subtitle: b.url, icon: "󰃥", url: b.url, source: b.source })
    }
    return out
  }
  function refresh() {
    if (root.allBookmarks.length === 0 && !bmProc.running)
      bmProc.running = true
  }

  Process {
    id: bmProc
    running: false
    command: ["sh", "-c", "python3 \"$HOME/.config/quickshell/modules/launcher/providers/bookmarks/bookmarks.py\" 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const lines = String(text || "").split("\n")
        let out = []
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i]
          if (!line.trim())
            continue
          const parts = line.split("\t")
          if (parts.length < 2)
            continue
          const title = (parts[0] || "").trim()
          const url = (parts[1] || "").trim()
          const source = ((parts[2] || "").trim().toLowerCase() || "unknown")
          if (!url)
            continue
          out.push({ title: title || url, url: url, hay: (title + " " + url + " " + source).toLowerCase(), source: source })
        }
        root.allBookmarks = out
      }
    }
  }
}
