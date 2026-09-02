pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
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

    // Pause on hover, resume on exit (like mako hover behaviour)
    property bool hovered: false

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
          cardRoot.hovered = true
          if (dismissTimer.running) dismissTimer.stop()
        }
        onExited: {
          cardRoot.hovered = false
          if (cardRoot.timeoutMs > 0) dismissTimer.restart()
        }
        onPositionChanged: {}
        z: 0
      }

      // ── Close button (top-right) — margins match text padding ───────
      Rectangle {
        id: closeBtn
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
            id: iconWrap
            visible: iconImg.visible
            Layout.preferredWidth: root.maxIconSize
            Layout.preferredHeight: root.maxIconSize
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 8 // align icon top with first line cap height

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
              id: summaryText
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
              id: bodyText
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
          id: appNameText
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
          id: actionFlow
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

      // ── Default action click (if only default) ───────────────────────
      MouseArea {
        // clicks on card invoke default action if exists, otherwise dismiss?
        // We keep dismiss on click only if actionable? Mako: on-button-left=exec makoctl menu...
        // Now we invoke default directly, and second click dismisses? Let's mirror common behavior:
        // left click invokes default action if present.
        anchors.fill: parent
        // below closeBtn and action buttons: let action buttons handle their clicks first
        // So we need z ordering: this is behind. Use propagate.
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton
        cursorShape: cardRoot.notif.actions.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
          // find default action
          for (let i = 0; i < cardRoot.notif.actions.length; i++) {
            if (cardRoot.notif.actions[i].identifier === "default") {
              cardRoot.notif.actions[i].invoke()
              cardRoot.notif.dismiss()
              mouse.accepted = true
              return
            }
          }
          // if no default but single action, clicking card could invoke it? optional — we leave no-op
          mouse.accepted = false
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
