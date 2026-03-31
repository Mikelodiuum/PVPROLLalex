extends CanvasLayer

## Pantalla de Game Over. Se muestra cuando un jugador gana la partida completa.

@onready var winner_label = $PanelContainer/VBoxContainer/WinnerLabel
@onready var rematch_btn = $PanelContainer/VBoxContainer/RematchButton
@onready var menu_btn = $PanelContainer/VBoxContainer/MenuButton

func _ready():
	rematch_btn.pressed.connect(_on_rematch)
	menu_btn.pressed.connect(_on_menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(winner_name: String):
	winner_label.text = "¡" + winner_name + " ES EL CAMPEÓN!"
	visible = true
	get_tree().paused = true

func _on_rematch():
	get_tree().paused = false
	var gm = get_node("/root/GameManager")
	if gm:
		gm.game_initialized = false
		gm.scores = {}
		gm.round_number = 1
		gm.player_modifiers = {}
		gm.round_active = false
		gm._waiting_for_draft = false
	get_tree().reload_current_scene()
	queue_free()

func _on_menu():
	get_tree().paused = false
	var gm = get_node("/root/GameManager")
	if gm:
		gm.game_initialized = false
		gm.scores = {}
		gm.round_number = 1
		gm.player_modifiers = {}
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	queue_free()
