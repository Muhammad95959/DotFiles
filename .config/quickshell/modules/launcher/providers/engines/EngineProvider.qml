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
    return { kind: "web", title: rest !== "" ? eng.name + ": " + rest : eng.name, subtitle: url, icon: "󰖟", iconFile: root.engineIconFile(eng), url: url }
  }
  function allWebItems(rest) {
    let out = []
    for (let i = 0; i < root.engines.length; i++)
      out.push(root.webItem(root.engines[i], rest))
    return out
  }
  function searchEngines(filterText) {
    const toks = String(filterText || "").toLowerCase().trim().split(/\s+/).filter(function (t) { return t.length > 0 })
    let out = []
    for (let i = 0; i < root.engines.length; i++) {
      const eng = root.engines[i]
      const hay = String(eng.name + " " + eng.trigger).toLowerCase()
      let ok = true
      for (let j = 0; j < toks.length; j++)
        if (!hay.includes(toks[j])) { ok = false; break }
      if (!ok) continue
      out.push({ kind: "engine", title: eng.name, subtitle: eng.trigger + " — select to search", icon: "󰖟", iconFile: root.engineIconFile(eng), trigger: eng.trigger })
    }
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
