import QtQuick

Rectangle {
    id: card
    property int taskId: -1
    property string title: ""
    property string notes: ""
    property string time: ""
    property int priority: 2
    property string kind: "daily"
    property bool done: false
    property bool overdue: false
    signal toggled()
    signal removeRequested()

    readonly property color metaColor: overdue ? Theme.danger : Theme.textSecondary
    implicitHeight: Math.max(76, info.implicitHeight + 32)
    height: implicitHeight
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: overdue ? Qt.alpha(Theme.danger, 0.6) : Theme.border

    Rectangle {
        x: 0; width: 5; height: parent.height - 32; radius: 2.5
        anchors.verticalCenter: parent.verticalCenter
        color: done ? Theme.border : Theme.priorityColor(priority)
    }

    Rectangle {
        id: box
        x: 22
        anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 30; radius: 15
        color: card.done ? Theme.success : "transparent"
        border.width: 2
        border.color: card.done ? Theme.success : Theme.textMuted
        Behavior on color { ColorAnimation { duration: 140 } }
        Glyph {
            anchors.centerIn: parent
            name: "check"; size: 18; stroke: 2.8
            color: Theme.onBright
            opacity: card.done ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: card.toggled() }
    }

    Column {
        id: info
        anchors.left: box.right; anchors.leftMargin: 14
        anchors.right: del.left; anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            width: parent.width
            text: card.title
            color: card.done ? Theme.textMuted : Theme.text
            font.pixelSize: 16
            font.weight: Font.DemiBold
            font.strikeout: card.done
            elide: Text.ElideRight
        }
        Row {
            spacing: 6
            Glyph { name: "clock"; size: 14; color: card.metaColor; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: card.time === "" ? "Anytime" : card.time
                color: card.metaColor; font.pixelSize: 13
                font.weight: card.overdue ? Font.Bold : Font.Normal
                anchors.verticalCenter: parent.verticalCenter
            }
            Text { text: "•"; color: Theme.textMuted; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: card.kind === "daily" ? "Daily" : (card.kind === "weekly" ? "Weekly" : "One-time")
                color: Theme.textSecondary; font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                visible: card.overdue || (card.priority === 3 && !card.done)
                height: 20; width: pillTxt.width + 14; radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Theme.danger, 0.18)
                Text {
                    id: pillTxt; anchors.centerIn: parent
                    text: card.overdue ? "Overdue" : "Important"
                    color: Theme.danger; font.pixelSize: 11; font.weight: Font.Bold
                }
            }
        }
        Text {
            visible: card.notes !== ""
            width: parent.width
            text: card.notes
            color: Theme.textMuted
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    Item {
        id: del
        width: 46; height: 46
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        Glyph { anchors.centerIn: parent; name: "trash"; size: 20; color: Theme.textMuted }
        MouseArea { anchors.fill: parent; onClicked: card.removeRequested() }
    }
}
