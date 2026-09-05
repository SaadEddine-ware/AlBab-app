import json
import os
import platform
import subprocess
import sys
import threading
import urllib.request
import urllib.error

from PySide6.QtCore import QObject, Signal, Slot, Property

from google import genai
from google.api_core.exceptions import ResourceExhausted

import time


class GeminiBackend(QObject):
    responseReady = Signal(str)
    toolCallStarted = Signal(str, str)
    toolCallFinished = Signal(str, str)
    errorOccurred = Signal(str)
    statusChanged = Signal(str)
    offlineChanged = Signal(bool)

    def __init__(self, key_rotation=None, parent=None):
        super().__init__(parent)
        self._key_rotation = key_rotation
        self._is_thinking = False
        self._api_key = self._resolve_key()
        self._is_offline = False
        self._client = None
        self._chat = None
        self._tools = self._define_tools()
        self._stop_event = threading.Event()
        self._init_lock = threading.Lock()
        self._user_context = ""
        self._context_dirty = False
        self._history_messages = []
        if self._api_key:
            self._init_client()

    def _resolve_key(self) -> str:
        if self._key_rotation and self._key_rotation.has_keys:
            return self._key_rotation.current
        return ""

    def _retry_with_backoff(self, fn, max_retries=5, base_delay=1):
        for attempt in range(max_retries):
            try:
                return fn()
            except ResourceExhausted:
                if attempt == max_retries - 1:
                    raise
                if self._key_rotation:
                    old_idx = self._key_rotation.currentIndex
                    self._key_rotation.mark_failure()
                    self._key_rotation.rotate()
                    self._api_key = self._key_rotation.current
                    rotated = self._key_rotation.currentIndex != old_idx
                    if rotated:
                        self.errorOccurred.emit(f"Rate limited on key {old_idx+1}. Rotated to key {self._key_rotation.currentIndex+1}.")
                        self._init_client()
                        self.statusChanged.emit("key_rotated")
                        delay = 0.5
                    else:
                        delay = base_delay * (2 ** attempt)
                        self.errorOccurred.emit(f"Rate limited. Retrying in {delay}s...")
                else:
                    delay = base_delay * (2 ** attempt)
                    self.errorOccurred.emit(f"Rate limited. Retrying in {delay}s...")
                time.sleep(delay)
        return None

    def _init_client(self, history=None):
        with self._init_lock:
            try:
                self._client = self._retry_with_backoff(
                    lambda: genai.Client(api_key=self._api_key)
                )
                if not self._client:
                    raise Exception("Client creation failed after retries")

                tool_list = []
                for tool in self._tools:
                    props = {}
                    for k, v in tool.get("parameters", {}).get("properties", {}).items():
                        props[k] = genai.types.Schema(
                            type=genai.types.Type.STRING,
                            description=v.get("description", "")
                        )
                    tool_list.append(genai.types.Tool(
                        function_declarations=[genai.types.FunctionDeclaration(
                            name=tool["name"],
                            description=tool["description"],
                            parameters=genai.types.Schema(
                                type=genai.types.Type.OBJECT,
                                properties=props,
                                required=tool.get("parameters", {}).get("required", [])
                            )
                        )]
                    ))
                config_kwargs = {"tools": tool_list}
                if self._user_context:
                    config_kwargs["system_instruction"] = self._user_context
                gen_history = None
                if history:
                    gen_history = []
                    for msg in history:
                        role = "user" if msg["role"] == "user" else "model"
                        gen_history.append(
                            genai.types.Content(
                                role=role,
                                parts=[genai.types.Part(text=msg["content"])]
                            )
                        )
                create_kwargs = {"model": "gemini-2.5-flash", "config": genai.types.GenerateContentConfig(**config_kwargs)}
                if gen_history:
                    create_kwargs["history"] = gen_history
                self._chat = self._retry_with_backoff(
                    lambda: self._client.chats.create(**create_kwargs)
                )
                if not self._chat:
                    raise Exception("Chat creation failed after retries")
            except Exception as e:
                self._client = None
                self._chat = None
                self.errorOccurred.emit(f"Failed to initialize AI: {str(e)}")

    @Property(bool, notify=statusChanged)
    def isThinking(self):
        return self._is_thinking

    @Property(str, notify=statusChanged)
    def apiKey(self):
        return self._api_key

    @Property(str, notify=statusChanged)
    def keyStatus(self):
        if self._key_rotation:
            return self._key_rotation.status
        return "Single key"

    def _set_thinking(self, value):
        self._is_thinking = value
        try:
            self.statusChanged.emit("thinking" if value else "ready")
        except RuntimeError:
            pass

    def _define_tools(self):
        return [
            {
                "name": "calculate",
                "description": "Evaluate a mathematical expression. Use this for calculations like 2+2, sqrt(16), sin(3.14), etc.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "expression": {
                            "type": "string",
                            "description": "The math expression to evaluate"
                        }
                    },
                    "required": ["expression"]
                }
            },
            {
                "name": "solve_equation",
                "description": "Solve a mathematical equation for a variable. Example: solve x^2 + 3x - 4 = 0",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "equation": {
                            "type": "string",
                            "description": "The equation to solve"
                        }
                    },
                    "required": ["equation"]
                }
            },
            {
                "name": "run_python",
                "description": "Execute Python code on the user's computer. Use for file operations, data processing, installing packages, etc.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "code": {
                            "type": "string",
                            "description": "Python code to execute"
                        }
                    },
                    "required": ["code"]
                }
            },
            {
                "name": "read_file",
                "description": "Read the contents of a file on the user's computer",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Absolute path to the file"
                        }
                    },
                    "required": ["path"]
                }
            },
            {
                "name": "write_file",
                "description": "Write content to a file on the user's computer",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": {"type": "string", "description": "Absolute path to the file"},
                        "content": {"type": "string", "description": "Content to write"}
                    },
                    "required": ["path", "content"]
                }
            },
            {
                "name": "list_directory",
                "description": "List files and folders in a directory",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": {"type": "string", "description": "Directory path"}
                    },
                    "required": ["path"]
                }
            },
            {
                "name": "get_system_info",
                "description": "Get information about the user's computer (OS, CPU, RAM, disk space)"
            },
            {
                "name": "run_command",
                "description": "Run a shell command on the user's computer",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "command": {"type": "string", "description": "Shell command to execute"}
                    },
                    "required": ["command"]
                }
            },
        ]

    def _execute_tool(self, name: str, args: dict) -> str:
        try:
            if name == "calculate":
                from core.math_engine import MathEngine
                engine = MathEngine()
                return engine.evaluate(args.get("expression", ""))

            elif name == "solve_equation":
                from core.math_engine import MathEngine
                engine = MathEngine()
                return engine.solve(args.get("equation", ""))

            elif name == "run_python":
                code = args.get("code", "")
                result = subprocess.run(
                    [sys.executable, "-c", code],
                    capture_output=True, text=True, timeout=30
                )
                output = result.stdout
                if result.stderr:
                    output += "\n[stderr] " + result.stderr
                return output or "(no output)"

            elif name == "read_file":
                path = args.get("path", "")
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read(10000)
                    if len(content) == 10000:
                        content += "\n... (truncated)"
                    return content

            elif name == "write_file":
                path = args.get("path", "")
                content = args.get("content", "")
                dirn = os.path.dirname(path)
                if dirn:
                    os.makedirs(dirn, exist_ok=True)
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)
                return f"File written to {path}"

            elif name == "list_directory":
                path = args.get("path", ".")
                items = os.listdir(path)
                return "\n".join(items[:100])

            elif name == "get_system_info":
                info = {
                    "os": platform.system(),
                    "os_version": platform.version(),
                    "machine": platform.machine(),
                    "processor": platform.processor(),
                    "python": platform.python_version(),
                }
                return json.dumps(info, indent=2)

            elif name == "run_command":
                command = args.get("command", "")
                result = subprocess.run(
                    command, shell=True, capture_output=True, text=True, timeout=30
                )
                output = result.stdout
                if result.stderr:
                    output += "\n[stderr] " + result.stderr
                return output or "(no output)"

            else:
                return f"Unknown tool: {name}"

        except Exception as e:
            return f"Error executing {name}: {str(e)}"

    @Slot(str)
    def sendMessage(self, text: str):
        if not text.strip():
            return

        self._set_thinking(True)
        self._stop_event.clear()

        def run():
            try:
                if self._context_dirty:
                    self._init_client(history=self._history_messages)
                    self._context_dirty = False
                if not self._client or not self._chat:
                    self._init_client()
                if not self._client or not self._chat:
                    self.errorOccurred.emit("AI not available. Check API key in settings.")
                    self._set_thinking(False)
                    return

                response = self._retry_with_backoff(
                    lambda chat=self._chat: chat.send_message(text)
                )
                if response is None:
                    raise Exception("Message send failed after retries")

                for i in range(10):
                    if self._stop_event.is_set():
                        break

                    if response.candidates and response.candidates[0].content:
                        parts = response.candidates[0].content.parts
                        has_function_call = False

                        for part in parts:
                            if hasattr(part, 'function_call') and part.function_call:
                                fc = part.function_call
                                tool_name = fc.name
                                tool_args = dict(fc.args) if fc.args else {}

                                self.toolCallStarted.emit(tool_name, json.dumps(tool_args))
                                result = self._execute_tool(tool_name, tool_args)
                                self.toolCallFinished.emit(tool_name, result)

                                response = self._retry_with_backoff(
                                    lambda: self._chat.send_message(
                                        genai.types.Part(
                                            function_response=genai.types.FunctionResponse(
                                                name=tool_name,
                                                response={"result": result}
                                            )
                                        )
                                    )
                                )
                                if response is None:
                                    raise Exception("Function response send failed after retries")
                                has_function_call = True

                        if not has_function_call:
                            text_parts = []
                            for part in parts:
                                if hasattr(part, 'text') and part.text:
                                    text_parts.append(part.text)
                            if text_parts:
                                self.responseReady.emit("\n".join(text_parts))
                            break
                    else:
                        break

            except Exception as e:
                self.errorOccurred.emit(f"Error: {str(e)}")
            finally:
                self._set_thinking(False)

        threading.Thread(target=run, daemon=True).start()

    @Slot()
    def stopGeneration(self):
        self._stop_event.set()

    @Slot(str)
    def setApiKey(self, key: str):
        self._api_key = key
        if self._key_rotation and key:
            self._key_rotation.add_key(key)
        self.statusChanged.emit("key_updated")
        def _init_thread():
            self._init_client()
            self.statusChanged.emit("key_updated")
        threading.Thread(target=_init_thread, daemon=True).start()

    @Slot(str)
    def setUserContext(self, context: str):
        self._user_context = context
        self._context_dirty = True

    @Slot(str)
    def setHistory(self, messages_json: str):
        try:
            self._history_messages = json.loads(messages_json) if messages_json else []
        except (json.JSONDecodeError, TypeError):
            self._history_messages = []
        self._context_dirty = False
        def _init_thread():
            self._init_client(history=self._history_messages)
        threading.Thread(target=_init_thread, daemon=True).start()

    @Slot(result=bool)
    def checkOnline(self) -> bool:
        try:
            urllib.request.urlopen("https://www.google.com", timeout=3)
            self._is_offline = False
            self.offlineChanged.emit(False)
            return True
        except (urllib.error.URLError, OSError):
            self._is_offline = True
            self.offlineChanged.emit(True)
            return False

    @Property(bool, notify=offlineChanged)
    def isOffline(self):
        return self._is_offline
