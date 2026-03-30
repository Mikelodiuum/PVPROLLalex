extends CanvasLayer

# Referencias a los nodos de texto
@onready var score_p1_label = $Panel/HBoxContainer/VBoxContainer/ScorePlayer1
@onready var score_p2_label = $Panel/HBoxContainer/VBoxContainer/ScorePlayer2
@onready var round_label = $Panel/HBoxContainer/VBoxContainer2/RoundLabel
@onready var timer_label = $Panel/HBoxContainer/VBoxContainer2/TimerLabel

# Referencia al GameManager (autoload)
var game_manager

func _ready():
	# Buscar el GameManager en el árbol (como es autoload, está en /root)
	game_manager = get_node("/root/GameManager")
	if game_manager == null:
		print("ERROR: GameManager no encontrado")
	else:
		# Actualización inicial
		actualizar_puntuaciones()
		actualizar_ronda()

func _process(delta):
	if game_manager == null:
		return
	# Actualizar cada frame (es ligero, no te preocupes)
	actualizar_puntuaciones()
	actualizar_ronda()
	actualizar_temporizador()

func actualizar_puntuaciones():
	var scores = game_manager.scores
	score_p1_label.text = "Player1: " + str(scores.get("Player1", 0))
	score_p2_label.text = "Player2: " + str(scores.get("Player2", 0))

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
