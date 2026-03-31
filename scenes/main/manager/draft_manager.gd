extends Node
class_name DraftManager

## Gestiona la lógica del draft de modificadores entre rondas.
## Flujo: perdedor elige 1 de 3 → los 2 restantes van al ganador → ganador elige 1.

signal draft_completed()
signal show_draft_ui(options: Array, player_name: String, is_reroll_available: bool)
signal hide_draft_ui()

# Pool de todos los modificadores disponibles para el draft
# Usamos preload explícito para evitar problemas con DirAccess
var modifier_pool: Array[BulletModifier] = []

# Estado del draft actual
var _current_options: Array = []
var _loser_name := ""
var _winner_name := ""
var _rerolls_left := 1
var _draft_phase := 0      # 0=idle, 1=loser_choosing, 2=winner_choosing
var _selected_by_loser: BulletModifier = null

func _ready():
	load_modifier_pool()

## Carga todos los modificadores del pool con preload explícito
## Para añadir un nuevo modifier: crear el .tres y añadirlo aquí
func load_modifier_pool():
	modifier_pool.clear()
	
	var paths := [
		"res://scenes/combat/modifiers/bullet_normal.tres",
		"res://scenes/combat/modifiers/bullet_fast.tres",
		"res://scenes/combat/modifiers/bullet_heavy.tres",
		"res://scenes/combat/modifiers/bullet_shotgun.tres",
		"res://scenes/combat/modifiers/bullet_sniper.tres",
		"res://scenes/combat/modifiers/bullet_toxic.tres",
		"res://scenes/combat/modifiers/bullet_burst.tres",
		"res://scenes/combat/modifiers/bullet_explosive.tres",
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is BulletModifier:
				modifier_pool.append(res)
				print("Draft pool: cargado ", res.modifier_name)
			else:
				print("AVISO: ", path, " no es un BulletModifier")
		else:
			print("AVISO: No existe ", path)
	
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
	
	# Leer config de rerolls
	var gm = get_node("/root/GameManager")
	if gm and gm.config:
		_rerolls_left = gm.config.draft_rerolls
	else:
		_rerolls_left = 1
	
	var options_count = 3
	if gm and gm.config:
		options_count = gm.config.draft_options_count
	
	if loser == "" and winner == "":
		print("Draft: Empate — sin draft")
		draft_completed.emit()
		return
	
	# Fase 1: el perdedor elige
	_draft_phase = 1
	_current_options = _pick_random_options(options_count)
	print("Draft: ", _loser_name, " elige entre: ", _current_options.map(func(m): return m.modifier_name))
	show_draft_ui.emit(_current_options, _loser_name, _rerolls_left > 0)

## El jugador selecciona un modifier (llamado por DraftUI)
func on_option_selected(index: int):
	if _draft_phase == 1:
		_selected_by_loser = _current_options[index]
		print("Draft: ", _loser_name, " eligió ", _selected_by_loser.modifier_name)
		
		# Quitar la opción elegida → los 2 restantes van al ganador
		var remaining = _current_options.duplicate()
		remaining.remove_at(index)
		
		# Fase 2: el ganador elige
		_draft_phase = 2
		_current_options = remaining
		print("Draft: ", _winner_name, " elige entre: ", remaining.map(func(m): return m.modifier_name))
		show_draft_ui.emit(_current_options, _winner_name, false)
		
	elif _draft_phase == 2:
		var selected_by_winner = _current_options[index]
		print("Draft: ", _winner_name, " eligió ", selected_by_winner.modifier_name)
		
		_draft_phase = 0
		hide_draft_ui.emit()
		
		# Guardar en GameManager
		var gm = get_node("/root/GameManager")
		if gm:
			gm.player_modifiers[_loser_name] = _selected_by_loser
			gm.player_modifiers[_winner_name] = selected_by_winner
		
		print("Draft completado!")
		draft_completed.emit()

## Reroll: genera nuevas opciones (solo disponible para el perdedor)
func on_reroll():
	if _rerolls_left <= 0 or _draft_phase != 1:
		return
	
	_rerolls_left -= 1
	
	var options_count = 3
	var gm = get_node("/root/GameManager")
	if gm and gm.config:
		options_count = gm.config.draft_options_count
	
	_current_options = _pick_random_options(options_count)
	print("Draft: Reroll! Nuevas opciones: ", _current_options.map(func(m): return m.modifier_name))
	show_draft_ui.emit(_current_options, _loser_name, _rerolls_left > 0)
