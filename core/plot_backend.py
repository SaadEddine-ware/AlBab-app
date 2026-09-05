import ast
import operator
import os
import math
import tempfile
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from PySide6.QtCore import QObject, Slot, Signal

_TEMP_DIR = os.path.join(tempfile.gettempdir(), "albab_plots")
os.makedirs(_TEMP_DIR, exist_ok=True)

_MAX_TEMP_FILES = 50

_SAFE_OPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.Pow: operator.pow,
    ast.USub: operator.neg,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
}

_NP_FUNCS = {
    "sin": np.sin, "cos": np.cos, "tan": np.tan,
    "asin": np.arcsin, "acos": np.arccos, "atan": np.arctan,
    "sinh": np.sinh, "cosh": np.cosh, "tanh": np.tanh,
    "log": np.log10, "ln": np.log, "log2": np.log2,
    "sqrt": np.sqrt, "abs": np.abs, "exp": np.exp,
}

_NP_CONSTS = {
    "pi": math.pi, "e": math.e, "tau": math.tau,
}


def _safe_eval_np(expr: str, ns: dict) -> np.ndarray:
    tree = ast.parse(expr.strip(), mode="eval")
    return _walk_np(tree.body, ns)


def _walk_np(node, ns: dict):
    if isinstance(node, ast.Expression):
        return _walk_np(node.body, ns)
    elif isinstance(node, ast.Constant):
        return node.value
    elif isinstance(node, ast.BinOp):
        left = _walk_np(node.left, ns)
        right = _walk_np(node.right, ns)
        op_type = type(node.op)
        if op_type in _SAFE_OPS:
            return _SAFE_OPS[op_type](left, right)
        raise ValueError(f"Unsupported operator: {op_type}")
    elif isinstance(node, ast.UnaryOp):
        operand = _walk_np(node.operand, ns)
        op_type = type(node.op)
        if op_type in _SAFE_OPS:
            return _SAFE_OPS[op_type](operand)
        raise ValueError(f"Unsupported unary operator: {op_type}")
    elif isinstance(node, ast.Call):
        func_name = node.func.id if isinstance(node.func, ast.Name) else None
        if func_name in _NP_FUNCS:
            args = [_walk_np(a, ns) for a in node.args]
            return _NP_FUNCS[func_name](*args)
        raise ValueError(f"Unknown function: {func_name}")
    elif isinstance(node, ast.Name):
        if node.id in ns:
            return ns[node.id]
        if node.id in _NP_CONSTS:
            return _NP_CONSTS[node.id]
        raise ValueError(f"Unknown variable: {node.id}")
    else:
        raise ValueError(f"Unsupported syntax: {type(node).__name__}")


def _make_ns(x=None, y=None):
    ns = dict(_NP_CONSTS)
    ns["np"] = np
    ns.update(_NP_FUNCS)
    if x is not None:
        ns["x"] = x
    if y is not None:
        ns["y"] = y
    return ns


def _clean_expr(expression: str) -> str:
    return expression.replace("^", "**").replace("\u00F7", "/").replace("\u00D7", "*")


def _save_fig(fig, prefix: str) -> str:
    global _plot_counter
    _plot_counter += 1
    path = os.path.join(_TEMP_DIR, f"{prefix}_{_plot_counter}.png")
    fig.savefig(path, dpi=120, bbox_inches="tight")
    plt.close(fig)
    _cleanup_temp_files()
    return "file:///" + path.replace("\\", "/")


def _cleanup_temp_files() -> None:
    try:
        files = sorted(
            [os.path.join(_TEMP_DIR, f) for f in os.listdir(_TEMP_DIR) if f.endswith(".png")],
            key=os.path.getmtime
        )
        while len(files) > _MAX_TEMP_FILES:
            os.remove(files.pop(0))
    except OSError:
        pass


_plot_counter = 0


class PlotBackend(QObject):
    plotUpdated = Signal(str)

    def __init__(self):
        super().__init__()
        self._theme = "light"

    @Slot(str, result=str)
    def plot2d(self, expression: str) -> str:
        x_min, x_max, points = -10, 10, 500
        try:
            xs = np.linspace(x_min, x_max, points)
            ns = _make_ns(x=xs)
            ys = _safe_eval_np(_clean_expr(expression), ns)
            ys = np.where(np.isfinite(ys), ys, np.nan)
        except Exception:
            return ""

        fig, ax = plt.subplots(figsize=(8, 5), facecolor="#F5F0EB")
        ax.set_facecolor("#F5F0EB")
        ax.plot(xs, ys, color="#B48250", linewidth=2)
        ax.axhline(0, color="#000000", linewidth=0.5, alpha=0.3)
        ax.axvline(0, color="#000000", linewidth=0.5, alpha=0.3)
        ax.grid(True, alpha=0.3)
        ax.set_xlabel("x", fontsize=10)
        ax.set_ylabel("f(x)", fontsize=10)
        ax.set_title(expression, fontsize=11, fontweight="bold")
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

        url = _save_fig(fig, "plot2d")
        self.plotUpdated.emit(url)
        return url

    @Slot(str, float, float, result=str)
    def plot2dRange(self, expression: str, x_min: float, x_max: float) -> str:
        points = 500
        try:
            xs = np.linspace(x_min, x_max, points)
            ns = _make_ns(x=xs)
            ys = _safe_eval_np(_clean_expr(expression), ns)
            ys = np.where(np.isfinite(ys), ys, np.nan)
        except Exception:
            return ""

        fig, ax = plt.subplots(figsize=(8, 5), facecolor="#F5F0EB")
        ax.set_facecolor("#F5F0EB")
        ax.plot(xs, ys, color="#B48250", linewidth=2)
        ax.axhline(0, color="#000000", linewidth=0.5, alpha=0.3)
        ax.axvline(0, color="#000000", linewidth=0.5, alpha=0.3)
        ax.grid(True, alpha=0.3)
        ax.set_xlabel("x", fontsize=10)
        ax.set_ylabel("f(x)", fontsize=10)
        ax.set_title(expression, fontsize=11, fontweight="bold")
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        url = _save_fig(fig, "plot2d")
        self.plotUpdated.emit(url)
        return url

    @Slot(str, result=str)
    def plot3d(self, expression: str) -> str:
        return self.plot3dRotated(expression, -60, 45)

    @Slot(str, float, float, float, float, int, result=str)
    def computeSurface(self, expression: str, x_min: float, x_max: float, y_min: float, y_max: float, res: int) -> str:
        try:
            xs = np.linspace(x_min, x_max, res).tolist()
            ys = np.linspace(y_min, y_max, res).tolist()
            X, Y = np.meshgrid(np.linspace(x_min, x_max, res), np.linspace(y_min, y_max, res))
            ns = _make_ns(x=X, y=Y)
            Z = _safe_eval_np(_clean_expr(expression), ns)
            Z = np.where(np.isfinite(Z), Z, np.nan)
            zs = Z.tolist()
            return json.dumps({"xs": [round(v, 6) for v in xs], "ys": [round(v, 6) for v in ys], "zs": [[round(v, 6) if v is not None and not np.isnan(v) else 0 for v in row] for row in zs]})
        except Exception:
            return "{}"

    @Slot(str, float, float, result=str)
    def plot3dRotated(self, expression: str, elevation: float, azimuth: float) -> str:
        x_min, x_max, y_min, y_max, res = -5, 5, -5, 5, 50
        try:
            xs = np.linspace(x_min, x_max, res)
            ys = np.linspace(y_min, y_max, res)
            X, Y = np.meshgrid(xs, ys)
            ns = _make_ns(x=X, y=Y)
            Z = _safe_eval_np(_clean_expr(expression), ns)
            Z = np.where(np.isfinite(Z), Z, np.nan)
        except Exception:
            return ""

        fig = plt.figure(figsize=(8, 6), facecolor="#F5F0EB")
        ax = fig.add_subplot(111, projection="3d", facecolor="#F5F0EB")
        surf = ax.plot_surface(X, Y, Z, cmap="viridis", edgecolor="none", alpha=0.9)
        ax.set_xlabel("x", fontsize=9)
        ax.set_ylabel("y", fontsize=9)
        ax.set_zlabel("z", fontsize=9)
        ax.set_title(expression, fontsize=11, fontweight="bold")
        ax.view_init(elev=elevation, azim=azimuth)
        fig.colorbar(surf, ax=ax, shrink=0.5, aspect=20)

        url = _save_fig(fig, "plot3d")
        self.plotUpdated.emit(url)
        return url

    @Slot(str, str, result=bool)
    def exportPdf(self, expression: str, filepath: str) -> bool:
        try:
            x_min, x_max, points = -10, 10, 500
            xs = np.linspace(x_min, x_max, points)
            ns = _make_ns(x=xs)
            ys = _safe_eval_np(_clean_expr(expression), ns)
            ys = np.where(np.isfinite(ys), ys, np.nan)
            fig, ax = plt.subplots(figsize=(8, 5), facecolor="#F5F0EB")
            ax.set_facecolor("#F5F0EB")
            ax.plot(xs, ys, color="#B48250", linewidth=2)
            ax.axhline(0, color="#000000", linewidth=0.5, alpha=0.3)
            ax.axvline(0, color="#000000", linewidth=0.5, alpha=0.3)
            ax.grid(True, alpha=0.3)
            ax.set_xlabel("x", fontsize=10)
            ax.set_ylabel("f(x)", fontsize=10)
            ax.set_title(expression, fontsize=11, fontweight="bold")
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)
            fig.tight_layout()
            fig.savefig(filepath, dpi=150, bbox_inches="tight")
            plt.close(fig)
            return True
        except Exception:
            return False

    @Slot(str, str, result=str)
    def getShapeGeometry(self, shape_type: str, json_params: str) -> str:
        try:
            params = json.loads(json_params)
        except (json.JSONDecodeError, TypeError):
            params = {}
        try:
            if shape_type == "cube":
                return self._geom_cube(params.get("size", 2))
            elif shape_type == "sphere":
                return self._geom_sphere(params.get("radius", 2))
            elif shape_type == "cylinder":
                return self._geom_cylinder(params.get("radius", 1.5), params.get("height", 3))
            elif shape_type == "cone":
                return self._geom_cone(params.get("radius", 1.5), params.get("height", 3))
            elif shape_type == "torus":
                return self._geom_torus(params.get("major_radius", 2), params.get("minor_radius", 0.8))
            elif shape_type == "pyramid":
                return self._geom_pyramid(params.get("base", 2), params.get("height", 2.5))
            else:
                return json.dumps({"error": "unknown shape"})
        except Exception as e:
            return json.dumps({"error": str(e)})

    def _face(self, verts: list, colors: list, vlist: list, color: str) -> None:
        if len(vlist) == 3:
            faces = [list(vlist)]
        elif len(vlist) == 4:
            a, b, c, d = vlist
            faces = [[a, b, c], [a, c, d]]
        else:
            return
        for f in faces:
            verts.append(f)
            colors.append(color)

    def _geom_cube(self, size: float) -> str:
        s = size / 2
        v = [[-s, -s, -s], [s, -s, -s], [s, s, -s], [-s, s, -s],
             [-s, -s, s], [s, -s, s], [s, s, s], [-s, s, s]]
        verts, colors = [], []
        c = "#B48250"
        self._face(verts, colors, [0, 1, 2, 3], c)
        self._face(verts, colors, [4, 5, 6, 7], c)
        self._face(verts, colors, [0, 1, 5, 4], c)
        self._face(verts, colors, [2, 3, 7, 6], c)
        self._face(verts, colors, [0, 3, 7, 4], c)
        self._face(verts, colors, [1, 2, 6, 5], c)
        return json.dumps({"vertices": v, "faces": verts, "colors": colors})

    def _geom_sphere(self, radius: float) -> str:
        u_steps, v_steps = 24, 16
        verts, faces, colors = [], [], []
        pts = []
        for j in range(v_steps + 1):
            v = j / v_steps
            theta = v * math.pi
            row = []
            for i in range(u_steps + 1):
                u = i / u_steps
                phi = u * 2 * math.pi
                x = radius * math.sin(theta) * math.cos(phi)
                y = radius * math.sin(theta) * math.sin(phi)
                z = radius * math.cos(theta)
                pts.append([x, y, z])
                row.append(len(pts) - 1)
            if j > 0:
                prev = len(pts) - len(row) - u_steps - 1
                for i in range(u_steps):
                    a = prev + i
                    b = prev + i + 1
                    c = prev + i + u_steps + 1
                    d = prev + i + u_steps + 2
                    r = (pts[a][2] + pts[b][2] + pts[c][2] + pts[d][2]) / 4
                    bright = 0.5 + 0.5 * (r / radius + 1) / 2
                    rgb = int(76 * bright), int(175 * bright), int(80 * bright)
                    hc = f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"
                    self._face(faces, colors, [a, b, d, c], hc)
        return json.dumps({"vertices": pts, "faces": faces, "colors": colors})

    def _geom_cylinder(self, radius: float, height: float) -> str:
        segs = 24
        half = height / 2
        verts, faces, colors = [], [], []
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs
            verts.append([radius * math.cos(a), radius * math.sin(a), -half])
            verts.append([radius * math.cos(a), radius * math.sin(a), half])
        for i in range(segs):
            a = i * 2
            b = a + 1
            c = (i + 1) * 2
            d = c + 1
            self._face(faces, colors, [a, b, d, c], "#FF9800")
        ci = len(verts)
        verts.append([0, 0, -half])
        bot_center = len(verts) - 1
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs
            verts.append([radius * math.cos(a), radius * math.sin(a), -half])
        for i in range(segs):
            self._face(faces, colors, [bot_center, ci + 1 + i, ci + 1 + i + 1], "#FF9800")
        ci = len(verts)
        verts.append([0, 0, half])
        top_center = len(verts) - 1
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs
            verts.append([radius * math.cos(a), radius * math.sin(a), half])
        for i in range(segs):
            self._face(faces, colors, [top_center, ci + 1 + i + 1, ci + 1 + i], "#FF9800")
        return json.dumps({"vertices": verts, "faces": faces, "colors": colors})

    def _geom_cone(self, radius: float, height: float) -> str:
        segs = 24
        half = height / 2
        verts, faces, colors = [], [], []
        apex = len(verts)
        verts.append([0, 0, half])
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs
            verts.append([radius * math.cos(a), radius * math.sin(a), -half])
        for i in range(segs):
            self._face(faces, colors, [apex, apex + 1 + i, apex + 1 + i + 1], "#E91E63")
        ci = len(verts)
        verts.append([0, 0, -half])
        center = len(verts) - 1
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs
            verts.append([radius * math.cos(a), radius * math.sin(a), -half])
        for i in range(segs):
            self._face(faces, colors, [center, ci + 1 + i + 1, ci + 1 + i], "#E91E63")
        return json.dumps({"vertices": verts, "faces": faces, "colors": colors})

    def _geom_torus(self, R: float, r: float) -> str:
        u_steps, v_steps = 24, 16
        verts, faces, colors = [], [], []
        pts = []
        for j in range(v_steps + 1):
            v = j / v_steps
            v_angle = v * 2 * math.pi
            row = []
            for i in range(u_steps + 1):
                u = i / u_steps
                u_angle = u * 2 * math.pi
                x = (R + r * math.cos(v_angle)) * math.cos(u_angle)
                y = (R + r * math.cos(v_angle)) * math.sin(u_angle)
                z = r * math.sin(v_angle)
                pts.append([x, y, z])
                row.append(len(pts) - 1)
            if j > 0:
                prev = len(pts) - len(row) - u_steps - 1
                for i in range(u_steps):
                    a = prev + i
                    b = prev + i + 1
                    c = prev + i + u_steps + 1
                    d = prev + i + u_steps + 2
                    self._face(faces, colors, [a, b, d, c], "#9C27B0")
        return json.dumps({"vertices": pts, "faces": faces, "colors": colors})

    def _geom_pyramid(self, base: float, height: float) -> str:
        s = base / 2
        h = height / 2
        verts, faces, colors = [], [], []
        verts.append([0, 0, h])
        verts.append([-s, -s, -h])
        verts.append([s, -s, -h])
        verts.append([s, s, -h])
        verts.append([-s, s, -h])
        c1, c2 = "#3F51B5", "#5C6BC0"
        self._face(faces, colors, [0, 1, 2], c1)
        self._face(faces, colors, [0, 2, 3], c1)
        self._face(faces, colors, [0, 3, 4], c1)
        self._face(faces, colors, [0, 4, 1], c1)
        self._face(faces, colors, [1, 2, 3, 4], c2)
        return json.dumps({"vertices": verts, "faces": faces, "colors": colors})

    @Slot(str, str, result=str)
    def render3dShape(self, shape_type: str, json_params: str) -> str:
        try:
            params = json.loads(json_params)
        except (json.JSONDecodeError, TypeError):
            params = {}
        fig = plt.figure(figsize=(7, 6), facecolor="#F5F0EB")
        ax = fig.add_subplot(111, projection="3d", facecolor="#F5F0EB")
        ax.grid(True, alpha=0.2)

        try:
            if shape_type == "cube":
                self._draw_cube(ax, params.get("size", 2))
                ax.set_title(f"Cube (side={params.get('size', 2)})", fontsize=11, fontweight="bold")
            elif shape_type == "sphere":
                r = params.get("radius", 2)
                self._draw_sphere(ax, r)
                ax.set_title(f"Sphere (r={r})", fontsize=11, fontweight="bold")
            elif shape_type == "cylinder":
                r, h = params.get("radius", 1.5), params.get("height", 3)
                self._draw_cylinder(ax, r, h)
                ax.set_title(f"Cylinder (r={r}, h={h})", fontsize=11, fontweight="bold")
            elif shape_type == "cone":
                r, h = params.get("radius", 1.5), params.get("height", 3)
                self._draw_cone(ax, r, h)
                ax.set_title(f"Cone (r={r}, h={h})", fontsize=11, fontweight="bold")
            elif shape_type == "torus":
                R, r = params.get("major_radius", 2), params.get("minor_radius", 0.8)
                self._draw_torus(ax, R, r)
                ax.set_title(f"Torus (R={R}, r={r})", fontsize=11, fontweight="bold")
            elif shape_type == "pyramid":
                s, h = params.get("base", 2), params.get("height", 2.5)
                self._draw_pyramid(ax, s, h)
                ax.set_title(f"Pyramid (base={s}, h={h})", fontsize=11, fontweight="bold")
            else:
                plt.close(fig)
                return ""
        except Exception:
            plt.close(fig)
            return ""

        ax.set_xlabel("x", fontsize=8)
        ax.set_ylabel("y", fontsize=8)
        ax.set_zlabel("z", fontsize=8)
        ax.set_box_aspect([1, 1, 1])
        max_dim = 3
        ax.set_xlim(-max_dim, max_dim)
        ax.set_ylim(-max_dim, max_dim)
        ax.set_zlim(-max_dim, max_dim)
        url = _save_fig(fig, "shape3d")
        self.plotUpdated.emit(url)
        return url

    def _draw_cube(self, ax, size: float) -> None:
        s = size / 2
        xx = np.array([-s, s, s, -s, -s, s, s, -s])
        yy = np.array([-s, -s, s, s, -s, -s, s, s])
        zz = np.array([-s, -s, -s, -s, s, s, s, s])
        idx = np.array([[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]])
        for i, j in idx:
            ax.plot([xx[i], xx[j]], [yy[i], yy[j]], [zz[i], zz[j]], color="#B48250", linewidth=2)
        faces = np.array([[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [0, 3, 7, 4], [1, 2, 6, 5]])
        for f in faces:
            xf, yf, zf = xx[f], yy[f], zz[f]
            ax.plot_surface(
                xf.reshape(2, 2), yf.reshape(2, 2), zf.reshape(2, 2),
                color="#B48250", alpha=0.15, edgecolor="none"
            )

    def _draw_sphere(self, ax, radius: float) -> None:
        u = np.linspace(0, 2 * np.pi, 30)
        v = np.linspace(0, np.pi, 20)
        x = radius * np.outer(np.cos(u), np.sin(v))
        y = radius * np.outer(np.sin(u), np.sin(v))
        z = radius * np.outer(np.ones(np.size(u)), np.cos(v))
        ax.plot_surface(x, y, z, cmap="viridis", alpha=0.75, edgecolor="none")

    def _draw_cylinder(self, ax, radius: float, height: float) -> None:
        z = np.linspace(-height / 2, height / 2, 20)
        theta = np.linspace(0, 2 * np.pi, 30)
        theta_grid, z_grid = np.meshgrid(theta, z)
        x = radius * np.cos(theta_grid)
        y = radius * np.sin(theta_grid)
        ax.plot_surface(x, y, z_grid, cmap="plasma", alpha=0.75, edgecolor="none")
        t = np.linspace(0, 2 * np.pi, 30)
        r2 = np.linspace(0, radius, 10)
        t2, r2 = np.meshgrid(t, r2)
        xc = r2 * np.cos(t2)
        yc = r2 * np.sin(t2)
        zc_bot = np.full_like(xc, -height / 2)
        zc_top = np.full_like(xc, height / 2)
        ax.plot_surface(xc, yc, zc_bot, color="#B48250", alpha=0.25, edgecolor="none")
        ax.plot_surface(xc, yc, zc_top, color="#B48250", alpha=0.25, edgecolor="none")

    def _draw_cone(self, ax, radius: float, height: float) -> None:
        n = 30
        theta = np.linspace(0, 2 * np.pi, n)
        z = np.linspace(-height / 2, height / 2, 20)
        theta_grid, z_grid = np.meshgrid(theta, z)
        r = radius * (1 - (z_grid + height / 2) / height)
        x = r * np.cos(theta_grid)
        y = r * np.sin(theta_grid)
        ax.plot_surface(x, y, z_grid, cmap="magma", alpha=0.75, edgecolor="none")
        t = np.linspace(0, 2 * np.pi, 30)
        r2 = np.linspace(0, radius, 10)
        t2, r2 = np.meshgrid(t, r2)
        xc = r2 * np.cos(t2)
        yc = r2 * np.sin(t2)
        zc = np.full_like(xc, -height / 2)
        ax.plot_surface(xc, yc, zc, color="#B48250", alpha=0.25, edgecolor="none")

    def _draw_torus(self, ax, R: float, r: float) -> None:
        u = np.linspace(0, 2 * np.pi, 30)
        v = np.linspace(0, 2 * np.pi, 20)
        u, v = np.meshgrid(u, v)
        x = (R + r * np.cos(v)) * np.cos(u)
        y = (R + r * np.cos(v)) * np.sin(u)
        z = r * np.sin(v)
        ax.plot_surface(x, y, z, cmap="twilight", alpha=0.75, edgecolor="none")

    def _draw_pyramid(self, ax, base: float, height: float) -> None:
        s = base / 2
        h = height / 2
        base_pts = np.array([[-s, -s, -h], [s, -s, -h], [s, s, -h], [-s, s, -h]])
        apex = np.array([0, 0, h])
        ax.plot_surface(
            base_pts[:, 0].reshape(2, 2), base_pts[:, 1].reshape(2, 2), base_pts[:, 2].reshape(2, 2),
            color="#B48250", alpha=0.2, edgecolor="none"
        )
        for i in range(4):
            j = (i + 1) % 4
            ax.plot([base_pts[i, 0], base_pts[j, 0]], [base_pts[i, 1], base_pts[j, 1]], [base_pts[i, 2], base_pts[j, 2]],
                    color="#B48250", linewidth=2)
            ax.plot([base_pts[i, 0], apex[0]], [base_pts[i, 1], apex[1]], [base_pts[i, 2], apex[2]],
                    color="#B48250", linewidth=2)

    @Slot(str, float, float, float, float, result=str)
    def plot3dRange(self, expression: str, x_min: float, x_max: float, y_min: float, y_max: float) -> str:
        res = 50
        try:
            xs = np.linspace(x_min, x_max, res)
            ys = np.linspace(y_min, y_max, res)
            X, Y = np.meshgrid(xs, ys)
            ns = _make_ns(x=X, y=Y)
            Z = _safe_eval_np(_clean_expr(expression), ns)
            Z = np.where(np.isfinite(Z), Z, np.nan)
        except Exception:
            return ""

        fig = plt.figure(figsize=(8, 6), facecolor="#F5F0EB")
        ax = fig.add_subplot(111, projection="3d", facecolor="#F5F0EB")
        surf = ax.plot_surface(X, Y, Z, cmap="viridis", edgecolor="none", alpha=0.9)
        ax.set_xlabel("x", fontsize=9)
        ax.set_ylabel("y", fontsize=9)
        ax.set_zlabel("z", fontsize=9)
        ax.set_title(expression, fontsize=11, fontweight="bold")
        fig.colorbar(surf, ax=ax, shrink=0.5, aspect=20)

        url = _save_fig(fig, "plot3d")
        self.plotUpdated.emit(url)
        return url
