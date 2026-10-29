import QtQuick
import qs.Commons
import qs.Ui as Ui

import "Icons.js" as Icons
Ui.Button {
    id: root
    property string icon: "info"
    required property string label
    focusable: true
    foreground: Color.popups.text
    implicitWidth: Style.space(26)
    implicitHeight: Style.space(26)
    horizontalPadding: 0
    verticalPadding: 0
    iconSize: Style.font.body
    tooltipText: label
    Accessible.name: label
    Accessible.role: Accessible.Button
    iconText: Icons.glyph(icon, I18n.rightToLeft)

}
