# deploy/Dockerfile - Boss Monster : export web Godot servi par nginx (statique)
#
# Build depuis la racine du dépôt :
#   docker build -f deploy/Dockerfile .
# (ou via deploy/docker-compose.yml, qui fixe context + dockerfile.)

# Images epinglees par digest (index multi-arch, releves le 2026-10-25) : pour mettre a jour, relire le digest du tag et remplacer le FROM.
# --- Stage 1 : import (tolérant : --import peut sortir en erreur alors que l'export réussit ;
# le test du .pck fait foi) puis export Web. Les templates 4.7.2.stable sont fournis par l'image,
# dans ~/.local/share/godot/export_templates/4.7.2.stable ; le preset n'utilise aucun template custom.
FROM barichello/godot-ci:4.7.2@sha256:cdcca31e9194fd59a68a63f4b1b9c3981716819c520cd6f7966c5d72ca7246bd AS export
WORKDIR /src
COPY . .
RUN mkdir -p /out \
 && (godot --headless --path src/frontend --import || true) \
 && godot --headless --path src/frontend --export-release Web /out/index.html \
 && test -s /out/index.pck \
 && gzip -9k /out/index.wasm /out/index.pck /out/index.js

# --- Stage 2 : nginx statique
FROM nginx:alpine@sha256:a3554c0d0b48177b1413c26e01f695334428020d9df01243fbae3e11cfd17417
COPY --from=export /out/ /usr/share/nginx/html/
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
