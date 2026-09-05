import os
import platform
import subprocess
import threading
import re
import time
import socket

from PySide6.QtCore import QObject, Signal, Slot, Property

OPENCODE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "bin",
    "opencode.exe" if platform.system() == "Windows" else "opencode"
)


def strip_ansi(text):
    return re.sub(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])", "", text)


def _find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class OpencodeProcess(QObject):
    outputReceived = Signal(str)
    processStarted = Signal()
    stateChanged = Signal()
    agentStatus = Signal(str)

    def __init__(self, working_dir=None, parent=None):
        super().__init__(parent)
        self._running = False
        self._is_processing = False
        self._working_dir = working_dir or os.path.expanduser("~")
        self._current_proc = None
        self._stop_event = threading.Event()
        self._agent_mode = "quick"
        self._lock = threading.Lock()
        self._server_proc = None
        self._server_port = None
        self._server_ready = False

    @Property(bool, notify=stateChanged)
    def running(self):
        return self._running

    @Property(str, notify=stateChanged)
    def serverUrl(self):
        if self._server_ready and self._server_port:
            return f"http://127.0.0.1:{self._server_port}"
        return ""

    @Property(bool, notify=stateChanged)
    def isProcessing(self):
        return self._is_processing

    @Property(str, notify=stateChanged)
    def agentMode(self):
        return self._agent_mode

    def _emit_safe(self, signal, *args):
        try:
            signal.emit(*args)
        except RuntimeError:
            pass

    def _set_property(self, name, value):
        setattr(self, f"_{name}", value)
        try:
            self.stateChanged.emit()
        except RuntimeError:
            pass

    def _start_server(self):
        with self._lock:
            if self._server_proc and self._server_proc.poll() is None:
                return True

        self._server_port = _find_free_port()

        kwargs = {
            "stdout": subprocess.DEVNULL,
            "stderr": subprocess.DEVNULL,
            "cwd": self._working_dir,
            "bufsize": 0,
        }
        if platform.system() == "Windows":
            kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW

        try:
            self._server_proc = subprocess.Popen(
                [OPENCODE_PATH, "serve", "--port", str(self._server_port)],
                **kwargs
            )
            self._wait_for_server()
            return self._server_ready
        except Exception as e:
            self._emit_safe(self.outputReceived, f"[AlBab] Server start failed: {e}\n")
            return False

    def _wait_for_server(self, timeout=30):
        start = time.time()
        while time.time() - start < timeout:
            if self._server_proc and self._server_proc.poll() is not None:
                break
            try:
                with socket.create_connection(("127.0.0.1", self._server_port), timeout=1):
                    self._server_ready = True
                    return
            except (ConnectionRefusedError, OSError):
                time.sleep(0.5)
        self._server_ready = False

    def _stop_server(self):
        if self._server_proc:
            try:
                self._server_proc.terminate()
                self._server_proc.wait(timeout=5)
            except Exception:
                try:
                    self._server_proc.kill()
                except Exception:
                    pass
            self._server_proc = None
            self._server_ready = False

    @Slot()
    def startProcess(self):
        self._set_property("running", True)
        self._set_property("is_processing", False)
        self._emit_safe(self.processStarted)
        self._emit_safe(self.outputReceived, "[AlBab] Starting AI server...\n")

        def init_server():
            if self._start_server():
                self._emit_safe(self.outputReceived, "[AlBab] AI ready!\n")
            else:
                self._emit_safe(self.outputReceived, "[AlBab] AI ready (direct mode).\n")

        threading.Thread(target=init_server, daemon=True).start()

    @Slot(str)
    def setAgentMode(self, mode):
        self._agent_mode = mode
        try:
            self.stateChanged.emit()
        except RuntimeError:
            pass

    @Slot(str)
    def sendInput(self, text):
        if not text.strip():
            return

        self._emit_safe(self.outputReceived, "> " + text + "\n")

        agent_mode = self._agent_mode

        if agent_mode == "quick":
            self._emit_safe(self.outputReceived, "[AlBab] Quick mode...\n")
            self._emit_safe(self.agentStatus, "planning")
        else:
            self._emit_safe(self.outputReceived, "[AlBab] Full mode...\n")
            self._emit_safe(self.agentStatus, "building")

        self._set_property("is_processing", True)
        self._stop_event.clear()

        def run():
            try:
                if self._server_ready and self._server_port:
                    attach_url = f"http://127.0.0.1:{self._server_port}"
                    if agent_mode == "quick":
                        cmd = [OPENCODE_PATH, "run", "--agent", "build", "--attach", attach_url, text]
                    else:
                        cmd = [OPENCODE_PATH, "run", "--attach", attach_url, text]
                    timeout = 120
                else:
                    if agent_mode == "quick":
                        cmd = [OPENCODE_PATH, "run", "--agent", "build", text]
                    else:
                        cmd = [OPENCODE_PATH, "run", text]
                    timeout = 120

                kwargs = {
                    "stdout": subprocess.PIPE,
                    "stderr": subprocess.PIPE,
                    "cwd": self._working_dir,
                    "bufsize": 0,
                }
                if platform.system() == "Windows":
                    kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW

                proc = subprocess.Popen(cmd, **kwargs)
                with self._lock:
                    self._current_proc = proc

                stdout_data, stderr_data = proc.communicate(timeout=timeout)

                with self._lock:
                    self._current_proc = None

                if self._stop_event.is_set():
                    self._emit_safe(self.outputReceived, "[AlBab] Stopped.\n")
                    self._finish()
                    return

                out = stdout_data.decode("utf-8", errors="replace")
                out = strip_ansi(out).strip()
                err = strip_ansi(stderr_data.decode("utf-8", errors="replace")).strip()

                if out:
                    self._emit_safe(self.outputReceived, out + "\n")
                elif err:
                    clean_err = "\n".join([l for l in err.split("\n") if l.strip()])
                    if clean_err:
                        self._emit_safe(self.outputReceived, clean_err + "\n")
                    else:
                        self._emit_safe(self.outputReceived, "[AlBab] No response.\n")
                else:
                    self._emit_safe(self.outputReceived, "[AlBab] No response.\n")

                if proc.returncode != 0:
                    err_lines = [l for l in stderr_data.decode("utf-8", errors="replace").split("\n")
                                 if "level=INFO" not in l and l.strip()]
                    if err_lines:
                        self._emit_safe(self.outputReceived, "[stderr] " + "\n".join(err_lines[:3]) + "\n")

                self._finish()

            except subprocess.TimeoutExpired:
                with self._lock:
                    if self._current_proc:
                        try:
                            self._current_proc.kill()
                        except Exception:
                            pass
                    self._current_proc = None
                self._emit_safe(self.outputReceived, f"[AlBab] Timed out ({timeout}s).\n")
                self._finish()
            except FileNotFoundError:
                with self._lock:
                    self._current_proc = None
                self._emit_safe(self.outputReceived, "[AlBab] opencode not found in bin/.\n")
                self._finish()
            except Exception as e:
                with self._lock:
                    self._current_proc = None
                self._emit_safe(self.outputReceived, f"[AlBab] Error: {e}\n")
                self._finish()

        threading.Thread(target=run, daemon=True).start()

    def _finish(self):
        self._set_property("is_processing", False)
        self._emit_safe(self.agentStatus, "idle")

    @Slot()
    def stopProcess(self):
        self._stop_event.set()
        with self._lock:
            if self._current_proc:
                try:
                    self._current_proc.kill()
                except Exception:
                    pass
                self._current_proc = None
        self._finish()

    @Slot()
    def restartProcess(self):
        self.stopProcess()
        self._stop_server()
        self._set_property("running", True)
        self._emit_safe(self.processStarted)
        self._emit_safe(self.outputReceived, "[AlBab] AI restarted.\n")

        def restart():
            self._start_server()
            self._emit_safe(self.outputReceived, "[AlBab] Server ready.\n")
        threading.Thread(target=restart, daemon=True).start()
