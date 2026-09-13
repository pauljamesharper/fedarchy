import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.screenshot"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: "Screenshot (right-click for capture menu)"
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("omarchy-menu toggle capture")
      else root.bar.run("omarchy-capture-screenshot")
    }
  }
}
