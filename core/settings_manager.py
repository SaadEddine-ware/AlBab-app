import os

from core.database import DatabaseManager


_DEFAULTS = {
    "language": "en",
    "theme": "frosted",
    "autostart_model": "Llama 3.2",
    "llm_provider": "OpenCode",
    "onboarding_done": False,
    "profile": {
        "first_name": "",
        "last_name": "",
        "faculty": "",
    }
}


class SettingsManager:
    def __init__(self, db: DatabaseManager, dev_mode=False):
        self._db = db
        self._dev_mode = dev_mode

    @property
    def data_dir(self):
        sub = "data-dev" if self._dev_mode else "data"
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(base, sub)

    def get(self, key, default=None):
        try:
            val = self._db.get_setting(key)
        except Exception:
            val = None
        if val is not None:
            return val
        return _DEFAULTS.get(key, default)

    def set(self, key, value):
        self._db.set_setting(key, value)

    @property
    def path(self):
        return self._db.path
