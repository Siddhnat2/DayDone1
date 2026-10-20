# Android startup diagnostics

This build adds a private startup log to help identify launch crashes and blank QML screens.
The log is written under Android's app-specific data directory as `daydone-startup.log`.
It records Python startup exceptions and QML engine warnings, including missing QML modules and
resource-loading errors. It does not record task titles or notes.

## Validation performed

- Python syntax compilation for all application and test modules.
- SQLite tests for daily, weekly, and one-time task visibility, completion toggling, soft deletion,
  and notification bookkeeping.
- Resource manifest validation and checks that every QML file declared in `resources.qrc` exists.

A real Android install/launch test still requires an Android device or emulator and the APK produced
by the GitHub Actions workflow. A successful APK build alone does not prove that the QML modules are
available at runtime; if launch still fails, collect `daydone-startup.log` or Android `logcat` to
identify the exact missing module or native-library error.
