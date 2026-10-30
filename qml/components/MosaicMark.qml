import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../lib/MosaicGeometry.js" as Geometry

Item {
    id: root
    property color foreground: Color.accent
    property color centerColor: foreground
    implicitWidth: 120
    implicitHeight: 120
    Accessible.ignored: true

    Shape {
        width: 120
        height: 120
        x: (root.width - width * scale) / 2
        y: (root.height - height * scale) / 2
        scale: Math.min(root.width, root.height) / 120
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: root.foreground
            PathSvg { path: Geometry.facets[0].path }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: Util.alpha(root.foreground, 0.8)
            PathSvg { path: Geometry.facets[1].path }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: Util.alpha(root.foreground, 0.8)
            PathSvg { path: Geometry.facets[2].path }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.foreground
            PathSvg { path: Geometry.facets[3].path }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.centerColor
            PathSvg { path: Geometry.center }
        }
    }
}
