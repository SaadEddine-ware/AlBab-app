from PySide6.QtCore import QObject, Signal, Property, Slot
from core.settings_manager import SettingsManager
from core.user_manager import UserManager


class SettingsBackend(QObject):
    settingsChanged = Signal()
    userChanged = Signal()

    def __init__(self, settings: SettingsManager = None, user_manager: UserManager = None, parent=None):
        super().__init__(parent)
        self._settings = settings
        self._user_manager = user_manager
        if self._user_manager:
            self._user_manager.userChanged.connect(self.settingsChanged.emit)

    @Property(str, notify=settingsChanged)
    def language(self):
        return self._settings.get("language", "en") if self._settings else "en"

    @Property(str, notify=settingsChanged)
    def theme(self):
        return self._settings.get("theme", "frosted") if self._settings else "frosted"

    @Property(str, notify=settingsChanged)
    def autostartModel(self):
        return self._settings.get("autostart_model", "Llama 3.2") if self._settings else "Llama 3.2"

    @Property(str, notify=settingsChanged)
    def llmProvider(self):
        return self._settings.get("llm_provider", "OpenCode") if self._settings else "OpenCode"

    @Property(str, notify=settingsChanged)
    def profileName(self):
        if self._user_manager:
            return self._user_manager.currentName
        if self._settings:
            profile = self._settings.get("profile", {})
            return profile.get("first_name", "") + " " + profile.get("last_name", "")
        return ""

    @Property(str, notify=settingsChanged)
    def profileEmail(self):
        if self._user_manager:
            return self._user_manager.currentEmail
        if self._settings:
            return self._settings.get("profile", {}).get("email", "")
        return ""

    @Property(str, notify=settingsChanged)
    def profileFaculty(self):
        if self._user_manager:
            return self._user_manager.currentFaculty
        if self._settings:
            return self._settings.get("profile", {}).get("faculty", "")
        return ""

    @Slot(result=bool)
    def isOnboardingDone(self) -> bool:
        return self._settings.get("onboarding_done", False) if self._settings else False

    @Slot()
    def setOnboardingDone(self) -> None:
        if self._settings:
            self._settings.set("onboarding_done", True)

    @Slot(str, str, str)
    def updateProfile(self, first: str, last: str, faculty: str) -> None:
        first = first.strip()
        last = last.strip()
        faculty = faculty.strip()
        if self._user_manager:
            self._user_manager.updateCurrentUser(first, last, faculty)
        if self._settings:
            profile = self._settings.get("profile", {})
            profile["first_name"] = first
            profile["last_name"] = last
            profile["faculty"] = faculty
            self._settings.set("profile", profile)
        self.settingsChanged.emit()

    @Slot(str)
    def setTheme(self, v: str) -> None:
        if self._settings:
            self._settings.set("theme", v)
            self.settingsChanged.emit()

    @Slot(str)
    def setLanguage(self, v: str) -> None:
        if self._settings:
            self._settings.set("language", v)
            self.settingsChanged.emit()

    @Slot(str)
    def setAutostartModel(self, v: str) -> None:
        if self._settings:
            self._settings.set("autostart_model", v)
            self.settingsChanged.emit()

    @Slot(str)
    def setLlmProvider(self, v: str) -> None:
        if self._settings:
            self._settings.set("llm_provider", v)
            self.settingsChanged.emit()
