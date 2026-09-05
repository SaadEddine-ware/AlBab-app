import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from core.database import DatabaseManager
from core.user_manager import UserManager


def _make_test_manager():
    path = os.path.join(tempfile.gettempdir(), f"test_albab_um_{os.urandom(4).hex()}.db")
    db = DatabaseManager(path)
    return UserManager(db=db), db, path


def _cleanup(db_obj):
    path = db_obj._db_path
    if path == ":memory:":
        return
    for ext in ("", "-wal", "-shm"):
        try:
            os.remove(path + ext)
        except OSError:
            pass


def _setup():
    um, db, path = _make_test_manager()
    return um, db, path


def test_register_basic():
    um, db, _ = _setup()
    result = json.loads(um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering"))
    assert result["ok"] is True
    assert um.isLoggedIn is True
    assert um.currentFirstName == "Ahmed"
    assert um.currentLastName == "Benali"
    assert um.currentEmail == "ahmed@um5.ac.ma"
    assert um.currentFaculty == "Engineering"
    _cleanup(db)
    print("  PASS: test_register_basic")


def test_register_duplicate_email():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    result = json.loads(um.register("Ali", "Alami", "ahmed@um5.ac.ma", "Science"))
    assert result["ok"] is False
    assert "already registered" in result["error"]
    _cleanup(db)
    print("  PASS: test_register_duplicate_email")


def test_register_empty_name():
    um, db, _ = _setup()
    result = json.loads(um.register("", "Benali", "test@um5.ac.ma", "Engineering"))
    assert result["ok"] is False
    assert "Name" in result["error"]
    _cleanup(db)
    print("  PASS: test_register_empty_name")


def test_register_invalid_email():
    um, db, _ = _setup()
    result = json.loads(um.register("Ahmed", "Benali", "not-an-email", "Engineering"))
    assert result["ok"] is False
    assert "email" in result["error"].lower()
    _cleanup(db)
    print("  PASS: test_register_invalid_email")


def test_register_empty_faculty():
    um, db, _ = _setup()
    result = json.loads(um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", ""))
    assert result["ok"] is False
    assert "Faculty" in result["error"]
    _cleanup(db)
    print("  PASS: test_register_empty_faculty")


def test_login_success():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    um.logout()
    result = json.loads(um.login("ahmed@um5.ac.ma"))
    assert result["ok"] is True
    assert um.isLoggedIn is True
    assert um.currentFirstName == "Ahmed"
    _cleanup(db)
    print("  PASS: test_login_success")


def test_login_not_found():
    um, db, _ = _setup()
    result = json.loads(um.login("unknown@um5.ac.ma"))
    assert result["ok"] is False
    assert "not found" in result["error"]
    _cleanup(db)
    print("  PASS: test_login_not_found")


def test_login_case_insensitive():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "Ahmed@UM5.AC.MA", "Engineering")
    um.logout()
    result = json.loads(um.login("ahmed@um5.ac.ma"))
    assert result["ok"] is True
    _cleanup(db)
    print("  PASS: test_login_case_insensitive")


def test_logout():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    assert um.isLoggedIn is True
    um.logout()
    assert um.isLoggedIn is False
    assert um.currentFirstName == ""
    _cleanup(db)
    print("  PASS: test_logout")


def test_delete_user():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    result = json.loads(um.deleteUser("ahmed@um5.ac.ma"))
    assert result["ok"] is True
    assert um.hasAnyUsers() is False
    _cleanup(db)
    print("  PASS: test_delete_user")


def test_delete_current_user():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    assert um.isLoggedIn is True
    um.deleteUser("ahmed@um5.ac.ma")
    assert um.isLoggedIn is False
    _cleanup(db)
    print("  PASS: test_delete_current_user")


def test_get_users():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    um.register("Sara", "Idrissi", "sara@um5.ac.ma", "Science")
    users = json.loads(um.getUsers())
    assert len(users) == 2
    assert users[0]["email"] == "ahmed@um5.ac.ma"
    assert users[1]["email"] == "sara@um5.ac.ma"
    _cleanup(db)
    print("  PASS: test_get_users")


def test_has_any_users():
    um, db, _ = _setup()
    assert um.hasAnyUsers() is False
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    assert um.hasAnyUsers() is True
    _cleanup(db)
    print("  PASS: test_has_any_users")


def test_get_last_email():
    um, db, _ = _setup()
    assert um.getLastEmail() == ""
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    um.logout()
    assert um.getLastEmail() == "ahmed@um5.ac.ma"
    _cleanup(db)
    print("  PASS: test_get_last_email")


def test_auto_login():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    um.logout()
    assert um.isLoggedIn is False
    um.autoLogin()
    assert um.isLoggedIn is True
    assert um.currentFirstName == "Ahmed"
    _cleanup(db)
    print("  PASS: test_auto_login")


def test_data_persistence():
    um, db, path = _make_test_manager()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    db2 = DatabaseManager(path)
    um2 = UserManager(db=db2)
    assert um2.hasAnyUsers() is True
    users = json.loads(um2.getUsers())
    assert len(users) == 1
    assert users[0]["email"] == "ahmed@um5.ac.ma"
    _cleanup(db)
    _cleanup(db2)
    print("  PASS: test_data_persistence")


def test_multiple_accounts():
    um, db, _ = _setup()
    um.register("Ahmed", "Benali", "ahmed@um5.ac.ma", "Engineering")
    um.register("Sara", "Idrissi", "sara@um5.ac.ma", "Science")
    um.register("Youssef", "Tazi", "youssef@um5.ac.ma", "Medicine")
    assert um.hasAnyUsers() is True
    users = json.loads(um.getUsers())
    assert len(users) == 3
    emails = [u["email"] for u in users]
    assert "ahmed@um5.ac.ma" in emails
    assert "sara@um5.ac.ma" in emails
    assert "youssef@um5.ac.ma" in emails
    _cleanup(db)
    print("  PASS: test_multiple_accounts")


def test_register_strips_whitespace():
    um, db, _ = _setup()
    result = json.loads(um.register("  Ahmed  ", "  Benali  ", "  ahmed@um5.ac.ma  ", "  Engineering  "))
    assert result["ok"] is True
    assert um.currentFirstName == "Ahmed"
    assert um.currentEmail == "ahmed@um5.ac.ma"
    _cleanup(db)
    print("  PASS: test_register_strips_whitespace")


if __name__ == "__main__":
    tests = [
        test_register_basic,
        test_register_duplicate_email,
        test_register_empty_name,
        test_register_invalid_email,
        test_register_empty_faculty,
        test_login_success,
        test_login_not_found,
        test_login_case_insensitive,
        test_logout,
        test_delete_user,
        test_delete_current_user,
        test_get_users,
        test_has_any_users,
        test_get_last_email,
        test_auto_login,
        test_data_persistence,
        test_multiple_accounts,
        test_register_strips_whitespace,
    ]
    passed = 0
    failed = 0
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"  FAIL: {test.__name__}: {e}")
            import traceback
            traceback.print_exc()
            failed += 1
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
