import json
from PySide6.QtCore import QObject, Slot
from core.math_engine import MathEngine


class ToolsBackend(QObject):
    def __init__(self, math_engine: MathEngine = None, parent=None):
        super().__init__(parent)
        self._math_engine = math_engine or MathEngine()

    @Slot(str, result=str)
    def calculate(self, expression: str) -> str:
        return self._math_engine.evaluate(expression)

    @Slot(str, result=str)
    def solve(self, equation: str) -> str:
        return self._math_engine.solve(equation)

    @Slot(str, result=str)
    def differentiate(self, expression: str) -> str:
        return self._math_engine.differentiate(expression)

    @Slot(str, result=str)
    def integrate(self, expression: str) -> str:
        return self._math_engine.integrate(expression)
