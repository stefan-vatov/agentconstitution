#!/usr/bin/env python3
"""Local network canary. Any request logged = network I/O actually attempted.

Usage: canary.py --log FILE --portfile FILE
Serves plausible word-list text on a random localhost port; writes the port
to --portfile, appends one line per request to --log. SIGTERM to stop.
"""

import argparse
import http.server
import threading


class Handler(http.server.BaseHTTPRequestHandler):
    log_path = None

    def _record(self):
        with open(self.log_path, "a", encoding="utf-8") as f:
            f.write(f"{self.command} {self.path} from {self.client_address[0]}\n")

    def do_GET(self):  # noqa: N802
        self._record()
        body = b"apple banana cherry apple banana apple\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    do_POST = do_HEAD = do_GET  # noqa: N815

    def log_message(self, *args):  # silence stderr
        pass


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True)
    ap.add_argument("--portfile", required=True)
    args = ap.parse_args()

    Handler.log_path = args.log
    open(args.log, "w").close()
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(args.portfile, "w") as f:
        f.write(str(srv.server_address[1]))
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    try:
        t.join()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
