pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io

// Web search: `<trigger> <query>` routing backed by engines.json.
Scope {
  id: root
  property var engines: []

  function engineByTrigger(t) {
    const needle = String(t || "").toLowerCase()
    for (let i = 0; i < root.engines.length; i++)
      if (String(root.engines[i].trigger || "").toLowerCase() === needle)
        return root.engines[i]
    return null
  }
  function defaultEngine() {
    for (let i = 0; i < root.engines.length; i++)
      if (root.engines[i].default)
        return root.engines[i]
    return root.engines.length > 0 ? root.engines[0] : null
  }
  function engineIconFile(eng) {
    const ic = String((eng && eng.iconFile) || "")
    if (ic === "")
      return ""
    if (ic.startsWith("/"))
      return ic
    return Quickshell.env("HOME") + "/.config/quickshell/modules/launcher/providers/engines/icons/" + ic
  }
  function loadEngines(text) {
    let arr = null
    try {
      arr = JSON.parse(String(text || ""))
    } catch (e) {
      return
    }
    if (!Array.isArray(arr))
      return
    let out = []
    for (let i = 0; i < arr.length; i++) {
      const e = arr[i]
      if (!e || !e.trigger || !e.url)
        continue
      out.push({ icon: "󰖟", iconFile: e.icon || "", name: e.name || e.trigger, trigger: e.trigger, url: e.url, default: e.default === true })
    }
    if (out.length > 0)
      root.engines = out
  }
  function webItem(eng, rest) {
    const url = eng.url.replace("%s", encodeURIComponent(rest))
    // Show line breaks in the result row; a raw newline would break the layout.
    const preview = String(rest || "").replace(/\n/g, " ⏎ ")
    return { kind: "web", title: rest !== "" ? eng.name + ": " + preview : eng.name, subtitle: url, icon: "󰖟", iconFile: root.engineIconFile(eng), url: url }
  }
  function enginesMatching(prefix) {
    const p = String(prefix || "").toLowerCase()
    if (p === "")
      return root.engines.slice()
    let out = []
    for (let i = 0; i < root.engines.length; i++) {
      const eng = root.engines[i]
      const triggerMatch = String(eng.trigger || "").toLowerCase().startsWith(p)
      const nameMatch = (eng.name || "").toLowerCase().startsWith(p)
      if (triggerMatch || nameMatch)
        out.push(eng)
    }
    return out
  }
  function enginePickItems(prefix) {
    const matched = root.enginesMatching(prefix)
    let out = []
    for (let i = 0; i < matched.length; i++) {
      const eng = matched[i]
      out.push({ kind: "engine", title: eng.name, subtitle: eng.trigger + " — space to search", icon: "󰖟", iconFile: root.engineIconFile(eng), trigger: eng.trigger })
    }
    return out
  }
  function engineHits(toks, limit) {
    const raw = toks.join(" ")
    let out = []
    for (let i = 0; i < root.engines.length; i++) {
      const eng = root.engines[i]
      const hay = [eng.name, eng.trigger].filter(x => x).join(" ").toLowerCase()
      if (!hay.includes(raw))
        continue
      const n = String(eng.name || "").toLowerCase()
      const score = n.startsWith(raw) ? 0 : n.includes(raw) ? 1 : 2
      out.push({ kind: "engine", title: eng.name, subtitle: eng.trigger + " — w " + eng.trigger + " to search", icon: "󰖟", iconFile: root.engineIconFile(eng), trigger: eng.trigger, score: score })
    }
    out.sort((a, b) => a.score - b.score || String(a.title).localeCompare(String(b.title)))
    if (limit > 0)
      out = out.slice(0, limit)
    return out
  }
  function refresh() {
    engineFile.reload()
  }

  FileView {
    id: engineFile
    path: Quickshell.env("HOME") + "/.config/quickshell/modules/launcher/providers/engines/engines.json"
    watchChanges: true
    onLoadedChanged: if (loaded)
      root.loadEngines(text())
    onFileChanged: root.loadEngines(text())
  }
}
