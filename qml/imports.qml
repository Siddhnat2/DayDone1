// Deployment import manifest.
// The Android packaging scanner can miss imports when the app loads QML from
// Python-compiled Qt resources (rc_resources.py). Keep these imports in a loose
// QML file so Qt's import scanner bundles the modules used by the UI.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

QtObject {
    objectName: "DayDoneQmlImportManifest"
}
