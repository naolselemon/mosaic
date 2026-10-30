import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

Rectangle {
    id: root
    property string label: ""
    property string value: ""
    property string detail: ""
    property string icon: ""
    property color tint: Color.accent
    property real ratio: -1
    property bool actionable: false
    signal clicked()
    signal focused(var item)
    implicitWidth: Style.space(148)
    implicitHeight: content.implicitHeight + Style.space(20)
    Layout.alignment: Qt.AlignTop
    radius: Style.space(10)
    color: Util.alpha(tint, 0.075)
    Ui.Button {
        anchors.fill: parent
        visible: root.actionable
        focusable: root.actionable
        radius: root.radius
        text: ""
        Accessible.name: root.label + ": " + root.value
        Accessible.description: root.detail
        onClicked: root.clicked()
        onActiveFocusChanged: if (activeFocus) root.focused(root)
    }

    ColumnLayout {
        id: content
        x: Style.space(10)
        y: Style.space(10)
        width: parent.width - Style.space(20)
        spacing: Style.space(5)
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            MapGlyph { visible: root.icon !== ""; icon: root.icon; color: root.tint; font.pixelSize: Style.font.caption }
            MapText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.7)
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
        MapText {
            Layout.fillWidth: true
            text: root.value
            font.pixelSize: Style.font.heading
            font.weight: Font.DemiBold
            color: root.tint
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(3)
            visible: root.ratio >= 0
            radius: height / 2
            color: Util.alpha(root.tint, 0.14)
            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, root.ratio))
                radius: parent.radius
                color: root.tint
                Behavior on width { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
            }
        }
        MapText {
            Layout.fillWidth: true
            visible: root.detail !== ""
            text: root.detail
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.72)
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
