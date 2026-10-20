import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ApplicationWindow {
    id: win
    visible: true
    width: 420
    height: 860
    minimumWidth: 320
    minimumHeight: 560
    title: "DayDone"
    color: Theme.bg

    // Make every stock control readable on the dark theme.
    palette.window: Theme.bg
    palette.windowText: Theme.text
    palette.text: Theme.text
    palette.base: Theme.field
    palette.button: Theme.surfaceHi
    palette.buttonText: Theme.text
    palette.highlight: Theme.accent
    palette.highlightedText: "#FFFFFF"
    palette.placeholderText: Theme.placeholder

    property string todayDay: backend.todayStr()
    property string selectedDay: todayDay
    property var todayStats: ({total: 0, done: 0, remaining: 0, percent: 0})
    property var selStats: ({total: 0, done: 0, remaining: 0, percent: 0})
    property var weekData: []
    property int streak: 0
    property int tab: 0
    property string nowHM: Qt.formatTime(new Date(), "hh:mm")

    ListModel { id: taskModel }

    function greeting() {
        var h = new Date().getHours()
        return h < 12 ? "Good morning" : (h < 17 ? "Good afternoon" : "Good evening")
    }
    function isoDate(offset) {
        var d = new Date(); d.setDate(d.getDate() + offset)
        return Qt.formatDate(d, "yyyy-MM-dd")
    }
    function refresh() {
        todayDay = backend.todayStr()
        taskModel.clear()
        var list = backend.tasksFor(selectedDay)
        for (var i = 0; i < list.length; i++) {
            var t = list[i]
            taskModel.append({tid: t.id, title: t.title, notes: t.notes, time: t.time,
                              priority: t.priority, kind: t.kind, done: t.done,
                              status: t.done ? "Done" : "Remaining"})
        }
        selStats = backend.stats(selectedDay)
        todayStats = backend.stats(todayDay)
        weekData = backend.weekStats(todayDay)
        streak = backend.streak()
    }
    function insight() {
        var best = null, tot = 0, dn = 0
        for (var i = 0; i < weekData.length; i++) {
            var w = weekData[i]
            if (w.future) continue
            tot += w.total; dn += w.done
            if (w.total > 0 && (best === null || w.percent > best.percent)) best = w
        }
        if (tot === 0) return "Add a few tasks and your weekly insights will show up here."
        return "You've completed " + dn + " of " + tot + " tasks this week. Best day so far: "
               + best.label + " (" + best.percent + "%)."
    }

    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: { nowHM = Qt.formatTime(new Date(), "hh:mm"); if (backend.todayStr() !== todayDay) refresh() }
    }
    Connections {
        target: backend
        function onChanged() { win.refresh() }
        function onCelebrate() { confetti.fire() }
        function onToast(msg) { toastText.text = msg; toast.opacity = 1; toastTimer.restart() }
    }
    Component.onCompleted: {
        refresh()
        if (backend.shouldCelebrateOnOpen()) openTimer.start()
    }
    Timer { id: openTimer; interval: 500; onTriggered: confetti.fire() }

    // ====================================================== SHELL
    Item {
        id: shell
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(win.width, 560)

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- header
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 90 + backend.topInset

                Column {
                    anchors.left: parent.left; anchors.leftMargin: 20
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                    spacing: 3
                    Text {
                        text: tab === 0 ? win.greeting() : "Your progress"
                        color: Theme.text; font.pixelSize: 27; font.weight: Font.Bold
                    }
                    Text {
                        text: Qt.formatDate(new Date(selectedDay + "T12:00:00"), "dddd, d MMMM")
                        color: Theme.textSecondary; font.pixelSize: 14
                    }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 20
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                    height: 36; width: streakRow.width + 26; radius: 18
                    color: Qt.alpha(Theme.warning, 0.14)
                    border.width: 1; border.color: Qt.alpha(Theme.warning, 0.45)
                    Row {
                        id: streakRow
                        anchors.centerIn: parent
                        spacing: 6
                        Glyph { name: "flame"; size: 16; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: streak + (streak === 1 ? " day" : " days")
                            color: Theme.warning; font.pixelSize: 14; font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ---------- pages
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tab

                // ================= TASKS
                ColumnLayout {
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 8
                        Repeater {
                            model: weekData
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                radius: 16
                                readonly property bool sel: modelData.day === selectedDay
                                readonly property bool full: modelData.total > 0 && modelData.done === modelData.total
                                color: sel ? Theme.accent : Theme.surface
                                border.width: 1
                                border.color: sel ? Theme.accentHi : (modelData.isToday ? Theme.accent : Theme.border)
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: parent.parent.sel ? "#F1EDFF" : Theme.textSecondary; font.pixelSize: 12 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.num; color: "#FFFFFF"; font.pixelSize: 19; font.weight: Font.Bold }
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 6; height: 6; radius: 3
                                        color: parent.parent.full ? (parent.parent.sel ? "#FFFFFF" : Theme.success)
                                             : (modelData.total > 0 ? Theme.textMuted : "transparent")
                                    }
                                }
                                MouseArea { anchors.fill: parent; onClicked: { selectedDay = modelData.day; refresh() } }
                            }
                        }
                    }

                    // progress card
                    Rectangle {
                        id: progCard
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        Layout.preferredHeight: 112
                        radius: 22
                        readonly property bool full: selStats.total > 0 && selStats.done === selStats.total
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: progCard.full ? "#0B7A56" : "#5636E6" }
                            GradientStop { position: 1; color: progCard.full ? "#13946C" : "#8B5CF6" }
                        }
                        Item {
                            anchors.fill: parent; anchors.margins: 18
                            Column {
                                anchors.left: parent.left; anchors.top: parent.top
                                spacing: 4
                                Text {
                                    text: selStats.total === 0 ? "Nothing planned" : (progCard.full ? "All tasks complete" : "Progress")
                                    color: "#EDE9FF"; font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                                Text {
                                    text: selStats.total === 0 ? "Add your first task" : selStats.done + " of " + selStats.total + " done"
                                    color: "#FFFFFF"; font.pixelSize: 22; font.weight: Font.Bold
                                }
                            }
                            Text {
                                anchors.right: parent.right; anchors.top: parent.top
                                text: selStats.percent + "%"
                                color: "#FFFFFF"; font.pixelSize: 34; font.weight: Font.Bold
                            }
                            Rectangle {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                height: 8; radius: 4; color: "#55FFFFFF"
                                Rectangle {
                                    height: parent.height; radius: 4; color: "#FFFFFF"
                                    width: parent.width * selStats.percent / 100
                                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        clip: true
                        spacing: 10
                        model: taskModel
                        bottomMargin: 110
                        boundsBehavior: Flickable.StopAtBounds
                        section.property: "status"
                        section.criteria: ViewSection.FullString
                        section.delegate: Item {
                            width: list.width; height: 36
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 4
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                                text: section === "Remaining" ? "REMAINING  ·  " + selStats.remaining
                                                              : "COMPLETED  ·  " + selStats.done
                                color: section === "Remaining" ? Theme.warning : Theme.success
                                font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.2
                            }
                        }
                        delegate: TaskCard {
                            width: list.width
                            taskId: model.tid
                            title: model.title
                            notes: model.notes
                            time: model.time
                            priority: model.priority
                            kind: model.kind
                            done: model.done
                            overdue: !model.done && model.time !== "" && selectedDay === todayDay && model.time <= nowHM
                            onToggled: backend.toggle(model.tid, selectedDay)
                            onRemoveRequested: { delConfirm.tid = model.tid; delConfirm.open() }
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: taskModel.count === 0
                            spacing: 10
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 84; height: 84; radius: 42; color: Theme.surface
                                border.width: 1; border.color: Theme.border
                                Glyph { anchors.centerIn: parent; name: "tasks"; size: 38; color: Theme.accentHi }
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No tasks for this day"; color: Theme.text; font.pixelSize: 18; font.weight: Font.DemiBold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Tap the + button to plan your day."; color: Theme.textSecondary; font.pixelSize: 14 }
                        }
                    }
                }

                // ================= DASHBOARD
                Flickable {
                    contentHeight: dash.height + 40
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: dash
                        x: 16; width: parent.width - 32
                        spacing: 14

                        Rectangle {
                            width: parent.width; height: 196; radius: 22
                            color: Theme.surface; border.width: 1; border.color: Theme.border
                            Row {
                                anchors.centerIn: parent
                                spacing: 22
                                Item {
                                    width: 138; height: 138
                                    Canvas {
                                        id: ring
                                        anchors.fill: parent
                                        property real pct: todayStats.percent
                                        onPctChanged: requestPaint()
                                        Component.onCompleted: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d"); ctx.reset()
                                            var cx = width / 2, cy = height / 2, r = 56
                                            ctx.lineWidth = 14; ctx.lineCap = "round"
                                            ctx.strokeStyle = "#2A3560"
                                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
                                            if (pct > 0) {
                                                ctx.strokeStyle = pct === 100 ? "#34D399" : "#9B86FF"
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * pct / 100)
                                                ctx.stroke()
                                            }
                                        }
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: todayStats.percent + "%"; color: "#FFFFFF"; font.pixelSize: 30; font.weight: Font.Bold }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "today"; color: Theme.textSecondary; font.pixelSize: 13 }
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Text { text: "Daily performance"; color: "#FFFFFF"; font.pixelSize: 16; font.weight: Font.Bold }
                                    Text {
                                        width: 130; wrapMode: Text.WordWrap
                                        text: todayStats.total === 0 ? "No tasks planned for today."
                                              : (todayStats.remaining === 0 ? "Everything is done. Great job!"
                                                 : todayStats.remaining + " more to go — you've got this.")
                                        color: Theme.textSecondary; font.pixelSize: 13
                                    }
                                }
                            }
                        }

                        RowLayout {
                            width: parent.width; spacing: 10
                            StatTile { Layout.fillWidth: true; label: "Completed"; value: todayStats.done; tint: Theme.success; iconName: "check" }
                            StatTile { Layout.fillWidth: true; label: "Remaining"; value: todayStats.remaining; tint: Theme.warning; iconName: "clock" }
                            StatTile { Layout.fillWidth: true; label: "Day streak"; value: streak; tint: Theme.accentHi; iconName: "flame" }
                        }

                        Rectangle {
                            width: parent.width; height: 282; radius: 22
                            color: Theme.surface; border.width: 1; border.color: Theme.border
                            Text { x: 20; y: 18; text: "Weekly performance"; color: "#FFFFFF"; font.pixelSize: 16; font.weight: Font.Bold }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 20; y: 20
                                text: { var t = 0, d = 0
                                        for (var i = 0; i < weekData.length; i++) { if (weekData[i].future) continue; t += weekData[i].total; d += weekData[i].done }
                                        return t ? Math.round(100 * d / t) + "% this week" : "No tasks yet" }
                                color: Theme.accentHi; font.pixelSize: 13; font.weight: Font.Bold
                            }
                            Row {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 20
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                                height: 200; spacing: 8
                                Repeater {
                                    model: weekData
                                    Item {
                                        width: (parent.width - 48) / 7; height: parent.height
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: bar.top; anchors.bottomMargin: 6
                                            text: (modelData.total > 0 && !modelData.future) ? modelData.percent + "%" : "–"
                                            color: Theme.textSecondary; font.pixelSize: 11
                                        }
                                        Rectangle {
                                            id: bar
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: lbl.top; anchors.bottomMargin: 8
                                            width: Math.min(parent.width * 0.75, 34)
                                            height: Math.max(6, (parent.height - 56) * (modelData.future ? 0 : modelData.percent) / 100)
                                            radius: 8
                                            color: modelData.percent === 100 ? Theme.success
                                                 : (modelData.percent === 0 ? Theme.border : (modelData.isToday ? Theme.accentHi : Theme.accent))
                                            Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                                        }
                                        Text {
                                            id: lbl
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            text: modelData.label
                                            color: modelData.isToday ? "#FFFFFF" : Theme.textSecondary
                                            font.pixelSize: 12; font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width; height: insightTxt.height + 36; radius: 22
                            color: Qt.alpha(Theme.accent, 0.16)
                            border.width: 1; border.color: Qt.alpha(Theme.accentHi, 0.5)
                            Text {
                                id: insightTxt
                                x: 18; y: 18; width: parent.width - 36
                                wrapMode: Text.WordWrap
                                text: win.insight()
                                color: "#EDE9FF"; font.pixelSize: 14; lineHeight: 1.2
                            }
                        }
                    }
                }
            }

            // ---------- bottom navigation
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 68 + backend.bottomInset
                color: Theme.surface
                Rectangle { width: parent.width; height: 1; color: Theme.border }
                Row {
                    width: parent.width; height: 68
                    Repeater {
                        model: [{icon: "tasks", label: "Tasks"}, {icon: "chart", label: "Dashboard"}]
                        Item {
                            width: parent.width / 2; height: 68
                            readonly property bool active: tab === index
                            Rectangle {
                                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                                width: 32; height: 3; radius: 1.5
                                color: parent.active ? Theme.accentHi : "transparent"
                            }
                            Column {
                                anchors.centerIn: parent; spacing: 4
                                Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: modelData.icon; size: 24; color: parent.parent.active ? Theme.accentHi : Theme.textMuted }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: parent.parent.active ? "#FFFFFF" : Theme.textMuted; font.pixelSize: 12; font.weight: parent.parent.active ? Font.Bold : Font.Normal }
                            }
                            MouseArea { anchors.fill: parent; onClicked: tab = index }
                        }
                    }
                }
            }
        }

        // ---------- floating add button
        Rectangle {
            visible: tab === 0
            width: 62; height: 62; radius: 31
            anchors.right: parent.right; anchors.rightMargin: 20
            anchors.bottom: parent.bottom; anchors.bottomMargin: 68 + backend.bottomInset + 18
            scale: fabArea.pressed ? 0.93 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            gradient: Gradient {
                GradientStop { position: 0; color: "#8B5CF6" }
                GradientStop { position: 1; color: "#5636E6" }
            }
            border.width: 1; border.color: "#B7A6FF"
            Glyph { anchors.centerIn: parent; name: "plus"; size: 28; stroke: 2.8; color: "#FFFFFF" }
            MouseArea { id: fabArea; anchors.fill: parent; onClicked: addPopup.open() }
        }
    }

    // ====================================================== TOAST
    Rectangle {
        id: toast
        opacity: 0
        z: 50
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16 + backend.topInset
        height: 46; width: Math.min(toastRow.width + 36, win.width - 32); radius: 23
        color: Theme.surfaceHi; border.width: 1; border.color: Theme.accentHi
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Row {
            id: toastRow
            anchors.centerIn: parent; spacing: 10
            Glyph { name: "bell"; size: 18; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
            Text { id: toastText; color: "#FFFFFF"; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        }
        Timer { id: toastTimer; interval: 4000; onTriggered: toast.opacity = 0 }
    }

    // ====================================================== DELETE CONFIRM
    Popup {
        id: delConfirm
        property int tid: -1
        parent: Overlay.overlay
        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(win.width - 48, 340)
        padding: 22
        Overlay.modal: Rectangle { color: "#CC05070D" }
        background: Rectangle { color: Theme.surface; radius: 24; border.width: 1; border.color: Theme.border }
        contentItem: Column {
            spacing: 14
            Text { text: "Delete this task?"; color: "#FFFFFF"; font.pixelSize: 19; font.weight: Font.Bold }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: "It will be removed from all days. This can't be undone."
                color: Theme.textSecondary; font.pixelSize: 14
            }
            Item { width: 1; height: 4 }
            Row {
                spacing: 12; width: parent.width
                AppButton { width: (parent.width - 12) / 2; text: "Cancel"; kind: "secondary"; onClicked: delConfirm.close() }
                AppButton { width: (parent.width - 12) / 2; text: "Delete"; kind: "danger"; onClicked: { backend.deleteTask(delConfirm.tid); delConfirm.close() } }
            }
        }
    }

    // ====================================================== ADD TASK SHEET
    Popup {
        id: addPopup
        objectName: "addPopup"
        parent: Overlay.overlay
        modal: true
        focus: true
        padding: 0
        property string kind: "daily"
        property int prio: 2
        property bool useTime: true
        readonly property real kb: Math.min(Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0, win.height * 0.5)

        width: Math.min(win.width - 24, 540)
        height: Math.min(sheetCol.height + 44, win.height - 24 - kb - backend.topInset)
        x: (win.width - width) / 2
        y: win.height - height - 12 - kb
        Behavior on y { NumberAnimation { duration: 160 } }

        Overlay.modal: Rectangle { color: "#CC05070D" }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
        background: Rectangle { color: Theme.surface; radius: 26; border.width: 1; border.color: Theme.border }

        function resetForm() {
            titleField.text = ""; notesField.text = ""
            titleField.invalid = false; errTxt.text = ""
            kind = "daily"; prio = 2; useTime = true
            hourStep.value = 9; minStep.value = 0
            dateField.text = win.selectedDay
            var idx = (new Date().getDay() + 6) % 7
            for (var i = 0; i < 7; i++) dayRep.itemAt(i).on = (i === idx)
            flick.contentY = 0
        }
        onAboutToShow: resetForm()

        contentItem: Flickable {
            id: flick
            clip: true
            contentHeight: sheetCol.height + 44
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: sheetCol
                x: 22; y: 22
                width: flick.width - 44
                spacing: 18

                Item {
                    width: parent.width; height: 34
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "New task"; color: "#FFFFFF"; font.pixelSize: 23; font.weight: Font.Bold }
                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36; radius: 18; color: Theme.field
                        Glyph { anchors.centerIn: parent; name: "close"; size: 16; color: "#FFFFFF" }
                        MouseArea { anchors.fill: parent; onClicked: addPopup.close() }
                    }
                }

                AppField { id: titleField; width: parent.width; label: "Title"; placeholder: "e.g. Morning workout" }
                AppField { id: notesField; width: parent.width; label: "Notes (optional)"; placeholder: "Add a short note" }

                Column {
                    width: parent.width; spacing: 8
                    SectionLabel { text: "Repeat" }
                    Segmented {
                        width: parent.width
                        value: addPopup.kind
                        options: [{value: "daily", label: "Daily"}, {value: "weekly", label: "Weekly"}, {value: "once", label: "One-time"}]
                        onPicked: function (v) { addPopup.kind = v }
                    }
                }

                Column {
                    visible: addPopup.kind === "weekly"
                    width: parent.width; spacing: 8
                    SectionLabel { text: "On these days" }
                    Row {
                        spacing: 8
                        Repeater {
                            id: dayRep
                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            Rectangle {
                                property bool on: false
                                width: (sheetCol.width - 6 * 8) / 7; height: 46; radius: 14
                                color: on ? Theme.accent : Theme.field
                                border.width: 1; border.color: on ? Theme.accentHi : Theme.border
                                Text { anchors.centerIn: parent; text: modelData.charAt(0); color: parent.on ? "#FFFFFF" : Theme.textSecondary; font.pixelSize: 15; font.weight: Font.Bold }
                                MouseArea { anchors.fill: parent; onClicked: parent.on = !parent.on }
                            }
                        }
                    }
                }

                Column {
                    visible: addPopup.kind === "once"
                    width: parent.width; spacing: 10
                    AppField { id: dateField; width: parent.width; label: "Date"; placeholder: "YYYY-MM-DD" }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{t: "Today", o: 0}, {t: "Tomorrow", o: 1}]
                            Rectangle {
                                height: 36; width: chipT.width + 28; radius: 18
                                color: Theme.field; border.width: 1; border.color: Theme.border
                                Text { id: chipT; anchors.centerIn: parent; text: modelData.t; color: "#FFFFFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                MouseArea { anchors.fill: parent; onClicked: dateField.text = win.isoDate(modelData.o) }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: timeCol.height + 36
                    radius: 18
                    color: Theme.field; border.width: 1; border.color: Theme.border
                    Column {
                        id: timeCol
                        x: 18; y: 18; width: parent.width - 36
                        spacing: 14
                        Item {
                            width: parent.width; height: 38
                            Column {
                                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Text { text: "Reminder time"; color: "#FFFFFF"; font.pixelSize: 16; font.weight: Font.DemiBold }
                                Text { text: addPopup.useTime ? "You'll be notified at this time" : "No time — shows as Anytime"; color: Theme.textSecondary; font.pixelSize: 12 }
                            }
                            Toggle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: addPopup.useTime; onToggled: function (v) { addPopup.useTime = v } }
                        }
                        Row {
                            visible: addPopup.useTime
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4
                            Stepper { id: hourStep; from: 0; to: 23; value: 9 }
                            Text { text: ":"; color: "#FFFFFF"; font.pixelSize: 30; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            Stepper { id: minStep; from: 0; to: 59; value: 0 }
                        }
                        Flow {
                            visible: addPopup.useTime
                            width: parent.width; spacing: 8
                            Repeater {
                                model: [{t: "Morning", h: 8}, {t: "Noon", h: 12}, {t: "Evening", h: 18}, {t: "Night", h: 21}]
                                Rectangle {
                                    height: 34; width: qt.width + 24; radius: 17
                                    color: Theme.surfaceHi; border.width: 1; border.color: Theme.border
                                    Text { id: qt; anchors.centerIn: parent; text: modelData.t + " " + modelData.h + ":00"; color: "#FFFFFF"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    MouseArea { anchors.fill: parent; onClicked: { hourStep.value = modelData.h; minStep.value = 0 } }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width; spacing: 8
                    SectionLabel { text: "Importance" }
                    Segmented {
                        width: parent.width
                        value: addPopup.prio
                        options: [{value: 1, label: "Low", color: Theme.success}, {value: 2, label: "Normal", color: Theme.warning}, {value: 3, label: "High", color: Theme.danger}]
                        onPicked: function (v) { addPopup.prio = v }
                    }
                }

                Text { id: errTxt; width: parent.width; wrapMode: Text.WordWrap; visible: text !== ""; color: Theme.danger; font.pixelSize: 14; font.weight: Font.DemiBold }

                Row {
                    width: parent.width; spacing: 12
                    AppButton { width: (parent.width - 12) * 0.36; text: "Cancel"; kind: "secondary"; onClicked: addPopup.close() }
                    AppButton {
                        width: (parent.width - 12) * 0.64
                        text: "Add task"; iconName: "plus"
                        onClicked: {
                            if (titleField.text.trim() === "") { titleField.invalid = true; errTxt.text = "Please enter a title."; return }
                            var days = []
                            for (var i = 0; i < 7; i++) if (dayRep.itemAt(i).on) days.push(i)
                            var tm = addPopup.useTime ? ("0" + hourStep.value).slice(-2) + ":" + ("0" + minStep.value).slice(-2) : ""
                            var err = backend.addTask(titleField.text, notesField.text, addPopup.kind,
                                                      days.join(","), dateField.text, tm, addPopup.prio)
                            if (err === "") addPopup.close(); else errTxt.text = err
                        }
                    }
                }
            }
        }
    }

    Confetti { id: confetti }
}
