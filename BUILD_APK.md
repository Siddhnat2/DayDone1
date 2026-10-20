# Building the DayDone APK

## 1. Run on desktop first (works on Windows / Mac / Linux)
    pip install -r requirements.txt
    python main.py

## 2. Build the APK (Linux or WSL2 Ubuntu recommended)
Requirements: Python 3.11 (exact version matters for Android wheels), JDK 17, ~10 GB disk.

    python3.11 -m venv venv && source venv/bin/activate
    pip install PySide6 android_deploy      # android_deploy ships in Qt's "pyside-setup" tools
    pip install -r https://code.qt.io/cgit/pyside/pyside-setup.git/plain/requirements-android.txt  # if needed

    # one-time: download Qt-for-Python Android wheels (shiboken6 + PySide6 for aarch64)
    # from https://download.qt.io/official_releases/QtForPython/  (see Qt docs below)

    pyside6-android-deploy --name DayDone \
        --wheel-pyside=<path/PySide6-*-android_aarch64.whl> \
        --wheel-shiboken=<path/shiboken6-*-android_aarch64.whl> \
        --ndk-path=<android-ndk-r26b> --sdk-path=<android-sdk>

The first run generates `pysidedeploy.spec`; the finished `.apk` is written next to it.
Official guide: https://doc.qt.io/qtforpython-6/deployment/deployment-pyside6-android-deploy.html

## 3. Install on phone
    adb install DayDone-*.apk
(or copy the APK to the phone and allow "Install unknown apps").

## Notifications on Android 13+
Settings → Apps → DayDone → Notifications → Allow.
Reminders fire while the app process is alive (open or in recent apps). To get reminders
after the app is fully closed, an AlarmManager + BroadcastReceiver (Java) is needed — see README.

## Easiest: build in the cloud with GitHub Actions (no local setup)
1. Create a new GitHub repo and push this folder to its `main` branch.
2. Open the repo → Actions → "Build Android APK" → Run workflow (it also runs on every push).
3. When it finishes (30–60 min), download the `DayDone-apk` artifact → unzip → install the .apk.
Workflow: .github/workflows/build-apk.yml (untested — if a step fails, copy the log to Claude).
