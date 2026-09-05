import json
import os
import tempfile
import time
from PySide6.QtCore import QObject, Slot

_TEMP_DIR = os.path.join(tempfile.gettempdir(), "albab_demo")
try:
    os.makedirs(_TEMP_DIR, exist_ok=True)
except OSError:
    pass
_MAX_TEMP_FILES = 50
_TEMP_MAX_AGE = 1800
_demo_counter = 0


def _cleanup_temp_files():
    try:
        now = time.time()
        files = [os.path.join(_TEMP_DIR, f) for f in os.listdir(_TEMP_DIR) if f.endswith(".png")]
        old = [f for f in files if now - os.path.getmtime(f) > _TEMP_MAX_AGE]
        for f in old:
            os.remove(f)
        files = sorted([f for f in files if f not in set(old)], key=os.path.getmtime)
        while len(files) > _MAX_TEMP_FILES:
            os.remove(files.pop(0))
    except OSError:
        pass

_INDICATORS = [
    {"id": "POP_EST", "name": "Population", "unit": "people", "fmt": ",.0f"},
    {"id": "GDP_MD_EST", "name": "GDP (est.)", "unit": "USD millions", "fmt": ",.0f"},
    {"id": "AREA_KM2", "name": "Area", "unit": "km\u00B2", "fmt": ",.0f"},
    {"id": "POP_DENSITY", "name": "Population Density", "unit": "people/km\u00B2", "fmt": ".1f"},
    {"id": "BIRTH_RATE", "name": "Birth Rate", "unit": "per 1000", "fmt": ".1f"},
    {"id": "DEATH_RATE", "name": "Death Rate", "unit": "per 1000", "fmt": ".1f"},
]

_mem_cache: dict = {}


class DemographicsBackend(QObject):
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
        import geopandas as gpd
        import cartopy.crs as ccrs
        import cartopy.io.shapereader as shapereader
        self._np = np
        self._plt = plt
        self._gpd = gpd
        self._ccrs = ccrs
        self._shapereader = shapereader
        self._imported = True

    def _load_data(self):
        self._lazy_import()
        global _mem_cache
        if "countries" in _mem_cache:
            return
        try:
            geoms = list(self._shapereader.Reader(
                self._shapereader.natural_earth(resolution="110m", category="cultural", name="admin_0_countries")
            ).records())
            _mem_cache["countries"] = []
            for r in geoms:
                a = r.attributes
                area = a.get("AREA_KM2", 0) or 0
                pop = a.get("POP_EST", 0) or 0
                density = pop / area if area > 0 else 0
                _mem_cache["countries"].append({
                    "name": a.get("NAME", ""),
                    "iso3": a.get("ADM0_A3", ""),
                    "pop": pop,
                    "gdp": a.get("GDP_MD_EST", 0) or 0,
                    "area": area,
                    "density": round(density, 2),
                    "birth_rate": a.get("BIRTH_RATE", 0) or 0,
                    "death_rate": a.get("DEATH_RATE", 0) or 0,
                    "geometry": r.geometry,
                })
        except Exception:
            _mem_cache["countries"] = []

    @Slot(result=str)
    def getIndicators(self) -> str:
        return json.dumps(_INDICATORS)

    @Slot(str, result=str)
    def getCountryData(self, iso3: str) -> str:
        self._load_data()
        for c in _mem_cache.get("countries", []):
            if c["iso3"].upper() == iso3.upper():
                c_no_geom = {k: v for k, v in c.items() if k != "geometry"}
                return json.dumps(c_no_geom)
        return json.dumps({"error": "not found"})

    @Slot(result=str)
    def getAllCountries(self) -> str:
        self._load_data()
        return json.dumps([{"name": c["name"], "iso3": c["iso3"]} for c in _mem_cache.get("countries", [])])

    @Slot(str, bool, result=str)
    def getTopBottom(self, indicator: str, bottom: bool = False) -> str:
        self._load_data()
        key_map = {"POP_EST": "pop", "GDP_MD_EST": "gdp", "AREA_KM2": "area", "POP_DENSITY": "density", "BIRTH_RATE": "birth_rate", "DEATH_RATE": "death_rate"}
        key = key_map.get(indicator, "pop")
        sorted_list = sorted(_mem_cache.get("countries", []), key=lambda c: c.get(key, 0), reverse=not bottom)
        return json.dumps([{"name": c["name"], "value": c.get(key, 0)} for c in sorted_list[:10]])

    @Slot(str, bool, result=str)
    def topCountries(self, indicator: str, asc: bool = False) -> str:
        return self.getTopBottom(indicator, asc)

    @Slot(str, str, str, result=str)
    def renderChoropleth(self, indicator: str, title: str, colormap: str = "YlOrRd") -> str:
        self._lazy_import()
        self._load_data()
        global _demo_counter
        key_map = {"POP_EST": "pop", "GDP_MD_EST": "gdp", "AREA_KM2": "area", "POP_DENSITY": "density", "BIRTH_RATE": "birth_rate", "DEATH_RATE": "death_rate"}
        key = key_map.get(indicator, "pop")
        countries = _mem_cache.get("countries", [])
        values = [c.get(key, 0) for c in countries]
        vmin, vmax = (min(values), max(values)) if values else (0, 1)
        fig, ax = self._plt.subplots(1, 1, figsize=(14, 8), subplot_kw={"projection": self._get_projection()})
        for c in countries:
            val = c.get(key, 0)
            norm = (val - vmin) / (vmax - vmin) if vmax > vmin else 0.5
            try:
                cmap = self._plt.colormaps[colormap]
            except (AttributeError, KeyError):
                cmap = self._plt.cm.get_cmap(colormap)
            color = cmap(norm)
            if c["geometry"]:
                ax.add_geometries([c["geometry"]], crs=self._get_projection(), facecolor=color, edgecolor="#333333", linewidth=0.2)
        ax.set_title(title, fontsize=14)
        path = os.path.join(_TEMP_DIR, f"demo_{_demo_counter}.png")
        self._plt.savefig(path, dpi=100, bbox_inches="tight")
        self._plt.close(fig)
        _demo_counter += 1
        _cleanup_temp_files()
        return f"file:///{path.replace(os.sep, '/')}"

    def _get_projection(self):
        self._lazy_import()
        return self._ccrs.Robinson()

    @Slot(str, str, result=str)
    def choropleth(self, indicator: str, colormap: str = "YlOrRd") -> str:
        ind_name = next((i["name"] for i in _INDICATORS if i["id"] == indicator), indicator)
        return self.renderChoropleth(indicator, f"{ind_name} by Country", colormap)

    @Slot(str, str, result=str)
    def renderComparison(self, indicator1: str, indicator2: str) -> str:
        self._lazy_import()
        self._load_data()
        global _demo_counter
        key_map = {"POP_EST": "pop", "GDP_MD_EST": "gdp", "AREA_KM2": "area", "POP_DENSITY": "density", "BIRTH_RATE": "birth_rate", "DEATH_RATE": "death_rate"}
        k1, k2 = key_map.get(indicator1, "pop"), key_map.get(indicator2, "pop")
        countries = _mem_cache.get("countries", [])
        x = [c.get(k1, 0) for c in countries]
        y = [c.get(k2, 0) for c in countries]
        fig, ax = self._plt.subplots(figsize=(10, 6))
        ax.scatter(x, y, alpha=0.6, s=20, c="#ff7f0e")
        ax.set_xlabel(indicator1)
        ax.set_ylabel(indicator2)
        ax.set_title(f"{indicator1} vs {indicator2}")
        path = os.path.join(_TEMP_DIR, f"demo_{_demo_counter}.png")
        self._plt.savefig(path, dpi=100, bbox_inches="tight")
        self._plt.close(fig)
        _demo_counter += 1
        _cleanup_temp_files()
        return f"file:///{path.replace(os.sep, '/')}"

    @Slot(str, str, result=str)
    def compareCountries(self, iso3_1: str, iso3_2: str) -> str:
        self._load_data()
        c1 = next((c for c in _mem_cache.get("countries", []) if c["iso3"].upper() == iso3_1.upper()), None)
        c2 = next((c for c in _mem_cache.get("countries", []) if c["iso3"].upper() == iso3_2.upper()), None)
        if c1 and c2:
            c1_clean = {k: v for k, v in c1.items() if k != "geometry"}
            c2_clean = {k: v for k, v in c2.items() if k != "geometry"}
            return json.dumps({"a": c1_clean, "b": c2_clean})
        return json.dumps({"error": "not found"})

    @Slot(str, result=str)
    def searchCountries(self, query: str) -> str:
        self._load_data()
        q = query.lower().strip()
        results = [{"name": c["name"], "iso3": c["iso3"]} for c in _mem_cache.get("countries", []) if q in c["name"].lower() or q in c["iso3"].lower()]
        return json.dumps(results[:20])
