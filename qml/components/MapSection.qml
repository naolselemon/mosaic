import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
    id: root
    property string title: ""
    property string caption: ""
    default property alias content: body.data
    implicitWidth: Style.space(320)
    implicitHeight: layout.implicitHeight + Style.space(20)
    radius: Style.space(10)
    color: Util.alpha(Color.popups.text, 0.045)

    ColumnLayout {
        id: layout
        x: Style.space(10)
        y: Style.space(10)
        width: parent.width - Style.space(20)
        spacing: Style.space(8)
        MapText {
            Layout.fillWidth: true
            visible: root.title !== ""
            text: root.title
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            visible: root.caption !== ""
            text: root.caption
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.Wrap
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: Style.space(8)
        }
    }
}
