extends Node

signal round_ended(winner_name: String)
signal game_ended(final_winner: String)
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

func _ready():
	if not game_initialized:
		game_initialized = true
		scores = {}
		round_number = 1
		call_deferred("start_round")
	else:
		call_deferred("start_round")

func start_round():
	await get_tree().process_frame
	ending_round = false
	pending_restart = false
	print("=== Ronda ", round_number, " ===")
	
	players = get_tree().get_nodes_in_group("players")
	print("Players detectados: ", players.size())
	
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
		# Esperamos a que los jugadores aparezcan tras recargar la escena
		var players_available = get_tree().get_nodes_in_group("players").size()
		if players_available > 0:
			pending_restart = false
			start_round()
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
	
	var winner_name = ""
	if alive_players.size() == 1:
		var winner = alive_players[0]
		scores[winner.name] += 1
		winner_name = winner.name
		print("Gana: ", winner.name)
	else:
		print("Empate")
	emit_signal("round_ended", winner_name)
	print("Puntuaciones: ", scores)
	
	await get_tree().create_timer(2.0).timeout
	next_round()

func next_round():
	print("CAMBIANDO DE RONDA")
	
	for player_name in scores:
		if scores[player_name] >= 3:
			print("WINNER WINNER CHICKEN DINNER FOR: ", player_name)
			end_game()
			return
	
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
