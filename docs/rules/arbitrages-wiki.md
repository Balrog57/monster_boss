# Arbitrages wiki : une ligne par decision

Regle du proprietaire : le texte imprime de la carte et le livret officiel l'emportent, lus a la lettre. Chemins relatifs a `src/frontend/godot/scripts/`, lignes approximatives (a la date de l'ecriture).

## Comportements tranches

- **RMB049 Personnel Office** : « Once per turn gain (c) when an opponent plays or promotes a Miniboss. » Lecture : « plays » = pose le miniboss, pas sa revelation. `Minibosses.gd:329` (apply_build), la revelation ne declenche plus rien.
- **RMB012 Kirax** : « once per turn you may pay (c)(c) to add one of any treasure type to any player's dungeon ». Aucune duree imprimee : l'icone est permanente (stockee dans `bonusTreasures`, comme Mirrax). `RmbAbilities.gd:685`.
- **RMB008 Oculus** : « draw a Spell when a Hero dies in a room with a Miniboss ». N'importe quel donjon, chaque proprietaire d'Oculus pioche. `Minibosses.gd:628`.
- **M12 kill / death** : glossaire « The Room in which a Hero is reduced to zero Health is the Room in which it dies ». Un « kill » des cartes wiki (PV a 0 dans la salle) declenche les « when a Hero dies ». Inchange. Les kills de l'APK (`noDeathTrigger`, Bottomless Pit, Cave-In) restent sans declencheur (parite).
- **RMB014 Monster Academy** : « gain (c)(c) for every miniboss you reveal from your hand ». Le joueur choisit combien reveler (0..n), journal public, 2 Coins chacun, les cartes restent en main. `RmbAbilities.gd:273`.
- **Miniboss sous une salle detruite** : livret p.6 « If a Room with a Miniboss is destroyed, discard the Miniboss. » Toujours defausse (le guide non officiel le faisait sauter). `Minibosses.gd:193`. Couvrir une salle fait toujours sauter le miniboss (inchange).
- **RMB069 Rage!** : « Choose a Miniboss [...] if you have only one Miniboss, you may then double the damage of that Room. » Tout miniboss, doublement facultatif, sur la salle choisie meme chez un adversaire. `RmbSpells.gd:178-190`.
- **TNL012 Eclipse** : « when you destroy a Room in your dungeon ». Seulement si le proprietaire detruit (un sort adverse ne donne rien). `TnlAbilities.gd:463` (destroy_actor), `Match.gd` (_resolve_pending_stack).
- **TNL055 Save Point** : « retrieve one Spell card from the discard pile that you played this turn ». Un sort annule a ete joue (la carte est en defausse) : il est memorise. `TnlAbilities.gd:823`, `Match.gd` (branche canceled).
- **TNL068 Shortcut!** : « skips the next Room it would enter. OR If that dungeon has five Rooms [...] next two ». Une salle desactivee reste une salle qu'il entrerait (sautee) ; cinq salles = cinq piles, face cachee comprise. `TnlAbilities.gd:730`, `TnlSpells.gd:248`.
- **CRL029 Finish Him!** : « Kill a Hero with 2 or less Health. » Inchange : PV a 0, il meurt dans la salle (glossaire), ame au proprietaire du donjon. Golden ajoute.

## Heros wiki

- **CRL017 The Prince** : texte exact lu sur la carte. Leurre « fewest total Souls minus Wounds » (`BossEngine.gd:216`), puis « may draw two rooms, two spells, or one of each » (`TnlAbilities.gd:1385`, `Match.gd:2046`).
- **CRL028 The King** : texte exact. Vote facultatif avant le leurre, un choix par joueur (XP decroissante), egalite ou aucun vote = reste en ville. `Match.gd:1383` (_king_vote), `BossEngine.gd:188`, cle `kingVote` (publique, `ViewFilter.gd`). IA : `AiWiki.king_vote_ai`.
- **RMB121 The Progenitors** : texte exact INTROUVABLE (art placeholder). Paraphrase du wiki : leurre « most treasure icons » (`BossEngine.gd:218`). La regle de placement sur les Coins (c) n'est pas implementee (texte inconnu).
- **RMB115 Warlock** : texte exact introuvable. Paraphrase « discard X Spells to give -X » : le proprietaire du donjon peut, avant la premiere salle, defausser X sorts pour que le heros perde X PV (hypothese : c'est le proprietaire qui choisit, car -X ne l'avantage que lui). Second tresor suppose : Mage + Cleric (`cards.json`, a verifier). `TnlAbilities.gd:1398`, `Match.gd:1880`. IA : l'option X = marge du heros vaut 20.
- **RMB119 Tax Collector** : idem, « pay X (c) to give -X », X Coins. Second tresor suppose : Thief + Fighter.
- **RMB083 Luz** : « When Luz is around, heroes only sometimes die » : aucune regle deterministe n'en decoule, NON implementee.

## IOD

- **IOD007 Crystal Ball** : Power-Up revele les sorts de tous (journal public), vous defaussez les votres que tient un adversaire (`IodAbilities.gd:672`). Reward : chaque adversaire ayant un sort en revele un (public), vous en prenez un (`IodAbilities.gd:302`, steps `thk_iod_cball*`). Aucune nouvelle cle de G publique hors `effects.thk.iodCball`, efface apres usage.
- **IOD011 Heart Container** : le livret l'emporte (face cachee = ame, face visible = blessure). Power-Up (un malus pour le proprietaire) : une de vos ames est retournee face visible, elle devient une blessure ; heros choisi automatiquement (celui qui vaut le moins d'ames) (`IodAbilities.gd:861`). Reward : le moteur garde l'identite de chaque ame (`soul_entry.hero`) ; l'ame d'un adversaire est retiree et le heros revient a l'entree de son donjon avec +3 (`IodAbilities.gd:316`). L'IA ne la joue jamais (gain incertain, score -5).
- **IOD018 Stolen Blueprints** : pas de sixieme salle (5 emplacements fixes) : la salle se construit dans les 5 emplacements, y compris par-dessus une salle ; detruite en fin de tour (`IodAbilities.gd:317`, `:891`). Power-Up : salle a l'icone du heros interdite le tour ou il arrive en ville (`:875`, `BossEngine.gd:130`, `TnlAbilities.gd:950`).
- **IOD023 Laser Drill** : Power-Up, de chaque pile la salle couverte la plus forte remonte (choix automatique) (`IodAbilities.gd:684`). Reward : « uncover » declenche pour chacune de vos piles (`:321`).
- **IOD026 Malakill** : un Objet (visible ou cache) passe sous une salle Monster, +3 (`IodAbilities.gd:601`, `BossEngine.gd:452`). Etat `iodUnder` sur la salle, masque aux adversaires si l'Objet est cache (`ViewFilter._room_view`). Detruite ou couverte : l'Objet retourne face cachee chez son proprietaire (`IodAbilities.gd:911`).
