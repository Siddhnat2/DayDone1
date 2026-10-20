import sys
import traceback
from datetime import date, datetime
from pathlib import Path

from PySide6.QtCore import Property, QObject, QStandardPaths, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from db import Database
import notifier

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
                notifier.notify(title, "\n".join(lines), nid=t["id"])
                self.db.mark_notified(t["id"], today)
                self.toast.emit(f"Due now: {t['title']}")


def _diagnostic_log_path():
    """Return a writable, app-private location for startup diagnostics."""
    for location in (QStandardPaths.writableLocation(QStandardPaths.AppLocalDataLocation),
                     QStandardPaths.writableLocation(QStandardPaths.AppDataLocation),
                     str(Path.home() / ".daydone")):
        if location:
            try:
                folder = Path(location)
                folder.mkdir(parents=True, exist_ok=True)
                probe = folder / ".write_test"
                probe.write_text("ok", encoding="utf-8")
                probe.unlink(missing_ok=True)
                return folder / "daydone-startup.log"
            except (OSError, RuntimeError):
                continue
    return None


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("DayDone")
    app.setOrganizationName("DayDone")
    try:
        app.setWindowIcon(QIcon(ICON_PATH))
    except Exception:
        pass

    log_path = _diagnostic_log_path()
    def log(message):
        line = f"[{datetime.now().isoformat(timespec='seconds')}] {message}"
        print(line, file=sys.stderr, flush=True)
        if log_path:
            try:
                with log_path.open("a", encoding="utf-8") as f:
                    f.write(line + "\n")
            except OSError:
                pass

    def exception_hook(exc_type, exc_value, exc_tb):
        log("UNHANDLED PYTHON EXCEPTION\n" + "".join(
            traceback.format_exception(exc_type, exc_value, exc_tb)))
    sys.excepthook = exception_hook

    try:
        data_location = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
        if not data_location:
            data_location = str(Path.home() / ".daydone")
        data_dir = Path(data_location)
        data_dir.mkdir(parents=True, exist_ok=True)
        log(f"Starting DayDone; platform={sys.platform}; Qt={__import__('PySide6').__version__}")
        log(f"QML URL: {QML_URL.toString()}; database: {data_dir / 'daydone.db'}")
        backend = Backend(str(data_dir / "daydone.db"))

        engine = QQmlApplicationEngine()
        engine.warnings.connect(lambda warnings: [log("QML warning: " + w.toString()) for w in warnings])
        engine.rootContext().setContextProperty("backend", backend)
        engine.load(QML_URL)
        if not engine.rootObjects():
            log("FATAL: QML engine produced no root objects; check QML warnings above.")
            return 2

        win = engine.rootObjects()[0]
        try:
            m = win.safeAreaMargins()
            backend.set_insets(m.top(), m.bottom())
            win.safeAreaMarginsChanged.connect(
                lambda: backend.set_insets(win.safeAreaMargins().top(), win.safeAreaMargins().bottom()))
        except Exception as exc:
            log(f"Safe-area API unavailable: {exc}")
            if sys.platform == "android" or hasattr(sys, "getandroidapilevel"):
                backend.set_insets(28, 12)
        log("QML root loaded successfully")
        return app.exec()
    except Exception:
        log("FATAL STARTUP ERROR\n" + traceback.format_exc())
        return 1


if __name__ == "__main__":
    main()
