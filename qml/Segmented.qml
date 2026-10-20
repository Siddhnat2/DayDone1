import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var options: []      // [{value, label, color?}]
    property var value
    signal picked(var v)
    implicitHeight: 46
    height: 46

    RowLayout {
        anchors.fill: parent
        spacing: 8
        Repeater {
            model: root.options
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                readonly property bool sel: modelData.value === root.value
                readonly property bool bright: modelData.color !== undefined
                color: sel ? (bright ? modelData.color : Theme.accent) : Theme.field
                border.width: 1
                border.color: sel ? "transparent" : Theme.border
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.sel ? (parent.bright ? Theme.onBright : "#FFFFFF") : Theme.textSecondary
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                MouseArea { anchors.fill: parent; onClicked: root.picked(modelData.value) }
            }
        }
    }
}
