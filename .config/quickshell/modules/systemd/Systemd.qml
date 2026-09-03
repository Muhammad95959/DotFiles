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

  property bool visible: false
  function toggle() { visible ? close() : open() }
  function open() { visible = true; query = ""; selectedIndex = 0; _altHeld = false; _blockHover = true; _showActions = false; refresh() }
  function close() { visible = false; _altHeld = false; _showActions = false }

  property string query: ""
  property int selectedIndex: 0
  property int actionIndex: 0
  property bool _showActions: false
  property var _targetUnit: null
  property var allEntries: []
  property string sourceFilter: "All"
  property string strategyFilter: "Files"
  property bool _altHeld: false
  property bool _blockHover: false

  readonly property var sourceFilters: [
    { key: "All", label: "All" },
    { key: "User", label: "User" },
    { key: "System", label: "System" }
  ]

  readonly property var strategyFilters: [
    { key: "Files", label: "Files" },
    { key: "Running", label: "Running" },
    { key: "Both", label: "Both" }
  ]

  readonly property var allActions: [
    { key: "enable", label: "enable", icon: "󰄬", hint: "Alt+E" },
    { key: "disable", label: "disable", icon: "󰅖", hint: "Alt+D" },
    { key: "stop", label: "stop", icon: "󰓛", hint: "Alt+K" },
    { key: "restart", label: "restart", icon: "󰑓", hint: "Alt+R" },
    { key: "tail", label: "tail", icon: "󰈙", hint: "Alt+T" },
    { key: "boot_logs", label: "boot_logs", icon: "󰍛", hint: "Alt+L" }
  ]

  readonly property var filtered: {
    const q = query.toLowerCase().trim()
    const sf = sourceFilter
    let list = []
    for (let i = 0; i < allEntries.length; i++) {
      const e = allEntries[i]
      if (sf === "User" && e.scope !== "user") continue
      if (sf === "System" && e.scope !== "system") continue
      if (q !== "") {
        const hay = (e.name + " " + e.state + " " + e.scope).toLowerCase()
        const toks = q.split(/\s+/)
        let ok = true
        for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) { ok = false; break }
        if (!ok) continue
      }
      list.push(e)
    }
    return list
  }

  readonly property var filteredActions: {
    const q = query.toLowerCase().trim()
    if (q === "") return allActions
    const toks = q.split(/\s+/)
    return allActions.filter(a => {
      const hay = (a.key + " " + a.label).toLowerCase()
      for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) return false
      return true
    })
  }

  function statusColor(state) {
    const s = String(state || "").toLowerCase()
    if (s === "enabled" || s === "active" || s === "running" || s === "enabled-runtime") return "#a6e3a1"
    if (s === "failed" || s === "masked" || s === "masked-runtime" || s === "bad") return Theme.urgent
    if (s === "disabled" || s === "inactive" || s === "dead") return Qt.alpha(Theme.fg, 0.45)
    if (s === "static" || s === "alias" || s === "indirect" || s === "generated" || s === "transient") return Qt.alpha(Theme.fg, 0.25)
    return Theme.border
  }

  function _markKeyboard() { _blockHover = true }

  onQueryChanged: {
    selectedIndex = 0
    actionIndex = 0
  }
  onSourceFilterChanged: { selectedIndex = 0; _blockHover = true }
  onStrategyFilterChanged: { selectedIndex = 0; _blockHover = true; refresh() }
  onVisibleChanged: {
    _altHeld = false
    if (visible) {
      selectedIndex = 0
      actionIndex = 0
      _showActions = false
      _blockHover = true
      refresh()
    }
  }

  function refresh() {
    allEntries = []
    const strat = strategyFilter
    realFetch.command = ["sh", "-c", "SYSTEMD_STRATEGY='" + strat.replace(/'/g, "'\\''") + "' python3 << 'PY'\nimport subprocess, json, os\nstrategy=os.environ.get('SYSTEMD_STRATEGY','Files')\nentries=[]\nscopes=['user','system']\nfor scope in scopes:\n    base=['systemctl'] + (['--user'] if scope=='user' else [])\n    if strategy in ('Files','Both'):\n        try:\n            out=subprocess.check_output(base+['list-unit-files','--no-legend','--no-pager'], text=True, stderr=subprocess.DEVNULL, timeout=5)\n            for line in out.splitlines():\n                line=line.strip()\n                if not line: continue\n                parts=line.split()\n                if len(parts)<2: continue\n                name=parts[0].split('/')[-1]\n                state=parts[1]\n                entries.append({'name':name,'state':state,'scope':scope,'active':'','strategy':'files'})\n        except Exception: pass\n    if strategy in ('Running','Both'):\n        try:\n            out=subprocess.check_output(base+['list-units','--all','--no-legend','--no-pager','--plain'], text=True, stderr=subprocess.DEVNULL, timeout=5)\n            for line in out.splitlines():\n                line=line.strip()\n                if not line: continue\n                parts=line.split()\n                if len(parts)<3: continue\n                name=parts[0]\n                active=parts[2] if len(parts)>2 else ''\n                if not any(e['name']==name and e['scope']==scope for e in entries):\n                    entries.append({'name':name,'state':active,'scope':scope,'active':active,'strategy':'running'})\n        except Exception: pass\nuniq={}\nfor e in entries:\n    k=e['name']+'|'+e['scope']\n    if k not in uniq: uniq[k]=e\nsorted_entries=sorted(uniq.values(), key=lambda x: x['name'].lower())\nimport json as _j\nprint(_j.dumps(sorted_entries))\nPY\n"]
    realFetch.running = true
  }

  function executeAction(unit, actionKey) {
    if (!unit || !actionKey) return
    const name = unit.name
    const scope = unit.scope
    const isUser = scope === "user"
    let cmd = ""
    let useTerm = false
    if (actionKey === "tail") {
      cmd = isUser ? "journalctl --user -u '" + name.replace(/'/g, "'\\''") + "' -f" : "journalctl -u '" + name.replace(/'/g, "'\\''") + "' -f"
      useTerm = true
    } else if (actionKey === "boot_logs") {
      cmd = isUser ? "journalctl --user -u '" + name.replace(/'/g, "'\\''") + "' --boot" : "journalctl -u '" + name.replace(/'/g, "'\\''") + "' --boot"
      useTerm = true
    } else {
      const base = isUser ? "systemctl --user " + actionKey + " '" + name.replace(/'/g, "'\\''") + "'" : "pkexec systemctl " + actionKey + " '" + name.replace(/'/g, "'\\''") + "'"
      cmd = base
    }
    if (useTerm) {
      const termCmd = "kitty --hold sh -c \"" + cmd.replace(/"/g, "\\\"") + "; echo \"\\n[Press Enter to close]\"; read\""
      Quickshell.execDetached(["sh", "-c", termCmd + " &"])
    } else {
      const wrapped = "sh -c \"" + cmd.replace(/"/g, "\\\"") + " 2>&1 | head -n 50 | xargs -I{} notify-send -t 3000 'systemd' '{}' 2>/dev/null; " + cmd.replace(/"/g, "\\\"") + "\""
      // simpler: run and notify
      Quickshell.execDetached(["sh", "-c", cmd + " 2>&1 | head -n 20 | tr -d \"'\" | xargs -I{} notify-send -t 2500 'systemd " + actionKey + "' '{}' 2>/dev/null; " + cmd + " >/dev/null 2>&1 &"])
    }
    close()
  }

  function activateAt(idx) {
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    const unit = list[idx]
    if (_showActions) {
      const acts = filteredActions
      if (actionIndex < 0 || actionIndex >= acts.length) return
      executeAction(unit._target ? unit._target : _targetUnit, acts[actionIndex].key)
      return
    }
    // default action like rofi: show list_actions picker
    _targetUnit = unit
    _showActions = true
    actionIndex = 0
    query = ""
  }

  function activateWithAction(idx, actionKey) {
    const list = filtered
    if (idx < 0 || idx >= list.length) return
    executeAction(list[idx], actionKey)
  }

  function move(delta) {
    _markKeyboard()
    if (_showActions) {
      const n = filteredActions.length; if (n === 0) return
      let ni = actionIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; actionIndex = ni; return
    }
    const n = filtered.length; if (n === 0) return
    let ni = selectedIndex + delta; if (ni < 0) ni = n - 1; if (ni >= n) ni = 0; selectedIndex = ni
  }
  function moveNoWrap(delta) {
    _markKeyboard()
    if (_showActions) {
      const n = filteredActions.length; if (n === 0) return
      const ni = actionIndex + delta; if (ni < 0 || ni >= n) return; actionIndex = ni; return
    }
    const n = filtered.length; if (n === 0) return
    const ni = selectedIndex + delta; if (ni < 0 || ni >= n) return; selectedIndex = ni
  }
  function goHome() {
    _markKeyboard()
    if (_showActions) { if (filteredActions.length > 0) actionIndex = 0; return }
    if (filtered.length > 0) selectedIndex = 0
  }
  function goEnd() {
    _markKeyboard()
    if (_showActions) { const n = filteredActions.length; if (n > 0) actionIndex = n - 1; return }
    const n = filtered.length; if (n > 0) selectedIndex = n - 1
  }
  function pageMove(dir) {
    _markKeyboard()
    if (_showActions) {
      const n = filteredActions.length; if (n === 0) return
      let page = 10
      let ni = actionIndex + dir * page; if (ni < 0) ni = 0; if (ni >= n) ni = n - 1; actionIndex = ni; return
    }
    const n = filtered.length; if (n === 0) return
    let page = 10; try { const h = listView ? listView.height : 0; if (h > 0) page = Math.max(1, Math.floor(h / 40)) } catch (e) {}
    let ni = selectedIndex + dir * page; if (ni < 0) ni = 0; if (ni >= n) ni = n - 1; selectedIndex = ni
    try { if (typeof listView !== "undefined" && listView) listView.positionViewAtIndex(ni, ListView.Contain) } catch (e) {}
  }

  Process {
    id: realFetch
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const arr = JSON.parse(String(text || "[]"))
          let out = []
          for (let e of arr) if (e.name) out.push(e)
          root.allEntries = out
          if (root.selectedIndex >= root.filtered.length) root.selectedIndex = 0
        } catch (e) { root.allEntries = [] }
      }
    }
  }

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
      WlrLayershell.namespace: "quickshell-systemd"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors { top: true; bottom: true; left: true; right: true }

      MouseArea { anchors.fill: parent; onClicked: root.close() }
      Rectangle { anchors.fill: parent; color: Theme.dim }

      Rectangle {
        id: container
        width: 780
        height: 520
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        clip: true
        LayoutMirroring.enabled: false
        focus: true

        Keys.onPressed: event => {
          const hasAlt = (event.modifiers & Qt.AltModifier) || event.key === Qt.Key_Alt
          if (hasAlt) root._altHeld = true
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_A) { root.sourceFilter = "All"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_U) { root.sourceFilter = "User"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_S) { root.sourceFilter = "System"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_F) { root.strategyFilter = "Files"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_R) { root.strategyFilter = "Running"; event.accepted = true; return }
          if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_B) { root.strategyFilter = "Both"; event.accepted = true; return }
          const inSearch = searchField.activeFocus
          if (event.key === Qt.Key_Escape) {
            if (root._showActions) { root._showActions = false; root.query = ""; event.accepted = true }
            else root.close()
            event.accepted = true
          } else if (event.key === Qt.Key_Slash && !inSearch && !(event.modifiers & Qt.AltModifier)) { searchField.forceActiveFocus(); event.accepted = true }
          else if (event.key === Qt.Key_R && !inSearch && !(event.modifiers & Qt.AltModifier) && !(event.modifiers & Qt.ControlModifier)) { root.refresh(); event.accepted = true }
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
            Rectangle { width: 32; height: 32; radius: 8; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: root._showActions ? "󰒓" : "󰒓"; color: Theme.fg; font.family: Theme.nerdFont; font.pixelSize: 14 }
            }
            ColumnLayout {
              spacing: 2
              Text { text: root._showActions && root._targetUnit ? "Action for " + root._targetUnit.name : "Systemd Units"; color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 14; font.bold: true }
              Text { text: root._showActions ? root.filteredActions.length + " actions" : root.filtered.length + " units • " + root.allEntries.length + " total • " + root.sourceFilter + " • " + root.strategyFilter; color: Theme.fg; opacity: 0.55; font.family: Theme.monoFont; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Rectangle { width: 28; height: 28; radius: 14; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.6; font.family: Theme.nerdFont; font.pixelSize: 11 }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
            Rectangle { width: 28; height: 28; radius: 14; color: Theme.surface; border.color: Theme.border; border.width: 1
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 11 }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 42
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
                  if (root._showActions) {
                    const acts = root.filteredActions
                    if (root.actionIndex >= 0 && root.actionIndex < acts.length && root._targetUnit) root.executeAction(root._targetUnit, acts[root.actionIndex].key)
                  } else root.activateAt(root.selectedIndex)
                }
                Keys.onPressed: event => {
                  const hasAlt = (event.modifiers & Qt.AltModifier) || event.key === Qt.Key_Alt
                  if (hasAlt) root._altHeld = true
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_A) { root.sourceFilter = "All"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_U) { root.sourceFilter = "User"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_S) { root.sourceFilter = "System"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_F) { root.strategyFilter = "Files"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_R) { root.strategyFilter = "Running"; event.accepted = true; return }
                  if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_B) { root.strategyFilter = "Both"; event.accepted = true; return }
                  if (event.key === Qt.Key_Escape) {
                    if (root._showActions) { root._showActions = false; text = ""; root.query = ""; event.accepted = true }
                    else if (text.length > 0) { text = ""; root.query = ""; event.accepted = true }
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
                    if (root._showActions) {
                      const acts = root.filteredActions
                      if (root.actionIndex >= 0 && root.actionIndex < acts.length && root._targetUnit) root.executeAction(root._targetUnit, acts[root.actionIndex].key)
                    } else root.activateAt(root.selectedIndex)
                    event.accepted = true
                  }
                  if (event.key === Qt.Key_Alt) root._altHeld = true
                }
                Keys.onReleased: event => {
                  if (event.key === Qt.Key_Alt) root._altHeld = false
                  else root._altHeld = Boolean(event.modifiers & Qt.AltModifier)
                }
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; visible: searchField.text === ""; text: root._showActions ? "Search action…" : "Search unit…"; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 14 }
              }
              Text { visible: searchField.text !== ""; text: ""; color: Theme.fg; opacity: 0.55; font.family: Theme.nerdFont; font.pixelSize: 12
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchField.text = ""; root.query = "" } }
              }
              Text { visible: searchField.text === "" && !root._showActions; text: "/"; color: Theme.fg; opacity: 0.35; font.family: Theme.monoFont; font.pixelSize: 11
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchField.forceActiveFocus() }
              }
            }
          }

          Flickable {
            visible: !root._showActions
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            contentWidth: filterRow.width
            contentHeight: 32
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            RowLayout {
              id: filterRow
              height: 32
              spacing: 8
              Repeater {
                model: root.sourceFilters
                Rectangle {
                  required property var modelData
                  height: 28
                  width: chipLabel.width + 22
                  radius: 14
                  color: root.sourceFilter === modelData.key ? Theme.fg : Theme.surface
                  border.color: root.sourceFilter === modelData.key ? Theme.fg : Theme.border
                  border.width: 1
                  Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: {
                      if (!root._altHeld) return modelData.label
                      if (modelData.key === "All") return "<u>A</u>ll"
                      if (modelData.key === "User") return "<u>U</u>ser"
                      if (modelData.key === "System") return "<u>S</u>ystem"
                      return modelData.label
                    }
                    textFormat: root._altHeld ? Text.RichText : Text.PlainText
                    color: root.sourceFilter === modelData.key ? Theme.bg : Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.bold: root.sourceFilter === modelData.key
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sourceFilter = modelData.key }
                }
              }
              Repeater {
                model: root.strategyFilters
                Rectangle {
                  required property var modelData
                  height: 28
                  width: stratLabel.width + 22
                  radius: 14
                  color: root.strategyFilter === modelData.key ? Theme.accent : Theme.surface
                  border.color: root.strategyFilter === modelData.key ? Theme.accent : Theme.border
                  border.width: 1
                  Text {
                    id: stratLabel
                    anchors.centerIn: parent
                    text: {
                      if (!root._altHeld) return modelData.label
                      if (modelData.key === "Files") return "<u>F</u>iles"
                      if (modelData.key === "Running") return "<u>R</u>unning"
                      if (modelData.key === "Both") return "<u>B</u>oth"
                      return modelData.label
                    }
                    textFormat: root._altHeld ? Text.RichText : Text.PlainText
                    color: root.strategyFilter === modelData.key ? Theme.bg : Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.bold: root.strategyFilter === modelData.key
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.strategyFilter = modelData.key }
                }
              }
              Item { Layout.preferredWidth: 8 }
              Text { text: root.filtered.length + " / " + root.allEntries.length; color: Theme.fg; opacity: 0.45; font.family: Theme.monoFont; font.pixelSize: 11; Layout.alignment: Qt.AlignVCenter }
            }
          }

          ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 6
            model: root._showActions ? root.filteredActions : root.filtered
            currentIndex: root._showActions ? root.actionIndex : root.selectedIndex
            onCurrentIndexChanged: {
              if (root._showActions) root.actionIndex = currentIndex
              else root.selectedIndex = currentIndex
              if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            }
            delegate: Rectangle {
              id: del
              required property var modelData
              required property int index
              width: listView.width
              height: root._showActions ? 38 : 44
              radius: Theme.radiusSm
              color: (root._showActions ? root.actionIndex : root.selectedIndex) === index ? Theme.surfaceHover : Theme.surface
              border.color: (root._showActions ? root.actionIndex : root.selectedIndex) === index ? Qt.alpha(Theme.fg, 0.33) : Theme.border
              border.width: 1
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Rectangle {
                  visible: !root._showActions
                  width: 8
                  height: 8
                  radius: 4
                  color: root.statusColor(del.modelData.state)
                  Layout.alignment: Qt.AlignVCenter
                  border.color: Qt.alpha(Theme.fg, 0.15)
                  border.width: 1
                }
                Text {
                  text: root._showActions ? (del.modelData.icon ?? "󰒓") : ((del.modelData.scope ?? "") === "user" ? "" : "󰒓")
                  color: Theme.fg
                  opacity: 0.7
                  font.family: Theme.nerdFont
                  font.pixelSize: 12
                  Layout.alignment: Qt.AlignVCenter
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text {
                    text: root._showActions ? (del.modelData.label ?? "") : (del.modelData.name ?? "")
                    color: Theme.fg
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    LayoutMirroring.enabled: false
                    font.bold: (root._showActions ? root.actionIndex : root.selectedIndex) === del.index
                  }
                  Text {
                    visible: !root._showActions
                    text: root._showActions ? "" : ((del.modelData.state ?? "") + " • " + (del.modelData.scope ?? ""))
                    color: Theme.fg
                    opacity: 0.45
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    LayoutMirroring.enabled: false
                  }
                }
                Text {
                  visible: !root._showActions
                  text: root._showActions ? "" : ((del.modelData.scope ?? "") === "user" ? "USER" : "SYSTEM")
                  color: (del.modelData.scope ?? "") === "user" ? Theme.accent : Theme.fg
                  opacity: (del.modelData.scope ?? "") === "user" ? 1 : 0.45
                  font.family: Theme.monoFont
                  font.pixelSize: 9
                  font.bold: (del.modelData.scope ?? "") === "user"
                }
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                  if (root._blockHover) return
                  if (root._showActions) root.actionIndex = del.index
                  else root.selectedIndex = del.index
                }
                onClicked: {
                  if (root._showActions) {
                    if (root._targetUnit) root.executeAction(root._targetUnit, del.modelData.key)
                  } else root.activateAt(del.index)
                }
              }
            }
            Text {
              anchors.centerIn: parent
              visible: (root._showActions ? root.filteredActions.length : root.filtered.length) === 0
              text: root.allEntries.length === 0 ? "No units found" : "No matches"
              color: Theme.fg
              opacity: 0.55
              font.family: Theme.monoFont
              font.pixelSize: 13
            }
          }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Text { text: "↵ actions"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
            Rectangle { width: 1; height: 10; color: Theme.border; opacity: 0.6 }
            Text { text: "Esc close"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
            Rectangle { width: 1; height: 10; color: Theme.border; opacity: 0.6 }
            Text { text: "Alt+key filter"; color: Theme.fg; opacity: 0.85; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true }
          }
        }
        Component.onCompleted: if (root.visible) searchField.forceActiveFocus()
        Connections { target: root; function onVisibleChanged() { if (root.visible) { searchField.text = ""; searchField.forceActiveFocus(); container.forceActiveFocus(); searchField.forceActiveFocus() } } }
      }
    }
  }
  }

  IpcHandler {
    target: "systemd"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  GlobalShortcut { name: "systemdToggle"; description: "Toggle systemd manager"; onPressed: root.toggle() }
}
