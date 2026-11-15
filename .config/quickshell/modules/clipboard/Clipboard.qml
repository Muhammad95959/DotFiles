pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
  id: clipRoot

  // ── Lifecycle ────────────────────────────────────────────────────────
  property bool visible: false
  property bool _everOpened: false
  property var _screen: null
  property int _epoch: 0
  property bool _loading: false
  property bool _refreshPending: false

  // ── History blob (raw text, no object graph) ─────────────────────────
  property string _blob: ""
  property var _starts: []
  property string _lcBlob: ""
  property int _lineCount: 0
  property bool _fullLoaded: false
  property string _topId: ""
  property var _entryCache: ({})

  // ── View ─────────────────────────────────────────────────────────────
  property string _typed: ""
  property string query: ""
  property var _matched: []
  property var _entries: []
  property string _appliedQuery: ""
  property int _scanPos: 0
  property int _pageLimit: 2 * pageSize
  property int selectedIndex: 0
  property string _selId: ""
  property bool _pinTop: false
  property int scrollNonce: 0
  property int fieldClearNonce: 0

  readonly property int rowHeight: 42
  readonly property int visibleRows: 8
  readonly property int listSpacing: 2
  readonly property int listMargins: 2
  readonly property int drawerHeight: 470
  readonly property int pageSize: 160
  readonly property int contentHeight: visibleRows * rowHeight + (visibleRows - 1) * listSpacing + listMargins * 2

  ListModel { id: listModel }

  // ── Preview ──────────────────────────────────────────────────────────
  property string previewFullText: ""
  property string previewImagePath: ""
  property bool previewIsImage: false
  property bool _previewTruncated: false
  property string previewUpdateId: ""
  property string _previewRequestId: ""
  readonly property int maxPreviewChars: 16384
  readonly property int previewCacheMaxBytes: 400000
  property var _previewCache: []
  property int _previewBytes: 0
  property var _wantPreview: null
  readonly property int previewDebounceMs: 25
  readonly property int postActivateRefreshMs: 600

  // ── Thumbnails ───────────────────────────────────────────────────────
  property string thumbDir: "/tmp/quickshell-clipboard"
  property var _thumbReady: ({})
  property var _thumbAttempted: ({})
  property var _thumbTries: ({})
  property var _decodeQueue: []
  property var _decodeBatch: []
  property var _decoded: []
  readonly property int maxThumbs: 8

  // ── Overlays ─────────────────────────────────────────────────────────
  property int _menuIndex: -1
  property bool _wipeArmed: false
  property var _deleteQueue: []
  property string _restoreId: ""
  property string _restoreMime: ""

  // ════════════════════════════════════════════════════════════════════
  // Blob helpers
  // ════════════════════════════════════════════════════════════════════
  function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

  function fileUrl(path) {
    if (!path) return ""
    return "file://" + String(path).split("/").map(p => p === "" ? "" : encodeURIComponent(p)).join("/")
  }

  function setBlob(text, full) {
    _blob = text
    _entryCache = ({})
    const starts = []
    const n = text.length
    let p = 0
    while (true) {
      starts.push(p)
      const nl = text.indexOf("\n", p)
      if (nl < 0) break
      p = nl + 1
    }
    if (starts.length > 0 && starts[starts.length - 1] >= n) starts.pop()
    _starts = starts
    _lineCount = starts.length
    _lcBlob = text.toLowerCase()
    _fullLoaded = full
  }

  function lineAt(i) {
    if (i < 0 || i >= _starts.length) return ""
    const s = _starts[i]
    const e = (i + 1 < _starts.length) ? _starts[i + 1] - 1 : _blob.length
    return _blob.substring(s, e)
  }

  function firstId() {
    if (_lineCount === 0) return ""
    const line = lineAt(0)
    const tab = line.indexOf("\t")
    return (tab < 0 ? line : line.substring(0, tab)).trim()
  }

  function lineIndexOfId(id) {
    if (!id || _blob === "") return -1
    let off = -1
    if (_blob.length > id.length && _blob.substring(0, id.length + 1) === id + "\t") off = 0
    else {
      const at = _blob.indexOf("\n" + id + "\t")
      if (at < 0) return -1
      off = at + 1
    }
    let lo = 0
    let hi = _starts.length - 1
    while (lo <= hi) {
      const mid = (lo + hi) >> 1
      const v = _starts[mid]
      if (v === off) return mid
      if (v < off) lo = mid + 1
      else hi = mid - 1
    }
    return -1
  }

  function cleanPreview(s) {
    if (s.indexOf("\u0000") >= 0) s = s.replace(/\u0000/g, "")
    return s.replace(/[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "·")
  }

  function parseLine(i) {
    const line = lineAt(i)
    if (!line) return null
    const tab = line.indexOf("\t")
    if (tab < 0) return null
    const id = line.substring(0, tab).trim()
    if (!id) return null
    const raw = line.substring(tab + 1).trim()
    if (raw.indexOf("<meta http-equiv=") >= 0) return null
    const isImage = raw.indexOf("[[ binary data") >= 0
    let ext = ""
    let mime = "text/plain;charset=utf-8"
    if (isImage) {
      const m = raw.match(/(png|jpe?g|bmp|gif|webp|svg|tiff?|avif)/i)
      if (m) ext = m[1].toLowerCase().replace("jpeg", "jpg").replace("tif", "tiff")
      mime = ext === "" ? "application/octet-stream"
        : ext === "jpg" ? "image/jpeg"
        : "image/" + ext
    }
    return {
      id: id,
      preview: cleanPreview(raw),
      isImage: isImage,
      ext: ext,
      mime: mime,
      thumbPath: (isImage && ext !== "") ? thumbDir + "/" + id + "." + ext : "",
      line: i
    }
  }

  function entryFor(i) {
    if (i < 0 || i >= _lineCount) return null
    const hit = _entryCache[i]
    if (hit !== undefined) return hit
    const e = parseLine(i)
    _entryCache[i] = e
    return e
  }

  // ════════════════════════════════════════════════════════════════════
  // Search + window
  // ════════════════════════════════════════════════════════════════════
  function scanToken(tok) {
    const out = []
    const lc = _lcBlob
    if (lc === "" || tok === "") return out
    let li = 0
    let lineEnd = lc.indexOf("\n")
    let hit = lc.indexOf(tok)
    while (hit !== -1) {
      while (lineEnd !== -1 && hit > lineEnd) {
        li++
        lineEnd = lc.indexOf("\n", lineEnd + 1)
      }
      if (out.length === 0 || out[out.length - 1] !== li) out.push(li)
      hit = lc.indexOf(tok, hit + tok.length)
    }
    return out
  }

  function filterIndices() {
    const all = []
    const n = _lineCount
    const q = query.trim()
    if (q === "") {
      for (let i = 0; i < n; i++) all.push(i)
      return all
    }
    const toks = q.toLowerCase().split(/\s+/).filter(t => t.length > 0)
    if (toks.length === 0) {
      for (let i = 0; i < n; i++) all.push(i)
      return all
    }
    let hits = scanToken(toks[0])
    for (let t = 1; t < toks.length && hits.length > 0; t++) {
      const set = scanToken(toks[t])
      const seen = ({})
      for (let i = 0; i < set.length; i++) seen[set[i]] = 1
      const next = []
      for (let i = 0; i < hits.length; i++) if (seen[hits[i]]) next.push(hits[i])
      hits = next
    }
    return hits
  }

  function rowFor(e) {
    return { preview: e.preview, isImage: e.isImage, thumbPath: e.thumbPath }
  }

  function buildWindow(reset) {
    if (reset) {
      _entries = []
      _scanPos = 0
      listModel.clear()
    }
    const m = _matched
    while (_entries.length < _pageLimit && _scanPos < m.length) {
      const e = entryFor(m[_scanPos])
      _scanPos++
      if (!e) continue
      _entries.push(e)
      listModel.append(rowFor(e))
    }
  }

  function refilter() {
    _matched = filterIndices()
    if (query !== _appliedQuery) {
      _appliedQuery = query
      _pageLimit = 2 * pageSize
    }
    buildWindow(true)
    scrollNonce++
    restoreSelection()
  }

  function restoreSelection() {
    const n = _entries.length
    if (n === 0) {
      _selId = ""
      selectedIndex = 0
      showPreview()
      return
    }
    let at = -1
    if (_pinTop) at = 0
    else if (_selId !== "") {
      for (let i = 0; i < n; i++) if (_entries[i].id === _selId) { at = i; break }
    }
    if (at < 0) at = Math.max(0, Math.min(selectedIndex, n - 1))
    const changed = selectedIndex !== at
    if (changed) selectedIndex = at
    _selId = _entries[at].id
    if (!changed) { showPreview(); schedulePreview() }
  }

  function loadMore() {
    if (_entries.length < _matched.length) {
      _pageLimit += pageSize
      buildWindow(false)
      return
    }
    if (!_fullLoaded) requestFull()
  }

  // ════════════════════════════════════════════════════════════════════
  // Navigation
  // ════════════════════════════════════════════════════════════════════
  function rememberSel() {
    const e = _entries[selectedIndex]
    if (e) _selId = e.id
  }

  function move(delta) {
    const n = _entries.length
    if (n === 0) return
    _pinTop = false
    let ni = selectedIndex + delta
    if (ni < 0) ni = n - 1
    if (ni >= n) ni = 0
    selectedIndex = ni
  }

  function moveNoWrap(delta) {
    const n = _entries.length
    if (n === 0) return
    _pinTop = false
    const ni = selectedIndex + delta
    if (ni < 0 || ni >= n) return
    selectedIndex = ni
  }

  function moveTo(i) {
    const n = _entries.length
    if (n === 0) return
    _pinTop = false
    selectedIndex = Math.max(0, Math.min(i, n - 1))
  }

  function pageMove(dir) {
    const n = _entries.length
    if (n === 0) return
    _pinTop = false
    selectedIndex = Math.max(0, Math.min(selectedIndex + dir * visibleRows, n - 1))
  }

  onSelectedIndexChanged: {
    if (selectedIndex >= _entries.length && _entries.length > 0) {
      selectedIndex = _entries.length - 1
      return
    }
    rememberSel()
    showPreview()
    schedulePreview()
    requestSelThumb()
  }

  // ════════════════════════════════════════════════════════════════════
  // Open / close / refresh
  // ════════════════════════════════════════════════════════════════════
  function focusedScreen() {
    const mon = Hyprland.focusedMonitor
    const list = Quickshell.screens
    if (mon) {
      for (let i = 0; i < list.length; i++) {
        try { if (Hyprland.monitorFor(list[i]) === mon) return list[i] } catch (e) {}
      }
    }
    return list.length > 0 ? list[0] : null
  }

  function toggle() { visible ? close() : open() }

  function open() {
    if (visible) return
    _everOpened = true
    _screen = focusedScreen()
    _typed = ""
    query = ""
    _pageLimit = 2 * pageSize
    _selId = ""
    _pinTop = true
    selectedIndex = 0
    _menuIndex = -1
    _wipeArmed = false
    visible = true
    resetFieldText()
    refilter()
    showPreview()
    schedulePreview()
    refresh()
  }

  function close() {
    if (!visible && !_everOpened) return
    visible = false
    _typed = ""
    query = ""
    _pageLimit = 2 * pageSize
    selectedIndex = 0
    _selId = ""
    _pinTop = false
    _menuIndex = -1
    _wipeArmed = false
    _wantPreview = null
    resetFieldText()
    if (decodeImagesProc.running) decodeImagesProc.running = false
    const batch = _decodeBatch
    for (let i = 0; i < batch.length; i++) {
      const p = batch[i].substring(batch[i].indexOf(":") + 1)
      delete _thumbAttempted[p]
    }
    _decodeQueue = []
    _decodeBatch = []
    _decoded = []
    const rid = _restoreId
    const rmime = _restoreMime
    _restoreId = ""
    _restoreMime = ""
    if (rid) startRestore(rid, rmime)
  }

  function refresh() {
    if (fastProc.running || fullProc.running) {
      _refreshPending = true
      return
    }
    _loading = true
    fastProc.ep = _epoch
    fastProc.running = true
  }

  function requestFull() {
    if (fullProc.running) return
    fullProc.ep = _epoch
    fullProc.running = true
  }

  function ingestFast(t, ep) {
    if (ep !== _epoch) return
    if (t.length === 0) return
    const nl = t.indexOf("\n")
    const head = nl < 0 ? t : t.substring(0, nl)
    const tab = head.indexOf("\t")
    const id = (tab < 0 ? head : head.substring(0, tab)).trim()
    if (id === "") return
    if (id === _topId && _lineCount > 0) return
    _topId = id
    setBlob(t, false)
    refilter()
    requestFull()
  }

  function ingestFull(t, ep) {
    if (ep !== _epoch) return
    if (t.length === 0 || t === _blob) {
      _loading = false
      return
    }
    setBlob(t, true)
    _topId = firstId()
    refilter()
    _loading = false
  }

  function onFastExit() {
    _loading = false
    if (_refreshPending) {
      _refreshPending = false
      Qt.callLater(() => clipRoot.refresh())
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Copy / delete / wipe
  // ════════════════════════════════════════════════════════════════════
  function copyEntry(e) {
    if (!e) return
    _restoreId = ""
    _restoreMime = ""
    if (restoreProc.running) restoreProc.running = false
    copyProc.command = ["sh", "-c", "exec cliphist decode \"$1\" | wl-copy -t \"$2\"", "sh", e.id, e.mime]
    copyProc.running = true
  }

  function startRestore(id, mime) {
    if (!id || lineIndexOfId(id) < 0) return
    restoreProc.command = ["sh", "-c", "exec cliphist decode \"$1\" | wl-copy -t \"$2\"", "sh", id, mime]
    restoreProc.running = true
  }

  function activateAt(idx, keepOpen) {
    const e = _entries[idx]
    if (!e) return
    copyEntry(e)
    if (!keepOpen) close()
  }

  function deleteSelected() {
    const e = _entries[selectedIndex]
    if (e) deleteId(e.id)
  }

  function armWipe() {
    if (_wipeArmed) {
      _wipeArmed = false
      wipeArmTimer.stop()
      wipe()
      return
    }
    _wipeArmed = true
    wipeArmTimer.restart()
  }

  function deleteId(id) {
    if (!id) return
    const idx = selectedIndex
    const below = _entries[idx + 1] || null
    const above = _entries[idx - 1] || null
    const next = below || above
    _selId = next ? next.id : ""
    const restore = above || below
    if (restore) {
      _restoreId = restore.id
      _restoreMime = restore.mime
    }
    previewDrop(id)
    _deleteQueue.push(id)
    const li = lineIndexOfId(id)
    if (li >= 0) removeLineAt(li)
    _menuIndex = -1
    startNextDelete()
  }

  function removeLineAt(li) {
    if (li < 0 || li >= _starts.length) return
    const s = _starts[li]
    const e = (li + 1 < _starts.length) ? _starts[li + 1] : _blob.length
    setBlob(_blob.substring(0, s) + _blob.substring(e), _fullLoaded)
    _topId = firstId()
    if (_lineCount === 0) _fullLoaded = true

    // shift matches rather than rebuilding the window: a model reset drops the scroll position
    const old = _matched
    const matched = []
    let removedPos = 0
    for (let i = 0; i < old.length; i++) {
      if (old[i] === li) { removedPos = i; continue }
      matched.push(old[i] > li ? old[i] - 1 : old[i])
    }
    _matched = matched
    if (removedPos < _scanPos) _scanPos--

    let wi = -1
    for (let i = 0; i < _entries.length; i++) {
      if (_entries[i].line === li) wi = i
      else if (_entries[i].line > li) _entries[i].line--
    }
    if (wi >= 0) {
      _entries.splice(wi, 1)
      if (wi < listModel.count) listModel.remove(wi)
    }
    buildWindow(false)

    let si = selectedIndex
    if (si >= _entries.length) si = _entries.length - 1
    if (si < 0) si = 0
    scrollNonce++
    if (si !== selectedIndex) selectedIndex = si
    else {
      if (_entries.length > 0) _selId = _entries[si].id
      showPreview()
      schedulePreview()
      requestSelThumb()
    }
  }

  function startNextDelete() {
    if (_deleteQueue.length === 0 || deleteProc.running) return
    const id = _deleteQueue.shift()
    deleteProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete; rm -f " + shQuote(thumbDir) + "/$1.*", "sh", id]
    deleteProc.ep = _epoch
    deleteProc.running = true
  }

  function wipe() {
    _epoch++
    if (fastProc.running) fastProc.running = false
    if (fullProc.running) fullProc.running = false
    if (deleteProc.running) deleteProc.running = false
    if (decodeImagesProc.running) decodeImagesProc.running = false
    if (imagePreviewProc.running) imagePreviewProc.running = false
    if (previewProc.running) previewProc.running = false
    if (prefetchProc.running) prefetchProc.running = false
    if (copyProc.running) copyProc.running = false
    if (restoreProc.running) restoreProc.running = false
    _deleteQueue = []
    _restoreId = ""
    _restoreMime = ""
    _decodeQueue = []
    _decodeBatch = []
    _decoded = []
    _thumbReady = ({})
    _thumbAttempted = ({})
    _thumbTries = ({})
    _previewCache = []
    _previewBytes = 0
    _previewRequestId = ""
    previewUpdateId = ""
    previewFullText = ""
    previewImagePath = ""
    previewIsImage = false
    _previewTruncated = false
    _fullLoaded = true
    _topId = ""
    setBlob("", true)
    _selId = ""
    selectedIndex = 0
    refilter()
    Quickshell.execDetached(["sh", "-c", "cliphist wipe; rm -rf " + shQuote(thumbDir) + "/* 2>/dev/null || true"])
  }

  // ════════════════════════════════════════════════════════════════════
  // Preview
  // ════════════════════════════════════════════════════════════════════
  function previewCached(id) {
    for (let i = 0; i < _previewCache.length; i++) {
      if (_previewCache[i].id === id) return _previewCache[i].text
    }
    return null
  }

  function previewStore(id, text) {
    if (!id) return
    if (text.length > maxPreviewChars) text = text.substring(0, maxPreviewChars)
    const old = previewCached(id)
    let list = _previewCache.filter(e => e.id !== id)
    let bytes = _previewBytes - (old === null ? 0 : old.length)
    list.push({ id: id, text: text })
    bytes += text.length
    while (bytes > previewCacheMaxBytes && list.length > 1) {
      bytes -= list.shift().text.length
    }
    _previewCache = list
    _previewBytes = bytes
  }

  function previewDrop(id) {
    const old = previewCached(id)
    if (old === null) return
    _previewCache = _previewCache.filter(e => e.id !== id)
    _previewBytes -= old.length
  }

  function showPreview() {
    if (!visible) return
    const n = _entries.length
    if (n === 0 || selectedIndex < 0 || selectedIndex >= n) {
      previewFullText = ""
      previewImagePath = ""
      previewIsImage = false
      previewUpdateId = ""
      _previewRequestId = ""
      return
    }
    const e = _entries[selectedIndex]
    if (e.id === previewUpdateId) return
    previewUpdateId = e.id
    _previewRequestId = e.id
    previewIsImage = e.isImage
    _previewTruncated = false
    if (e.isImage) {
      previewImagePath = e.thumbPath
      previewFullText = e.preview
    } else {
      previewImagePath = ""
      const hit = previewCached(e.id)
      previewFullText = hit !== null ? hit : e.preview
    }
  }

  function fetchPreview() {
    if (!visible) return
    const n = _entries.length
    if (selectedIndex < 0 || selectedIndex >= n) return
    const e = _entries[selectedIndex]
    if (e.id !== _previewRequestId) return
    if (e.isImage) {
      if (!e.thumbPath || _thumbReady[e.thumbPath]) return
      if (imagePreviewProc.running) {
        if (imagePreviewProc.targetPath !== e.thumbPath) _wantPreview = e
        return
      }
      _wantPreview = null
      startImagePreview(e)
    } else {
      if (previewCached(e.id) !== null) return
      if (previewProc.running) return
      previewProc.command = ["sh", "-c", "printf '__ID__%s\\n' \"$1\"; exec cliphist decode \"$1\" 2>/dev/null | head -c " + maxPreviewChars, "sh", e.id]
      previewProc.running = true
    }
  }

  function startImagePreview(e) {
    if (!e || !e.thumbPath) return
    imagePreviewProc.targetPath = e.thumbPath
    imagePreviewProc.command = ["sh", "-c",
      "mkdir -p " + shQuote(thumbDir) + "; p=\"$1\"; id=\"$2\"; " +
      "[ -s \"$p\" ] && { echo \"READY:$p\"; exit 0; }; " +
      "t=\"$p.tmp\"; if cliphist decode \"$id\" > \"$t\" 2>/dev/null && [ -s \"$t\" ]; then mv -f \"$t\" \"$p\"; echo \"READY:$p\"; else rm -f \"$t\"; fi",
      "sh", e.thumbPath, e.id]
    imagePreviewProc.running = true
  }

  function ingestPreview(raw) {
    const nl = raw.indexOf("\n")
    if (nl < 4) return
    const head = raw.substring(0, nl)
    if (head.substring(0, 6) !== "__ID__") return
    const id = head.substring(6)
    const body = raw.substring(nl + 1)
    previewStore(id, body)
    if (id !== _previewRequestId) return
    if (previewIsImage) return
    previewFullText = body
    _previewTruncated = body.length >= maxPreviewChars - 4
    prefetchTimer.restart()
  }

  function prefetchNext() {
    if (!visible) return
    if (prefetchProc.running || previewProc.running) return
    const i = selectedIndex + 1
    if (i >= _entries.length) return
    const e = _entries[i]
    if (!e || e.isImage) return
    if (previewCached(e.id) !== null) return
    prefetchProc.command = ["sh", "-c", "printf '__ID__%s\\n' \"$1\"; exec cliphist decode \"$1\" 2>/dev/null | head -c " + maxPreviewChars, "sh", e.id]
    prefetchProc.running = true
  }

  function schedulePreview() {
    previewTimer.restart()
  }

  // ════════════════════════════════════════════════════════════════════
  // Thumbnails
  // ════════════════════════════════════════════════════════════════════
  function thumbSource(path) {
    if (!path || !_thumbReady[path]) return ""
    return fileUrl(path)
  }

  function markThumbsReady(paths) {
    if (!paths || paths.length === 0) return
    const next = Object.assign({}, _thumbReady)
    let changed = false
    for (let i = 0; i < paths.length; i++) {
      const p = paths[i]
      if (p && !next[p]) { next[p] = 1; changed = true }
    }
    if (changed) _thumbReady = next
  }

  function thumbBatchCommand(batch) {
    const items = batch.map(s => shQuote(s)).join(" ")
    return ["sh", "-c",
      "mkdir -p " + shQuote(thumbDir) + "; for entry in " + items + "; do " +
      "id=\"${entry%%:*}\"; path=\"${entry#*:}\"; " +
      "[ -s \"$path\" ] && { echo \"READY:$path\"; continue; }; " +
      "t=\"$path.tmp\"; if cliphist decode \"$id\" > \"$t\" 2>/dev/null && [ -s \"$t\" ]; then mv -f \"$t\" \"$path\"; echo \"READY:$path\"; else rm -f \"$t\"; fi; done"]
  }

  function requestThumbs(entries) {
    if (!entries || entries.length === 0) return
    if (!visible) return
    const q = _decodeQueue.slice()
    let added = false
    for (let i = 0; i < entries.length; i++) {
      const e = entries[i]
      if (!e || !e.isImage || !e.thumbPath) continue
      if (_thumbReady[e.thumbPath] || _thumbAttempted[e.thumbPath]) continue
      _thumbAttempted[e.thumbPath] = 1
      q.push(e.id + ":" + e.thumbPath)
      added = true
    }
    if (!added) return
    if (decodeImagesProc.running) {
      _decodeQueue = q
      return
    }
    _decodeBatch = q.slice(0, maxThumbs)
    _decodeQueue = q.slice(_decodeBatch.length)
    decodeImagesProc.ep = _epoch
    decodeImagesProc.command = thumbBatchCommand(_decodeBatch)
    decodeImagesProc.running = true
  }

  function requestSelThumb() {
    const e = _entries[selectedIndex]
    if (e && e.isImage) requestThumbs([e])
  }

  function onDecodeExit() {
    const done = _decoded
    const batch = _decodeBatch
    _decoded = []
    _decodeBatch = []
    if (decodeImagesProc.ep !== _epoch) {
      // the batch was dropped mid-flight; let those thumbs be requested again later
      for (let i = 0; i < batch.length; i++) delete _thumbAttempted[batch[i].substring(batch[i].indexOf(":") + 1)]
      return
    }
    markThumbsReady(done)
    const ready = ({})
    for (let i = 0; i < done.length; i++) ready[done[i]] = 1
    for (let i = 0; i < batch.length; i++) {
      const p = batch[i].substring(batch[i].indexOf(":") + 1)
      if (ready[p]) { delete _thumbTries[p]; continue }
      const tries = (_thumbTries[p] || 0) + 1
      _thumbTries[p] = tries
      if (tries < 2) delete _thumbAttempted[p]
    }
    const rest = _decodeQueue
    if (rest.length > 0) {
      _decodeBatch = rest.slice(0, maxThumbs)
      _decodeQueue = rest.slice(maxThumbs)
      decodeImagesProc.ep = _epoch
      decodeImagesProc.command = thumbBatchCommand(_decodeBatch)
      decodeImagesProc.running = true
    } else {
      schedulePreview()
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // Keyboard
  // ════════════════════════════════════════════════════════════════════
  function onTyped(t) {
    if (t === _typed) return
    _typed = t
    if (t === query) return
    queryTimer.restart()
  }

  function resetFieldText() {
    fieldClearNonce++
  }

  function clearSearch() {
    _typed = ""
    query = ""
    _pageLimit = 2 * pageSize
    _selId = ""
    selectedIndex = 0
    resetFieldText()
    refilter()
  }

  function handleKey(event) {
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    const shift = (event.modifiers & Qt.ShiftModifier) !== 0
    const k = event.key

    if (k === Qt.Key_Escape) {
      if (_menuIndex >= 0) { _menuIndex = -1; return true }
      if (_typed !== "" || query !== "") clearSearch()
      else close()
      return true
    }
    if (k === Qt.Key_Up) { moveNoWrap(-1); return true }
    if (k === Qt.Key_Down) { moveNoWrap(1); return true }
    if (k === Qt.Key_PageUp) { pageMove(-1); return true }
    if (k === Qt.Key_PageDown) { pageMove(1); return true }
    if (k === Qt.Key_Return || k === Qt.Key_Enter) { activateAt(selectedIndex); return true }
    if (k === Qt.Key_Tab) { move(shift ? -1 : 1); return true }
    if (k === Qt.Key_Backtab) { move(-1); return true }
    if (ctrl && k === Qt.Key_N) { moveNoWrap(1); return true }
    if (ctrl && k === Qt.Key_P) { moveNoWrap(-1); return true }

    if (k === Qt.Key_Delete) {
      if (_typed === "" && shift) { armWipe(); return true }
      deleteSelected()
      return true
    }
    if (k === Qt.Key_Home && _typed === "") { moveTo(0); return true }
    if (k === Qt.Key_End && _typed === "") { moveTo(_entries.length - 1); return true }
    return false
  }

  // ════════════════════════════════════════════════════════════════════
  // Processes
  // ════════════════════════════════════════════════════════════════════
  Process {
    id: fastProc
    property int ep: 0
    running: false
    command: ["sh", "-c", "exec cliphist list 2>/dev/null | head -n 400"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: clipRoot.ingestFast(String(text || ""), fastProc.ep)
    }
    onExited: clipRoot.onFastExit()
  }

  Process {
    id: fullProc
    property int ep: 0
    running: false
    command: ["cliphist", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: clipRoot.ingestFull(String(text || ""), fullProc.ep)
    }
    onExited: {
      if (fullProc.ep === clipRoot._epoch) clipRoot._loading = false
    }
  }

  Process {
    id: deleteProc
    property int ep: 0
    running: false
    onExited: (code, status) => {
      if (deleteProc.ep !== clipRoot._epoch) return
      if (code !== 0) {
        clipRoot._epoch++
        clipRoot.refresh()
      }
      if (clipRoot._deleteQueue.length > 0) clipRoot.startNextDelete()
    }
  }

  Process {
    id: copyProc
    running: false
    onExited: (code, status) => {
      if (code !== 0) Quickshell.execDetached(["notify-send", "-t", "2500", "-a", "Clipboard", "Copy failed", "cliphist decode / wl-copy exit " + code])
      clipRoot.postActivateTimer.restart()
    }
  }

  Process {
    id: restoreProc
    running: false
    onExited: (code, status) => {
      if (code === 0 && clipRoot.visible) clipRoot.postActivateTimer.restart()
    }
  }

  Process {
    id: previewProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: clipRoot.ingestPreview(String(text || ""))
    }
    onExited: clipRoot.schedulePreview()
  }

  Process {
    id: prefetchProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const raw = String(text || "")
        const nl = raw.indexOf("\n")
        if (nl < 7) return
        const head = raw.substring(0, nl)
        if (head.substring(0, 6) !== "__ID__") return
        clipRoot.previewStore(head.substring(6), raw.substring(nl + 1))
      }
    }
  }

  Process {
    id: imagePreviewProc
    property string targetPath: ""
    running: false
    stdout: SplitParser {
      onRead: d => {
        const s = String(d || "")
        if (s.substring(0, 6) === "READY:") clipRoot.markThumbsReady([s.substring(6).trim()])
      }
    }
    onExited: {
      imagePreviewProc.targetPath = ""
      const w = clipRoot._wantPreview
      clipRoot._wantPreview = null
      if (w && clipRoot.visible && w.id === clipRoot._previewRequestId) clipRoot.startImagePreview(w)
    }
  }

  Process {
    id: decodeImagesProc
    property int ep: 0
    running: false
    stdout: SplitParser {
      onRead: d => {
        const s = String(d || "")
        if (s.substring(0, 6) === "READY:") clipRoot._decoded.push(s.substring(6).trim())
      }
    }
    onExited: clipRoot.onDecodeExit()
  }

  Process {
    id: pruneProc
    running: false
    command: ["sh", "-c", "mkdir -p " + clipRoot.shQuote(clipRoot.thumbDir) + "; find " + clipRoot.shQuote(clipRoot.thumbDir) + " -type f -mmin +1440 -delete 2>/dev/null || true"]
  }

  // ════════════════════════════════════════════════════════════════════
  // Timers
  // ════════════════════════════════════════════════════════════════════
  Timer {
    id: queryTimer
    interval: 60
    repeat: false
    onTriggered: {
      if (clipRoot._typed === clipRoot.query) return
      clipRoot.query = clipRoot._typed
      clipRoot._pageLimit = 2 * clipRoot.pageSize
      clipRoot._selId = ""
      clipRoot.selectedIndex = 0
      clipRoot.refilter()
    }
  }

  Timer {
    id: previewTimer
    interval: clipRoot.previewDebounceMs
    repeat: false
    onTriggered: clipRoot.fetchPreview()
  }

  Timer {
    id: prefetchTimer
    interval: 260
    repeat: false
    onTriggered: clipRoot.prefetchNext()
  }

  Timer {
    id: postActivateTimer
    interval: clipRoot.postActivateRefreshMs
    repeat: false
    onTriggered: clipRoot.refresh()
  }

  Timer {
    id: wipeArmTimer
    interval: 2500
    repeat: false
    onTriggered: clipRoot._wipeArmed = false
  }

  Timer {
    id: warmTimer
    interval: 900
    repeat: false
    onTriggered: clipRoot.refresh()
  }

  Timer {
    id: fullWarmTimer
    interval: 3200
    repeat: false
    onTriggered: clipRoot.requestFull()
  }

  Component.onCompleted: {
    pruneProc.running = true
    warmTimer.restart()
    fullWarmTimer.restart()
  }

  // ════════════════════════════════════════════════════════════════════
  // UI
  // ════════════════════════════════════════════════════════════════════
  LazyLoader {
    active: clipRoot.visible || clipRoot._everOpened

    Variants {
      model: clipRoot._screen ? [clipRoot._screen] : []
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: clipRoot.visible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: clipRoot.close() }
        Rectangle { anchors.fill: parent; color: Theme.dim }

        Rectangle {
          width: parent.width
          height: clipRoot.drawerHeight
          anchors.top: parent.top
          color: Theme.bg
          clip: true
          focus: true
          Keys.onPressed: event => { if (clipRoot.handleKey(event)) event.accepted = true }
          MouseArea {
            anchors.fill: parent
            onClicked: { clipRoot._menuIndex = -1; searchField.forceActiveFocus() }
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            anchors.topMargin: 0
            spacing: 8

            // ── Header ────────────────────────────────────────────────
            Rectangle {
              Layout.fillWidth: true
              height: clipRoot.rowHeight
              color: Theme.bg
              Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 2; color: Theme.border; opacity: 0.6 }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10
                Text { text: " "; color: Theme.fg; opacity: 0.85; font.family: Theme.nerdFont; font.pixelSize: 14 }
                TextInput {
                  id: searchField
                  Layout.fillWidth: true
                  color: Theme.fg
                  font.family: Theme.monoFont
                  font.pixelSize: 13
                  focus: true
                  activeFocusOnTab: false
                  onTextChanged: clipRoot.onTyped(text)
                  onAccepted: clipRoot.activateAt(clipRoot.selectedIndex)
                  Keys.onPressed: event => { if (clipRoot.handleKey(event)) event.accepted = true }
                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard: search or select..."
                    color: Theme.fg
                    opacity: 0.45
                    font.family: Theme.monoFont
                    font.pixelSize: 13
                    visible: searchField.text === ""
                  }
                }
                Text {
                  visible: searchField.text !== ""
                  text: ""
                  color: Theme.fg
                  opacity: 0.55
                  font.family: Theme.nerdFont
                  font.pixelSize: 12
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: clipRoot.clearSearch() }
                }
                Text {
                  text: clipRoot._matched.length + "/" + clipRoot._lineCount
                  color: Theme.fg
                  opacity: clipRoot._loading ? 0.25 : 0.45
                  font.family: Theme.monoFont
                  font.pixelSize: 11
                }
              }
            }

            // ── Body ──────────────────────────────────────────────────
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: clipRoot.contentHeight
              clip: true
              Row {
                anchors.fill: parent
                spacing: 0

                Item {
                  width: (parent.width - 1) / 2
                  height: parent.height
                  clip: true

                  ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.margins: clipRoot.listMargins
                    anchors.rightMargin: 10
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: clipRoot.listSpacing
                    model: listModel
                    reuseItems: true
                    cacheBuffer: 240

                    function sync() {
                      const idx = clipRoot.selectedIndex
                      if (idx < 0) return
                      const pitch = clipRoot.rowHeight + clipRoot.listSpacing
                      const start = Math.floor(idx / clipRoot.visibleRows) * clipRoot.visibleRows
                      const target = start * pitch
                      if (Math.abs(contentY - target) < 1) return
                      const n = Math.max(count, clipRoot._entries.length)
                      const maxY = Math.max(0, n * pitch - clipRoot.listSpacing - height)
                      contentY = Math.min(target, maxY)
                    }

                    Component.onCompleted: { sync(); thumbTimer.restart() }
                    onCountChanged: thumbTimer.restart()
                    onMovementEnded: thumbTimer.restart()
                    onContentYChanged: thumbTimer.restart()
                    onHeightChanged: thumbTimer.restart()
                    onAtYEndChanged: if (atYEnd && contentHeight > height + 1) clipRoot.loadMore()

                    // lives here so `listView` resolves: the root scope cannot see ids inside this component
                    Timer {
                      id: thumbTimer
                      interval: 120
                      repeat: false
                      onTriggered: {
                        const pitch = clipRoot.rowHeight + clipRoot.listSpacing
                        const rows = Math.max(1, Math.ceil(listView.height / pitch))
                        const first = Math.max(0, Math.floor(listView.contentY / pitch))
                        const last = Math.min(listView.count - 1, first + rows - 1)
                        const items = []
                        for (let i = first; i <= last; i++) {
                          const e = clipRoot._entries[i]
                          if (e && e.isImage) items.push(e)
                        }
                        clipRoot.requestThumbs(items)
                      }
                    }

                    Connections {
                      target: clipRoot
                      function onSelectedIndexChanged() { listView.sync() }
                      function onScrollNonceChanged() { listView.sync() }
                    }

                    footer: Item {
                      width: listView.width
                      height: {
                        const n = listView.count
                        if (n <= clipRoot.visibleRows) return 0
                        const pitch = clipRoot.rowHeight + clipRoot.listSpacing
                        const lastPageStart = Math.floor((n - 1) / clipRoot.visibleRows) * clipRoot.visibleRows
                        const content = n * clipRoot.rowHeight + (n - 1) * clipRoot.listSpacing
                        const viewport = clipRoot.contentHeight - clipRoot.listMargins * 2
                        return Math.max(0, lastPageStart * pitch + viewport - content)
                      }
                    }

                    delegate: Item {
                      id: del
                      required property string preview
                      required property bool isImage
                      required property string thumbPath
                      required property int index
                      width: listView.width - 8
                      height: clipRoot.rowHeight

                      Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: clipRoot.selectedIndex === index ? Theme.surfaceHover : "transparent"
                      }

                      Item {
                        id: thumbBox
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        clip: true

                        Rectangle {
                          anchors.fill: parent
                          visible: del.isImage
                          color: "transparent"
                          border.color: Theme.border
                          border.width: 1
                          radius: 2
                          opacity: 0.4
                        }
                        Image {
                          id: thumbImg
                          anchors.fill: parent
                          visible: del.isImage && status === Image.Ready
                          source: del.isImage ? clipRoot.thumbSource(del.thumbPath) : ""
                          asynchronous: true
                          cache: true
                          smooth: true
                          fillMode: Image.PreserveAspectCrop
                          sourceSize.width: 56
                          sourceSize.height: 56
                        }
                        Text {
                          anchors.centerIn: parent
                          visible: !del.isImage || thumbImg.status !== Image.Ready
                          text: "󰅍"
                          color: Theme.fg
                          opacity: 0.55
                          font.family: Theme.nerdFont
                          font.pixelSize: 14
                        }
                      }

                      Text {
                        anchors.left: thumbBox.right
                        anchors.leftMargin: 10
                        anchors.right: del.isImage ? imgBadge.left : parent.right
                        anchors.rightMargin: del.isImage ? 8 : 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: del.preview
                        textFormat: Text.PlainText
                        color: Theme.fg
                        font.family: Theme.monoFont
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        opacity: del.isImage ? 0.8 : 1
                      }

                      Text {
                        id: imgBadge
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: del.isImage
                        text: "IMG"
                        color: Theme.fg
                        opacity: 0.4
                        font.family: Theme.monoFont
                        font.pixelSize: 9
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                          clipRoot._pinTop = false
                          if (mouse.button === Qt.RightButton) {
                            clipRoot.selectedIndex = del.index
                            clipRoot._menuIndex = del.index
                          } else if (clipRoot.selectedIndex === del.index) {
                            clipRoot.activateAt(del.index)
                          } else {
                            clipRoot.selectedIndex = del.index
                          }
                        }
                        onDoubleClicked: clipRoot.activateAt(del.index)
                      }
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: clipRoot._everOpened && listModel.count === 0
                      text: clipRoot._lineCount === 0 ? "Clipboard empty — copy something first" : "No matches for \"" + clipRoot.query + "\""
                      textFormat: Text.PlainText
                      color: Theme.fg
                      opacity: 0.5
                      font.family: Theme.monoFont
                      font.pixelSize: 12
                    }

                    Rectangle {
                      visible: listView.contentHeight > listView.height + 1
                      width: 4
                      radius: 2
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      anchors.rightMargin: 2
                      anchors.topMargin: 2
                      anchors.bottomMargin: 2
                      color: Theme.surface
                      opacity: 0.6
                      Rectangle {
                        width: parent.width
                        height: Math.max(8, parent.height * (listView.height / Math.max(1, listView.contentHeight)))
                        y: (parent.height - height) * (listView.contentY / Math.max(1, listView.contentHeight - listView.height))
                        radius: 2
                        color: Theme.border
                      }
                    }
                  }
                }

                Rectangle { width: 1; height: parent.height; color: Theme.border; opacity: 0.35 }

                Rectangle {
                  width: (parent.width - 1) / 2
                  height: parent.height
                  color: Theme.surface
                  clip: true

                  Image {
                    id: previewImg
                    visible: clipRoot.previewIsImage && clipRoot.previewImagePath !== "" && status === Image.Ready
                    anchors.fill: parent
                    anchors.margins: 8
                    source: clipRoot.previewIsImage ? clipRoot.thumbSource(clipRoot.previewImagePath) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    sourceSize.width: 512
                    sourceSize.height: 512
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: clipRoot.previewIsImage && previewImg.status !== Image.Ready
                    text: "decoding image…"
                    color: Theme.fg
                    opacity: 0.4
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                  }

                  Flickable {
                    visible: !clipRoot.previewIsImage
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: previewText.implicitHeight
                    contentWidth: width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Text {
                      id: previewText
                      width: parent.width
                      text: clipRoot.previewFullText
                      color: Theme.fg
                      font.family: Theme.monoFont
                      font.pixelSize: 12
                      wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                      textFormat: Text.PlainText
                    }
                  }

                  Text {
                    visible: text !== ""
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    text: clipRoot._previewTruncated ? "showing first " + (clipRoot.maxPreviewChars / 1024) + " KB" : ""
                    color: Theme.fg
                    opacity: 0.35
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                  }

                  Text {
                    visible: clipRoot._everOpened && listModel.count === 0
                    anchors.centerIn: parent
                    text: "No preview"
                    color: Theme.fg
                    opacity: 0.35
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                  }
                }
              }
            }

            // ── Footer ────────────────────────────────────────────────
            Rectangle {
              Layout.fillWidth: true
              height: 28
              color: Theme.surface
              radius: Theme.radiusSm
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Text {
                  text: clipRoot._wipeArmed ? "Shift+Del again to wipe everything" : "↵ Copy"
                  color: clipRoot._wipeArmed ? Theme.urgent : Theme.fg
                  font.family: Theme.monoFont
                  font.pixelSize: 10
                  font.bold: true
                }
                Text { text: "•"; color: Theme.fg; opacity: 0.3; font.pixelSize: 10 }
                Text { text: "Del Delete"; color: Theme.fg; opacity: 0.7; font.family: Theme.monoFont; font.pixelSize: 10 }
                Text { text: "•"; color: Theme.fg; opacity: 0.3; font.pixelSize: 10 }
                Text { text: "Esc Close"; color: Theme.fg; opacity: 0.7; font.family: Theme.monoFont; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text {
                  visible: listModel.count < clipRoot._matched.length
                  text: "scroll for more"
                  color: Theme.fg
                  opacity: 0.4
                  font.family: Theme.monoFont
                  font.pixelSize: 10
                }
                Text { text: clipRoot._lineCount + " items"; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 10 }
              }
            }
          }

          // ── Action menu (right click) ───────────────────────────────
          Rectangle {
            id: actionMenu
            visible: clipRoot._menuIndex >= 0 && clipRoot._menuIndex < listModel.count
            width: 340
            height: 124
            anchors.centerIn: parent
            color: Theme.bgAlt
            border.color: Theme.border
            border.width: 1
            radius: Theme.radiusMd
            z: 100

            readonly property var entry: {
              const i = clipRoot._menuIndex
              return (i >= 0 && i < listModel.count) ? clipRoot._entries[i] : null
            }

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: 8
              Text {
                Layout.fillWidth: true
                text: actionMenu.entry ? actionMenu.entry.preview : ""
                color: Theme.fg
                opacity: 0.75
                font.family: Theme.monoFont
                font.pixelSize: 11
                textFormat: Text.PlainText
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WrapAnywhere
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                  model: [
                    { label: "Copy", action: "copy" },
                    { label: "Copy & close", action: "copyClose" },
                    { label: "Delete", action: "delete" },
                    { label: "Cancel", action: "cancel" }
                  ]
                  Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 26
                    radius: 4
                    color: hover.containsMouse ? Theme.surfaceHover : Theme.surface
                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      color: modelData.action === "delete" ? Theme.urgent : Theme.fg
                      font.family: Theme.monoFont
                      font.pixelSize: 10
                    }
                    MouseArea {
                      id: hover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        const i = clipRoot._menuIndex
                        const act = modelData.action
                        clipRoot._menuIndex = -1
                        const e = clipRoot._entries[i]
                        if (!e) return
                        if (act === "copy") clipRoot.copyEntry(e)
                        else if (act === "copyClose") { clipRoot.copyEntry(e); clipRoot.close() }
                        else if (act === "delete") clipRoot.deleteId(e.id)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Component.onCompleted: if (clipRoot.visible) searchField.forceActiveFocus()
        Connections {
          target: clipRoot
          function onVisibleChanged() {
            if (clipRoot.visible) searchField.forceActiveFocus()
          }
          function onFieldClearNonceChanged() {
            if (searchField.text !== "") searchField.text = ""
          }
        }
      }
    }
  }

  IpcHandler {
    target: "clipboard"
    function toggle(): string { clipRoot.toggle(); return "ok" }
    function open(): string { clipRoot.open(); return "ok" }
    function close(): string { clipRoot.close(); return "ok" }
  }

  GlobalShortcut {
    name: "clipboardToggle"
    description: "Toggle clipboard manager"
    onPressed: clipRoot.toggle()
  }
}
