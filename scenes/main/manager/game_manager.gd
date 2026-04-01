extends Node

## GameManager (Autoload) — Controla el flujo del juego:
## rondas, puntuaciones, countdown, spawn points, weapon select, draft de habilidades.
## Usa GameConfig (.tres) para toda la configuración — editable sin programar.

signal round_ended(winner_name: String)
signal game_ended(final_winner: String)
signal countdown_tick(number: int)

# === CONFIGURACIÓN ===
var config: GameConfig = null

# === ESTADO DEL JUEGO ===
var current_time   := 0.0
var players        := []
var round_active   := false
var round_number   := 1
var scores         = {}
var game_initialized := false
var ending_round   := false
var pending_restart := false

# === LOADOUT Y HABILIDADES ===
## player_loadouts persiste entre partidas (el jugador elige sus armas una vez)
var player_loadouts      = {}   # "Player1" → Array[BulletModifier]
## player_weapon_index y player_abilities se reinician al empezar una nueva partida
var player_weapon_index  = {}   # "Player1" → int
var player_abilities     = {}   # "Player1" → Array[AbilityResource]

# Pool de armas para el bot (Player2)
const BOT_WEAPON_POOL := [
	"res://scenes/combat/modifiers/bullet_normal.tres",
	"res://scenes/combat/modifiers/bullet_shotgun.tres",
	"res://scenes/combat/modifiers/bullet_fast.tres",
]

# === DRAFT DE HABILIDADES ===
var draft_manager: DraftManager = null
var draft_ui = null
var _waiting_for_draft := false
var _last_winner := ""
var _last_loser  := ""

# === WEAPON SELECT ===
var weapon_select_ui = null
var _waiting_for_weapon_select := false

func _ready():
	if config == null:
		var loaded = load("res://scenes/main/manager/game_config_default.tres")
		if loaded is GameConfig:
			config = loaded
		else:
			config = GameConfig.new()
			print("AVISO: No se encontró game_config_default.tres, usando valores por defecto")

	if not game_initialized:
		game_initialized = true
		scores           = {}
		round_number     = 1
		_reset_match_state()
		_setup_systems()
		pending_restart = true
	else:
		_setup_systems()
		pending_restart = true

func _reset_match_state():
	## Reinicia solo el estado de partida (no el loadout — ese persiste)
	player_weapon_index = {}
	player_abilities    = {}

func _setup_systems():
	# DraftManager
	if draft_manager == null:
		draft_manager = DraftManager.new()
		draft_manager.name = "DraftManager"
		add_child(draft_manager)
		draft_manager.draft_completed.connect(_on_draft_completed)

	# DraftUI
	if draft_ui == null:
		var draft_scene = load("res://scenes/ui/draft_ui.tscn")
		if draft_scene:
			draft_ui = draft_scene.instantiate()
			add_child(draft_ui)
			draft_ui.setup(draft_manager)
		else:
			print("ERROR: No se encontró draft_ui.tscn")

	# WeaponSelectUI
	if weapon_select_ui == null:
		var ws_scene = load("res://scenes/ui/weapon_select_ui.tscn")
		if ws_scene:
			weapon_select_ui = ws_scene.instantiate()
			add_child(weapon_select_ui)
			weapon_select_ui.weapon_selected.connect(_on_weapon_selected)
		else:
			print("ERROR: No se encontró weapon_select_ui.tscn")

# =========================================================
# INICIO DE RONDA
# =========================================================
func start_round():
	await get_tree().process_frame
	ending_round            = false
	pending_restart         = false
	_waiting_for_draft      = false
	_waiting_for_weapon_select = false
	print("=== Ronda ", round_number, " ===")

	players = get_tree().get_nodes_in_group("players")
	print("Players detectados: ", players.size())

	var arena = get_tree().get_first_node_in_group("arena")
	if arena:
		for i in range(players.size()):
			players[i].global_position = arena.get_player_spawn(i)

		# Configurar límites de cámara de P1 según el tamaño del mapa
		if arena.has_method("get_map_bounds"):
			var bounds = arena.get_map_bounds()
			for p in players:
				if p.has_method("setup_camera_limits"):
					p.setup_camera_limits(bounds)

		if config.pickups_enabled:
			var pickup_spawns = arena.get_all_pickup_spawns()
			if pickup_spawns.size() > 0:
				var spawner = PickupSpawner.new()
				spawner.name                = "PickupSpawner"
				spawner.respawn_time        = config.pickup_respawn_time
				spawner.initial_spawn_delay = config.pickup_initial_delay
				spawner.stagger_delay       = config.pickup_stagger
				arena.add_child(spawner)
				spawner.setup(pickup_spawns, arena)

	# === APLICAR LOADOUT Y HABILIDADES A CADA JUGADOR ===
	for p in players:
		if p.name == "Player1":
			_apply_player1_state(p)
		else:
			_apply_bot_weapon(p)

	# Congelar jugadores durante countdown
	for p in players:
		p.frozen = true

	# Countdown
	for i in range(config.countdown_from, 0, -1):
		emit_signal("countdown_tick", i)
		await get_tree().create_timer(config.countdown_step_time).timeout
	emit_signal("countdown_tick", 0)

	for p in players:
		p.frozen = false

	for p in players:
		if not scores.has(p.name):
			scores[p.name] = 0

	current_time = config.round_time
	round_active = true

func _apply_player1_state(p: Node):
	## Aplica arma activa y habilidades acumuladas a Player1
	if player_loadouts.has("Player1") and player_loadouts["Player1"].size() > 0:
		p.weapon_loadout = player_loadouts["Player1"]
	if not player_weapon_index.has("Player1"):
		player_weapon_index["Player1"] = 0
	p.active_weapon_index = player_weapon_index.get("Player1", 0)
	p.active_abilities    = player_abilities.get("Player1", [])
	p.refresh_effective_modifier()

func _apply_bot_weapon(p: Node):
	## El bot elige aleatoriamente entre 3 armas básicas cada ronda
	var path = BOT_WEAPON_POOL[randi() % BOT_WEAPON_POOL.size()]
	if ResourceLoader.exists(path):
		var weapon = load(path)
		if weapon is BulletModifier:
			p.bullet_modifier = weapon
			p.weapon_loadout  = [weapon]
			p.active_weapon_index = 0
			p.active_abilities    = []
			p.refresh_effective_modifier()
			print(p.name, " (bot) usa arma: ", weapon.modifier_name)

# =========================================================
# CHEQUEO DE JUGADORES VIVOS
# =========================================================
func check_players_alive():
	if players.size() == 0: return
	var alive = []
	for p in players:
		if is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion():
			alive.append(p)
	if alive.size() <= 1:
		end_round("death")

# =========================================================
# PROCESS
# =========================================================
func _process(delta):
	if pending_restart:
		if get_tree().get_nodes_in_group("players").size() > 0:
			pending_restart = false
			start_round()
		return

	if _waiting_for_weapon_select or _waiting_for_draft:
		return

	if not round_active:
		return

	current_time -= delta
	if current_time <= 0:
		end_round("timeout")
		return

	check_players_alive()

# =========================================================
# FIN DE RONDA
# =========================================================
func end_round(reason):
	if not round_active or ending_round: return
	ending_round = true
	round_active = false
	print("Fin de ronda por: ", reason)

	var alive = []
	for p in players:
		if is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion():
			alive.append(p)

	_last_winner = ""
	_last_loser  = ""

	if alive.size() == 1:
		var winner = alive[0]
		scores[winner.name] += 1
		_last_winner = winner.name
		for p_name in scores:
			if p_name != winner.name:
				_last_loser = p_name
				break
		print("Gana: ", winner.name)
	else:
		print("Empate")

	emit_signal("round_ended", _last_winner)
	print("Puntuaciones: ", scores)

	await get_tree().create_timer(config.round_end_delay).timeout

	# ¿Terminó el juego?
	for player_name in scores:
		if scores[player_name] >= config.rounds_to_win:
			end_game()
			return
	if round_number >= config.max_rounds:
		end_game()
		return

	# === WEAPON SELECT (solo para Player1 si tiene loadout) ===
	if config.weapon_select_enabled \
	   and player_loadouts.has("Player1") \
	   and player_loadouts["Player1"].size() > 0 \
	   and weapon_select_ui != null:
		_waiting_for_weapon_select = true
		weapon_select_ui.show_for_player(
			"Player1",
			player_loadouts["Player1"],
			player_weapon_index.get("Player1", 0)
		)
	else:
		_start_ability_draft()

func _on_weapon_selected(weapon_index: int):
	player_weapon_index["Player1"] = weapon_index
	_waiting_for_weapon_select     = false
	print("Player1 cambia a arma ", weapon_index)
	_start_ability_draft()

func _start_ability_draft():
	if not config.draft_enabled:
		next_round()
		return
	if _last_winner != "" and _last_loser != "":
		_waiting_for_draft = true
		draft_manager.start_draft(_last_winner, _last_loser)
	elif config.draft_on_tie and _last_winner == "":
		_waiting_for_draft = true
		draft_manager.start_draft("", "")
	else:
		next_round()

func _on_draft_completed():
	print("Draft completado — avanzando a siguiente ronda")
	_waiting_for_draft = false
	next_round()

# =========================================================
# SIGUIENTE RONDA / FIN DE JUEGO
# =========================================================
func next_round():
	print("CAMBIANDO DE RONDA")
	round_number += 1
	if round_number > config.max_rounds:
		end_game()
		return
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	pending_restart = true

func end_game():
	print("=== FIN DE JUEGO ===")
	print("Puntuaciones finales: ", scores)
	var final_winner = ""
	for player_name in scores:
		if scores[player_name] >= config.rounds_to_win:
			final_winner = player_name
			break
	if final_winner == "":
		final_winner = "Empate"

	var go_scene = load("res://scenes/ui/game_over_ui.tscn")
	if go_scene:
		var go_ui = go_scene.instantiate()
		add_child(go_ui)
		go_ui.setup(final_winner)

	emit_signal("game_ended", final_winner)
	round_active = false
