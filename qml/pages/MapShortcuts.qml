import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../components"

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: false
    readonly property var groups: [
        {title: "everywhere", rows: [
            {keys: "Esc", action: "back"}, {keys: "Tab / Shift+Tab", action: "actions"},
            {keys: "Ctrl+R", action: "refresh"}, {keys: "?", action: "help"}]},
        {title: "apps", rows: [
            {keys: "Ctrl+F / /", action: "search"}, {keys: "↑ / ↓", action: "select"},
            {keys: "Enter", action: "open"}, {keys: "H / Ctrl+H", action: "dashboard"},
            {keys: "PgUp / PgDn", action: "page"}]},
        {title: "folders", rows: [
            {keys: "↑ / ↓", action: "location"},
            {keys: "Enter", action: "breakdown"}, {keys: "Ctrl+D", action: "deep"},
            {keys: "O", action: "folder"}, {keys: "Ctrl+C", action: "copy"},
            {keys: "PgUp / PgDn", action: "scroll"}]},
        {title: "workspace", rows: [
            {keys: "↑ / ↓", action: "scroll"}, {keys: "PgUp / PgDn", action: "page"},
            {keys: "Home / End", action: "ends"}, {keys: "H / Ctrl+H", action: "back"},
            {keys: I18n.rightToLeft ? "Alt+→ / ⌫" : "Alt+← / ⌫", action: "back"}]}
    ]
    spacing: Style.space(8)

    Repeater {
        model: root.groups
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: group.implicitHeight + Style.space(20)
            radius: Style.cornerRadius
            color: Util.alpha(Color.popups.text, 0.035)
            ColumnLayout {
                id: group
                x: Style.space(10)
                y: Style.space(10)
                width: parent.width - Style.space(20)
                spacing: Style.space(9)
                MapText {
                    text: root.workspace.strings.t("keys.group." + modelData.title)
                    font.pixelSize: Style.font.caption
                    font.weight: Font.DemiBold
                    color: root.workspace.insightColor
                }
                Repeater {
                    model: modelData.rows
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Style.space(8)
                        MapText {
                            Layout.fillWidth: true
                            text: root.workspace.strings.t("keys.action." + modelData.action)
                            font.pixelSize: Style.font.bodySmall
                            wrapMode: Text.Wrap
                        }
                        Rectangle {
                            implicitWidth: keyText.implicitWidth + Style.space(10)
                            implicitHeight: keyText.implicitHeight + Style.space(6)
                            color: Util.alpha(Color.popups.text, 0.055)
                            border.color: Util.alpha(Color.popups.text, 0.08)
                            radius: Math.min(Style.cornerRadius, Style.space(3))
                            MapText {
                                id: keyText
                                anchors.centerIn: parent
                                text: modelData.keys
                                font.pixelSize: Style.font.caption
                                LayoutMirroring.enabled: false
                            }
                        }
                    }
                }
            }
        }
    }
}
