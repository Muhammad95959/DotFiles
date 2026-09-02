pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../common"

// Style1 — Centered 560×420 card (original Dmenu style)
// Extracted from Dmenu.qml so multiple styles can coexist.
// Used by Dmenu.qml controller via Loader/Variants.
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
  anchors { top:true; bottom:true; left:true; right:true }

  MouseArea { anchors.fill: parent; onClicked: qmenuRoot.close() }
  Rectangle { anchors.fill: parent; color: Theme.dim }

  Rectangle {
    width: 560
    height: Math.min(420, col.implicitHeight + 32)
    anchors.centerIn: parent
    radius: Theme.radiusLg
    color: Theme.bg
    border.color: Theme.border
    border.width: 1
    clip: true
    MouseArea { anchors.fill: parent; hoverEnabled:true; onPositionChanged: if(qmenuRoot._blockHover) qmenuRoot._blockHover=false; onClicked:{} }

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      // header
      RowLayout {
        Layout.fillWidth:true; spacing:10
        Rectangle { Layout.alignment: Qt.AlignVCenter; width:32; height:32; radius:8; color:Theme.surface; border.color:Theme.border; border.width:1
          Text { anchors.centerIn: parent; text: ""; color:Theme.fg; font.family:Theme.nerdFont; font.pixelSize:14 }
        }
        ColumnLayout { Layout.alignment: Qt.AlignVCenter; spacing:2
          Text { text: qmenuRoot.prompt; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:13; font.bold:true; visible: qmenuRoot.prompt.length>0 }
          Text { text: qmenuRoot.filtered.length + " / " + qmenuRoot.items.length; color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:11 }
        }
        Item { Layout.fillWidth:true }
        Rectangle { width:28; height:28; radius:14; color:Theme.surface; border.color:Theme.border; border.width:1
          Text { anchors.centerIn: parent; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:11 }
          MouseArea { anchors.fill: parent; cursorShape:Qt.PointingHandCursor; onClicked: qmenuRoot.close() }
        }
      }

      // search
      Rectangle {
        Layout.fillWidth:true; height:42; radius:Theme.radiusMd; color:Theme.surface; border.color: searchField.activeFocus?Qt.alpha(Theme.fg,0.40):Theme.border; border.width:1
        RowLayout {
          anchors.fill: parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:8
          TextInput {
            id: searchField
            Layout.fillWidth:true; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:13
            focus: true; activeFocusOnTab: false
            onTextChanged: qmenuRoot.query = text
            onAccepted: qmenuRoot.activateAt(qmenuRoot.selectedIndex)
            Keys.onPressed: event=>{
              if(event.key===Qt.Key_Escape){ qmenuRoot.cancelled(); qmenuRoot.close(); event.accepted=true}
              else if(event.key===Qt.Key_Up){ qmenuRoot.moveNoWrap(-1); event.accepted=true}
              else if(event.key===Qt.Key_Down){ qmenuRoot.moveNoWrap(1); event.accepted=true}
              else if(event.key===Qt.Key_Home){ qmenuRoot.goHome(); event.accepted=true}
              else if(event.key===Qt.Key_End){ qmenuRoot.goEnd(); event.accepted=true}
              else if(event.key===Qt.Key_PageUp){ qmenuRoot.pageMove(-1); event.accepted=true}
              else if(event.key===Qt.Key_PageDown){ qmenuRoot.pageMove(1); event.accepted=true}
              else if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter){ qmenuRoot.activateAt(qmenuRoot.selectedIndex); event.accepted=true}
            }
            Text { anchors.left:parent.left; anchors.verticalCenter:parent.verticalCenter; visible: searchField.text===""; text: qmenuRoot.placeholder; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:13 }
          }
          Text { visible: searchField.text!==""; text:""; color:Theme.fg; opacity:0.55; font.family:Theme.nerdFont; font.pixelSize:12
            MouseArea{ anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{ searchField.text=""; qmenuRoot.query="" } }
          }
        }
      }

      ListView {
        id: listView
        Layout.fillWidth:true
        Layout.preferredHeight: Math.min(260, Math.max(1, qmenuRoot.filtered.length) * 38)
        Layout.fillHeight: false
        clip:true; boundsBehavior:Flickable.StopAtBounds; spacing:4
        model: qmenuRoot.filtered
        currentIndex: qmenuRoot.selectedIndex
        onCurrentIndexChanged:{ qmenuRoot.selectedIndex=currentIndex; if(currentIndex>=0) positionViewAtIndex(currentIndex, ListView.Contain)}
        delegate: Rectangle {
          id: del
          required property var modelData
          required property int index
          width: listView.width; height: 34; radius: Theme.radiusSm
          color: qmenuRoot.selectedIndex===index ? Theme.surfaceHover : Theme.surface
          border.color: qmenuRoot.selectedIndex===index ? Qt.alpha(Theme.fg,0.33) : Theme.border; border.width:1
          RowLayout {
            anchors.fill: parent; anchors.leftMargin:12; anchors.rightMargin:12; spacing:10
            Text { text: del.modelData.label; color:Theme.fg; font.family:Theme.monoFont; font.pixelSize:12; Layout.fillWidth:true; elide:Text.ElideRight; font.bold: qmenuRoot.selectedIndex===del.index }
            Text { text: del.modelData.detail; color:Theme.fg; opacity:0.45; font.family:Theme.monoFont; font.pixelSize:11; visible: del.modelData.detail!==""; elide:Text.ElideRight; Layout.preferredWidth: Math.min(180, implicitWidth) }
          }
          MouseArea{ anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onEntered: if(!qmenuRoot._blockHover) qmenuRoot.selectedIndex=del.index; onClicked: qmenuRoot.activateAt(del.index) }
        }
        Text { anchors.centerIn: parent; visible: qmenuRoot.filtered.length===0; text: qmenuRoot.items.length===0 ? "No items" : "No match for \""+qmenuRoot.query+"\""; color:Theme.fg; opacity:0.55; font.family:Theme.monoFont; font.pixelSize:12 }
      }

    }

    Component.onCompleted: if(qmenuRoot.visible) searchField.forceActiveFocus()
    Connections{ target: qmenuRoot; function onVisibleChanged(){ if(qmenuRoot.visible){ searchField.text=""; searchField.forceActiveFocus() } } }
  }
}
