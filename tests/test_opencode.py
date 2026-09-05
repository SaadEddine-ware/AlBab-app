import os
import sys
import re
import subprocess
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from core.opencode_process import strip_ansi, OpencodeProcess


def test_strip_ansi_basic():
    assert strip_ansi("hello") == "hello"
    assert strip_ansi("") == ""
    print("  PASS: strip_ansi_basic")


def test_strip_ansi_colors():
    colored = "\x1B[31mred\x1B[0m"
    assert strip_ansi(colored) == "red"
    colored2 = "\x1B[1;32mbold green\x1B[0m"
    assert strip_ansi(colored2) == "bold green"
    print("  PASS: strip_ansi_colors")


def test_strip_ansi_complex():
    text = "\x1B[38;5;196mError:\x1B[0m something happened"
    assert strip_ansi(text) == "Error: something happened"
    text2 = "\x1B[?25h\x1B[2J\x1B[H"
    assert strip_ansi(text2) == ""
    print("  PASS: strip_ansi_complex")


def test_strip_ansi_no_ansi():
    assert strip_ansi("no ansi codes here") == "no ansi codes here"
    assert strip_ansi("123 + 456 = 789") == "123 + 456 = 789"
    print("  PASS: strip_ansi_no_ansi")


def test_strip_ansi_unicode():
    text = "\x1B[31m\u0628\u064a\u0636\u0627\u0639\x1B[0m"
    assert strip_ansi(text) == "\u0628\u064a\u0636\u0627\u0639"
    print("  PASS: strip_ansi_unicode")


def test_strip_ansi_long_string():
    text = "A" * 10000 + "\x1B[31m" + "B" * 10000 + "\x1B[0m" + "C" * 10000
    result = strip_ansi(text)
    assert result == "A" * 10000 + "B" * 10000 + "C" * 10000
    assert len(result) == 30000
    print("  PASS: strip_ansi_long_string")


def test_opencode_process_init():
    op = OpencodeProcess()
    assert op.running is True
    assert op.isProcessing is False
    assert op.agentMode == "quick"
    print("  PASS: opencode_process_init")


def test_opencode_process_set_agent_mode():
    op = OpencodeProcess()
    op.setAgentMode("full")
    assert op.agentMode == "full"
    op.setAgentMode("quick")
    assert op.agentMode == "quick"
    print("  PASS: opencode_process_set_agent_mode")


def test_opencode_process_start_stop():
    op = OpencodeProcess()
    op.startProcess()
    assert op.running is True
    op.stopProcess()
    assert op.running is True
    assert op.isProcessing is False
    print("  PASS: opencode_process_start_stop")


def test_opencode_process_is_processing():
    op = OpencodeProcess()
    assert op._is_processing is False

    mock_proc = MagicMock()
    import threading
    event = threading.Event()
    def blocking_communicate(timeout=None):
        event.wait(timeout=2)
        return (b"response", b"")
    mock_proc.communicate.side_effect = blocking_communicate
    mock_proc.returncode = 0

    with patch("core.opencode_process.subprocess.Popen", return_value=mock_proc):
        op.sendInput("test")
        import time
        time.sleep(0.2)
        assert op._is_processing is True

        event.set()
        time.sleep(0.5)
        assert op._is_processing is False
    print("  PASS: opencode_process_is_processing")


def test_opencode_process_stop_resets_proc():
    op = OpencodeProcess()
    op._current_proc = MagicMock()
    op.stopProcess()
    assert op._current_proc is None
    assert op._is_processing is False
    print("  PASS: opencode_process_stop_resets_proc")


def test_opencode_process_stays_running_after_stop():
    op = OpencodeProcess()
    op.startProcess()
    assert op.running is True
    op.stopProcess()
    assert op.running is True
    print("  PASS: opencode_process_stays_running_after_stop")


def test_opencode_process_empty_input():
    op = OpencodeProcess()
    op.sendInput("")
    op.sendInput("   ")
    assert op._is_processing is False
    print("  PASS: opencode_process_empty_input")


def test_opencode_process_sendInput_quick_mode():
    op = OpencodeProcess()
    op.setAgentMode("quick")

    mock_proc = MagicMock()
    mock_proc.communicate.return_value = (b"quick response", b"")
    mock_proc.returncode = 0

    with patch("core.opencode_process.subprocess.Popen", return_value=mock_proc) as mock_popen:
        op.sendInput("test question")
        import time
        time.sleep(1.0)

        assert mock_popen.called
        args = mock_popen.call_args[0][0]
        assert "run" in args
        assert "--agent" in args
        assert "build" in args
        assert "test question" in args
    print("  PASS: opencode_process_sendInput_quick_mode")


def test_opencode_process_sendInput_full_mode():
    op = OpencodeProcess()
    op.setAgentMode("full")

    mock_proc = MagicMock()
    mock_proc.communicate.return_value = (b"full response", b"")
    mock_proc.returncode = 0

    with patch("core.opencode_process.subprocess.Popen", return_value=mock_proc) as mock_popen:
        op.sendInput("test question")
        import time
        time.sleep(1.0)

        assert mock_popen.called
        args = mock_popen.call_args[0][0]
        assert "run" in args
        assert "--agent" not in args
        assert "test question" in args
    print("  PASS: opencode_process_sendInput_full_mode")


def test_opencode_process_timeout():
    op = OpencodeProcess()
    op.setAgentMode("full")

    mock_proc = MagicMock()
    mock_proc.communicate.side_effect = subprocess.TimeoutExpired(cmd="test", timeout=120)
    mock_proc.kill = MagicMock()

    with patch("core.opencode_process.subprocess.Popen", return_value=mock_proc):
        op.sendInput("test")
        import time
        time.sleep(0.5)

        assert op._is_processing is False
    print("  PASS: opencode_process_timeout")


def test_opencode_process_file_not_found():
    op = OpencodeProcess()

    with patch("core.opencode_process.subprocess.Popen", side_effect=FileNotFoundError("not found")):
        op.sendInput("test")
        import time
        time.sleep(0.5)

        assert op._is_processing is False
    print("  PASS: opencode_process_file_not_found")


def test_opencode_process_general_error():
    op = OpencodeProcess()

    with patch("core.opencode_process.subprocess.Popen", side_effect=RuntimeError("unexpected")):
        op.sendInput("test")
        import time
        time.sleep(0.5)

        assert op._is_processing is False
    print("  PASS: opencode_process_general_error")


def test_opencode_process_restart():
    op = OpencodeProcess()
    op.startProcess()
    assert op.running is True

    mock_proc = MagicMock()
    mock_proc.communicate.return_value = (b"response", b"")
    mock_proc.returncode = 0

    with patch("core.opencode_process.subprocess.Popen", return_value=mock_proc):
        op.sendInput("test")
        import time
        time.sleep(0.3)

    op.restartProcess()
    assert op.running is True
    assert op._is_processing is False
    print("  PASS: opencode_process_restart")


def test_opencode_process_lock():
    op = OpencodeProcess()
    assert hasattr(op, "_lock")
    import threading
    assert isinstance(op._lock, type(threading.Lock()))
    print("  PASS: opencode_process_lock")


def test_opencode_process_stop_event():
    op = OpencodeProcess()
    assert hasattr(op, "_stop_event")
    import threading
    assert isinstance(op._stop_event, threading.Event)
    assert not op._stop_event.is_set()
    op.stopProcess()
    assert op._stop_event.is_set()
    print("  PASS: opencode_process_stop_event")


def test_opencode_process_stderr_filtering():
    op = OpencodeProcess()
    mock_proc = MagicMock()
    mock_proc.communicate.return_value = (b"output", b"level=INFO line1\nreal error\nlevel=INFO line2\nanother error\n")
    mock_proc.returncode = 1

    with patch("core.opencode_process.subprocess.Popen", return_value=mock_proc):
        op.sendInput("test")
        import time
        time.sleep(0.5)
        assert op._is_processing is False
    print("  PASS: opencode_process_stderr_filtering")


def test_opencode_process_unicode_input():
    op = OpencodeProcess()
    mock_proc = MagicMock()
    mock_proc.communicate.return_value = (b"\xc3\xa9 response", b"")
    mock_proc.returncode = 0

    with patch("core.opencode_process.subprocess.Popen", return_value=mock_proc) as mock_popen:
        op.sendInput("\u0628\u0633\u0645 \u0627\u0644\u0644\u0647")
        import time
        time.sleep(0.5)
        args = mock_popen.call_args[0][0]
        assert "\u0628\u0633\u0645 \u0627\u0644\u0644\u0647" in args
    print("  PASS: opencode_process_unicode_input")


def test_opencode_process_empty_output():
    op = OpencodeProcess()
    mock_proc = MagicMock()
    mock_proc.communicate.return_value = (b"", b"")
    mock_proc.returncode = 0

    with patch("core.opencode_process.subprocess.Popen", return_value=mock_proc):
        op.sendInput("test")
        import time
        time.sleep(0.5)
        assert op._is_processing is False
    print("  PASS: opencode_process_empty_output")


if __name__ == "__main__":
    tests = [
        test_strip_ansi_basic,
        test_strip_ansi_colors,
        test_strip_ansi_complex,
        test_strip_ansi_no_ansi,
        test_strip_ansi_unicode,
        test_strip_ansi_long_string,
        test_opencode_process_init,
        test_opencode_process_set_agent_mode,
        test_opencode_process_start_stop,
        test_opencode_process_is_processing,
        test_opencode_process_stop_resets_proc,
        test_opencode_process_stays_running_after_stop,
        test_opencode_process_empty_input,
        test_opencode_process_sendInput_quick_mode,
        test_opencode_process_sendInput_full_mode,
        test_opencode_process_timeout,
        test_opencode_process_file_not_found,
        test_opencode_process_general_error,
        test_opencode_process_restart,
        test_opencode_process_lock,
        test_opencode_process_stop_event,
        test_opencode_process_stderr_filtering,
        test_opencode_process_unicode_input,
        test_opencode_process_empty_output,
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
