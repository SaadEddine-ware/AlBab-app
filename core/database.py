import json
import os
import sqlite3
import threading


class DatabaseManager:
    def __init__(self, db_path: str):
        self._db_path = db_path
        self._lock = threading.Lock()
        if db_path != ":memory:":
            dirn = os.path.dirname(db_path)
            if dirn:
                os.makedirs(dirn, exist_ok=True)
        self._conn = sqlite3.connect(db_path, timeout=10, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute("PRAGMA foreign_keys=ON")
        self._init_db()

    def _init_db(self):
        with self._lock:
            self._conn.executescript("""
                CREATE TABLE IF NOT EXISTS settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS users (
                    email TEXT PRIMARY KEY,
                    first_name TEXT NOT NULL,
                    last_name TEXT NOT NULL,
                    faculty TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT (datetime('now'))
                );
                CREATE TABLE IF NOT EXISTS calculator_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    expression TEXT NOT NULL,
                    result TEXT NOT NULL,
                    timestamp TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS source_sessions (
                    name TEXT PRIMARY KEY,
                    data TEXT NOT NULL,
                    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
                );
                CREATE TABLE IF NOT EXISTS kv_store (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS app_state (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS chat_sessions (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL DEFAULT 'New Chat',
                    backend TEXT NOT NULL DEFAULT 'OpenCode',
                    opencode_session_id TEXT DEFAULT '',
                    pinned INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL DEFAULT (datetime('now')),
                    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
                );
                CREATE TABLE IF NOT EXISTS chat_messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
                    role TEXT NOT NULL CHECK(role IN ('user', 'ai')),
                    content TEXT NOT NULL DEFAULT '',
                    reasoning TEXT DEFAULT '',
                    tokens_input INTEGER DEFAULT 0,
                    tokens_output INTEGER DEFAULT 0,
                    is_error INTEGER DEFAULT 0,
                    created_at TEXT NOT NULL DEFAULT (datetime('now'))
                );
            """)
            cols = [r["name"] for r in self._conn.execute("PRAGMA table_info(chat_sessions)").fetchall()]
            if "pinned" not in cols:
                self._conn.execute("ALTER TABLE chat_sessions ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0")
            self._conn.commit()

    def migrate_from_json(self, settings_path: str = None, users_path: str = None):
        with self._lock:
            count = self._conn.execute("SELECT COUNT(*) FROM settings").fetchone()[0]
            if count > 0:
                return
            if settings_path and os.path.exists(settings_path):
                with open(settings_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                for key, value in data.items():
                    self._conn.execute(
                        "INSERT INTO settings (key, value) VALUES (?, ?)",
                        (key, json.dumps(value))
                    )
            if users_path and os.path.exists(users_path):
                with open(users_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                for u in data.get("users", []):
                    self._conn.execute(
                        "INSERT OR IGNORE INTO users (email, first_name, last_name, faculty, created_at) VALUES (?, ?, ?, ?, datetime('now'))",
                        (u.get("email"), u.get("first_name", ""), u.get("last_name", ""), u.get("faculty", ""))
                    )
                if data.get("current_email"):
                    self._conn.execute(
                        "INSERT OR REPLACE INTO app_state (key, value) VALUES ('current_email', ?)",
                        (data["current_email"],)
                    )
            self._conn.commit()

    def get_setting(self, key: str, default=None):
        with self._lock:
            row = self._conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
            if row:
                return json.loads(row["value"])
            return default

    def set_setting(self, key: str, value):
        with self._lock:
            self._conn.execute(
                "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (key, json.dumps(value))
            )
            self._conn.commit()

    def get_all_settings(self):
        with self._lock:
            rows = self._conn.execute("SELECT key, value FROM settings").fetchall()
            return {row["key"]: json.loads(row["value"]) for row in rows}

    def get_users(self):
        with self._lock:
            rows = self._conn.execute("SELECT email, first_name, last_name, faculty FROM users ORDER BY created_at").fetchall()
            return [{"email": r["email"], "first_name": r["first_name"], "last_name": r["last_name"], "faculty": r["faculty"]} for r in rows]

    def add_user(self, email, first_name, last_name, faculty):
        with self._lock:
            try:
                self._conn.execute(
                    "INSERT INTO users (email, first_name, last_name, faculty) VALUES (?, ?, ?, ?)",
                    (email, first_name, last_name, faculty)
                )
                self._conn.commit()
                return True
            except sqlite3.IntegrityError:
                return False

    def delete_user(self, email):
        with self._lock:
            self._conn.execute("DELETE FROM users WHERE email=?", (email,))
            self._conn.commit()

    def has_any_users(self):
        with self._lock:
            row = self._conn.execute("SELECT 1 FROM users LIMIT 1").fetchone()
            return row is not None

    def get_state(self, key, default=None):
        with self._lock:
            row = self._conn.execute("SELECT value FROM app_state WHERE key=?", (key,)).fetchone()
            return row["value"] if row else default

    def set_state(self, key, value):
        if value is None:
            value = ""
        with self._lock:
            self._conn.execute(
                "INSERT INTO app_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (key, value)
            )
            self._conn.commit()

    def add_calc_history(self, expression, result, timestamp):
        with self._lock:
            self._conn.execute(
                "INSERT INTO calculator_history (expression, result, timestamp) VALUES (?, ?, ?)",
                (expression, result, timestamp)
            )
            self._conn.commit()

    def get_calc_history(self, limit=100):
        with self._lock:
            rows = self._conn.execute(
                "SELECT expression, result, timestamp FROM calculator_history ORDER BY id DESC LIMIT ?",
                (limit,)
            ).fetchall()
            return [{"expr": row["expression"], "result": row["result"], "time": row["timestamp"]} for row in rows]

    def clear_calc_history(self):
        with self._lock:
            self._conn.execute("DELETE FROM calculator_history")
            self._conn.commit()

    def kv_save(self, key, value):
        with self._lock:
            self._conn.execute(
                "INSERT INTO kv_store (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (key, value)
            )
            self._conn.commit()

    def kv_load(self, key, default="[]"):
        with self._lock:
            row = self._conn.execute("SELECT value FROM kv_store WHERE key=?", (key,)).fetchone()
            return row["value"] if row else default

    def kv_remove(self, key):
        with self._lock:
            self._conn.execute("DELETE FROM kv_store WHERE key=?", (key,))
            self._conn.commit()

    def kv_exists(self, key):
        with self._lock:
            row = self._conn.execute("SELECT 1 FROM kv_store WHERE key=?", (key,)).fetchone()
            return row is not None

    def save_session(self, name, data):
        with self._lock:
            self._conn.execute(
                "INSERT INTO source_sessions (name, data, updated_at) VALUES (?, ?, datetime('now')) ON CONFLICT(name) DO UPDATE SET data=excluded.data, updated_at=excluded.updated_at",
                (name, data)
            )
            self._conn.commit()

    def load_session(self, name):
        with self._lock:
            row = self._conn.execute("SELECT data FROM source_sessions WHERE name=?", (name,)).fetchone()
            return row["data"] if row else json.dumps({"error": "not found"})

    def list_sessions(self):
        with self._lock:
            rows = self._conn.execute("SELECT name FROM source_sessions ORDER BY updated_at DESC").fetchall()
            return [row["name"] for row in rows]

    def delete_session(self, name):
        with self._lock:
            self._conn.execute("DELETE FROM source_sessions WHERE name=?", (name,))
            self._conn.commit()

    def create_chat_session(self, session_id, name, backend, opencode_session_id=""):
        with self._lock:
            try:
                self._conn.execute(
                    "INSERT INTO chat_sessions (id, name, backend, opencode_session_id) VALUES (?, ?, ?, ?)",
                    (session_id, name, backend, opencode_session_id)
                )
                self._conn.commit()
            except sqlite3.IntegrityError:
                pass

    def delete_chat_session(self, session_id):
        with self._lock:
            self._conn.execute("DELETE FROM chat_sessions WHERE id=?", (session_id,))
            self._conn.commit()

    def rename_chat_session(self, session_id, name):
        with self._lock:
            self._conn.execute(
                "UPDATE chat_sessions SET name=?, updated_at=datetime('now') WHERE id=?",
                (name, session_id)
            )
            self._conn.commit()

    def list_chat_sessions(self, backend=None):
        with self._lock:
            if backend:
                rows = self._conn.execute(
                    "SELECT id, name, backend, updated_at, pinned FROM chat_sessions WHERE backend=? ORDER BY pinned DESC, updated_at DESC",
                    (backend,)
                ).fetchall()
            else:
                rows = self._conn.execute(
                    "SELECT id, name, backend, updated_at, pinned FROM chat_sessions ORDER BY pinned DESC, updated_at DESC"
                ).fetchall()
            return [{"id": r["id"], "name": r["name"], "backend": r["backend"], "updatedAt": r["updated_at"], "pinned": bool(r["pinned"])} for r in rows]

    def get_chat_session(self, session_id):
        with self._lock:
            row = self._conn.execute(
                "SELECT id, name, backend, opencode_session_id, pinned FROM chat_sessions WHERE id=?",
                (session_id,)
            ).fetchone()
            if row:
                return {"id": row["id"], "name": row["name"], "backend": row["backend"], "opencode_session_id": row["opencode_session_id"], "pinned": bool(row["pinned"])}
            return None

    def set_pinned_chat_session(self, session_id, pinned):
        with self._lock:
            self._conn.execute(
                "UPDATE chat_sessions SET pinned=? WHERE id=?",
                (1 if pinned else 0, session_id)
            )
            self._conn.commit()

    def touch_chat_session(self, session_id):
        with self._lock:
            self._conn.execute(
                "UPDATE chat_sessions SET updated_at=datetime('now') WHERE id=?",
                (session_id,)
            )
            self._conn.commit()

    def update_opencode_session_id(self, session_id, opencode_session_id):
        with self._lock:
            self._conn.execute(
                "UPDATE chat_sessions SET opencode_session_id=?, updated_at=datetime('now') WHERE id=?",
                (opencode_session_id, session_id)
            )
            self._conn.commit()

    def add_chat_message(self, session_id, role, content, reasoning="", tokens_input=0, tokens_output=0, is_error=0):
        with self._lock:
            self._conn.execute(
                "INSERT INTO chat_messages (session_id, role, content, reasoning, tokens_input, tokens_output, is_error) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (session_id, role, content, reasoning, tokens_input, tokens_output, is_error)
            )
            self._conn.commit()
            return self._conn.execute("SELECT last_insert_rowid()").fetchone()[0]

    def get_chat_messages(self, session_id):
        with self._lock:
            rows = self._conn.execute(
                "SELECT id, session_id, role, content, reasoning, tokens_input, tokens_output, is_error, created_at FROM chat_messages WHERE session_id=? ORDER BY id",
                (session_id,)
            ).fetchall()
            result = []
            for r in rows:
                result.append({
                    "id": r["id"],
                    "role": r["role"],
                    "content": r["content"],
                    "reasoning": r["reasoning"] or "",
                    "tokensInput": r["tokens_input"] or 0,
                    "tokensOutput": r["tokens_output"] or 0,
                    "isError": bool(r["is_error"]),
                    "createdAt": r["created_at"],
                })
            return result

    def search_chat_messages(self, query: str):
        with self._lock:
            safe_q = query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            like = f"%{safe_q}%"
            rows = self._conn.execute(
                "SELECT m.id, m.session_id, m.role, m.content, m.created_at, "
                "s.name AS session_name, s.backend "
                "FROM chat_messages m "
                "JOIN chat_sessions s ON s.id = m.session_id "
                "WHERE m.content LIKE ? ESCAPE '\\' "
                "ORDER BY m.created_at DESC LIMIT 50",
                (like,)
            ).fetchall()
            return [
                {
                    "id": r["id"],
                    "sessionId": r["session_id"],
                    "role": r["role"],
                    "content": r["content"][:200],
                    "createdAt": r["created_at"],
                    "sessionName": r["session_name"],
                    "backend": r["backend"],
                }
                for r in rows
            ]

    def delete_chat_messages_after(self, session_id: str, after_id: int):
        with self._lock:
            self._conn.execute(
                "DELETE FROM chat_messages WHERE session_id=? AND id>?",
                (session_id, after_id)
            )
            self._conn.commit()

    def update_chat_message(self, msg_id: int, content: str):
        with self._lock:
            self._conn.execute(
                "UPDATE chat_messages SET content=? WHERE id=?",
                (content, msg_id)
            )
            self._conn.commit()

    def update_chat_message_tokens(self, session_id: str, content: str, tokens_input: int, tokens_output: int):
        with self._lock:
            self._conn.execute(
                "UPDATE chat_messages SET tokens_input=?, tokens_output=? "
                "WHERE session_id=? AND role='ai' AND content=? "
                "ORDER BY id DESC LIMIT 1",
                (tokens_input, tokens_output, session_id, content)
            )
            self._conn.commit()

    def get_last_user_message_id(self, session_id: str, before_id: int):
        with self._lock:
            row = self._conn.execute(
                "SELECT id FROM chat_messages WHERE session_id=? AND id<? AND role='user' ORDER BY id DESC LIMIT 1",
                (session_id, before_id)
            ).fetchone()
            return row["id"] if row else None

    def close(self):
        if self._conn:
            try:
                self._conn.close()
            except Exception:
                pass
            self._conn = None

    @property
    def path(self):
        return self._db_path
