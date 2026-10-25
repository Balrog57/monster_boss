# Protocole multijoueur Boss Monster (serveur Godot headless)

Lancement : `godot --headless --path src/frontend res://godot/server/Server.tscn -- --port=8091`
Options : `--turn-timeout=60` (s, 0 = sans minuteur) `--adventure-timeout=10` `--bot-delay=350` (ms entre deux coups d'IA)
`--ttl=3600` (s, salle sans humain connecte) `--max-rooms=200` `--seat-grace=30` (s, voir Nettoyage) `--public-idle=120` (s, voir Nettoyage).

Transport : WebSocket, **trames texte JSON**, un objet par trame avec un champ `t` (type). Une connexion = une salle = un siege.
Derriere nginx : proxifier `/ws` vers `localhost:8091` (Upgrade/Connection) ; le client web derive `ws(s)://<hote-de-la-page>/ws`.
Les cles entieres des dictionnaires (`players`, `stackPassed`...) voyagent en texte ; `NetCodec.decode` les restaure.

## Client -> serveur

| t | champs | effet |
|---|---|---|
| `create` | `name`, `public` (booleen JSON, defaut `false`), `title`, `players` (2-4 ; 5-6 exigent `crash-landing` dans `sets` et n'admettent que `crash-landing`, `hidden-heroes` et `tools` (ni les autres paquets, ni les cases wiki) ; sinon `error` `bad_setup`), `sets` (ids de paquets, base toujours present), `bots` (0..players-1 : sieges IA prerempli), `turnTimeout` (s, defaut serveur), `avatar`, `wins`, `defeats` (profil affiche en salle d'attente, optionnels) | cree la salle (code de 4 lettres majuscules sans I ni O, comme l'APK ; collision => nouveau tirage), l'hote prend le siege 0. `public: true` (seul le booleen JSON compte, pas le texte `"true"`) la rend visible dans `listRooms` ; sinon elle est privee et jamais listee (le code est son seul secret). `title` : nom affiche dans la liste (nettoye comme `name` : espaces rognes, 25 caracteres au plus ; defaut `<nom de l'hote>'s game`). Le setup est valide de la meme facon pour une salle publique (`bad_setup`). |
| `join` | `code`, `name`, `avatar`, `wins`, `defeats` (optionnels, comme `create`) | prend le premier siege humain libre ; salle pleine => la partie demarre |
| `resume` | `code`, `seat`, `token` | reprend un siege (reconnexion, rechargement de page) ; rend le siege a l'humain si l'IA l'avait pris |
| `start` | - | hote seulement : lance la partie, les sieges vides deviennent des IA |
| `move` | `move: {type, args}` | doit etre exactement un coup de `Match.legal_moves(seat)` (vocabulaire de Match.gd) |
| `sync` | - | renvoie lobby / etat courant |
| `leave` | - | salle d'attente : libere le siege (l'hote ferme la salle) ; en partie : l'IA garde le siege definitivement |
| `listRooms` | - | repond `rooms` (liste des salles publiques, voir plus bas) et inscrit la connexion aux pushes `rooms` tant qu'elle n'est dans aucune salle |
| `ping` | - | `pong` (le client en envoie un toutes les 20 s ; 120 s de silence = deconnexion ; un onglet endormi qui se reveille reping aussitot, rouvre la liaison avec `resume` si elle est morte) |

## Serveur -> client

- `joined` : `code`, `seat`, `token` (secret du siege, a garder), `host` (bool).
- `lobby` (avant la partie, a chaque changement) : `code`, `status` (`open|running|finished`), `numPlayers`, `seats: [{name|null, bot, connected, avatar, wins, defeats}]` (`avatar` = nom de fichier d'avatar sans extension, "" si inconnu ; `name` borne a 25 caracteres ; `wins` / `defeats` = compteurs locaux du joueur, cosmetiques), `sets`, `host`.
- `state` (en partie, apres chaque coup ; contient aussi les champs de `lobby`) : `seat`, `view` (G filtre pour CE siege, format de `Match.G`),
  `moves` (coups legaux de ce siege), `deadline` (ms unix de fin du delai en cours, 0 = aucun), `awaited` (sieges humains dont une decision bloque la partie : le client affiche le compte a rebours quand son siege y figure), `serverTime` (le client en deduit le decalage d'horloge).
- `error` : `message`, `code` (`bad_message|bad_setup|bad_move|busy|full|not_found|bad_token|forbidden|bad_state|no_seat|illegal`). `bad_move` : le champ `move` de `move` n'est pas un objet. Un coup illegal (`illegal`) est suivi d'un `state` de resynchronisation. Anti-force-brute : 5 echecs `join`/`resume` (`not_found`/`bad_token`) sur UNE connexion la coupent (1008) ; les messages suivants de la meme rafale ne sont pas traites. Un joueur n'est donc plus bloque par les essais d'un autre (avant le lot 3.1, un compteur global de 5 echecs/s faisait repondre `busy` a tout le monde). Il reste une soupape globale (100 echecs `join`/`resume` par seconde sur tout le serveur : au-dela, `busy` sans consulter les salles), inatteignable par une seule IP derriere nginx. Le nombre de connexions neuves par IP est borne par nginx (`limit_req`, voir plus bas).
- `closed` : la salle n'existe plus (hote parti, TTL, salle publique abandonnee). `pong`.
- `rooms` : `rooms: [{code, title, host, numPlayers, free, sets, status}]` ; reponse a `listRooms`, et PUSH envoye aux connexions qui ont demande la liste et ne sont dans aucune salle (la demande est oubliee des qu'elles entrent dans une salle : redemander apres un `leave`). Le push part des que la liste change (creation, jonction, depart, demarrage, fermeture, siege fantome libere), regroupe : au plus un controle par 250 ms. Contenu : salles `public` ET `status == "open"` ET `free > 0` uniquement (une salle pleine, en cours ou terminee n'est jamais listee), 50 entrees au plus dans l'ordre de creation ; `host` = nom de l'hote, `title` = titre nettoye, `free` / `numPlayers` = sieges libres / total, `sets` = paquets actifs, `status` = `open`. Jamais de jeton, d'identifiant de connexion ni de detail de siege ; un salon prive n'apparait jamais.

## Regles serveur

- Autorite : seul Match.gd (serveur) applique les coups ; le client n'envoie que des coups proposes dans `moves`.
- Minuteur : une decision attendue d'un humain (choix en attente, choix de boss, pose initiale, fenetre de sorts, pause d'aventure, tour de construction)
  a `turnTimeout` secondes (10 s pour une pause d'aventure). A l'echeance l'IA (AI.gd) joue pour lui et continue jusqu'a ce qu'il rejoue
  ou se reconnecte (`resume`). Aucun etat n'est persiste : salle supprimee `ttl` s apres le dernier humain, 10 min apres la fin de partie.
- Coup `undoBuild` (`args: [emplacement]`, sieges humains seulement, jamais l'IA) : legal tant que la salle posee CE tour par ce siege est encore face cachee et non verrouillee, donc avant son DONE (`pass`/`passBuild`) et tant qu'aucun sort ni capacite n'a ete joue depuis (par n'importe qui ; `buildRoom`, `undoBuild`, `pickBoss`, `openingDiscard` ne verrouillent pas). Effet : la carte retourne en fin de main, la salle recouverte redevient visible, `buildsThisTurn` redescend de 1. Listee dans `moves` seulement quand elle est legale (`Match._undo_build_moves`).
- Filtrage (`ViewFilter.gd`) : mains adverses, pioches (rooms/spells/heroes/epics/items), salles face cachee adverses, options des choix d'autrui
  deviennent `{"hidden": true}` (tailles conservees) ; `bossPicks` vide hors phase boss ; files internes et crochets de test retires ;
  minibosses face caches reduits a `{faceDown, hidden}` (sur la salle visible ou sur le dos d'une salle face cachee) ; journal : le moteur ecrit les lignes privees
  `{t, pub, owners}` (Match._log), le client ne recoit que du texte (`t` pour les proprietaires, `pub` pour les autres, 60 dernieres lignes) ;
  cles de joueur en liste blanche aussi (`PLAYER_PUBLIC_KEYS`). Toute cle de G inconnue est retiree (liste blanche).

## Nettoyage des salles

- Siege fantome : en salle d'attente (`open`), un siege humain NON hote dont la connexion est absente depuis plus de `--seat-grace` (30 s) est libere comme par un `leave` (le `lobby` est rediffuse ; l'ancien jeton devient `bad_token`). Un rechargement de page qui reprend (`resume`) avant la fin du delai garde son siege. L'hote n'est jamais libere par ce mecanisme : son absence ne ferme pas une salle privee (il peut partager le code dans une autre appli) ; seule la salle publique est fermee, voir ci-dessous.
- Salle publique `open` sans aucun humain connecte depuis `--public-idle` (120 s) : fermee (`closed` aux sieges connectes, retiree de la liste). Les salles privees gardent la regle `--ttl`.
- Plafond de salles par source : NON implemente. Le serveur Godot ne voit que l'adresse de nginx (`get_connected_host()` = nginx ; les en-tetes du handshake, dont `X-Forwarded-For`, ne sont pas exposes cote serveur : `get_handshake_headers()` est vide). Une connexion ne cree qu'une salle a la fois ; l'abus (200 salles creees en se reconnectant) est borne par nginx (`limit_req` : 5 ouvertures/s par IP, rafale de 20), `--max-rooms` et le nettoyage ci-dessus.

## Limites de transport

- Trame texte : 16 Kio au plus (`MAX_PACKET_BYTES`) ; au-dela la connexion est fermee en 1009 "message trop gros" et la trame n'est pas traitee. Une trame qui depasse le tampon d'entree (`inbound_buffer_size` = 64 Kio) est coupee par Godot lui-meme (1009 cote serveur, le client voit la liaison tomber). Trames binaires ignorees.
- Debit : plus de 60 messages par seconde sur une connexion => fermeture 1008. Silence de 120 s => fermeture 1001.
- Connexions : 512 au plus sur le serveur.

## nginx (deploy/nginx.conf)

- `Origin` : `/ws` repond 403 si l'en-tete `Origin` est present et different de `http(s)://<Host de la page>` (liste blanche extensible dans le `map`). Sans `Origin` (curl, CI) : accepte. Acces local `http://localhost:8090` : accepte.
- Par IP (CF-Connecting-IP quand la connexion vient d'une adresse privee, sinon l'adresse TCP) : `/ws` 5 ouvertures/s (rafale 20) et 20 liaisons ouvertes ; site statique 30 requetes/s (rafale 100) ; depassement => 429.
