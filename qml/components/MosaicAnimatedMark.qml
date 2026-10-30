import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../lib/MosaicGeometry.js" as Geometry

Item {
    id: root
    property color foreground: Color.accent
    property color centerColor: foreground
    property bool presented: false
    property bool motionEnabled: true
    readonly property bool motionAllowed: motionEnabled && Style.duration(240) > 0
    readonly property bool running: choreography.running
    property bool ready: false
    property real phase: 3
    readonly property real lift: bounded(phase)
    readonly property real unfold: bounded(phase - 1)
    readonly property real assembly: bounded(phase - 2)
    readonly property real direction: I18n.rightToLeft ? -1 : 1
    implicitWidth: 120
    implicitHeight: 120
    Accessible.ignored: true

    function bounded(value) { return Math.max(0, Math.min(1, value)); }
    function settle() {
        choreography.stop();
        phase = 3;
    }
    function play() {
        settle();
        if (ready && presented && motionAllowed) choreography.start();
    }
    onPresentedChanged: {
        if (!ready) return;
        if (presented) play();
        else settle();
    }
    onMotionAllowedChanged: if (!motionAllowed) settle()
    Component.onCompleted: {
        ready = true;
        if (presented) play();
    }

    HoverHandler {
        blocking: false
        onHoveredChanged: if (hovered && !root.running) root.play()
    }

    // Three deliberate beats: separate the shutters, unfold them, then assemble.
    // Only the mark moves; its layout slot and the surrounding UI never transform.
    SequentialAnimation {
        id: choreography
        NumberAnimation { target: root; property: "phase"; from: 0; to: 1; duration: Style.duration(240); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "phase"; from: 1; to: 2; duration: Style.duration(260); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "phase"; from: 2; to: 3; duration: Style.duration(260); easing.type: Easing.OutCubic }
    }

    Item {
        id: drawing
        width: 120
        height: 120
        scale: Math.min(root.width, root.height) / 120
        x: (root.width - width * scale) / 2
        y: (root.height - height * scale) / 2
        transformOrigin: Item.TopLeft

        Repeater {
            model: Geometry.facets
            Item {
                id: facet
                required property var modelData
                readonly property int order: I18n.rightToLeft ? modelData.rtlOrder : modelData.order
                readonly property real opened: root.bounded((root.unfold - order * 0.12) / 0.64)
                readonly property real closed: root.bounded((root.assembly - order * 0.1) / 0.7)
                readonly property real spread: root.lift * (1 - closed)
                readonly property real fold: root.lift * (1 - opened)
                width: 120
                height: 120
                x: modelData.sx * 12 * spread
                y: modelData.sy * 12 * spread
                transform: [
                    Rotation {
                        origin.x: facet.modelData.x
                        origin.y: facet.modelData.y
                        axis.x: 1; axis.y: 0; axis.z: 0
                        angle: facet.modelData.sy * 18 * facet.fold
                    },
                    Rotation {
                        origin.x: facet.modelData.x
                        origin.y: facet.modelData.y
                        axis.x: 0; axis.y: 1; axis.z: 0
                        angle: facet.modelData.sx * 68 * facet.fold
                    },
                    Rotation {
                        origin.x: facet.modelData.x
                        origin.y: facet.modelData.y
                        axis.x: 0; axis.y: 0; axis.z: 1
                        angle: root.direction * facet.modelData.sx * facet.modelData.sy * 8 * facet.spread
                    }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1
                        fillColor: Qt.tint(Util.alpha(root.foreground, facet.modelData.tone), Util.alpha(root.centerColor, 0.16 * facet.fold))
                        PathSvg { path: facet.modelData.path }
                    }
                }
            }
        }

        Shape {
            width: 120
            height: 120
            transform: [
                Rotation {
                    origin.x: 60; origin.y: 60
                    axis.x: 0; axis.y: 0; axis.z: 1
                    angle: root.direction * (45 * root.lift + 90 * root.unfold + 45 * root.assembly)
                },
                Rotation {
                    origin.x: 60; origin.y: 60
                    axis.x: 0; axis.y: 1; axis.z: 0
                    angle: -root.direction * 24 * root.lift * (1 - root.assembly)
                }
            ]
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.tint(root.centerColor, Util.alpha(root.foreground, 0.35 * root.lift * (1 - root.assembly)))
                PathSvg { path: Geometry.center }
            }
        }
    }
}
