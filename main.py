import faulthandler
import json
import os
import re
import subprocess
import sys
import time
import traceback
from datetime import date, datetime
from pathlib import Path

from PySide6.QtCore import Property, QCoreApplication, QFile, QObject, QStandardPaths, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

try:
    from PySide6.QtQuick import QQuickWindow
except Exception:                       # keep going without it
    QQuickWindow = None

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
                notifier.notify(title, "\n".join(lines), nid=t["id"])
                self.db.mark_notified(t["id"], today)
                self.toast.emit(f"Due now: {t['title']}")


REPORT_QML = b"""
import QtQuick
Window {
    id: win
    visible: true; width: 400; height: 800; color: "#0B0F1A"; title: "DayDone"
    Connections { target: reporter; function onCloseRequested() { win.close() } }
    Flickable {
        anchors.fill: parent; anchors.margins: 18; anchors.bottomMargin: 100
        contentHeight: col.height + 40; clip: true
        Column {
            id: col; width: parent.width; spacing: 14; y: 34
            Text { width: parent.width; wrapMode: Text.WordWrap; color: "#FFFFFF"; font.pixelSize: 24; font.bold: true
                   text: reportTitle }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: "#C9D1EE"; font.pixelSize: 15
                   text: "Tap Copy report (or take a screenshot) and send it to the developer." }
            Text { width: parent.width; wrapMode: Text.WrapAnywhere; color: "#FF9AA8"; font.pixelSize: 11
                   font.family: "monospace"; text: reportText }
        }
    }
    Row {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 26
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
        Rectangle {
            width: 160; height: 52; radius: 14; color: "#232D52"
            Text { anchors.centerIn: parent; text: "Copy report"; color: "#FFFFFF"; font.pixelSize: 16; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: reporter.copy() }
        }
        Rectangle {
            visible: canProceed; width: 180; height: 52; radius: 14; color: "#6C4BFF"
            Text { anchors.centerIn: parent; text: "Open app"; color: "#FFFFFF"; font.pixelSize: 16; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: reporter.proceed() }
        }
    }
}
"""

KEEP = []          # keeps engines / windows alive
REPORTER = None


class Reporter(QObject):
    closeRequested = Signal()

    def __init__(self, text, on_proceed):
        super().__init__()
        self._text, self._on_proceed = text, on_proceed

    @Slot()
    def copy(self):
        QGuiApplication.clipboard().setText(self._text)

    @Slot()
    def proceed(self):
        if self._on_proceed:
            self._on_proceed()
        self.closeRequested.emit()


def show_report(title, text, on_proceed=None):
    """Plain-QML screen (no dependencies on the main UI) showing a report."""
    global REPORTER
    engine = QQmlApplicationEngine()
    REPORTER = Reporter(text, on_proceed)
    ctx = engine.rootContext()
    ctx.setContextProperty("reporter", REPORTER)
    ctx.setContextProperty("reportText", text)
    ctx.setContextProperty("canProceed", on_proceed is not None)
    ctx.setContextProperty("reportTitle", title)
    engine.loadData(REPORT_QML)
    KEEP.append(engine)


class Health:
    """Detects a previous launch that never finished starting and collects evidence."""

    def __init__(self, folder: Path):
        self.d = folder
        self.state_f = folder / "state.json"
        self.trace_f = folder / "trace.txt"
        self.crash_f = folder / "crash.txt"
        self.state = {}
        try:
            self.state = json.loads(self.state_f.read_text())
        except Exception:
            pass

    def _save(self):
        try:
            self.state_f.write_text(json.dumps(self.state))
        except Exception:
            pass

    def trace(self, step):
        try:
            with open(self.trace_f, "a") as f:
                f.write(f"{time.strftime('%H:%M:%S')} {step}\n")
        except Exception:
            pass

    @staticmethod
    def _logcat():
        try:
            out = subprocess.run(["logcat", "-d", "-t", "800", "-v", "brief"],
                                 capture_output=True, text=True, timeout=6).stdout
        except Exception as e:
            return f"(logcat unavailable: {e})"
        pat = re.compile(r"(FATAL|AndroidRuntime|SIGSEGV|SIGABRT|signal \d|Abort|abort|backtrace|"
                         r"python|Python|PySide|shiboken|libQt|Qt6|qml|QML|DayDone|JNI|Traceback|Error|error)")
        lines = [ln[:190] for ln in out.splitlines() if pat.search(ln)]
        return "\n".join(lines[-45:]) or "(no matching log lines)"

    def begin(self):
        """Call first thing. Returns a crash report string if the last launch did not finish."""
        report = None
        if self.state.get("phase") == "running":
            trace = self.trace_f.read_text() if self.trace_f.exists() else ""
            crash = self.crash_f.read_text() if self.crash_f.exists() else ""
            report = ("The previous launch did not finish starting.\n\n"
                      f"Steps reached:\n{trace.strip() or '(none)'}\n\n"
                      f"Python crash dump:\n{crash.strip()[-1500:] or '(none)'}\n\n"
                      f"Android log (filtered):\n{self._logcat()}")
            self.state["safe_mode"] = True          # use software rendering from now on
            self.state["crashes"] = self.state.get("crashes", 0) + 1
        self.state["phase"] = "running"
        self._save()
        try:
            self.trace_f.write_text("")
            self._fh = open(self.crash_f, "w")
            faulthandler.enable(file=self._fh, all_threads=True)
        except Exception:
            pass
        self.trace(f"start python {sys.version.split()[0]} safe_mode={self.state.get('safe_mode', False)}")
        return report

    def mark_ok(self):
        self.state["phase"] = "ok"
        self._save()
        self.trace("alive after 4 s - startup OK")


def main():
    QCoreApplication.setApplicationName("DayDone")
    folder = os.environ.get("DAYDONE_DATA_DIR") or QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
    data_dir = Path(folder)
    try:
        data_dir.mkdir(parents=True, exist_ok=True)
    except Exception:
        pass

    health = Health(data_dir)
    report = health.begin()

    if health.state.get("safe_mode") and QQuickWindow is not None:
        try:
            QQuickWindow.setSceneGraphBackend("software")     # most compatible renderer
            health.trace("software renderer selected")
        except Exception as e:
            health.trace(f"software renderer failed: {e}")

    app = QGuiApplication(sys.argv)
    app.setApplicationName("DayDone")
    app.setWindowIcon(QIcon(ICON_PATH))
    health.trace("app created")

    def start_normal():
        if _import_error:
            raise RuntimeError("Import failed:\n" + _import_error)
        backend = Backend(str(data_dir / "daydone.db"))
        health.trace("backend ready")

        engine = QQmlApplicationEngine()
        KEEP.append(engine)
        KEEP.append(backend)
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
        health.trace("screens loaded")

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
        QTimer.singleShot(4000, health.mark_ok)

    def safe_start():
        try:
            start_normal()
        except Exception:
            text = f"Python {sys.version.split()[0]} on {sys.platform}\n\n" + traceback.format_exc()
            health.trace("startup exception")
            try:
                (data_dir / "last_error.txt").write_text(text)
            except Exception:
                pass
            show_report("DayDone could not start", text)

    if report:
        show_report("DayDone crashed last time", report, on_proceed=safe_start)
    else:
        safe_start()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
