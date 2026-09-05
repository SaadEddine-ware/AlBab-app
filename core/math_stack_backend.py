import json
import math
import statistics
import numpy as np
from PySide6.QtCore import QObject, Slot


def _mean(data):
    return sum(data) / len(data) if data else 0


def _variance(data, ddof=1):
    m = _mean(data)
    return sum((x - m) ** 2 for x in data) / (len(data) - ddof) if len(data) > ddof else 0


def _std_dev(data, ddof=1):
    return math.sqrt(_variance(data, ddof))


def _pearson(x, y):
    n = len(x)
    mx, my = _mean(x), _mean(y)
    num = sum((xi - mx) * (yi - my) for xi, yi in zip(x, y))
    den = math.sqrt(sum((xi - mx) ** 2 for xi in x) * sum((yi - my) ** 2 for yi in y))
    return num / den if den else 0


def _ttest_ind(a, b):
    n1, n2 = len(a), len(b)
    if n1 < 2 or n2 < 2:
        return 0
    m1, m2 = _mean(a), _mean(b)
    v1, v2 = _variance(a), _variance(b)
    se = math.sqrt(v1 / n1 + v2 / n2)
    t = (m1 - m2) / se if se else 0
    return t


def _ttest_1samp(data, mu):
    n = len(data)
    m = _mean(data)
    s = _std_dev(data)
    se = s / math.sqrt(n) if s else 1
    t = (m - mu) / se
    return t


def _f_oneway(*groups):
    all_data = [x for g in groups for x in g]
    grand_mean = _mean(all_data)
    ssb = sum(len(g) * (_mean(g) - grand_mean) ** 2 for g in groups)
    ssw = sum(sum((x - _mean(g)) ** 2 for x in g) for g in groups)
    k = len(groups)
    n = len(all_data)
    dfb = k - 1
    dfw = n - k
    msb = ssb / dfb if dfb else 0
    msw = ssw / dfw if dfw else 1
    f = msb / msw if msw else 0
    return f

class MathStackBackend(QObject):
    @Slot(str, result=str)
    def descriptiveStats(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            arr = np.array(data)
            q1, q2, q3 = float(np.percentile(arr, 25)), float(np.median(arr)), float(np.percentile(arr, 75))
            try:
                mode_val = statistics.mode(data)
            except statistics.StatisticsError:
                mode_val = "N/A"
            n = len(data)
            m = float(np.mean(arr))
            v = float(np.var(arr, ddof=1))
            s = float(np.std(arr, ddof=1))
            skew = (n / ((n - 1) * (n - 2))) * float(np.sum(((arr - m) / s) ** 3)) if s and n > 2 else 0
            kurt = float(np.mean(((arr - m) / s) ** 4)) - 3 if s else 0
            return json.dumps({
                "ok": True,
                "n": n, "mean": m, "median": q2, "mode": str(mode_val),
                "variance": v, "std_dev": s, "min": float(np.min(arr)), "max": float(np.max(arr)),
                "q1": q1, "q3": q3, "skewness": skew, "kurtosis": kurt,
            })
        except (json.JSONDecodeError, TypeError, ValueError, ZeroDivisionError, IndexError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, str, result=str)
    def linearRegression(self, json_x: str, json_y: str) -> str:
        try:
            x = np.array(json.loads(json_x), dtype=float)
            y = np.array(json.loads(json_y), dtype=float)
            A = np.vstack([x, np.ones(len(x))]).T
            slope, intercept = np.linalg.lstsq(A, y, rcond=None)[0]
            y_pred = slope * x + intercept
            ss_res = np.sum((y - y_pred) ** 2)
            ss_tot = np.sum((y - np.mean(y)) ** 2)
            r2 = 1 - ss_res / ss_tot if ss_tot else 0
            cc = _pearson(x.tolist(), y.tolist())
            return json.dumps({
                "ok": True, "slope": float(slope), "intercept": float(intercept),
                "r_squared": float(r2), "correlation": cc,
            })
        except (json.JSONDecodeError, TypeError, ValueError, ZeroDivisionError, IndexError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def ttestOneSample(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            mu = data.get("mu", 0)
            values = data.get("values", [])
            t = _ttest_1samp(values, mu)
            return json.dumps({"ok": True, "t_stat": t, "p_value": 0})
        except (json.JSONDecodeError, TypeError, ValueError, ZeroDivisionError, IndexError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, str, result=str)
    def ttestIndependent(self, json_a: str, json_b: str) -> str:
        try:
            a = json.loads(json_a)
            b = json.loads(json_b)
            t = _ttest_ind(a, b)
            return json.dumps({"ok": True, "t_stat": t, "p_value": 0})
        except (json.JSONDecodeError, TypeError, ValueError, ZeroDivisionError, IndexError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def anova(self, json_groups: str) -> str:
        try:
            groups = json.loads(json_groups)
            f = _f_oneway(*groups)
            return json.dumps({"ok": True, "f_stat": f, "p_value": 0})
        except (json.JSONDecodeError, TypeError, ValueError, ZeroDivisionError, IndexError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def shapeArea(self, json_data: str) -> str:
        try:
            d = json.loads(json_data)
            shape_name = d.get("shape", "")
            params = d.get("params", {})
            if shape_name == "circle":
                r = params.get("radius", 0)
                return json.dumps({"ok": True, "area": math.pi * r * r, "perimeter": 2 * math.pi * r})
            elif shape_name == "rectangle":
                w, h = params.get("width", 0), params.get("height", 0)
                return json.dumps({"ok": True, "area": w * h, "perimeter": 2 * (w + h)})
            elif shape_name == "triangle":
                a, b, c = params.get("a", 0), params.get("b", 0), params.get("c", 0)
                s = (a + b + c) / 2
                area = math.sqrt(s * (s - a) * (s - b) * (s - c)) if s > max(a, b, c) else 0
                return json.dumps({"ok": True, "area": area, "perimeter": a + b + c})
            elif shape_name == "sphere":
                r = params.get("radius", 1)
                return json.dumps({"ok": True, "area": 4 * math.pi * r * r, "perimeter": 2 * math.pi * r, "volume": (4/3) * math.pi * r**3})
            elif shape_name == "cube":
                s = params.get("size", 1)
                return json.dumps({"ok": True, "area": 6 * s * s, "perimeter": 12 * s, "volume": s**3})
            elif shape_name == "cylinder":
                r, h = params.get("radius", 1), params.get("height", 1)
                return json.dumps({"ok": True, "area": 2 * math.pi * r * (r + h), "perimeter": 2 * math.pi * r, "volume": math.pi * r * r * h})
            elif shape_name == "cone":
                r, h = params.get("radius", 1), params.get("height", 1)
                l = (r*r + h*h) ** 0.5
                return json.dumps({"ok": True, "area": math.pi * r * (r + l), "perimeter": 2 * math.pi * r, "volume": (1/3) * math.pi * r * r * h})
            elif shape_name == "pyramid":
                b, h = params.get("base", 1), params.get("height", 1)
                return json.dumps({"ok": True, "area": b * b + 2 * b * (b*b/4 + h*h)**0.5, "perimeter": 4 * b, "volume": (1/3) * b * b * h})
            else:
                return json.dumps({"ok": False, "error": f"Unknown shape: {shape_name}"})
        except (json.JSONDecodeError, TypeError, ValueError, ZeroDivisionError, IndexError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def distance(self, json_data: str) -> str:
        try:
            d = json.loads(json_data)
            xy1, xy2 = d.get("p1", []), d.get("p2", [])
            dist = math.sqrt((xy2[0] - xy1[0]) ** 2 + (xy2[1] - xy1[1]) ** 2)
            return json.dumps({"ok": True, "distance": dist})
        except (json.JSONDecodeError, TypeError, ValueError, ZeroDivisionError, IndexError) as e:
            return json.dumps({"ok": False, "error": str(e)})
