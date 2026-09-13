import QtQuick
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false

  // Font Awesome's bell-slash (a BMP codepoint, no surrogate pair) instead of
  // Material Design's md-bell_off (U+F009B, supplementary plane): the latter
  // reliably rendered as a broken "CSI" placeholder in this component,
  // seemingly specific to that exact codepoint - every other supplementary-
  // plane icon here renders fine, and the glyph itself is valid in every
  // installed font, so the cause is somewhere in Qt's text stack rather than
  // missing font coverage. Not worth chasing further when an equivalent
  // glyph one plane down sidesteps it entirely.
  active: dnd
  activeText: ""
  inactiveText: ""
  activeTooltipText: "Allow Notifications"
  inactiveTooltipText: "Silence Notifications"

  onPressed: function() {
    if (root.notificationService) {
      root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
    }
  }
}
