"""Runs `pyside6-android-deploy` with the extra settings DayDone needs on Android.

Why: the stock tool hard-codes `requirements = python3,shiboken6,PySide6`, which leaves out
Python's sqlite3 module (the app crashes on start-up with ImportError), and it does not ask for
the notification permission. This wrapper adds both, and pre-accepts the Android SDK licence.

Usage (same arguments as pyside6-android-deploy):
    python tools/android_build.py --name DayDone --wheel-pyside ... --wheel-shiboken ... --force -v
"""
import runpy
import sys
from pathlib import Path

import PySide6

SCRIPTS = Path(PySide6.__file__).parent / "scripts"
sys.path.insert(0, str(SCRIPTS))

from deploy_lib.android import buildozer as bz  # noqa: E402  (module name used by the tool itself)

EXTRA_REQUIREMENTS = ["sqlite3"]
EXTRA_PERMISSIONS = ["android.permission.POST_NOTIFICATIONS"]

_original_init = bz.BuildozerConfig.__init__


def _patched_init(self, spec_file, cfg):
    _original_init(self, spec_file, cfg)

    reqs = [r.strip() for r in (self.get_value("app", "requirements", True) or "").split(",") if r.strip()]
    # python-for-android must process optional stdlib modules (notably
    # sqlite3/_sqlite3) BEFORE python3 is built. Putting sqlite3 after python3
    # can produce an APK that installs but exits at startup with
    # "No module named _sqlite3". Keep these recipes at the front.
    for r in reversed(EXTRA_REQUIREMENTS):
        if r not in reqs:
            reqs.insert(0, r)
    self.set_value("app", "requirements", ",".join(reqs), raise_warning=False)

    perms = [p.strip() for p in (self.get_value("app", "android.permissions", True) or "").split(",")
             if p.strip()]
    for p in EXTRA_PERMISSIONS:
        if p not in perms:
            perms.append(p)
    self.set_value("app", "android.permissions", ", ".join(perms), raise_warning=False)

    self.set_value("app", "android.accept_sdk_license", "True", raise_warning=False)
    self.update_config()


bz.BuildozerConfig.__init__ = _patched_init

if __name__ == "__main__":
    sys.argv = ["pyside6-android-deploy"] + sys.argv[1:]
    runpy.run_path(str(SCRIPTS / "android_deploy.py"), run_name="__main__")
