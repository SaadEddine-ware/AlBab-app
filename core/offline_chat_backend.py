import json
import os
import platform
import re
import subprocess
import sys
import threading
from collections import Counter
from math import sqrt, sin, cos, tan, log, log10, exp, pi, e

from PySide6.QtCore import QObject, Signal, Slot, Property

try:
    from core.math_engine import MathEngine
    _HAS_MATH_ENGINE = True
except ImportError:
    _HAS_MATH_ENGINE = False


class OfflineChatBackend(QObject):
    """
    Local-only chat backend that works without any API keys.
    Uses rule-based responses + local tools (math, files, system).
    """
    responseReady = Signal(str)
    toolCallStarted = Signal(str, str)
    toolCallFinished = Signal(str, str)
    errorOccurred = Signal(str)
    statusChanged = Signal(str)
    offlineChanged = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._is_thinking = False
        self._stop_event = threading.Event()
        self._user_context = ""
        self._history_messages = []
        self._math_engine = MathEngine() if _HAS_MATH_ENGINE else None
        self._init_keywords()

    def _init_keywords(self):
        """Keywords for intent classification."""
        self._math_keywords = {
            'calculate', 'compute', 'evaluate', 'solve', 'equation', 'math',
            'derivative', 'integral', 'limit', 'matrix', 'determinant',
            'sin', 'cos', 'tan', 'log', 'sqrt', 'power', '^', '+', '-', '*', '/',
            'حساب', 'احسب', 'حل', 'معادلة', 'رياضيات', 'مشتقة', 'تكامل'
        }
        self._file_keywords = {
            'read', 'write', 'list', 'file', 'directory', 'folder', 'create',
            'اقرأ', 'اكتب', 'قائمة', 'ملف', 'مجلد', 'إنشاء'
        }
        self._system_keywords = {
            'system', 'info', 'cpu', 'ram', 'disk', 'os', 'python', 'version',
            'نظام', 'معلومات', 'المعالج', 'الذاكرة', 'القرص'
        }
        self._greeting_keywords = {
            'hello', 'hi', 'hey', 'سلام', 'أهلا', 'مرحبا', 'صباح', 'مساء'
        }
        self._help_keywords = {
            'help', 'what can you do', 'commands', 'features', 'tools',
            'مساعدة', 'ماذا', 'أوامر', 'أدوات', 'مميزات'
        }

    @Property(bool, notify=statusChanged)
    def isThinking(self):
        return self._is_thinking

    @Property(str, notify=statusChanged)
    def mode(self):
        return "Offline (Local Tools Only)"

    def _set_thinking(self, value):
        self._is_thinking = value
        try:
            self.statusChanged.emit("thinking" if value else "ready")
        except RuntimeError:
            pass

    @Slot(str)
    def sendMessage(self, text: str):
        if not text.strip():
            return

        self._set_thinking(True)
        self._stop_event.clear()

        def run():
            try:
                response = self._process_message(text)
                if response and not self._stop_event.is_set():
                    self.responseReady.emit(response)
            except Exception as e:
                if not self._stop_event.is_set():
                    self.errorOccurred.emit(f"Error: {str(e)}")
            finally:
                if not self._stop_event.is_set():
                    self._set_thinking(False)

        threading.Thread(target=run, daemon=True).start()

    def _process_message(self, text: str) -> str:
        """Process message and return response."""
        text_lower = text.lower().strip()

        # Greetings
        if any(kw in text_lower for kw in self._greeting_keywords):
            return self._greeting_response()

        # Help
        if any(kw in text_lower for kw in self._help_keywords):
            return self._help_response()

        # Math expressions
        if self._looks_like_math(text):
            return self._handle_math(text)

        # File operations
        if any(kw in text_lower for kw in self._file_keywords):
            return self._handle_file_ops(text)

        # System info
        if any(kw in text_lower for kw in self._system_keywords):
            return self._handle_system_info(text)

        # General conversation - rule-based responses
        return self._general_response(text)

    def _looks_like_math(self, text: str) -> bool:
        """Detect if text looks like a math expression."""
        # Contains numbers and operators
        has_numbers = bool(re.search(r'\d', text))
        has_operators = bool(re.search(r'[\+\-\*\/\^\(\)\=]', text))
        has_math_words = any(kw in text.lower() for kw in self._math_keywords)
        return has_numbers and (has_operators or has_math_words)

    def _handle_math(self, text: str) -> str:
        """Handle math queries using local MathEngine."""
        try:
            if _HAS_MATH_ENGINE and self._math_engine:
                # Check if it's an equation
                if '=' in text and not text.strip().startswith('='):
                    result = self._math_engine.solve(text)
                    return f"🔢 **Solution:**\n{result}"
                else:
                    result = self._math_engine.evaluate(text)
                    return f"🔢 **Result:**\n{result}"
        except Exception as e:
            pass

        # Fallback: try python eval for simple expressions
        try:
            safe_expr = re.sub(r'[^0-9\+\-\*\/\.\(\)\s]', '', text)
            if safe_expr.strip():
                result = eval(safe_expr)
                return f"🔢 **Result:**\n{result}"
        except:
            pass

        return "❌ Could not evaluate. Try: `2+2`, `sqrt(16)`, `sin(pi/2)`, or `x^2 - 4 = 0`"

    def _handle_file_ops(self, text: str) -> str:
        """Handle file operations via keywords."""
        text_lower = text.lower()

        if 'read' in text_lower or 'اقرأ' in text_lower:
            # Extract path
            match = re.search(r'(?:read|اقرأ)\s+(.+)', text, re.IGNORECASE)
            if match:
                path = match.group(1).strip().strip('"\'')
                return self._read_file(path)

        if 'write' in text_lower or 'اكتب' in text_lower:
            match = re.search(r'(?:write|اكتب)\s+(.+?)\s+(?:to|في|into|إلى)\s+(.+)', text, re.IGNORECASE)
            if match:
                content = match.group(1).strip()
                path = match.group(2).strip().strip('"\'')
                return self._write_file(path, content)

        if 'list' in text_lower or 'قائمة' in text_lower:
            match = re.search(r'(?:list|قائمة)\s+(.+)', text, re.IGNORECASE)
            path = match.group(1).strip().strip('"\'') if match else "."
            return self._list_directory(path)

        return "📁 **File operations:**\n- `read /path/to/file` — read file\n- `write \"content\" to /path/to/file` — write file\n- `list /path/to/dir` — list directory"

    def _read_file(self, path: str) -> str:
        try:
            path = os.path.expanduser(path)
            with open(path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read(5000)
                if len(content) == 5000:
                    content += "\n... (truncated)"
            return f"📄 **File: {path}**\n```\n{content}\n```"
        except Exception as e:
            return f"❌ Error reading file: {e}"

    def _write_file(self, path: str, content: str) -> str:
        try:
            path = os.path.expanduser(path)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            return f"✅ File written to {path}"
        except Exception as e:
            return f"❌ Error writing file: {e}"

    def _list_directory(self, path: str) -> str:
        try:
            path = os.path.expanduser(path)
            items = os.listdir(path)
            items.sort()
            output = [f"📁 **Directory: {path}** ({len(items)} items)"]
            for item in items[:50]:
                full = os.path.join(path, item)
                prefix = "📁" if os.path.isdir(full) else "📄"
                output.append(f"  {prefix} {item}")
            if len(items) > 50:
                output.append(f"  ... and {len(items) - 50} more")
            return "\n".join(output)
        except Exception as e:
            return f"❌ Error listing directory: {e}"

    def _handle_system_info(self, text: str) -> str:
        info = {
            "OS": platform.system(),
            "OS Version": platform.version(),
            "Machine": platform.machine(),
            "Processor": platform.processor(),
            "Python": platform.python_version(),
        }
        try:
            import psutil
            info["CPU Cores"] = psutil.cpu_count()
            info["RAM (GB)"] = round(psutil.virtual_memory().total / (1024**3), 1)
            info["Disk Free (GB)"] = round(psutil.disk_usage('/').free / (1024**3), 1)
        except ImportError:
            pass

        lines = ["💻 **System Info:**"]
        for k, v in info.items():
            lines.append(f"  • **{k}:** {v}")
        return "\n".join(lines)

    def _greeting_response(self) -> str:
        return (
            "👋 **مرحبا!** I'm running in **Offline Mode** (local tools only).\n\n"
            "I can help with:\n"
            "• 🔢 **Math** — `2+2`, `sqrt(16)`, `sin(pi/2)`, `x^2 - 4 = 0`\n"
            "• 📁 **Files** — `read file.txt`, `write \"hello\" to test.txt`, `list ~`\n"
            "• 💻 **System** — `system info`\n"
            "• 💬 **Chat** — basic conversation\n\n"
            "Type `help` for more, or ask me anything!"
        )

    def _help_response(self) -> str:
        return (
            "📖 **Offline Mode Help**\n\n"
            "**Math:**\n"
            "  `2 + 3 * 4` → 14\n"
            "  `sqrt(64)` → 8\n"
            "  `sin(pi/2)` → 1\n"
            "  `x^2 - 5x + 6 = 0` → x = 2, 3\n"
            "  `matrix [[1,2],[3,4]] det` → -2\n\n"
            "**Files:**\n"
            "  `read ~/file.txt`\n"
            "  `write \"content\" to ~/new.txt`\n"
            "  `list ~/Documents`\n\n"
            "**System:**\n"
            "  `system info`\n\n"
            "**Note:** No AI features (Gemini/Groq) in offline mode. "
            "Add valid API keys in Settings to enable AI chat."
        )

    def _general_response(self, text: str) -> str:
        """Rule-based general responses."""
        text_lower = text.lower()

        # Arabic responses
        arabic_responses = {
            'كيف حالك': "بخير، شكراً! وكيف يمكنني مساعدتك اليوم؟",
            'شكرا': "العفو! هل هناك شيء آخر تحتاج مساعدة فيه؟",
            'باي': "مع السلامة! 👋",
            'وداعا': "إلى اللقاء!",
            'السلام عليكم': "وعليكم السلام ورحمة الله وبركاته! كيف أساعدك؟",
        }
        for key, resp in arabic_responses.items():
            if key in text_lower:
                return resp

        # English responses
        if any(w in text_lower for w in ['how are you', 'how r u']):
            return "I'm doing great! Running locally with no API keys needed. How can I help?"
        if any(w in text_lower for w in ['thank', 'thanks']):
            return "You're welcome! 😊"
        if any(w in text_lower for w in ['bye', 'goodbye', 'see you']):
            return "Goodbye! Come back anytime. 👋"
        if 'name' in text_lower:
            return "I'm AlBab Offline Assistant — your local study companion."

        # Default
        return (
            "🤔 I'm in **Offline Mode** — no AI brain, just local tools.\n\n"
            "Try:\n"
            "• `calculate 2+2` or `sqrt(16)`\n"
            "• `solve x^2 - 4 = 0`\n"
            "• `read ~/file.txt`\n"
            "• `system info`\n"
            "• `help` for full list\n\n"
            "Or add a **Gemini API key** in Settings → API Keys to enable AI chat."
        )

    @Slot()
    def stopGeneration(self):
        self._stop_event.set()

    @Slot(str)
    def setUserContext(self, context: str):
        self._user_context = context

    @Slot(str)
    def setHistory(self, messages_json: str):
        try:
            self._history_messages = json.loads(messages_json) if messages_json else []
        except (json.JSONDecodeError, TypeError):
            self._history_messages = []

    @Slot(result=bool)
    def checkOnline(self) -> bool:
        self.offlineChanged.emit(True)
        return False

    @Property(bool, notify=offlineChanged)
    def isOffline(self):
        return True
