#!/usr/bin/env python3
"""
Simple POST logging HTTP server.
"""

from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import sys
from typing import Tuple


def build_handler(allowed_path: str) -> type[BaseHTTPRequestHandler]:
    """Create a HTTP handler class bound to the allowed path."""

    class PostLoggingHandler(BaseHTTPRequestHandler):
        server_version = "PostCaptureHTTP/0.1"

        def log_message(self, format: str, *args) -> None:  # noqa: A003 - matches BaseHTTPRequestHandler signature
            sys.stderr.write(
                "%s - - [%s] %s\n"
                % (
                    self.address_string(),
                    self.log_date_time_string(),
                    format % args,
                )
            )

        def _dump_request(self, body: bytes) -> None:
            """Emit request metadata and body to stdout for operator visibility."""
            print("=== New request ===")
            print(f"Client: {self.client_address[0]}:{self.client_address[1]}")
            print(f"Path: {self.path}")
            print("Headers:")
            for key, value in self.headers.items():
                print(f"  {key}: {value}")
            print("Body:")
            print(body.decode("utf-8", errors="replace"))
            print("=== End request ===")
            sys.stdout.flush()

        def _read_body(self) -> bytes:
            length_str = self.headers.get("Content-Length", "0")
            try:
                length = int(length_str)
            except ValueError:
                length = 0
            return self.rfile.read(length)

        def _send_response(self, code: int, body: bytes) -> None:
            self.send_response(code)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self) -> None:  # noqa: N802 - required method signature
            if self.path != allowed_path:
                self._send_response(404, b"Not found\n")
                return

            body = self._read_body()
            self._dump_request(body)

            self._send_response(200, b"OK\n")

        def do_GET(self) -> None:  # noqa: N802 - required method signature
            if self.path == "/health":
                self._send_response(200, b"SLR test server is up\n")
            else:
                self._send_response(404, b"Not found\n")

        def address_string(self) -> str:  # pragma: no cover - inherited behavior undesired
            """Avoid reverse DNS lookups for speed."""
            host, _port = self.client_address
            return host

    return PostLoggingHandler


def parse_args(argv: list[str]) -> Tuple[int, str]:
    parser = argparse.ArgumentParser(description="Simple POST logging server.")
    parser.add_argument("--port", type=int, required=True, help="TCP port to listen on")
    parser.add_argument(
        "--path",
        type=str,
        required=True,
        help="Exact URL path that accepts POSTs (including leading slash)",
    )
    args = parser.parse_args(argv)
    return args.port, args.path


def main(argv: list[str] | None = None) -> int:
    port, allowed_path = parse_args(argv)

    if not allowed_path.startswith("/"):
        print("--path must start with '/'", file=sys.stderr)
        return 1

    handler_cls = build_handler(allowed_path)
    server = HTTPServer(("0.0.0.0", port), handler_cls)

    banner = f"Listening on 0.0.0.0:{port}, allowed POST path: {allowed_path}"
    print(banner)
    sys.stdout.flush()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down server...")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
