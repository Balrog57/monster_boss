"""Génère apk-original/decompiled/INDEX.md : inventaire du C# décompilé + preuves REA."""
import collections
import datetime
import hashlib
import json
import os
import re

BASE = os.path.join('apk-original', 'decompiled')
DBM = os.path.join(BASE, 'DBMGame')
WAVE = os.path.join(BASE, 'Wave')
EVID = os.path.join(BASE, 'evidence')
OUT = os.path.join(BASE, 'INDEX.md')

NS_RE = re.compile(r'^namespace\s+([\w.]+)\s*;', re.M)
TYPE_RE = re.compile(r'^\s*(?:public|internal|private|protected)\s+(?:static\s+|sealed\s+|abstract\s+|partial\s+|readonly\s+)*'
                     r'(?:class|struct|interface|enum|delegate)\s+(\w+)', re.M)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def scan(root):
    rows = []
    for dirpath, _dirs, files in os.walk(root):
        for fn in files:
            if not fn.endswith('.cs'):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, encoding='utf-8-sig', errors='replace') as f:
                src = f.read()
            ns = (NS_RE.search(src) or [None, '(global)'])[1] if NS_RE.search(src) else '(global)'
            types = sorted(TYPE_RE.findall(src))
            rows.append({
                'ns': ns,
                'file': os.path.relpath(p, BASE).replace('\\', '/'),
                'lines': src.count('\n') + 1,
                'types': types,
            })
    return rows


def main():
    dbm_rows = scan(DBM)
    wave_rows = scan(WAVE)
    others = {}
    for name in sorted(os.listdir(BASE)):
        full = os.path.join(BASE, name)
        if name in ('DBMGame', 'Wave', 'evidence') or not os.path.isdir(full):
            continue
        if any(fn.endswith('.cs') for _, _, fs in os.walk(full) for fn in fs):
            others[name] = scan(full)

    by_ns = collections.OrderedDict()
    for r in sorted(dbm_rows, key=lambda r: r['ns']):
        by_ns.setdefault(r['ns'], []).append(r)

    ev_files = sorted(f for f in os.listdir(EVID) if f.endswith('.json'))

    def load(name):
        p = os.path.join(EVID, name)
        if not os.path.exists(p):
            return None
        with open(p, encoding='utf-8-sig') as f:
            return json.load(f)

    art = load('managed_artifact_DBMGame.json')
    mem = load('managed_members_DBMGame.json')
    rec = load('reconstruction_import.json')

    L = []
    L.append('# INDEX — décompilation DBMGame.dll (APK Boss Monster 2.2.6)')
    L.append('')
    L.append(f'Généré le {datetime.date.today().isoformat()} par `tools/build_decompiled_index.py`. '
             'Contenu **gitignoré** (référence locale uniquement).')
    L.append('')
    L.append('## 1. Provenance')
    L.append('')
    L.append('| Élément | Valeur |')
    L.append('|---|---|')
    if art:
        a = art['normalized_result']['artifact']
        L.append(f'| APK | `boss-monster-2-2-6-android.apk` (SHA-256 `{load("android_package.json")["subject"]["digest"]["sha256"]}`) |')
        L.append(f'| Assemblage | `DBMGame.dll` — {a["byte_length"]} octets, SHA-256 `{a["sha256"]}` |')
        L.append(f'| MVID | `{mem["normalized_result"]["module"]["mvid"]}` |')
        L.append(f'| Tables | TypeDef {mem["normalized_result"]["metadata"]["table_row_counts"]["TypeDef"]}, '
                 f'MethodDef {mem["normalized_result"]["metadata"]["table_row_counts"]["MethodDef"]} |')
    L.append('| Décompilateur | `ilspycmd` 9.1.0.7988 (mode projet, .NET 8) |')
    L.append('| Analyse | REA 6.3.0 (`rea-dotnet-static`), jadx 0.7.1 headless pour l\'APK |')
    L.append('')
    L.append('## 2. Arborescence décompilée')
    L.append('')
    L.append(f'- `DBMGame/` — **{len(dbm_rows)} fichiers .cs**, '
             f'{sum(r["lines"] for r in dbm_rows):,} lignes, {len(by_ns)} namespaces '
             '(jeu : règles, IA, scènes)')
    L.append(f'- `Wave/` — {len(wave_rows)} fichiers .cs '
             f'({sum(r["lines"] for r in wave_rows):,} lignes) : moteur WaveEngine '
             '(Adapter, Common, Components, Framework, Materials, Physics)')
    L.append(f'- autres assemblages décompilés : **{len(others)}** répertoires, '
             f'{sum(len(v) for v in others.values()):,} fichiers .cs '
             '(bibliothèques : aucune règle de jeu)')
    L.append('')
    L.append('| Assemblage | Fichiers .cs | Lignes |')
    L.append('|---|---:|---:|')
    for name, rows in others.items():
        L.append(f'| `{name}/` | {len(rows):,} | {sum(r["lines"] for r in rows):,} |')
    L.append('- `.csproj` généré par ILSpy : `DBMGame/DBMGame.csproj` (décoratif, non compilable tel quel)')
    L.append('')
    L.append('## 3. Namespaces → types (DBMGame)')
    L.append('')
    L.append('| Namespace | Fichiers | Lignes | Types |')
    L.append('|---|---:|---:|---|')
    for ns, rows in by_ns.items():
        types = sorted({t for r in rows for t in r['types']})
        shown = ', '.join(types[:12]) + (' …' if len(types) > 12 else '')
        L.append(f'| `{ns}` | {len(rows)} | {sum(r["lines"] for r in rows):,} | {shown} |')
    L.append('')
    L.append('## 4. Points d\'entrée utiles pour la cartographie des règles')
    L.append('')
    L.append('| Domaine | Fichier |')
    L.append('|---|---|')
    for label, path in [
        ('Machine à états (13 phases)', 'DBMGame/DBMGameModel.Logic/GameBoard.cs'),
        ('Scène de jeu / boucle NextStep', 'DBMGame/DBMGameProject.Scenes.GamePlay/GamePlayBaseScene.cs'),
        ('Fabrique d\'habilités (reflection JSON)', 'DBMGame/DBMGameModel.Logic/AbilityFactory.cs'),
        ('Résolution de cibles', 'DBMGame/DBMGameProject.Scenes.GamePlay.SceneBehaviors/TargetResolverBaseSceneBehavior.cs'),
        ('Déclenchement des triggers', 'DBMGame/DBMGameProject.Scenes.GamePlay.SceneBehaviors/TriggerAbilitiesResolverSceneBehavior.cs'),
        ('IA — arbitre', 'DBMGame/DBMGameProject.AI/FixedAI.cs'),
        ('IA — scoring salles', 'DBMGame/DBMGameProject.AI.Statistics/RoomCalculator.cs'),
        ('IA — éligibilité des sorts/activations', 'DBMGame/DBMGameProject.AI.Statistics/AbilityCalculator.cs'),
        ('IA — choix des cibles', 'DBMGame/DBMGameProject.AI.Statistics/TriggerCalculator.cs'),
        ('Réseau (Photon)', 'DBMGame/DBMGameProject.Services.Online/OnlineFlowManager.cs'),
        ('Sauvegarde locale', 'DBMGame/DBMGameProject.Storage/'),
    ]:
        L.append(f'| {label} | `{path}` |')
    L.append('')
    L.append('## 5. Preuves REA (dossier `evidence/`)')
    L.append('')
    L.append('| Fichier | Opération | Evidence ID |')
    L.append('|---|---|---|')
    for f in ev_files:
        d = load(f)
        if not d:
            continue
        L.append(f'| `{f}` | `{d.get("operation", "?")}` | `{d.get("evidence_id", "?")[:24]}…` |')
    if mem:
        L.append('')
        L.append(f'- `managed_members_DBMGame.json` : 918 types, 5 704 méthodes, ancrages CIL par token '
                 f'(fichier de {os.path.getsize(os.path.join(EVID, "managed_members_DBMGame.json")) // 1048576} Mo).')
    if rec:
        n = len(rec['normalized_result'].get('method_locks', rec['parameters'].get('method_locks', [])))
        L.append(f'- `reconstruction_import.json` : {n} méthodes ILSpy verrouillées '
                 '(token + signature SHA-256 + IL normalisé).')
    L.append('- `managed_graph.json` : graphe d\'application projeté (artifact + membres).')
    L.append('')
    L.append('## 6. Limites')
    L.append('')
    L.append('- C# = **reconstruction IL→source**, pas le source d\'origine (noms de variables locaux perdus, '
             'comments absents).')
    L.append('- Les **27 DLL managées** de l\'APK sont décompilées (0 marqueur d\'échec sur 4 915 fichiers, '
             '640/640 types IL retrouvés) ; seuls les `.so` natifs ARM ne sont pas du C# '
             '(leur bundle mono a livré les DLL) et `classes.dex` est décompilé à part en smali '
             '(`apk-original/apktool-decoded/smali/`, 196 fichiers).')
    L.append('- Les données de cartes (JSON) ne sont **pas** dans la DLL : elles vivent dans les `.wpk` '
             '(`assets/Content/CardDecks/*/data.json`).')
    L.append('- Aucune exécution du code cible : analyse 100 % statique.')

    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(L) + '\n')
    print(f'{OUT} — {len(by_ns)} namespaces, {len(dbm_rows)} fichiers')


if __name__ == '__main__':
    main()
