# CLAUDE.md

@AGENTS.md

## Avant d'écrire du code

### Référence et open source

La référence, c'est le C# décompilé de l'APK (`apk-original/`) et le livre de règles officiel ; le wiki ne sert que pour les extensions. Pour les règles, l'IA, l'interface, les durées et la géométrie, on porte ce que fait l'APK, bizarreries comprises.

Pour la manière de l'implémenter, quand la technique est mal connue (shader, effet visuel, réseau, audio web, outil d'extraction, parseur...), n'écris pas from scratch :

1. Cherche sur GitHub des projets open source qui résolvent le même problème (de préférence en Godot 4 / GDScript). Retiens-en 2 ou 3.
2. Compare les approches : taille, licence (compatible et citée), maintenance, adéquation au code existant.
3. Dis en une ligne quelle approche tu retiens et pourquoi, puis commence.

Un projet open source ne remplace jamais la référence : il montre comment faire, l'APK et les règles disent quoi faire.

### Documentation à jour : Context7, pas la mémoire

Pour toute bibliothèque, framework, API, moteur ou outil (Godot 4.7, GDScript, export web, Docker, nginx, Python, .NET...) :

- Consulte la documentation actuelle avec Context7 (`resolve-library-id` puis `query-docs`) avant d'écrire ou de corriger du code qui en dépend, même pour une API que tu crois connaître.
- N'invente jamais une bibliothèque, une fonction, une option ou un paramètre. Si Context7 ne le confirme pas, dis-le et vérifie autrement (doc officielle, code source).
- N'utilise pas d'API obsolète ou retirée : Godot 4.7, pas Godot 3 (`connect` par Callable, `@export`, `FileAccess`, etc.).
