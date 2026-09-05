import json
import os
from PySide6.QtCore import QObject, Slot, Signal


class UndoManager(QObject):
    canUndoChanged = Signal()
    canRedoChanged = Signal()

    def __init__(self, max_history=50, parent=None):
        super().__init__(parent)
        self._undo_stack = []
        self._redo_stack = []
        self._max = max_history

    @Slot(result=bool)
    def canUndo(self) -> bool:
        return len(self._undo_stack) > 0

    @Slot(result=bool)
    def canRedo(self) -> bool:
        return len(self._redo_stack) > 0

    @Slot(str, result=bool)
    def push(self, state_json: str) -> bool:
        self._undo_stack.append(state_json)
        self._redo_stack.clear()
        if len(self._undo_stack) > self._max:
            self._undo_stack.pop(0)
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()
        return True

    @Slot(result=str)
    def undo(self) -> str:
        if not self._undo_stack:
            return ""
        state = self._undo_stack.pop()
        self._redo_stack.append(state)
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()
        if self._undo_stack:
            return self._undo_stack[-1]
        return ""

    @Slot(result=str)
    def redo(self) -> str:
        if not self._redo_stack:
            return ""
        state = self._redo_stack.pop()
        self._undo_stack.append(state)
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()
        return state

    @Slot()
    def clear(self):
        self._undo_stack.clear()
        self._redo_stack.clear()
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()

    @Slot(result=str)
    def getState(self) -> str:
        if self._undo_stack:
            return self._undo_stack[-1]
        return ""
