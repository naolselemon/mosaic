import QtQuick
import qs.Commons

Text {
    textFormat: Text.PlainText
    // Explicit alignment also mirrors text using the English fallback.
    horizontalAlignment: Text.AlignLeft
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    renderType: Text.QtRendering
}
