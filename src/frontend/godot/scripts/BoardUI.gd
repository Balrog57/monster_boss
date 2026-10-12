class_name BoardUI
extends Control
## Interface principale du plateau de jeu Boss Monster (Board.tscn).
## Présentation complète style rétro arcade / APK avec double donjon,
## barres de statistiques graphiques, animations de bannières et audio.

const GameManager = preload("res://godot/scripts/GameManager.gd")
const OnlineGameManager = preload("res://godot/scripts/OnlineGameManager.gd")
const BossEngine = preload("res://godot/scripts/BossEngine.gd")

var game_manager: GameManager
var on_exit_callback: Callable
var view_pid: int = 0
var seat_bar: HBoxContainer
var choice_bar: HBoxContainer
var extra_bar: HBoxContainer
var discard_pick: Array = []
var _last_phase: String = ""

const CORE_MOVE_TYPES := ["pickBoss", "buildInitialRoom", "buildRoom", "pass", "passBuild", "adventureNext", "resolveNextHero", "openingDiscard", "resolveLevelUpChoice"]

# Chemins des textures rétro
const TEX_SOUL := "res://assets/ui/ingame/souls_icon.webp"
const TEX_SOUL_EMPTY := "res://assets/ui/ingame/souls_icon_empty.webp"
const TEX_WOUND := "res://assets/ui/ingame/wound_icon.webp"
const TEX_WOUND_EMPTY := "res://assets/ui/ingame/wound_icon_empty.webp"
const TEX_TREASURE_CLERIC := "res://assets/ui/ingame/icon_treasure_cleric.webp"
const TEX_TREASURE_FIGHTER := "res://assets/ui/ingame/icon_treasure_fighter.webp"
const TEX_TREASURE_MAGE := "res://assets/ui/ingame/icon_treasure_mage.webp"
const TEX_TREASURE_THIEF := "res://assets/ui/ingame/icon_treasure_thief.webp"

const PHASE_BANNERS := {
	"build": "res://assets/ui/ingame/build_phase.webp",
	"bait": "res://assets/ui/ingame/bait_phase.webp",
	"adventure": "res://assets/ui/ingame/adventure_phase.webp",
}

func _is_online() -> bool:
	return game_manager is OnlineGameManager

func _my_pid() -> int:
	if _is_online():
		return (game_manager as OnlineGameManager).my_pid
	return view_pid

@onready var background_tex: TextureRect = $Background
@onready var hud_status: Label = $TopBar/StatusLabel
@onready var town_container: HBoxContainer = $TownArea/TownContainer
@onready var dungeon_slots_container: HBoxContainer = $DungeonArea/PlayerRow/PlayerDungeon
@onready var player_boss_container: CenterContainer = $DungeonArea/PlayerRow/PlayerBossContainer
@onready var foe_dungeon_container: HBoxContainer = $DungeonArea/FoeRow/FoeDungeon
@onready var foe_boss_container: CenterContainer = $DungeonArea/FoeRow/FoeBossContainer
@onready var foe_title: Label = $DungeonArea/FoeTitle
@onready var player_title: Label = $DungeonArea/PlayerTitle
@onready var hand_container: HBoxContainer = $BottomArea/HandScroll/HandContainer
@onready var hand_title: Label = $BottomArea/HandTitle
@onready var btn_advance: BaseButton = $BottomArea/ActionButtons/BtnAdvance
@onready var btn_pass: BaseButton = $BottomArea/ActionButtons/BtnPass
@onready var log_label: Label = $BottomArea/LogLabel

@onready var sidebar_boss_label: Label = $Sidebar/SidebarContent/BossInfoLabel
@onready var souls_container: HBoxContainer = $Sidebar/SidebarContent/SoulsContainer
@onready var wounds_container: HBoxContainer = $Sidebar/SidebarContent/WoundsContainer
@onready var treasures_container: HBoxContainer = $Sidebar/SidebarContent/TreasuresContainer
@onready var deck_info_label: Label = $Sidebar/SidebarContent/DecksInfoLabel
@onready var discard_info_label: Label = $Sidebar/SidebarContent/DiscardInfoLabel

@onready var phase_banner: TextureRect = $PhaseBanner
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var _card_scene = preload("res://godot/scenes/Card.tscn")
var _slot_scene = preload("res://godot/scenes/DungeonSlot.tscn")
var _dungeon_slots: Array = []
var _ai_timer: float = 0.0

func setup(p_gm: GameManager, p_exit_cb: Callable) -> void:
	game_manager = p_gm
	on_exit_callback = p_exit_cb
	_build_seat_bar()
	var action_box: HBoxContainer = $BottomArea/ActionButtons
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

	_init_dungeon_slots()
	if music_player and not music_player.playing:
		music_player.play()
	refresh()

func _play_sfx(path: String) -> void:
	if sfx_player and ResourceLoader.exists(path):
		sfx_player.stream = load(path)
		sfx_player.play()

## Barre de sièges hotseat : visible seulement si 2+ humains.
func _build_seat_bar() -> void:
	seat_bar = HBoxContainer.new()
	seat_bar.add_theme_constant_override("separation", 8)
	var bottom: VBoxContainer = $BottomArea
	bottom.add_child(seat_bar)
	bottom.move_child(seat_bar, 0)

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
	# Gestion du tour IA
	var players: Dictionary = game_manager.G.get("players", {})
	for pid in players:
		if (players[pid] as Dictionary).get("isAI", false):
			var pc: Dictionary = game_manager.G.get("pendingChoice", {})
			var has_ai_choice: bool = not pc.is_empty() and int(pc.get("playerId", -1)) == int(pid)
			if not moves.is_empty() and (has_ai_choice or phase == "boss" or phase == "setup" or phase == "build"):
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

	# 1. Top HUD
	if G.get("gameOver") != null:
		var w = G["gameOver"].get("winner", -1)
		hud_status.text = "PARTIE TERMINÉE — Gagnant : Joueur %s (%s)" % [str(int(w) + 1), G["gameOver"].get("reason", "")]
	else:
		var timer_str := ""
		var deadline := int(G.get("turnDeadline", 0))
		if deadline > 0:
			var now_ms: float = Time.get_unix_time_from_system() * 1000.0
			var rem_sec := clampi(int((deadline - now_ms) / 1000.0), 0, 999)
			timer_str = " | ⏱️ %ds" % rem_sec
		hud_status.text = "Tour %d — Phase %s — Joueur %d%s" % [G.get("turn", 0), phase.to_upper(), view_pid + 1, timer_str]

	var p_dmg := _get_total_dungeon_damage(p)
	var p_boss_name := str(p.get("boss", {}).get("name", "Boss"))
	var p_xp := int(p.get("boss", {}).get("xp", 0))
	player_title.text = "MON DONJON (%s — %d XP) — DÉGÂTS : %d ⚔️" % [p_boss_name, p_xp, p_dmg]

	var foe_pids := (G["players"] as Dictionary).keys().filter(func(k): return int(k) != view_pid)
	if not foe_pids.is_empty():
		var foe_dict: Dictionary = (G["players"] as Dictionary)[foe_pids[0]]
		var f_dmg := _get_total_dungeon_damage(foe_dict)
		var f_boss_name := str(foe_dict.get("boss", {}).get("name", "Adversaire"))
		var f_xp := int(foe_dict.get("boss", {}).get("xp", 0))
		foe_title.text = "DONJON ADVERSE (%s — %d XP) — DÉGÂTS : %d ⚔️" % [f_boss_name, f_xp, f_dmg]
	else:
		foe_title.text = "DONJON ADVERSE (IA) :"

	hand_title.text = "MA MAIN :"

	# Feedback de combat héroïque (SFX)
	var lhf = G.get("lastHeroFight")
	if lhf != null and lhf is Dictionary:
		if bool(lhf.get("killed", false)):
			_play_sfx("res://assets/audio/sfx/char_hero_death.wav")
		else:
			_play_sfx("res://assets/audio/sfx/char_hero_attack.wav")
		G.erase("lastHeroFight")

	# 2. Bannière de phase animée
	_refresh_phase_banner(phase)

	# 3. Barre latérale de statistiques rétro (Âmes, Blessures, Trésors, Pioches)
	_refresh_sidebar(G, p)

	# 4. Ville (Héros en attente)
	for c in town_container.get_children():
		c.queue_free()
	for hero in G.get("town", []):
		var hero_card = _card_scene.instantiate()
		town_container.add_child(hero_card)
		hero_card.is_in_hand = false
		hero_card.setup(hero)

	# 5. Mon Donjon (5 slots + Boss joueur à droite)
	var dungeon: Array = p.get("dungeon", [])
	for i in range(_dungeon_slots.size()):
		var slot: DungeonSlot = _dungeon_slots[i]
		if i < dungeon.size():
			slot.set_stack(dungeon[i])
		else:
			slot.set_stack([])

	for c in player_boss_container.get_children():
		c.queue_free()
	if p.get("boss") != null:
		var boss_ui = _card_scene.instantiate()
		player_boss_container.add_child(boss_ui)
		boss_ui.is_in_hand = false
		boss_ui.setup(p["boss"])

	# 6. Donjon Adverse (salles + Boss adverse à droite)
	for c in foe_dungeon_container.get_children():
		c.queue_free()
	for c in foe_boss_container.get_children():
		c.queue_free()

	for pid in (G["players"] as Dictionary):
		if int(pid) == view_pid:
			continue
		var foe: Dictionary = (G["players"] as Dictionary)[pid]
		for stack in foe.get("dungeon", []):
			var r = BossEngine.active_room(stack)
			if r != null:
				var room_ui = _card_scene.instantiate()
				foe_dungeon_container.add_child(room_ui)
				room_ui.is_in_hand = false
				room_ui.setup(r)
		if foe.get("boss") != null:
			var foe_boss_ui = _card_scene.instantiate()
			foe_boss_container.add_child(foe_boss_ui)
			foe_boss_ui.is_in_hand = false
			foe_boss_ui.setup(foe["boss"])

	# 7. Main du joueur
	for c in hand_container.get_children():
		c.queue_free()

	if phase == "boss":
		for b in G.get("bossPicks", []):
			var boss_card = _card_scene.instantiate()
			hand_container.add_child(boss_card)
			boss_card.setup(b)
			var bid = str(b.get("id", ""))
			boss_card.card_clicked.connect(func(_data):
				_play_sfx("res://assets/audio/sfx/ui_button_select.wav")
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
			elif phase == "setup" and (bool(card_dict.get("advanced", false)) or bool(card_dict.get("isAdvanced", false))):
				card_ui.modulate = Color(0.6, 0.6, 0.6, 0.7)

	# 8. Boutons d'action
	var my_moves: Array = game_manager.legal_moves(_my_pid())
	btn_advance.visible = (phase == "adventure") or _has_move(my_moves, "resolveNextHero")
	btn_pass.visible = (phase == "build") or _has_move(my_moves, "pass")
	_refresh_choice_bar(G, my_moves)
	_refresh_extra_bar(G, my_moves)

	# 9. Logs
	var logs: Array = G.get("log", [])
	log_label.text = "\n".join(logs.slice(max(0, logs.size() - 2)))

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

func _refresh_sidebar(G: Dictionary, p: Dictionary) -> void:
	# Info Boss
	if p.get("boss") != null:
		var bname: String = str(p["boss"].get("name", "Boss"))
		var bxp: int = int(p["boss"].get("xp", 0))
		sidebar_boss_label.text = "%s (%d XP)" % [bname, bxp]
	else:
		sidebar_boss_label.text = "Boss : En sélection..."

	# Âmes visuelles (10 icônes)
	var souls: int = CardDB.total_souls(p)
	for c in souls_container.get_children():
		c.queue_free()
	for i in range(10):
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(24, 24)
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
		t.custom_minimum_size = Vector2(24, 24)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path = TEX_WOUND if i < wounds else TEX_WOUND_EMPTY
		if ResourceLoader.exists(path):
			t.texture = load(path)
		wounds_container.add_child(t)

	# Trésors visuels (Clerc, Guerrier, Mage, Voleur)
	for c in treasures_container.get_children():
		c.queue_free()
	var t_counts = BossEngine.treasure_counts(p)
	var t_icons := [
		[1, TEX_TREASURE_CLERIC],
		[2, TEX_TREASURE_FIGHTER],
		[3, TEX_TREASURE_MAGE],
		[4, TEX_TREASURE_THIEF],
	]
	for item in t_icons:
		var count: int = int(t_counts.get(item[0], 0))
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(item[1]):
			icon.texture = load(item[1])
		box.add_child(icon)
		var lbl := Label.new()
		lbl.text = str(count)
		lbl.add_theme_font_size_override("font_size", 14)
		box.add_child(lbl)
		treasures_container.add_child(box)

	# Decks & Défausses
	var decks: Dictionary = G.get("decks", {})
	deck_info_label.text = "Salles : %d | Sorts : %d\nHéros restants : %d" % [
		decks.get("rooms", []).size(),
		decks.get("spells", []).size(),
		decks.get("heroes", []).size() + decks.get("epics", []).size()
	]
	discard_info_label.text = "Défausse Salles : %d\nDéfausse Sorts : %d\nDéfausse Héros : %d" % [
		decks.get("roomDiscard", []).size(),
		decks.get("spellDiscard", []).size(),
		decks.get("heroDiscard", []).size()
	]

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
			return "Sort : %s" % hand_name
		"useHandRoom", "activateRoom":
			return "Capacité : %s" % hand_name
		"buildMiniboss", "promoteMiniboss", "activateMiniboss":
			return "Miniboss (%s)" % t
		"payDarkHero":
			return "Payer (héros noir)"
		"docScarecrow":
			return "Épouvantail"
		"timebenderCancel":
			return "Contre-sort"
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
	if phase == "setup":
		_play_sfx("res://assets/audio/sfx/sfx_room_physical.wav")
		game_manager.build_room_at(_my_pid(), idx, 0)
	elif phase == "build" and card.get("isRoom", false):
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

func _get_total_dungeon_damage(player_dict: Dictionary) -> int:
	var total := 0
	for stack in player_dict.get("dungeon", []):
		var r = BossEngine.active_room(stack)
		if r != null and not bool((r as Dictionary).get("faceDown", false)):
			total += int((r as Dictionary).get("damage", 0))
	return total
