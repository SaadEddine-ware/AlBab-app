import json
import math
from PySide6.QtCore import QObject, Slot


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> dict:
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    km = R * c
    return {"km": round(km, 3), "miles": round(km * 0.621371, 3), "nmi": round(km * 0.539957, 3)}


class GeoUtils(QObject):
    @Slot(float, float, result=str)
    def convertDD(self, lat: float, lng: float) -> str:
        def to_dms(v: float, pos: str, neg: str) -> str:
            d = abs(v)
            deg = int(d)
            m = int((d - deg) * 60)
            s = (d - deg - m / 60) * 3600
            label = pos if v >= 0 else neg
            return f"{deg}\u00B0 {m}' {s:.2f}\" {label}"
        return json.dumps({
            "dms_lat": to_dms(lat, "N", "S"),
            "dms_lng": to_dms(lng, "E", "W"),
            "lat": lat, "lng": lng
        })

    @Slot(float, float, float, str, float, float, float, str, result=str)
    def convertDMS(self, d1: float, m1: float, s1: float, dir1: str,
                   d2: float, m2: float, s2: float, dir2: str) -> str:
        def to_dd(d: float, m: float, s: float, dirstr: str) -> float:
            val = d + m / 60 + s / 3600
            return -val if dirstr in ("S", "W") else val
        lat = to_dd(d1, m1, s1, dir1)
        lng = to_dd(d2, m2, s2, dir2)
        return json.dumps({"lat": round(lat, 6), "lng": round(lng, 6)})

    @Slot(float, float, float, float, result=str)
    def haversine(self, lat1: float, lng1: float, lat2: float, lng2: float) -> str:
        return json.dumps(haversine_km(lat1, lng1, lat2, lng2))

    @Slot(float, float, float, float, result=str)
    def bearing(self, lat1: float, lng1: float, lat2: float, lng2: float) -> str:
        phi1, phi2 = math.radians(lat1), math.radians(lat2)
        lam1, lam2 = math.radians(lng1), math.radians(lng2)
        dlam = lam2 - lam1
        x = math.sin(dlam) * math.cos(phi2)
        y = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dlam)
        brng = (math.degrees(math.atan2(x, y)) + 360) % 360
        return json.dumps({"degrees": round(brng, 2), "compass": self._compass(brng)})

    def _compass(self, deg: float) -> str:
        dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        idx = round(deg / 22.5) % 16
        return dirs[idx]

    @Slot(str, str, result=str)
    def batchConvert(self, csvJson: str, mode: str) -> str:
        try:
            rows = json.loads(csvJson)
        except (json.JSONDecodeError, TypeError):
            return json.dumps([["error", "Invalid JSON"]])
        out = []
        for row in rows:
            try:
                if mode == "dd_to_dms":
                    lat, lng = float(row[0]), float(row[1])
                    dms = json.loads(self.convertDD(lat, lng))
                    out.append([dms["dms_lat"], dms["dms_lng"]])
                elif mode == "dms_to_dd":
                    d1, m1, s1, dir1, d2, m2, s2, dir2 = row
                    r = json.loads(self.convertDMS(float(d1), float(m1), float(s1), dir1,
                                                    float(d2), float(m2), float(s2), dir2))
                    out.append([r["lat"], r["lng"]])
                else:
                    out.append(["error", "unknown mode"])
            except (ValueError, IndexError, json.JSONDecodeError) as e:
                out.append(["error", str(e)])
        return json.dumps(out)
