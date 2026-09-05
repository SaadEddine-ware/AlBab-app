import uuid

from PySide6.QtCore import QObject, Signal, Slot, Property

from core.database import DatabaseManager


class ChatSessionManager(QObject):
    sessionsChanged = Signal()
    currentSessionChanged = Signal()

    def __init__(self, db: DatabaseManager, key_rotation=None, parent=None):
        super().__init__(parent)
        self._db = db
        self._key_rotation = key_rotation
        self._current_id = None

    @Property("QVariant", notify=sessionsChanged)
    def sessions(self):
        return self._db.list_chat_sessions()

    @Property(str, notify=currentSessionChanged)
    def currentSessionId(self):
        return self._current_id or ""

    @Property(str, notify=currentSessionChanged)
    def currentSessionName(self):
        if not self._current_id:
            return ""
        s = self._db.get_chat_session(self._current_id)
        return s["name"] if s else ""

    @Property(str, notify=currentSessionChanged)
    def currentSessionBackend(self):
        if not self._current_id:
            return ""
        s = self._db.get_chat_session(self._current_id)
        return s["backend"] if s else ""

    @Property(str, notify=currentSessionChanged)
    def currentOpencodeSessionId(self):
        if not self._current_id:
            return ""
        s = self._db.get_chat_session(self._current_id)
        return s.get("opencode_session_id", "") if s else ""

    @Slot(str, result=str)
    def newSession(self, backend: str) -> str:
        sid = f"chat_{uuid.uuid4().hex[:16]}"
        self._db.create_chat_session(sid, f"New {backend} Chat", backend)
        self._current_id = sid
        self.sessionsChanged.emit()
        self.currentSessionChanged.emit()
        return sid

    @Slot(str)
    def switchSession(self, session_id: str):
        s = self._db.get_chat_session(session_id)
        if not s:
            return
        self._current_id = session_id
        self.currentSessionChanged.emit()

    @Slot(str)
    def deleteSession(self, session_id: str):
        self._db.delete_chat_session(session_id)
        if self._current_id == session_id:
            sessions = self._db.list_chat_sessions()
            if sessions:
                self._current_id = sessions[0]["id"]
            else:
                self._current_id = None
        self.sessionsChanged.emit()
        self.currentSessionChanged.emit()

    @Slot(str)
    def deleteSessionsByName(self, name: str):
        sessions = self._db.list_chat_sessions()
        deleted_ids = set()
        for s in sessions:
            if s["name"] == name:
                self._db.delete_chat_session(s["id"])
                deleted_ids.add(s["id"])
        if self._current_id in deleted_ids:
            remaining = self._db.list_chat_sessions()
            if remaining:
                self._current_id = remaining[0]["id"]
            else:
                self._current_id = None
        self.sessionsChanged.emit()
        self.currentSessionChanged.emit()

    @Slot(str, str)
    def renameSession(self, session_id: str, name: str):
        name = name.strip()
        if not name:
            name = "New Chat"
        self._db.rename_chat_session(session_id, name)
        self.sessionsChanged.emit()
        if session_id == self._current_id:
            self.currentSessionChanged.emit()

    @Slot(str, bool)
    def pinSession(self, session_id: str, pinned: bool):
        self._db.set_pinned_chat_session(session_id, pinned)
        self.sessionsChanged.emit()

    @Slot(str, str, result=int)
    def addUserMessage(self, session_id: str, text: str) -> int:
        msg_id = self._db.add_chat_message(session_id, "user", text)
        self._db.touch_chat_session(session_id)
        self._auto_name(session_id, text)
        self.sessionsChanged.emit()
        self.currentSessionChanged.emit()
        return msg_id

    @Slot(str, str, str, int, int)
    def addAiMessage(self, session_id: str, content: str, reasoning: str = "", tokens_input: int = 0, tokens_output: int = 0):
        self._db.add_chat_message(session_id, "ai", content, reasoning, tokens_input, tokens_output)
        self._db.touch_chat_session(session_id)

    @Slot(str, str, int, int)
    def updateAiTokens(self, session_id: str, content: str, tokens_input: int = 0, tokens_output: int = 0):
        self._db.update_chat_message_tokens(session_id, content, tokens_input, tokens_output)
        self._db.touch_chat_session(session_id)

    @Slot(str, str)
    def setOpencodeSessionId(self, session_id: str, opencode_id: str):
        self._db.update_opencode_session_id(session_id, opencode_id)

    @Slot(result="QVariant")
    def loadMessages(self) -> list:
        if not self._current_id:
            return []
        return self._db.get_chat_messages(self._current_id)

    @Slot(str, result="QVariant")
    def loadMessagesForSession(self, session_id: str) -> list:
        return self._db.get_chat_messages(session_id)

    @Slot(str, result="QVariant")
    def searchMessages(self, query: str) -> list:
        return self._db.search_chat_messages(query)

    @Slot(str, int)
    def deleteMessagesAfter(self, session_id: str, after_id: int):
        self._db.delete_chat_messages_after(session_id, after_id)
        self._db.touch_chat_session(session_id)

    @Slot(str, int, result=int)
    def lastUserMessageId(self, session_id: str, before_id: int) -> int:
        return self._db.get_last_user_message_id(session_id, before_id) or -1

    @Slot(str, int, str, result=int)
    def updateMessage(self, session_id: str, msg_id: int, content: str) -> int:
        self._db.update_chat_message(msg_id, content)
        self._db.touch_chat_session(session_id)
        return msg_id

    @Slot(result=str)
    def exportSessionAsMarkdown(self) -> str:
        if not self._current_id:
            return ""
        session = self._db.get_chat_session(self._current_id)
        if not session:
            return ""
        try:
            name = session["name"]
            msgs = self._db.get_chat_messages(self._current_id)
            lines = [f"# {name}", ""]
            for m in msgs:
                role = "You" if m["role"] == "user" else "AI"
                content = m["content"]
                if m["reasoning"]:
                    lines.append(f"**{role}** (_reasoning: {m['reasoning'][:100]}..._)")
                else:
                    lines.append(f"**{role}**")
                lines.append(content)
                lines.append("---" if m["role"] == "ai" else "")
                lines.append("")
            import os
            export_dir = os.path.join(os.path.expanduser("~"), "Documents", "AlBab")
            os.makedirs(export_dir, exist_ok=True)
            safe_name = "".join(c if c.isalnum() or c in " _-" else "_" for c in name)[:50].strip()
            path = os.path.join(export_dir, f"{safe_name}.md")
            with open(path, "w", encoding="utf-8") as f:
                f.write("\n".join(lines).strip())
            return path
        except Exception:
            return ""

    def _auto_name(self, session_id: str, first_text: str):
        s = self._db.get_chat_session(session_id)
        if s and (s["name"] == "New Chat" or s["name"] == f"New {s['backend']} Chat"):
            temp_name = first_text[:60].strip()
            if temp_name:
                self._db.rename_chat_session(session_id, temp_name)
            # Schedule AI naming on next event loop tick
            from PySide6.QtCore import QTimer
            QTimer.singleShot(0, lambda: self._generate_ai_name(session_id, first_text))

    def _generate_ai_name(self, session_id: str, first_text: str):
        s = self._db.get_chat_session(session_id)
        if not s:
            return
        # Only overwrite if still the temporary first-60-chars name (not a user rename)
        current_name = s["name"]
        expected_temp = first_text[:60].strip()
        if expected_temp and current_name != expected_temp:
            return  # User already renamed it manually

        try:
            if not self._key_rotation or not self._key_rotation.current:
                print("[ChatSessionManager] No API key available for AI naming")
                return
            import google.genai as genai
            client = genai.Client(api_key=self._key_rotation.current)
            prompt = (
                f"Generate a very short title (max 5 words) for a chat that starts with this message. "
                f"Respond with ONLY the title, no quotes, no extra text:\n\n{first_text[:200]}"
            )
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt
            )
            title = response.text.strip().strip('"').strip("'")[:60]
            if title:
                self._db.rename_chat_session(session_id, title)
                self.sessionsChanged.emit()
                if session_id == self._current_id:
                    self.currentSessionChanged.emit()
        except Exception as e:
            print(f"[ChatSessionManager] AI naming failed: {e}")
