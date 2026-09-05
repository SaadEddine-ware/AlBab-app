import threading

from PySide6.QtCore import QObject, Signal, Property


# Load keys from settings file instead of hardcoding
_BUILTIN_KEYS = []



_USE_DEFAULT = object()


class KeyRotation(QObject):
    keyChanged = Signal(str)

    def __init__(self, keys=_USE_DEFAULT, parent=None):
        super().__init__(parent)
        if keys is _USE_DEFAULT:
            keys = _BUILTIN_KEYS
        self._keys = [k.strip() for k in (keys or []) if k.strip()]
        self._idx = 0
        self._fails = {}
        self._lock = threading.Lock()

    @Property(str, notify=keyChanged)
    def current(self) -> str:
        if not self._keys:
            return ""
        return self._keys[self._idx]

    def rotate(self) -> str:
        with self._lock:
            if not self._keys:
                return ""
            self._idx = (self._idx + 1) % len(self._keys)
            self.keyChanged.emit(self.status)
            return self.current

    def mark_success(self):
        self._fails[self._idx] = 0

    def mark_failure(self):
        with self._lock:
            self._fails[self._idx] = self._fails.get(self._idx, 0) + 1

    def add_key(self, key: str):
        with self._lock:
            key = key.strip()
            if key and key not in self._keys:
                self._keys.append(key)
                self.keyChanged.emit(self.status)

    @Property(str, notify=keyChanged)
    def status(self) -> str:
        if not self._keys:
            return "No keys"
        return f"Key {self._idx + 1}/{len(self._keys)}"

    @Property(bool, notify=keyChanged)
    def has_keys(self) -> bool:
        return len(self._keys) > 0

    @Property(int, notify=keyChanged)
    def count(self) -> int:
        return len(self._keys)

    @Property(int, notify=keyChanged)
    def currentIndex(self) -> int:
        return self._idx
