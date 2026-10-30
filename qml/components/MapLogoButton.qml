import QtQuick
import qs.Commons
import "../lib/Icons.js" as Icons

MapIconButton {
    id: root
    property bool motionEnabled: true
    property bool brand: false
    property bool presented: false
    property bool ready: false
    readonly property bool motionAllowed: motionEnabled && Style.duration(280) > 0
    iconText: brand ? "" : Icons.glyph(icon, I18n.rightToLeft)
    implicitWidth: Style.space(42)
    implicitHeight: Style.space(42)
    iconSize: Style.space(30)
    foreground: Color.accent
    Loader {
        id: brandMark
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        active: root.brand
        sourceComponent: MosaicAnimatedMark {
            foreground: root.foreground
            centerColor: Color.popups.text
            presented: root.presented
            motionEnabled: root.motionEnabled
        }
    }

    function settle() {
        entrance.stop();
        iconRotation = 0;
    }
    function play() {
        if (ready && !brand && presented && motionAllowed && !entrance.running)
            entrance.start();
    }
    onPresentedChanged: {
        if (!ready) return;
        if (presented) play();
        else settle();
    }
    onMotionAllowedChanged: if (!motionAllowed) settle()
    onHovered: function(hovered) { if (hovered) play(); }
    Component.onCompleted: {
        ready = true;
        if (presented) play();
    }
    NumberAnimation {
        id: entrance
        target: root
        property: "iconRotation"
        from: I18n.rightToLeft ? 360 : -360
        to: 0
        duration: Style.duration(280)
        easing.type: Easing.OutCubic
    }
}
