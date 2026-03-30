extends CanvasLayer

# Referencias a los nodos de texto de la barra superior
@onready var score_p1_label = $Panel/HBoxContainer/VBoxContainer/ScorePlayer1
@onready var score_p2_label = $Panel/HBoxContainer/VBoxContainer/ScorePlayer2
@onready var round_label = $Panel/HBoxContainer/VBoxContainer2/RoundLabel
@onready var timer_label = $Panel/HBoxContainer/VBoxContainer2/TimerLabel

# Referencia al nuevo Label central
@onready var message_label = $CenterContainer/MessageLabel

# Referencia al GameManager
var game_manager

func _ready():
	game_manager = get_node("/root/GameManager")
	if game_manager:
		# Conectar las señales
		game_manager.round_ended.connect(_on_round_ended)
		game_manager.game_ended.connect(_on_game_ended)
		# Actualización inicial
		actualizar_puntuaciones()
		actualizar_ronda()
	else:
		print("ERROR: GameManager no encontrado")

func _process(delta):
	if game_manager == null:
		return
	actualizar_puntuaciones()
	actualizar_ronda()
	actualizar_temporizador()

func actualizar_puntuaciones():
	var scores = game_manager.scores
	score_p1_label.text = "Player 1: " + str(scores.get("Player1", 0))
	score_p2_label.text = "Player 2: " + str(scores.get("Player2", 0))

func actualizar_ronda():
	round_label.text = "Ronda " + str(game_manager.round_number) + "/" + str(game_manager.max_rounds)

func actualizar_temporizador():
	if game_manager.round_active:
		var tiempo_restante = max(0, game_manager.current_time)
		timer_label.text = formatear_tiempo(tiempo_restante)
	else:
		timer_label.text = "00:00"

func formatear_tiempo(segundos: float) -> String:
	var minutos = int(segundos / 60)
	var segs = int(segundos) % 60
	return "%02d:%02d" % [minutos, segs]

# ============================================
# FUNCIONES PARA LOS MENSAJES CENTRALES
# ============================================

func show_message(text: String, duration: float = 2.0):
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	message_label.visible = false

func _on_round_ended(winner_name: String):
	if winner_name != "":
		show_message(winner_name + " gana la ronda!", 2.0)
	else:
		show_message("Empate!", 2.0)

func _on_game_ended(final_winner: String):
	show_message("¡" + final_winner + " es el CAMPEÓN!", 4.0)
