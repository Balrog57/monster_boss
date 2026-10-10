"""Construit le payload REA import_managed_reconstruction.

Relie le C# décompilé (ilspycmd) aux membres statiques authentifiés
(token / signature_sha256 / normalized_il_sha256) pour un ensemble de types.
"""
import json
import os
import re
import sys

BASE = os.path.join('apk-original', 'decompiled')
EVID = os.path.join(BASE, 'evidence')
MEMBERS = os.path.join(EVID, 'managed_members_DBMGame.json')
OUT = os.path.join(EVID, 'reconstruction_input.json')

TYPES = [
    'DBMGameProject.AI.Statistics.RoomCalculator',
    'DBMGameProject.AI.Statistics.TriggerCalculator',
    'DBMGameModel.Logic.Abilities.Targets.RoomInDungeon',
    'DBMGameModel.Logic.GameBoard',
    'DBMGameProject.AI.FixedAI',
    'DBMGameModel.Logic.AbilityFactory',
]

SIG = re.compile(
    r'^\t(?P<mods>(?:public|private|protected|internal|static|override|virtual|abstract|sealed|partial|new|async|readonly)\s+)+'
    r'(?P<ret>[\w<>\[\],\.\?]+)\s+(?P<name>\w+)\s*\('
)
CTOR = re.compile(
    r'^\t(?P<mods>(?:public|private|protected|internal|static|unsafe)\s+)+'
    r'(?P<type>\w+)\s*\('
)
MEMBER = re.compile(
    r'^\t(?P<mods>(?:public|private|protected|internal|static|override|virtual|abstract|sealed|new|readonly|const)\s+)+'
    r'(?P<ret>[\w<>\[\],\.\?]+)\s+(?P<name>\w+)\s*(?:=>|\{|$)'
)


def _span(lines, i):
    """Fin de la déclaration débutant à l'indice i (accolades ou ';' final)."""
    depth = 0
    seen_open = False
    j = i
    while j < len(lines):
        line = lines[j]
        depth += line.count('{') - line.count('}')
        if '{' in line:
            seen_open = True
        if seen_open and depth <= 0:
            break
        if line.rstrip().endswith(';') and not seen_open:
            break
        j += 1
    return min(j, len(lines) - 1)


def method_spans(path, type_name):
    """(nom_déclaré, start_line, end_line, text) pour chaque membre du fichier."""
    with open(path, encoding='utf-8-sig') as f:
        lines = f.read().split('\n')
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        name = None
        if line.startswith('\t' + type_name + '(') or CTOR.match(line) and CTOR.match(line).group('type') == type_name:
            name = '.ctor'
        elif SIG.match(line):
            name = SIG.match(line).group('name')
        elif MEMBER.match(line):
            name = MEMBER.match(line).group('name')
        if name is None:
            i += 1
            continue
        end = _span(lines, i)
        # propriété { get; set; } : un seul bloc, get_/set_ partagent ce texte
        out.append((name, i + 1, end + 1, '\n'.join(lines[i:end + 1])))
        i = end + 1
    return out


def type_file(ns_type):
    """Répertoire = namespace, fichier = dernier segment."""
    parts = ns_type.split('.')
    name = parts[-1]
    ns = '.'.join(parts[:-1])
    return os.path.join(BASE, 'DBMGame', ns, name + '.cs')


def main():
    members = json.load(open(MEMBERS, encoding='utf-8-sig'))
    norm = members['normalized_result']
    sha = norm['artifact']['sha256']
    mvid = norm['module']['mvid']

    by_type = {}
    for m in norm['methods']:
        by_type.setdefault(m['declaring_type'], []).append(m)

    entries = []
    report = []
    for t in TYPES:
        path = type_file(t)
        if not os.path.exists(path):
            report.append(f'MANQUANT {t} ({path})')
            continue
        methods = by_type.get(t, [])
        if not methods:
            report.append(f'ABSENT membres {t}')
            continue
        simple = t.split('.')[-1]
        spans = method_spans(path, simple)
        by_name = {}
        for name, s, e, text in spans:
            by_name.setdefault(name, []).append((s, e, text))
        ok = 0
        misses = []
        for m in methods:
            raw = m['name']
            # get_X / set_X partagent le texte de la propriété X décompilée
            keys = [raw]
            if raw.startswith(('get_', 'set_')):
                keys.append(raw[4:])
            cands = []
            exact = False
            for k in keys:
                if by_name.get(k):
                    cands = by_name[k]
                    exact = (k == raw)
                    break
            if not cands:
                misses.append(raw)
                continue
            if exact:
                s, e, text = cands.pop(0)
            else:
                s, e, text = cands[0]  # alias get_/set_ : même bloc propriété
            body = m.get('body') or {}
            sig = m.get('signature') or {}
            if body.get('normalized_il_sha256') is None or sig.get('raw_sha256') is None:
                continue
            entries.append({
                'token': m['token'],
                'signature_sha256': sig['raw_sha256'],
                'normalized_il_sha256': body['normalized_il_sha256'],
                'reconstruction': {
                    'kind': 'decompiled-csharp',
                    'language': 'csharp',
                    'text': text,
                    'source_path': path.replace('\\', '/'),
                    'start_line': s,
                    'end_line': e,
                },
            })
            ok += 1
        uniq = sorted(set(misses))
        suffix = f' — non liés: {", ".join(uniq[:8])}' if uniq else ''
        report.append(f'{t}: {ok}/{len(methods)} méthodes liées{suffix}')

    payload = {
        'static_members': members,
        'decompiler': {
            'name': 'ilspycmd',
            'version': '9.1.0.7988',
            'family': 'ilspy',
            'executable_sha256': None,
            'options': ['-p', '--disable-updatecheck'],
        },
        'methods': entries,
        'notes': [
            'Sortie ilspycmd 9.1 (mode projet) liée aux membres statiques REA '
            f'(artifact sha256 {sha}, MVID {mvid}).',
            'Le C# est une reconstruction par décompilation, pas le source d\'origine.',
        ],
    }
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(payload, f, ensure_ascii=False)
    print('\n'.join(report))
    print(f'payload: {len(entries)} méthodes -> {OUT} '
          f'({os.path.getsize(OUT) // 1024} Ko)')


if __name__ == '__main__':
    sys.exit(main())
