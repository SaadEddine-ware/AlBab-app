from PySide6.QtCore import QObject, Signal, Property, Slot
from core.settings_manager import SettingsManager
from core.user_manager import UserManager


class MainWindowBackend(QObject):
    profileChanged = Signal()

    def __init__(self, settings: SettingsManager = None, user_manager: UserManager = None, parent=None):
        super().__init__(parent)
        self._settings = settings
        self._user_manager = user_manager
        self._first_name = ""
        self._last_name = ""
        self._faculty = ""
        if self._user_manager:
            self._user_manager.userChanged.connect(self._sync_from_user_manager)
        self._sync_from_user_manager()

    def _sync_from_user_manager(self):
        if self._user_manager:
            self._first_name = self._user_manager.currentFirstName
            self._last_name = self._user_manager.currentLastName
            self._faculty = self._user_manager.currentFaculty
        self.profileChanged.emit()

    @Property(str, notify=profileChanged)
    def firstName(self):
        return self._first_name

    @Property(str, notify=profileChanged)
    def lastName(self):
        return self._last_name

    @Property(str, notify=profileChanged)
    def faculty(self):
        return self._faculty

    @Property(bool, notify=profileChanged)
    def hasProfile(self):
        return bool(self._first_name and self._last_name)

    @Slot(str, str, str)
    def submitProfile(self, first_name, last_name, faculty):
        self._first_name = first_name.strip()
        self._last_name = last_name.strip()
        self._faculty = faculty.strip()
        if self._settings:
            self._settings.set("profile", {
                "first_name": self._first_name,
                "last_name": self._last_name,
                "faculty": self._faculty,
            })
        if self._user_manager:
            self._user_manager.registerLocal(self._first_name, self._last_name, self._faculty)
        self.profileChanged.emit()
