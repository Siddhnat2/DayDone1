import QtQuick

Rectangle {
    id: b
    property string text: ""
    property string kind: "primary"      // primary | secondary | danger
    property string iconName: ""
    signal clicked()

    implicitHeight: 50
    radius: 14
    color: kind === "primary" ? (area.pressed ? Theme.accentDark : Theme.accent)
         : kind === "danger" ? (area.pressed ? "#D9485E" : "#E5566B")
         : (area.pressed ? Theme.border : Theme.field)
    border.width: kind === "secondary" ? 1 : 0
    border.color: Theme.border
    scale: area.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    Row {
        anchors.centerIn: parent
        spacing: 8
        Glyph { visible: b.iconName !== ""; name: b.iconName; size: 18; color: "white"; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: b.text
            color: "#FFFFFF"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: b.clicked() }
}
