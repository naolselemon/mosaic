import QtQuick
import qs.Commons
import "../lib/Icons.js" as Icons

MapIconButton {
    id: root
    property bool motionEnabled: true
    property bool brand: false
    iconText: brand ? "" : Icons.glyph(icon, I18n.rightToLeft)
    implicitWidth: Style.space(42)
    implicitHeight: Style.space(42)
    iconSize: Style.space(30)
    foreground: Color.accent
    Loader {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        active: root.brand
        sourceComponent: MosaicMark {
            foreground: root.foreground
            centerColor: Color.popups.text
        }
    }

    function play() {
        entrance.stop();
        if (motionEnabled && Style.duration(180) > 0) entrance.start();
        else rotation = 0;
    }
    onMotionEnabledChanged: if (!motionEnabled) {
        entrance.stop();
        rotation = 0;
    }
    NumberAnimation {
        id: entrance
        target: root
        property: "rotation"
        from: I18n.rightToLeft ? 10 : -10
        to: 0
        duration: Style.duration(180)
        easing.type: Easing.OutCubic
    }
}
