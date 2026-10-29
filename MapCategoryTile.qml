import QtQuick
import Quickshell
import qs.Commons
import qs.Ui as Ui

Item {
    id: root
    required property var tile
    required property var workspace
    required property color tint
    property bool selected: false
    readonly property real gutter: Math.min(Style.space(2), width * 0.08, height * 0.08)
    readonly property bool actionable: width >= Style.space(34) && height >= Style.space(30)
    readonly property bool roomy: width >= Style.space(105) && height >= Style.space(76)
    readonly property string label: tile.kind === "other" ? workspace.strings.t("category.other") : tile.name
    signal activated()
    signal inspected(bool inspecting)

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.gutter
        radius: Math.min(Style.space(5), width / 5, height / 5)
        color: Util.alpha(root.tint, root.selected ? 0.3 : 0.17)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Util.alpha(root.tint, 0.14)
            opacity: tileButton.hot || tileButton.activeFocus || root.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.workspace.motionEnabled ? Style.duration(140) : 0; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: root.tint
            border.width: Style.space(1)
            opacity: root.selected ? 1 : 0
        }
    }
    Ui.Button {
        id: tileButton
        anchors.fill: parent
        anchors.margins: root.gutter
        visible: root.actionable
        focusable: root.actionable
        selected: root.selected
        foreground: Color.popups.text
        accent: root.tint
        scale: 1
        clip: true
        Accessible.name: root.label
        Accessible.description: root.workspace.strings.t(root.tile.kind === "other" ? "category.otherDescription" : "category.tileDescription").arg(root.workspace.size(root.tile.bytes, root.tile.partial))
        onClicked: root.activated()
        onHovered: function(isHovered) { root.inspected(isHovered || activeFocus); }
        onActiveFocusChanged: {
            root.inspected(activeFocus || hot);
            if (activeFocus) root.workspace.reveal(this);
        }
        Column {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Style.space(12))
            spacing: Style.space(3)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.space(root.roomy ? 26 : 18)
                height: width
                visible: root.tile.kind === "app" && tileButton.height >= Style.space(54)
                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(root.tile.icon || "") ? Quickshell.iconPath(root.tile.icon, true) : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }
                MapText {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: root.label.slice(0, 1).toLocaleUpperCase()
                    color: root.tint
                    font.weight: Font.DemiBold
                }
            }
            MapText {
                width: parent.width
                visible: root.tile.kind === "other" || tileButton.width >= Style.space(65)
                text: root.label
                font.pixelSize: root.roomy ? Style.font.bodySmall : Style.font.caption
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            MapText {
                width: parent.width
                visible: root.roomy
                text: root.workspace.size(root.tile.bytes, root.tile.partial)
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.78)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
