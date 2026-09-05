import json
import math
import os
import tempfile
import time
from PySide6.QtCore import QObject, Slot

_TEMP_DIR = os.path.join(tempfile.gettempdir(), "albab_map")
os.makedirs(_TEMP_DIR, exist_ok=True)
_MAX_TEMP_FILES = 50
_TEMP_MAX_AGE = 1800
_map_counter = 0

_mem_cache: dict = {}


def _cleanup_temp_files():
    try:
        now = time.time()
        files = [os.path.join(_TEMP_DIR, f) for f in os.listdir(_TEMP_DIR) if f.endswith(".png")]
        old = [f for f in files if now - os.path.getmtime(f) > _TEMP_MAX_AGE]
        for f in old:
            os.remove(f)
        files = sorted([f for f in files if f not in old], key=os.path.getmtime)
        while len(files) > _MAX_TEMP_FILES:
            os.remove(files.pop(0))
    except OSError:
        pass


class MapBackend(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._imported = False

    def _lazy_import(self):
        if self._imported:
            return
        import numpy as np
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        import cartopy.crs as ccrs
        import cartopy.feature as cfeature
        import cartopy.io.shapereader as shapereader
        from shapely.geometry import Point
        self._np = np
        self._plt = plt
        self._ccrs = ccrs
        self._cfeature = cfeature
        self._shapereader = shapereader
        self._Point = Point
        self._imported = True

    def _load_country_data(self):
        self._lazy_import()
        global _mem_cache
        if "countries" in _mem_cache:
            return
        try:
            geoms = list(self._shapereader.Reader(
                self._shapereader.natural_earth(resolution="110m", category="cultural", name="admin_0_countries")
            ).records())
            _mem_cache["countries"] = [
                {
                    "name": r.attributes.get("NAME", ""),
                    "iso3": r.attributes.get("ADM0_A3", ""),
                    "capital": r.attributes.get("CAPITAL", ""),
                    "region": r.attributes.get("REGION_UN", ""),
                    "geometry": r.geometry,
                }
                for r in geoms
            ]
        except Exception:
            _mem_cache["countries"] = []

    @Slot(result=str)
    def renderMap(self) -> str:
        self._lazy_import()
        global _map_counter
        fig = self._plt.figure(figsize=(10, 6))
        ax = fig.add_subplot(1, 1, 1, projection=self._ccrs.Robinson())
        ax.add_feature(self._cfeature.LAND, color="#2d5a27")
        ax.add_feature(self._cfeature.OCEAN, color="#1a3d5c")
        ax.add_feature(self._cfeature.COASTLINE, edgecolor="#88ccff", linewidth=0.5)
        ax.add_feature(self._cfeature.BORDERS, edgecolor="#88ccff", linewidth=0.3)
        path = os.path.join(_TEMP_DIR, f"map_{_map_counter}.png")
        self._plt.savefig(path, dpi=100, bbox_inches="tight")
        self._plt.close(fig)
        _map_counter += 1
        _cleanup_temp_files()
        return f"file:///{path.replace(os.sep, '/')}"

    @Slot(float, float, result=str)
    def identifyPoint(self, lat: float, lng: float) -> str:
        self._lazy_import()
        self._load_country_data()
        point = self._Point(lng, lat)
        for c in _mem_cache.get("countries", []):
            if c["geometry"].contains(point):
                return json.dumps({"name": c["name"], "iso3": c["iso3"], "capital": c["capital"], "region": c["region"]})
        return json.dumps({"name": "Unknown"})

    @Slot(str, result=str)
    def searchCountries(self, query: str) -> str:
        self._load_country_data()
        q = query.lower().strip()
        results = []
        for c in _mem_cache.get("countries", []):
            if q in c["name"].lower() or q in c["iso3"].lower():
                results.append({"name": c["name"], "iso3": c["iso3"], "capital": c["capital"], "region": c["region"]})
        return json.dumps(results[:20])

    @Slot(str, result=str)
    def getCountryInfo(self, iso3: str) -> str:
        self._load_country_data()
        for c in _mem_cache.get("countries", []):
            if c["iso3"].upper() == iso3.upper():
                return json.dumps(c)
        return json.dumps({"error": "not found"})

    @Slot(str, result=str)
    def findCountry(self, name: str) -> str:
        self._load_country_data()
        q = name.strip().lower()
        for c in _mem_cache.get("countries", []):
            if c["name"].lower() == q:
                return json.dumps(c)
        return json.dumps({"error": "not found"})

    @Slot(str, result=str)
    def searchCountry(self, name: str) -> str:
        return self.findCountry(name)

    @Slot(float, float, float, float, result=str)
    def haversine(self, lat1: float, lng1: float, lat2: float, lng2: float) -> str:
        from core.geo_utils import haversine_km
        return json.dumps(haversine_km(lat1, lng1, lat2, lng2))

    @Slot(float, float, float, float, result=str)
    def getDistance(self, lat1: float, lng1: float, lat2: float, lng2: float) -> str:
        return self.haversine(lat1, lng1, lat2, lng2)
