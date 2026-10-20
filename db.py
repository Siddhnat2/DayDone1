"""SQLite layer for DayDone."""
import sqlite3
from datetime import date, timedelta

SCHEMA = """
CREATE TABLE IF NOT EXISTS tasks(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  notes TEXT DEFAULT '',
  kind TEXT NOT NULL CHECK(kind IN ('daily','weekly','once')),
  weekdays TEXT DEFAULT '',      -- CSV of 0-6 (Mon=0) for weekly tasks
  due_date TEXT DEFAULT '',      -- yyyy-mm-dd for one-time tasks
  time TEXT DEFAULT '',          -- HH:MM, empty = no specific time
  priority INTEGER DEFAULT 2,    -- 1 low, 2 normal, 3 high
  created TEXT NOT NULL,
  active INTEGER DEFAULT 1
);
CREATE TABLE IF NOT EXISTS completions(
  task_id INTEGER, day TEXT, done_at TEXT,
  PRIMARY KEY(task_id, day)
);
CREATE TABLE IF NOT EXISTS notified(
  task_id INTEGER, day TEXT,
  PRIMARY KEY(task_id, day)
);
"""


class Database:
    def __init__(self, path):
        self.con = sqlite3.connect(path)
        self.con.row_factory = sqlite3.Row
        self.con.executescript(SCHEMA)
        self.con.commit()

    # ---- tasks -------------------------------------------------------
    def add_task(self, title, notes, kind, weekdays, due_date, time, priority):
        self.con.execute(
            "INSERT INTO tasks(title,notes,kind,weekdays,due_date,time,priority,created)"
            " VALUES(?,?,?,?,?,?,?,?)",
            (title.strip(), notes.strip(), kind, weekdays, due_date, time,
             int(priority), date.today().isoformat()))
        self.con.commit()

    def delete_task(self, task_id):
        self.con.execute("UPDATE tasks SET active=0 WHERE id=?", (task_id,))
        self.con.commit()

    def tasks_for(self, day: date):
        d = day.isoformat()
        done = {r["task_id"] for r in self.con.execute(
            "SELECT task_id FROM completions WHERE day=?", (d,))}
        out = []
        for r in self.con.execute("SELECT * FROM tasks WHERE active=1 AND created<=?", (d,)):
            if r["kind"] == "once" and r["due_date"] != d:
                continue
            if r["kind"] == "weekly" and str(day.weekday()) not in r["weekdays"].split(","):
                continue
            out.append({
                "id": r["id"], "title": r["title"], "notes": r["notes"],
                "kind": r["kind"], "time": r["time"], "priority": r["priority"],
                "done": r["id"] in done,
            })
        out.sort(key=lambda t: (t["done"], t["time"] == "", t["time"], -t["priority"]))
        return out

    def toggle(self, task_id, day: date):
        d = day.isoformat()
        cur = self.con.execute("SELECT 1 FROM completions WHERE task_id=? AND day=?", (task_id, d))
        if cur.fetchone():
            self.con.execute("DELETE FROM completions WHERE task_id=? AND day=?", (task_id, d))
        else:
            self.con.execute("INSERT INTO completions VALUES(?,?,datetime('now','localtime'))",
                             (task_id, d))
        self.con.commit()

    # ---- stats -------------------------------------------------------
    def stats(self, day: date):
        tasks = self.tasks_for(day)
        total, done = len(tasks), sum(t["done"] for t in tasks)
        return {"total": total, "done": done, "remaining": total - done,
                "percent": round(100 * done / total) if total else 0}

    def week_stats(self, day: date):
        monday = day - timedelta(days=day.weekday())
        names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        res = []
        for i in range(7):
            d = monday + timedelta(days=i)
            s = self.stats(d)
            s.update(label=names[i], day=d.isoformat(), num=d.day, isToday=(d == date.today()),
                     future=(d > date.today()))
            res.append(s)
        return res

    def streak(self):
        d, n = date.today(), 0
        s = self.stats(d)
        if not (s["total"] and s["done"] == s["total"]):
            d -= timedelta(days=1)          # today not finished yet: don't break the streak
        while True:
            s = self.stats(d)
            if s["total"] and s["done"] == s["total"]:
                n += 1
                d -= timedelta(days=1)
            else:
                return n
            if n > 3650:
                return n

    # ---- notification bookkeeping ------------------------------------
    def was_notified(self, task_id, day):
        return self.con.execute("SELECT 1 FROM notified WHERE task_id=? AND day=?",
                                (task_id, day.isoformat())).fetchone() is not None

    def mark_notified(self, task_id, day):
        self.con.execute("INSERT OR IGNORE INTO notified VALUES(?,?)", (task_id, day.isoformat()))
        self.con.commit()
