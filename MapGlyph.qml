import QtQuick
import qs.Commons
import "Icons.js" as Icons

MapText {
    property string icon: "info"
    text: Icons.glyph(icon, I18n.rightToLeft)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Accessible.ignored: true
}
