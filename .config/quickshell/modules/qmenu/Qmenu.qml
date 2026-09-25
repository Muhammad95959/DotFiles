pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import "styles"

Scope {
  id: root
  property bool visible: false
  property string _lastResult: ""
  property string _resultState: "idle"
  property string currentStyle: "Default"
  property string prompt: ""
  property string placeholder: "Search…"
  property var items: []
  property string query: ""
  property int selectedIndex: 0
  property bool _blockHover: false
  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    const src = Array.isArray(items) ? items : []
    let out = []
    for (let i = 0; i < src.length; i++)
      out.push(norm(src[i]))
    if (q === "")
      return out
    const toks = q.split(/\s+/)
    return out.filter(e => {
      const hay = (e.label + " " + e.detail).toLowerCase()
      for (let t = 0; t < toks.length; t++)
        if (!hay.includes(toks[t]))
          return false
      return true
    })
  }

  signal accepted(var item, int index)
  signal cancelled()

  function toggle() { visible ? close() : open() }
  function open() { visible = true; query = ""; selectedIndex = 0; _resultState = "pending"; _lastResult = "" }
  function close() {
    if (_resultState === "pending") { _resultState = "cancel"; _lastResult = "" }
    visible = false
    query = ""
    selectedIndex = 0
  }
  function forceClose() { visible = false; query = ""; selectedIndex = 0 }
  function _markKeyboard() { _blockHover = true }
  function _parseStr(s) {
    if (!s)
      return ""
    try { const parsed = JSON.parse(s); if (typeof parsed === "string") return parsed } catch (e) {}
    return String(s)
  }
  function _unwrapPrompt(s) {
    let v = _parseStr(s).trim()
    if (v.length >= 2 && ((v[0] === '"' && v[v.length - 1] === '"') || (v[0] === "'" && v[v.length - 1] === "'")))
      v = v.slice(1, -1)
    return v
  }
  function _parseArray(json) {
    let v = JSON.parse(json)
    if (typeof v === "string") { try { const v2 = JSON.parse(v); if (Array.isArray(v2)) v = v2 } catch (e2) {} }
    return v
  }
  function norm(e) {
    if (typeof e === "string")
      return { label: e, detail: "", raw: e }
    if (e && typeof e === "object") {
      const l = e.label ?? e.name ?? e.title ?? e.text ?? String(e)
      const d = e.detail ?? e.description ?? e.subtitle ?? ""
      return { label: String(l), detail: String(d), raw: e }
    }
    return { label: String(e), detail: "", raw: e }
  }
  function activateAt(idx) {
    const list = filtered
    if (idx < 0 || idx >= list.length)
      return
    const chosen = list[idx]
    const src = Array.isArray(items) ? items : []
    let orig = -1
    for (let i = 0; i < src.length; i++)
      if (norm(src[i]).label === chosen.label) { orig = i; break }
    if (orig < 0)
      orig = idx
    _lastResult = chosen.label
    _resultState = "ok"
    root.accepted(chosen.raw, orig)
    forceClose()
  }
  function submitFreeText() {
    const t = String(query || "").trim()
    if (t.length === 0)
      return
    _lastResult = t
    _resultState = "ok"
    root.accepted(t, -1)
    forceClose()
  }
  function move(delta) { _markKeyboard(); const n = filtered.length; if (n === 0) return; let ni = selectedIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; selectedIndex = ni }
  function moveNoWrap(delta) { _markKeyboard(); const n = filtered.length; if (n === 0) return; const ni = selectedIndex + delta; if (ni < 0 || ni >= n) return; selectedIndex = ni }
  function pageMove(dir) { _markKeyboard(); const n = filtered.length; if (n === 0) return; let ni = selectedIndex + dir * 6; if (ni < 0) ni = 0; if (ni >= n) ni = n - 1; selectedIndex = ni }

  onQueryChanged: selectedIndex = 0
  onVisibleChanged: { if (visible) { query = ""; selectedIndex = 0; _blockHover = true } else { query = ""; selectedIndex = 0 } }
  onItemsChanged: { const f = filtered; if (f && selectedIndex >= f.length) selectedIndex = 0 }
  onCancelled: { if (_resultState === "pending") { _resultState = "cancel"; _lastResult = "" } }
  onAccepted: (item, idx) => console.log("[qmenu] accepted", JSON.stringify(item), idx)

  LazyLoader {
    active: root.visible && root.currentStyle === "Default"
    Variants {
      model: Quickshell.screens
      Default { qmenuRoot: root }
    }
  }

  LazyLoader {
    active: root.visible && root.currentStyle === "Oneliner"
    Variants {
      model: Quickshell.screens
      Oneliner { qmenuRoot: root }
    }
  }

  IpcHandler {
    target: "qmenu"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function setPrompt(p: string): string { root.prompt = root._unwrapPrompt(p); return "ok" }
    function setPlaceholder(p: string): string { root.placeholder = p; return "ok" }
    function setStyle(s: string): string {
      try {
        let v = root._parseStr(s)
        if (!/^[A-Za-z0-9_]+$/.test(v))
          v = "Default"
        root.currentStyle = v
        return "ok " + v
      } catch (e) { return "err " + e }
    }
    function setItems(json: string): string {
      try {
        const v = root._parseArray(json)
        if (!Array.isArray(v))
          return "err not array got " + typeof v + ":" + String(v).slice(0, 60)
        root.items = v
        return "ok " + v.length
      } catch (e) { return "err " + e }
    }
    function openWith(json: string, promptStr: string): string {
      try {
        if (promptStr && String(promptStr).trim().length > 0)
          root.prompt = root._unwrapPrompt(promptStr)
        const v = root._parseArray(json)
        if (!Array.isArray(v))
          return "err not array got " + typeof v + ":" + String(v).slice(0, 60)
        root.items = v
        root.open()
        return "ok " + v.length
      } catch (e) { return "err " + e }
    }
    function getResult(): string {
      if (root._resultState === "pending")
        return "__PENDING__"
      if (root._resultState === "ok") { const r = root._lastResult; root._resultState = "idle"; root._lastResult = ""; return r }
      if (root._resultState === "cancel") { root._resultState = "idle"; root._lastResult = ""; return "__CANCELLED__" }
      return "__PENDING__"
    }
    function clearResult(): string { root._resultState = "idle"; root._lastResult = ""; return "ok" }
    function isPending(): string { return root._resultState === "pending" ? "1" : "0" }
  }
  GlobalShortcut { name: "qmenuToggle"; description: "Toggle qmenu"; onPressed: root.toggle() }
}
