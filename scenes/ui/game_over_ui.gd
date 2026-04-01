extends CanvasLayer

## Pantalla de Game Over. Se muestra cuando un jugador gana la partida completa.

@onready var winner_label = $PanelContainer/VBoxContainer/WinnerLabel
@onready var rematch_btn  = $PanelContainer/VBoxContainer/RematchButton
@onready var menu_btn     = $PanelContainer/VBoxContainer/MenuButton

func _ready() -> void:
	rematch_btn.pressed.connect(_on_rematch)
	menu_btn.pressed.connect(_on_menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(winner_name: String) -> void:
	winner_label.text = "¡" + winner_name + " ES EL CAMPEÓN!"
	visible = true
	get_tree().paused = true

## Reinicia la partida completa desde cero (loadouts se mantienen).
func _on_rematch() -> void:
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.game_initialized           = false
		gm.scores                     = {}
		gm.round_number               = 1
		gm.player_weapon_index        = {}
		gm.player_abilities           = {}
		gm.round_active               = false
		gm._waiting_for_draft         = false
		gm._waiting_for_weapon_select = false
	get_tree().reload_current_scene()
	queue_free()

## Vuelve al menú principal (resetea todo, incluyendo loadouts).
func _on_menu() -> void:
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.game_initialized  = false
		gm.scores            = {}
		gm.round_number      = 1
		gm.player_weapon_index = {}
		gm.player_abilities    = {}
		gm.player_loadouts     = {}
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	queue_free()
