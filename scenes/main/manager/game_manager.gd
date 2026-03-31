extends Node

## GameManager (Autoload) — Controla el flujo del juego:
## rondas, puntuaciones, countdown, spawn points, draft de modificadores y transiciones.

signal round_ended(winner_name: String)
signal game_ended(final_winner: String)
signal countdown_tick(number: int)

@export var round_time := 120.0
var current_time := 0.0
var players := []
var round_active := false
var round_number := 1
var max_rounds := 5
var scores = {}
var game_initialized := false
var ending_round := false
var pending_restart := false

# === DRAFT DE MODIFICADORES ===
var player_modifiers = {}            # "Player1" → BulletModifier (persiste entre rondas)
var draft_manager: DraftManager = null
var draft_ui = null                  # DraftUI (CanvasLayer)
var _waiting_for_draft := false
var _last_winner := ""
var _last_loser := ""

func _ready():
	if not game_initialized:
		game_initialized = true
		scores = {}
		round_number = 1
		_setup_draft()
		call_deferred("start_round")
	else:
		_setup_draft()
		call_deferred("start_round")

func _setup_draft():
	# Crear DraftManager si no existe
	if draft_manager == null:
		draft_manager = DraftManager.new()
		draft_manager.name = "DraftManager"
		add_child(draft_manager)
		draft_manager.draft_completed.connect(_on_draft_completed)
	
	# Crear DraftUI si no existe
	if draft_ui == null:
		var DraftUIScript = load("res://scenes/ui/draft_ui.gd")
		draft_ui = CanvasLayer.new()
		draft_ui.set_script(DraftUIScript)
		draft_ui.name = "DraftUI"
		add_child(draft_ui)
		draft_ui.setup(draft_manager)

func start_round():
	await get_tree().process_frame
	ending_round = false
	pending_restart = false
	_waiting_for_draft = false
	print("=== Ronda ", round_number, " ===")
	
	players = get_tree().get_nodes_in_group("players")
	print("Players detectados: ", players.size())
	
	# Posicionar jugadores en los spawn points de la arena
	var arena = get_tree().get_first_node_in_group("arena")
	if arena:
		for i in range(players.size()):
			players[i].global_position = arena.get_player_spawn(i)
		
		# === SPAWN PICKUPS ===
		var pickup_spawns = arena.get_all_pickup_spawns()
		if pickup_spawns.size() > 0:
			var spawner = PickupSpawner.new()
			spawner.name = "PickupSpawner"
			arena.add_child(spawner)
			spawner.setup(pickup_spawns, arena)
	
	# === APLICAR MODIFICADORES PERSISTENTES DEL DRAFT ===
	for p in players:
		if player_modifiers.has(p.name):
			p.bullet_modifier = player_modifiers[p.name]
			print(p.name, " usa modifier del draft: ", p.bullet_modifier.modifier_name)
	
	# Congelar jugadores durante el countdown
	for p in players:
		p.frozen = true
	
	# === COUNTDOWN 3-2-1-GO! ===
	for i in range(3, 0, -1):
		emit_signal("countdown_tick", i)
		await get_tree().create_timer(1.0).timeout
	emit_signal("countdown_tick", 0)  # 0 = ¡FIGHT!
	
	# Descongelar jugadores e iniciar ronda
	for p in players:
		p.frozen = false
	
	for p in players:
		if not scores.has(p.name):
			scores[p.name] = 0
	
	current_time = round_time
	round_active = true

func check_players_alive():
	if players.size() == 0:
		return
	
	var alive_players = []
	for p in players:
		if is_instance_valid(p) and p.is_inside_tree():
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
		if is_instance_valid(p) and p.is_inside_tree():
			alive_players.append(p)
	
	_last_winner = ""
	_last_loser = ""
	
	if alive_players.size() == 1:
		var winner = alive_players[0]
		scores[winner.name] += 1
		_last_winner = winner.name
		# Determinar el perdedor
		for p_name in scores:
			if p_name != winner.name:
				_last_loser = p_name
				break
		print("Gana: ", winner.name)
	else:
		print("Empate")
	
	emit_signal("round_ended", _last_winner)
	print("Puntuaciones: ", scores)
	
	await get_tree().create_timer(2.0).timeout
	
	# Verificar si el juego terminó antes del draft
	for player_name in scores:
		if scores[player_name] >= 3:
			end_game()
			return
	
	if round_number >= max_rounds:
		end_game()
		return
	
	# === INICIAR DRAFT ===
	if _last_winner != "" and _last_loser != "":
		_waiting_for_draft = true
		draft_manager.start_draft(_last_loser, _last_winner)
	else:
		# Empate: sin draft, siguiente ronda directamente
		next_round()

func _on_draft_completed():
	print("Draft completado — avanzando a siguiente ronda")
	_waiting_for_draft = false
	next_round()

func next_round():
	print("CAMBIANDO DE RONDA")
	
	round_number += 1
	
	if round_number > max_rounds:
		end_game()
		return
	
	pending_restart = true
	get_tree().reload_current_scene()

func end_game():
	print("===!VUELVE A JUGAR JODER¡===")
	print("Puntuaciones finales: ", scores)
	var final_winner = ""
	for player_name in scores:
		if scores[player_name] >= 3:
			final_winner = player_name
			break
	if final_winner == "":
		final_winner = "Empate"
	emit_signal("game_ended", final_winner)
	round_active = false
