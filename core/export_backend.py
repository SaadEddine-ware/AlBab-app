import json
import os
from PySide6.QtCore import QObject, Slot, Signal


class ExportBackend(QObject):
    exportComplete = Signal(str, bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._export_dir = os.path.join(os.path.expanduser("~"), "Documents", "AlBab")
        os.makedirs(self._export_dir, exist_ok=True)

    @Slot(str, str, result=bool)
    def exportText(self, content: str, filename: str) -> bool:
        try:
            safe_filename = os.path.basename(filename)
            path = os.path.join(self._export_dir, safe_filename)
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            self.exportComplete.emit(path, True)
            return True
        except (OSError, TypeError) as e:
            self.exportComplete.emit(str(e), False)
            return False

    @Slot(str, str, result=bool)
    def exportJson(self, data: str, filename: str) -> bool:
        try:
            safe_filename = os.path.basename(filename)
            path = os.path.join(self._export_dir, safe_filename)
            with open(path, "w", encoding="utf-8") as f:
                f.write(data)
            self.exportComplete.emit(path, True)
            return True
        except (OSError, TypeError) as e:
            self.exportComplete.emit(str(e), False)
            return False

    @Slot(str, result=str)
    def getExportPath(self, filename: str) -> str:
        return os.path.join(self._export_dir, filename)

    @Slot(result=str)
    def getExportDir(self) -> str:
        return self._export_dir
