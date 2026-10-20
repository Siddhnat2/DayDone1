import QtQuick

Rectangle {
    id: tile
    property string label: ""
    property string value: "0"
    property color tint: Theme.accentHi
    property string iconName: "check"
    implicitHeight: 108
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    Rectangle {
        x: 14; y: 14; width: 30; height: 30; radius: 15
        color: Qt.alpha(tile.tint, 0.18)
        Glyph { anchors.centerIn: parent; name: tile.iconName; size: 16; color: tile.tint }
    }
    Text { x: 14; y: 48; text: tile.value; color: Theme.text; font.pixelSize: 24; font.weight: Font.Bold }
    Text { x: 14; y: 82; text: tile.label; color: Theme.textSecondary; font.pixelSize: 12 }
}
