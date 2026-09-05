import re
from PySide6.QtCore import QObject, Slot, Signal

from core.database import DatabaseManager


class DataStore(QObject):
    dataChanged = Signal(str)

    def __init__(self, db: DatabaseManager = None, parent=None):
        super().__init__(parent)
        self._db = db

    def _safe_key(self, key: str) -> str:
        return re.sub(r"[^a-zA-Z0-9_\-]", "_", key)[:64]

    @Slot(str, str)
    def save(self, key: str, json_data: str) -> None:
        try:
            if self._db:
                self._db.kv_save(self._safe_key(key), json_data)
                self.dataChanged.emit(key)
        except Exception:
            pass

    @Slot(str, result=str)
    def load(self, key: str) -> str:
        try:
            if self._db:
                return self._db.kv_load(self._safe_key(key), "[]")
        except Exception:
            pass
        return "[]"

    @Slot(str)
    def remove(self, key: str) -> None:
        try:
            if self._db:
                self._db.kv_remove(self._safe_key(key))
                self.dataChanged.emit(key)
        except Exception:
            pass

    @Slot(str, result=bool)
    def exists(self, key: str) -> bool:
        try:
            if self._db:
                return self._db.kv_exists(self._safe_key(key))
        except Exception:
            pass
        return False
