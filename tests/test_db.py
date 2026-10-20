"""Regression tests for DayDone's SQLite task model (no Qt required)."""
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path

from db import Database


class DatabaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Database(str(Path(self.tmp.name) / "daydone.db"))

    def tearDown(self):
        self.db.con.close()
        self.tmp.cleanup()

    def test_daily_task_add_complete_and_stats(self):
        today = date.today()
        self.db.add_task("Read", "10 pages", "daily", "", "", "09:30", 3)
        tasks = self.db.tasks_for(today)
        self.assertEqual(len(tasks), 1)
        self.assertEqual(tasks[0]["title"], "Read")
        self.assertFalse(tasks[0]["done"])
        self.db.toggle(tasks[0]["id"], today)
        self.assertEqual(self.db.stats(today)["percent"], 100)
        self.assertTrue(self.db.tasks_for(today)[0]["done"])

    def test_weekly_task_only_appears_on_selected_weekday(self):
        today = date.today()
        self.db.add_task("Gym", "", "weekly", str(today.weekday()), "", "", 2)
        self.assertEqual(len(self.db.tasks_for(today)), 1)
        other_day = today + timedelta(days=(1 if today.weekday() != 6 else 2))
        self.assertEqual(self.db.tasks_for(other_day), [])

    def test_one_time_task_only_appears_on_due_date(self):
        today = date.today()
        due = today + timedelta(days=2)
        self.db.add_task("Appointment", "", "once", "", due.isoformat(), "14:00", 2)
        self.assertEqual(self.db.tasks_for(today), [])
        self.assertEqual(len(self.db.tasks_for(due)), 1)

    def test_delete_hides_task_without_erasing_history(self):
        today = date.today()
        self.db.add_task("Keep record", "", "daily", "", "", "", 1)
        task_id = self.db.tasks_for(today)[0]["id"]
        self.db.toggle(task_id, today)
        self.db.delete_task(task_id)
        self.assertEqual(self.db.tasks_for(today), [])
        self.assertIsNotNone(self.db.con.execute(
            "SELECT 1 FROM completions WHERE task_id=? AND day=?",
            (task_id, today.isoformat())).fetchone())

    def test_notification_deduplication(self):
        today = date.today()
        self.db.add_task("Ping", "", "daily", "", "", "", 2)
        task_id = self.db.tasks_for(today)[0]["id"]
        self.assertFalse(self.db.was_notified(task_id, today))
        self.db.mark_notified(task_id, today)
        self.assertTrue(self.db.was_notified(task_id, today))

    def test_database_reopens_and_keeps_tasks(self):
        today = date.today()
        self.db.add_task("Persist", "", "daily", "", "", "", 2)
        path = self.db.con.execute("PRAGMA database_list").fetchone()[2]
        self.db.con.close()
        self.db = Database(path)
        self.assertEqual(self.db.tasks_for(today)[0]["title"], "Persist")


if __name__ == "__main__":
    unittest.main()
