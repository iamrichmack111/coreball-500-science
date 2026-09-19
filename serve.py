#!/usr/bin/env python3
import http.server, socketserver, socket, os, webbrowser
from pathlib import Path

os.chdir(Path(__file__).resolve().parent)

def free(port):
    s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    try:
        s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
        s.bind(("0.0.0.0",port))
        return True
    except OSError:
        return False
    finally:
        s.close()

port=next((p for p in range(8080,8200) if free(p)),None)
if port is None:
    raise SystemExit("No free port found from 8080 through 8199.")

class Server(socketserver.TCPServer):
    allow_reuse_address=True

url=f"http://127.0.0.1:{port}"
print(f"\nCoreball 500 Science: {url}")
print("Press Ctrl+C to stop.\n")
try:
    webbrowser.open(url)
except Exception:
    pass

with Server(("0.0.0.0",port),http.server.SimpleHTTPRequestHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
