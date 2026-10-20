# Building the DayDone APK

## What was fixed

- **SQLite startup crash:** the Android build wrapper now places the `sqlite3` recipe before `python3`. python-for-android builds optional standard-library extensions in dependency order; placing `sqlite3` after `python3` can produce an APK where importing `sqlite3` fails at launch.
- **QML module packaging:** `qml/imports.qml` explicitly lists the Qt Quick modules used by the interface. This helps the Android import scanner discover modules when the real UI is loaded from `rc_resources.py`.
- **Reminder error handling:** a failed native notification is no longer recorded as delivered, and notification errors are prevented from propagating through the reminder timer.
- **Build validation:** the GitHub Actions workflow runs Python compilation and regression tests before attempting the Android build, and fails if no APK is produced.

## 1. Run source and database tests

Use Python 3.11 or newer for these tests. The database tests do not require PySide6:

```bash
python -m compileall -q main.py db.py notifier.py tools tests
python -m unittest discover -s tests -v
```

For the desktop UI, install PySide6 and run:

```bash
pip install -r requirements.txt
python main.py
```

## 2. Build the APK (Linux or WSL2 Ubuntu recommended)

The GitHub Actions workflow is the preferred route because PySide6 Android deployment needs Linux, Java 17, Android SDK/NDK, and matching Android wheels.

1. Push the `DayDone` folder contents to a GitHub repository's `main` branch.
2. Open **Actions → Build Android APK** and run the workflow (or push a commit).
3. Wait for the job to finish successfully.
4. Download the **DayDone-apk** artifact and extract the APK.
5. If the job fails, download **build-diagnostics** and inspect `build.log`.

The workflow pins PySide6 to 6.8.3 (instead of installing the latest version, which may not have a published Android-wheel directory) and downloads matching Android wheels from the official package index (the wheels are not stored in version-named subdirectories), compiles `resources.qrc`, runs the custom wrapper, and checks that an APK was actually created.

## 3. Install and verify on the phone

Install the APK, launch DayDone, add a daily task, mark it done, close and reopen the app, and confirm the task remains saved. Then add a task with a time a minute or two ahead and verify the reminder while the app process is alive. On Android 13+, allow notifications in **Settings → Apps → DayDone → Notifications**.

To capture a startup crash with Android Platform Tools installed, connect the phone with USB debugging enabled and run:

```bash
adb logcat -c
adb shell monkey -p org.daydone.daydone 1
adb logcat -d -s AndroidRuntime Python Qt DEBUG
```

The exact package name may differ depending on the generated `pysidedeploy.spec`; check its `package` setting if the `monkey` command cannot find the app.

## Known limitation

Reminders are checked by an in-app timer every 30 seconds. They are not guaranteed after Android force-stops the app or kills its process. Reliable delivery while fully closed requires native scheduled alarms/receivers. Also, a successful source test or CI build is not a substitute for testing the APK on a physical Android device.
