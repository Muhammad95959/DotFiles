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
  function close() { visible = false }

  // stage: vms | actions
  property string stage: "vms"
  property string query: ""
  property int selectedIndex: 0
  property var vms: [] // {name, state}
  property var actions: [
    { label: "Force off", icon: "󰐥", shortcut: "F" },
    { label: "Shutdown", icon: "", shortcut: "S" },
    { label: "Open with virt-viewer", icon: "󰖃", shortcut: "V" },
    { label: "Open with virt-manager", icon: "󰣖", shortcut: "M" }
  ]
  readonly property string selectedVmState: {
    if (stage !== "vms" || filteredVms.length === 0 || selectedIndex < 0 || selectedIndex >= filteredVms.length) return ""
    return filteredVms[selectedIndex].state || ""
  }
  property string pendingVm: ""
  property string pendingState: ""
  property string _accum: ""
  property bool _blockHover: false
  function _markKeyboard() { _blockHover = true }

  readonly property var filteredVms: {
    const q = query.toLowerCase().trim()
    if (q === "") return vms
    const toks = q.split(/\s+/)
    return vms.filter(v => {
      const hay = v.name.toLowerCase()
      for (let t=0; t<toks.length; t++) if (!hay.includes(toks[t])) return false
      return true
    })
  }
  readonly property var filteredActions: {
    const q = query.toLowerCase().trim()
    if (q === "") return actions
    const toks = q.split(/\s+/)
    return actions.filter(a => {
      const hay = a.label.toLowerCase()
      for (let t=0; t<toks.length; t++) if (!hay.includes(toks[t])) return false
      return true
    })
  }
  property int currentCount: stage === "vms" ? filteredVms.length : filteredActions.length

  onQueryChanged: selectedIndex = 0
  onVisibleChanged: if (visible) { selectedIndex = 0; _blockHover = true }

  function refreshVms() {
    _accum = ""; vms = []
    ensureProc.running = true
  }

  // ensure libvirtd + net
  Process {
    id: ensureProc
    command: ["sh","-c","sudo systemctl start libvirtd 2>/dev/null; sudo virsh net-start default 2>/dev/null || true; echo done"]
    onExited: listProc.running = true
  }

  Process {
    id: listProc
    command: ["sh","-c","sudo virsh list --all --name 2>/dev/null | sed '/^$/d'"]
    stdout: SplitParser { onRead: data => root._accum += data + "\n" }
    onExited: {
      const names = root._accum.split("\n").map(s=>s.trim()).filter(s=>s.length>0)
      if (names.length === 0) { root.vms = []; return }
      // fetch states in one call to avoid multiple sudo
      stateAccum = ""; stateProc.command = ["sh","-c", names.map(n=> "printf '" + n.replace(/'/g,"'\\''") + ":'; sudo virsh domstate '" + n.replace(/'/g,"'\\''") + "' 2>/dev/null | tr -d '\\n'; echo").join("; ")]
      stateProc.running = true
    }
  }
  property string stateAccum: ""
  Process {
    id: stateProc
    stdout: SplitParser { onRead: data => root.stateAccum += data + "\n" }
    onExited: {
      const lines = root.stateAccum.split("\n").map(s=>s.trim()).filter(s=>s.length>0)
      let out = []
      for (let l of lines) {
        const idx = l.indexOf(":")
        if (idx < 0) continue
        const n = l.slice(0, idx)
        const st = l.slice(idx+1).trim()
        out.push({ name: n, state: st })
      }
      // fallback if parsing failed (use names only)
      if (out.length === 0) {
        const names = root._accum.split("\n").map(s=>s.trim()).filter(s=>s.length>0)
        out = names.map(n=> ({name:n, state:"unknown"}))
      }
      root.vms = out
      root.selectedIndex = 0
    }
  }

  function chooseVm(idx) {
    const list = filteredVms
    if (idx<0||idx>=list.length) return
    const vm = list[idx]
    pendingVm = vm.name
    pendingState = vm.state
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
      Quickshell.execDetached(["sh","-c","sudo virsh -c qemu:///system destroy '" + vm.replace(/'/g,"'\\''") + "' 2>&1 | xargs -I{} notify-send \"VM\" \"{}\" 2>/dev/null || true"])
    } else if (act === "Shutdown") {
      Quickshell.execDetached(["sh","-c","sudo virsh -c qemu:///system shutdown '" + vm.replace(/'/g,"'\\''") + "' 2>&1 | xargs -I{} notify-send \"VM\" \"{}\" 2>/dev/null || true"])
    } else if (act === "Open with virt-viewer") {
      Quickshell.execDetached(["sh","-c","SPICE_NOGRAB=1 virt-viewer --connect qemu:///system '" + vm.replace(/'/g,"'\\''") + "' --full-screen &"])
    } else if (act === "Open with virt-manager") {
      Quickshell.execDetached(["sh","-c","virt-manager --connect qemu:///system --show-domain-console '" + vm.replace(/'/g,"'\\''") + "' &"])
    }
    close()
  }
  function startAndView(vm) {
    Quickshell.execDetached(["sh","-c","if sudo virsh -c qemu:///system start '" + vm.replace(/'/g,"'\\''") + "' 2>&1; then SPICE_NOGRAB=1 virt-viewer --connect qemu:///system '" + vm.replace(/'/g,"'\\''") + "' --full-screen & else notify-send \"VM Launcher\" \"Failed to start " + vm.replace(/"/g,"") + "\"; fi"])
    close()
  }
  function onAccepted() {
    if (stage === "vms") chooseVm(selectedIndex)
    else chooseAction(selectedIndex)
  }
  function handleActionShortcut(text) {
    if (stage !== "actions") return false
    const k = String(text||"").toLowerCase()
    if (k.length !== 1) return false
    // map F/S/V/M and 1-4
    let idx = -1
    if (k === "f" || k === "1") idx = 0
    else if (k === "s" || k === "2") idx = 1
    else if (k === "v" || k === "3") idx = 2
    else if (k === "m" || k === "4") idx = 3
    else {
      for (let i=0;i<actions.length;i++) if (actions[i].shortcut.toLowerCase()===k) { idx=i; break }
    }
    if (idx>=0 && idx<filteredActions.length) { chooseAction(idx); return true }
    return false
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
  function goHome(){ _markKeyboard(); if(currentCount>0) selectedIndex=0 }
  function goEnd(){ _markKeyboard(); if(currentCount>0) selectedIndex=currentCount-1 }
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
        width: Math.max(320, col.implicitHeight * 4 / 3); height: Math.min(560, col.implicitHeight + 32); anchors.centerIn: parent; radius: Theme.radiusLg; color: Theme.bg; border.color: Theme.border; border.width:1; clip:true
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
                  else if(event.key===Qt.Key_Home){ root.goHome(); event.accepted=true}
                  else if(event.key===Qt.Key_End){ root.goEnd(); event.accepted=true}
                  else if(event.key===Qt.Key_PageUp){ root.pageMove(-1); event.accepted=true}
                  else if(event.key===Qt.Key_PageDown){ root.pageMove(1); event.accepted=true}
                  else if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter){ root.onAccepted(); event.accepted=true}
                  else if(event.key===Qt.Key_Backspace && text==="" && root.stage==="actions"){ root.onBack(); event.accepted=true}
                  else if(root.stage==="actions" && event.text && event.text.length===1){
                    if(root.handleActionShortcut(event.text)){ event.accepted=true }
                  }
                  else if(root.stage==="actions" && event.key>=Qt.Key_1 && event.key<=Qt.Key_4){
                    const d = String.fromCharCode(event.key); if(root.handleActionShortcut(d)){ event.accepted=true }
                  }
                }
                Text{ anchors.left:parent.left; anchors.verticalCenter:parent.verticalCenter; visible: searchField.text===""; text: root.stage==="vms" ? "Search VM…" : "Search action…"; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:14 }
              }
              Text{ visible: searchField.text!==""; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:12; MouseArea{anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{ searchField.text=""; root.query="" } } }
            }
          }
          ListView{
            id: listView; Layout.fillWidth:true; Layout.preferredHeight: Math.min(360, Math.max(1, root.currentCount) * 46); Layout.fillHeight:false; clip:true; boundsBehavior:Flickable.StopAtBounds; spacing:6
            model: root.stage==="vms" ? root.filteredVms : root.filteredActions
            currentIndex: root.selectedIndex
            onCurrentIndexChanged:{ root.selectedIndex=currentIndex; if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain) }
            delegate: Rectangle{
              id: del; required property var modelData; required property int index; width:listView.width; height:42; radius:Theme.radiusSm; color: root.selectedIndex===index?Theme.surfaceHover:Theme.surface; border.color: root.selectedIndex===index?Qt.alpha(Theme.fg,0.33):Theme.border; border.width:1
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
                Rectangle{
                  visible: root.stage==="actions"
                  width: 18; height: 18; radius: 4
                  color: root.selectedIndex===del.index ? Theme.accent : Qt.alpha(Theme.fg,0.08)
                  border.color: root.selectedIndex===del.index ? Theme.accent : Qt.alpha(Theme.fg,0.15)
                  border.width: 1
                  Layout.alignment: Qt.AlignVCenter
                  Text{ anchors.centerIn: parent; anchors.verticalCenterOffset: 0.5; text: modelData.shortcut || ""; color: root.selectedIndex===del.index ? Theme.bg : Theme.fg; opacity: root.selectedIndex===del.index ? 1 : 0.7; font.family:Theme.monoFont; font.pixelSize:9; font.bold:true }
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
          RowLayout{ Layout.alignment:Qt.AlignHCenter; spacing:6; visible: root.stage==="actions"
            Text{ text:"F"; color:Theme.bg; font.family:Theme.monoFont; font.pixelSize:9; font.bold:true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
              Rectangle{ anchors.centerIn: parent; width: parent.width+8; height: 16; radius:4; color: Theme.accent; z:-1; visible: root.selectedIndex===0 }
              width:12; height:12
            }
            Text{ text:"Force off"; color:Theme.fg; opacity: root.selectedIndex===0?1:0.7; font.family:Theme.monoFont; font.pixelSize:10; font.bold: root.selectedIndex===0 }
            Text{ text:"•"; color:Theme.fg; opacity:0.3; font.pixelSize:10 }
            Text{ text:"S"; color:Theme.bg; font.family:Theme.monoFont; font.pixelSize:9; font.bold:true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
              Rectangle{ anchors.centerIn: parent; width: parent.width+8; height: 16; radius:4; color: Theme.accent; z:-1; visible: root.selectedIndex===1 }
              width:12; height:12
            }
            Text{ text:"Shutdown"; color:Theme.fg; opacity: root.selectedIndex===1?1:0.7; font.family:Theme.monoFont; font.pixelSize:10; font.bold: root.selectedIndex===1 }
            Text{ text:"•"; color:Theme.fg; opacity:0.3; font.pixelSize:10 }
            Text{ text:"V"; color:Theme.bg; font.family:Theme.monoFont; font.pixelSize:9; font.bold:true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
              Rectangle{ anchors.centerIn: parent; width: parent.width+8; height: 16; radius:4; color: Theme.accent; z:-1; visible: root.selectedIndex===2 }
              width:12; height:12
            }
            Text{ text:"Viewer"; color:Theme.fg; opacity: root.selectedIndex===2?1:0.7; font.family:Theme.monoFont; font.pixelSize:10; font.bold: root.selectedIndex===2 }
            Text{ text:"•"; color:Theme.fg; opacity:0.3; font.pixelSize:10 }
            Text{ text:"M"; color:Theme.bg; font.family:Theme.monoFont; font.pixelSize:9; font.bold:true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
              Rectangle{ anchors.centerIn: parent; width: parent.width+8; height: 16; radius:4; color: Theme.accent; z:-1; visible: root.selectedIndex===3 }
              width:12; height:12
            }
            Text{ text:"Manager"; color:Theme.fg; opacity: root.selectedIndex===3?1:0.7; font.family:Theme.monoFont; font.pixelSize:10; font.bold: root.selectedIndex===3 }
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
