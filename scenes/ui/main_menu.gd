extends CanvasLayer

## Menú principal del juego. Se carga al iniciar el juego.
## Tiene botón de Jugar y Salir.

@onready var play_button = $MainPanel/VBoxContainer/PlayButton
@onready var quit_button = $MainPanel/VBoxContainer/QuitButton

func _ready():
	play_button.pressed.connect(_on_play)
	quit_button.pressed.connect(_on_quit)

func _on_play():
	var gm = get_node("/root/GameManager")
	if gm:
		gm.game_initialized = true
		gm.scores = {}
		gm.round_number = 1
		gm.player_modifiers = {}
		gm.pending_restart = true
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_quit():
	get_tree().quit()
