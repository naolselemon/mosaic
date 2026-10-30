import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

Item {
    id: root
    required property var workspace
    required property string label
    property string icon: ""
    property string description: ""
    property color accent: Color.accent
    property bool checked: false
    signal clicked()

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: Math.max(Style.space(38), labelText.implicitHeight + Style.space(16))
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.description: description
    Accessible.checked: checked
    Accessible.focusable: enabled
    Accessible.onToggleAction: if (enabled) clicked()
    Accessible.onPressAction: if (enabled) clicked()
    onActiveFocusChanged: if (activeFocus) workspace.reveal(root)
    Keys.onSpacePressed: event => { if (enabled) clicked(); event.accepted = true; }
    Keys.onReturnPressed: event => { if (enabled) clicked(); event.accepted = true; }
    Keys.onEnterPressed: event => { if (enabled) clicked(); event.accepted = true; }

    Ui.BorderSurface {
        anchors.fill: parent
        radius: Style.space(8)
        color: mouse.pressed ? Style.pressedFillFor(Color.popups.text, Color.accent)
            : root.activeFocus ? Style.focusFillFor(Color.popups.text, Color.accent)
            : mouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
        borderSpec: root.activeFocus ? Border.controlSpec("focus", Color.popups.text, Color.accent)
            : mouse.containsMouse ? Border.controlSpec("hover-cursor", Color.popups.text, Color.accent) : Border.none()
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(root.icon !== "" ? 4 : 8)
        anchors.rightMargin: Style.space(root.icon !== "" ? 4 : 8)
        spacing: Style.space(10)
        MapPreferenceLabel {
            id: labelText
            Layout.fillWidth: true
            icon: root.icon
            label: root.label
            description: root.description
            accent: root.accent
            Accessible.ignored: true
        }
        // Ui.ToggleSwitch's pill geometry and native state tokens, with the
        // workspace motion preference applied as well as the shell's setting.
        Ui.BorderSurface {
            id: track
            Layout.preferredWidth: Math.round(trackHeight * 1.9)
            Layout.preferredHeight: trackHeight
            property int trackHeight: Math.max(18, Style.space(18))
            readonly property int knobSize: Math.round(trackHeight * 0.72)
            readonly property int knobInset: Math.round((trackHeight - knobSize) / 2)
            radius: height / 2
            color: root.checked ? Style.selectedFillFor(Color.popups.text, Color.accent)
                : Style.normalFillFor(Color.popups.text, Color.accent)
            borderSpec: Border.controlSpec(root.checked ? "selected" : "normal", Color.popups.text, Color.accent)
            Behavior on color {
                ColorAnimation { duration: root.workspace.motionEnabled ? Style.duration(120) : 0 }
            }
            Rectangle {
                width: track.knobSize
                height: width
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked !== root.LayoutMirroring.enabled ? track.width - width - track.knobInset : track.knobInset
                color: root.checked ? Style.selectedStateColor(Color.popups.text, Color.accent) : Qt.darker(Color.popups.text, 1.25)
                Behavior on x {
                    NumberAnimation {
                        duration: root.workspace.motionEnabled ? Style.duration(120) : 0
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation { duration: root.workspace.motionEnabled ? Style.duration(120) : 0 }
                }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.forceActiveFocus(); root.clicked(); }
    }
}
