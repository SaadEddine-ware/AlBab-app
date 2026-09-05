import json
import math
import sys
import os
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from core.database import DatabaseManager
from core.math_engine import MathEngine, _SafeEvaluator
from core.source_analyzer import _safe_session_name
from core.settings_manager import SettingsManager


def test_math_engine_basic():
    engine = MathEngine()
    assert engine.evaluate("2 + 3") == "5"
    assert engine.evaluate("10 / 2") == "5"
    assert engine.evaluate("2 * 3") == "6"
    assert engine.evaluate("10 - 4") == "6"
    assert engine.evaluate("2 ^ 3") == "8"
    assert engine.evaluate("-5") == "-5"


def test_math_engine_functions():
    engine = MathEngine()
    assert engine.evaluate("sqrt(16)") == "4"
    assert engine.evaluate("abs(-7)") == "7"
    assert engine.evaluate("floor(3.7)") == "3"
    assert engine.evaluate("ceil(3.2)") == "4"


def test_math_engine_constants():
    engine = MathEngine()
    result = engine.evaluate("pi")
    assert abs(float(result) - math.pi) < 1e-10
    result = engine.evaluate("e")
    assert abs(float(result) - math.e) < 1e-10


def test_math_engine_with_x():
    engine = MathEngine()
    assert engine.evaluate_with_x("x + 1", 5) == "6"
    assert engine.evaluate_with_x("x * 2", 3) == "6"


def test_math_engine_error():
    engine = MathEngine()
    result = engine.evaluate("unknown_func(1)")
    assert "Error" in result


def test_safe_evaluator():
    evaluator = _SafeEvaluator()
    assert evaluator.eval("2 + 3") == 5
    assert evaluator.eval("sqrt(9)") == 3
    assert evaluator.eval("sin(0)") == 0


def test_safe_session_name():
    assert _safe_session_name("my_session") == "my_session"
    result = _safe_session_name("../../../etc/passwd")
    assert ".." not in result
    assert "/" not in result
    assert len(_safe_session_name("a" * 200)) == 128
    assert _safe_session_name("hello world!") == "hello_world_"


def test_settings_manager_dev():
    path = os.path.join(tempfile.gettempdir(), f"test_albab_sm_{os.urandom(4).hex()}.db")
    db = DatabaseManager(path)
    mgr = SettingsManager(db=db, dev_mode=True)
    assert mgr.get("language") == "en"
    assert mgr.get("theme") == "frosted"
    assert "data-dev" in mgr.data_dir
    for ext in ("", "-wal", "-shm"):
        try:
            os.remove(path + ext)
        except OSError:
            pass


def test_settings_manager_set():
    path = os.path.join(tempfile.gettempdir(), f"test_albab_sm2_{os.urandom(4).hex()}.db")
    db = DatabaseManager(path)
    mgr = SettingsManager(db=db, dev_mode=True)
    mgr.set("test_key", "test_value")
    assert mgr.get("test_key") == "test_value"
    for ext in ("", "-wal", "-shm"):
        try:
            os.remove(path + ext)
        except OSError:
            pass


def test_matrix_backend():
    from core.matrix_backend import Matrix
    m = Matrix([[1, 2], [3, 4]])
    assert abs(m.det() - (-2.0)) < 1e-10
    assert m.transpose() == [[1, 3], [2, 4]]
    assert m.rank() == 2

    m2 = Matrix([[1, 0], [0, 1]])
    inv = m2.inverse()
    assert inv is not None
    assert abs(inv[0][0] - 1.0) < 1e-10


def test_graph_backend():
    from core.graph_backend import GraphAlgo
    adj = [[0, 1, 0], [1, 0, 1], [0, 1, 0]]
    algo = GraphAlgo(adj)
    connected, _ = algo.connectivity()
    assert connected is True

    path = algo.shortest_path(0, 2)
    assert path == [0, 1, 2]

    assert algo.is_bipartite() is True

    components = algo.connected_components()
    assert len(components) == 1


def test_geo_utils():
    from core.geo_utils import GeoUtils
    geo = GeoUtils()
    result = json.loads(geo.haversine(0, 0, 0, 1))
    assert "km" in result
    assert result["km"] > 0

    result = json.loads(geo.bearing(0, 0, 1, 0))
    assert "degrees" in result
    assert "compass" in result


if __name__ == "__main__":
    tests = [
        test_math_engine_basic,
        test_math_engine_functions,
        test_math_engine_constants,
        test_math_engine_with_x,
        test_math_engine_error,
        test_safe_evaluator,
        test_safe_session_name,
        test_settings_manager_dev,
        test_settings_manager_set,
        test_matrix_backend,
        test_graph_backend,
        test_geo_utils,
    ]
    passed = 0
    failed = 0
    for test in tests:
        try:
            test()
            print(f"  PASS: {test.__name__}")
            passed += 1
        except Exception as e:
            print(f"  FAIL: {test.__name__}: {e}")
            failed += 1
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
