pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Wayland

import "../../common"

// Oneliner — full-width top bar (ported from modules/oneliner/OnelinerBar,
// 1:1 with rofi/oneliner.rasi: north, 100% width, inputbar 20% + horizontal listview)
// Used by Qmenu.qml controller via Loader/Variants. Wired to qmenuRoot:
//   query/filtered/selectedIndex + activateAt/move/cancelled/close.
// Enter with items → activateAt(selectedIndex); with no items (or no match)
// and non-empty query → submitFreeText() (free-text input mode).
PanelWindow {
  required property var modelData
  required property var qmenuRoot
  screen: modelData
  visible: qmenuRoot.visible
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.namespace: "quickshell-qmenu"
  anchors { top: true; bottom: true; left: true; right: true }

  readonly property bool inputOnly: qmenuRoot.items.length === 0

  function acceptCurrent() {
    if (qmenuRoot.filtered.length > 0) {
      qmenuRoot.activateAt(qmenuRoot.selectedIndex)
    } else if (qmenuRoot.query.trim().length > 0) {
      qmenuRoot.submitFreeText()
    }
  }

  MouseArea { anchors.fill: parent; onClicked: qmenuRoot.close() }
  Rectangle { anchors.fill: parent; color: Theme.dim }

  Rectangle {
    width: parent.width
    height: Config.barHeight
    anchors.top: parent.top
    anchors.topMargin: 0
    color: Theme.bg

    RowLayout {
      anchors.fill: parent
      spacing: 0

      // ── Inputbar (20% width, or 100% in inputOnly) ──
      Rectangle {
        Layout.preferredWidth: inputOnly ? parent.width : Math.floor(parent.width * 0.20)
        Layout.fillHeight: true
        color: Theme.bg
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          anchors.topMargin: 1
          anchors.bottomMargin: 1
          spacing: 8
          Text {
            text: qmenuRoot.prompt
            color: Theme.fg
            font.family: Theme.monoFont
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            visible: text !== ""
          }
          TextInput {
            id: entry
            Layout.fillWidth: true
            color: Theme.fg
            font.family: Theme.monoFont
            font.pixelSize: 13
            focus: true
            activeFocusOnTab: false
            verticalAlignment: TextInput.AlignVCenter
            onTextChanged: qmenuRoot.query = text
            onAccepted: acceptCurrent()
            Keys.onPressed: event => {
              if (event.key === Qt.Key_Escape) { qmenuRoot.cancelled(); qmenuRoot.close(); event.accepted = true }
              else if (event.key === Qt.Key_Backtab) { qmenuRoot.move(-1); event.accepted = true }
              else if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier) qmenuRoot.move(-1)
                else qmenuRoot.move(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Right) { qmenuRoot.moveNoWrap(1); event.accepted = true }
              else if (event.key === Qt.Key_Left) { qmenuRoot.moveNoWrap(-1); event.accepted = true }
              else if (event.key === Qt.Key_Down) { qmenuRoot.moveNoWrap(1); event.accepted = true }
              else if (event.key === Qt.Key_Up) { qmenuRoot.moveNoWrap(-1); event.accepted = true }
              else if (event.key === Qt.Key_Home) { qmenuRoot.goHome(); event.accepted = true }
              else if (event.key === Qt.Key_End) { qmenuRoot.goEnd(); event.accepted = true }
              else if (event.key === Qt.Key_PageUp) { qmenuRoot.pageMove(-1); event.accepted = true }
              else if (event.key === Qt.Key_PageDown) { qmenuRoot.pageMove(1); event.accepted = true }
            }
            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.text === "" && qmenuRoot.placeholder !== ""
              text: qmenuRoot.placeholder
              color: Theme.fg
              opacity: 0.35
              font.family: Theme.monoFont
              font.pixelSize: 13
            }
          }
        }
      }

      // ── Listview (horizontal) ──
      ListView {
        visible: !inputOnly
        Layout.fillWidth: true
        Layout.fillHeight: true
        orientation: ListView.Horizontal
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 0
        model: qmenuRoot.filtered
        currentIndex: qmenuRoot.selectedIndex
        onCurrentIndexChanged: { if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain) }
        LayoutMirroring.enabled: false
        delegate: Rectangle {
          id: del
          required property var modelData
          required property int index
          width: Math.max(150, delText.implicitWidth + 16)
          height: ListView.view.height
          color: qmenuRoot.selectedIndex === index ? Theme.fg : "transparent"
          Text {
            id: delText
            anchors.centerIn: parent
            text: del.modelData.label
            color: qmenuRoot.selectedIndex === index ? Theme.bg : Theme.fg
            font.family: Theme.monoFont
            font.pixelSize: 13
            elide: Text.ElideRight
            opacity: 1
            horizontalAlignment: Text.AlignLeft
            LayoutMirroring.enabled: false
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
              if (mouse.button === Qt.LeftButton) {
                if (qmenuRoot.selectedIndex === del.index) acceptCurrent()
                else qmenuRoot.selectedIndex = del.index
              }
            }
          }
        }
      }
    }

    Component.onCompleted: if (qmenuRoot.visible) entry.forceActiveFocus()
    Connections {
      target: qmenuRoot
      function onVisibleChanged() {
        if (qmenuRoot.visible) { entry.text = ""; qmenuRoot.query = ""; entry.forceActiveFocus() }
      }
    }
  }
}
