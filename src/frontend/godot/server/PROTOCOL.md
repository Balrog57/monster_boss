# Protocole multijoueur Boss Monster (serveur Godot headless)

Lancement : `godot --headless --path src/frontend res://godot/server/Server.tscn -- --port=8091`
Options : `--turn-timeout=60` (s, 0 = sans minuteur) `--adventure-timeout=10` `--bot-delay=350` (ms entre deux coups d'IA)
`--ttl=3600` (s, salle sans humain connecte) `--max-rooms=200`.

Transport : WebSocket, **trames texte JSON**, un objet par trame avec un champ `t` (type). Une connexion = une salle = un siege.
Derriere nginx : proxifier `/ws` vers `localhost:8091` (Upgrade/Connection) ; le client web derive `ws(s)://<hote-de-la-page>/ws`.
Les cles entieres des dictionnaires (`players`, `stackPassed`...) voyagent en texte ; `NetCodec.decode` les restaure.

## Client -> serveur

| t | champs | effet |
|---|---|---|
| `create` | `name`, `players` (2-4), `sets` (ids de paquets, base toujours present), `bots` (0..players-1 : sieges IA prerempli), `turnTimeout` (s, defaut serveur), `avatar`, `wins`, `defeats` (profil affiche en salle d'attente, optionnels) | cree la salle (code de 4 lettres majuscules sans I ni O, comme l'APK ; collision => nouveau tirage), l'hote prend le siege 0 |
| `join` | `code`, `name`, `avatar`, `wins`, `defeats` (optionnels, comme `create`) | prend le premier siege humain libre ; salle pleine => la partie demarre |
| `resume` | `code`, `seat`, `token` | reprend un siege (reconnexion, rechargement de page) ; rend le siege a l'humain si l'IA l'avait pris |
| `start` | - | hote seulement : lance la partie, les sieges vides deviennent des IA |
| `move` | `move: {type, args}` | doit etre exactement un coup de `Match.legal_moves(seat)` (vocabulaire de Match.gd) |
| `sync` | - | renvoie lobby / etat courant |
| `leave` | - | salle d'attente : libere le siege (l'hote ferme la salle) ; en partie : l'IA garde le siege definitivement |
| `ping` | - | `pong` (le client en envoie un toutes les 20 s ; 120 s de silence = deconnexion ; un onglet endormi qui se reveille reping aussitot, rouvre la liaison avec `resume` si elle est morte) |

## Serveur -> client

- `joined` : `code`, `seat`, `token` (secret du siege, a garder), `host` (bool).
- `lobby` (avant la partie, a chaque changement) : `code`, `status` (`open|running|finished`), `numPlayers`, `seats: [{name|null, bot, connected, avatar, wins, defeats}]` (`avatar` = nom de fichier d'avatar sans extension, "" si inconnu ; `name` borne a 25 caracteres ; `wins` / `defeats` = compteurs locaux du joueur, cosmetiques), `sets`, `host`.
- `state` (en partie, apres chaque coup ; contient aussi les champs de `lobby`) : `seat`, `view` (G filtre pour CE siege, format de `Match.G`),
  `moves` (coups legaux de ce siege), `deadline` (ms unix de fin du delai en cours, 0 = aucun), `awaited` (sieges humains dont une decision bloque la partie : le client affiche le compte a rebours quand son siege y figure), `serverTime` (le client en deduit le decalage d'horloge).
- `error` : `message`, `code` (`bad_message|busy|full|not_found|bad_token|forbidden|bad_state|no_seat|illegal`). Un coup illegal est suivi d'un `state` de resynchronisation.
- `closed` : la salle n'existe plus (hote parti, TTL). `pong`.

## Regles serveur

- Autorite : seul Match.gd (serveur) applique les coups ; le client n'envoie que des coups proposes dans `moves`.
- Minuteur : une decision attendue d'un humain (choix en attente, choix de boss, pose initiale, fenetre de sorts, pause d'aventure, tour de construction)
  a `turnTimeout` secondes (10 s pour une pause d'aventure). A l'echeance l'IA (AI.gd) joue pour lui et continue jusqu'a ce qu'il rejoue
  ou se reconnecte (`resume`). Aucun etat n'est persiste : salle supprimee `ttl` s apres le dernier humain, 10 min apres la fin de partie.
- Filtrage (`ViewFilter.gd`) : mains adverses, pioches (rooms/spells/heroes/epics/items), salles face cachee adverses, options des choix d'autrui
  deviennent `{"hidden": true}` (tailles conservees) ; `bossPicks` vide hors phase boss ; files internes et crochets de test retires ;
  minibosses face caches reduits a `{faceDown, hidden}` (sur la salle visible ou sur le dos d'une salle face cachee) ; journal : le moteur ecrit les lignes privees
  `{t, pub, owners}` (Match._log), le client ne recoit que du texte (`t` pour les proprietaires, `pub` pour les autres, 60 dernieres lignes) ;
  cles de joueur en liste blanche aussi (`PLAYER_PUBLIC_KEYS`). Toute cle de G inconnue est retiree (liste blanche).
