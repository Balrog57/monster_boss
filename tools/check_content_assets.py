"""Croise les chemins `Content/...` référencés dans le C# décompilé
avec les fichiers réellement présents dans l'APK et avec les assets déjà
extraits dans `assets/` (produits par tools/extract_apk_226.py).

Sortie : apk-original/decompiled/assets_coverage.md
"""
import os
import re

APK_CONTENT = os.path.join('apk-original', 'boss-monster-2-2-6', 'assets', 'Content')
DBM = os.path.join('apk-original', 'decompiled', 'DBMGame')
OUT = os.path.join('apk-original', 'decompiled', 'assets_coverage.md')

PATH_RE = re.compile(r'"(?:Content|content)/([^"\n]+\.(?:wpk|png|jpg|ogg|mp3|wav|ttf|fnt|atlas|json|xml|anim|spritefont))"', re.I)
BARE_RE = re.compile(r'"([A-Za-z0-9_\-/]+)\.(wpk|png|mp3|ogg|wav|ttf)"')


def list_apk():
    out = set()
    for dirpath, _d, files in os.walk(APK_CONTENT):
        for fn in files:
            full = os.path.join(dirpath, fn)
            out.add(os.path.relpath(full, APK_CONTENT).replace('\\', '/'))
    return out


def list_extracted():
    """Assets déjà produits dans assets/ (WebP, audio, fonts, data)."""
    out = set()
    for root in (os.path.join('src', 'frontend', 'assets'),):
        for dirpath, _d, files in os.walk(root):
            if 'apk_cards' in dirpath:
                continue
            for fn in files:
                if fn.startswith('.'):
                    continue
                out.add(os.path.relpath(os.path.join(dirpath, fn), root).replace('\\', '/'))
    return out


def scan_refs():
    refs = {}
    for dirpath, _d, files in os.walk(DBM):
        for fn in files:
            if not fn.endswith('.cs'):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, encoding='utf-8-sig', errors='replace') as f:
                src = f.read()
            rel = os.path.relpath(p, 'apk-original').replace('\\', '/')
            for m in PATH_RE.finditer(src):
                refs.setdefault(m.group(1).lstrip('/'), set()).add(rel)
            for m in BARE_RE.finditer(src):
                refs.setdefault(f'{m.group(1)}.{m.group(2)}', set()).add(rel)


def norm(p):
    p = p.replace('\\', '/').lstrip('/')
    return p[8:] if p.startswith('Content/') else p


def main():
    apk = list_apk()
    extracted = list_extracted()
    refs = {}
    for dirpath, _d, files in os.walk(DBM):
        for fn in files:
            if not fn.endswith('.cs'):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, encoding='utf-8-sig', errors='replace') as f:
                src = f.read()
            rel = os.path.relpath(p, 'apk-original').replace('\\', '/')
            for rx in (PATH_RE, BARE_RE):
                for m in rx.finditer(src):
                    key = (m.group(1) if rx is PATH_RE else f'{m.group(1)}.{m.group(2)}')
                    refs.setdefault(norm(key), set()).add(rel)

    # noms sans répertoire : on localise dans l'APK
    apk_by_name = {}
    for a in apk:
        apk_by_name.setdefault(a.split('/')[-1].lower(), []).append(a)

    found, missing, loose = [], [], []
    for r in sorted(refs):
        if r in apk:
            found.append(r)
        elif '/' not in r and r.lower() in apk_by_name:
            found.append(f'{r}  →  {apk_by_name[r.lower()][0]}')
        else:
            missing.append(r)

    L = ['# Couverture des assets — code C# vs APK vs `assets/` extrait', '']
    L.append(f'- Chemins `Content/...` référencés dans le C# décompilé : **{len(refs)}**')
    L.append(f'- Fichiers présents dans `assets/Content/` (APK) : **{len(apk)}**')
    L.append(f'- Fichiers déjà extraits côté projet (`assets/`, hors `apk_cards/`) : **{len(extracted)}**')
    L.append('')
    L.append('## 1. Références résolues dans l\'APK')
    L.append('')
    for f in found:
        L.append(f'- `{f}`')
    if missing:
        L.append('')
        L.append('## 2. Références non résolues (nom générique, construit dynamiquement, ou asset absent)')
        L.append('')
        for m in missing:
            srcs = ', '.join(sorted(refs[m])[:2])
            L.append(f'- `{m}` — vu dans {srcs}')
    L.append('')
    L.append('## 3. Répertoires de l\'APK non couverts par les scripts d\'extraction')
    L.append('')
    tops = {}
    for a in apk:
        tops[a.split('/')[0]] = tops.get(a.split('/')[0], 0) + 1
    for k in sorted(tops):
        L.append(f'- `{k}/` : {tops[k]} fichiers')
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(L) + '\n')
    print(f'{OUT} — {len(refs)} références, {len(found)} résolues, {len(missing)} non résolues')


if __name__ == '__main__':
    main()
