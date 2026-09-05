from __future__ import annotations
import json
import numpy as np
from PySide6.QtCore import QObject, Slot

class Matrix:
    def __init__(self, data=None):
        if data is not None:
            if not isinstance(data, list) or not all(isinstance(r, list) for r in data):
                raise TypeError("Data must be a 2D list")
            self.data = [row[:] for row in data]
            self.rows = len(data)
            self.cols = len(data[0]) if data else 0
        else:
            self.data = []
            self.rows = 0
            self.cols = 0

    def to_numpy(self) -> np.ndarray:
        return np.array(self.data, dtype=float)

    def det(self) -> float | None:
        if self.rows != self.cols:
            return None
        return float(np.linalg.det(self.to_numpy()))

    def rank(self) -> int:
        return int(np.linalg.matrix_rank(self.to_numpy()))

    def inverse(self) -> list | None:
        try:
            inv = np.linalg.inv(self.to_numpy())
            return inv.tolist()
        except np.linalg.LinAlgError:
            return None

    def rref(self) -> list:
        import sympy
        m = sympy.Matrix(self.data)
        rref_mat, _ = m.rref()
        return np.array(rref_mat).astype(float).tolist()

    def transpose(self) -> list:
        return np.array(self.data).T.tolist()

    def multiply(self, other_data: list) -> list | None:
        a = np.array(self.data, dtype=float)
        b = np.array(other_data, dtype=float)
        if a.shape[1] != b.shape[0]:
            return None
        return (a @ b).tolist()

    def add(self, other_data: list) -> list | None:
        a = np.array(self.data, dtype=float)
        b = np.array(other_data, dtype=float)
        if a.shape != b.shape:
            return None
        return (a + b).tolist()

class MatrixBackend(QObject):
    def __init__(self):
        super().__init__()

    @Slot(str, result=str)
    def det(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            m = Matrix(data)
            r = m.det()
            return json.dumps({"ok": True, "result": r}) if r is not None else json.dumps({"ok": False, "error": "Not a square matrix"})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def rank(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            m = Matrix(data)
            return json.dumps({"ok": True, "result": m.rank()})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def inverse(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            m = Matrix(data)
            inv = m.inverse()
            if inv is None:
                return json.dumps({"ok": False, "error": "Singular matrix (no inverse)"})
            return json.dumps({"ok": True, "result": inv})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def rref(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            m = Matrix(data)
            return json.dumps({"ok": True, "result": m.rref()})
        except (json.JSONDecodeError, TypeError, ValueError, ImportError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def transpose(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            m = Matrix(data)
            return json.dumps({"ok": True, "result": m.transpose()})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, str, result=str)
    def multiply(self, json_a: str, json_b: str) -> str:
        try:
            data_a = json.loads(json_a)
            data_b = json.loads(json_b)
            m = Matrix(data_a)
            r = m.multiply(data_b)
            if r is None:
                return json.dumps({"ok": False, "error": "Dimensions incompatible"})
            return json.dumps({"ok": True, "result": r})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, str, result=str)
    def add(self, json_a: str, json_b: str) -> str:
        try:
            data_a = json.loads(json_a)
            data_b = json.loads(json_b)
            m = Matrix(data_a)
            r = m.add(data_b)
            if r is None:
                return json.dumps({"ok": False, "error": "Dimensions must match"})
            return json.dumps({"ok": True, "result": r})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})
