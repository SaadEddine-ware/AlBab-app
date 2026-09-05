import os
import sys

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from core.database import DatabaseManager
from core.settings_manager import SettingsManager

DEV_MODE = "--dev" in sys.argv
MODE_LABEL = " [DEV]" if DEV_MODE else ""

app = QGuiApplication(sys.argv)
app.setOrganizationName("AlBab")
app.setApplicationName("AlBab Student Hub" + MODE_LABEL)

_icon_path = os.path.join(
    getattr(sys, "_MEIPASS", os.path.dirname(__file__)),
    "assets", "app_icon.ico"
)
if os.path.isfile(_icon_path):
    app.setWindowIcon(QIcon(_icon_path))

engine = QQmlApplicationEngine()
engine.setOutputWarningsToStandardError(True)

_data_root = os.path.join(os.path.expanduser("~"), ".albab") if not DEV_MODE else os.path.join(os.path.dirname(__file__), "data-dev")
os.makedirs(_data_root, exist_ok=True)
settings_mgr = SettingsManager(
    db=DatabaseManager(db_path=os.path.join(_data_root, "app.db")),
    dev_mode=DEV_MODE,
)

settings_mgr._db.migrate_from_json(
    settings_path=os.path.join(os.path.dirname(__file__), "settings.dev.json" if DEV_MODE else "settings.json"),
    users_path=os.path.join(os.path.dirname(__file__), "data-dev" if DEV_MODE else "data", "users.json"),
)

from windows.main_window import MainWindowBackend
from windows.settings_window import SettingsBackend
from core.opencode_process import OpencodeProcess
from core.opencode_chat_backend import OpenCodeChatBackend
from core.user_manager import UserManager

user_manager = UserManager(db=settings_mgr._db)
user_manager.autoLogin()
main_backend = MainWindowBackend(settings=settings_mgr, user_manager=user_manager)
settings_backend = SettingsBackend(settings=settings_mgr, user_manager=user_manager)
opencode_wd = settings_mgr.data_dir if DEV_MODE else os.path.expanduser("~")
opencode_backend = OpencodeProcess(working_dir=opencode_wd)

engine.rootContext().setContextProperty("MainBackend", main_backend)
engine.rootContext().setContextProperty("SettingsBackend", settings_backend)
engine.rootContext().setContextProperty("OpencodeBackend", opencode_backend)
engine.rootContext().setContextProperty("DevMode", DEV_MODE)

from core.key_rotation import KeyRotation
from core.chat_session_manager import ChatSessionManager
from core.math_engine import MathEngine
from core.matrix_backend import MatrixBackend
from core.graph_backend import GraphBackend
from core.plot_backend import PlotBackend
from core.math_stack_backend import MathStackBackend
from core.mesh_backend import MeshBackend
from core.geo_utils import GeoUtils
from core.source_analyzer import SourceAnalyzer
from core.timeline_backend import TimelineBackend
from core.demographics_backend import DemographicsBackend
from core.map_backend import MapBackend
from core.undo_manager import UndoManager
from core.calculator_backend import CalculatorBackend
from core.export_backend import ExportBackend
from core.gemini_backend import GeminiBackend
from core.data_store import DataStore
from core.formula_library_backend import FormulaLibraryBackend
from core.tools_backend import ToolsBackend
from core.mindmap_backend import MindMapBackend

_gemini_key_rotation = KeyRotation(keys=settings_mgr.get("api_keys", []))

_math_engine = MathEngine()

backends = {
    "MathEngine": _math_engine,
    "MatrixBackend": MatrixBackend(),
    "GraphBackend": GraphBackend(),
    "PlotBackend": PlotBackend(),
    "MathStackBackend": MathStackBackend(),
    "MeshBackend": MeshBackend(),
    "GeoUtils": GeoUtils(),
    "SourceAnalyzer": SourceAnalyzer(db=settings_mgr._db),
    "TimelineBackend": TimelineBackend(),
    "DemographicsBackend": DemographicsBackend(),
    "MapBackend": MapBackend(),
    "UndoManager": UndoManager(),
    "CalculatorBackend": CalculatorBackend(db=settings_mgr._db),
    "ExportBackend": ExportBackend(),
    "ChatSessionManager": ChatSessionManager(db=settings_mgr._db, key_rotation=_gemini_key_rotation),
    "UserManager": user_manager,
    "GeminiBackend": GeminiBackend(key_rotation=_gemini_key_rotation),
    "KeyRotation": _gemini_key_rotation,
    "OpenCodeBackend": OpenCodeChatBackend(
        working_dir=opencode_wd,
        server_url=opencode_backend.serverUrl if opencode_backend.serverUrl else None,
    ),
    "DataStore": DataStore(db=settings_mgr._db),
    "FormulaLibraryBackend": FormulaLibraryBackend(),
    "ToolsBackend": ToolsBackend(math_engine=_math_engine),
    "MindMapBackend": MindMapBackend(key_rotation=_gemini_key_rotation),
}

# Cross-backend signal wiring: profile changes flow both ways
main_backend.profileChanged.connect(settings_backend.settingsChanged.emit)
settings_backend.settingsChanged.connect(main_backend.profileChanged.emit)

open_chat = backends["OpenCodeBackend"]
chat_mgr = backends["ChatSessionManager"]
open_chat.sessionIdReceived.connect(
    lambda sid: chat_mgr.setOpencodeSessionId(chat_mgr.currentSessionId, sid)
)

# Clean up stale empty sessions (those never renamed from default and with zero messages)
_stale = [s for s in chat_mgr.sessions if s["name"] == "New Chat"]
for s in _stale:
    _msgs = settings_mgr._db.get_chat_messages(s["id"])
    if not _msgs:
        chat_mgr.deleteSession(s["id"])

for name, backend in backends.items():
    engine.rootContext().setContextProperty(name, backend)

ui_dir = os.path.join(os.path.dirname(__file__), "ui")
engine.addImportPath(ui_dir)

qml_file = os.path.join(ui_dir, "main.qml")
engine.load(QUrl.fromLocalFile(qml_file))

if not engine.rootObjects():
    print("FATAL: Failed to load QML application. Check QML syntax and backend imports.")
    sys.exit(-1)

opencode_backend.startProcess()

def _on_quit():
    try:
        opencode_backend.stopProcess()
        opencode_backend._stop_server()
        settings_mgr._db.close()
    except Exception:
        pass

app.aboutToQuit.connect(_on_quit)

print(f"AlBab{MODE_LABEL} — data dir: {settings_mgr.data_dir}")
print(f"AlBab{MODE_LABEL} — config: {settings_mgr.path}")

try:
    sys.exit(app.exec())
except SystemExit:
    raise
except Exception as e:
    print(f"Fatal error: {e}", file=sys.stderr)
    sys.exit(1)
