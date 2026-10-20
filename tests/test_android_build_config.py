"""Guard the Android startup-crash regression without importing host-only PySide6."""
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AndroidBuildConfigTests(unittest.TestCase):
    def test_sqlite_recipe_is_inserted_before_python3(self):
        source = (ROOT / "tools" / "android_build.py").read_text(encoding="utf-8")
        self.assertIn("for r in reversed(EXTRA_REQUIREMENTS):", source)
        self.assertIn("reqs.insert(0, r)", source)
        self.assertIn('EXTRA_REQUIREMENTS = ["sqlite3"]', source)

    def test_qml_import_manifest_contains_ui_modules(self):
        manifest = (ROOT / "qml" / "imports.qml").read_text(encoding="utf-8")
        self.assertIn("import QtQuick", manifest)
        self.assertIn("import QtQuick.Controls.Basic", manifest)
        self.assertIn("import QtQuick.Layouts", manifest)

    def test_qml_import_manifest_is_in_resources_and_project_files(self):
        qrc = (ROOT / "resources.qrc").read_text(encoding="utf-8")
        project = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
        self.assertIn("qml/imports.qml", qrc)
        self.assertIn("qml/imports.qml", project)


if __name__ == "__main__":
    unittest.main()
