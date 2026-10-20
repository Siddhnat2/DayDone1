import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path

from db import Database


class DatabaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Database(str(Path(self.tmp.name) / "test.db"))

    def tearDown(self):
        self.db.con.close()
        self.tmp.cleanup()

    def test_daily_task_and_completion_toggle(self):
        self.db.add_task("Read", "", "daily", "", "", "", 2)
        today = date.today()
        self.assertEqual(self.db.stats(today)["total"], 1)
        self.assertEqual(self.db.stats(today)["done"], 0)
        self.db.toggle(1, today)
        self.assertEqual(self.db.stats(today)["percent"], 100)
        self.db.toggle(1, today)
        self.assertEqual(self.db.stats(today)["done"], 0)

    def test_weekly_task_only_appears_on_selected_weekday(self):
        self.db.add_task("Monday", "", "weekly", "0", "", "", 2)
        monday = date.today() + timedelta(days=(7 - date.today().weekday()) % 7)
        if monday == date.today():
            monday += timedelta(days=7)
        self.assertEqual(len(self.db.tasks_for(monday)), 1)
        self.assertEqual(len(self.db.tasks_for(monday + timedelta(days=1))), 0)

    def test_one_time_task_only_appears_on_due_date(self):
        tomorrow = date.today() + timedelta(days=1)
        self.db.add_task("Appointment", "", "once", "", tomorrow.isoformat(), "", 3)
        self.assertEqual(len(self.db.tasks_for(tomorrow)), 1)
        self.assertEqual(len(self.db.tasks_for(date.today())), 0)

    def test_delete_hides_task_without_erasing_history(self):
        self.db.add_task("Keep history", "", "daily", "", "", "", 1)
        self.db.toggle(1, date.today())
        self.db.delete_task(1)
        self.assertEqual(self.db.tasks_for(date.today()), [])
        row = self.db.con.execute("SELECT COUNT(*) FROM completions").fetchone()[0]
        self.assertEqual(row, 1)

    def test_notification_bookkeeping_is_idempotent(self):
        today = date.today()
        self.assertFalse(self.db.was_notified(9, today))
        self.db.mark_notified(9, today)
        self.db.mark_notified(9, today)
        self.assertTrue(self.db.was_notified(9, today))
        self.assertEqual(self.db.con.execute("SELECT COUNT(*) FROM notified").fetchone()[0], 1)


if __name__ == "__main__":
    unittest.main()
