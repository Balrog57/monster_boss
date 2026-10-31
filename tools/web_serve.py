#!/usr/bin/env python3
"""Serveur statique local qui imite deploy/nginx.conf pour tester l'export web sans Docker.

Comportement repris de nginx : gzip_static (sert X.gz avec Content-Encoding: gzip quand le client
accepte gzip, en gardant le Content-Type du fichier d'origine), gzip_vary, Cache-Control: no-cache,
ETag + 304. Pas de limites par IP ni de /ws (multijoueur : non couvert ici).

Usage : python tools/web_serve.py [dossier] [--port 8090] [--bind 127.0.0.1]
Le dossier par defaut est src/frontend/godot/build_web (export + `gzip -9k index.wasm index.pck index.js`).
"""
import argparse
import os
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

ROOT_DEFAUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "frontend", "godot", "build_web")
# Types du mime.types de nginx (stock, master verifie le 2026-10-31 : js = application/javascript, wasm = application/wasm).
MIME = {
    ".html": "text/html", ".js": "application/javascript", ".wasm": "application/wasm", ".png": "image/png",
    ".css": "text/css", ".json": "application/json", ".webmanifest": "application/manifest+json",
    ".ico": "image/x-icon", ".svg": "image/svg+xml",
}
# nginx n'a pas de type pour .pck : application/octet-stream (default_type).


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    root = ""

    def log_message(self, fmt, *args):
        if os.environ.get("WEB_SERVE_QUIET") != "1":
            super().log_message(fmt, *args)

    def _resolve(self):
        path = unquote(urlsplit(self.path).path)
        full = os.path.normpath(os.path.join(self.root, path.lstrip("/")))
        if os.path.commonpath([full, self.root]) != self.root:
            return None
        if os.path.isdir(full):
            full = os.path.join(full, "index.html")
        return full if os.path.isfile(full) else None

    def _send(self, head_only):
        full = self._resolve()
        if full is None:
            body = b"404 Not Found"
            self.send_response(HTTPStatus.NOT_FOUND)
            self.send_header("Content-Type", "text/html")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if not head_only:
                self.wfile.write(body)
            return
        ext = os.path.splitext(full)[1].lower()
        ctype = MIME.get(ext, "application/octet-stream")
        send_path, gz = full, False
        if "gzip" in self.headers.get("Accept-Encoding", "") and os.path.isfile(full + ".gz"):
            send_path, gz = full + ".gz", True  # gzip_static on
        st = os.stat(send_path)
        etag = '"%x-%x"' % (int(st.st_mtime), st.st_size)
        if self.headers.get("If-None-Match") == etag:
            self.send_response(HTTPStatus.NOT_MODIFIED)
            self.send_header("ETag", etag)
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(st.st_size))
        self.send_header("ETag", etag)
        self.send_header("Cache-Control", "no-cache")
        if gz or os.path.isfile(full + ".gz"):
            self.send_header("Vary", "Accept-Encoding")  # gzip_vary on
        if gz:
            self.send_header("Content-Encoding", "gzip")
        self.end_headers()
        if not head_only:
            with open(send_path, "rb") as f:
                while chunk := f.read(1 << 20):
                    try:
                        self.wfile.write(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        break

    def do_GET(self):
        self._send(False)

    def do_HEAD(self):
        self._send(True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default=ROOT_DEFAUT)
    ap.add_argument("--port", type=int, default=8090)
    ap.add_argument("--bind", default="127.0.0.1", help="0.0.0.0 pour tester depuis le LAN (contexte non securise)")
    a = ap.parse_args()
    Handler.root = os.path.normpath(os.path.abspath(a.root))
    if not os.path.isfile(os.path.join(Handler.root, "index.html")):
        sys.exit("index.html introuvable dans " + Handler.root)
    srv = ThreadingHTTPServer((a.bind, a.port), Handler)
    print("http://%s:%d/  <-  %s" % (a.bind, a.port, Handler.root), flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
