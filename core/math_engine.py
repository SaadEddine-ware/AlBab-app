import math
import json
import ast
import operator

from PySide6.QtCore import QObject, Slot


_SAFE_OPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.Pow: operator.pow,
    ast.USub: operator.neg,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.BitXor: operator.pow,
}

_MATH_FUNCS = {
    "sqrt": math.sqrt, "cbrt": lambda x: x ** (1 / 3),
    "sin": math.sin, "cos": math.cos, "tan": math.tan,
    "asin": math.asin, "acos": math.acos, "atan": math.atan, "atan2": math.atan2,
    "sinh": math.sinh, "cosh": math.cosh, "tanh": math.tanh,
    "asinh": math.asinh, "acosh": math.acosh, "atanh": math.atanh,
    "log": math.log10, "ln": math.log, "log2": math.log2,
    "abs": abs, "floor": math.floor, "ceil": math.ceil,
    "round": round, "exp": math.exp,
    "radians": math.radians, "degrees": math.degrees,
    "factorial": math.factorial, "gamma": math.gamma,
    "erf": math.erf, "hypot": math.hypot,
}

_MATH_CONSTS = {
    "pi": math.pi, "e": math.e, "tau": math.tau, "phi": (1 + 5 ** 0.5) / 2,
}


class _SafeEvaluator:
    def __init__(self):
        self._allowed_names = {}
        self._allowed_names.update(_MATH_FUNCS)
        self._allowed_names.update(_MATH_CONSTS)

    def eval(self, expr, variables=None):
        self._locals = variables or {}
        expr = expr.replace("^", "**").replace("\u00F7", "/").replace("\u00D7", "*")
        tree = ast.parse(expr.strip(), mode="eval")
        return self._walk(tree.body)

    def _walk(self, node):
        if isinstance(node, ast.Expression):
            return self._walk(node.body)
        elif isinstance(node, ast.Constant):
            return node.value
        elif isinstance(node, ast.BinOp):
            left = self._walk(node.left)
            right = self._walk(node.right)
            op_type = type(node.op)
            if op_type in _SAFE_OPS:
                return _SAFE_OPS[op_type](left, right)
            raise ValueError(f"Unsupported operator: {op_type}")
        elif isinstance(node, ast.UnaryOp):
            operand = self._walk(node.operand)
            op_type = type(node.op)
            if op_type in _SAFE_OPS:
                return _SAFE_OPS[op_type](operand)
            raise ValueError(f"Unsupported unary operator: {op_type}")
        elif isinstance(node, ast.Call):
            func_name = node.func.id if isinstance(node.func, ast.Name) else None
            if func_name in self._allowed_names:
                args = [self._walk(a) for a in node.args]
                return self._allowed_names[func_name](*args)
            raise ValueError(f"Unknown function: {func_name}")
        elif isinstance(node, ast.Name):
            if node.id in self._allowed_names:
                return self._allowed_names[node.id]
            if node.id in self._locals:
                return self._locals[node.id]
            raise ValueError(f"Unknown variable: {node.id}")
        else:
            raise ValueError(f"Unsupported syntax: {type(node).__name__}")


_evaluator = _SafeEvaluator()


def _format_number(v):
    if isinstance(v, float):
        if math.isnan(v) or math.isinf(v):
            return "Error"
        try:
            if v == int(v):
                return str(int(v))
        except (OverflowError, ValueError):
            return str(v)
        s = round(v, 12)
        try:
            if s == int(s):
                return str(int(s))
        except (OverflowError, ValueError):
            return str(s)
        return str(s)
    return str(v)


class MathEngine(QObject):
    @Slot(str, result=str)
    def evaluate(self, expression):
        try:
            result = _evaluator.eval(expression)
            return _format_number(result)
        except Exception as e:
            return f"Error: {e}"

    @Slot(str, float, result=str)
    def evaluate_with_x(self, expression, x):
        try:
            result = _evaluator.eval(expression, {"x": x})
            return _format_number(result)
        except Exception as e:
            return f"Error: {e}"

    @Slot(str, float, float, int, result=str)
    def plot2d(self, func, x_min, x_max, points):
        try:
            data = []
            step = (x_max - x_min) / max(points - 1, 1)
            for i in range(points):
                x = x_min + i * step
                try:
                    y = _evaluator.eval(func, {"x": x})
                    if isinstance(y, (int, float)) and not math.isnan(y) and math.isfinite(y):
                        data.append({"x": round(x, 8), "y": round(y, 8)})
                except Exception:
                    data.append({"x": round(x, 8), "y": None})
            return json.dumps(data)
        except Exception as e:
            return json.dumps({"error": str(e)})

    @Slot(str, float, float, float, float, int, result=str)
    def plot3d(self, func, x_min, x_max, y_min, y_max, resolution):
        try:
            xs = []
            ys = []
            zs = []
            step_x = (x_max - x_min) / max(resolution - 1, 1)
            step_y = (y_max - y_min) / max(resolution - 1, 1)
            for i in range(resolution):
                x = x_min + i * step_x
                xs.append(x)
            for j in range(resolution):
                y = y_min + j * step_y
                ys.append(y)
            for j in range(resolution):
                y = y_min + j * step_y
                row = []
                for i in range(resolution):
                    x = x_min + i * step_x
                    try:
                        z = _evaluator.eval(func, {"x": x, "y": y})
                        if isinstance(z, (int, float)) and not math.isnan(z) and math.isfinite(z):
                            row.append(round(z, 8))
                        else:
                            row.append(None)
                    except Exception:
                        row.append(None)
                zs.append(row)
            return json.dumps({
                "xs": [round(v, 8) for v in xs],
                "ys": [round(v, 8) for v in ys],
                "zs": zs,
            })
        except Exception as e:
            return json.dumps({"error": str(e)})

    @Slot(str, result=str)
    def solve(self, equation):
        try:
            import sympy
        except ImportError:
            return "Install sympy: pip install sympy"
        try:
            if "=" in equation:
                lhs, rhs = equation.split("=", 1)
                expr = sympy.sympify(f"({lhs}) - ({rhs})")
            else:
                expr = sympy.sympify(equation)
            var = None
            for s in expr.free_symbols:
                var = s
                break
            if var is None:
                return "No variable found"
            sol = sympy.solve(expr, var)
            if not sol:
                return "No solution found"
            steps = [f"Equation: {equation}"]
            if "=" in equation:
                steps.append(f"Rewrite: ({lhs}) - ({rhs}) = 0")
            steps.append(f"Solve for {var}:")
            for s in sol:
                steps.append(f"  {var} = {s}")
            return "\n".join(steps)
        except Exception as e:
            return f"Error: {e}"

    @Slot(str, result=str)
    def differentiate(self, expression):
        try:
            import sympy
        except ImportError:
            return "Install sympy: pip install sympy"
        try:
            expr = sympy.sympify(expression)
            var = None
            for s in expr.free_symbols:
                var = s
                break
            if var is None:
                return "No variable found"
            deriv = sympy.diff(expr, var)
            return f"f({var}) = {expression}\nf'({var}) = {deriv}"
        except Exception as e:
            return f"Error: {e}"

    @Slot(str, result=str)
    def integrate(self, expression):
        try:
            import sympy
        except ImportError:
            return "Install sympy: pip install sympy"
        try:
            expr = sympy.sympify(expression)
            var = None
            for s in expr.free_symbols:
                var = s
                break
            if var is None:
                return "No variable found"
            integral = sympy.integrate(expr, var)
            return f"\u222B {expression} d{var} = {integral} + C"
        except Exception as e:
            return f"Error: {e}"

    @Slot(str, float, float, result=str)
    def definiteIntegral(self, expression, a, b):
        try:
            import sympy
        except ImportError:
            return "Install sympy: pip install sympy"
        try:
            expr = sympy.sympify(expression)
            var = None
            for s in expr.free_symbols:
                var = s
                break
            if var is None:
                return "No variable found"
            integral = sympy.integrate(expr, (var, a, b))
            return f"\u222B[{a}, {b}] {expression} d{var} = {integral}"
        except Exception as e:
            return f"Error: {e}"
