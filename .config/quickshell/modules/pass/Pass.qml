pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../common"

Scope {
    id: root

    property int actionIndex: 0
    property var allEntries: []
    property string query: ""
    property int selectedIndex: 0
    property bool visible: false

    property var _actionFieldsMap: null
    property bool _altHeld: false
    property bool _blockHover: false
    property var _cache: ({})
    property string _currentStore: ""
    property bool _decrypting: false
    property int _fieldIndex: 0
    property string _fieldMode: ""
    property var _fieldsList: []
    property var _fieldsMap: ({})
    property bool _pendingFieldPicker: false
    property string _pendingKey: ""
    property string _previewPass: ""
    property bool _revealPass: false
    property int _rootIndex: 0
    property var _roots: []
    property bool _showActions: false
    property bool _showFieldPicker: false
    property var _targetEntry: null

    readonly property var allActions: {
        let base = [
            { key: "type_pass", label: "Type Pass", icon: "", hint: "Alt+P" },
            { key: "type_user", label: "Type User", icon: "", hint: "Alt+U" },
            { key: "type_otp", label: "Type OTP", icon: "", hint: "Alt+O" },
            { key: "autotype", label: "Autotype", icon: "󰌌", hint: "Alt+A" },
            { key: "copy_pass", label: "Copy Pass", icon: "", hint: "Alt+C" },
            { key: "copy_user", label: "Copy User", icon: "", hint: "Alt+R" },
            { key: "copy_otp", label: "Copy OTP", icon: "", hint: "Alt+Y" },
            { key: "edit", label: "Edit", icon: "󰏫", hint: "Alt+E" }
        ]
        const eff = root._showActions && root._actionFieldsMap ? root._actionFieldsMap : root._fieldsMap
        const hasOtp = eff && (eff["OTP"] !== undefined || eff["otp"] !== undefined)
        if (!hasOtp) {
            base = base.filter(a => a.key !== "type_otp" && a.key !== "copy_otp")
        }
        return base
    }

    readonly property var filtered: {
        const q = query.toLowerCase().trim()
        if (q === "") return allEntries
        const toks = q.split(/\s+/).filter(t => t.length > 0)
        let out = []
        for (let i = 0; i < allEntries.length; i++) {
            const e = allEntries[i]
            const hay = (e.label || "").toLowerCase()
            let ok = true
            for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) { ok = false; break }
            if (ok) out.push(e)
        }
        return out
    }

    readonly property var filteredActions: {
        const q = query.toLowerCase().trim()
        if (q === "") return allActions
        const toks = q.split(/\s+/).filter(t => t.length > 0)
        return allActions.filter(a => {
            const hay = (a.key + " " + a.label).toLowerCase()
            for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) return false
            return true
        })
    }

    readonly property var filteredFields: {
        const q = query.toLowerCase().trim()
        if (q === "") return _fieldsList
        const toks = q.split(/\s+/).filter(t => t.length > 0)
        let out = []
        for (let i = 0; i < _fieldsList.length; i++) {
            const f = _fieldsList[i]
            const hay = (f.key + " " + f.value).toLowerCase()
            let ok = true
            for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) { ok = false; break }
            if (ok) out.push(f)
        }
        return out
    }

    readonly property string storeName: {
        if (_currentStore === "") return ""
        const parts = _currentStore.split("/")
        return parts[parts.length - 1] || _currentStore
    }

    onQueryChanged: {
        selectedIndex = 0
        actionIndex = 0
        _fieldIndex = 0
    }
    onVisibleChanged: {
        _altHeld = false
        if (visible) {
            selectedIndex = 0
            actionIndex = 0
            _fieldIndex = 0
            _showActions = false
            _showFieldPicker = false
            _pendingFieldPicker = false
            _revealPass = false
            _blockHover = true
            _actionFieldsMap = null
            if (_roots.length > 0) refresh()
            else schedulePreview()
        } else {
            _previewTimer.stop()
            _decryptFallback.stop()
            _decrypting = false
            _pendingKey = ""
            _pendingFieldPicker = false
        }
    }
    onSelectedIndexChanged: schedulePreview()
    onFilteredChanged: schedulePreview()

    function cacheKey(store, label) { return String(store) + "|" + String(label) }
    function close() {
        visible = false
        _altHeld = false
        _showActions = false
        _showFieldPicker = false
        _pendingFieldPicker = false
        _fieldMode = ""
        _revealPass = false
        _previewTimer.stop()
        _decryptFallback.stop()
        _decrypting = false
        _pendingKey = ""
    }
    function copyDetailAt(idx) {
        const lst = filteredFields
        if (idx < 0 || idx >= lst.length) return
        const f = lst[idx]
        if (f.key === "pass") copyPass(_targetEntry)
        else copyValue(f.value, f.key)
    }
    function copyOtp(entry) {
        if (!entry) return
        const store = entry.store || _currentStore
        Quickshell.execDetached(["sh", "-c", "PASSWORD_STORE_DIR=" + shellEscape(store) + " pass otp -c " + shellEscape(entry.label) + " 2>&1 | tr -d \"'\" | xargs -I{} notify-send -t 2500 'Pass' '{}' 2>/dev/null; PASSWORD_STORE_DIR=" + shellEscape(store) + " pass otp -c " + shellEscape(entry.label) + " >/dev/null 2>&1 && notify-send -t 2500 'Pass' 'Copied OTP' || notify-send -u critical 'Pass' 'OTP not configured'"])
        close()
    }
    function copyPass(entry) {
        if (!entry) return
        const store = entry.store || _currentStore
        Quickshell.execDetached(["sh", "-c", "PASSWORD_STORE_DIR=" + shellEscape(store) + " pass -c " + shellEscape(entry.label) + " 2>&1 | tr -d \"'\" | xargs -I{} notify-send -t 2500 'Pass' '{}' 2>/dev/null; PASSWORD_STORE_DIR=" + shellEscape(store) + " pass -c " + shellEscape(entry.label) + " >/dev/null 2>&1 && notify-send -t 2000 'Pass' " + shellEscape("Copied pass • clearing in ${PASSWORD_STORE_CLIP_TIME:-45}s") + " || notify-send -u critical 'Pass' 'Failed to copy pass'"])
        close()
    }
    function copyValue(val, label) {
        if (val === undefined || val === null) { notifyErr("Empty field"); return }
        const v = String(val)
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + shellEscape(v) + " | wl-copy && notify-send -t 2500 'Pass' " + shellEscape("Copied " + label) + " || notify-send -u critical 'Pass' " + shellEscape("Failed to copy " + label)])
        close()
    }
    function doAutotype(entry) {
        if (!entry) return
        const store = entry.store || _currentStore
        const lab = shellEscape(entry.label)
        const escStore = shellEscape(store)
        Quickshell.execDetached(["sh", "-c", "PASSWORD_STORE_DIR=" + escStore + " out=$(pass show " + lab + " 2>/dev/null); ec=$?; [ $ec -ne 0 ] && { notify-send -u critical 'Pass' 'Failed to show entry'; exit 1; }; passVal=$(printf '%s' \"$out\" | head -n1); getF() { printf '%s' \"$out\" | awk -F': ' -v k=\"$1\" 'BEGIN{found=0} $1==k{ sub($1\": \",\"\"); print; found=1; exit} END{if(!found) exit 1}'; }; autotype=$(getF autotype 2>/dev/null); [ -z \"$autotype\" ] && autotype='user :tab pass'; sleep 0.2; for word in $autotype; do case \"$word\" in :tab) wtype -P Tab -s 50 -p Tab 2>/dev/null || wtype -k Tab 2>/dev/null ;; :space) wtype -P space -s 50 -p space 2>/dev/null || wtype -k space 2>/dev/null ;; :delay|:sleep) sleep 2 ;; :enter) wtype -P Return -s 50 -p Return 2>/dev/null || wtype -k Return 2>/dev/null ;; :otp|otp) PASSWORD_STORE_DIR=" + escStore + " pass otp " + lab + " 2>/dev/null | tr -d '\\n' | wtype -d 12 - 2>/dev/null ;; pass) printf '%s' \"$passVal\" | wtype -d 12 - 2>/dev/null ;; path) printf '%s' " + lab + " | rev | cut -d'/' -f1 | rev | wtype -d 12 - 2>/dev/null ;; *) v=$(getF \"$word\" 2>/dev/null); printf '%s' \"$v\" | wtype -d 12 - 2>/dev/null ;; esac; sleep 0.06; done || notify-send -u critical 'Pass' 'Autotype failed (wtype missing?)'"])
        close()
    }
    function doPreview() {
        if (_showActions || _showFieldPicker) {
            if (!_pendingFieldPicker) { _decrypting = false; _pendingKey = ""; }
            _decryptFallback.stop()
            return
        }
        const lst = filtered
        if (lst.length === 0 || selectedIndex < 0 || selectedIndex >= lst.length) { _decrypting = false; _pendingKey = ""; _decryptFallback.stop(); return }
        const e = lst[selectedIndex]
        const key = cacheKey(e.store || _currentStore, e.label)
        if (_cache[key]) {
            const hit = _cache[key]
            _fieldsMap = hit.map
            _fieldsList = hit.list
            _previewPass = hit.pass
            _decrypting = false
            _pendingKey = ""
            _previewTimer.stop()
            _decryptFallback.stop()
            return
        }
        // Action-only: do not auto-decrypt; wait for explicit action
        _decrypting = false
        _pendingKey = ""
        _decryptFallback.stop()
        _previewTimer.stop()
        _fieldsMap = {}
        _fieldsList = []
        _previewPass = ""
    }
    function executeAction(entry, key) {
        if (!entry || !key) return
        if (key === "type_pass") typePass(entry)
        else if (key === "type_user") typeUser(entry)
        else if (key === "type_otp") typeOtp(entry)
        else if (key === "autotype") doAutotype(entry)
        else if (key === "copy_pass") copyPass(entry)
        else if (key === "copy_user") {
            const eff = _actionFieldsMap || _fieldsMap
            let u = eff ? (eff["user"] || eff["username"]) : null
            if (u) { copyValue(u, "user"); return }
            const store = entry.store || _currentStore
            Quickshell.execDetached(["sh", "-c", "PASSWORD_STORE_DIR=" + shellEscape(store) + " out=$(pass show " + shellEscape(entry.label) + " 2>/dev/null); u=$(printf '%s' \"$out\" | awk -F': ' '$1==\"user\"{print substr($0,index($0,\": \")+2); exit}'); [ -z \"$u\" ] && u=$(printf '%s' \"$out\" | awk -F': ' '$1==\"username\"{print substr($0,index($0,\": \")+2); exit}'); [ -z \"$u\" ] && { notify-send -u critical 'Pass' 'No user field'; exit 1; }; printf '%s' \"$u\" | wl-copy && notify-send -t 2500 'Pass' 'Copied user' || notify-send -u critical 'Pass' 'Failed to copy user'"])
            close()
        } else if (key === "copy_otp") copyOtp(entry)
        else if (key === "edit") {
            const store = entry.store || _currentStore
            Quickshell.execDetached(["sh", "-c", "PASSWORD_STORE_DIR=" + shellEscape(store) + " kitty -e pass edit " + shellEscape(entry.label) + " &"])
            notify("Editing " + entry.label)
            close()
        }
    }
    function goEnd() {
        _markKeyboard()
        if (_showFieldPicker) { const n = filteredFields.length; if (n > 0) _fieldIndex = n - 1; return }
        if (_showActions) { const n = filteredActions.length; if (n > 0) actionIndex = n - 1; return }
        const n = filtered.length; if (n > 0) selectedIndex = n - 1
    }
    function goHome() {
        _markKeyboard()
        if (_showFieldPicker) { if (filteredFields.length > 0) _fieldIndex = 0; return }
        if (_showActions) { if (filteredActions.length > 0) actionIndex = 0; return }
        if (filtered.length > 0) selectedIndex = 0
    }
    function move(delta) {
        _markKeyboard()
        if (_showFieldPicker) {
            const n = filteredFields.length; if (n === 0) return
            let ni = _fieldIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; _fieldIndex = ni; return
        }
        if (_showActions) {
            const n = filteredActions.length; if (n === 0) return
            let ni = actionIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; actionIndex = ni; return
        }
        const n = filtered.length; if (n === 0) return
        let ni = selectedIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; selectedIndex = ni
    }
    function moveNoWrap(delta) {
        _markKeyboard()
        if (_showFieldPicker) {
            const n = filteredFields.length; if (n === 0) return
            const ni = _fieldIndex + delta; if (ni < 0 || ni >= n) return; _fieldIndex = ni; return
        }
        if (_showActions) {
            const n = filteredActions.length; if (n === 0) return
            const ni = actionIndex + delta; if (ni < 0 || ni >= n) return; actionIndex = ni; return
        }
        const n = filtered.length; if (n === 0) return
        const ni = selectedIndex + delta; if (ni < 0 || ni >= n) return; selectedIndex = ni
    }
    function nextStore() {
        if (_roots.length <= 1) return
        _rootIndex = (_rootIndex + 1) % _roots.length
        _currentStore = _roots[_rootIndex]
        refresh()
        notify("Store: " + storeName)
    }
    function notify(msg) { Quickshell.execDetached(["sh", "-c", "notify-send -t 2500 'Pass' " + shellEscape(msg)]) }
    function notifyErr(msg) { Quickshell.execDetached(["sh", "-c", "notify-send -t 3500 -u critical 'Pass' " + shellEscape(msg)]) }
    function open() {
        visible = true
        query = ""
        selectedIndex = 0
        actionIndex = 0
        _fieldIndex = 0
        _showActions = false
        _showFieldPicker = false
        _fieldMode = ""
        _revealPass = false
        _altHeld = false
        _blockHover = true
        if (_roots.length === 0) envProc.running = true
        else refresh()
    }
    function openFieldPicker(mode) {
        if (!_targetEntry) return
        let srcMap = _actionFieldsMap || _fieldsMap
        const ckTarget = cacheKey(_targetEntry.store || _currentStore, _targetEntry.label)
        const cached = _cache[ckTarget]
        if ((!srcMap || Object.keys(srcMap).length === 0) && cached) {
            srcMap = cached.map
            _fieldsMap = cached.map
            _fieldsList = cached.list
            _previewPass = cached.pass
        }
        if (!srcMap || Object.keys(srcMap).length === 0) {
            if (_fieldsList && _fieldsList.length > 0) {
                srcMap = _fieldsMap
                if (!srcMap || Object.keys(srcMap).length === 0) {
                    let m = {}
                    for (let i = 0; i < _fieldsList.length; i++) m[_fieldsList[i].key] = _fieldsList[i].value
                    srcMap = m
                }
            }
        }
        if (!srcMap || Object.keys(srcMap).length === 0) {
            _fieldMode = mode
            _pendingFieldPicker = true
            _pendingKey = ckTarget
            _decrypting = true
            _decryptFallback.restart()
            showProc.command = ["sh", "-c", "PASSWORD_STORE_DIR=" + shellEscape(_targetEntry.store || _currentStore) + " pass show " + shellEscape(_targetEntry.label) + " 2>&1"]
            showProc.running = true
            notify("Decrypting " + _targetEntry.label + "…")
            return
        }
        let tmpList = []
        const keys = srcMap ? Object.keys(srcMap) : []
        for (let k = 0; k < keys.length; k++) {
            const kk = keys[k]
            if (kk === "autotype") continue
            const v = srcMap[kk]
            const masked = kk === "pass"
            tmpList.push({ key: kk, value: v, masked: masked })
        }
        tmpList.sort((a, b) => a.key.localeCompare(b.key))
        if (tmpList.length === 0) { notifyErr("No fields to pick"); return }
        _fieldsList = tmpList
        _fieldMode = mode
        _pendingFieldPicker = false
        _showFieldPicker = true
        _fieldIndex = 0
        query = ""
    }
    function pageMove(dir) {
        _markKeyboard()
        let page = 8
        if (_showFieldPicker) {
            const n = filteredFields.length; if (n === 0) return
            let ni = _fieldIndex + dir * page; if (ni < 0) ni = 0; if (ni >= n) ni = n - 1; _fieldIndex = ni; return
        }
        if (_showActions) {
            const n = filteredActions.length; if (n === 0) return
            let ni = actionIndex + dir * page; if (ni < 0) ni = 0; if (ni >= n) ni = n - 1; actionIndex = ni; return
        }
        const n = filtered.length; if (n === 0) return
        try { const h = listView ? listView.height : 0; if (h > 0) page = Math.max(1, Math.floor(h / 42)) } catch (e) {}
        let ni = selectedIndex + dir * page; if (ni < 0) ni = 0; if (ni >= n) ni = n - 1; selectedIndex = ni
        try { if (typeof listView !== "undefined" && listView) listView.positionViewAtIndex(ni, ListView.Contain) } catch (e) {}
    }
    function parseShowOutput(text) {
        const raw = String(text || "")
        const rawLower = raw.toLowerCase()
        const isStoreErr = raw.includes("is not in the password store")
        const isGpgFail = rawLower.includes("gpg: decryption failed") || rawLower.includes("decryption failed") || rawLower.includes("failed to decrypt")
        let filteredRaw = raw.split("\n").filter(l => !l.startsWith("gpg:") && !l.startsWith("pinentry") && !l.includes("gpg:"))
        let rawJoined = filteredRaw.join("\n")
        const key = _pendingKey
        const hasFailed = isStoreErr || isGpgFail || rawJoined.toLowerCase().includes("failed")
        if (hasFailed || rawJoined.trim() === "" || rawJoined.includes("is not in the password store")) {
            _decrypting = false
            _decryptFallback.stop()
            if (hasFailed) {
                let snippet = filteredRaw.join(" | ").trim().substring(0, 80)
                if (snippet === "") snippet = raw.trim().split("\n").filter(l => l.trim() !== "").join(" | ").substring(0, 80)
                if (snippet.trim() === "") snippet = "(empty)"
                snippet = snippet.replace(/\n/g, " | ")
                notifyErr("Decrypt failed: " + snippet)
                _pendingKey = ""
                _pendingFieldPicker = false
                return
            }
            if (rawJoined.trim() === "") {
                let snippet = raw.trim().substring(0, 80).replace(/\n/g, " | ")
                if (raw.trim().length > 0 && !rawLower.includes("gpg:")) notifyErr("Empty output: " + snippet)
                if (key) {
                    const lst = filtered
                    if (lst.length > 0 && selectedIndex >= 0 && selectedIndex < lst.length) {
                        const e = lst[selectedIndex]
                        const ck2 = cacheKey(e.store || _currentStore, e.label)
                        if (ck2 === key && !_pendingFieldPicker) {
                            _fieldsMap = {}
                            _fieldsList = []
                            _previewPass = ""
                        }
                    }
                }
                if (_pendingFieldPicker) {
                    const tk = _targetEntry ? cacheKey(_targetEntry.store || _currentStore, _targetEntry.label) : ""
                    if (tk !== "" && tk === key) _pendingFieldPicker = false
                }
                _pendingKey = ""
                if (_pendingFieldPicker) _pendingFieldPicker = false
                return
            }
            let snippet2 = rawJoined.trim().substring(0, 80).replace(/\n/g, " | ")
            notifyErr(snippet2 || "Failed to show entry")
            _pendingKey = ""
            _pendingFieldPicker = false
            return
        }
        const lines = filteredRaw.filter(l => l.length > 0 || filteredRaw.length === 1)
        let firstIdx = 0
        while (firstIdx < lines.length && lines[firstIdx].trim() === "") firstIdx++
        const first = firstIdx < lines.length ? lines[firstIdx] : ""
        if (first === "" && lines.length === 0) {
            _decrypting = false
            _pendingKey = ""
            _decryptFallback.stop()
            let snippet = raw.trim().substring(0, 80).replace(/\n/g, " | ")
            if (snippet.trim() !== "") notifyErr("Empty decrypt: " + snippet)
            if (_pendingFieldPicker) _pendingFieldPicker = false
            return
        }
        let map = { pass: first }
        let list = [{ key: "pass", value: first, masked: true }]
        for (let i = firstIdx + 1; i < lines.length; i++) {
            const line = lines[i]
            if (line.trim() === "") continue
            if (line.startsWith("otpauth://")) {
                map["OTP"] = "configured"
                list.push({ key: "OTP", value: "otpauth://…", masked: false })
                continue
            }
            const colon = line.indexOf(":")
            if (colon > 0) {
                const k = line.substring(0, colon).trim()
                const v = line.substring(colon + 1).trimStart()
                if (k.length > 0) {
                    map[k] = v
                    list.push({ key: k, value: v, masked: false })
                }
            }
        }
        let ck = key
        if (!ck) {
            const lst = filtered
            if (lst.length > 0 && selectedIndex >= 0 && selectedIndex < lst.length) {
                const e = lst[selectedIndex]
                ck = cacheKey(e.store || _currentStore, e.label)
            }
        }
        if (ck) {
            let c = _cache
            c[ck] = { pass: first, map: map, list: list }
            _cache = c
        }
        if (_pendingKey !== "" && _pendingKey !== ck) {
            _decrypting = false
            _decryptFallback.stop()
            const lst2 = filtered
            let curKey = ""
            if (lst2.length > 0 && selectedIndex >= 0 && selectedIndex < lst2.length) {
                const e2 = lst2[selectedIndex]
                curKey = cacheKey(e2.store || _currentStore, e2.label)
            }
            const targetKey = _targetEntry ? cacheKey(_targetEntry.store || _currentStore, _targetEntry.label) : ""
            let matched = false
            if (curKey !== "" && curKey === ck) {
                _fieldsMap = map
                _fieldsList = list
                _previewPass = first
                matched = true
            }
            if (targetKey !== "" && targetKey === ck) {
                _actionFieldsMap = map
                if (!matched) {
                    _fieldsMap = map
                    _fieldsList = list
                    _previewPass = first
                }
                matched = true
            }
            if (_pendingFieldPicker && targetKey === ck) {
                let tmpList = []
                const pKeys = Object.keys(map)
                for (let k = 0; k < pKeys.length; k++) {
                    const kk = pKeys[k]
                    if (kk === "autotype") continue
                    tmpList.push({ key: kk, value: map[kk], masked: kk === "pass" })
                }
                tmpList.sort((a, b) => a.key.localeCompare(b.key))
                if (tmpList.length > 0) {
                    _fieldsList = tmpList
                    _showFieldPicker = true
                    _fieldIndex = 0
                    query = ""
                }
                _pendingFieldPicker = false
                _pendingKey = ""
                return
            }
            if (!matched) {
                if (curKey !== "" && _cache[curKey]) {
                    const hit2 = _cache[curKey]
                    _fieldsMap = hit2.map
                    _fieldsList = hit2.list
                    _previewPass = hit2.pass
                } else if (curKey !== "" && curKey !== ck) {
                    _pendingKey = curKey
                    _pendingFieldPicker = false
                    _decrypting = true
                    _decryptFallback.restart()
                    schedulePreview()
                    return
                } else {
                    _fieldsMap = map
                    _previewPass = first
                    _fieldsList = list
                }
            }
            _pendingKey = ""
            _pendingFieldPicker = false
            return
        }
        _fieldsMap = map
        _previewPass = first
        _decrypting = false
        _pendingKey = ""
        _decryptFallback.stop()
        _fieldsList = list
        if (_showActions && _targetEntry) {
            const tk = cacheKey(_targetEntry.store || _currentStore, _targetEntry.label)
            if (tk === ck) _actionFieldsMap = map
        }
        if (_pendingFieldPicker) {
            const tk2 = _targetEntry ? cacheKey(_targetEntry.store || _currentStore, _targetEntry.label) : ck
            if (tk2 === ck) {
                let tmpList = []
                const pKeys2 = Object.keys(map)
                for (let k = 0; k < pKeys2.length; k++) {
                    const kk = pKeys2[k]
                    if (kk === "autotype") continue
                    tmpList.push({ key: kk, value: map[kk], masked: kk === "pass" })
                }
                tmpList.sort((a, b) => a.key.localeCompare(b.key))
                if (tmpList.length > 0) {
                    _fieldsList = tmpList
                    _showFieldPicker = true
                    _fieldIndex = 0
                    query = ""
                } else {
                    notifyErr("No fields to pick")
                }
            }
            _pendingFieldPicker = false
        }
    }
    function refresh() {
        _previewTimer.stop()
        _decryptFallback.stop()
        _decrypting = false
        _pendingKey = ""
        _pendingFieldPicker = false
        if (_roots.length === 0) {
            envProc.running = true
            return
        }
        if (_currentStore === "" && _roots.length > 0) _currentStore = _roots[_rootIndex]
        allEntries = []
        _revealPass = false
        if (_currentStore === "") return
        const store = _currentStore
        fetchProc.command = ["sh", "-c", "set -e; s=" + shellEscape(store) + "; [ -d \"$s\" ] || { echo '[]'; exit 0; }; cd \"$s\" 2>/dev/null || { echo '[]'; exit 0; }; find -L . -name '*.gpg' -print0 2>/dev/null | tr '\\0' '\\n' | sed 's#^\\./##; s#\\.gpg$##' | grep -v '^$' | sort | python3 -c \"import sys,json; print(json.dumps([{'label':l.strip(),'path':l.strip(),'store':sys.argv[1]} for l in sys.stdin if l.strip()]))\" " + shellEscape(store)]
        fetchProc.running = true
    }
    function schedulePreview() {
        if (_showActions || _showFieldPicker) {
            if (!_pendingFieldPicker) { _decrypting = false; _pendingKey = ""; }
            _previewTimer.stop()
            _decryptFallback.stop()
            return
        }
        const lst = filtered
        if (lst.length === 0 || selectedIndex < 0 || selectedIndex >= lst.length) {
            _previewTimer.stop()
            _decryptFallback.stop()
            _decrypting = false
            _pendingKey = ""
            return
        }
        const e = lst[selectedIndex]
        const key = cacheKey(e.store || _currentStore, e.label)
        const hit = _cache[key]
        if (hit) {
            _previewTimer.stop()
            _decryptFallback.stop()
            _decrypting = false
            _pendingKey = ""
            _fieldsMap = hit.map
            _fieldsList = hit.list
            _previewPass = hit.pass
            return
        }
        // Action-only: do not auto-decrypt preview; only use cache
        _previewTimer.stop()
        _decryptFallback.stop()
        _decrypting = false
        _pendingKey = ""
        _fieldsMap = {}
        _fieldsList = []
        _previewPass = ""
    }
    function shellEscape(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function switchStore(dir) {
        const idx = _roots.indexOf(dir)
        if (idx >= 0) _rootIndex = idx
        _currentStore = dir
        refresh()
    }
    function toggle() { visible ? close() : open() }
    function typeDetailAt(idx) {
        const lst = filteredFields
        if (idx < 0 || idx >= lst.length) return
        const f = lst[idx]
        if (f.key === "pass") typePass(_targetEntry)
        else typeValue(f.value)
    }
    function typeOtp(entry) {
        if (!entry) return
        const store = entry.store || _currentStore
        Quickshell.execDetached(["sh", "-c", "PASSWORD_STORE_DIR=" + shellEscape(store) + " otp=$(pass otp " + shellEscape(entry.label) + " 2>/dev/null | tr -d '\\n'); [ -n \"$otp\" ] || { notify-send -u critical 'Pass' 'OTP not configured'; exit 1; }; sleep 0.2; printf '%s' \"$otp\" | wtype -d 12 - 2>/dev/null || notify-send -u critical 'Pass' 'wtype not found'"])
        close()
    }
    function typePass(entry) {
        if (!entry) return
        const store = entry.store || _currentStore
        Quickshell.execDetached(["sh", "-c", "PASSWORD_STORE_DIR=" + shellEscape(store) + " p=$(pass show " + shellEscape(entry.label) + " 2>/dev/null | head -n1); [ -n \"$p\" ] || { notify-send -u critical 'Pass' 'No password'; exit 1; }; sleep 0.2; printf '%s' \"$p\" | wtype -d 12 - 2>/dev/null || notify-send -u critical 'Pass' 'wtype not found'"])
        close()
    }
    function typeUser(entry) {
        if (!entry) return
        const eff = _actionFieldsMap || _fieldsMap
        let u = eff ? (eff["user"] || eff["username"]) : null
        if (u) { typeValue(u); return }
        const store = entry.store || _currentStore
        Quickshell.execDetached(["sh", "-c", "PASSWORD_STORE_DIR=" + shellEscape(store) + " out=$(pass show " + shellEscape(entry.label) + " 2>/dev/null); u=$(printf '%s' \"$out\" | awk -F': ' '$1==\"user\"{print substr($0,index($0,\": \")+2); exit}'); [ -z \"$u\" ] && u=$(printf '%s' \"$out\" | awk -F': ' '$1==\"username\"{print substr($0,index($0,\": \")+2); exit}'); [ -z \"$u\" ] && { notify-send -u critical 'Pass' 'No user field'; exit 1; }; sleep 0.2; printf '%s' \"$u\" | wtype -d 12 - 2>/dev/null || notify-send -u critical 'Pass' 'wtype not found'"])
        close()
    }
    function typeValue(val) {
        if (val === undefined || val === null) { notifyErr("Empty field"); return }
        const v = String(val)
        Quickshell.execDetached(["sh", "-c", "sleep 0.2; printf '%s' " + shellEscape(v) + " | wtype -d 12 - 2>/dev/null || notify-send -u critical 'Pass' 'wtype not found'"])
        close()
    }
    function _markKeyboard() { _blockHover = true }

    function activateAt(idx) {
        const list = filtered
        if (idx < 0 || idx >= list.length) return
        const entry = list[idx]
        _targetEntry = entry
        if (_showFieldPicker) return
        const tk = cacheKey(entry.store || _currentStore, entry.label)
        const hit = _cache[tk]
        if (hit) {
            _actionFieldsMap = hit.map
            if (_fieldsMap !== hit.map || _pendingKey !== tk) {
                _fieldsMap = hit.map
                _fieldsList = hit.list
                _previewPass = hit.pass
            }
            _decrypting = false
            _pendingKey = ""
            _decryptFallback.stop()
            _previewTimer.stop()
        } else {
            // Action-only: do not decrypt until an explicit action is chosen
            _actionFieldsMap = null
            _decrypting = false
            _pendingKey = ""
            _decryptFallback.stop()
            _previewTimer.stop()
        }
        _revealPass = false
        _showActions = true
        actionIndex = 0
        query = ""
    }

    function activateFieldAt(idx) {
        const lst = filteredFields
        if (idx < 0 || idx >= lst.length) return
        const f = lst[idx]
        if (_fieldMode === "copy") {
            if (f.key === "pass") copyPass(_targetEntry)
            else copyValue(f.value, f.key)
            return
        }
        if (_fieldMode === "type") {
            if (f.key === "pass") typePass(_targetEntry)
            else typeValue(f.value)
            return
        }
    }

    Timer {
        id: _previewTimer
        interval: 110
        repeat: false
        onTriggered: root.doPreview()
    }

    Timer {
        id: _decryptFallback
        interval: 500
        repeat: false
        onTriggered: {
            if (root._decrypting) {
                root._decrypting = false
                if (root._pendingFieldPicker && showProc.running) return
                const lst = root.filtered
                if (lst.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < lst.length) {
                    const e = lst[root.selectedIndex]
                    const k = root.cacheKey(e.store || root._currentStore, e.label)
                    const hit = root._cache[k]
                    if (hit) {
                        root._fieldsMap = hit.map
                        root._fieldsList = hit.list
                        root._previewPass = hit.pass
                        root._pendingKey = ""
                        root._pendingFieldPicker = false
                    } else if (root._pendingKey !== "" && !root._showActions && !root._showFieldPicker && !showProc.running) {
                        root.schedulePreview()
                    } else if (!showProc.running && !root._pendingFieldPicker) {
                        root._pendingKey = ""
                    }
                } else {
                    if (!root._pendingFieldPicker) root._pendingKey = ""
                }
            }
        }
    }

    Process {
        id: envProc
        running: false
        command: ["sh", "-c", "printf '%s|%s|%s' \"$ROOTS\" \"$PASSWORD_STORE_DIR\" \"$HOME\""]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const parts = String(text || "").split("|")
                const rootsRaw = (parts[0] || "").trim()
                const psd = (parts[1] || "").trim()
                const home = (parts[2] || "").trim() || "/tmp"
                let roots = []
                if (rootsRaw !== "") roots = rootsRaw.split(":").map(s => s.trim()).filter(s => s.length > 0)
                else if (psd !== "") roots = [psd]
                else roots = [home + "/.password-store"]
                root._roots = roots
                if (roots.length > 0) {
                    root._currentStore = roots[0]
                    root._rootIndex = 0
                }
                root.refresh()
            }
        }
        onExited: if (exitCode !== 0) { root._roots = ["/tmp"]; root._currentStore = "/tmp" }
    }

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const arr = JSON.parse(String(text || "[]"))
                    let out = []
                    for (let i = 0; i < arr.length; i++) {
                        const e = arr[i]
                        if (!e.label) continue
                        const segs = e.label.split("/")
                        const name = segs[segs.length - 1]
                        out.push({ label: e.label, path: e.path || e.label, store: e.store || root._currentStore, name: name, dir: segs.slice(0, -1).join("/") })
                    }
                    root.allEntries = out
                    if (root.selectedIndex >= root.filtered.length) root.selectedIndex = 0
                    root.schedulePreview()
                } catch (e) { root.allEntries = []; root.notifyErr("Failed to list store") }
            }
        }
        onExited: if (exitCode !== 0) root.notifyErr("Store not found: " + root._currentStore)
    }

    Process {
        id: showProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseShowOutput(text)
        }
        onExited: {
            root._decrypting = false
            root._decryptFallback.stop()
            if (exitCode !== 0) {
                const wasPicker = root._pendingFieldPicker
                root._pendingFieldPicker = false
                root._pendingKey = ""
                root.notifyErr("Failed to show entry (code " + exitCode + ")")
                if (wasPicker) root._pendingKey = ""
            } else if (root._pendingKey !== "" && !root._pendingFieldPicker) {
                const lst = root.filtered
                let curKey = ""
                if (lst.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < lst.length) {
                    const e = lst[root.selectedIndex]
                    curKey = root.cacheKey(e.store || root._currentStore, e.label)
                }
                if (curKey !== "" && curKey !== root._pendingKey) {
                    root._pendingKey = ""
                } else if (curKey === "" || !root._cache[curKey]) {
                    root._pendingKey = ""
                }
            }
        }
    }

    Process {
        id: actionProc
        running: false
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: {} }
        onExited: if (exitCode !== 0) root.notifyErr("Action failed")
    }

    IpcHandler {
        target: "pass"
        function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
        function open(): string { root.open(); return "ok" }
        function close(): string { root.close(); return "ok" }
    }

    GlobalShortcut { name: "passToggle"; description: "Toggle password store"; onPressed: root.toggle() }

    LazyLoader {
        active: root.visible

        Variants {
            model: Quickshell.screens

            PanelWindow {
                required property var modelData
                screen: modelData
                visible: root.visible
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "quickshell-pass"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                anchors { top: true; bottom: true; left: true; right: true }

                MouseArea { anchors.fill: parent; onClicked: root.close() }
                Rectangle { anchors.fill: parent; color: Theme.dim }

                Rectangle {
                    id: container
                    width: 640
                    height: 480
                    anchors.centerIn: parent
                    radius: Theme.radiusLg
                    color: Theme.bg
                    border.color: Theme.border
                    border.width: 1
                    clip: true
                    focus: true
                    LayoutMirroring.enabled: false

                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.AltModifier) root._altHeld = true
                        const shift = Boolean(event.modifiers & Qt.ShiftModifier)
                        const alt = Boolean(event.modifiers & Qt.AltModifier)
                        if (alt && !shift && event.key === Qt.Key_C) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "copy_pass"); event.accepted = true; return }
                        if (alt && !shift && event.key === Qt.Key_R) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "copy_user"); event.accepted = true; return }
                        if (alt && !shift && event.key === Qt.Key_Y) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "copy_otp"); event.accepted = true; return }
                        if (alt && !shift && event.key === Qt.Key_P) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "type_pass"); event.accepted = true; return }
                        if (alt && !shift && event.key === Qt.Key_U) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "type_user"); event.accepted = true; return }
                        if (alt && !shift && event.key === Qt.Key_O) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "type_otp"); event.accepted = true; return }
                        if (alt && !shift && event.key === Qt.Key_A) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "autotype"); event.accepted = true; return }
                        if (alt && !shift && event.key === Qt.Key_E) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "edit"); event.accepted = true; return }
                        if (alt && event.key === Qt.Key_BracketLeft) { root.nextStore(); event.accepted = true; return }
                        if (event.key === Qt.Key_Escape) {
                            if (root._showFieldPicker) {
                                root._showFieldPicker = false; root._fieldMode = ""; root.query = ""
                                const ck = root._targetEntry ? root.cacheKey(root._targetEntry.store || root._currentStore, root._targetEntry.label) : ""
                                const hit = ck ? root._cache[ck] : null
                                if (hit) { root._fieldsMap = hit.map; root._fieldsList = hit.list; root._previewPass = hit.pass } else { root.schedulePreview() }
                                event.accepted = true
                            } else if (root._showActions) {
                                root._showActions = false; root.query = ""; root._revealPass = false; root._actionFieldsMap = null
                                root.schedulePreview()
                                event.accepted = true
                            } else root.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_R && !searchField.activeFocus && !(event.modifiers & Qt.AltModifier) && !(event.modifiers & Qt.ControlModifier)) { root.refresh(); event.accepted = true }
                        if (event.key === Qt.Key_Alt) root._altHeld = true
                    }
                    Keys.onReleased: event => {
                        if (event.key === Qt.Key_Alt) root._altHeld = false
                        else root._altHeld = Boolean(event.modifiers & Qt.AltModifier)
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: if (root._blockHover) root._blockHover = false; onClicked: {} }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 8
                                color: Theme.surface; border.color: Theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: root._showFieldPicker ? "󰍉" : root._showActions ? "󰒓" : "󰌋"; color: Theme.fg; font.family: Theme.nerdFont; font.pixelSize: 14 }
                            }
                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: {
                                        if (root._showFieldPicker) return (_fieldMode === "copy" ? "Copy field" : "Type field") + " • " + (root._targetEntry ? root._targetEntry.label : "")
                                        if (root._showActions && root._targetEntry) return "Action for " + root._targetEntry.label
                                        return "Password Store"
                                    }
                                    color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; Layout.maximumWidth: 420
                                }
                                Text {
                                    text: {
                                        if (root._showFieldPicker) return root.filteredFields.length + " fields"
                                        if (root._showActions) return root.filteredActions.length + " actions"
                                        return root.filtered.length + " entries • " + root.allEntries.length + " total • " + root.storeName
                                    }
                                    color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 11
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                visible: root._roots.length > 1
                                Layout.preferredHeight: 28; Layout.preferredWidth: storeText.width + 22; radius: 14
                                color: Theme.surface; border.color: Theme.border; border.width: 1
                                Text {
                                    id: storeText
                                    anchors.centerIn: parent
                                    text: root.storeName
                                    color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 11; font.bold: true
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextStore() }
                            }
                            Rectangle {
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                color: Theme.surface; border.color: Theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.6; font.family: Theme.nerdFont; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
                            }
                            Rectangle {
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                color: Theme.surface; border.color: Theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            radius: Theme.radiusMd
                            color: Theme.surface
                            border.color: searchField.activeFocus ? Qt.alpha(Theme.fg, 0.40) : Theme.border
                            border.width: 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8
                                Text { text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 14 }
                                TextInput {
                                    id: searchField
                                    Layout.fillWidth: true
                                    color: Theme.fg
                                    font.family: Theme.monoFont
                                    font.pixelSize: 14
                                    focus: true
                                    activeFocusOnTab: false
                                    onTextChanged: root.query = text
                                    onAccepted: {
                                        if (root._showFieldPicker) {
                                            if (root._fieldIndex >= 0 && root._fieldIndex < root.filteredFields.length) root.activateFieldAt(root._fieldIndex)
                                        } else if (root._showActions) {
                                            const acts = root.filteredActions
                                            if (root.actionIndex >= 0 && root.actionIndex < acts.length && root._targetEntry) root.executeAction(root._targetEntry, acts[root.actionIndex].key)
                                        } else {
                                            root.activateAt(root.selectedIndex)
                                        }
                                    }
                                    Keys.onPressed: event => {
                                        const shift = Boolean(event.modifiers & Qt.ShiftModifier)
                                        const alt = Boolean(event.modifiers & Qt.AltModifier)
                                        if (alt && !shift && event.key === Qt.Key_C) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "copy_pass"); event.accepted = true; return }
                                        if (alt && !shift && event.key === Qt.Key_R) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "copy_user"); event.accepted = true; return }
                                        if (alt && !shift && event.key === Qt.Key_Y) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "copy_otp"); event.accepted = true; return }
                                        if (alt && !shift && event.key === Qt.Key_P) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "type_pass"); event.accepted = true; return }
                                        if (alt && !shift && event.key === Qt.Key_U) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "type_user"); event.accepted = true; return }
                                        if (alt && !shift && event.key === Qt.Key_O) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "type_otp"); event.accepted = true; return }
                                        if (alt && !shift && event.key === Qt.Key_A) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "autotype"); event.accepted = true; return }
                                        if (alt && !shift && event.key === Qt.Key_E) { const e = root._showActions ? root._targetEntry : (root.filtered.length > 0 ? root.filtered[root.selectedIndex] : null); if (e) root.executeAction(e, "edit"); event.accepted = true; return }
                                        if (alt && event.key === Qt.Key_BracketLeft) { root.nextStore(); event.accepted = true; return }
                                        if (event.key === Qt.Key_Escape) {
                                            if (root._showFieldPicker) {
                                                root._showFieldPicker = false; root._fieldMode = ""; text = ""; root.query = ""
                                                const ck = root._targetEntry ? root.cacheKey(root._targetEntry.store || root._currentStore, root._targetEntry.label) : ""
                                                const hit = ck ? root._cache[ck] : null
                                                if (hit) { root._fieldsMap = hit.map; root._fieldsList = hit.list; root._previewPass = hit.pass } else { root.schedulePreview() }
                                                event.accepted = true
                                            } else if (root._showActions) {
                                                root._showActions = false; root._revealPass = false; root._actionFieldsMap = null; text = ""; root.query = ""
                                                root.schedulePreview()
                                                event.accepted = true
                                            } else if (text.length > 0) { text = ""; root.query = ""; event.accepted = true }
                                            else { root.close(); event.accepted = true }
                                        } else if (event.key === Qt.Key_Backtab) { root.move(-1); event.accepted = true }
                                        else if (event.key === Qt.Key_Tab) { if (event.modifiers & Qt.ShiftModifier) root.move(-1); else root.move(1); event.accepted = true }
                                        else if (event.key === Qt.Key_Up) { root.moveNoWrap(-1); event.accepted = true }
                                        else if (event.key === Qt.Key_Down) { root.moveNoWrap(1); event.accepted = true }
                                        else if (event.key === Qt.Key_Left) { root.moveNoWrap(-1); event.accepted = true }
                                        else if (event.key === Qt.Key_Right) { root.moveNoWrap(1); event.accepted = true }
                                        else if (event.key === Qt.Key_Home) { root.goHome(); event.accepted = true }
                                        else if (event.key === Qt.Key_End) { root.goEnd(); event.accepted = true }
                                        else if (event.key === Qt.Key_PageUp) { root.pageMove(-1); event.accepted = true }
                                        else if (event.key === Qt.Key_PageDown) { root.pageMove(1); event.accepted = true }
                                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (root._showFieldPicker) {
                                                if (root._fieldIndex >= 0 && root._fieldIndex < root.filteredFields.length) root.activateFieldAt(root._fieldIndex)
                                            } else if (root._showActions) {
                                                const acts = root.filteredActions
                                                if (root.actionIndex >= 0 && root.actionIndex < acts.length && root._targetEntry) root.executeAction(root._targetEntry, acts[root.actionIndex].key)
                                            } else root.activateAt(root.selectedIndex)
                                            event.accepted = true
                                        }
                                    }
                                    Text {
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        visible: searchField.text === ""
                                        text: root._showFieldPicker ? "Filter field…" : root._showActions ? "Search action…" : "Search entry…"
                                        color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 14
                                    }
                                }
                                Text {
                                    visible: searchField.text !== ""
                                    text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 12
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchField.text = ""; root.query = "" } }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                visible: !root._showActions && !root._showFieldPicker
                                radius: Theme.radiusMd
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                clip: true

                                ListView {
                                    id: listView
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    spacing: 4
                                    model: root.filtered
                                    currentIndex: root.selectedIndex
                                    onCurrentIndexChanged: {
                                        root.selectedIndex = currentIndex
                                        if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                                    }
                                    delegate: Rectangle {
                                        id: del
                                        required property var modelData
                                        required property int index
                                        width: listView.width
                                        height: 42
                                        radius: Theme.radiusSm
                                        color: root.selectedIndex === index ? Theme.surfaceHover : "transparent"
                                        border.color: root.selectedIndex === index ? Qt.alpha(Theme.fg, 0.33) : "transparent"
                                        border.width: 1
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10
                                            Rectangle {
                                                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8
                                                color: root.selectedIndex === del.index ? Theme.bg : Theme.surface
                                                border.color: Theme.border; border.width: 1
                                                Text { anchors.centerIn: parent; text: "󰌋"; color: Theme.accent; font.family: Theme.nerdFont; font.pixelSize: 12 }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: del.modelData.label
                                                    color: Theme.fg
                                                    font.family: Theme.monoFont; font.pixelSize: 12
                                                    elide: Text.ElideMiddle
                                                    Layout.fillWidth: true
                                                    font.bold: root.selectedIndex === del.index
                                                }
                                                Text {
                                                    text: del.modelData.dir || "—"
                                                    color: Theme.fg; opacity: 0.45
                                                    font.family: Theme.monoFont; font.pixelSize: 10
                                                    elide: Text.ElideMiddle
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: { if (root._blockHover) return; root.selectedIndex = del.index }
                                            onClicked: root.activateAt(del.index)
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: root.filtered.length === 0
                                        text: root.allEntries.length === 0 ? "No entries — store empty" : "No matches"
                                        color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 13
                                    }
                                }
                            }

                            ListView {
                                id: actionList
                                anchors.fill: parent
                                visible: root._showActions && !root._showFieldPicker
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                spacing: 4
                                model: root.filteredActions
                                currentIndex: root.actionIndex
                                onCurrentIndexChanged: { root.actionIndex = currentIndex; if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain) }
                                delegate: Rectangle {
                                    id: ad
                                    required property var modelData
                                    required property int index
                                    width: actionList.width
                                    height: 38
                                    radius: Theme.radiusSm
                                    color: root.actionIndex === index ? Theme.surfaceHover : Theme.surface
                                    border.color: root.actionIndex === index ? Qt.alpha(Theme.fg, 0.33) : Theme.border
                                    border.width: 1
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10
                                        Text { text: ad.modelData.icon; color: Theme.fg; opacity: 0.75; font.family: Theme.nerdFont; font.pixelSize: 12 }
                                        Text {
                                            text: {
                                                if (!root._altHeld) return ad.modelData.label
                                                if (ad.modelData.key === "type_pass") return "Type <u>P</u>ass"
                                                if (ad.modelData.key === "type_user") return "Type <u>U</u>ser"
                                                if (ad.modelData.key === "type_otp") return "Type <u>O</u>TP"
                                                if (ad.modelData.key === "autotype") return "<u>A</u>utotype"
                                                if (ad.modelData.key === "copy_pass") return "<u>C</u>opy Pass"
                                                if (ad.modelData.key === "copy_user") return "Copy Use<u>r</u>"
                                                if (ad.modelData.key === "copy_otp") return "Cop<u>y</u> OTP"
                                                if (ad.modelData.key === "edit") return "<u>E</u>dit"
                                                return ad.modelData.label
                                            }
                                            textFormat: root._altHeld ? Text.RichText : Text.PlainText
                                            color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 12; Layout.fillWidth: true; font.bold: root.actionIndex === ad.index
                                        }
                                        Text { text: ad.modelData.hint; color: Theme.fg; opacity: 0.35; font.family: Theme.monoFont; font.pixelSize: 10 }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: { if (root._blockHover) return; root.actionIndex = ad.index }
                                        onClicked: if (root._targetEntry) root.executeAction(root._targetEntry, ad.modelData.key)
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: root.filteredActions.length === 0
                                    text: "No actions"
                                    color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 13
                                }
                            }

                            ListView {
                                id: fieldList
                                anchors.fill: parent
                                visible: root._showFieldPicker
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                spacing: 4
                                model: root.filteredFields
                                currentIndex: root._fieldIndex
                                onCurrentIndexChanged: { root._fieldIndex = currentIndex; if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain) }
                                delegate: Rectangle {
                                    id: fd
                                    required property var modelData
                                    required property int index
                                    width: fieldList.width
                                    height: 38
                                    radius: Theme.radiusSm
                                    color: root._fieldIndex === index ? Theme.surfaceHover : Theme.surface
                                    border.color: root._fieldIndex === index ? Qt.alpha(Theme.fg, 0.33) : Theme.border
                                    border.width: 1
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10
                                        Text { text: "󰅍"; color: Theme.accent; font.family: Theme.nerdFont; font.pixelSize: 11 }
                                        Text { text: fd.modelData.key; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 110; elide: Text.ElideRight }
                                        Text { text: fd.modelData.masked && !root._revealPass ? "••••••••" : fd.modelData.value; color: Theme.fg; opacity: 0.65; font.family: Theme.monoFont; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideMiddle }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: { if (root._blockHover) return; root._fieldIndex = fd.index }
                                        onClicked: root.activateFieldAt(fd.index)
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: root.filteredFields.length === 0
                                    text: "No fields"
                                    color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 13
                                }
                            }

                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            text: {
                                if (root._showFieldPicker) return "↵ pick • Esc back"
                                if (root._showActions) return "↵ run • Esc back"
                                return "↵ actions • Esc close"
                            }
                            color: Theme.fg; opacity: 0.65; font.family: Theme.monoFont; font.pixelSize: 10
                        }
                    }

                    Component.onCompleted: if (root.visible) searchField.forceActiveFocus()
                    Connections {
                        target: root
                        function onVisibleChanged() {
                            if (root.visible) {
                                searchField.text = ""
                                searchField.forceActiveFocus()
                                container.forceActiveFocus()
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }
    }
}
