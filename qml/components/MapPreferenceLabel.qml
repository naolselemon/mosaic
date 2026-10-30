import QtQuick
import QtQuick.Layouts
import qs.Commons

RowLayout {
    id: root
    property string icon: ""
    required property string label
    property string description: ""
    property color accent: Color.accent

    Layout.minimumWidth: 0
    spacing: Style.space(9)

    MapGlyph {
        visible: root.icon !== ""
        Layout.minimumWidth: Style.space(16)
        Layout.preferredWidth: Style.space(16)
        Layout.maximumWidth: Style.space(16)
        Layout.alignment: Qt.AlignVCenter
        icon: root.icon
        font.pixelSize: Style.font.bodySmall
        color: root.accent
        Accessible.ignored: true
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: Style.space(2)

        MapText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.label
            horizontalAlignment: Text.AlignLeft
            font.pixelSize: Style.font.bodySmall
            color: root.icon !== "" ? Qt.tint(Color.popups.text, Util.alpha(root.accent, 0.3)) : Color.popups.text
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: root.description !== ""
            text: root.description
            horizontalAlignment: Text.AlignLeft
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.6)
            wrapMode: Text.Wrap
        }
    }
}
