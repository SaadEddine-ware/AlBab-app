import json
from datetime import datetime
from PySide6.QtCore import QObject, Slot, Signal
from PySide6.QtGui import QClipboard, QGuiApplication

from core.database import DatabaseManager


class CalculatorBackend(QObject):
    historyChanged = Signal()

    def __init__(self, db: DatabaseManager = None, parent=None):
        super().__init__(parent)
        self._db = db
        self._max_history = 100
        self._history = []

    @Slot(str)
    def copyToClipboard(self, text: str) -> None:
        clipboard = QGuiApplication.clipboard()
        if clipboard:
            clipboard.setText(text)

    @Slot(str, str)
    def addToHistory(self, expression: str, result: str) -> None:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        if self._db:
            self._db.add_calc_history(expression, result, timestamp)
        self._history.insert(0, {"expr": expression, "result": result, "time": timestamp})
        if len(self._history) > self._max_history:
            self._history.pop()
        self.historyChanged.emit()

    @Slot(result=str)
    def getHistory(self) -> str:
        if self._db:
            return json.dumps(self._db.get_calc_history(self._max_history))
        return json.dumps(self._history)

    @Slot()
    def clearHistory(self) -> None:
        if self._db:
            self._db.clear_calc_history()
        self._history.clear()
        self.historyChanged.emit()

    @Slot(str, result=bool)
    def exportCsv(self, filepath: str) -> bool:
        import csv
        try:
            rows = self._db.get_calc_history(self._max_history) if self._db else self._history
            with open(filepath, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(["Expression", "Result", "Time"])
                for r in rows:
                    w.writerow([r.get("expr", ""), r.get("result", ""), r.get("time", "")])
            return True
        except Exception:
            return False
