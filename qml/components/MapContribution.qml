import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

Rectangle {
    id: root
    required property var workspace
    property string failedKey: ""
    readonly property var links: [
        { key: "bug", icon: "bug", url: "https://github.com/naolselemon/mosaic/issues/new?title=%5BBug%5D%20" },
        { key: "idea", icon: "idea", url: "https://github.com/naolselemon/mosaic/issues/new?title=%5BIdea%5D%20" },
        { key: "code", icon: "contribute", url: "https://github.com/naolselemon/mosaic" },
        { key: "star", icon: "star", url: "https://github.com/naolselemon/mosaic" }
    ]

    Layout.fillWidth: true
    implicitWidth: Style.space(320)
    implicitHeight: content.implicitHeight + Style.space(24)
    radius: Math.max(Style.cornerRadius, Style.space(8))
    color: Util.alpha(workspace.heroColor, 0.045)
    border.width: Math.max(1, Style.normalBorderWidth)
    border.color: Util.alpha(workspace.heroColor, 0.3)

    ColumnLayout {
        id: content
        x: Style.space(10)
        y: Style.space(12)
        width: Math.max(0, root.width - Style.space(20))
        spacing: Style.space(4)

        MapText {
            Layout.fillWidth: true
            Layout.leftMargin: Style.space(4)
            Layout.rightMargin: Style.space(4)
            Layout.bottomMargin: Style.space(3)
            text: root.workspace.strings.t("contribution.title")
            font.pixelSize: Style.font.caption
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Style.space(1.5)
            font.weight: Font.DemiBold
            color: root.workspace.heroColor
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.links

            Ui.Button {
                id: linkButton
                required property var modelData
                readonly property string linkTitle: root.workspace.strings.t("contribution." + modelData.key)
                readonly property string linkHint: root.workspace.strings.t("contribution." + modelData.key + "Hint")
                readonly property bool openFailed: root.failedKey === modelData.key

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: Math.max(Style.space(42), linkContent.implicitHeight + Style.space(12))
                focusable: true
                foreground: Color.popups.text
                accent: root.workspace.heroColor
                tooltipText: root.workspace.strings.t("contribution.externalHint")
                Accessible.role: Accessible.Link
                Accessible.name: linkTitle
                Accessible.description: linkHint + "\n" + root.workspace.strings.t("contribution.externalHint")
                    + (openFailed ? "\n" + root.workspace.strings.t("contribution.openFailed") : "")
                Accessible.focusable: true
                Accessible.onPressAction: clicked()
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                onClicked: {
                    root.failedKey = Qt.openUrlExternally(modelData.url) ? "" : modelData.key;
                    if (openFailed) Qt.callLater(function () { root.workspace.reveal(linkButton); });
                }

                RowLayout {
                    id: linkContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(4)
                    anchors.rightMargin: Style.space(4)
                    spacing: Style.space(9)

                    MapGlyph {
                        Layout.preferredWidth: Style.space(16)
                        Layout.alignment: Qt.AlignVCenter
                        icon: linkButton.modelData.icon
                        font.pixelSize: Style.font.bodySmall
                        color: root.workspace.heroColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: Style.space(2)

                        MapText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: linkButton.linkTitle
                            font.pixelSize: Style.font.bodySmall
                            color: Qt.tint(Color.popups.text, Util.alpha(root.workspace.heroColor, 0.3))
                            wrapMode: Text.Wrap
                            Accessible.ignored: true
                        }
                        MapText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: linkButton.linkHint
                            font.pixelSize: Style.font.caption
                            color: Util.alpha(Color.popups.text, 0.6)
                            wrapMode: Text.Wrap
                            Accessible.ignored: true
                        }
                        MapText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            visible: linkButton.openFailed
                            text: root.workspace.strings.t("contribution.openFailed")
                            font.pixelSize: Style.font.caption
                            color: Color.urgent
                            wrapMode: Text.Wrap
                        }
                    }

                    MapGlyph {
                        Layout.preferredWidth: Style.space(16)
                        Layout.alignment: Qt.AlignVCenter
                        icon: "external"
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(root.workspace.heroColor, 0.7)
                    }
                }
            }
        }
    }
}
