import QtQuick
import qs.Commons
import "../lib/DonutGeometry.js" as Geometry

Item {
    id: root
    property var values: [0, 0, 0, 0]
    property var palette: [Color.accent, Color.foreground, Qt.tint(Color.accent, Util.alpha(Color.urgent, 0.7)), Color.urgent]
    property string caption: ""
    property string centerText: ""
    property var labels: []
    property var valueTexts: []
    property int emphasizedIndex: -1
    property bool presentationActive: true
    property bool motionEnabled: true
    readonly property int activeIndex: !presented ? -1 : validIndex(hoveredIndex)
        ? hoveredIndex : validIndex(emphasizedIndex) ? emphasizedIndex : -1
    readonly property color trackColor: Util.alpha(Color.popups.text, 0.08)
    readonly property var geometry: Geometry.build(values)
    readonly property bool presented: presentationActive && visible
    readonly property bool motionAllowed: motionEnabled && Style.duration(180) > 0
    readonly property real strokeWidth: Math.max(4, Math.min(width, height) * 0.105)
    readonly property real ringRadius: Math.max(0, Math.min(width, height) / 2 - strokeWidth / 2 - Style.space(4))
    property real openingTilt: 0
    property int hoveredIndex: -1
    property bool ready: false
    signal activated(int index)
    implicitWidth: Style.space(116)
    implicitHeight: implicitWidth

    Translations { id: strings; directory: Qt.resolvedUrl("../../i18n") }

    function validIndex(index) {
        return index >= 0 && index < geometry.segments.length;
    }

    function clearHover() {
        hoveredIndex = -1;
    }

    function enterPresentation() {
        entrance.stop();
        openingTilt = 0;
        if (ready && presented && motionAllowed) entrance.start();
    }

    function arcContains(index, x, y) {
        var arc = arcs.itemAt(index);
        if (!arc) return false;
        // Hit-test the same opening and hover transforms that are painted.
        var local = arc.mapFromItem(pointer, x, y);
        return Geometry.contains(arc.segment, local.x, local.y, arc.width / 2,
            arc.height / 2, ringRadius, strokeWidth);
    }

    function indexAt(x, y) {
        if (!presented) return -1;
        // The selected arc is painted above its neighbours.
        if (validIndex(activeIndex) && arcContains(activeIndex, x, y)) return activeIndex;
        for (var i = 0; i < geometry.segments.length; ++i)
            if (arcContains(i, x, y)) return i;
        return -1;
    }

    function updateHover(x, y) {
        hoveredIndex = indexAt(x, y);
    }

    onValuesChanged: clearHover()
    onLabelsChanged: clearHover()
    onValueTextsChanged: clearHover()
    onPresentedChanged: {
        clearHover();
        enterPresentation();
    }
    onMotionAllowedChanged: if (!motionAllowed) {
        entrance.stop();
        openingTilt = 0;
    }
    Component.onCompleted: {
        ready = true;
        enterPresentation();
    }

    NumberAnimation {
        id: entrance
        target: root
        property: "openingTilt"
        from: 18
        to: 0
        duration: Style.duration(220)
        easing.type: Easing.OutCubic
    }

    Item {
        id: ring
        anchors.fill: parent
        transform: Rotation {
            origin.x: ring.width / 2
            origin.y: ring.height / 2
            axis.x: 1; axis.y: 0; axis.z: 0
            angle: root.openingTilt
        }
        Canvas {
            id: trackCanvas
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root
                function onTrackColorChanged() { trackCanvas.requestPaint(); }
                function onRingRadiusChanged() { trackCanvas.requestPaint(); }
                function onStrokeWidthChanged() { trackCanvas.requestPaint(); }
            }
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                if (root.ringRadius <= 0) return;
                ctx.lineWidth = root.strokeWidth;
                ctx.strokeStyle = root.trackColor;
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, root.ringRadius, 0, Math.PI * 2);
                ctx.stroke();
            }
        }
        Repeater {
            id: arcs
            model: root.geometry.segments.length
            delegate: Item {
                id: arcItem
                required property int index
                readonly property var segment: root.geometry.segments[index]
                readonly property color arcColor: root.palette[index] || Color.accent
                readonly property bool selected: root.activeIndex === index
                property real emphasis: selected ? 1 : 0
                width: ring.width
                height: ring.height
                z: selected ? 1 : 0
                opacity: root.activeIndex < 0 || selected ? 1 : 0.48
                transform: Rotation {
                    origin.x: arcItem.width / 2 + Math.cos(arcItem.segment.middle) * root.ringRadius
                    origin.y: arcItem.height / 2 + Math.sin(arcItem.segment.middle) * root.ringRadius
                    axis.x: 0; axis.y: 1; axis.z: 0
                    angle: root.motionAllowed ? arcItem.emphasis * 14 : 0
                }
                Behavior on emphasis {
                    NumberAnimation {
                        id: turnAnimation
                        duration: root.motionAllowed ? Style.duration(arcItem.selected ? 180 : 120) : 0
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        id: fadeAnimation
                        duration: root.motionAllowed ? Style.duration(120) : 0
                        easing.type: Easing.OutCubic
                    }
                }
                Connections {
                    target: root
                    function onMotionAllowedChanged() {
                        if (!root.motionAllowed) {
                            turnAnimation.complete();
                            fadeAnimation.complete();
                        }
                    }
                }
                // Rasterize only data/size/theme changes; hover rotates scenegraph nodes.
                Canvas {
                    id: arcCanvas
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Connections {
                        target: arcItem
                        function onSegmentChanged() { arcCanvas.requestPaint(); }
                        function onArcColorChanged() { arcCanvas.requestPaint(); }
                    }
                    Connections {
                        target: root
                        function onRingRadiusChanged() { arcCanvas.requestPaint(); }
                        function onStrokeWidthChanged() { arcCanvas.requestPaint(); }
                    }
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (!arcItem.segment.drawable || root.ringRadius <= 0) return;
                        ctx.lineWidth = root.strokeWidth;
                        ctx.lineCap = "butt";
                        ctx.strokeStyle = arcItem.arcColor;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, root.ringRadius,
                            arcItem.segment.start, arcItem.segment.end);
                        ctx.stroke();
                    }
                }
            }
        }
    }

    MouseArea {
        id: pointer
        property int pressedIndex: -1
        anchors.fill: parent
        enabled: root.presented
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.hoveredIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: root.updateHover(mouseX, mouseY)
        onPositionChanged: function(mouse) { root.updateHover(mouse.x, mouse.y); }
        onPressed: function(mouse) { pressedIndex = root.indexAt(mouse.x, mouse.y); }
        onClicked: function(mouse) {
            var index = root.indexAt(mouse.x, mouse.y);
            if (index >= 0 && index === pressedIndex) root.activated(index);
            pressedIndex = -1;
        }
        onExited: root.clearHover()
        onCanceled: { pressedIndex = -1; root.clearHover(); }
    }

    // This sibling of the ring never tilts or changes the component's footprint.
    Column {
        anchors.centerIn: parent
        width: Math.max(0, (root.ringRadius - root.strokeWidth / 2) * 1.8)
        spacing: Style.space(1)
        MapText {
            width: parent.width
            text: root.activeIndex >= 0 ? root.labels[root.activeIndex] || "" : root.centerText
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: root.activeIndex >= 0 ? Style.font.bodySmall : Style.font.body
            fontSizeMode: Text.Fit
            minimumPixelSize: Style.font.caption
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        MapText {
            width: parent.width
            text: root.activeIndex >= 0 ? root.valueTexts[root.activeIndex] || "" : root.caption
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.74)
            elide: Text.ElideRight
        }
        MapText {
            width: parent.width
            visible: root.activeIndex >= 0
            text: root.activeIndex < 0 || root.geometry.shares[root.activeIndex] === null
                ? strings.t("donut.shareUnavailable")
                : strings.t("donut.measuredShare").arg(I18n.formatNumber(root.geometry.shares[root.activeIndex] * 100, 1))
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.58)
            fontSizeMode: Text.Fit
            minimumPixelSize: Style.font.caption * 0.85
            elide: Text.ElideRight
        }
    }
}
