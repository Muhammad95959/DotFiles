pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets

import "../common"

Scope {
  id: root

  readonly property int notifWidth: 420
  readonly property int notifMaxHeight: 420
  readonly property int outerMargin: 20
  readonly property int paddingV: 12
  readonly property int paddingH: 12
  readonly property int borderSize: 1
  readonly property int borderRadius: 4
  readonly property int maxIconSize: 32
  readonly property int spacingInner: 10
  readonly property int actionSpacing: 8

  readonly property color bgColor: Qt.alpha(Theme.bg, 0.867)
  readonly property color textColor: Theme.fg
  readonly property color borderDefault: Qt.alpha(Theme.fg, 0.867)
  readonly property color borderActionable: Qt.alpha(Theme.fg, 0.867)
  readonly property color borderUrgent: Qt.alpha(Theme.urgent, 0.867)
  readonly property color progressColor: Qt.alpha(Theme.fg, 0.55)
  readonly property color actionBg: Theme.surface
  readonly property color actionBgHover: Theme.surfaceHover
  readonly property color actionBorder: Qt.alpha(Theme.border, 0.9)
  readonly property color actionBorderHover: Qt.alpha(Theme.fg, 0.9)
  readonly property color actionText: Theme.fg
  readonly property color closeHover: Qt.alpha(Theme.urgent, 0.18)

  property bool dnd: false

  function borderFor(notif) : color {
    if (notif.urgency === NotificationUrgency.Critical)
      return borderUrgent
    // quickshell has no High enum, so check the hint too.
    if (notif.hints["urgency"] === 2)
      return borderUrgent
    if (notif.actions.length > 0)
      return borderActionable
    return borderDefault
  }

  function effectiveTimeout(notif) : int {
    if (notif.urgency === NotificationUrgency.Critical)
      return 0
    if (notif.hints["urgency"] === 2)
      return 0
    let t = notif.expireTimeout
    if (notif.actions.length > 0) {
      if (t === -1 || t === 0) return 30000
      if (t === 5000) return 30000
      return t
    }
    if (t === -1 || t === undefined || isNaN(t)) return 5000
    if (t === 0) return 5000
    return t
  }

  function dismissAll() {
    const vals = server.trackedNotifications.values.slice()
    for (let i = 0; i < vals.length; i++)
      vals[i].dismiss()
  }

  function dismissByApp(appName: string) {
    const vals = server.trackedNotifications.values.slice()
    for (let i = 0; i < vals.length; i++)
      if (vals[i].appName === appName)
        vals[i].dismiss()
  }

  readonly property string whatsappDesktopEntry: "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default"
  readonly property string whatsappAppIdShort: "hnpfjngllnobngcgfapefoaidbinmjnm"

  function toplevelScore(t, lowerDe: string, isWhatsapp: bool): int {
    const ipc = t.lastIpcObject || {}
    const cls = (ipc.class || ipc.initialClass || (t.wayland ? t.wayland.appId : "") || "").toLowerCase()
    const title = ((ipc.title || t.title || "") + "").toLowerCase()
    if (cls.length === 0 && title.length === 0) return -1
    const shortDe = lowerDe.replace("-default", "")
    const shortCls = cls.replace("-default", "")
    if (cls === lowerDe) return 100
    if (isWhatsapp) {
      if (cls.includes(whatsappAppIdShort)) return 95
      if (cls === whatsappDesktopEntry.toLowerCase()) return 95
      if (shortDe.includes("hnpfj") && shortCls.includes("hnpfj")) return 90
      if (title.includes("whatsapp")) return 85
    }
    if (shortDe.length > 8 && shortCls.length > 8 && (shortDe.includes(shortCls) || shortCls.includes(shortDe))) return 80
    if (cls.includes(lowerDe) || lowerDe.includes(cls)) return 70
    if (title.includes(lowerDe)) return 60
    return -1
  }

  function findBestToplevel(desktopEntry: string, isWhatsapp: bool) {
    let toplevels = []
    try { toplevels = Hyprland.toplevels.values } catch (e) { toplevels = [] }
    let best = null
    let bestScore = -1
    const lowerDe = (desktopEntry || "").toLowerCase()
    const whatsappLower = whatsappDesktopEntry.toLowerCase()
    for (let i = 0; i < toplevels.length; i++) {
      const t = toplevels[i]
      let s = toplevelScore(t, lowerDe, isWhatsapp)
      if (isWhatsapp && lowerDe !== whatsappLower) {
        const s2 = toplevelScore(t, whatsappLower, true)
        if (s2 > s) s = s2
      }
      if (s > bestScore) {
        bestScore = s
        best = t
      }
    }
    if (isWhatsapp && best) {
      const ipc = best.lastIpcObject || {}
      const cls = (ipc.class || ipc.initialClass || (best.wayland ? best.wayland.appId : "") || "")
      if (cls.includes("new-tab-page")) {
        // try second best that is not new-tab-page
        let second = null
        let secondScore = -1
        for (let i = 0; i < toplevels.length; i++) {
          const t = toplevels[i]
          if (t === best) continue
          const s = toplevelScore(t, whatsappLower, true)
          if (s > secondScore) { secondScore = s; second = t }
        }
        if (second && secondScore >= 85) return second
      }
    }
    return bestScore >= 60 ? best : null
  }

  // Falls back to window focus when no "default" action exists (e.g. WhatsApp Web PWA).
  function focusWindowForDesktopEntry(desktopEntry: string, isWhatsapp: bool): bool {
    if (!desktopEntry || desktopEntry.length === 0) return false
    const candidate = findBestToplevel(desktopEntry, isWhatsapp)
    if (candidate) {
      const ipc = candidate.lastIpcObject || {}      const wsName = (candidate.workspace ? candidate.workspace.name : "") || ipc.workspace || ""
      const isSpecial = wsName.startsWith("special:")
      if (isSpecial) {
        let targetWs = "1"
        try {
          const fw = Hyprland.focusedWorkspace
          if (fw && fw.id) targetWs = String(fw.id)
          else {
            const mon = Hyprland.monitorFor(Quickshell.screens[0])
            if (mon && mon.activeWorkspace && mon.activeWorkspace.id) targetWs = String(mon.activeWorkspace.id)
          }
        } catch (e) {}
        Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspace", targetWs + ",address:" + candidate.address])
        Quickshell.execDetached(["sh", "-c", "sleep 0.05; hyprctl dispatch focuswindow address:" + candidate.address + "; hyprctl dispatch bringactivetotop address:" + candidate.address])
      } else {
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + candidate.address])
        Quickshell.execDetached(["hyprctl", "dispatch", "bringactivetotop", "address:" + candidate.address])
      }
      console.log("[notifications] focusWindowForDesktopEntry", desktopEntry, "->", candidate.address, (ipc.class || ""), wsName)
      return true
    }
    // Fallback: ask Hyprland to focus by class directly
    console.log("[notifications] focusWindowForDesktopEntry fallback class:", desktopEntry)
    Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:" + desktopEntry])
    return true
  }

  function activateNotification(notif): bool {
    const summary = (notif.summary || "").toLowerCase()
    const body = (notif.body || "").toLowerCase()
    const app = (notif.appName || "").toLowerCase()
    const isWhatsapp = app.includes("whatsapp") || summary.includes("whatsapp") || body.includes("whatsapp")
    if (isWhatsapp || app.includes("brave") || app.includes("chrome") || app.includes("chromium")) {
      console.log("[notifications] activate", JSON.stringify({
        appName: notif.appName, summary: notif.summary, body: (notif.body || "").slice(0,120),
        desktopEntry: notif.desktopEntry, hints: notif.hints, actions: notif.actions.map(a => a.identifier)
      }))
    }
    for (let i = 0; i < notif.actions.length; i++) {
      if (notif.actions[i].identifier === "default") {
        console.log("[notifications] invoke default for", notif.appName)
        notif.actions[i].invoke()
        notif.dismiss()
        return true
      }
    }
    let de = notif.desktopEntry || ""
    if (de.length === 0) {
      de = notif.hints["desktop-entry"] || notif.hints["desktop_entry"] || notif.hints["app-id"] || notif.hints["app_id"] || ""
    }
    if (isWhatsapp) {
      if (!de.toLowerCase().includes(whatsappAppIdShort)) {
        de = whatsappDesktopEntry
      }
    } else if (de.length === 0) {
      if (app === "brave" || app === "brave-browser" || app.includes("chromium") || app.includes("chrome")) {
        de = notif.appName
      }
    }
    if (de.length > 0) {
      focusWindowForDesktopEntry(de, isWhatsapp)
      notif.dismiss()
      return true
    }
    // Fallback via sender-pid hint.
    let pid = notif.hints["sender-pid"]
    if (pid === undefined) pid = notif.hints["sender_pid"]
    if (pid === undefined) pid = 0
    let pidStr = String(pid)
    if (pid && pidStr !== "0") {
      console.log("[notifications] fallback pid focus", pidStr)
      Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "pid:" + pidStr])
      notif.dismiss()
      return true
    }
    console.log("[notifications] no focus target, dismiss only", notif.appName)
    notif.dismiss()
    return false
  }

  NotificationServer {
    id: server
    keepOnReload: false
    actionsSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    imageSupported: true
    actionIconsSupported: false
    persistenceSupported: true
    inlineReplySupported: false

    onNotification: notification => {
      const isChromium = (notification.appName || "").toLowerCase().includes("brave") || 
                      (notification.appName || "").toLowerCase().includes("helium") ||
                      (notification.appName || "").toLowerCase().includes("chrome") ||
                      (notification.appName || "").toLowerCase().includes("chromium")

      // Bypass DND for notify-send and Chromium to prevent silent drops.
      if (root.dnd && notification.appName !== "notify-send" && !isChromium) {
        return
      }

      if (notification.appName === "power") {
        const vals = server.trackedNotifications.values.slice()
        for (let i = 0; i < vals.length; i++) {
          if (vals[i].appName === "power")
            vals[i].dismiss()
        }
      }
      
      notification.tracked = true
    }
  }

  // Newest-first view of tracked notifications.
  property var revModel: {
    const vals = server.trackedNotifications.values
    const len = vals.length
    let r = []
    for (let i = len - 1; i >= 0; i--) r.push(vals[i])
    return r
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "quickshell-notifications"

      // Anchored top-right and sized to the notification area so clicks outside pass through.
      anchors { top: true; right: true }
      // PanelWindow margins inset from screen edges
      margins { top: Config.barHeight + root.outerMargin; right: root.outerMargin; bottom: root.outerMargin }
      implicitWidth: root.notifWidth
      implicitHeight: Math.min(col.implicitHeight, (win.screen ? win.screen.height : 1080) - Config.barHeight - root.outerMargin * 2)
      visible: root.revModel.length > 0

      Column {
        id: col
        width: root.notifWidth
        spacing: 10

        Repeater {
          model: root.revModel
          delegate: NotificationCard {
            required property Notification modelData
            notif: modelData
          }
        }
      }
    }
  }

  component NotificationCard: Item {
    id: cardRoot
    required property Notification notif
    width: root.notifWidth
    implicitHeight: card.implicitHeight

    property int timeoutMs: root.effectiveTimeout(notif)
    property color borderCol: root.borderFor(notif)
    property int progressVal: {
      let v = notif.hints["value"]
      if (v === undefined) v = notif.hints["progress"]
      if (v === undefined) return -1
      let n = parseInt(v)
      if (isNaN(n)) return -1
      if (n < 0) n = 0
      if (n > 100) n = 100
      return n
    }

    Timer {
      id: dismissTimer
      interval: cardRoot.timeoutMs
      running: cardRoot.timeoutMs > 0
      repeat: false
      onTriggered: cardRoot.notif.dismiss()
    }

    Rectangle {
      id: card
      width: root.notifWidth
      implicitHeight: Math.min(contentCol.implicitHeight + root.paddingV * 2 + (cardRoot.progressVal >= 0 ? 6 : 0), root.notifMaxHeight)
      radius: root.borderRadius
      color: root.bgColor
      border.width: root.borderSize
      border.color: cardRoot.borderCol
      clip: true

      // Pause auto-dismiss on hover.
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
          if (dismissTimer.running) dismissTimer.stop()
        }
        onExited: {
          if (cardRoot.timeoutMs > 0) dismissTimer.restart()
        }
        z: 0
      }

      Rectangle {
        width: 18; height: 18
        radius: 2
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.paddingV + 2
        anchors.rightMargin: root.paddingH
        color: ca.containsMouse ? root.closeHover : "transparent"
        z: 10
        Text {
          anchors.centerIn: parent
          text: ""
          color: root.textColor
          opacity: ca.containsMouse ? 1 : 0.55
          font.family: "Symbols Nerd Font"
          font.pixelSize: 10
        }
        MouseArea {
          id: ca
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: cardRoot.notif.dismiss()
        }
      }

      ColumnLayout {
        id: contentCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.paddingV
        anchors.leftMargin: root.paddingH
        anchors.rightMargin: root.paddingH
        anchors.bottomMargin: cardRoot.progressVal >= 0 ? 6 + root.paddingV : root.paddingV
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          spacing: root.spacingInner
          Layout.rightMargin: 26

          Item {
            visible: iconImg.visible
            Layout.preferredWidth: root.maxIconSize
            Layout.preferredHeight: root.maxIconSize
            Layout.alignment: Qt.AlignTop

            IconImage {
              id: iconImg
              anchors.fill: parent
              visible: {
                let s = cardRoot.notif.image
                if (s && s.length > 0) return true
                let a = cardRoot.notif.appIcon
                if (a && a.length > 0) return true
                return false
              }
              source: {
                let s = cardRoot.notif.image
                if (s && s.length > 0) {
                  if (s.startsWith("/") || s.startsWith("file://"))
                    return s
                  let p = Quickshell.iconPath(s, true)
                  if (p && p.length > 0) return p
                  return s
                }
                let a = cardRoot.notif.appIcon
                if (a && a.length > 0) {
                  let p = Quickshell.iconPath(a, true)
                  return p.length > 0 ? p : a
                }
                return ""
              }
              implicitSize: root.maxIconSize
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Layout.alignment: Qt.AlignTop

            Text {
              visible: text.length > 0
              Layout.fillWidth: true
              text: cardRoot.notif.summary || ""
              color: root.textColor
              font.family: "sans-serif"
              font.pixelSize: 15
              font.bold: true
              wrapMode: Text.WrapAtWordBoundaryOrAnywhere
              maximumLineCount: 100
              elide: Text.ElideNone
              textFormat: Text.PlainText
            }

            Text {
              visible: text.length > 0
              Layout.fillWidth: true
              text: cardRoot.notif.body || ""
              color: Qt.alpha(root.textColor, 0.92)
              font.family: "sans-serif"
              font.pixelSize: 14
              wrapMode: Text.WrapAtWordBoundaryOrAnywhere
              maximumLineCount: 100
              elide: Text.ElideNone
              textFormat: Text.RichText
              onLinkActivated: link => Qt.openUrlExternally(link)
            }
          }
        }

        Text {
          visible: (cardRoot.notif.appName || "").length > 0 && (cardRoot.notif.appName !== cardRoot.notif.summary)
          Layout.fillWidth: true
          text: cardRoot.notif.appName
          color: Qt.alpha(root.textColor, 0.55)
          font.family: "sans-serif"
          font.pixelSize: 10
          elide: Text.ElideRight
          maximumLineCount: 1
          textFormat: Text.PlainText
        }

        Rectangle {
          visible: cardRoot.progressVal >= 0
          Layout.fillWidth: true
          Layout.preferredHeight: 4
          radius: 2
          color: Qt.alpha(root.progressColor, 0.25)
          clip: true
          Rectangle {
            height: parent.height
            radius: 2
            width: parent.width * (cardRoot.progressVal / 100)
            color: root.progressColor
          }
        }

        Flow {
          visible: cardRoot.notif.actions.length > 0
          Layout.alignment: Qt.AlignHCenter
          spacing: root.actionSpacing

          Repeater {
            model: cardRoot.notif.actions
              delegate: Rectangle {
                id: actBtn
                required property NotificationAction modelData
                visible: modelData.identifier !== "default"
              implicitWidth: actLabel.implicitWidth + 18
              implicitHeight: 26
              radius: 4
              color: ma.containsMouse ? root.actionBgHover : root.actionBg
              border.width: 1
              border.color: ma.containsMouse ? root.actionBorderHover : root.actionBorder

              Text {
                id: actLabel
                anchors.centerIn: parent
                text: actBtn.modelData.text || actBtn.modelData.identifier
                color: root.actionText
                font.family: "sans-serif"
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
              }

              MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  actBtn.modelData.invoke()
                  cardRoot.notif.dismiss()
                }
              }
            }
          }
        }
      }

      // Card click invokes default action (or window-focus fallback); right-click dismisses.
      MouseArea {
        anchors.fill: parent
        // keep below close button and action buttons so they receive clicks first
        z: -1
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton) {
            cardRoot.notif.dismiss()
            mouse.accepted = true
            return
          }
          // An action button already handled the click; don't double-activate.
          if (mouse.accepted) return
          root.activateNotification(cardRoot.notif)
          mouse.accepted = true
        }
      }

      // Entrance animation.
      NumberAnimation on opacity { from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }
  }

  IpcHandler {
    target: "notifications"
    function dismissAll(): string { root.dismissAll(); return "ok" }
    function dismiss(): string { root.dismissAll(); return "ok" }
    function dismissApp(appName: string): string { if (appName && appName.length > 0) root.dismissByApp(appName); else root.dismissAll(); return "ok" }
    function dismissGroup(group: string): string { root.dismissByApp(group); return "ok" }
    function closeAll(): string { root.dismissAll(); return "ok" }
    function dnd(state: string): string {
      if (state === "toggle") root.dnd = !root.dnd
      else if (state === "on" || state === "1" || state === "true") root.dnd = true
      else if (state === "off" || state === "0" || state === "false") root.dnd = false
      return root.dnd ? "on" : "off"
    }
    function isDnd(): string { return root.dnd ? "on" : "off" }
    function status(): string { return JSON.stringify({ dnd: root.dnd, count: server.trackedNotifications.values.length }) }
  }

  GlobalShortcut {
    name: "notificationsDismissAll"
    description: "Dismiss all notifications"
    onPressed: root.dismissAll()
  }
}
