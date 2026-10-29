import QtQuick
import QtQuick.Shapes
import qs.Commons

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
            PathSvg { path: "M0 0H42V20H20V42H0Z" }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: Util.alpha(root.foreground, 0.8)
            PathSvg { path: "M78 0H120V42H100V20H78Z" }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: Util.alpha(root.foreground, 0.8)
            PathSvg { path: "M0 78H20V100H42V120H0Z" }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.foreground
            PathSvg { path: "M100 78H120V120H78V100H100Z" }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.centerColor
            PathSvg { path: "M60 37L83 60L60 83L37 60Z" }
        }
    }
}
