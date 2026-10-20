import QtQuick
import QtQuick.Controls.Basic

Column {
    id: root
    property string label: ""
    property string placeholder: ""
    property bool invalid: false
    property alias text: input.text
    property alias field: input
    spacing: 8

    SectionLabel { visible: root.label !== ""; text: root.label }

    Rectangle {
        width: parent.width
        height: 50
        radius: 14
        color: Theme.field
        border.width: 1.5
        border.color: root.invalid ? Theme.danger : (input.activeFocus ? Theme.accentHi : Theme.border)

        TextField {
            id: input
            anchors.fill: parent
            leftPadding: 16
            rightPadding: 16
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            placeholderText: root.placeholder
            placeholderTextColor: Theme.placeholder
            selectionColor: Theme.accent
            selectedTextColor: "#FFFFFF"
            font.pixelSize: 16
            background: null
            onTextChanged: if (text !== "") root.invalid = false
        }
    }
}
