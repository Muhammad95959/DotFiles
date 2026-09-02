pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../common"

// Reusable top-bar picker — 1:1 with rofi/oneliner.rasi
// window { location: north; width:100%; height:24px; y-offset:-24px; bg @background; children [mainbox,message] }
// mainbox horizontal [inputbar(20%), listview(horizontal)]
// Use inside a PanelWindow anchored top.
Item {
  id: root
  required property string prompt
  required property string query
  required property var model
  required property int selectedIndex
  property bool inputOnly: false
  property string placeholder: ""
  signal queryChangedStr(string newQuery)
  signal accepted(int index)
  signal cancelled()
  signal moved(int delta)
  signal hovered(int index)

  // expose focus call
  function focusInput() { entry.forceActiveFocus() }
  function clear() { entry.text = "" }

  height: Config.barHeight
  // background handled by parent PanelWindow; this is row content — theme colors only

  RowLayout {
    anchors.fill: parent
    spacing: 0

    // ── Inputbar (20% width, or 100% in inputOnly) ──
    Rectangle {
      id: inputBar
      Layout.preferredWidth: root.inputOnly ? parent.width : Math.floor(parent.width * 0.20)
      Layout.fillHeight: true
      color: Theme.bg
      // rofi: padding 1px 8px spacing 8px
      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        spacing: 8
        Text {
          id: promptText
          text: root.prompt
          color: Theme.fg
          font.family: Theme.monoFont
          font.pixelSize: 13
          verticalAlignment: Text.AlignVCenter
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
          onTextChanged: root.queryChangedStr(text)
          onAccepted: {
            if (root.inputOnly) {
              if (text.trim().length > 0) root.accepted(-1)
            } else {
              root.accepted(root.selectedIndex)
            }
          }
          Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { root.cancelled(); event.accepted = true }
            else if (!root.inputOnly && event.key === Qt.Key_Right) { root.moved(1); event.accepted = true }
            else if (!root.inputOnly && event.key === Qt.Key_Left) { root.moved(-1); event.accepted = true }
            else if (!root.inputOnly && event.key === Qt.Key_Tab) { root.moved(1); event.accepted = true }
            else if (!root.inputOnly && event.key === Qt.Key_Backtab) { root.moved(-1); event.accepted = true }
            else if (!root.inputOnly && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) { /* ignore vertical */ event.accepted = true }
            else if (event.key === Qt.Key_Home) { root.moved(-9999); event.accepted = true }
            else if (event.key === Qt.Key_End) { root.moved(9999); event.accepted = true }
          }
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.text === "" && root.placeholder !== ""
            text: root.placeholder
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
      id: listView
      visible: !root.inputOnly
      Layout.fillWidth: true
      Layout.fillHeight: true
      orientation: ListView.Horizontal
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      spacing: 0
      model: root.model
      currentIndex: root.selectedIndex
      onCurrentIndexChanged: { if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain) }
      delegate: Rectangle {
        id: del
        required property var modelData
        required property int index
        width: Math.max(150, delText.implicitWidth + 16)
        height: ListView.view.height
        color: root.selectedIndex === index ? Theme.fg : "transparent"
        // element selected normal bg @accent-color, text @background
        // element normal urgent/active handled via modelData if present
        Text {
          id: delText
          anchors.centerIn: parent
          text: {
            if (typeof del.modelData === "string") return del.modelData
            if (del.modelData.label) return del.modelData.label
            if (del.modelData.name) return del.modelData.name
            if (del.modelData.title) return del.modelData.title
            return String(del.modelData)
          }
          color: root.selectedIndex === index ? Theme.bg : Theme.fg
           font.family: Theme.monoFont
           font.pixelSize: 13
          elide: Text.ElideRight
          // urgent/active coloring when not selected
          opacity: {
            if (root.selectedIndex === del.index) return 1
            if (del.modelData && del.modelData.urgent) return 1
            return 1
          }
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          // rofi hover-select true, me-select-entry MousePrimary, me-accept-entry !MousePrimary
          onEntered: root.hovered(del.index)
          onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
              root.hovered(del.index)
              root.accepted(del.index)
            }
          }
        }
      }
    }
  }
}
