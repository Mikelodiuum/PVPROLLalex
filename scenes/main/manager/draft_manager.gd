extends Node
class_name DraftManager

## Gestiona la lógica del draft de modificadores entre rondas.
## Flujo: perdedor elige 1 de 3 → los 2 restantes van al ganador → ganador elige 1.
## Si hay empate, cada jugador elige de su propio pool de 3.

signal draft_completed()
signal show_draft_ui(options: Array, player_name: String, is_reroll_available: bool)
signal hide_draft_ui()

# Pool de todos los modificadores disponibles para el draft
var modifier_pool: Array[BulletModifier] = []

# Estado del draft actual
var _current_options: Array = []     # 3 BulletModifier opciones actuales
var _loser_name := ""
var _winner_name := ""
var _rerolls_left := 1
var _draft_phase := 0                # 0=idle, 1=loser_choosing, 2=winner_choosing
var _selected_by_loser: BulletModifier = null

func _ready():
	load_modifier_pool()

## Carga todos los .tres de la carpeta de modifiers
func load_modifier_pool():
	modifier_pool.clear()
	var dir_path = "res://scenes/combat/modifiers/"
	var dir = DirAccess.open(dir_path)
	if dir == null:
		print("ERROR: No se pudo abrir la carpeta de modifiers: ", dir_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res = load(dir_path + file_name)
			if res is BulletModifier:
				modifier_pool.append(res)
				print("Draft pool: cargado ", res.modifier_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	print("Draft: ", modifier_pool.size(), " modificadores en el pool")

## Genera N opciones aleatorias sin repetir
func _pick_random_options(count: int) -> Array:
	var pool_copy = modifier_pool.duplicate()
	pool_copy.shuffle()
	var result = []
	for i in min(count, pool_copy.size()):
		result.append(pool_copy[i])
	return result

## Inicia el draft tras una ronda (llamado por GameManager)
func start_draft(loser: String, winner: String):
	_loser_name = loser
	_winner_name = winner
	_rerolls_left = 1
	
	if loser == "" and winner == "":
		# Empate: ambos eligen de un pool propio (simplificado: solo show result)
		print("Draft: Empate — sin draft")
		draft_completed.emit()
		return
	
	# Fase 1: el perdedor elige
	_draft_phase = 1
	_current_options = _pick_random_options(3)
	print("Draft: ", _loser_name, " elige entre: ", _current_options.map(func(m): return m.modifier_name))
	show_draft_ui.emit(_current_options, _loser_name, _rerolls_left > 0)

## El perdedor selecciona un modifier (llamado por DraftUI)
func on_option_selected(index: int):
	if _draft_phase == 1:
		# Perdedor eligió
		_selected_by_loser = _current_options[index]
		print("Draft: ", _loser_name, " eligió ", _selected_by_loser.modifier_name)
		
		# Quitar la opción elegida → los 2 restantes van al ganador
		var remaining = _current_options.duplicate()
		remaining.remove_at(index)
		
		# Fase 2: el ganador elige de los 2 restantes
		_draft_phase = 2
		_current_options = remaining
		print("Draft: ", _winner_name, " elige entre: ", remaining.map(func(m): return m.modifier_name))
		show_draft_ui.emit(_current_options, _winner_name, false)
		
	elif _draft_phase == 2:
		# Ganador eligió
		var selected_by_winner = _current_options[index]
		print("Draft: ", _winner_name, " eligió ", selected_by_winner.modifier_name)
		
		# Aplicar los modificadores persistentes
		_draft_phase = 0
		hide_draft_ui.emit()
		
		# Guardar en GameManager
		var gm = get_node("/root/GameManager")
		if gm:
			gm.player_modifiers[_loser_name] = _selected_by_loser
			gm.player_modifiers[_winner_name] = selected_by_winner
		
		print("Draft completado!")
		draft_completed.emit()

## Reroll: genera 3 nuevas opciones (solo disponible para el perdedor, 1 vez)
func on_reroll():
	if _rerolls_left <= 0 or _draft_phase != 1:
		return
	
	_rerolls_left -= 1
	_current_options = _pick_random_options(3)
	print("Draft: Reroll! Nuevas opciones: ", _current_options.map(func(m): return m.modifier_name))
	show_draft_ui.emit(_current_options, _loser_name, _rerolls_left > 0)
