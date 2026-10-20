import QtQuick

Item {
    id: root
    anchors.fill: parent
    visible: false
    z: 100
    property var confettiColors: ["#FF5C8A", "#FFC857", "#5CE1E6", "#7CFF6B", "#B388FF", "#FF8A5C"]

    function fire() {
        visible = true
        for (var i = 0; i < rep.count; i++) rep.itemAt(i).launch()
        hideTimer.restart()
    }

    Timer { id: hideTimer; interval: 5200; onTriggered: root.visible = false }

    Rectangle { anchors.fill: parent; color: "#D905070D" }
    MouseArea { anchors.fill: parent; onClicked: root.visible = false }

    Column {
        z: 5
        anchors.centerIn: parent
        spacing: 12
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🎉"; font.pixelSize: 88 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "All done for today!"; color: "#FFFFFF"; font.pixelSize: 30; font.weight: Font.Bold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width - 80
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Congratulations — you completed every task. Enjoy the rest of your day."
            color: Theme.textSecondary; font.pixelSize: 16
        }
        Item { width: 1; height: 8 }
        AppButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200
            text: "Continue"
            onClicked: root.visible = false
        }
    }

    Repeater {
        id: rep
        model: 110
        Rectangle {
            id: p
            property bool fromLeft: index % 2 === 0
            property real tx: 0
            property real peak: 0
            width: 6 + Math.random() * 8
            height: width * 1.6
            radius: 2
            color: root.confettiColors[index % root.confettiColors.length]
            x: fromLeft ? 0 : root.width
            y: root.height

            function launch() {
                anim.stop()
                x = fromLeft ? 0 : root.width
                y = root.height
                rotation = 0
                tx = fromLeft ? Math.random() * root.width * 0.9 : root.width - Math.random() * root.width * 0.9
                peak = root.height * (0.08 + Math.random() * 0.5)
                anim.start()
            }

            ParallelAnimation {
                id: anim
                NumberAnimation { target: p; property: "x"; to: p.tx; duration: 2800; easing.type: Easing.OutQuad }
                NumberAnimation { target: p; property: "rotation"; to: (Math.random() - 0.5) * 1440; duration: 2800 }
                SequentialAnimation {
                    NumberAnimation { target: p; property: "y"; to: p.peak; duration: 900; easing.type: Easing.OutQuad }
                    NumberAnimation { target: p; property: "y"; to: root.height + 40; duration: 1900; easing.type: Easing.InQuad }
                }
            }
        }
    }
}
