import QtQuick

// [-]  09  [+]   — hold a button to repeat.
Item {
    id: root
    property int value: 0
    property int from: 0
    property int to: 23
    property int step: 1
    property string caption: ""
    implicitWidth: btnRow.width
    width: implicitWidth
    implicitHeight: 64
    height: 64

    property int _dir: 1
    function bump(d) {
        var v = value + d * step
        if (v > to) v = from
        else if (v < from) v = to
        value = v
    }
    Timer { id: hold; interval: 420; onTriggered: rep.start() }
    Timer { id: rep; interval: 110; repeat: true; onTriggered: root.bump(root._dir) }

    Row {
        id: btnRow
        anchors.centerIn: parent
        spacing: 6
        Repeater {
            model: [-1, 0, 1]
            Item {
                width: modelData === 0 ? 48 : 38
                height: 52
                Rectangle {
                    visible: modelData !== 0
                    anchors.fill: parent
                    radius: 12
                    color: ma.pressed ? Theme.border : Theme.surfaceHi
                    Glyph { anchors.centerIn: parent; name: modelData < 0 ? "close" : "plus"; size: 18; color: "white"; visible: modelData > 0 }
                    Rectangle { visible: modelData < 0; anchors.centerIn: parent; width: 14; height: 2.4; radius: 1.2; color: "white" }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        onPressed: { root._dir = modelData; root.bump(modelData); hold.restart() }
                        onReleased: { hold.stop(); rep.stop() }
                        onCanceled: { hold.stop(); rep.stop() }
                    }
                }
                Column {
                    visible: modelData === 0
                    anchors.centerIn: parent
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ("0" + root.value).slice(-2)
                        color: Theme.text
                        font.pixelSize: 30
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
