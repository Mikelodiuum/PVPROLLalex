extends Node

## GameManager (Autoload) — Controla el flujo del juego:
## rondas, puntuaciones, countdown, spawn points, draft de modificadores y transiciones.
## Usa GameConfig (.tres) para toda la configuración — editable sin programar.

signal round_ended(winner_name: String)
signal game_ended(final_winner: String)
signal countdown_tick(number: int)

# === CONFIGURACIÓN (editar game_config_default.tres en el Inspector) ===
var config: GameConfig = null

# === ESTADO DEL JUEGO ===
var current_time := 0.0
var players := []
var round_active := false
var round_number := 1
var scores = {}
var game_initialized := false
var ending_round := false
var pending_restart := false

# === DRAFT DE MODIFICADORES ===
var player_modifiers = {}            # "Player1" → BulletModifier (Arma equipada esta ronda)
var player_weapon_loadouts = {}      # "Player1" → Array[BulletModifier] (Inventario global 3 armas)
var player_abilities = {}            # "Player1" → Array[AbilityResource]
var draft_manager: DraftManager = null
var draft_ui = null                  # DraftUI (CanvasLayer)
var _waiting_for_draft := false
var _last_winner := ""
var _last_loser := ""
var global_weapon_pool := []

func _ready():
	# Cargar configuración
	if config == null:
		var loaded = load("res://scenes/main/manager/game_config_default.tres")
		if loaded is GameConfig:
			config = loaded
		else:
			config = GameConfig.new()
			print("AVISO: No se encontró game_config_default.tres, usando valores por defecto")
	
	if not game_initialized:
		game_initialized = true
		scores = {}
		round_number = 1
		player_modifiers = {}
		player_weapon_loadouts = {}
		player_abilities = {}
		_load_global_weapons()
		_setup_draft()
		pending_restart = true
	else:
		_setup_draft()
		pending_restart = true

func _load_global_weapons():
	global_weapon_pool.clear()
	var path = "res://scenes/combat/modifiers/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var res = load(path + file_name)
				if res is BulletModifier:
					global_weapon_pool.append(res)
			file_name = dir.get_next()

func _setup_draft():
	if draft_manager == null:
		draft_manager = DraftManager.new()
		draft_manager.name = "DraftManager"
		add_child(draft_manager)
		draft_manager.draft_completed.connect(_on_draft_completed)
	
	if draft_ui == null:
		var draft_scene = load("res://scenes/ui/draft_ui.tscn")
		if draft_scene:
			draft_ui = draft_scene.instantiate()
			add_child(draft_ui)
			draft_ui.setup(draft_manager)
		else:
			print("ERROR: No se encontró draft_ui.tscn")

## Llamado por game_over_ui.gd al pulsar Rematch o Menú.
func reset_for_rematch():
	game_initialized  = false
	scores            = {}
	round_number      = 1
	round_active      = false
	_waiting_for_draft = false
	ending_round      = false
	pending_restart   = false
	player_modifiers  = {}
	player_weapon_loadouts = {}
	player_abilities  = {}

func start_round():
	await get_tree().process_frame
	ending_round = false
	pending_restart = false
	_waiting_for_draft = false
	print("=== Ronda ", round_number, " ===")
	
	players = get_tree().get_nodes_in_group("players")
	print("Players detectados: ", players.size())
	
	# === ASIGNAR ARMA POR DEFECTO (SLOT 1) SI NO HAY NINGUNA EQUIPADA ===
	for p_name in player_weapon_loadouts:
		if not player_modifiers.has(p_name) and player_weapon_loadouts[p_name].size() > 0:
			player_modifiers[p_name] = player_weapon_loadouts[p_name][0]
	
	# Posicionar jugadores en los spawn points de la arena
	var arena = get_tree().get_first_node_in_group("arena")
	if arena:
		for i in range(players.size()):
			players[i].global_position = arena.get_player_spawn(i)
		
		# === SPAWN PICKUPS ===
		if config.pickups_enabled:
			var pickup_spawns = arena.get_all_pickup_spawns()
			if pickup_spawns.size() > 0:
				var spawner = PickupSpawner.new()
				spawner.name = "PickupSpawner"
				spawner.respawn_time = config.pickup_respawn_time
				spawner.initial_spawn_delay = config.pickup_initial_delay
				spawner.stagger_delay = config.pickup_stagger
				arena.add_child(spawner)
				spawner.setup(pickup_spawns, arena)
	
	# === APLICAR MODIFICADORES Y CPU ===
	for p in players:
		if player_modifiers.has(p.name):
			p.bullet_modifier = player_modifiers[p.name]
		# Aplicar Habilidades Activas
		if player_abilities.has(p.name):
			p.active_abilities = player_abilities[p.name].duplicate()
		p.refresh_effective_modifier()
		print(p.name, " usa arma: ", p.bullet_modifier.modifier_name if p.bullet_modifier else "Default")

		if p.name == "Player2" and p.has_method("set_cpu_mode"):
			var is_cpu = config.p2_is_cpu if config else true
			var diff   = config.cpu_difficulty if config else 1
			p.set_cpu_mode(is_cpu, diff)
	
	# Congelar jugadores durante el countdown
	for p in players:
		p.frozen = true
	
	# === COUNTDOWN ===
	for i in range(config.countdown_from, 0, -1):
		emit_signal("countdown_tick", i)
		await get_tree().create_timer(config.countdown_step_time).timeout
	emit_signal("countdown_tick", 0)  # 0 = ¡FIGHT!
	
	# Descongelar jugadores e iniciar ronda
	for p in players:
		p.frozen = false
	
	for p in players:
		if not scores.has(p.name):
			scores[p.name] = 0
	
	current_time = config.round_time
	round_active = true

func check_players_alive():
	if players.size() == 0:
		return
	
	var alive_players = []
	for p in players:
		if is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion():
			alive_players.append(p)
	
	if alive_players.size() <= 1:
		end_round("death")

func _process(delta):
	if pending_restart:
		var players_available = get_tree().get_nodes_in_group("players").size()
		if players_available > 0:
			pending_restart = false
			start_round()
		return
	
	if _waiting_for_draft:
		return
	
	if not round_active:
		return
	
	current_time -= delta
	
	if current_time <= 0:
		end_round("timeout")
		return
	
	check_players_alive()

func end_round(reason):
	if not round_active or ending_round:
		return
	
	ending_round = true
	round_active = false
	
	print("Fin de ronda por: ", reason)
	
	var alive_players = []
	for p in players:
		if is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion():
			alive_players.append(p)
	
	_last_winner = ""
	_last_loser = ""
	
	if alive_players.size() == 1:
		var winner = alive_players[0]
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
	
	# Verificar si el juego terminó antes del draft
	for player_name in scores:
		if scores[player_name] >= config.rounds_to_win:
			end_game()
			return
	
	if round_number >= config.max_rounds:
		end_game()
		return
	
	# === INICIAR DRAFT ===
	if config.draft_enabled and _last_winner != "" and _last_loser != "":
		_waiting_for_draft = true
		draft_manager.start_draft(_last_loser, _last_winner)
	elif config.draft_enabled and config.draft_on_tie and _last_winner == "":
		_waiting_for_draft = true
		draft_manager.start_draft("", "")
	else:
		next_round()

func _on_draft_completed():
	print("Draft completado — avanzando a siguiente ronda")
	_waiting_for_draft = false
	next_round()

func next_round():
	print("CAMBIANDO DE RONDA")
	
	round_number += 1
	
	if round_number > config.max_rounds:
		end_game()
		return
	get_tree().reload_current_scene()
	
	# Esperar a que la escena cambie realmente antes de intentar buscar jugadores
	await get_tree().process_frame
	await get_tree().process_frame
	
	pending_restart = true

func end_game():
	print("===! VUELVE A JUGAR JODER ¡===")
	print("Puntuaciones finales: ", scores)
	var final_winner = ""
	for player_name in scores:
		if scores[player_name] >= config.rounds_to_win:
			final_winner = player_name
			break
	if final_winner == "":
		final_winner = "Empate"
		
	# Instanciar UI de Game Over interactiva
	var go_scene = load("res://scenes/ui/game_over_ui.tscn")
	if go_scene:
		var go_ui = go_scene.instantiate()
		add_child(go_ui)
		go_ui.setup(final_winner)
		
	emit_signal("game_ended", final_winner)
	round_active = false
