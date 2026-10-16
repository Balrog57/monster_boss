class_name BoardUI
extends Control
## Interface principale du plateau de jeu Boss Monster (Board.tscn).
## Reproduction fidèle de l'UI/UX de l'APK (2.2.6) :
## - Colonne gauche : Héros en ville (HEROES IN TOWN) empilés verticalement + Défausse (DISCARD PILE).
## - Aire centrale :
##     * Donjon adverse avec background de boss dédié, badges dégâts/XP et sprite de boss sur estrade.
##     * Barre d'action centrale (Passer, Go, Choix de défausse d'ouverture, Sorts réactifs).
##     * Mon Donjon avec background dédié, 5 emplacements, badges dégâts/XP et sprite de boss sur estrade.
##     * Main du joueur en bas (cartes zoomables au survol et interactives).
## - Barre latérale droite : Statistiques rétro (Adversaire + Mon Boss avec 10 âmes, 5 blessures, trésors) et bouton LEVEL UP.
## - Animation authentique de traversée de héros (HeroCrossingBehavior.cs) avec audio et saut mortel.

const GameManager = preload("res://godot/scripts/GameManager.gd")
const OnlineGameManager = preload("res://godot/scripts/OnlineGameManager.gd")
const BossEngine = preload("res://godot/scripts/BossEngine.gd")
const CardData = preload("res://godot/scripts/CardData.gd")

var game_manager: GameManager
var on_exit_callback: Callable
var view_pid: int = 0
var seat_bar: HBoxContainer
var choice_bar: HBoxContainer
var extra_bar: HBoxContainer
var discard_pick: Array = []
var _last_phase: String = ""

const CORE_MOVE_TYPES := ["pickBoss", "buildRoom", "pass", "passBuild", "adventureNext", "resolveNextHero", "openingDiscard", "resolveLevelUpChoice"]

# Chemins des textures rétro de l'APK
const TEX_SOUL := "res://assets/ui/ingame/souls_icon.webp"
const TEX_SOUL_EMPTY := "res://assets/ui/ingame/souls_icon_empty.webp"
const TEX_WOUND := "res://assets/ui/ingame/wound_icon.webp"
const TEX_WOUND_EMPTY := "res://assets/ui/ingame/wound_icon_empty.webp"
const TEX_TREASURE_CLERIC := "res://assets/ui/ingame/icon_treasure_cleric.webp"
const TEX_TREASURE_FIGHTER := "res://assets/ui/ingame/icon_treasure_fighter.webp"
const TEX_TREASURE_MAGE := "res://assets/ui/ingame/icon_treasure_mage.webp"
const TEX_TREASURE_THIEF := "res://assets/ui/ingame/icon_treasure_thief.webp"
const TEX_TOTAL_DAMAGE := "res://assets/ui/ingame/total_damage.webp"
const TEX_XP_BADGE := "res://assets/ui/ingame/bg_position_exp.webp"
const TEX_UNKNOWN_BOSS := "res://assets/ui/ingame/unknow_boss_character.webp"

const PHASE_BANNERS := {
	"build": "res://assets/ui/ingame/build_phase.webp",
	"bait": "res://assets/ui/ingame/bait_phase.webp",
	"adventure": "res://assets/ui/ingame/adventure_phase.webp",
}

# Noeuds UI
@onready var background_tex: TextureRect = $Background
@onready var top_menu_btn: Button = $TopMenuBtn
@onready var town_container: VBoxContainer = $LeftPanel/TownScroll/TownContainer
@onready var discard_btn: TextureButton = $LeftPanel/DiscardBtn

# Donjon Adverse
@onready var foe_bg: TextureRect = $CenterArea/FoeFrame/FoeBg
@onready var foe_title: Label = $CenterArea/FoeFrame/FoeHeader/FoeTitle
@onready var foe_damage_badge: TextureRect = $CenterArea/FoeFrame/FoeHeader/FoeDamageBadge
@onready var foe_damage_label: Label = $CenterArea/FoeFrame/FoeHeader/FoeDamageBadge/Label
@onready var foe_xp_badge: TextureRect = $CenterArea/FoeFrame/FoeHeader/FoeXPBadge
@onready var foe_xp_label: Label = $CenterArea/FoeFrame/FoeHeader/FoeXPBadge/Label
@onready var foe_entrance_container: VBoxContainer = $CenterArea/FoeFrame/FoeEntrance
@onready var foe_dungeon_container: HBoxContainer = $CenterArea/FoeFrame/FoeDungeon
@onready var foe_boss_platform: Control = $CenterArea/FoeFrame/FoeBossPlatform
@onready var foe_boss_sprite: TextureRect = $CenterArea/FoeFrame/FoeBossPlatform/FoeBossSprite
@onready var foe_boss_container: CenterContainer = $CenterArea/FoeFrame/FoeBossPlatform/FoeBossContainer

# Aire Centrale / Actions
@onready var hud_status: Label = $CenterArea/CenterDivider/StatusLabel
@onready var btn_advance: BaseButton = $CenterArea/CenterDivider/ActionButtons/BtnAdvance
@onready var btn_pass: BaseButton = $CenterArea/CenterDivider/ActionButtons/BtnPass

# Mon Donjon
@onready var player_bg: TextureRect = $CenterArea/PlayerFrame/PlayerBg
@onready var player_title: Label = $CenterArea/PlayerFrame/PlayerHeader/PlayerTitle
@onready var player_damage_badge: TextureRect = $CenterArea/PlayerFrame/PlayerHeader/PlayerDamageBadge
@onready var player_damage_label: Label = $CenterArea/PlayerFrame/PlayerHeader/PlayerDamageBadge/Label
@onready var player_xp_badge: TextureRect = $CenterArea/PlayerFrame/PlayerHeader/PlayerXPBadge
@onready var player_xp_label: Label = $CenterArea/PlayerFrame/PlayerHeader/PlayerXPBadge/Label
@onready var player_entrance_container: VBoxContainer = $CenterArea/PlayerFrame/PlayerEntrance
@onready var dungeon_slots_container: HBoxContainer = $CenterArea/PlayerFrame/PlayerDungeon
@onready var player_boss_platform: Control = $CenterArea/PlayerFrame/PlayerBossPlatform
@onready var player_boss_sprite: TextureRect = $CenterArea/PlayerFrame/PlayerBossPlatform/PlayerBossSprite
@onready var player_boss_container: CenterContainer = $CenterArea/PlayerFrame/PlayerBossPlatform/PlayerBossContainer

# Main & Journal
@onready var hand_title: Label = $CenterArea/BottomArea/HandTitle
@onready var hand_container: HBoxContainer = $CenterArea/BottomArea/HandScroll/HandContainer
@onready var log_label: Label = $CenterArea/BottomArea/LogLabel

# Barre Latérale (Sidebar)
@onready var foe_boss_label: Label = $Sidebar/SidebarContent/FoeBossLabel
@onready var foe_wounds_label: Label = $Sidebar/SidebarContent/FoeStatsBox/FoeWoundsLabel
@onready var foe_souls_label: Label = $Sidebar/SidebarContent/FoeStatsBox/FoeSoulsLabel
@onready var foe_treasures_container: HBoxContainer = $Sidebar/SidebarContent/FoeTreasuresContainer
@onready var sidebar_boss_label: Label = $Sidebar/SidebarContent/BossInfoLabel
@onready var souls_container: HBoxContainer = $Sidebar/SidebarContent/SoulsContainer
@onready var wounds_container: HBoxContainer = $Sidebar/SidebarContent/WoundsContainer
@onready var treasures_container: HBoxContainer = $Sidebar/SidebarContent/TreasuresContainer
@onready var deck_info_label: Label = $Sidebar/SidebarContent/DecksInfoLabel
@onready var discard_info_label: Label = $Sidebar/SidebarContent/DiscardInfoLabel
@onready var levelup_btn: TextureButton = $Sidebar/SidebarContent/LevelUpBtn

# Phase Banner, Audio et Animation
@onready var phase_banner: TextureRect = $PhaseBanner
@onready var hero_crossing_layer: Control = $HeroCrossingLayer
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var _card_scene = preload("res://godot/scenes/Card.tscn")
var _slot_scene = preload("res://godot/scenes/DungeonSlot.tscn")
var _dungeon_slots: Array = []
var _foe_slots: Array = []
var _ai_timer: float = 0.0
var _animating_hero: bool = false
var _over_sting_played: bool = false

func _is_online() -> bool:
	return game_manager is OnlineGameManager

func _my_pid() -> int:
	if _is_online():
		return (game_manager as OnlineGameManager).my_pid
	return view_pid

func setup(p_gm: GameManager, p_exit_cb: Callable) -> void:
	game_manager = p_gm
	on_exit_callback = p_exit_cb
	_build_seat_bar()

	var action_box: HBoxContainer = $CenterArea/CenterDivider/ActionButtons
	choice_bar = HBoxContainer.new()
	choice_bar.add_theme_constant_override("separation", 8)
	action_box.add_child(choice_bar)

	extra_bar = HBoxContainer.new()
	extra_bar.add_theme_constant_override("separation", 8)
	action_box.add_child(extra_bar)

	game_manager.state_changed.connect(refresh)
	if btn_advance:
		btn_advance.pressed.connect(_on_advance_pressed)
	if btn_pass:
		btn_pass.pressed.connect(_on_pass_pressed)
	if discard_btn:
		discard_btn.pressed.connect(_on_discard_pile_pressed)
	if levelup_btn:
		levelup_btn.pressed.connect(_on_level_up_pressed)

	_init_badges()
	_init_dungeon_slots()
	AudioManager.play_music("music_dungeon_v3")
	refresh()

func _init_badges() -> void:
	if ResourceLoader.exists(TEX_TOTAL_DAMAGE):
		var t := load(TEX_TOTAL_DAMAGE)
		foe_damage_badge.texture = t
		player_damage_badge.texture = t
	if ResourceLoader.exists(TEX_XP_BADGE):
		var t := load(TEX_XP_BADGE)
		foe_xp_badge.texture = t
		player_xp_badge.texture = t

func _play_sfx(path: String) -> void:
	AudioManager.play_sfx(path)

func _build_seat_bar() -> void:
	seat_bar = HBoxContainer.new()
	seat_bar.add_theme_constant_override("separation", 8)
	var divider: HBoxContainer = $CenterArea/CenterDivider
	divider.add_child(seat_bar)
	divider.move_child(seat_bar, 0)

func _refresh_seat_bar() -> void:
	for c in seat_bar.get_children():
		c.queue_free()
	if _is_online():
		seat_bar.visible = false
		return
	var players: Dictionary = game_manager.G.get("players", {})
	var humans: Array = []
	for pid in players:
		if not (players[pid] as Dictionary).get("isAI", false):
			humans.append(int(pid))
	seat_bar.visible = humans.size() > 1
	if humans.size() <= 1:
		return
	humans.sort()
	for pid in humans:
		var b := Button.new()
		b.text = "Joueur %d" % (pid + 1)
		b.disabled = (pid == view_pid)
		var p: int = int(pid)
		b.pressed.connect(func(): view_pid = p; _sync_slot_pids(); refresh())
		seat_bar.add_child(b)

func _sync_slot_pids() -> void:
	for slot in _dungeon_slots:
		(slot as DungeonSlot).player_id = view_pid

func _init_dungeon_slots() -> void:
	for child in dungeon_slots_container.get_children():
		child.queue_free()
	_dungeon_slots.clear()

	for i in CardDB.DUNGEON_SLOTS:
		var slot: DungeonSlot = _slot_scene.instantiate()
		dungeon_slots_container.add_child(slot)
		slot.setup(game_manager, i, view_pid)
		_dungeon_slots.append(slot)

func _process(delta: float) -> void:
	if game_manager == null or game_manager.G.get("gameOver") != null:
		return
	if _animating_hero:
		return
	var players: Dictionary = game_manager.G.get("players", {})
	for pid in players:
		if (players[pid] as Dictionary).get("isAI", false):
			var moves: Array = game_manager.legal_moves(int(pid))
			var phase: String = game_manager.G.get("phase", "")
			var pc: Dictionary = game_manager.G.get("pendingChoice", {})
			var has_ai_choice: bool = not pc.is_empty() and int(pc.get("playerId", -1)) == int(pid)
			if not moves.is_empty() and (has_ai_choice or phase == "boss" or phase == "build"):
				_ai_timer += delta
				if _ai_timer > 0.5:
					_ai_timer = 0.0
					var mv = AI.pick_move(game_manager, int(pid))
					if mv != null:
						game_manager.apply_move(int(pid), mv)
						refresh()
				return

func refresh() -> void:
	if game_manager == null or game_manager.G.is_empty():
		return

	var G: Dictionary = game_manager.G
	if _is_online():
		view_pid = _my_pid()
		_sync_slot_pids()
	if not (G.get("players", {}) as Dictionary).has(view_pid):
		view_pid = 0
		_sync_slot_pids()
	_refresh_seat_bar()

	var p: Dictionary = (G["players"] as Dictionary)[view_pid]
	var phase: String = G.get("phase", "")

	# Animation de combat / traversée héroïque si en attente
	var lhf = G.get("lastHeroFight")
	if lhf != null and lhf is Dictionary and not _animating_hero:
		G.erase("lastHeroFight")
		_play_hero_crossing_animation(lhf)

	# 1. Top HUD
	if G.get("gameOver") != null:
		var w = G["gameOver"].get("winner", -1)
		if not _over_sting_played:
			_over_sting_played = true
			AudioManager.play_sfx("sting_player_win" if int(w) == view_pid else "sting_player_lose")  # APK WinnerScene/LoseScene
		hud_status.text = "PARTIE TERMINÉE — Gagnant : Joueur %s (%s)" % [str(int(w) + 1), G["gameOver"].get("reason", "")]
	else:
		var timer_str := ""
		var deadline := int(G.get("turnDeadline", 0))
		if deadline > 0:
			var now_ms: float = Time.get_unix_time_from_system() * 1000.0
			var rem_sec := clampi(int((deadline - now_ms) / 1000.0), 0, 999)
			timer_str = " | ⏱️ %ds" % rem_sec
		hud_status.text = "Tour %d — Phase %s — Joueur %d%s" % [G.get("turn", 0), phase.to_upper(), view_pid + 1, timer_str]

	# Badges et données Joueur
	var p_dmg := _get_total_dungeon_damage(p)
	var p_boss_name := str(p.get("boss", {}).get("name", "Boss"))
	var p_xp := int(p.get("boss", {}).get("xp", 0))
	player_title.text = "MON DONJON (%s)" % p_boss_name
	player_damage_label.text = "DMG %d" % p_dmg
	player_xp_label.text = "%d XP" % p_xp

	# Badges et données Adversaire
	var foe_pids := (G["players"] as Dictionary).keys().filter(func(k): return int(k) != view_pid)
	var foe_dict: Dictionary = {}
	if not foe_pids.is_empty():
		foe_dict = (G["players"] as Dictionary)[foe_pids[0]]
		var f_dmg := _get_total_dungeon_damage(foe_dict)
		var f_boss_name := str(foe_dict.get("boss", {}).get("name", "Adversaire"))
		var f_xp := int(foe_dict.get("boss", {}).get("xp", 0))
		foe_title.text = "DONJON ADVERSE (%s)" % f_boss_name
		foe_damage_label.text = "DMG %d" % f_dmg
		foe_xp_label.text = "%d XP" % f_xp
	else:
		foe_title.text = "DONJON ADVERSE (IA)"
		foe_damage_label.text = "DMG 0"
		foe_xp_label.text = "0 XP"

	# 2. Bannière de phase animée
	_refresh_phase_banner(phase)

	# 3. Barres de statistiques rétro et profil adversaire
	_refresh_sidebar(G, p, foe_dict)

	# 4. Colonne de gauche : Héros en ville (HEROES IN TOWN)
	_refresh_town(G)

	# 5. Estrades de Boss et backgrounds de donjon
	_refresh_boss_platforms(p, foe_dict)

	# 6. Entrées des donjons (files de héros attirés)
	_refresh_entrances(p, foe_dict)

	# 7. Donjon du joueur (5 emplacements)
	var dungeon: Array = p.get("dungeon", [])
	for i in range(_dungeon_slots.size()):
		var slot: DungeonSlot = _dungeon_slots[i]
		if i < dungeon.size():
			slot.set_stack(dungeon[i])
		else:
			slot.set_stack([])

	# 8. Donjon adverse (salles de l'adversaire)
	_refresh_foe_dungeon(foe_dict)

	# 9. Main du joueur
	_refresh_hand(G, p, phase)

	# 10. Boutons d'action
	var my_moves: Array = game_manager.legal_moves(_my_pid())
	btn_advance.visible = (phase == "adventure") or _has_move(my_moves, "resolveNextHero")
	btn_pass.visible = (phase == "build" or phase == "setup") or _has_move(my_moves, "pass")
	_refresh_choice_bar(G, my_moves)
	_refresh_extra_bar(G, my_moves)

	# 11. Logs
	var logs: Array = G.get("log", [])
	log_label.text = "\n".join(logs.slice(max(0, logs.size() - 2)))

func _refresh_town(G: Dictionary) -> void:
	for c in town_container.get_children():
		c.queue_free()
	for hero in G.get("town", []):
		var hero_card = _card_scene.instantiate()
		town_container.add_child(hero_card)
		hero_card.is_in_hand = false
		hero_card.custom_minimum_size = Vector2(140, 180)
		hero_card.setup(hero)

func _refresh_entrances(p: Dictionary, foe: Dictionary) -> void:
	for c in player_entrance_container.get_children():
		c.queue_free()
	for hero in p.get("entrance", []):
		var mini := _create_mini_hero_token(hero)
		player_entrance_container.add_child(mini)

	for c in foe_entrance_container.get_children():
		c.queue_free()
	for hero in foe.get("entrance", []):
		var mini := _create_mini_hero_token(hero)
		foe_entrance_container.add_child(mini)

func _create_mini_hero_token(hero: Dictionary) -> Control:
	var c := TextureRect.new()
	c.custom_minimum_size = Vector2(75, 75)
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hid := str(hero.get("id", "")).to_lower()
	var sprite_path := "res://assets/ui/characters/heroes/%s_character.webp" % hid
	if ResourceLoader.exists(sprite_path):
		c.texture = load(sprite_path)
	c.tooltip_text = "%s (PV: %s)" % [str(hero.get("name", "Héros")), str(hero.get("health", 4))]
	return c

func _refresh_boss_platforms(p: Dictionary, foe: Dictionary) -> void:
	# Joueur
	var p_boss = p.get("boss")
	if p_boss != null:
		var pid_str := str(p_boss.get("id", "")).to_lower()
		var bg_path := "res://assets/ui/dungeon/%s_bg.webp" % pid_str
		if ResourceLoader.exists(bg_path):
			player_bg.texture = load(bg_path)
		var char_path := "res://assets/ui/characters/%s_character.webp" % pid_str
		if ResourceLoader.exists(char_path):
			player_boss_sprite.texture = load(char_path)
			player_boss_sprite.visible = true
			for child in player_boss_container.get_children():
				child.queue_free()
		else:
			player_boss_sprite.visible = false
			_ensure_boss_card(player_boss_container, p_boss)
	else:
		if ResourceLoader.exists(TEX_UNKNOWN_BOSS):
			player_boss_sprite.texture = load(TEX_UNKNOWN_BOSS)
			player_boss_sprite.visible = true

	# Adversaire
	var f_boss = foe.get("boss")
	if f_boss != null:
		var fid_str := str(f_boss.get("id", "")).to_lower()
		var f_bg_path := "res://assets/ui/dungeon/%s_bg.webp" % fid_str
		if ResourceLoader.exists(f_bg_path):
			foe_bg.texture = load(f_bg_path)
		var f_char_path := "res://assets/ui/characters/%s_character.webp" % fid_str
		if ResourceLoader.exists(f_char_path):
			foe_boss_sprite.texture = load(f_char_path)
			foe_boss_sprite.visible = true
			for child in foe_boss_container.get_children():
				child.queue_free()
		else:
			foe_boss_sprite.visible = false
			_ensure_boss_card(foe_boss_container, f_boss)
	else:
		if ResourceLoader.exists(TEX_UNKNOWN_BOSS):
			foe_boss_sprite.texture = load(TEX_UNKNOWN_BOSS)
			foe_boss_sprite.visible = true

func _ensure_boss_card(container: CenterContainer, boss_dict: Dictionary) -> void:
	for c in container.get_children():
		c.queue_free()
	var boss_ui = _card_scene.instantiate()
	container.add_child(boss_ui)
	boss_ui.is_in_hand = false
	boss_ui.setup(boss_dict)

func _refresh_foe_dungeon(foe: Dictionary) -> void:
	for c in foe_dungeon_container.get_children():
		c.queue_free()
	_foe_slots.clear()

	var dungeon: Array = foe.get("dungeon", [])
	for i in CardDB.DUNGEON_SLOTS:
		var slot_ctrl := Control.new()
		slot_ctrl.custom_minimum_size = Vector2(130, 185)
		var frame := TextureRect.new()
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists("res://assets/ui/ingame/card_slot.webp"):
			frame.texture = load("res://assets/ui/ingame/card_slot.webp")
		slot_ctrl.add_child(frame)

		if i < dungeon.size():
			var r = BossEngine.active_room(dungeon[i])
			if r != null:
				frame.visible = false
				var room_ui = _card_scene.instantiate()
				slot_ctrl.add_child(room_ui)
				room_ui.is_in_hand = false
				room_ui.setup(r)
		foe_dungeon_container.add_child(slot_ctrl)
		_foe_slots.append(slot_ctrl)

func _refresh_hand(G: Dictionary, p: Dictionary, phase: String) -> void:
	for c in hand_container.get_children():
		c.queue_free()

	if phase == "boss":
		for b in G.get("bossPicks", []):
			var boss_card = _card_scene.instantiate()
			hand_container.add_child(boss_card)
			boss_card.setup(b)
			var bid = str(b.get("id", ""))
			boss_card.card_clicked.connect(func(_data):
				var is_fem := ["BMA006", "BMA007", "BMA008"].has(bid)
				_play_sfx("res://assets/audio/sfx/boss_female_intro.wav" if is_fem else "res://assets/audio/sfx/boss_male_intro.wav")
				_do({"type": "pickBoss", "args": [bid]})
			)
	else:
		var hand: Array = p.get("hand", [])
		for i in hand.size():
			var card_dict: Dictionary = hand[i]
			var card_ui = _card_scene.instantiate()
			hand_container.add_child(card_ui)
			card_ui.setup(card_dict, i)
			var idx := i
			card_ui.card_clicked.connect(func(_data): _on_hand_card_clicked(idx, card_dict))
			if discard_pick.has(idx):
				card_ui.modulate = Color(1.3, 1.3, 0.4, 1.0)
				var glow := card_ui.get_node_or_null("GlowRect")
				if glow != null:
					glow.visible = true

func _refresh_phase_banner(phase: String) -> void:
	if phase == _last_phase:
		return
	_last_phase = phase
	if phase_banner and PHASE_BANNERS.has(phase):
		var banner_path: String = PHASE_BANNERS[phase]
		if ResourceLoader.exists(banner_path):
			phase_banner.texture = load(banner_path)
			phase_banner.visible = true
			phase_banner.modulate = Color(1, 1, 1, 0)
			var tw := create_tween()
			tw.tween_property(phase_banner, "modulate:a", 1.0, 0.3)
			tw.tween_interval(1.5)
			tw.tween_property(phase_banner, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func(): phase_banner.visible = false)

func _refresh_sidebar(G: Dictionary, p: Dictionary, foe: Dictionary) -> void:
	# Info Boss Joueur
	if p.get("boss") != null:
		var bname: String = str(p["boss"].get("name", "Boss"))
		var bxp: int = int(p["boss"].get("xp", 0))
		sidebar_boss_label.text = "%s (%d XP)" % [bname, bxp]
	else:
		sidebar_boss_label.text = "Boss : En sélection..."

	# Âmes visuelles (10 icônes)
	var souls: int = CardDB.total_souls(p, game_manager.G)
	for c in souls_container.get_children():
		c.queue_free()
	for i in range(10):
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(20, 20)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path = TEX_SOUL if i < souls else TEX_SOUL_EMPTY
		if ResourceLoader.exists(path):
			t.texture = load(path)
		souls_container.add_child(t)

	# Blessures visuelles (5 icônes)
	var wounds: int = CardDB.total_wounds(p)
	for c in wounds_container.get_children():
		c.queue_free()
	for i in range(5):
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(20, 20)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path = TEX_WOUND if i < wounds else TEX_WOUND_EMPTY
		if ResourceLoader.exists(path):
			t.texture = load(path)
		wounds_container.add_child(t)

	# Trésors visuels Joueur
	for c in treasures_container.get_children():
		c.queue_free()
	var t_counts = BossEngine.treasure_counts(p)
	var t_icons := [
		[1, TEX_TREASURE_CLERIC],
		[2, TEX_TREASURE_FIGHTER],
		[3, TEX_TREASURE_MAGE],
		[4, TEX_TREASURE_THIEF],
		[5, ""], # Explorer (Crash Landing) : pas d'icone, affiche seulement s'il y en a
	]
	for item in t_icons:
		var count: int = int(t_counts.get(item[0], 0))
		if int(item[0]) == 5 and count == 0:
			continue
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(item[1]):
			icon.texture = load(item[1])
		box.add_child(icon)
		var lbl := Label.new()
		lbl.text = str(count)
		lbl.add_theme_font_size_override("font_size", 13)
		if int(item[0]) == 5:
			lbl.text = "Expl. %d" % count
		box.add_child(lbl)
		treasures_container.add_child(box)

	# Info Adversaire
	if foe.get("boss") != null:
		foe_boss_label.text = "%s (%d XP)" % [str(foe["boss"].get("name", "Adversaire")), int(foe["boss"].get("xp", 0))]
	else:
		foe_boss_label.text = "Adversaire (IA)"
	foe_wounds_label.text = "Blessures : %d/5" % CardDB.total_wounds(foe)
	foe_souls_label.text = "Âmes : %d/10" % CardDB.total_souls(foe, game_manager.G)

	for c in foe_treasures_container.get_children():
		c.queue_free()
	var foe_t_counts = BossEngine.treasure_counts(foe)
	for item in t_icons:
		var count: int = int(foe_t_counts.get(item[0], 0))
		if int(item[0]) == 5 and count == 0:
			continue
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(item[1]):
			icon.texture = load(item[1])
		box.add_child(icon)
		var lbl := Label.new()
		lbl.text = str(count)
		lbl.add_theme_font_size_override("font_size", 12)
		if int(item[0]) == 5:
			lbl.text = "Expl. %d" % count
		box.add_child(lbl)
		foe_treasures_container.add_child(box)

	# Decks & Défausses
	var decks: Dictionary = G.get("decks", {})
	deck_info_label.text = "Salles : %d | Sorts : %d\nHéros : %d" % [
		decks.get("rooms", []).size(),
		decks.get("spells", []).size(),
		decks.get("heroes", []).size() + decks.get("epics", []).size()
	]
	discard_info_label.text = "Défausse Salles : %d\nDéfausse Sorts : %d\nDéfausse Héros : %d" % [
		decks.get("roomDiscard", []).size(),
		decks.get("spellDiscard", []).size(),
		decks.get("heroDiscard", []).size()
	]

	# Bouton Level Up : brille si 5 salles
	var can_lvl: bool = BossEngine.count_visible_rooms(p.get("dungeon", [])) >= 5
	levelup_btn.modulate = Color(1.2, 1.2, 0.4, 1.0) if can_lvl else Color(0.7, 0.7, 0.7, 0.8)

func _play_hero_crossing_animation(lhf: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var pid: int = int(lhf.get("pid", 0))
	var hero: Dictionary = lhf.get("hero", {})
	var killed: bool = bool(lhf.get("killed", false))
	var path_taken: Array = lhf.get("path", [])
	var initial_hp: int = int(lhf.get("initialHp", 4))

	var is_my_dungeon := (pid == view_pid)
	var slots_list: Array = _dungeon_slots if is_my_dungeon else _foe_slots
	var boss_platform: Control = player_boss_platform if is_my_dungeon else foe_boss_platform
	var boss_sprite: Control = player_boss_sprite if is_my_dungeon else foe_boss_sprite
	var entrance_ctrl: Control = player_entrance_container if is_my_dungeon else foe_entrance_container

	_animating_hero = true

	# Créer le pion héroïque animé
	var pawn := _create_hero_pawn(hero, initial_hp)
	hero_crossing_layer.add_child(pawn)
	pawn.global_position = entrance_ctrl.global_position + Vector2(10, 10)

	var tw := create_tween()
	var current_hp := initial_hp

	for step in path_taken:
		var slot_idx: int = int(step.get("slot", 0))
		var dmg: int = int(step.get("damage", 0))
		var is_magic: bool = bool(step.get("isMagic", false))
		if slot_idx < slots_list.size():
			var target_slot: Control = slots_list[slot_idx]
			var target_pos := target_slot.global_position + Vector2(15, 20)

			tw.tween_callback(func(): _play_sfx("res://assets/audio/sfx/char_hero_move.wav"))
			tw.tween_property(pawn, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

			tw.tween_callback(func():
				var sfx_path := "res://assets/audio/sfx/sfx_room_magic.wav" if is_magic else "res://assets/audio/sfx/sfx_room_physical.wav"
				_play_sfx(sfx_path)
				_bump_slot(target_slot)
				_show_floating_dmg(pawn, dmg)
			)
			current_hp -= dmg
			tw.tween_interval(0.25)

	if killed:
		tw.tween_callback(func(): _play_sfx("res://assets/audio/sfx/char_hero_death.wav"))
		tw.tween_property(pawn, "position:y", pawn.position.y - 100.0, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(pawn, "modulate:v", 1.6, 0.15)
		tw.tween_property(pawn, "position:y", pawn.position.y + 220.0, 0.4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(pawn, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func():
			_spawn_flying_soul(pawn.global_position, souls_container.global_position if is_my_dungeon else foe_souls_label.global_position)
			pawn.queue_free()
			_animating_hero = false
			refresh()
		)
	else:
		var boss_pos := boss_platform.global_position + Vector2(25, 25)
		tw.tween_property(pawn, "global_position", boss_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			_play_sfx("res://assets/audio/sfx/char_hero_attack.wav")
			_shake_node(boss_sprite)
			var boss_dict: Dictionary = (game_manager.G.get("players", {}) as Dictionary).get(pid, {}).get("boss", {})
			var is_female := ["BMA006", "BMA007", "BMA008"].has(str(boss_dict.get("id", "")))
			_play_sfx("res://assets/audio/sfx/boss_female_hurt.wav" if is_female else "res://assets/audio/sfx/boss_male_hurt.wav")
			_show_floating_dmg(boss_platform, 1, Color(1, 0.3, 0.3))
		)
		tw.tween_property(pawn, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func():
			pawn.queue_free()
			_animating_hero = false
			refresh()
		)

func _create_hero_pawn(hero: Dictionary, hp: int) -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(90, 115)

	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hid := str(hero.get("id", "")).to_lower()
	var sprite_path := "res://assets/ui/characters/heroes/%s_character.webp" % hid
	if ResourceLoader.exists(sprite_path):
		tex.texture = load(sprite_path)
	ctrl.add_child(tex)

	var hp_badge := Label.new()
	hp_badge.text = "%d PV" % hp
	hp_badge.add_theme_font_size_override("font_size", 14)
	hp_badge.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	hp_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_badge.add_theme_constant_override("outline_size", 3)
	hp_badge.position = Vector2(10, 0)
	ctrl.add_child(hp_badge)
	return ctrl

func _bump_slot(slot: Control) -> void:
	var orig_scale := slot.scale
	var tw := create_tween()
	tw.tween_property(slot, "scale", orig_scale * 1.08, 0.1)
	tw.tween_property(slot, "scale", orig_scale, 0.12)

func _show_floating_dmg(parent: Control, dmg: int, color := Color(1.0, 0.25, 0.25)) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % dmg
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	hero_crossing_layer.add_child(lbl)
	lbl.global_position = parent.global_position + Vector2(20, -10)

	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 45.0, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(func(): lbl.queue_free())

func _shake_node(node: Control) -> void:
	if node == null:
		return
	var orig_x := node.position.x
	var tw := create_tween()
	tw.tween_property(node, "position:x", orig_x - 10.0, 0.05)
	tw.tween_property(node, "position:x", orig_x + 10.0, 0.05)
	tw.tween_property(node, "position:x", orig_x - 5.0, 0.05)
	tw.tween_property(node, "position:x", orig_x + 5.0, 0.05)
	tw.tween_property(node, "position:x", orig_x, 0.05)

func _spawn_flying_soul(from_pos: Vector2, to_pos: Vector2) -> void:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(26, 26)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TEX_SOUL):
		t.texture = load(TEX_SOUL)
	hero_crossing_layer.add_child(t)
	t.global_position = from_pos
	var tw := create_tween()
	tw.tween_property(t, "global_position", to_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "scale", Vector2.ZERO, 0.15)
	tw.tween_callback(func(): t.queue_free())

func _has_move(moves: Array, mtype: String) -> bool:
	for m in moves:
		if m is Dictionary and str((m as Dictionary).get("type", "")) == mtype:
			return true
	return false

func _moves_of(moves: Array, mtype: String) -> Array:
	var out: Array = []
	for m in moves:
		if m is Dictionary and str((m as Dictionary).get("type", "")) == mtype:
			out.append(m)
	return out

func _refresh_choice_bar(G: Dictionary, my_moves: Array) -> void:
	for c in choice_bar.get_children():
		c.queue_free()
	var pc: Dictionary = G.get("pendingChoice", {})
	if pc.is_empty() or int(pc.get("playerId", -1)) != _my_pid():
		choice_bar.visible = false
		discard_pick.clear()
		return
	choice_bar.visible = true
	if str(pc.get("type", "")) == "opening-discard":
		var lbl := Label.new()
		lbl.text = "SELECT 2 CARDS TO DISCARD (%d/2)" % discard_pick.size()
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_font_size_override("font_size", 16)
		choice_bar.add_child(lbl)
		if discard_pick.size() == 2:
			var ok := TextureButton.new()
			ok.custom_minimum_size = Vector2(140, 42)
			ok.ignore_texture_size = true
			ok.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			if ResourceLoader.exists("res://assets/ui/ingame/continue_button.webp"):
				ok.texture_normal = load("res://assets/ui/ingame/continue_button.webp")
			if ResourceLoader.exists("res://assets/ui/ingame/continue_button_pressed.webp"):
				ok.texture_pressed = load("res://assets/ui/ingame/continue_button_pressed.webp")
			var pair := discard_pick.duplicate()
			pair.sort()
			ok.pressed.connect(func():
				_play_sfx("res://assets/audio/sfx/ui_card_flip.wav")
				_do({"type": "openingDiscard", "args": pair})
				discard_pick.clear()
			)
			choice_bar.add_child(ok)
	else:
		var opts: Array = pc.get("options", [])
		var choice_moves := _moves_of(my_moves, "resolveChoice")
		if not choice_moves.is_empty():
			for m in choice_moves:
				var i: int = int((m as Dictionary).get("args", [0])[0])
				var b := Button.new()
				b.text = _option_label(opts, i)
				b.tooltip_text = str(pc.get("message", ""))
				var mv := (m as Dictionary).duplicate()
				b.pressed.connect(func():
					_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
					_do(mv)
				)
				choice_bar.add_child(b)
			return
		for m in _moves_of(my_moves, "resolveLevelUpChoice"):
			var i: int = int((m as Dictionary).get("args", [0])[0])
			var b := Button.new()
			b.text = _option_label(opts, i)
			var mv := (m as Dictionary).duplicate()
			b.pressed.connect(func():
				_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
				_do(mv)
			)
			choice_bar.add_child(b)

func _option_label(opts: Array, i: int) -> String:
	if i < 0:
		return "Passer"
	if i < opts.size() and opts[i] is Dictionary:
		var o: Dictionary = opts[i]
		for k in ["label", "name"]:
			if str(o.get(k, "")) != "":
				return str(o[k])
		if (o.get("card", {}) as Dictionary).get("name", "") != "":
			return str((o["card"] as Dictionary)["name"])
		if o.has("targetPlayerId"):
			return "Joueur %d" % (int(o["targetPlayerId"]) + 1)
	return "Choix %d" % (i + 1)

func _refresh_extra_bar(G: Dictionary, my_moves: Array) -> void:
	for c in extra_bar.get_children():
		c.queue_free()
	var shown := false
	var hand: Array = ((G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("hand", [])
	var pc: Dictionary = G.get("pendingChoice", {})
	if not pc.is_empty():
		extra_bar.visible = false
		return
	for m in my_moves:
		if not (m is Dictionary) or str((m as Dictionary).get("type", "")) in CORE_MOVE_TYPES:
			continue
		var b := Button.new()
		b.text = _move_label(m, G, hand)
		var mv := (m as Dictionary).duplicate()
		b.pressed.connect(func():
			_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
			_do(mv)
		)
		extra_bar.add_child(b)
		shown = true
	extra_bar.visible = shown

func _move_label(m: Dictionary, _G: Dictionary, hand: Array) -> String:
	var t := str(m.get("type", ""))
	var args: Array = m.get("args", [])
	var hand_name := ""
	if not args.is_empty() and args[0] is int and int(args[0]) >= 0 and int(args[0]) < hand.size():
		hand_name = str((hand[int(args[0])] as Dictionary).get("name", ""))
	match t:
		"playSpell":
			# Counterspell : une entree par sort adverse en attente, on nomme la cible.
			if args.size() > 1 and args[1] is Dictionary and (args[1] as Dictionary).has("stackId"):
				return "Sort : %s -> %s" % [hand_name, str((((args[1] as Dictionary).get("card", {})) as Dictionary).get("name", "?"))]
			# The Next Level : la cible (salle, joueur, heros...) est decrite, sinon plusieurs boutons identiques.
			if hand_name != "" and args.size() > 1 and args[1] is Dictionary and TnlSpells.TARGETS.has(str((hand[int(args[0])] as Dictionary).get("id", ""))):
				var desc := TnlSpells.describe_target(_G, args[1])
				return "Sort : %s -> %s" % [hand_name, desc] if desc != "" else "Sort : %s" % hand_name
			return "Sort : %s" % hand_name
		"activateRoom":
			var dgn: Array = ((_G.get("players", {}) as Dictionary).get(_my_pid(), {}) as Dictionary).get("dungeon", [])
			var ri := int(args[0]) if not args.is_empty() else -1
			var rv = BossEngine.active_room(dgn[ri]) if ri >= 0 and ri < dgn.size() else null
			return "Capacité : %s" % (str((rv as Dictionary).get("name", "?")) if rv != null else hand_name)
		"useHandRoom":
			return "Capacité : %s" % hand_name
		"buildMiniboss", "promoteMiniboss", "activateMiniboss":
			return "Miniboss (%s)" % t
		"payDarkHero":
			return "Payer %s (héros noir)" % hand_name
		"docScarecrow":
			var town: Array = _G.get("town", [])
			var ti := int(args[1]) if args.size() > 1 else -1
			return "Épouvantail : %s -> %s" % [hand_name, str((town[ti] as Dictionary).get("name", "?")) if ti >= 0 and ti < town.size() else "?"]
		"timebenderCancel":
			return "Dr. Timebender : défausse %s, annule le sort" % hand_name
		"antimagicCancel":
			return "Antimagic Zone : annule le sort"
		_:
			return hand_name if hand_name != "" else t

func _do(move: Dictionary) -> void:
	if game_manager.apply_move(_my_pid(), move):
		refresh()

func _on_hand_card_clicked(idx: int, card: Dictionary) -> void:
	if _is_opening_discard_for_me():
		if discard_pick.has(idx):
			discard_pick.erase(idx)
		elif discard_pick.size() < 2:
			discard_pick.append(idx)
		_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
		refresh()
		return
	var phase: String = game_manager.G.get("phase", "")
	if (phase == "build" or phase == "setup") and card.get("isRoom", false):
		var dungeon: Array = ((game_manager.G["players"] as Dictionary)[_my_pid()] as Dictionary).get("dungeon", [])
		var target_slot := dungeon.size()
		_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
		game_manager.build_room_at(_my_pid(), idx, target_slot)
	elif phase == "build" and card.get("isSpell", false):
		_play_spell_from_hand(idx)

func _play_spell_from_hand(idx: int) -> void:
	var pid := _my_pid()
	for mv in game_manager.legal_moves(pid):
		var m: Dictionary = mv
		if str(m.get("type", "")) != "playSpell":
			continue
		var args: Array = m.get("args", [])
		if not args.is_empty() and int(args[0]) == idx:
			_play_sfx("res://assets/audio/sfx/sfx_room_magic.wav")
			if game_manager.apply_move(pid, m):
				refresh()
			return

func _is_opening_discard_for_me() -> bool:
	var pc: Dictionary = game_manager.G.get("pendingChoice", {})
	return str(pc.get("type", "")) == "opening-discard" and int(pc.get("playerId", -1)) == _my_pid()

func _on_advance_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/char_hero_move.wav")
	if _is_online():
		_do({"type": "resolveNextHero", "args": []})
	else:
		game_manager.apply_move(_my_pid(), {"type": "adventureNext", "args": []})
		refresh()

func _on_pass_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	if _is_online():
		_do({"type": "pass", "args": []})
	else:
		if game_manager.apply_move(_my_pid(), {"type": "passBuild", "args": []}):
			refresh()

func _on_menu_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_goback.wav")
	if on_exit_callback.is_valid():
		on_exit_callback.call()

func _on_discard_pile_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
	var decks: Dictionary = game_manager.G.get("decks", {})
	var r_disc: Array = decks.get("roomDiscard", [])
	var s_disc: Array = decks.get("spellDiscard", [])
	var h_disc: Array = decks.get("heroDiscard", [])

	var dialog := AcceptDialog.new()
	dialog.title = "DÉFAUSSES (DISCARD PILES)"
	dialog.size = Vector2i(700, 480)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var lbl := Label.new()
	lbl.text = "Salles défaussées (%d) :\n%s\n\nSorts défaussés (%d) :\n%s\n\nHéros morts (%d) :\n%s" % [
		r_disc.size(),
		", ".join(r_disc.map(func(c): return str((c as Dictionary).get("name", "?")))),
		s_disc.size(),
		", ".join(s_disc.map(func(c): return str((c as Dictionary).get("name", "?")))),
		h_disc.size(),
		", ".join(h_disc.map(func(c): return str((c as Dictionary).get("name", "?"))))
	]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 400)
	scroll.add_child(lbl)
	vbox.add_child(scroll)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func _on_level_up_pressed() -> void:
	_play_sfx("res://assets/audio/sfx/sting_levelup.wav")
	# Si un choix de level-up est en attente, le mettre en surbrillance
	var pc: Dictionary = game_manager.G.get("pendingChoice", {})
	if not pc.is_empty():
		choice_bar.modulate = Color(1.5, 1.5, 0.5, 1.0)

func _get_total_dungeon_damage(player_dict: Dictionary) -> int:
	var total := 0
	for stack in player_dict.get("dungeon", []):
		var r = BossEngine.active_room(stack)
		if r != null and not bool((r as Dictionary).get("faceDown", false)):
			total += int((r as Dictionary).get("damage", 0))
	return total
