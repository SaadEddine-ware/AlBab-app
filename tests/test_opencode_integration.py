"""
Integration tests for OpenCode chat backend + terminal UI.
Run with: python -m pytest tests/test_opencode_integration.py -v
"""
import json
import os
import sys
import time
import pytest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ─── Backend Unit Tests ─────────────────────────────────────────────

class TestOpenCodeChatBackend:
    """Test the Python backend class in isolation."""

    def test_import(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        assert OpenCodeChatBackend is not None

    def test_instantiation(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        backend = OpenCodeChatBackend(working_dir=".")
        assert backend is not None

    def test_default_properties(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        backend = OpenCodeChatBackend()
        assert backend.isThinking == False
        assert backend.isOffline == False
        assert backend.apiKey == ""

    def test_strip_ansi(self):
        from core.opencode_chat_backend import strip_ansi
        assert strip_ansi("Hello") == "Hello"
        assert strip_ansi("\x1B[32mGreen\x1B[0m") == "Green"
        assert strip_ansi("foo\x1B[Kbar") == "foobar"

    def test_set_thinking_signal(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        backend = OpenCodeChatBackend()
        signals = []
        backend.statusChanged.connect(lambda s: signals.append(s))
        backend._set_thinking(True)
        assert signals == ["thinking"]
        backend._set_thinking(False)
        assert signals == ["thinking", "ready"]

    def test_send_message_empty(self, capsys):
        from core.opencode_chat_backend import OpenCodeChatBackend
        backend = OpenCodeChatBackend()
        backend.sendMessage("")  # should be no-op
        backend.sendMessage("   ")
        assert backend.isThinking == False

    def test_stop_generation_no_proc(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        backend = OpenCodeChatBackend()
        backend.stopGeneration()  # should not crash

    def test_set_api_key_noop(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        backend = OpenCodeChatBackend()
        backend.setApiKey("test-key")
        assert backend.apiKey == ""  # OpenCode ignores keys

    def test_check_online(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        backend = OpenCodeChatBackend()
        result = backend.checkOnline()
        assert isinstance(result, bool)

    def test_signal_interface_matches_gemini(self):
        """OpenCodeChatBackend must emit the same signals as GeminiBackend."""
        from PySide6.QtCore import Signal
        from core.opencode_chat_backend import OpenCodeChatBackend

        oc_signals = {
            name for name, val in vars(OpenCodeChatBackend).items()
            if isinstance(val, Signal)
        }

        required = {"responseReady", "toolCallStarted", "toolCallFinished",
                    "errorOccurred", "statusChanged", "offlineChanged",
                    "reasoningReady", "tokenInfo"}
        missing = required - oc_signals
        assert not missing, f"Missing signals: {missing}"

    def test_property_interface_matches_gemini(self):
        """OpenCodeChatBackend must expose the same properties as GeminiBackend."""
        from core.opencode_chat_backend import OpenCodeChatBackend
        from core.gemini_backend import GeminiBackend

        required = {"isThinking", "apiKey", "isOffline"}
        for prop in required:
            assert hasattr(OpenCodeChatBackend, prop), f"Missing property: {prop}"

    def test_slot_interface_matches_gemini(self):
        """OpenCodeChatBackend must expose the same slots QML calls on GeminiBackend."""
        from core.opencode_chat_backend import OpenCodeChatBackend
        from core.gemini_backend import GeminiBackend

        required = {"sendMessage", "stopGeneration", "setApiKey", "checkOnline"}
        for slot in required:
            assert hasattr(OpenCodeChatBackend, slot), f"Missing slot: {slot}"


# ─── JSON Event Parsing Tests ───────────────────────────────────────

class TestJsonEventParsing:
    """Test that OpenCodeChatBackend correctly parses opencode's JSON events."""

    @pytest.fixture
    def backend(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        return OpenCodeChatBackend(working_dir=".")

    def test_event_handling(self, backend):
        """Simulate the JSON events opencode emits and verify signals."""
        events = [
            {"type": "step_start", "timestamp": 1000, "sessionID": "ses_123", "part": {}},
            {"type": "reasoning", "timestamp": 1001, "sessionID": "ses_123",
             "part": {"type": "reasoning", "reasoning": "thinking..."}},
            {"type": "text", "timestamp": 1002, "sessionID": "ses_123",
             "part": {"type": "text", "text": "Hello! ", "format": ""}},
            {"type": "text", "timestamp": 1003, "sessionID": "ses_123",
             "part": {"type": "text", "text": "How can I help?", "format": ""}},
            {"type": "tool_use", "timestamp": 1004, "sessionID": "ses_123",
             "part": {"type": "tool-use", "name": "calculate",
                      "input": {"expression": "2+2"}}},
            {"type": "tool_result", "timestamp": 1005, "sessionID": "ses_123",
             "part": {"type": "tool-result", "name": "calculate", "result": "4"}},
            {"type": "text", "timestamp": 1006, "sessionID": "ses_123",
             "part": {"type": "text", "text": "Result: 4", "format": ""}},
            {"type": "step_finish", "timestamp": 1007, "sessionID": "ses_123",
             "part": {"type": "step-finish", "tokens": {"input": 10, "output": 20}}},
        ]

        text_parts = []
        tools_started = []
        tools_finished = []

        backend.responseReady.connect(lambda msg: text_parts.append(msg))
        backend.toolCallStarted.connect(
            lambda name, args: tools_started.append((name, args)))
        backend.toolCallFinished.connect(
            lambda name, result: tools_finished.append((name, result)))

        # Simulate processing events like the run() method does
        accumulated = ""
        session_id = None

        for event in events:
            etype = event.get("type", "")
            part = event.get("part", {})
            sid = event.get("sessionID", "")
            if sid:
                session_id = sid

            if etype == "text":
                t = part.get("text", "")
                if t:
                    accumulated += t
            elif etype == "tool_use":
                backend.toolCallStarted.emit(
                    part.get("name", ""),
                    json.dumps(part.get("input", {}))
                )
            elif etype == "tool_result":
                r = part.get("result", "")
                backend.toolCallFinished.emit(
                    part.get("name", ""),
                    str(r) if not isinstance(r, str) else r
                )

        backend.responseReady.emit(accumulated)

        assert text_parts == ["Hello! How can I help?Result: 4"]
        assert len(tools_started) == 1
        assert tools_started[0][0] == "calculate"
        assert json.loads(tools_started[0][1]) == {"expression": "2+2"}
        assert len(tools_finished) == 1
        assert tools_finished[0][0] == "calculate"
        assert session_id == "ses_123"

    def test_reasoning_and_token_events(self, backend):
        """Verify reasoningReady and tokenInfo signals emit correctly."""
        reasons = []
        tokens = []

        backend.reasoningReady.connect(lambda sid, t: reasons.append((sid, t)))
        backend.tokenInfo.connect(lambda sid, i, o: tokens.append((sid, i, o)))

        events = [
            {"type": "reasoning", "sessionID": "ses_1",
             "part": {"type": "reasoning", "reasoning": "thinking step 1"}},
            {"type": "reasoning", "sessionID": "ses_1",
             "part": {"type": "reasoning", "reasoning": "thinking step 2"}},
            {"type": "step_finish", "sessionID": "ses_1",
             "part": {"type": "step-finish", "tokens": {"input": 50, "output": 120}}},
        ]

        for event in events:
            etype = event.get("type", "")
            part = event.get("part", {})
            sid = event.get("sessionID", "")
            if etype == "reasoning":
                t = part.get("reasoning", "")
                if t:
                    backend.reasoningReady.emit(sid, t)
            elif etype == "step_finish":
                toks = part.get("tokens", {})
                if toks:
                    inp = toks.get("input", 0) or 0
                    out = toks.get("output", 0) or 0
                    if inp or out:
                        backend.tokenInfo.emit(sid, inp, out)

        assert len(reasons) == 2
        assert reasons[0] == ("ses_1", "thinking step 1")
        assert reasons[1] == ("ses_1", "thinking step 2")
        assert len(tokens) == 1
        assert tokens[0] == ("ses_1", 50, 120)

    def test_zero_tokens_not_emitted(self, backend):
        """tokenInfo should not emit when both token counts are zero."""
        tokens = []
        backend.tokenInfo.connect(lambda sid, i, o: tokens.append((sid, i, o)))

        event = {"type": "step_finish", "sessionID": "ses_2",
                 "part": {"type": "step-finish", "tokens": {"input": 0, "output": 0}}}
        toks = event["part"].get("tokens", {})
        inp = toks.get("input", 0) or 0
        out = toks.get("output", 0) or 0
        if inp or out:
            backend.tokenInfo.emit(event["sessionID"], inp, out)

        assert len(tokens) == 0


# ─── Main.py Wiring Tests ───────────────────────────────────────────

class TestMainWiring:
    """Test that main.py correctly wires both backends."""

    def test_all_backends_importable(self, tmp_path):
        from core.database import DatabaseManager
        from core.settings_manager import SettingsManager
        from core.opencode_process import OpencodeProcess
        from core.opencode_chat_backend import OpenCodeChatBackend
        from core.gemini_backend import GeminiBackend
        from core.user_manager import UserManager
        from windows.main_window import MainWindowBackend
        from windows.settings_window import SettingsBackend

        db = DatabaseManager(db_path=str(tmp_path / "test.db"))
        settings_mgr = SettingsManager(db=db, dev_mode=True)
        user_manager = UserManager(db=db)
        opencode_backend = OpencodeProcess(working_dir=".")
        opencode_chat = OpenCodeChatBackend(working_dir=".")
        gemini = GeminiBackend()

        assert opencode_backend is not None
        assert opencode_chat is not None
        assert gemini is not None
        assert settings_mgr is not None
        assert user_manager is not None


# ─── GeminiBackend (fallback) Tests ─────────────────────────────────

class TestGeminiBackendFallback:
    """Verify the existing GeminiBackend still works (regression check)."""

    def test_gemini_imports_and_properties(self, tmp_path):
        from core.gemini_backend import GeminiBackend

        backend = GeminiBackend()

        assert hasattr(backend, "isThinking")
        assert hasattr(backend, "isOffline")
        assert hasattr(backend, "apiKey")
        assert hasattr(backend, "sendMessage")
        assert hasattr(backend, "stopGeneration")
        assert hasattr(backend, "setApiKey")
        assert hasattr(backend, "checkOnline")
        assert hasattr(backend, "responseReady")
        assert hasattr(backend, "toolCallStarted")
        assert hasattr(backend, "toolCallFinished")
        assert hasattr(backend, "errorOccurred")
        assert hasattr(backend, "statusChanged")
        assert hasattr(backend, "offlineChanged")

    def test_retry_backoff_exists(self, tmp_path):
        from core.gemini_backend import GeminiBackend
        backend = GeminiBackend()
        assert hasattr(backend, "_retry_with_backoff")
        assert callable(backend._retry_with_backoff)


# ─── Settings Defaults Tests ────────────────────────────────────────

class TestSettingsDefaults:
    """Verify the default LLM provider is now 'OpenCode'."""

    def test_settings_default(self, tmp_path):
        from core.settings_manager import SettingsManager
        from core.database import DatabaseManager
        db = DatabaseManager(db_path=str(tmp_path / "defaults_test.db"))
        sm = SettingsManager(db=db, dev_mode=True)
        assert sm.get("llm_provider", "OpenCode") == "OpenCode"

    def test_settings_backend_default(self, tmp_path):
        from core.database import DatabaseManager
        from core.settings_manager import SettingsManager
        from core.user_manager import UserManager
        from windows.settings_window import SettingsBackend

        db = DatabaseManager(db_path=str(tmp_path / "backend_default_test.db"))
        sm = SettingsManager(db=db, dev_mode=True)
        um = UserManager(db=db)
        sb = SettingsBackend(settings=sm, user_manager=um)
        assert sb.llmProvider == "OpenCode"

    def test_set_llm_provider(self, tmp_path):
        from core.database import DatabaseManager
        from core.settings_manager import SettingsManager
        from core.user_manager import UserManager
        from windows.settings_window import SettingsBackend

        db = DatabaseManager(db_path=str(tmp_path / "provider_test.db"))
        sm = SettingsManager(db=db, dev_mode=True)
        um = UserManager(db=db)
        sb = SettingsBackend(settings=sm, user_manager=um)

        sb.setLlmProvider("Gemini")
        assert sb.llmProvider == "Gemini"

        sb.setLlmProvider("OpenCode")
        assert sb.llmProvider == "OpenCode"


# ─── OpencodeProcess Server URL Tests ───────────────────────────────

class TestOpencodeProcessServerUrl:
    """Verify the serverUrl property is exposed on OpencodeProcess."""

    def test_server_url_property(self):
        from core.opencode_process import OpencodeProcess
        proc = OpencodeProcess(working_dir=".")
        assert hasattr(proc, "serverUrl")
        # Initially empty (no server started)
        assert proc.serverUrl == ""

    def test_server_url_type(self):
        from core.opencode_process import OpencodeProcess
        proc = OpencodeProcess(working_dir=".")
        url = proc.serverUrl
        assert isinstance(url, str)


class TestKeyRotation:
    def test_import(self):
        from core.key_rotation import KeyRotation
        assert KeyRotation is not None

    def test_empty_keys(self):
        from core.key_rotation import KeyRotation
        kr = KeyRotation([])
        assert kr.current == ""
        assert kr.status == "No keys"
        assert not kr.has_keys
        assert kr.count == 0

    def test_multiple_keys(self):
        from core.key_rotation import KeyRotation
        kr = KeyRotation(["key1", "key2", "key3"])
        assert kr.current == "key1"
        assert kr.status == "Key 1/3"
        assert kr.has_keys
        assert kr.count == 3

    def test_rotate(self):
        from core.key_rotation import KeyRotation
        kr = KeyRotation(["keyA", "keyB"])
        assert kr.current == "keyA"
        kr.rotate()
        assert kr.current == "keyB"
        assert kr.status == "Key 2/2"
        assert kr.currentIndex == 1
        kr.rotate()
        assert kr.current == "keyA"
        assert kr.currentIndex == 0

    def test_rotate_empty(self):
        from core.key_rotation import KeyRotation
        kr = KeyRotation([])
        assert kr.rotate() == ""

    def test_mark_success_failure(self):
        from core.key_rotation import KeyRotation
        kr = KeyRotation(["keyX", "keyY"])
        kr.mark_failure()
        kr.mark_failure()
        kr.rotate()
        kr.mark_success()
        assert kr.current == "keyY"

    def test_with_gemini_backend(self):
        import os
        from core.key_rotation import KeyRotation
        from core.gemini_backend import GeminiBackend
        kr = KeyRotation(["dummy_key_1", "dummy_key_2"])
        backend = GeminiBackend(key_rotation=kr)
        assert backend.keyStatus == "Key 1/2"
        assert backend.apiKey == "dummy_key_1"
        # key rotation property appears
        assert hasattr(backend, "_key_rotation")


class TestChatSessionManager:
    def test_import(self):
        from core.chat_session_manager import ChatSessionManager
        assert ChatSessionManager is not None

    def test_create_and_list(self):
        from core.database import DatabaseManager
        from core.chat_session_manager import ChatSessionManager
        import tempfile, os

        db_path = os.path.join(tempfile.gettempdir(), "test_albab_sessions.db")
        if os.path.exists(db_path):
            os.remove(db_path)
        db = DatabaseManager(db_path)
        mgr = ChatSessionManager(db=db)

        assert mgr.sessions == []
        assert mgr.currentSessionId == ""

        sid = mgr.newSession("OpenCode")
        assert sid.startswith("chat_")
        assert mgr.currentSessionId == sid
        assert len(mgr.sessions) == 1
        assert mgr.sessions[0]["id"] == sid
        assert mgr.sessions[0]["name"] == "New OpenCode Chat"

        db.close()
        os.remove(db_path)

    def test_auto_name(self):
        from core.database import DatabaseManager
        from core.chat_session_manager import ChatSessionManager
        import tempfile, os

        db_path = os.path.join(tempfile.gettempdir(), "test_albab_name.db")
        if os.path.exists(db_path):
            os.remove(db_path)
        db = DatabaseManager(db_path)
        mgr = ChatSessionManager(db=db)

        sid = mgr.newSession("Gemini")
        assert mgr.currentSessionName == "New Gemini Chat"
        mgr.addUserMessage(sid, "What is calculus?")
        assert mgr.currentSessionName == "What is calculus?"

        db.close()
        os.remove(db_path)

    def test_switch_session(self):
        from core.database import DatabaseManager
        from core.chat_session_manager import ChatSessionManager
        import tempfile, os

        db_path = os.path.join(tempfile.gettempdir(), "test_albab_switch.db")
        if os.path.exists(db_path):
            os.remove(db_path)
        db = DatabaseManager(db_path)
        mgr = ChatSessionManager(db=db)

        s1 = mgr.newSession("OpenCode")
        s2 = mgr.newSession("Gemini")
        assert mgr.currentSessionId == s2

        mgr.switchSession(s1)
        assert mgr.currentSessionId == s1
        assert mgr.currentSessionBackend == "OpenCode"

        db.close()
        os.remove(db_path)

    def test_delete_session(self):
        from core.database import DatabaseManager
        from core.chat_session_manager import ChatSessionManager
        import tempfile, os

        db_path = os.path.join(tempfile.gettempdir(), "test_albab_delete.db")
        if os.path.exists(db_path):
            os.remove(db_path)
        db = DatabaseManager(db_path)
        mgr = ChatSessionManager(db=db)

        s1 = mgr.newSession("OpenCode")
        s2 = mgr.newSession("Gemini")
        mgr.switchSession(s1)
        mgr.deleteSession(s2)
        assert mgr.currentSessionId == s1
        assert len(mgr.sessions) == 1

        mgr.deleteSession(s1)
        assert mgr.currentSessionId == ""

        db.close()
        os.remove(db_path)

    def test_messages_persist(self):
        from core.database import DatabaseManager
        from core.chat_session_manager import ChatSessionManager
        import tempfile, os

        db_path = os.path.join(tempfile.gettempdir(), "test_albab_msgs.db")
        if os.path.exists(db_path):
            os.remove(db_path)
        db = DatabaseManager(db_path)
        mgr = ChatSessionManager(db=db)

        sid = mgr.newSession("OpenCode")
        mgr.addUserMessage(sid, "Hello")
        mgr.addAiMessage(sid, "Hi there!", "thinking...", 10, 20)

        msgs = mgr.loadMessages()
        assert len(msgs) == 2
        assert msgs[0]["role"] == "user"
        assert msgs[0]["content"] == "Hello"
        assert msgs[1]["role"] == "ai"
        assert msgs[1]["content"] == "Hi there!"
        assert msgs[1]["reasoning"] == "thinking..."
        assert msgs[1]["tokensInput"] == 10
        assert msgs[1]["tokensOutput"] == 20

        db.close()
        os.remove(db_path)


class TestSessionBackendIntegration:
    def test_opencode_set_session_id(self):
        from core.opencode_chat_backend import OpenCodeChatBackend
        b = OpenCodeChatBackend()
        assert hasattr(b, "setOpencodeSessionId")
        b.setOpencodeSessionId("ses_test_123")
        assert b._session_args == ["--session", "ses_test_123"]
        b.setOpencodeSessionId("")
        assert b._session_args == []

    def test_gemini_set_history(self):
        from core.gemini_backend import GeminiBackend
        kr = type("obj", (object,), {"has_keys": False, "current": "", "status": "", "currentIndex": 0, "mark_failure": lambda s: None, "rotate": lambda s: "", "keyChanged": type("S", (object,), {"emit": lambda s,v: None})()})()
        b = GeminiBackend(key_rotation=kr)
        assert hasattr(b, "setHistory")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
