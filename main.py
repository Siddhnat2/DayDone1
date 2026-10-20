import sys
import traceback
from datetime import date, datetime
from pathlib import Path

from PySide6.QtCore import Property, QFile, QObject, QStandardPaths, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

_import_error = None
try:
    from db import Database
    import notifier
except Exception:                      # e.g. sqlite3 missing in an Android build
    _import_error = traceback.format_exc()
    Database = None
    notifier = None

# UI files are compiled into rc_resources.py (pyside6-rcc resources.qrc -o rc_resources.py)
# so they ship inside the app on Android. Falls back to loose files when running from source.
try:
    import rc_resources  # noqa: F401
    QML_URL = QUrl("qrc:/qml/main.qml")
    ICON_PATH = ":/icon.png"
except ImportError:
    QML_URL = QUrl.fromLocalFile(str(Path(__file__).parent / "qml" / "main.qml"))
    ICON_PATH = str(Path(__file__).parent / "icon.png")

PRIORITY = {1: "Low", 2: "Normal", 3: "High"}


class Backend(QObject):
    changed = Signal()
    celebrate = Signal()
    toast = Signal(str)
    insetsChanged = Signal()

    def __init__(self, db_path):
        super().__init__()
        self._top = 0
        self._bottom = 0
        self.db = Database(db_path)
        self.timer = QTimer(self)
        self.timer.setInterval(30_000)           # check due tasks every 30 s
        self.timer.timeout.connect(self.check_due)
        self.timer.start()
        QTimer.singleShot(2000, self.check_due)

    # ---- safe-area insets (status bar / gesture bar) -------------------
    @Property(int, notify=insetsChanged)
    def topInset(self):
        return self._top

    @Property(int, notify=insetsChanged)
    def bottomInset(self):
        return self._bottom

    def set_insets(self, top, bottom):
        self._top, self._bottom = int(top), int(bottom)
        self.insetsChanged.emit()

    # ---- helpers -----------------------------------------------------
    @staticmethod
    def _d(s):
        return date.fromisoformat(s)

    # ---- QML API -----------------------------------------------------
    @Slot(result=str)
    def todayStr(self):
        return date.today().isoformat()

    @Slot(str, result="QVariantList")
    def tasksFor(self, day):
        return self.db.tasks_for(self._d(day))

    @Slot(str, result="QVariantMap")
    def stats(self, day):
        return self.db.stats(self._d(day))

    @Slot(str, result="QVariantList")
    def weekStats(self, day):
        return self.db.week_stats(self._d(day))

    @Slot(result=int)
    def streak(self):
        return self.db.streak()

    @Slot(result=bool)
    def shouldCelebrateOnOpen(self):
        s = self.db.stats(date.today())
        return s["total"] > 0 and s["done"] == s["total"]

    @Slot(str, str, str, str, str, str, int, result=str)
    def addTask(self, title, notes, kind, weekdays, due_date, time, priority):
        if not title.strip():
            return "Please enter a task title."
        if kind == "weekly" and not weekdays:
            return "Pick at least one weekday."
        if kind == "once":
            try:
                self._d(due_date)
            except ValueError:
                return "Date must look like 2026-10-25."
        self.db.add_task(title, notes, kind, weekdays, due_date if kind == "once" else "",
                         time, priority)
        self.changed.emit()
        return ""

    @Slot(int, str)
    def toggle(self, task_id, day):
        d = self._d(day)
        before = self.db.stats(d)
        self.db.toggle(task_id, d)
        after = self.db.stats(d)
        self.changed.emit()
        if (d == date.today() and after["total"] and after["done"] == after["total"]
                and before["done"] != before["total"]):
            self.celebrate.emit()

    @Slot(int)
    def deleteTask(self, task_id):
        self.db.delete_task(task_id)
        self.changed.emit()

    # ---- reminders ---------------------------------------------------
    @Slot()
    def check_due(self):
        today, now = date.today(), datetime.now().strftime("%H:%M")
        tasks = self.db.tasks_for(today)
        pending = [t for t in tasks if not t["done"]]
        for t in pending:
            if t["time"] and t["time"] <= now and not self.db.was_notified(t["id"], today):
                others = [x for x in pending if x["id"] != t["id"]]
                important = [x["title"] for x in others if x["priority"] == 3][:3]
                lines = [f"{PRIORITY[t['priority']]} priority · due {t['time']}"]
                if t["notes"]:
                    lines.append(t["notes"])
                lines.append(f"{len(pending)} task(s) still pending today.")
                if important:
                    lines.append("Important: " + ", ".join(important))
                title = ("🔥 " if t["priority"] == 3 else "⏰ ") + t["title"]
                try:
                    # Do not record a reminder as delivered when Android rejected it
                    # (for example, notifications are disabled or JNI is unavailable).
                    delivered = notifier.notify(title, "\n".join(lines), nid=t["id"])
                except Exception:
                    traceback.print_exc()
                    delivered = False
                if delivered:
                    self.db.mark_notified(t["id"], today)
                    self.toast.emit(f"Due now: {t['title']}")


ERROR_QML = b"""
import QtQuick
Window {
    visible: true; width: 400; height: 800; color: "#0B0F1A"; title: "DayDone"
    Flickable {
        anchors.fill: parent; anchors.margins: 18
        contentHeight: col.height + 40; clip: true
        Column {
            id: col; width: parent.width; spacing: 14; y: 30
            Text { width: parent.width; wrapMode: Text.WordWrap; color: "#FFFFFF"; font.pixelSize: 24; font.bold: true
                   text: "DayDone could not start" }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: "#C9D1EE"; font.pixelSize: 15
                   text: "Please take a screenshot of this screen and send it to the developer." }
            Text { width: parent.width; wrapMode: Text.WrapAnywhere; color: "#FF9AA8"; font.pixelSize: 11
                   font.family: "monospace"; text: errorText }
        }
    }
}
"""


def run_error_screen(app, text):
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("errorText", text)
    engine.loadData(ERROR_QML)
    return app.exec()


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("DayDone")
    app.setWindowIcon(QIcon(ICON_PATH))
    data_dir = Path(QStandardPaths.writableLocation(QStandardPaths.AppDataLocation))
    try:
        data_dir.mkdir(parents=True, exist_ok=True)
    except Exception:
        pass

    try:
        if _import_error:
            raise RuntimeError("Import failed:\n" + _import_error)
        backend = Backend(str(data_dir / "daydone.db"))

        engine = QQmlApplicationEngine()
        messages = []
        engine.warnings.connect(lambda ws: messages.extend(w.toString() for w in ws))
        engine.rootContext().setContextProperty("backend", backend)

        # 1) screens bundled in the app (qrc), 2) fall back to loose files next to main.py
        candidates = [QML_URL]
        loose = QUrl.fromLocalFile(str(Path(__file__).parent / "qml" / "main.qml"))
        if loose != QML_URL:
            candidates.append(loose)
        for url in candidates:
            engine.load(url)
            if engine.rootObjects():
                break
            messages.append(f"-- could not load {url.toString()}")
        if not engine.rootObjects():
            f = QFile(":/qml/main.qml")
            diag = (f"qrc exists={f.exists()} size={f.size()}; "
                    f"loose qml dir exists={(Path(__file__).parent / 'qml').exists()}")
            raise RuntimeError("The screens failed to load:\n" + diag + "\n" + "\n".join(messages[:12]))

        # Keep content clear of the Android status bar / gesture bar.
        win = engine.rootObjects()[0]
        try:
            m = win.safeAreaMargins()                  # Qt >= 6.9
            backend.set_insets(m.top(), m.bottom())
            win.safeAreaMarginsChanged.connect(
                lambda: backend.set_insets(win.safeAreaMargins().top(), win.safeAreaMargins().bottom()))
        except Exception:
            if sys.platform == "android" or hasattr(sys, "getandroidapilevel"):
                backend.set_insets(28, 12)             # sensible default on older Qt
    except Exception:
        text = f"Python {sys.version.split()[0]} on {sys.platform}\n\n" + traceback.format_exc()
        try:
            (data_dir / "last_error.txt").write_text(text)
        except Exception:
            pass
        sys.exit(run_error_screen(app, text))

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
