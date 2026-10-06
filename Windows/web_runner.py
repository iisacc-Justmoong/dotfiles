"""Start an owned local web server and verify its HTTP runtime response."""
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request


def run_web(command, cwd, environment, log, expected, path='/', timeout=60):
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    command = [argument.replace('{port}', str(port)) for argument in command]
    environment = dict(environment, PORT=str(port), HOST='127.0.0.1')
    result = {'command': command, 'url': f'http://127.0.0.1:{port}{path}', 'success': False, 'log': str(log)}
    with Path(log).open('w', encoding='utf-8') as stream:
        process = subprocess.Popen(command, cwd=cwd, env=environment, stdout=stream, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        result['pid'] = process.pid
        try:
            deadline = time.monotonic() + timeout
            while process.poll() is None and time.monotonic() < deadline:
                try:
                    with urllib.request.urlopen(result['url'], timeout=2) as response:
                        body = response.read(4*1024*1024).decode('utf-8', errors='replace')
                        result.update(status=response.status, bytes=len(body.encode('utf-8')),
                                      success=response.status == 200 and expected in body)
                    if result['success']: break
                except (OSError, ValueError) as error:
                    result['last_error'] = str(error)
                time.sleep(.1)
            if process.poll() is not None: result['early_exit'] = process.returncode
        finally:
            if process.poll() is None:
                if os.name == 'nt':
                    subprocess.run(['taskkill.exe', '/PID', str(process.pid), '/T', '/F'],
                                   stdout=stream, stderr=subprocess.STDOUT, check=False)
                else: process.terminate()
                process.wait(timeout=10)
            result['server_stopped'] = process.poll() is not None
    return result
