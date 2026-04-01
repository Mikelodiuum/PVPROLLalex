extends CanvasLayer

## Menú de pausa. Se activa/desactiva con ESC.
## Pausa el juego y muestra opciones: Continuar, Reiniciar, Salir.

@onready var continue_btn = $PausePanel/VBoxContainer/ContinueButton
@onready var restart_btn  = $PausePanel/VBoxContainer/RestartButton
@onready var quit_btn     = $PausePanel/VBoxContainer/QuitButton

var _is_paused := false

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)
	restart_btn.pressed.connect(_on_restart)
	quit_btn.pressed.connect(_on_quit)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	_is_paused = !_is_paused
	visible    = _is_paused
	get_tree().paused = _is_paused

func _on_continue() -> void:
	toggle_pause()

func _on_restart() -> void:
	get_tree().paused = false
	_is_paused        = false
	visible           = false
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

func _on_quit() -> void:
	get_tree().quit()
