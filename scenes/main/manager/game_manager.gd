extends Node

## GameManager (Autoload) — Controla el flujo del juego:
## rondas, puntuaciones, countdown, spawn points, weapon select, draft de habilidades.
## Usa GameConfig (.tres) para toda la configuración — editable sin programar.
##
## ARQUITECTURA DE MENÚS POST-RONDA:
##   Al terminar una ronda se muestran SIMULTÁNEAMENTE:
##     - WeaponSelectUI (mini-panel top-right): Player1 elige su arma activa
##     - DraftUI (pantalla completa): ganador/perdedor eligen habilidades
##   next_round() solo se llama cuando AMBAS decisiones están confirmadas.
## ARQUITECTURA DE BOT (P2):
##   Si config.bot_p2_enabled, el GameManager intercepta los turnos de P2
##   en el draft y llama automáticamente on_option_selected con un índice
##   aleatorio, con un pequeño delay para que se vea natural.

signal round_ended(winner_name: String)
signal game_ended(final_winner: String)
signal countdown_tick(number: int)

# === CONFIGURACIÓN ===
var config: GameConfig = null

# === ESTADO DEL JUEGO ===
var current_time    := 0.0
var players         := []
var round_active    := false
var round_number    := 1
var scores          = {}
var game_initialized := false
var ending_round    := false
var pending_restart := false

# === LOADOUT Y HABILIDADES ===
## player_loadouts persiste entre partidas (el jugador elige sus armas una vez)
var player_loadouts     = {}   # "Player1" → Array[BulletModifier]
## player_weapon_index y player_abilities se reinician al empezar una nueva partida
var player_weapon_index = {}   # "Player1" → int
var player_abilities    = {}   # "Player1" → Array[AbilityResource]

# === POOL DE ARMAS DEL BOT ===
## Las armas están ordenadas por dificultad ascendente:
##   Fácil   (bot_p2_difficulty=0): índices 0..1
##   Normal  (bot_p2_difficulty=1): índices 0..2
##   Difícil (bot_p2_difficulty=2): pool completo
## Para añadir armas al bot: agregar la ruta aquí (las más fáciles al principio).
const BOT_WEAPON_POOL := [
	"res://scenes/combat/modifiers/bullet_normal.tres",    # 0 - Fácil
	"res://scenes/combat/modifiers/bullet_shotgun.tres",   # 1 - Fácil
	"res://scenes/combat/modifiers/bullet_fast.tres",      # 2 - Normal
	"res://scenes/combat/modifiers/bullet_heavy.tres",     # 3 - Difícil
	"res://scenes/combat/modifiers/bullet_sniper.tres",    # 4 - Difícil
]
## Cuántos elementos del pool usa cada nivel de dificultad
const BOT_DIFFICULTY_POOL_SIZE := [2, 3, 5]   # Fácil, Normal, Difícil

# === DRAFT DE HABILIDADES ===
var draft_manager: DraftManager = null
var draft_ui = null
var _waiting_for_draft := false
var _last_winner := ""
var _last_loser  := ""

# === WEAPON SELECT ===
var weapon_select_ui = null
var _waiting_for_weapon_select := false

# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready() -> void:
	if config == null:
		var loaded = load("res://scenes/main/manager/game_config_default.tres")
		if loaded is GameConfig:
			config = loaded
		else:
			config = GameConfig.new()
			push_warning("GameManager: No se encontró game_config_default.tres, usando valores por defecto")

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

func _reset_match_state() -> void:
	## Reinicia solo el estado de partida (el loadout persiste entre partidas)
	player_weapon_index = {}
	player_abilities    = {}

func _setup_systems() -> void:
	# DraftManager
	if draft_manager == null:
		draft_manager = DraftManager.new()
		draft_manager.name = "DraftManager"
		add_child(draft_manager)
		draft_manager.draft_completed.connect(_on_draft_completed)
		# Interceptamos show_draft_ui para que el bot auto-seleccione cuando le toca a P2
		draft_manager.show_draft_ui.connect(_on_draft_show_for_bot)

	# DraftUI
	if draft_ui == null:
		var draft_scene = load("res://scenes/ui/draft_ui.tscn")
		if draft_scene:
			draft_ui = draft_scene.instantiate()
			add_child(draft_ui)
			draft_ui.setup(draft_manager)
		else:
			push_error("GameManager: No se encontró draft_ui.tscn")

	# WeaponSelectUI
	if weapon_select_ui == null:
		var ws_scene = load("res://scenes/ui/weapon_select_ui.tscn")
		if ws_scene:
			weapon_select_ui = ws_scene.instantiate()
			add_child(weapon_select_ui)
			weapon_select_ui.weapon_selected.connect(_on_weapon_selected)
		else:
			push_error("GameManager: No se encontró weapon_select_ui.tscn")

# =========================================================
# INICIO DE RONDA
# =========================================================

func start_round() -> void:
	await get_tree().process_frame
	ending_round               = false
	pending_restart            = false
	_waiting_for_draft         = false
	_waiting_for_weapon_select = false
	print("=== Ronda ", round_number, " ===")

	players = get_tree().get_nodes_in_group("players")
	print("Players detectados: ", players.size())

	var arena = get_tree().get_first_node_in_group("arena")
	if arena:
		for i in range(players.size()):
			players[i].global_position = arena.get_player_spawn(i)

		# Límites de cámara
		if arena.has_method("get_map_bounds"):
			var bounds = arena.get_map_bounds()
			for p in players:
				if p.has_method("setup_camera_limits"):
					p.setup_camera_limits(bounds)

		# Spawner de pickups
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

	# Aplicar loadout y habilidades a cada jugador
	for p in players:
		if p.name == "Player1":
			_apply_player1_state(p)
		else:
			_apply_bot_state(p)

	# Congelar jugadores durante countdown
	for p in players:
		p.frozen = true

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

# =========================================================
# APLICAR ESTADO A JUGADORES
# =========================================================

func _apply_player1_state(p: Node) -> void:
	## Aplica arma activa y habilidades acumuladas a Player1
	if player_loadouts.has("Player1") and player_loadouts["Player1"].size() > 0:
		p.weapon_loadout = player_loadouts["Player1"]
	if not player_weapon_index.has("Player1"):
		player_weapon_index["Player1"] = 0
	p.active_weapon_index = player_weapon_index.get("Player1", 0)
	p.active_abilities    = player_abilities.get("Player1", [])
	p.refresh_effective_modifier()

func _apply_bot_state(p: Node) -> void:
	## Aplica arma aleatoria al bot y, si el bot está activo, inyecta BotController.
	if not (config and config.bot_p2_enabled):
		# Bot desactivado: P2 usa controles físicos normales
		if config and config.default_modifier:
			p.bullet_modifier     = config.default_modifier
			p.weapon_loadout      = [config.default_modifier]
			p.active_weapon_index = 0
			p.active_abilities    = player_abilities.get(p.name, [])
			p.refresh_effective_modifier()
		return

	# Determinar arma según dificultad
	var difficulty: int  = clamp(int(config.bot_p2_difficulty), 0, BOT_DIFFICULTY_POOL_SIZE.size() - 1)
	var pool_count: int  = clamp(BOT_DIFFICULTY_POOL_SIZE[difficulty], 1, BOT_WEAPON_POOL.size())
	var path: String     = BOT_WEAPON_POOL[randi() % pool_count]

	if ResourceLoader.exists(path):
		var weapon = load(path)
		if weapon is BulletModifier:
			p.bullet_modifier     = weapon
			p.weapon_loadout      = [weapon]
			p.active_weapon_index = 0
			p.active_abilities    = player_abilities.get(p.name, [])
			p.refresh_effective_modifier()
			print(p.name, " (bot dif=%d) usa: " % difficulty, weapon.modifier_name)
	else:
		push_warning("GameManager: Arma del bot no encontrada: " + path)

	# Inyectar cerebro IA — solo si no hay ya un BotController en este nodo
	if not p.has_node("BotController"):
		p.is_bot       = true
		var bot        = BotController.new()
		bot.name       = "BotController"
		bot.player     = p
		bot.config     = config
		p.add_child(bot)
		print("BotController inyectado en ", p.name)

# =========================================================
# CHEQUEO DE JUGADORES VIVOS
# =========================================================

func check_players_alive() -> void:
	if players.size() == 0: return
	var alive := []
	for p in players:
		if is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion():
			alive.append(p)
	if alive.size() <= 1:
		end_round("death")

# =========================================================
# PROCESS
# =========================================================

func _process(delta) -> void:
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

func end_round(reason: String) -> void:
	if not round_active or ending_round: return
	ending_round = true
	round_active = false
	print("Fin de ronda por: ", reason)

	var alive := []
	for p in players:
		if is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion():
			alive.append(p)

	_last_winner = ""
	_last_loser  = ""

	if alive.size() == 1:
		var winner = alive[0]
		scores[winner.name] = scores.get(winner.name, 0) + 1
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

	# Mostrar menús post-ronda simultáneamente
	_show_post_round_menus()

# =========================================================
# MENÚS POST-RONDA (SIMULTÁNEOS)
# =========================================================

func _show_post_round_menus() -> void:
	## Muestra el selector de arma (top-right) y el draft de habilidades
	## al mismo tiempo. next_round() solo se llama cuando ambos confirman.
	_waiting_for_weapon_select = false
	_waiting_for_draft         = false

	# --- Weapon select (solo si P1 tiene más de 1 arma) ---
	if config.weapon_select_enabled \
	   and player_loadouts.has("Player1") \
	   and player_loadouts["Player1"].size() > 1 \
	   and weapon_select_ui != null:
		_waiting_for_weapon_select = true
		weapon_select_ui.show_for_player(
			"Player1",
			player_loadouts["Player1"],
			player_weapon_index.get("Player1", 0)
		)

	# --- Draft de habilidades ---
	if config.draft_enabled:
		if _last_winner != "" and _last_loser != "":
			_waiting_for_draft = true
			draft_manager.start_draft(_last_winner, _last_loser)
		elif config.draft_on_tie and _last_winner == "":
			_waiting_for_draft = true
			draft_manager.start_draft("", "")

	# Si ninguno de los dos está activo, avanzar directamente
	_try_advance_round()

func _try_advance_round() -> void:
	## Avanza a la siguiente ronda solo cuando ambos menús han confirmado.
	if not _waiting_for_weapon_select and not _waiting_for_draft:
		next_round()

# =========================================================
# CALLBACKS DE MENÚS
# =========================================================

func _on_weapon_selected(weapon_index: int) -> void:
	player_weapon_index["Player1"] = weapon_index
	_waiting_for_weapon_select     = false
	print("Player1 cambia a arma índice ", weapon_index)
	_try_advance_round()

func _on_draft_completed() -> void:
	print("Draft completado")
	_waiting_for_draft = false
	_try_advance_round()

# =========================================================
# BOT: AUTO-SELECCIÓN EN DRAFT
# =========================================================

func _on_draft_show_for_bot(options: Array, player_name: String, _reroll: bool) -> void:
	## Si el jugador al que le toca es P2 y el bot está activo,
	## elegimos una opción aleatoria con un pequeño delay para que se vea natural.
	if not (config and config.bot_p2_enabled):
		return
	if player_name != "Player2":
		return
	if options.is_empty():
		return

	# Delay suave: hace que parezca que el bot "piensa"
	var think_time := 0.4 + randf() * 0.4
	await get_tree().create_timer(think_time).timeout

	# Verificar que el draft sigue activo (podría haberse cancelado)
	if is_instance_valid(draft_manager) and draft_manager._draft_phase > 0:
		var chosen := randi() % options.size()
		print("Bot (P2) auto-elige habilidad índice ", chosen, " de ", options.size())
		draft_manager.on_option_selected(chosen)

# =========================================================
# SIGUIENTE RONDA / FIN DE JUEGO
# =========================================================

func next_round() -> void:
	print("CAMBIANDO DE RONDA → ", round_number + 1)
	round_number += 1
	if round_number > config.max_rounds:
		end_game()
		return
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	pending_restart = true

func end_game() -> void:
	print("=== FIN DE JUEGO ===")
	print("Puntuaciones finales: ", scores)

	var final_winner := ""
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
