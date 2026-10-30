import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
    id: root

    required property var workspace
    property bool active: false
    property bool inView: false

    readonly property real padding: Style.space(20)

    implicitWidth: Style.space(320)
    // Only the logo animates; the card and text keep their geometry.
    implicitHeight: content.implicitHeight + padding * 2
    Accessible.role: Accessible.Grouping
    Accessible.name: workspace.strings.t("preferences.about")


    Rectangle {
        id: card
        anchors.fill: parent
        radius: Math.max(Style.cornerRadius, Style.space(8))
        color: Util.alpha(Color.popups.text, 0.045)

        ColumnLayout {
            id: content
            x: root.padding
            y: root.padding
            width: Math.max(0, parent.width - root.padding * 2)
            spacing: Style.space(8)

            MosaicAnimatedMark {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Style.space(28)
                Layout.preferredHeight: Style.space(28)
                Layout.bottomMargin: Style.space(2)
                foreground: root.workspace.heroColor
                centerColor: Color.popups.text
                presented: root.active && root.inView
                motionEnabled: root.workspace.motionEnabled
            }

            MapText {
                Layout.fillWidth: true
                text: root.workspace.strings.t("app.name")
                font.pixelSize: Style.font.heading
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Rectangle {
                id: versionBadge
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: content.width
                implicitWidth: versionText.implicitWidth + Style.space(14)
                implicitHeight: versionText.implicitHeight + Style.space(6)
                radius: Math.max(Style.cornerRadius, Style.space(3))
                color: Util.alpha(root.workspace.heroColor, 0.08)
                border.width: 1
                border.color: Util.alpha(root.workspace.heroColor, 0.4)

                MapText {
                    id: versionText
                    x: Style.space(7)
                    y: Style.space(3)
                    width: Math.max(0, parent.width - Style.space(14))
                    text: root.workspace.service && root.workspace.service.manifest && root.workspace.service.manifest.version
                        ? root.workspace.strings.t("preferences.version").arg(root.workspace.service.manifest.version)
                        : root.workspace.strings.t("preferences.versionUnavailable")
                    font.pixelSize: Style.font.caption
                    font.weight: Font.Medium
                    color: root.workspace.heroColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }

            MapText {
                Layout.fillWidth: true
                text: root.workspace.strings.t("about.tagline")
                font.pixelSize: Style.font.bodySmall
                color: Util.alpha(Color.popups.text, 0.76)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            MapText {
                Layout.fillWidth: true
                text: root.workspace.strings.t("about.traits")
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.5)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
}
