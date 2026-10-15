#!/usr/bin/env python3
"""A tiny sync server for Countdown Together.

Two phones on the same Wi-Fi can share invite codes without CloudKit
or an API key. From this folder:

    python3 tools/sync_server.py

Then in the app, Settings, Sync server, enter http://<this-computer-ip>:8787.
The iOS Simulator on this Mac can use http://127.0.0.1:8787.

Set SYNC_TOKEN to require Authorization: Bearer <token>.
Set PORT or SYNC_DATA to change the port or the folder where rooms are stored.
"""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class ServerConfig:
    def __init__(self, root: Path, token: str = "") -> None:
        self.root = root
        self.token = token
        self.root.mkdir(parents=True, exist_ok=True)


def make_handler(config: ServerConfig):
    class Handler(BaseHTTPRequestHandler):
        server_version = "CountdownSync/1.0"

        def log_message(self, fmt: str, *args) -> None:
            print("%s - %s" % (self.address_string(), fmt % args))

        def _authorized(self) -> bool:
            if not config.token:
                return True
            return self.headers.get("Authorization", "") == f"Bearer {config.token}"

        def _send(self, status: int, payload=None) -> None:
            body = b""
            if payload is not None:
                body = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if body and self.command != "HEAD":
                self.wfile.write(body)

        def _reject_unauthorized(self) -> bool:
            if self._authorized():
                return False
            self._send(401, {"error": "unauthorized"})
            return True

        def _room_code(self):
            path = self.path.split("?", 1)[0].strip("/")
            parts = path.split("/")
            if len(parts) == 3 and parts[0] == "v1" and parts[1] == "rooms":
                code = parts[2]
                if code.isalnum() and code == code.upper():
                    return code
            return None

        def _room_path(self, code: str) -> Path:
            return config.root / f"{code}.json"

        def _read_json(self):
            length = int(self.headers.get("Content-Length", "0") or "0")
            if length > 4_000_000:
                self._send(413, {"error": "payload too large"})
                return None
            raw = self.rfile.read(length) if length else b""
            try:
                return json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                self._send(400, {"error": "invalid json"})
                return None

        def do_GET(self) -> None:
            if self.path.split("?", 1)[0] in ("/health", "/health/"):
                self._send(200, {"ok": True})
                return
            if self._reject_unauthorized():
                return
            code = self._room_code()
            if code is None:
                self._send(404, {"error": "not found"})
                return
            path = self._room_path(code)
            if not path.exists():
                self._send(404, {"error": "not found"})
                return
            self._send(200, json.loads(path.read_text(encoding="utf-8")))

        def do_PUT(self) -> None:
            if self._reject_unauthorized():
                return
            code = self._room_code()
            if code is None:
                self._send(404, {"error": "not found"})
                return
            incoming = self._read_json()
            if incoming is None:
                return
            path = self._room_path(code)
            if path.exists():
                existing = json.loads(path.read_text(encoding="utf-8"))
                if updated_at(existing) > updated_at(incoming):
                    self._send(409, existing)
                    return
            path.write_text(json.dumps(incoming, separators=(",", ":")), encoding="utf-8")
            self._send(200, incoming)

        def do_DELETE(self) -> None:
            if self._reject_unauthorized():
                return
            code = self._room_code()
            if code is None:
                self._send(404, {"error": "not found"})
                return
            path = self._room_path(code)
            if path.exists():
                path.unlink()
            self._send(204, None)

    return Handler


def updated_at(payload: dict) -> str:
    countdown = payload.get("countdown")
    if not isinstance(countdown, dict):
        return ""
    value = countdown.get("updatedAt")
    return value if isinstance(value, str) else ""


def serve(port: int, config: ServerConfig) -> None:
    handler = make_handler(config)
    server = ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"Countdown sync listening on http://0.0.0.0:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping.")
    finally:
        server.server_close()


def main() -> None:
    root = Path(os.environ.get("SYNC_DATA", Path(__file__).resolve().parent / ".sync-data"))
    token = os.environ.get("SYNC_TOKEN", "")
    port = int(os.environ.get("PORT", "8787"))
    serve(port, ServerConfig(root=root, token=token))


if __name__ == "__main__":
    main()
