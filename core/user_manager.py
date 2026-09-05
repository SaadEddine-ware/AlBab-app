import json
import re
from PySide6.QtCore import QObject, Signal, Slot, Property

from core.database import DatabaseManager


def _validate_email(email: str) -> bool:
    return bool(re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email))


class UserManager(QObject):
    userChanged = Signal()
    userListChanged = Signal()

    def __init__(self, db: DatabaseManager, parent=None):
        super().__init__(parent)
        self._db = db
        self._current_user = None

    def _user_dict(self, email):
        for u in self._db.get_users():
            if u["email"] == email:
                return u
        return None

    @Property(str, notify=userChanged)
    def currentName(self):
        if self._current_user:
            return (self._current_user.get("first_name", "") + " " + self._current_user.get("last_name", "")).strip()
        return ""

    @Property(str, notify=userChanged)
    def currentEmail(self):
        if self._current_user:
            return self._current_user.get("email", "")
        return ""

    @Property(str, notify=userChanged)
    def currentFaculty(self):
        if self._current_user:
            return self._current_user.get("faculty", "")
        return ""

    @Property(str, notify=userChanged)
    def currentFirstName(self):
        if self._current_user:
            return self._current_user.get("first_name", "")
        return ""

    @Property(str, notify=userChanged)
    def currentLastName(self):
        if self._current_user:
            return self._current_user.get("last_name", "")
        return ""

    @Property(bool, notify=userChanged)
    def isLoggedIn(self):
        return self._current_user is not None

    @Slot(result=str)
    def getUsers(self) -> str:
        return json.dumps(self._db.get_users())

    @Slot(str, str, str, str, result=str)
    def register(self, first_name: str, last_name: str, email: str, faculty: str) -> str:
        first_name = first_name.strip()
        last_name = last_name.strip()
        email = email.strip().lower()
        faculty = faculty.strip()

        if not first_name or not last_name:
            return json.dumps({"ok": False, "error": "Name is required"})
        if not _validate_email(email):
            return json.dumps({"ok": False, "error": "Invalid email format"})
        if not faculty:
            return json.dumps({"ok": False, "error": "Faculty is required"})

        if self._db.add_user(email, first_name, last_name, faculty):
            self._db.set_state("current_email", email)
            self._current_user = {"email": email, "first_name": first_name, "last_name": last_name, "faculty": faculty}
            self.userChanged.emit()
            self.userListChanged.emit()
            return json.dumps({"ok": True})
        return json.dumps({"ok": False, "error": "Email already registered"})

    @Slot(str, result=str)
    def login(self, email: str) -> str:
        email = email.strip().lower()
        user = self._user_dict(email)
        if user:
            self._current_user = user
            self._db.set_state("current_email", email)
            self.userChanged.emit()
            return json.dumps({"ok": True, "user": user})
        return json.dumps({"ok": False, "error": "Account not found"})

    @Slot()
    def logout(self):
        self._current_user = None
        self.userChanged.emit()

    @Slot(str, str, str, result=str)
    def updateCurrentUser(self, first_name: str, last_name: str, faculty: str) -> str:
        if not self._current_user:
            return json.dumps({"ok": False, "error": "No user logged in"})
        first_name = first_name.strip()
        last_name = last_name.strip()
        faculty = faculty.strip()
        if not first_name or not last_name:
            return json.dumps({"ok": False, "error": "Name is required"})
        email = self._current_user["email"]
        self._db.delete_user(email)
        self._db.add_user(email, first_name, last_name, faculty)
        self._current_user = {"email": email, "first_name": first_name, "last_name": last_name, "faculty": faculty}
        self.userChanged.emit()
        return json.dumps({"ok": True})

    @Slot(str, str, str, result=str)
    def registerLocal(self, first_name: str, last_name: str, faculty: str) -> str:
        first_name = first_name.strip()
        last_name = last_name.strip()
        faculty = faculty.strip()

        if not first_name or not last_name:
            return json.dumps({"ok": False, "error": "Name is required"})

        email = "local@albab.app"
        if self._db.has_any_users():
            self._db.delete_user(email)

        self._db.add_user(email, first_name, last_name, faculty)
        self._db.set_state("current_email", email)
        self._current_user = {"email": email, "first_name": first_name, "last_name": last_name, "faculty": faculty}
        self.userChanged.emit()
        self.userListChanged.emit()
        return json.dumps({"ok": True})

    @Slot(str, result=str)
    def deleteUser(self, email: str) -> str:
        email = email.strip().lower()
        self._db.delete_user(email)
        if self._current_user and self._current_user.get("email") == email:
            self._current_user = None
            self._db.set_state("current_email", "")
            self.userChanged.emit()
        self.userListChanged.emit()
        return json.dumps({"ok": True})

    @Slot(result=bool)
    def hasAnyUsers(self) -> bool:
        return self._db.has_any_users()

    @Slot(result=str)
    def getLastEmail(self) -> str:
        return self._db.get_state("current_email") or ""

    @Slot()
    def autoLogin(self):
        last_email = self._db.get_state("current_email")
        if last_email:
            user = self._user_dict(last_email)
            if user:
                self._current_user = user
                self.userChanged.emit()
