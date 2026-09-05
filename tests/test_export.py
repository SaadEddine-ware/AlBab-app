import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from core.database import DatabaseManager
from core.geo_utils import GeoUtils, haversine_km
from core.calculator_backend import CalculatorBackend
from core.source_analyzer import SourceAnalyzer
from core.plot_backend import PlotBackend
from core.export_backend import ExportBackend


def test_haversine_shared_function():
    result = haversine_km(0, 0, 0, 0)
    assert result["km"] == 0
    assert result["miles"] == 0
    assert result["nmi"] == 0


def test_haversine_known_distance():
    result = haversine_km(51.5, 0, 48.8566, 2.3522)
    assert 300 < result["km"] < 400
    assert result["miles"] > 0
    assert result["nmi"] > 0
    ratio = result["miles"] / result["km"]
    assert abs(ratio - 0.621371) < 0.001


def test_haversine_via_geo_utils():
    g = GeoUtils()
    raw = g.haversine(51.5, 0, 48.8566, 2.3522)
    d = json.loads(raw)
    assert "km" in d
    assert "miles" in d
    assert "nmi" in d


def test_export_csv_no_history(tmp_path):
    db_path = str(tmp_path / "test.db")
    db = DatabaseManager(db_path)
    cb = CalculatorBackend(db=db)
    path = str(tmp_path / "hist.csv")
    ok = cb.exportCsv(path)
    assert ok
    with open(path) as f:
        lines = f.read().strip().split("\n")
    assert len(lines) == 1
    assert "Expression" in lines[0]


def test_export_csv_with_history(tmp_path):
    db_path = str(tmp_path / "test.db")
    db = DatabaseManager(db_path)
    cb = CalculatorBackend(db=db)
    cb.addToHistory("2+2", "4")
    cb.addToHistory("3*3", "9")
    path = str(tmp_path / "hist.csv")
    ok = cb.exportCsv(path)
    assert ok
    with open(path) as f:
        lines = f.read().strip().split("\n")
    assert len(lines) == 3
    assert "2+2" in lines[1] or "2+2" in lines[2]
    assert "3*3" in lines[1] or "3*3" in lines[2]


def test_export_csv_no_db(tmp_path):
    cb = CalculatorBackend()
    path = str(tmp_path / "hist.csv")
    ok = cb.exportCsv(path)
    assert ok


def test_export_html_source(tmp_path):
    db_path = str(tmp_path / "test.db")
    db = DatabaseManager(db_path)
    sa = SourceAnalyzer(db=db)
    data = json.dumps({"title": "Test Source", "type": "Primary", "author": "Test Author",
                       "date": "1900", "context": "Test context", "purpose": "Test purpose",
                       "audience": "Test audience", "bias": "None", "reliability": "High",
                       "notes": "Interesting"})
    sa.saveSession("test_source", data)
    path = str(tmp_path / "source.html")
    ok = sa.exportHtml("test_source", path)
    assert ok
    with open(path) as f:
        html = f.read()
    assert "Test Source" in html
    assert "Primary" in html
    assert "Test Author" in html


def test_export_html_nonexistent(tmp_path):
    db_path = str(tmp_path / "test.db")
    db = DatabaseManager(db_path)
    sa = SourceAnalyzer(db=db)
    path = str(tmp_path / "nope.html")
    ok = sa.exportHtml("nonexistent", path)
    assert not ok


def test_export_pdf_graph(tmp_path):
    pb = PlotBackend()
    path = str(tmp_path / "graph.pdf")
    ok = pb.exportPdf("sin(x)", path)
    assert ok
    assert os.path.getsize(path) > 1000


def test_export_pdf_bad_expression(tmp_path):
    pb = PlotBackend()
    path = str(tmp_path / "bad.pdf")
    ok = pb.exportPdf("invalid((((" + "x" * 1000, path)
    assert not ok


def test_export_backend_text():
    eb = ExportBackend()
    ok = eb.exportText("hello world", "test_export.txt")
    assert ok
    path = eb.getExportPath("test_export.txt")
    assert os.path.exists(path)
    with open(path) as f:
        assert f.read() == "hello world"


def test_export_backend_json():
    eb = ExportBackend()
    ok = eb.exportJson(json.dumps({"key": "value"}), "test_export.json")
    assert ok
    path = eb.getExportPath("test_export.json")
    assert os.path.exists(path)
    with open(path) as f:
        assert json.loads(f.read())["key"] == "value"


def test_calculator_backend_no_db():
    cb = CalculatorBackend()
    cb.addToHistory("1+1", "2")
    h = json.loads(cb.getHistory())
    assert len(h) >= 1


def test_database_settings(tmp_path):
    db_path = str(tmp_path / "test.db")
    db = DatabaseManager(db_path)
    db.set_setting("gemini_api_key", "test-key-123")
    assert db.get_setting("gemini_api_key") == "test-key-123"
    assert db.get_setting("nonexistent", "default") == "default"


def test_geo_utils_convert_dd():
    g = GeoUtils()
    raw = g.convertDD(51.5, 0.12)
    d = json.loads(raw)
    assert "dms_lat" in d
    assert "dms_lng" in d
    assert abs(d["lat"] - 51.5) < 0.001


def test_geo_utils_bearing():
    g = GeoUtils()
    raw = g.bearing(0, 0, 0, 1)
    d = json.loads(raw)
    assert abs(d["degrees"] - 90) < 1
    assert "compass" in d
