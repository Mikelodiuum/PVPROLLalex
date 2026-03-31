extends CanvasLayer

## Menú principal del juego. Se carga al iniciar el juego.
## Tiene botón de Jugar y Salir.

@onready var play_button = $MainPanel/VBoxContainer/PlayButton
@onready var quit_button = $MainPanel/VBoxContainer/QuitButton

func _ready():
	var main_panel = $MainPanel
	main_panel.anchor_left = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -220
	main_panel.offset_right = 220
	main_panel.offset_top = -200
	main_panel.offset_bottom = 200
	
	play_button.pressed.connect(_on_play)
	quit_button.pressed.connect(_on_quit)

func _on_play():
	var gm = get_node("/root/GameManager")
	if gm:
		gm.game_initialized = true
		gm.scores = {}
		gm.round_number = 1
		gm.player_modifiers = {}
		gm.player_weapon_loadouts = {}
		gm.player_abilities = {}
		gm.pending_restart = true
		gm._load_global_weapons()
	
	get_tree().change_scene_to_file("res://scenes/ui/weapon_draft_standalone.tscn")

func _on_quit():
	get_tree().quit()
