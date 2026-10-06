"""Run a Windows desktop executable, observe its own window, and close it."""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import subprocess
import time


def process_windows(process_id):
    user = ctypes.WinDLL("user32", use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user.GetWindowTextLengthW.argtypes = [wintypes.HWND]
    user.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    found = []

    @callback_type
    def inspect(handle, _parameter):
        owner = wintypes.DWORD()
        user.GetWindowThreadProcessId(handle, ctypes.byref(owner))
        if owner.value == process_id:
            length = user.GetWindowTextLengthW(handle)
            title = ctypes.create_unicode_buffer(length + 1)
            user.GetWindowTextW(handle, title, len(title))
            kind = ctypes.create_unicode_buffer(256)
            user.GetClassNameW(handle, kind, len(kind))
            if title.value and kind.value not in ("IME", "MSCTFIME UI"):
                found.append({"handle": int(handle), "title": title.value,
                              "class": kind.value})
        return True

    if not user.EnumWindows(inspect, 0):
        raise ctypes.WinError(ctypes.get_last_error())
    return found


def run_native(executable, arguments, output, timeout=45, dwell=3, environment=None):
    if os.name != "nt":
        raise RuntimeError("This runner requires a Windows desktop session")
    executable = Path(executable).resolve(strict=True)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    started = time.monotonic()
    windows = []
    stable_since = None
    record = {"executable": str(executable), "arguments": arguments, "log": str(output)}
    with output.open("w", encoding="utf-8") as stream:
        process = subprocess.Popen([str(executable), *arguments], cwd=executable.parent,
                                   env=environment, stdout=stream, stderr=subprocess.STDOUT,
                                   startupinfo=startup)
        record["pid"] = process.pid
        try:
            while process.poll() is None and time.monotonic() - started < timeout:
                current = process_windows(process.pid)
                if current:
                    windows = current
                    if stable_since is None:
                        stable_since = time.monotonic()
                    if time.monotonic() - stable_since >= dwell:
                        break
                else:
                    stable_since = None
                time.sleep(0.1)
            observed = bool(stable_since is not None and
                            time.monotonic() - stable_since >= dwell and process.poll() is None)
            if observed:
                user = ctypes.WinDLL("user32", use_last_error=True)
                user.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT,
                                             wintypes.WPARAM, wintypes.LPARAM]
                for window in windows:
                    user.PostMessageW(window["handle"], 0x0010, 0, 0)
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    record["shutdown"] = "did_not_close"
            record.update(window_observed=observed, windows=windows,
                          returncode=process.poll(), seconds=round(time.monotonic() - started, 2))
            record["success"] = observed and process.poll() == 0
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
                record["terminated_by_runner"] = True
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=45)
    parser.add_argument("arguments", nargs="*")
    args = parser.parse_args()
    report = run_native(args.executable, args.arguments, args.report.with_suffix(".log"),
                        timeout=args.timeout)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
