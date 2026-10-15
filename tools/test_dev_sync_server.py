import json
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sync_server import ServerConfig, make_handler
from http.server import ThreadingHTTPServer


def start_server(token: str = ""):
    directory = tempfile.TemporaryDirectory()
    config = ServerConfig(root=Path(directory.name), token=token)
    server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(config))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, directory


def request(server, method, path, payload=None, token=None):
    url = f"http://127.0.0.1:{server.server_address[1]}{path}"
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method=method)
    if payload is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as response:
            body = response.read()
            return response.status, json.loads(body.decode()) if body else None
    except urllib.error.HTTPError as error:
        body = error.read()
        parsed = json.loads(body.decode()) if body else None
        return error.code, parsed


class SyncServerTests(unittest.TestCase):
    def test_put_get_and_conflict(self):
        server, directory = start_server()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.addCleanup(directory.cleanup)
        room = {
            "version": 1,
            "countdown": {"title": "Lisbon", "updatedAt": "2026-06-01T12:00:00Z", "inviteCode": "ABCD2345"},
        }
        status, body = request(server, "PUT", "/v1/rooms/ABCD2345", room)
        self.assertEqual(status, 200)
        self.assertEqual(body["countdown"]["title"], "Lisbon")

        status, body = request(server, "GET", "/v1/rooms/ABCD2345")
        self.assertEqual(status, 200)
        self.assertEqual(body["countdown"]["title"], "Lisbon")

        older = {
            "version": 1,
            "countdown": {"title": "Old", "updatedAt": "2026-05-01T12:00:00Z"},
        }
        status, body = request(server, "PUT", "/v1/rooms/ABCD2345", older)
        self.assertEqual(status, 409)
        self.assertEqual(body["countdown"]["title"], "Lisbon")

        status, _ = request(server, "DELETE", "/v1/rooms/ABCD2345")
        self.assertEqual(status, 204)
        status, _ = request(server, "GET", "/v1/rooms/ABCD2345")
        self.assertEqual(status, 404)

    def test_token(self):
        server, directory = start_server(token="secret")
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.addCleanup(directory.cleanup)
        status, _ = request(server, "GET", "/health")
        self.assertEqual(status, 200)
        status, _ = request(server, "GET", "/v1/rooms/ABCD2345")
        self.assertEqual(status, 401)
        status, _ = request(server, "GET", "/v1/rooms/ABCD2345", token="secret")
        self.assertEqual(status, 404)


if __name__ == "__main__":
    unittest.main()
