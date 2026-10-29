import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui as Ui
import "ViewModel.js" as Model

Ui.Button {
    id: root
    required property var app
    required property var strings
    required property var palette
    property real largestBytes: 0
    signal cursorRequested()
    focusable: true
    implicitHeight: Style.space(36)
    foreground: Color.popups.text
    onActiveFocusChanged: if (activeFocus) cursorRequested()
    Accessible.name: app.name
    Accessible.description: Model.appSize(app, strings, I18n)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(4)
        anchors.rightMargin: Style.space(4)
        anchors.topMargin: Style.space(4)
        anchors.bottomMargin: Style.space(4)
        spacing: Style.space(9)
        Item {
            Layout.preferredWidth: Style.space(20)
            Layout.preferredHeight: Style.space(20)
            Image {
                id: appIcon
                anchors.fill: parent
                source: /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(root.app.icon || "") ? Quickshell.iconPath(root.app.icon, true) : ""
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            MapText {
                anchors.centerIn: parent
                visible: !appIcon.visible
                text: root.app.name.slice(0, 1).toLocaleUpperCase()
                font.pixelSize: Style.font.body
                color: Color.accent
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(3)
            RowLayout {
                Layout.fillWidth: true
                MapText {
                    Layout.fillWidth: true
                    text: root.app.name
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                }
                MapText {
                    Layout.maximumWidth: root.width * 0.45
                    elide: Text.ElideRight
                    text: Model.appSize(root.app, root.strings, I18n)
                    font.pixelSize: Style.font.bodySmall
                    color: Color.popups.text
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(2)
                color: Util.alpha(Color.popups.text, 0.06)
                Row {
                    width: parent.width * (root.largestBytes > 0 ? Math.min(1, root.app.mappedBytes / root.largestBytes) : 0)
                    height: parent.height
                    Repeater {
                        model: Model.categoryKeys
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: parent.width * (root.app.mappedBytes > 0 ? (root.app.categories[modelData] || 0) / root.app.mappedBytes : 0)
                            height: parent.height
                            color: root.palette[index]
                        }
                    }
                }
            }
        }
    }
}
