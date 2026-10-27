# CLAUDE.md

@AGENTS.md

## Avant d'écrire du code

### Ne pas réinventer : chercher d'abord ce qui existe

Pour toute fonctionnalité que tu ne connais pas bien (shader, effet visuel, réseau, audio web, outil d'extraction, parseur...), n'écris pas from scratch :

1. Cherche d'abord dans ce dépôt : un helper, un script ou un motif déjà présent l'emporte toujours.
2. Sinon, cherche sur GitHub des projets open source qui résolvent le même problème (de préférence en Godot 4 / GDScript). Retiens-en 2 ou 3.
3. Compare les approches : taille, licence (compatible et citée), maintenance, adéquation au code existant.
4. Dis en une ligne quelle approche tu retiens et pourquoi, puis commence.

Cette règle ne s'applique pas au comportement du jeu : pour les règles, l'IA, l'interface, les durées et la géométrie, la référence reste le C# décompilé de l'APK (`apk-original/`), les règles officielles et le wiki (extensions). On porte ce que fait l'APK, on n'importe pas la logique d'un autre jeu.

### Documentation à jour : Context7, pas la mémoire

Pour toute bibliothèque, framework, API, moteur ou outil (Godot 4.7, GDScript, export web, Docker, nginx, Python, .NET...) :

- Consulte la documentation actuelle avec Context7 (`resolve-library-id` puis `query-docs`) avant d'écrire ou de corriger du code qui en dépend, même pour une API que tu crois connaître.
- N'invente jamais une bibliothèque, une fonction, une option ou un paramètre. Si Context7 ne le confirme pas, dis-le et vérifie autrement (doc officielle, code source).
- N'utilise pas d'API obsolète ou retirée : Godot 4.7, pas Godot 3 (`connect` par Callable, `@export`, `FileAccess`, etc.).
