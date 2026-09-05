import json
import os
import platform
import re
import subprocess
import threading

from PySide6.QtCore import QObject, Signal, Slot, Property

OPENCODE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "bin",
    "opencode.exe" if platform.system() == "Windows" else "opencode"
)


def strip_ansi(text):
    return re.sub(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])", "", text)


class OpenCodeChatBackend(QObject):
    responseReady = Signal(str)
    toolCallStarted = Signal(str, str)
    toolCallFinished = Signal(str, str)
    errorOccurred = Signal(str)
    statusChanged = Signal(str)
    offlineChanged = Signal(bool)
    reasoningReady = Signal(str, str)
    tokenInfo = Signal(str, int, int)
    sessionIdReceived = Signal(str)
    sessionTitleReceived = Signal(str, str)
    sessionsListChanged = Signal()

    def __init__(self, working_dir=None, server_url=None, parent=None):
        super().__init__(parent)
        self._working_dir = working_dir or os.path.expanduser("~")
        self._server_url = server_url
        self._is_thinking = False
        self._is_offline = False
        self._has_key = True
        self._stop_event = threading.Event()
        self._current_proc = None
        self._lock = threading.Lock()
        self._session_args = []
        self._session_id = ""
        self._user_context = ""
        self._context_injected = False
        self._cached_sessions = []

    def _set_thinking(self, value):
        self._is_thinking = value
        try:
            self.statusChanged.emit("thinking" if value else "ready")
        except RuntimeError:
            pass

    @Slot(str)
    def setUserContext(self, context: str):
        self._user_context = context
        self._context_injected = False

    @Slot(str)
    def sendMessage(self, text):
        if not text.strip():
            return

        if self._user_context and not self._context_injected:
            with self._lock:
                if not self._context_injected:
                    text = f"SYSTEM: {self._user_context}\n\n{text}"
                    self._context_injected = True

        self._set_thinking(True)
        self._stop_event.clear()

        def run():
            try:
                cmd = [OPENCODE_PATH, "run", "--format", "json"]
                if self._server_url:
                    cmd.extend(["--attach", self._server_url])
                cmd.extend(self._session_args)
                cmd.append(text)

                kwargs = {
                    "stdout": subprocess.PIPE,
                    "stderr": subprocess.STDOUT,
                    "cwd": self._working_dir,
                    "bufsize": 0,
                }
                if platform.system() == "Windows":
                    kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW

                proc = subprocess.Popen(cmd, **kwargs)
                with self._lock:
                    self._current_proc = proc

                accumulated_text = ""
                session_id = None

                for raw_line in iter(proc.stdout.readline, b""):
                    if self._stop_event.is_set():
                        proc.kill()
                        break

                    line = raw_line.decode("utf-8", errors="replace").strip()
                    if not line:
                        continue

                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    event_type = event.get("type", "")
                    part = event.get("part", {})
                    sid = event.get("sessionID", "")
                    if sid:
                        session_id = sid

                    if event_type == "text":
                        text_content = part.get("text", "")
                        if text_content:
                            accumulated_text += text_content

                    elif event_type == "tool_use":
                        tool_name = part.get("name", "")
                        tool_input = part.get("input", {})
                        self.toolCallStarted.emit(tool_name, json.dumps(tool_input))

                    elif event_type == "reasoning":
                        reasoning_text = part.get("reasoning", "")
                        if reasoning_text:
                            self.reasoningReady.emit(session_id or "", reasoning_text)

                    elif event_type == "tool_result":
                        tool_name = part.get("name", "")
                        tool_result = part.get("result", "")
                        if isinstance(tool_result, dict):
                            tool_result = json.dumps(tool_result)
                        self.toolCallFinished.emit(tool_name, str(tool_result))

                    elif event_type == "step_finish":
                        tokens = part.get("tokens", {})
                        if tokens:
                            inp = tokens.get("input", 0) or 0
                            out = tokens.get("output", 0) or 0
                            if inp or out:
                                self.tokenInfo.emit(session_id or "", inp, out)

                proc.stdout.close()
                proc.wait()

                with self._lock:
                    self._current_proc = None

                if session_id:
                    self._session_id = session_id
                    self._session_args = ["--session", session_id]
                    self.sessionIdReceived.emit(session_id)

                if self._stop_event.is_set():
                    return

                if accumulated_text:
                    self.responseReady.emit(strip_ansi(accumulated_text).strip())
                    if session_id:
                        self._fetch_session_title(session_id)
                else:
                    self.errorOccurred.emit("No response received from OpenCode.")

            except FileNotFoundError:
                self.errorOccurred.emit("opencode not found in bin/")
            except Exception as e:
                self.errorOccurred.emit(f"Error: {str(e)}")
            finally:
                self._set_thinking(False)

        threading.Thread(target=run, daemon=True).start()

    @Slot()
    def stopGeneration(self):
        self._stop_event.set()
        with self._lock:
            if self._current_proc:
                try:
                    self._current_proc.kill()
                except Exception:
                    pass
                self._current_proc = None

    @Slot(str)
    def setOpencodeSessionId(self, session_id: str):
        self._session_id = session_id
        self._session_args = ["--session", session_id] if session_id else []
        self._context_injected = False

    @Slot(str)
    def setApiKey(self, key):
        pass

    @Slot(result=bool)
    def checkOnline(self) -> bool:
        try:
            import urllib.request
            import urllib.error
            urllib.request.urlopen("https://www.google.com", timeout=3)
            return True
        except Exception:
            return False

    @Property(bool, notify=statusChanged)
    def isThinking(self):
        return self._is_thinking

    @Property(str, notify=statusChanged)
    def apiKey(self):
        return ""

    @Property(bool, notify=offlineChanged)
    def isOffline(self):
        return self._is_offline

    @Property(str, notify=sessionIdReceived)
    def sessionArgsId(self):
        return self._session_id

    @Property("QVariant", notify=sessionsListChanged)
    def sessions(self):
        return self._list_sessions()

    def _list_sessions(self):
        try:
            cmd = [OPENCODE_PATH, "session", "list", "--format", "json", "-n", "50"]
            if platform.system() == "Windows":
                kwargs = {"creationflags": subprocess.CREATE_NO_WINDOW}
            else:
                kwargs = {}
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self._working_dir, timeout=10, **kwargs)
            sessions = json.loads(result.stdout) if result.stdout.strip() else []
            self._cached_sessions = sessions
            return sessions
        except Exception:
            return self._cached_sessions

    @Slot(result="QVariant")
    def listSessions(self):
        # Run in a thread to avoid blocking the UI
        def _run():
            result = self._list_sessions()
            try:
                self.sessionsListChanged.emit()
            except RuntimeError:
                pass
        threading.Thread(target=_run, daemon=True).start()
        return self._cached_sessions

    def _run_export(self, session_id: str):
        try:
            cmd = [OPENCODE_PATH, "export", session_id]
            if platform.system() == "Windows":
                kwargs = {"creationflags": subprocess.CREATE_NO_WINDOW}
            else:
                kwargs = {}
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self._working_dir, timeout=15, **kwargs)
            return json.loads(result.stdout) if result.stdout.strip() else {}
        except Exception:
            return {}

    @Slot(str, result="QVariant")
    def exportSession(self, session_id: str):
        # Run in a thread to avoid blocking the UI
        def _run():
            result = self._run_export(session_id)
            try:
                self.sessionsListChanged.emit()
            except RuntimeError:
                pass
        threading.Thread(target=_run, daemon=True).start()
        return {}

    def _fetch_session_title(self, session_id: str):
        def _run():
            data = self._run_export(session_id)
            title = data.get("info", {}).get("title", "")
            if title:
                try:
                    self.sessionTitleReceived.emit(session_id, title)
                except RuntimeError:
                    pass
        threading.Thread(target=_run, daemon=True).start()

    @Slot()
    def refreshSessions(self):
        self.sessionsListChanged.emit()
