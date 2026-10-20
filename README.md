# DayDone — To-Do app (PySide6 + QML + SQLite)

Features
- Daily, weekly (pick weekdays) and one-time tasks
- Optional time per task; "Anytime" tasks when no time is set
- Checklist split into Remaining / Done, overdue times highlighted
- Week strip to browse and tick off any day of the current week
- Dashboard: today's completion ring, weekly bar chart, streak
- 🎉 Confetti + congratulations when you finish all tasks, and again every time you open the app on a day that is fully done
- Reminders when a task's time arrives: shows its priority, notes, how many tasks are still pending, and the other high-priority ones

Design
- High-contrast dark theme (all text/background pairs WCAG AA), vector icons drawn in QML (no emoji/image assets),
  custom buttons, fields, steppers and toggles, bottom-sheet task editor that lifts above the keyboard
- Design tokens live in qml/Theme.qml — change colours in one place

Layout
- main.py      Backend (QObject) exposed to QML, reminder timer
- db.py        SQLite schema + queries (tasks, completions, notified)
- notifier.py  Android notification via JNI; console fallback on desktop
- qml/         UI: main.qml + reusable components (Theme, TaskCard, AppField, Segmented, Stepper, ...)
- icon.png     512px app icon

Android build notes
- The Android wrapper orders the `sqlite3` recipe before `python3` to avoid a missing `_sqlite3`
  extension at startup.
- `qml/imports.qml` is a deployment import manifest for the Qt Quick modules used by the UI.
- Run `python -m unittest discover -s tests -v` for database and build-regression checks.
- See `BUILD_APK.md` for build steps and Android crash-log collection.

Known limitation
Reminders are checked every 30 s by an in-app timer, so they fire while the app process is
running. For guaranteed delivery after the app is force-stopped or killed, add native scheduled
alarms and a BroadcastReceiver.
