#!/usr/bin/env python3
"""Serveur statique local qui imite deploy/nginx.conf pour tester l'export web sans Docker.

Comportement repris de nginx : gzip_static (sert X.gz avec Content-Encoding: gzip quand le client
accepte gzip, en gardant le Content-Type du fichier d'origine), gzip_vary, Cache-Control: no-cache,
ETag + 304. /ws : tunnel TCP vers le serveur Godot (--ws-upstream, defaut 127.0.0.1:8091) avec le controle d'Origin de
nginx.conf (403 si l'Origin n'est pas http(s)://<Host>) ; pas de limites par IP (limit_req / limit_conn : non imitees).

Usage : python tools/web_serve.py [dossier] [--port 8090] [--bind 127.0.0.1]
Le dossier par defaut est src/frontend/godot/build_web (export + `gzip -9k index.wasm index.pck index.js`).
"""
import argparse
import os
import select
import socket
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
    ws_upstream = ("127.0.0.1", 8091)  # serveur multijoueur (nginx : proxy_pass http://server:8091)
    tunnels = set()  # sockets navigateur des tunnels /ws ouverts : cut_tunnels() simule une coupure de liaison (tests en ligne)

    @classmethod
    def cut_tunnels(cls):
        """Ferme brutalement tous les tunnels /ws (coupure reseau cote navigateur) ; renvoie leur nombre."""
        n = 0
        for sock in list(cls.tunnels):
            try:
                sock.shutdown(socket.SHUT_RDWR)
                n += 1
            except OSError:
                pass
        return n

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

    def _ws_tunnel(self):
        """Imite `location = /ws` de nginx : Origin controle, puis octets recopies dans les deux sens (le handshake 101 vient du serveur Godot)."""
        origin, host = self.headers.get("Origin"), self.headers.get("Host", "")
        if origin and origin.lower().split("://", 1)[-1] != host.lower():
            self.send_error(HTTPStatus.FORBIDDEN)
            return
        try:
            up = socket.create_connection(self.ws_upstream, timeout=5)
        except OSError:
            self.send_error(HTTPStatus.BAD_GATEWAY)
            return
        up.settimeout(None)
        self.close_connection = True
        head = self.requestline + "\r\n" + "".join("%s: %s\r\n" % kv for kv in self.headers.items()) + "\r\n"
        up.sendall(head.encode("latin-1"))
        cli = self.connection
        self.tunnels.add(cli)
        try:
            while True:
                r, _, _ = select.select([cli, up], [], [], 60)
                if not r:
                    continue
                for a, b in ((cli, up), (up, cli)):
                    if a in r:
                        data = a.recv(65536)
                        if not data:
                            return
                        b.sendall(data)
        except OSError:
            pass
        finally:
            self.tunnels.discard(cli)
            up.close()

    def _send(self, head_only):
        if urlsplit(self.path).path == "/ws" and self.headers.get("Upgrade", "").lower() == "websocket":
            return self._ws_tunnel()
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
    ap.add_argument("--ws-upstream", default="127.0.0.1:8091", help="serveur multijoueur pour /ws (host:port)")
    a = ap.parse_args()
    h, _, pt = a.ws_upstream.rpartition(":")
    Handler.ws_upstream = (h, int(pt))
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
