pragma ComponentBehavior: Bound
import Quickshell.Io
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../common"

Scope {
  id: root

  // ── Config (mirrors mako) ───────────────────────────────────────────
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

  // Colors with DD opacity (0xDD/255 ≈ 0.867) — actionable now uses Theme
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

  // ── DND ─────────────────────────────────────────────────────────────
  property bool dnd: false

  function borderFor(notif) : color {
    if (notif.urgency === NotificationUrgency.Critical)
      return borderUrgent
    // mako [urgency=high] also uses same red; quickshell has no High enum,
    // so Critical covers it. Could check hint urgency=2 as well.
    if (notif.hints["urgency"] === 2)
      return borderUrgent
    if (notif.actions.length > 0)
      return borderActionable
    return borderDefault
  }

  function effectiveTimeout(notif) : int {
    // critical → persistent (0)
    if (notif.urgency === NotificationUrgency.Critical)
      return 0
    if (notif.hints["urgency"] === 2)
      return 0
    let t = notif.expireTimeout
    // actionable overrides to 30s (mako has two [actionable] blocks)
    if (notif.actions.length > 0) {
      if (t === -1 || t === 0) return 30000
      if (t === 5000) return 30000
      return t
    }
    // non-actionable defaults
    if (t === -1 || t === undefined || isNaN(t)) return 5000
    if (t === 0) return 5000 // 0 means server default except critical
    return t
  }

  function dismissAll() {
    // copy because trackedNotifications changes during iteration
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

  // WhatsApp PWA app-id (brave --app-id=hnpfj...)
  readonly property string whatsappDesktopEntry: "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default"
  readonly property string whatsappAppIdShort: "hnpfjngllnobngcgfapefoaidbinmjnm"

  // Score helper for finding the best toplevel match
  function toplevelScore(t, lowerDe: string, isWhatsapp: bool): int {
    const ipc = t.lastIpcObject || {}
    const cls = (ipc.class || ipc.initialClass || (t.wayland ? t.wayland.appId : "") || "").toLowerCase()
    const title = ((ipc.title || t.title || "") + "").toLowerCase()
    if (cls.length === 0 && title.length === 0) return -1
    const shortDe = lowerDe.replace("-default", "")
    const shortCls = cls.replace("-default", "")
    // exact whatsapp PWA class is highest priority
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
    // for whatsapp, also try whatsapp DE even if requested de is generic
    const whatsappLower = whatsappDesktopEntry.toLowerCase()
    for (let i = 0; i < toplevels.length; i++) {
      const t = toplevels[i]
      let s = toplevelScore(t, lowerDe, isWhatsapp)
      // if whatsapp, also score against whatsapp DE as alternative
      if (isWhatsapp && lowerDe !== whatsappLower) {
        const s2 = toplevelScore(t, whatsappLower, true)
        if (s2 > s) s = s2
      }
      if (s > bestScore) {
        bestScore = s
        best = t
      }
    }
    // never return the hidden new-tab page if we are looking for whatsapp and best is that page
    if (isWhatsapp && best) {
      const ipc = best.lastIpcObject || {}
      const cls = (ipc.class || ipc.initialClass || (best.wayland ? best.wayland.appId : "") || "")
      // new-tab page is brave-__home_muhammad_Projects_new-tab-page_index.html-Default
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

  // Try to focus the window that sent the notification.
  // Used as fallback when no "default" action is present (e.g. WhatsApp Web
  // via Brave PWA sends actions=[] but expects click → focus).
  function focusWindowForDesktopEntry(desktopEntry: string, isWhatsapp: bool): bool {
    if (!desktopEntry || desktopEntry.length === 0) return false
    // 1) Try to find a matching Hyprland toplevel and focus by address (most precise)
    const candidate = findBestToplevel(desktopEntry, isWhatsapp)
    if (candidate) {
      const ipc = candidate.lastIpcObject || {}
      const wsName = (candidate.workspace ? candidate.workspace.name : "") || ipc.workspace || ""
      const isSpecial = wsName.startsWith("special:")
      if (isSpecial) {
        // Move from special:hidden / special:minimized to active workspace then focus
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
        // small delay then focus
        Quickshell.execDetached(["sh", "-c", "sleep 0.05; hyprctl dispatch focuswindow address:" + candidate.address + "; hyprctl dispatch bringactivetotop address:" + candidate.address])
      } else {
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + candidate.address])
        Quickshell.execDetached(["hyprctl", "dispatch", "bringactivetotop", "address:" + candidate.address])
      }
      console.log("[notifications] focusWindowForDesktopEntry", desktopEntry, "->", candidate.address, (ipc.class || ""), wsName)
      return true
    }
    // 2) Fallback: ask Hyprland to focus by class directly
    console.log("[notifications] focusWindowForDesktopEntry fallback class:", desktopEntry)
    Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:" + desktopEntry])
    return true
  }

  function activateNotification(notif): bool {
    const summary = (notif.summary || "").toLowerCase()
    const body = (notif.body || "").toLowerCase()
    const app = (notif.appName || "").toLowerCase()
    const isWhatsapp = app.includes("whatsapp") || summary.includes("whatsapp") || body.includes("whatsapp")
    // Debug: log all hints for brave/whatsapp to catch mismatched desktopEntry
    if (isWhatsapp || app.includes("brave") || app.includes("chrome") || app.includes("chromium")) {
      console.log("[notifications] activate", JSON.stringify({
        appName: notif.appName, summary: notif.summary, body: (notif.body || "").slice(0,120),
        desktopEntry: notif.desktopEntry, hints: notif.hints, actions: notif.actions.map(a => a.identifier)
      }))
    }
    // 1) spec-compliant: invoke "default" if present
    for (let i = 0; i < notif.actions.length; i++) {
      if (notif.actions[i].identifier === "default") {
        console.log("[notifications] invoke default for", notif.appName)
        notif.actions[i].invoke()
        notif.dismiss()
        return true
      }
    }
    // 2) fallback: try to focus window via desktopEntry / hints
    let de = notif.desktopEntry || ""
    if (de.length === 0) {
      // freedesktop hints: "desktop-entry", "desktop_entry", "app-id", "x-canonical-*"
      de = notif.hints["desktop-entry"] || notif.hints["desktop_entry"] || notif.hints["app-id"] || notif.hints["app_id"] || ""
    }
    // Force whatsapp DE if content indicates whatsapp, even if de is generic "brave"/"chromium"
    if (isWhatsapp) {
      // if de is generic or missing, override; if de already looks like whatsapp PWA keep it
      if (!de.toLowerCase().includes(whatsappAppIdShort)) {
        de = whatsappDesktopEntry
      }
    } else if (de.length === 0) {
      if (app === "brave" || app === "brave-browser" || app.includes("chromium") || app.includes("chrome")) {
        // generic brave window — try appName as class
        de = notif.appName
      }
    }
    if (de.length > 0) {
      focusWindowForDesktopEntry(de, isWhatsapp)
      notif.dismiss()
      return true
    }
    // 3) fallback via sender-pid
    let pid = notif.hints["sender-pid"]
    if (pid === undefined) pid = notif.hints["sender_pid"]
    if (pid === undefined) pid = 0
    // hints may store pid as int or string
    let pidStr = String(pid)
    if (pid && pidStr !== "0") {
      console.log("[notifications] fallback pid focus", pidStr)
      Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "pid:" + pidStr])
      notif.dismiss()
      return true
    }
    // 4) last resort: just dismiss (don't leave stale notification)
    console.log("[notifications] no focus target, dismiss only", notif.appName)
    notif.dismiss()
    return false
  }

  // ── Notification server ─────────────────────────────────────────────
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
      // [mode=do-not-disturb] invisible=true except app-name=notify-send
      if (root.dnd && notification.appName !== "notify-send") {
        // drop silently (not tracked)
        return
      }
      // [app-name=power] group-by=app-name  → replace previous power notifs
      if (notification.appName === "power") {
        const vals = server.trackedNotifications.values.slice()
        for (let i = 0; i < vals.length; i++) {
          if (vals[i].appName === "power")
            vals[i].dismiss()
        }
      }
      // Also replace-by-id if same replaces-id handling is automatic via notification id?
      // but ensure tracked
      notification.tracked = true
    }
  }

  // reverse model (newest top) — reactive on values
  property var revModel: {
    const vals = server.trackedNotifications.values
    // force re-eval when length changes
    const len = vals.length
    let r = []
    for (let i = len - 1; i >= 0; i--) r.push(vals[i])
    return r
  }

  // ── Per-screen overlay ───────────────────────────────────────────────
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

      // anchored top-right, inset by outerMargin + bar height — only covers
      // notification area so clicks outside pass through. Fixes left cut
      // (previous implicitWidth + child rightMargin overflowed).
      anchors { top: true; right: true }
      // PanelWindow margins inset from screen edges
      margins { top: Config.barHeight + root.outerMargin; right: root.outerMargin; bottom: root.outerMargin }
      implicitWidth: root.notifWidth
      // height tracks content but never exceeds screen height
      implicitHeight: Math.min(col.implicitHeight, (win.screen ? win.screen.height : 1080) - Config.barHeight - root.outerMargin * 2)
      visible: root.revModel.length > 0

      Column {
        id: col
        // fill the inset window — no extra margins to avoid double offset
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

  // ── Delegated card ───────────────────────────────────────────────────
  component NotificationCard: Item {
    id: cardRoot
    required property Notification notif
    width: root.notifWidth
    // height determined by content + progress bar + actions, capped at maxHeight
    implicitHeight: card.implicitHeight

    // Effective timeout computed once per notification
    property int timeoutMs: root.effectiveTimeout(notif)
    property color borderCol: root.borderFor(notif)
    // progress hint: freedesktop value hint (0-100) or "value" string
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
      // Card height is the single tunable knob. Grows with content up to
      // notifMaxHeight, then content is clipped (increase notifMaxHeight
      // to allow taller notifications).
      implicitHeight: Math.min(contentCol.implicitHeight + root.paddingV * 2 + (cardRoot.progressVal >= 0 ? 6 : 0), root.notifMaxHeight)
      radius: root.borderRadius
      color: root.bgColor
      border.width: root.borderSize
      border.color: cardRoot.borderCol
      clip: true

      // pause timer on hover
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
        onPositionChanged: {}
        z: 0
      }

      // ── Close button (top-right) — margins match text padding ───────
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

      // ── Content column ──────────────────────────────────────────────
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

        // Top row: icon + summary/body
        RowLayout {
          Layout.fillWidth: true
          spacing: root.spacingInner
          Layout.rightMargin: 26 // leave room for 22px close btn

          // Icon (max 32) — prefer notification image, fallback appIcon
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
                  // if absolute path or file://, use as-is; else icon lookup
                  if (s.startsWith("/") || s.startsWith("file://"))
                    return s
                  // try icon path
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

            // Summary (title) — bold, allow multiline (bilal uses summary for multi-line)
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

            // Body — allow long bodies to expand height instead of eliding
            Text {
              visible: text.length > 0
              Layout.fillWidth: true
              text: {
                let b = cardRoot.notif.body || ""
                return b
              }
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

        // App name — dedicated line at bottom, mirrors text padding
        // 10px size, own row so margins match body/summary
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

        // ── Progress bar (if hint value present) ──────────────────────
        // mako progress-color=over #838691
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

        // ── Action buttons (replaces rofi selector) — centered ───────
        Flow {
          visible: cardRoot.notif.actions.length > 0
          Layout.alignment: Qt.AlignHCenter
          spacing: root.actionSpacing

          Repeater {
            model: cardRoot.notif.actions
            delegate: Rectangle {
              id: actBtn
              required property NotificationAction modelData
              // hide "default" action which is usually click-action — we handle via card click
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
                  // dismiss after invoking (mako closes on action)
                  cardRoot.notif.dismiss()
                }
              }
            }
          }
        }
      }

      // ── Card click: invoke default or fallback focus (WhatsApp Web) ────
      // Right-click dismisses notification
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
          // if an action button already handled the click, don't double-activate
          if (mouse.accepted) return
          root.activateNotification(cardRoot.notif)
          mouse.accepted = true
        }
      }

      // Entrance animation (slide from right)
      NumberAnimation on opacity { from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }
  }

  // ── IPC ───────────────────────────────────────────────────────────────
  IpcHandler {
    target: "notifications"
    function dismissAll(): string { root.dismissAll(); return "ok" }
    function dismiss(): string { root.dismissAll(); return "ok" }
    function dismissApp(appName: string): string { if (appName && appName.length > 0) root.dismissByApp(appName); else root.dismissAll(); return "ok" }
    // makoctl compat: dismiss [-a app] [-g group] [-i id]
    function dismissGroup(group: string): string { root.dismissByApp(group); return "ok" }
    // alias for makoctl compatibility helpers
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
