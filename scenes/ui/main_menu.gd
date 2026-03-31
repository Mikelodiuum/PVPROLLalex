extends CanvasLayer

## Menú principal del juego.
## Botones: JUGAR, EQUIPAMIENTO, SALIR.

@onready var play_button      = $MainPanel/VBoxContainer/PlayButton
@onready var equipment_button = $MainPanel/VBoxContainer/EquipmentButton
@onready var quit_button      = $MainPanel/VBoxContainer/QuitButton

var _equipment_menu = null

func _ready():
	play_button.pressed.connect(_on_play)
	equipment_button.pressed.connect(_on_equipment)
	quit_button.pressed.connect(_on_quit)

	# Pre-cargar el menú de equipamiento
	var eq_scene = load("res://scenes/ui/equipment_menu.tscn")
	if eq_scene:
		_equipment_menu = eq_scene.instantiate()
		add_child(_equipment_menu)
		_equipment_menu.equipment_confirmed.connect(_on_equipment_closed)
		_equipment_menu.equipment_cancelled.connect(_on_equipment_closed)
	else:
		print("ERROR: No se encontró equipment_menu.tscn")

func _on_play():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.game_initialized = true
		gm.scores           = {}
		gm.round_number     = 1
		gm._reset_match_state()
		gm.pending_restart  = true
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_equipment():
	if _equipment_menu:
		_equipment_menu.show_menu()

func _on_equipment_closed():
	pass  # El menú se oculta solo; nada extra que hacer aquí

func _on_quit():
	get_tree().quit()
