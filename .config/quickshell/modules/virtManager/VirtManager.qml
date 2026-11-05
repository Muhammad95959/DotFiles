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
  function open() { visible = true; stage = "vms"; selectedIndex = 0; query = ""; refreshVms() }
  function close() { visible = false; query = ""; selectedIndex = 0 }

  property string stage: "vms"
  property string query: ""
  property int selectedIndex: 0
  readonly property int entryHeight: 42
  readonly property int entryGap: 6
  readonly property int vmEntries: 3
  readonly property int menuWidth: 420
  property var vms: []
  property string _accum: ""
  readonly property var actions: [
    { label: "Force off", icon: "󰐥" },
    { label: "Shutdown", icon: "" },
    { label: "Open with virt-viewer", icon: "󰖃" },
    { label: "Open with virt-manager", icon: "󰣖" }
  ]
  readonly property int menuListHeight: Math.max(vmEntries, actions.length) * entryHeight + (Math.max(vmEntries, actions.length) - 1) * entryGap
  readonly property int menuHeight: 180 + menuListHeight
  readonly property string selectedVmState: {
    if (stage !== "vms" || filteredVms.length === 0 || selectedIndex < 0 || selectedIndex >= filteredVms.length) return ""
    return filteredVms[selectedIndex].state || ""
  }
  property string pendingVm: ""
  property bool _blockHover: false
  function _markKeyboard() { _blockHover = true }
  function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
  function matchAll(hay, toks) {
    for (let t = 0; t < toks.length; t++) if (!hay.includes(toks[t])) return false
    return true
  }

  readonly property var filteredVms: {
    const q = query.toLowerCase().trim()
    if (q === "") return vms
    const toks = q.split(/\s+/)
    return vms.filter(v => matchAll(v.name.toLowerCase(), toks))
  }
  readonly property var filteredActions: {
    const q = query.toLowerCase().trim()
    if (q === "") return actions
    const toks = q.split(/\s+/)
    return actions.filter(a => matchAll(a.label.toLowerCase(), toks))
  }
  property int currentCount: stage === "vms" ? filteredVms.length : filteredActions.length

  onQueryChanged: selectedIndex = 0
  onVisibleChanged: { if (visible) { query=""; selectedIndex = 0; _blockHover = true } else { query=""; selectedIndex = 0 } }

  function refreshVms() {
    _accum = ""
    ensureProc.running = true
  }

  Process {
    id: ensureProc
    command: ["sh","-c","sudo systemctl start libvirtd 2>/dev/null; sudo virsh net-start default 2>/dev/null || true; echo done"]
    onExited: listProc.running = true
  }

  Process {
    id: listProc
    command: ["sh","-c","sudo virsh list --all --name 2>/dev/null | sed '/^$/d'"]
    stdout: SplitParser { onRead: data => root._accum += data + "\n" }
    onExited: queryStates()
  }

  function queryStates() {
    stateAccum = ""
    const names = _accum.split("\n").map(s=>s.trim()).filter(s=>s.length>0)
    if (names.length === 0) { vms = []; selectedIndex = 0; return }
    stateProc.command = ["sh","-c", names.map(n=> "printf " + root.shQuote(n + ":") + "; sudo virsh domstate " + root.shQuote(n) + " 2>/dev/null | tr -d '\\n'; echo").join("; ")]
    stateProc.running = true
  }
  property string stateAccum: ""
  Process {
    id: stateProc
    stdout: SplitParser { onRead: data => root.stateAccum += data + "\n" }
    onExited: {
      const lines = root.stateAccum.split("\n").map(s=>s.trim()).filter(s=>s.length>0)
      const states = {}
      for (let l of lines) {
        const idx = l.indexOf(":")
        if (idx < 0) continue
        states[l.slice(0, idx)] = l.slice(idx+1).trim() || "unknown"
      }
      const names = root._accum.split("\n").map(s=>s.trim()).filter(s=>s.length>0)
      root.vms = names.map(n => ({ name: n, state: states[n] || "unknown" }))
      root.selectedIndex = 0
    }
  }

  function chooseVm(idx) {
    const list = filteredVms
    if (idx<0||idx>=list.length) return
    const vm = list[idx]
    pendingVm = vm.name
    if (vm.state === "running") {
      stage = "actions"; selectedIndex = 0; query = ""
    } else {
      startAndView(vm.name)
    }
  }
  function chooseAction(idx) {
    const list = filteredActions
    if (idx<0||idx>=list.length) return
    const act = list[idx].label
    const vm = pendingVm
    if (act === "Force off") {
      Quickshell.execDetached(["sh","-c","out=$(sudo virsh -c qemu:///system destroy " + shQuote(vm) + " 2>&1); notify-send \"VM\" \"$out\" 2>/dev/null || true"])
    } else if (act === "Shutdown") {
      Quickshell.execDetached(["sh","-c","out=$(sudo virsh -c qemu:///system shutdown " + shQuote(vm) + " 2>&1); notify-send \"VM\" \"$out\" 2>/dev/null || true"])
    } else if (act === "Open with virt-viewer") {
      Quickshell.execDetached(["sh","-c","SPICE_NOGRAB=1 virt-viewer --connect qemu:///system " + shQuote(vm) + " --full-screen &"])
    } else if (act === "Open with virt-manager") {
      Quickshell.execDetached(["sh","-c","virt-manager --connect qemu:///system --show-domain-console " + shQuote(vm) + " &"])
    }
    close()
  }
  function startAndView(vm) {
    Quickshell.execDetached(["sh","-c","if sudo virsh -c qemu:///system start " + shQuote(vm) + " 2>&1; then SPICE_NOGRAB=1 virt-viewer --connect qemu:///system " + shQuote(vm) + " --full-screen & else notify-send \"VM Launcher\" \"Failed to start " + vm.replace(/"/g,"") + "\"; fi"])
    close()
  }
  function onAccepted() {
    if (stage === "vms") chooseVm(selectedIndex)
    else chooseAction(selectedIndex)
  }
  function onBack() {
    if (stage === "actions") { stage = "vms"; selectedIndex = 0; query = "" }
    else close()
  }

  function move(delta){
    _markKeyboard(); const n=currentCount; if(n===0)return; let ni=selectedIndex+delta; if(ni<0) ni=n-1; if(ni>=n) ni=0; selectedIndex=ni
  }
  function moveNoWrap(delta){
    _markKeyboard(); const n=currentCount; if(n===0)return; const ni=selectedIndex+delta; if(ni<0||ni>=n) return; selectedIndex=ni
  }
  function pageMove(dir){
    _markKeyboard(); const n=currentCount; if(n===0)return; let page=10; try{ const h=listView?listView.height:0; if(h>0) page=Math.max(1, Math.floor(h/42))}catch(e){} let ni=selectedIndex+dir*page; if(ni<0) ni=0; if(ni>=n) ni=n-1; selectedIndex=ni; try{ if(typeof listView!=="undefined"&&listView) listView.positionViewAtIndex(ni, ListView.Contain)}catch(e){}
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
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-virt"
      anchors { top:true; bottom:true; left:true; right:true }
      MouseArea{ anchors.fill: parent; onClicked: root.stage==="actions" ? root.onBack() : root.close() }
      Rectangle{ anchors.fill: parent; color: Theme.dim }
      Rectangle {
        width: root.menuWidth; height: root.menuHeight; anchors.centerIn: parent; radius: Theme.radiusLg; color: Theme.bg; border.color: Theme.border; border.width:1; clip:true
        LayoutMirroring.enabled: false
        MouseArea{ anchors.fill: parent; hoverEnabled:true; onPositionChanged: if(root._blockHover) root._blockHover=false; onClicked:{} }
        ColumnLayout {
          id: col
          anchors.fill: parent; anchors.margins:16; spacing:12
          RowLayout {
            Layout.fillWidth:true; spacing:10
            Rectangle{ width:32; height:32; radius:8; color:Theme.surface; border.color:Theme.border; border.width:1; Text{ anchors.centerIn:parent; text: root.stage==="vms"?"󰢹":"󰄾"; color:Theme.fg; font.family:Theme.nerdFont; font.pixelSize:14 } }
            ColumnLayout{
              spacing:2
              Text{ text: root.stage==="vms" ? "Virtual Machines" : pendingVm + " is running"; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:14; font.bold:true }
              Text{ text: root.stage==="vms" ? (root.filteredVms.length + " vms") : "choose action"; color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:11 }
            }
            Item{ Layout.fillWidth:true }
            Rectangle{ visible: root.stage==="actions"; width:28; height:28; radius:14; color:Theme.surface; border.color:Theme.border; border.width:1; Text{ anchors.centerIn:parent; text:"󰦛"; color:Theme.fg; font.family:Theme.nerdFont; font.pixelSize:12 } MouseArea{ anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: root.onBack() } }
            Rectangle{ width:28; height:28; radius:14; color:Theme.surface; border.color:Theme.border; border.width:1; Text{ anchors.centerIn:parent; text:""; color:Theme.fg; opacity:0.6; font.family:Theme.nerdFont; font.pixelSize:11 } MouseArea{ anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: root.refreshVms() } }
            Rectangle{ width:28; height:28; radius:14; color:Theme.surface; border.color:Theme.border; border.width:1; Text{ anchors.centerIn:parent; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:11 } MouseArea{ anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: root.close() } }
          }
          Rectangle {
            Layout.fillWidth:true; height:42; radius:Theme.radiusMd; color:Theme.surface; border.color: searchField.activeFocus?Qt.alpha(Theme.fg,0.40):Theme.border; border.width:1
            RowLayout{ anchors.fill:parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:8
              Text{ text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:14 }
              TextInput{
                id: searchField; Layout.fillWidth:true; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:14; focus:true; activeFocusOnTab:false
                text: root.query
                onTextChanged: root.query=text
                onAccepted: root.onAccepted()
                Keys.onPressed: event=>{
                  if(event.key===Qt.Key_Escape){ if(root.stage==="actions") root.onBack(); else root.close(); event.accepted=true}
                  else if(event.key===Qt.Key_Backtab){ root.move(-1); event.accepted=true}
                  else if(event.key===Qt.Key_Tab){ if(event.modifiers & Qt.ShiftModifier) root.move(-1); else root.move(1); event.accepted=true }
                  else if(event.key===Qt.Key_Up){ root.moveNoWrap(-1); event.accepted=true}
                  else if(event.key===Qt.Key_Down){ root.moveNoWrap(1); event.accepted=true}
                  else if(event.key===Qt.Key_Left){ root.moveNoWrap(-1); event.accepted=true}
                  else if(event.key===Qt.Key_Right){ root.moveNoWrap(1); event.accepted=true}
                  else if(event.key===Qt.Key_PageUp){ root.pageMove(-1); event.accepted=true}
                  else if(event.key===Qt.Key_PageDown){ root.pageMove(1); event.accepted=true}
                  else if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter){ root.onAccepted(); event.accepted=true}
                  else if(event.key===Qt.Key_Backspace && text==="" && root.stage==="actions"){ root.onBack(); event.accepted=true}
                }
                Text{ anchors.left:parent.left; anchors.verticalCenter:parent.verticalCenter; visible: searchField.text===""; text: root.stage==="vms" ? "Search VM…" : "Search action…"; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:14 }
              }
              Text{ visible: searchField.text!==""; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:12; MouseArea{anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{ searchField.text=""; root.query="" } } }
            }
          }
          ListView{
            id: listView; Layout.fillWidth:true; Layout.preferredHeight: { const n = root.stage==="vms" ? root.vmEntries : root.actions.length; return n * root.entryHeight + (n - 1) * root.entryGap } Layout.fillHeight:false; clip:true; boundsBehavior:Flickable.StopAtBounds; spacing: root.entryGap
            model: root.stage==="vms" ? root.filteredVms : root.filteredActions
            currentIndex: root.selectedIndex
            onCurrentIndexChanged:{ root.selectedIndex=currentIndex; if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain) }
            delegate: Rectangle{
              id: del; required property var modelData; required property int index; width:listView.width; height: root.entryHeight; radius:Theme.radiusSm; color: root.selectedIndex===index?Theme.surfaceHover:Theme.surface; border.color: root.selectedIndex===index?Qt.alpha(Theme.fg,0.33):Theme.border; border.width:1
              RowLayout{
                anchors.fill:parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:12
                Rectangle{
                  width:28; height:28; radius:6
                  color: root.stage==="vms" ? (modelData.state==="running"?Qt.alpha(Theme.accent,0.2):Theme.bg) : Qt.alpha(Theme.accent,0.12)
                  border.color:Theme.border; border.width:1
                  Layout.alignment: Qt.AlignVCenter
                  Text{ anchors.centerIn:parent; anchors.verticalCenterOffset: 0.5; text: root.stage==="vms" ? (modelData.state==="running"?"󰐥":"󰢹") : modelData.icon; color: root.stage==="vms" && modelData.state==="running" ? Theme.accent : Theme.fg; font.family:Theme.nerdFont; font.pixelSize:12 }
                }
                ColumnLayout{
                  Layout.fillWidth:true; Layout.alignment: Qt.AlignVCenter; spacing:2
                  Text{
                    text: root.stage==="vms" ? modelData.name : modelData.label
                    color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:12; font.bold: root.selectedIndex===del.index; horizontalAlignment: Text.AlignLeft; LayoutMirroring.enabled: false
                    elide:Text.ElideRight; Layout.fillWidth:true
                    verticalAlignment: Text.AlignVCenter; leftPadding: 0; topPadding: 0; bottomPadding: 0
                    lineHeight: 1.0; lineHeightMode: Text.FixedHeight
                  }
                  Text{
                    text: root.stage==="vms" ? modelData.state : ""
                    color:Theme.fg; opacity:0.5; font.family:Theme.monoFont; font.pixelSize:10
                    visible: root.stage==="vms" && modelData.state !== ""
                    elide:Text.ElideRight; Layout.fillWidth:true
                    verticalAlignment: Text.AlignVCenter; lineHeight: 1.0; lineHeightMode: Text.FixedHeight
                  }
                }
                Text{
                  text: root.stage==="vms" && modelData.state==="running" ? "running" : ""
                  color:Theme.accent; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true
                  visible: root.stage==="vms" && modelData.state==="running"
                  Layout.alignment: Qt.AlignVCenter; verticalAlignment: Text.AlignVCenter
                  Layout.preferredWidth: visible ? implicitWidth : 0
                }
              }
              MouseArea{ anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onClicked: { if (root.selectedIndex === del.index) { if (root.stage === "vms") root.chooseVm(del.index); else root.chooseAction(del.index) } else root.selectedIndex = del.index } }
            }
            Text{ anchors.centerIn:parent; visible: root.currentCount===0; text: root.stage==="vms" ? (root.vms.length===0?"No VMs":"No match") : "No actions"; color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:13 }
          }
          Item{ Layout.fillHeight:true }
          RowLayout{ Layout.alignment:Qt.AlignHCenter; spacing:8; visible: root.stage==="vms"
            Text{
              text: {
                if (root.selectedVmState === "running") return "↵ Actions"
                if (root.selectedVmState !== "") return "↵ Start & View"
                return "↵ Select"
              }
              color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true
            }
            Rectangle{ width:1; height:10; color:Theme.border; opacity:0.6 }
            Text{ text:"Esc Close"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true }
            Text{ text:"•"; color:Theme.fg; opacity:0.3; font.pixelSize:10; visible: root.selectedVmState==="running" }
            Text{ text:"running → actions"; color:Theme.accent; font.family:Theme.monoFont; font.pixelSize:9; visible: root.selectedVmState==="running" }
            Text{ text:"•"; color:Theme.fg; opacity:0.3; font.pixelSize:10; visible: root.selectedVmState!=="" && root.selectedVmState!=="running" }
            Text{ text:"shut off → start"; color:Theme.fg; opacity:0.6; font.family:Theme.monoFont; font.pixelSize:9; visible: root.selectedVmState!=="" && root.selectedVmState!=="running" }
          }
          RowLayout{ Layout.alignment:Qt.AlignHCenter; spacing:8; visible: root.stage==="actions"
            Text{ text:"↵ Run"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true }
            Rectangle{ width:1; height:10; color:Theme.border; opacity:0.6 }
            Text{ text:"Esc Back"; color:Theme.fg; opacity:0.85; font.family:Theme.monoFont; font.pixelSize:10; font.bold:true }
          }
        }
        Component.onCompleted: if(root.visible) searchField.forceActiveFocus()
        Connections{ target: root; function onVisibleChanged(){ if(root.visible){ searchField.text=""; root.query=""; searchField.forceActiveFocus() } } }
      }
    }
  }
  }

  IpcHandler {
    target: "virtManager"
    function toggle(): string { root.toggle(); return root.visible ? "open" : "closed" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
  }
  GlobalShortcut { name: "virtManagerToggle"; description: "Toggle VM manager"; onPressed: root.toggle() }
}
