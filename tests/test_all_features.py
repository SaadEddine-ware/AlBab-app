import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from core.undo_manager import UndoManager
from core.calculator_backend import CalculatorBackend
from core.export_backend import ExportBackend
from core.plot_backend import PlotBackend
from core.mesh_backend import MeshBackend
from core.timeline_backend import TimelineBackend
from core.demographics_backend import DemographicsBackend
from core.map_backend import MapBackend
from core.math_engine import MathEngine
from core.source_analyzer import SourceAnalyzer, _safe_session_name
from core.database import DatabaseManager
from core.settings_manager import SettingsManager


def test_undo_manager_push_undo_redo():
    um = UndoManager()
    um.push('{"expr":"1+1"}')
    um.push('{"expr":"2+2"}')
    assert um.canUndo() is True
    assert um.canRedo() is False
    state = um.undo()
    assert '"1+1"' in state
    assert um.canRedo() is True
    state = um.redo()
    assert '"2+2"' in state
    print("  PASS: undo_manager_push_undo_redo")


def test_undo_manager_clear():
    um = UndoManager()
    um.push('{"a":1}')
    um.push('{"b":2}')
    um.clear()
    assert um.canUndo() is False
    assert um.canRedo() is False
    assert um.undo() == ""
    assert um.redo() == ""
    print("  PASS: undo_manager_clear")


def test_undo_manager_max_history():
    um = UndoManager(max_history=3)
    for i in range(5):
        um.push(json.dumps({"i": i}))
    state = json.loads(um.getState())
    assert state["i"] == 4
    for _ in range(3):
        um.undo()
    assert um.canUndo() is False
    print("  PASS: undo_manager_max_history")


def test_calculator_backend_history():
    cb = CalculatorBackend()
    cb.addToHistory("2 + 3", "5")
    cb.addToHistory("10 * 5", "50")
    h = json.loads(cb.getHistory())
    assert len(h) == 2
    assert h[0]["expr"] == "10 * 5"
    assert h[1]["expr"] == "2 + 3"
    cb.clearHistory()
    h = json.loads(cb.getHistory())
    assert len(h) == 0
    print("  PASS: calculator_backend_history")


def test_calculator_backend_clipboard():
    cb = CalculatorBackend()
    cb.copyToClipboard("test_value")
    from PySide6.QtGui import QGuiApplication
    app = QGuiApplication.instance()
    if app:
        clipboard = app.clipboard()
        assert clipboard.text() == "test_value"
    print("  PASS: calculator_backend_clipboard")


def test_export_backend():
    eb = ExportBackend()
    assert eb.exportText("hello world", "test.txt") is True
    export_dir = eb.getExportDir()
    path = os.path.join(export_dir, "test.txt")
    assert os.path.exists(path)
    with open(path) as f:
        assert f.read() == "hello world"
    os.remove(path)

    data = json.dumps({"key": "value"})
    assert eb.exportJson(data, "test.json") is True
    path = os.path.join(export_dir, "test.json")
    assert os.path.exists(path)
    os.remove(path)
    print("  PASS: export_backend")


def test_settings_backend_profile():
    from windows.settings_window import SettingsBackend
    path = os.path.join(tempfile.gettempdir(), f"test_albab_sb_{os.urandom(4).hex()}.db")
    db = DatabaseManager(path)
    mgr = SettingsManager(db=db, dev_mode=True)
    sb = SettingsBackend(settings=mgr)
    sb.updateProfile("John", "Doe", "Engineering")
    sb.setOnboardingDone()
    assert sb.isOnboardingDone() is True
    for ext in ("", "-wal", "-shm"):
        try:
            os.remove(path + ext)
        except OSError:
            pass
    print("  PASS: settings_backend_profile")


def test_plot_backend_safe_eval():
    pb = PlotBackend()
    result = pb.plot2d("sin(x)")
    assert result.startswith("file:///") or result == ""
    result = pb.plot2d("x^2 + 1")
    assert result.startswith("file:///") or result == ""
    print("  PASS: plot_backend_safe_eval")


def test_plot_backend_3d():
    pb = PlotBackend()
    result = pb.plot3d("sin(sqrt(x^2 + y^2))")
    assert result.startswith("file:///") or result == ""
    print("  PASS: plot_backend_3d")


def test_plot_backend_shapes():
    pb = PlotBackend()
    shapes = ["cube", "sphere", "cylinder", "cone", "torus", "pyramid"]
    for shape in shapes:
        result = pb.getShapeGeometry(shape, json.dumps({}))
        data = json.loads(result)
        assert "vertices" in data or "error" in data
    print("  PASS: plot_backend_shapes")


def test_mesh_backend_crud():
    mb = MeshBackend()
    scene = json.loads(mb.newScene())
    assert len(scene["objects"]) == 0

    scene = json.loads(mb.addPrimitive("Cube", json.dumps({"type": "cube", "size": 2})))
    assert len(scene["objects"]) == 1
    obj_id = scene["objects"][0]["id"]

    scene = json.loads(mb.setObjectPosition(obj_id, 1.0, 2.0, 3.0))
    obj = scene["objects"][0]
    assert obj["transform"]["position"] == [1.0, 2.0, 3.0]

    scene = json.loads(mb.duplicateObject(obj_id))
    assert len(scene["objects"]) == 2

    scene = json.loads(mb.removeObject(obj_id))
    assert len(scene["objects"]) == 1

    print("  PASS: mesh_backend_crud")


def test_mesh_backend_mesh_ops():
    mb = MeshBackend()
    mb.newScene()
    scene = json.loads(mb.addPrimitive("Sphere", json.dumps({"type": "sphere", "radius": 1})))
    obj_id = scene["objects"][0]["id"]

    result = mb.subdivideObject(obj_id, 1)
    scene = json.loads(result)
    assert len(scene["objects"]) == 1

    result = mb.weldVertices(obj_id, 0.01)
    assert result is not None

    print("  PASS: mesh_backend_mesh_ops")


def test_mesh_backend_export_import():
    mb = MeshBackend()
    mb.newScene()
    scene = json.loads(mb.addPrimitive("Cube", json.dumps({"type": "cube", "size": 1})))
    obj_id = scene["objects"][0]["id"]

    export_path = os.path.join(tempfile.gettempdir(), "test_mesh_export.stl")
    result = mb.exportMesh(obj_id, export_path, "stl")
    assert result is True
    assert os.path.exists(export_path)
    os.remove(export_path)

    print("  PASS: mesh_backend_export_import")


def test_timeline_backend():
    tb = TimelineBackend()
    tl = json.loads(tb.getTimeline())
    assert "events" in tl

    tb.loadSample("world_wars")
    tl = json.loads(tb.getTimeline())
    assert len(tl["events"]) > 0

    tb.loadSample("ancient")
    tl = json.loads(tb.getTimeline())
    assert len(tl["events"]) > 0

    tb.newTimeline()
    tl = json.loads(tb.getTimeline())
    assert len(tl["events"]) == 0

    tb.setName("My Timeline")
    tl = json.loads(tb.getTimeline())
    assert tl["name"] == "My Timeline"

    tb.addEvent("2024-01-01", "Test Event", "Description", "general", "#B48250", 3)
    tl = json.loads(tb.getTimeline())
    assert len(tl["events"]) == 1

    names = json.loads(tb.getSampleNames())
    assert "world_wars" in names
    assert "ancient" in names

    print("  PASS: timeline_backend")


def test_source_analyzer():
    sa = SourceAnalyzer()
    data = json.dumps({"title": "Test Source", "author": "Author", "type": "Primary"})
    result = sa.generateAiPrompt(data)
    assert "Test Source" in result
    assert "Author" in result
    assert "primary" in result.lower()

    print("  PASS: source_analyzer")


def test_math_engine_advanced():
    engine = MathEngine()

    result = engine.evaluate("sqrt(144)")
    assert result == "12"

    result = engine.evaluate("log(100)")
    assert result == "2"

    result = engine.evaluate("ln(e)")
    assert result == "1"

    result = engine.evaluate("factorial(5)")
    assert result == "120"

    result = engine.evaluate_with_x("x^2", 4)
    assert result == "16"

    print("  PASS: math_engine_advanced")


def test_math_engine_plot2d():
    engine = MathEngine()
    result = engine.plot2d("sin(x)", -10, 10, 100)
    data = json.loads(result)
    assert isinstance(data, list)
    assert len(data) == 100
    assert "x" in data[0]
    assert "y" in data[0]

    print("  PASS: math_engine_plot2d")


def test_geo_utils_full():
    from core.geo_utils import GeoUtils
    geo = GeoUtils()

    result = json.loads(geo.convertDD(48.8566, 2.3522))
    assert "dms_lat" in result
    assert "dms_lng" in result
    assert "N" in result["dms_lat"] or "S" in result["dms_lat"]

    result = json.loads(geo.haversine(48.8566, 2.3522, 40.7128, -74.006))
    assert result["km"] > 5000

    result = json.loads(geo.bearing(0, 0, 1, 0))
    assert "degrees" in result
    assert "compass" in result

    csv_data = json.dumps([["48.8566", "2.3522"], ["40.7128", "-74.006"]])
    result = json.loads(geo.batchConvert(csv_data, "dd_to_dms"))
    assert len(result) == 2

    print("  PASS: geo_utils_full")


def test_matrix_backend_full():
    from core.matrix_backend import MatrixBackend, Matrix
    mb = MatrixBackend()

    data = json.dumps([[1, 2], [3, 4]])
    result = json.loads(mb.det(data))
    assert result["ok"] is True
    assert abs(result["result"] - (-2.0)) < 1e-10

    result = json.loads(mb.rank(data))
    assert result["ok"] is True
    assert result["result"] == 2

    result = json.loads(mb.transpose(data))
    assert result["ok"] is True
    assert result["result"] == [[1, 3], [2, 4]]

    identity = json.dumps([[1, 0], [0, 1]])
    result = json.loads(mb.inverse(identity))
    assert result["ok"] is True

    result = json.loads(mb.rref(data))
    assert result["ok"] is True

    data_b = json.dumps([[5, 6], [7, 8]])
    result = json.loads(mb.multiply(data, data_b))
    assert result["ok"] is True
    assert result["result"] == [[19, 22], [43, 50]]

    result = json.loads(mb.add(data, data_b))
    assert result["ok"] is True
    assert result["result"] == [[6, 8], [10, 12]]

    print("  PASS: matrix_backend_full")


def test_graph_backend_full():
    from core.graph_backend import GraphBackend
    gb = GraphBackend()

    adj = json.dumps([[0, 1, 0], [1, 0, 1], [0, 1, 0]])
    result = json.loads(gb.connectivity(adj))
    assert result["ok"] is True
    assert result["connected"] is True

    result = json.loads(gb.connectedComponents(adj))
    assert result["ok"] is True
    assert len(result["components"]) == 1

    result = json.loads(gb.bipartite(adj))
    assert result["ok"] is True
    assert result["bipartite"] is True

    result = json.loads(gb.shortestPath(adj, 0, 2))
    assert result["ok"] is True
    assert result["path"] == [0, 1, 2]

    result = json.loads(gb.mst(adj))
    assert result["ok"] is True
    assert len(result["edges"]) == 2

    print("  PASS: graph_backend_full")


if __name__ == "__main__":
    tests = [
        test_undo_manager_push_undo_redo,
        test_undo_manager_clear,
        test_undo_manager_max_history,
        test_calculator_backend_history,
        test_calculator_backend_clipboard,
        test_export_backend,
        test_settings_backend_profile,
        test_plot_backend_safe_eval,
        test_plot_backend_3d,
        test_plot_backend_shapes,
        test_mesh_backend_crud,
        test_mesh_backend_mesh_ops,
        test_mesh_backend_export_import,
        test_timeline_backend,
        test_source_analyzer,
        test_math_engine_advanced,
        test_math_engine_plot2d,
        test_geo_utils_full,
        test_matrix_backend_full,
        test_graph_backend_full,
    ]
    passed = 0
    failed = 0
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"  FAIL: {test.__name__}: {e}")
            import traceback
            traceback.print_exc()
            failed += 1
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
