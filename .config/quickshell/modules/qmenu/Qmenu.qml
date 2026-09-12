pragma ComponentBehavior: Bound
import QtQuick

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import "styles"

// Generic vertical qmenu — replacement for `rofi -dmenu -p "Prompt"`
// Controller owns state + IPC; UI delegated to styles/Default.qml and styles/Oneliner.qml
// Usage:
//   quickshell ipc call qmenu open
//   quickshell ipc call qmenu setItems '["a","b","c"]'
//   quickshell ipc call qmenu openWith '[{"label":"Foo","detail":"bar"}]' "Prompt:"
//   echo -e "a\nb" | /path/to/qmenu -p "Prompt:"  (wrapper at modules/qmenu/qmenu)
Scope {
  id: root
  property bool visible: false
  // result handling for qmenu binary (hyprminimizer) — polled via getResult
  property string _lastResult: ""
  property string _resultState: "idle" // idle | pending | ok | cancel
  // style selection — change via `quickshell ipc call qmenu setStyle "Oneliner"` or `qmenu --style Oneliner`
  property string currentStyle: "Default"
  function toggle() { visible ? close() : open() }
  function open() { visible = true; query = ""; selectedIndex = 0; _resultState = "pending"; _lastResult = "" }
  function close() {
    if (_resultState === "pending") { _resultState = "cancel"; _lastResult = "" }
    visible = false
    query = ""
    selectedIndex = 0
  }
  function forceClose() { visible = false; query = ""; selectedIndex = 0 }

  // ── API ────────────────────────────────────────────────────────────────
  property string prompt: ""
  property string placeholder: "Search…"
  // helper: unwrap JSON-encoded prompt and strip surrounding quotes
  function _unwrapPrompt(s: string): string {
    if (!s) return ""
    let v = s
    try { const parsed = JSON.parse(s); if (typeof parsed === "string") v = parsed } catch(e) {}
    v = String(v).trim()
    // strip surrounding double or single quotes if present
    if (v.length >= 2 && ((v[0] === '"' && v[v.length-1] === '"') || (v[0] === "'" && v[v.length-1] === "'"))) {
      v = v.slice(1, -1)
    }
    return v
  }
  property var items: [] // string | {label, detail, icon, data}

  // Normalize to {label, detail, raw}
  function norm(e) {
    if (typeof e === "string") return { label: e, detail: "", raw: e }
    if (e && typeof e === "object") {
      const l = e.label ?? e.name ?? e.title ?? e.text ?? String(e)
      const d = e.detail ?? e.description ?? e.subtitle ?? ""
      return { label: String(l), detail: String(d), raw: e }
    }
    return { label: String(e), detail: "", raw: e }
  }

  property string query: ""
  property int selectedIndex: 0
  property bool _blockHover: false
  function _markKeyboard() { _blockHover = true }

  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    const src = Array.isArray(items) ? items : []
    let out = []
    for (let i = 0; i < src.length; i++) out.push(norm(src[i]))
    if (q === "") return out
    const toks = q.split(/\s+/)
    return out.filter(e => {
      const hay = (e.label + " " + e.detail).toLowerCase()
      for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) return false
      return true
    })
  }

  onQueryChanged: selectedIndex = 0
  onVisibleChanged: { if (visible) { query=""; selectedIndex = 0; _blockHover = true } else { query=""; selectedIndex = 0 } }
  onItemsChanged: { const f = filtered; if (f && selectedIndex >= f.length) selectedIndex = 0 }

  // Callbacks — override via Connections or set handlers
  signal accepted(var item, int index)
  signal cancelled()
  onCancelled: { if (_resultState === "pending") { _resultState = "cancel"; _lastResult = "" } }

  function activateAt(idx) {
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    const chosen = list[idx]
    const src = Array.isArray(items) ? items : []
    let orig = -1
    for (let i = 0; i < src.length; i++) if (norm(src[i]).label === chosen.label) { orig = i; break }
    if (orig < 0) orig = idx
    _lastResult = chosen.label
    _resultState = "ok"
    root.accepted(chosen.raw, orig)
    forceClose()
  }

  // free-text submit — used by the Oneliner style when there are no items
  // (or no match) and the query is non-empty; emits accepted(text, -1)
  function submitFreeText() {
    const t = String(query || "").trim()
    if (t.length === 0) return
    _lastResult = t
    _resultState = "ok"
    root.accepted(t, -1)
    forceClose()
  }

  // keyboard helpers
  function move(delta) { _markKeyboard(); const n=filtered.length; if(n===0) return; let ni=selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni }
  function moveNoWrap(delta) { _markKeyboard(); const n=filtered.length; if(n===0) return; const ni=selectedIndex+delta; if(ni<0||ni>=n) return; selectedIndex=ni }
  function goHome() { _markKeyboard(); if(filtered.length>0) selectedIndex=0 }
  function goEnd() { _markKeyboard(); const n=filtered.length; if(n>0) selectedIndex=n-1 }
  function pageMove(dir) {
    _markKeyboard(); const n=filtered.length; if(n===0) return
    let page=6
    let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni
  }

  // ── Style loader ───────────────────────────────────────────────────────
  // Delegates UI to styles/Default.qml and styles/Oneliner.qml. Keeps logic single-source.
  // To add a style: copy styles/Default.qml → styles/<Name>.qml and add a
  // LazyLoader block below gated on `root.currentStyle === "<Name>"`.
  LazyLoader {
    active: root.visible && root.currentStyle === "Default"

    Variants {
      model: Quickshell.screens
      Default {
        qmenuRoot: root
      }
    }
  }

  LazyLoader {
    active: root.visible && root.currentStyle === "Oneliner"

    Variants {
      model: Quickshell.screens
      Oneliner {
        qmenuRoot: root
      }
    }
  }

  // default demo handler — logs to console; override via Connections in consumer
  onAccepted: (item, idx) => console.log("[qmenu] accepted", JSON.stringify(item), idx)

  IpcHandler {
    target: "qmenu"
    function toggle(): string { root.toggle(); return root.visible?"open":"closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function setPrompt(p: string): string { root.prompt = root._unwrapPrompt(p); return "ok" }
    function setPlaceholder(p: string): string { root.placeholder = p; return "ok" }
    function setStyle(s: string): string {
      try {
        // handle JSON-encoded string "\"Default\"" vs raw "Default"
        let v = s
        try { const parsed = JSON.parse(s); if (typeof parsed === "string") v = parsed } catch(e) {}
        // sanitize: only allow alphanumeric + underscore, fallback to Default
        if (!/^[A-Za-z0-9_]+$/.test(v)) v = "Default"
        root.currentStyle = v; return "ok "+v
      } catch(e){ return "err "+e }
    }
    function setItems(json: string): string {
      try {
        let v = JSON.parse(json)
        if (typeof v === "string") { try { const v2 = JSON.parse(v); if (Array.isArray(v2)) v = v2 } catch(e2) {} }
        if (!Array.isArray(v)) return "err not array got "+typeof v+":"+String(v).slice(0,60)
        root.items = v; return "ok "+v.length
      } catch(e){ return "err "+e }
    }
    function openWith(json: string, promptStr: string): string {
      try {
        if (promptStr && String(promptStr).trim().length>0) {
          const up = root._unwrapPrompt(promptStr)
          if (up.length>0) root.prompt = up
          else if (up === "") root.prompt = ""
        }
        let v = JSON.parse(json)
        if (typeof v === "string") { try { const v2 = JSON.parse(v); if (Array.isArray(v2)) v = v2 } catch(e2) {} }
        if (!Array.isArray(v)) return "err not array got "+typeof v+":"+String(v).slice(0,60)
        root.items = v; root.open(); return "ok "+v.length
      } catch(e){ return "err "+e }
    }
    function getResult(): string {
      if (root._resultState === "pending") return "__PENDING__"
      if (root._resultState === "ok") { const r = root._lastResult; root._resultState = "idle"; root._lastResult = ""; return r }
      if (root._resultState === "cancel") { root._resultState = "idle"; root._lastResult = ""; return "__CANCELLED__" }
      return "__PENDING__"
    }
    function clearResult(): string { root._resultState = "idle"; root._lastResult = ""; return "ok" }
    function isPending(): string { return root._resultState === "pending" ? "1" : "0" }
  }
  GlobalShortcut { name:"qmenuToggle"; description:"Toggle qmenu"; onPressed: root.toggle() }
}
