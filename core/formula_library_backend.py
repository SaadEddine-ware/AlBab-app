from PySide6.QtCore import QObject, Slot
from PySide6.QtGui import QClipboard, QGuiApplication


class FormulaLibraryBackend(QObject):
    @Slot(str)
    def copyToClipboard(self, text: str) -> None:
        if not text:
            return
        try:
            clipboard = QGuiApplication.clipboard()
            if clipboard:
                clipboard.setText(text)
        except Exception:
            pass
