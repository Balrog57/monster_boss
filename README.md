# Boss Monster - Projet complet

## Objectif
Convertir l'APK Android Boss Monster v2.4.12 en un jeu HTML jouable avec :
- Toutes les images de l'APK
- Toutes les données de cartes (JSON)
- Jeu solo contre 1-3 IA (pas juste survie 14 manches)
- Interface fidèle au jeu original

---

## Ce qui a été fait

### 1. Extraction APK
- APK décompressé → `boss-monster-extract/apk/`
- 617 fichiers extraits (81 MB) → `apk_assets_full/`
- Tous les WPK (97), JSON (11), MP3 (2), WAV (42), TTF (4), PNG (6)
- Décompilation Decompiler.com → 189 fichiers Java (wrappers Mono.Android uniquement)
- Code C# non disponible (compilé AOT en ARM)

### 2. Format WPK décodé
- **Header** : magic `WPK\0` + type string + flag compression + GZIP
- **Sprite list** : count (int32) + [name_len (byte) + name + x,y,w,h (int32×4)] × N
- **Texture metadata** : separator(0) + format + width + height + mips + data_size
- **Pixel data** : à la FIN du buffer décompressé, pas après les métadonnées
- **Format final** : E_RBG 16-bit à 2048×2048 (R=11-15, B=5-10, G=0-4, little-endian)
- **Offsets** : texture = `total_decompressed - 2048*2048*2`

### 3. Tentatives de couleurs (historique)
| Essai | Format | Offset | Résultat |
|-------|--------|--------|----------|
| v2 | Raw RGBA | 480 (350×488) | "film rose", formes OK |
| v2 fix | RGB↔BGR swap | 480 | "rouge à fond, vert en fond" |
| v3 | BGR565 | 496 (2048×2048) | 558 couleurs, "trop rouge" |
| v4 | ARGB 32-bit | 496 (2048×1024) | 1373 couleurs, très sombre |
| v5 | E_RBG | end (2048×2048) | 116 couleurs, cartes vertes ✅ |

### 4. Projet DevinABrock (React)
- Cloné depuis GitHub
- Build fonctionnel avec `--openssl-legacy-provider`
- Images APK intégrées (102 SVG → JPG)
- **État actuel** : tourne sur http://localhost:8080 avec images APK
- **Problème** : jeu solo uniquement (14 rounds, durabilité), pas d'IA

### 5. Version HTML standalone
- Fichier `boss-monster.html` (3 MB) avec 96 cartes APK intégrées
- Multi-joueurs contre 1-3 IA
- Toutes les phases : boss pick → setup → build → bait → adventure → end
- Sorts, level-up, capacités de salles
- **Problème** : interface pas fidèle, cartes trop petites ou pas visibles

---

## Ce qui manque / À faire

### Images
- [ ] **Couleurs pas encore validées** : le format E_RBG (v5) donne des cartes vertes mais l'utilisateur n'a pas confirmé
- [ ] Extraire TOUTES les cartes avec le bon format et les intégrer
- [ ] Extraire les fonds d'écran (menu_bg, etc.) en RGB565 1920×1081
- [ ] Extraire les éléments UI (boutons, HUD, logo) depuis les sprites Common/
- [ ] Intégrer les icônes de type de trésor (Tutorial/)

### Gameplay
- [ ] Reproduire le système de jeu EXACT de l'APK (pas le jeu solo modifié)
- [ ] IA fonctionnelle qui joue comme le vrai jeu
- [ ] Interface qui ressemble au jeu original (landscape, HUD en haut, donjon au centre)
- [ ] Cartes assez grandes pour être lisibles
- [ ] Gestion correcte des sorts pendant les phases appropriées

### Interface
- [ ] Utiliser boardgame.io ou refaire from scratch proprement
- [ ] Layout landscape comme l'APK
- [ ] HUD avec stats (âmes, blessures, salles, tour, pioche)
- [ ] Donjon : 5 emplacements + boss avec les VRAIES images de cartes
- [ ] Ville : héros avec leurs portraits
- [ ] Main : cartes jouables avec overlay dégât/trésor
- [ ] Panel info : détail de la carte sélectionnée
- [ ] Log des événements

---

## Fichiers importants

### Code
| Fichier | Description |
|---------|-------------|
| `Downloads/boss-monster.html` | Jeu HTML standalone (3 MB, multi-AI) |
| `Downloads/boss-monster-build/` | Build React DevinABrock (images APK) |
| `opencode/extract_wpk_v2.py` | Extraction WPK originale (RGB565, offset 496) |
| `opencode/extract_final_v2.py` | Extraction corrigée (E_RBG, end of buffer) |
| `opencode/build_complete.py` | Build HTML avec assets APK |
| `opencode/swap_images.py` | Remplacement SVG→JPG dans React |

### Assets
| Dossier | Contenu |
|---------|---------|
| `opencode/apk_assets_full/` | 617 fichiers extraits de l'APK (81 MB) |
| `opencode/extracted_assets_v2/` | Sprites extraits (couleurs incorrectes) |
| `opencode/extracted_assets_final_v2/` | Sprites extraits (E_RBG, 2048×2048, fin buffer) |
| `opencode/boss_monster_ref/` | Projet React DevinABrock cloné |
| `opencode/decompiled_apk/` | Décompilation Decompiler.com |

### Données
| Fichier | Description |
|---------|-------------|
| `apk/.../BaseDeck/data.json` | 4072 lignes, toutes les cartes BMA001-BMA096 |
| `apk/.../BaseDeck/ai_info.json` | 242 lignes, comportement IA |
| Autres decks | HiddenHeros, PlayerChoice, PowerUp, ToolsHeroKind |

---

## Problèmes en cours

1. **Couleurs des images** : après 20+ tentatives, le format E_RBG donne des résultats prometteurs mais non confirmés
2. **DevinABrock** : jeu solo modifié, pas le vrai jeu APK multi-joueurs
3. **HTML standalone** : interface pas assez fidèle, cartes pas assez visibles
4. **Pas de décompilation C#** : le code source du jeu original reste inaccessible

## Prochaines étapes suggérées

1. Valider les couleurs E_RBG avec l'utilisateur
2. Si OK → extraire toutes les cartes, remplacer dans le build React
3. Ajouter le support multi-IA au projet React (ou refaire en boardgame.io)
4. Intégrer les assets UI (fond menu, HUD, boutons, polices)
5. Ajouter les sons
