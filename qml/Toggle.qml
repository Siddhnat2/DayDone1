import QtQuick

Rectangle {
    id: t
    property bool checked: false
    signal toggled(bool value)
    width: 54
    height: 32
    radius: 16
    color: checked ? Theme.accent : Theme.border
    Behavior on color { ColorAnimation { duration: 140 } }
    Rectangle {
        width: 26; height: 26; radius: 13
        y: 3
        x: t.checked ? parent.width - width - 3 : 3
        color: "#FFFFFF"
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; onClicked: t.toggled(!t.checked) }
}
