extends Node
class_name DraftManager

## Gestiona el draft de habilidades entre rondas.
## Flujo: GANADOR elige 1 de 3 habilidades → las 2 restantes van al PERDEDOR → perdedor elige 1.
## Las habilidades se acumulan (se añaden a la lista, no se reemplazan).

signal draft_completed()
signal show_draft_ui(options: Array, player_name: String, is_reroll_available: bool)
signal hide_draft_ui()

# Pool de todas las habilidades disponibles para el draft
var ability_pool: Array = []   # Array[AbilityResource]

# Estado del draft actual
var _current_options: Array = []
var _winner_name := ""
var _loser_name  := ""
var _draft_phase := 0      # 0=idle, 1=winner_choosing, 2=loser_choosing
var _selected_by_winner = null   # AbilityResource

func _ready():
	load_ability_pool()

## Carga todas las habilidades con preload explícito.
## Para añadir una nueva habilidad: crear el .tres y añadir la ruta aquí.
func load_ability_pool():
	ability_pool.clear()

	var paths := [
		"res://scenes/combat/abilities/ab_lifesteal.tres",
		"res://scenes/combat/abilities/ab_damage_boost.tres",
		"res://scenes/combat/abilities/ab_speed_boost.tres",
		"res://scenes/combat/abilities/ab_shield.tres",
		"res://scenes/combat/abilities/ab_cooldown.tres",
	]

	for path in paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AbilityResource:
				ability_pool.append(res)
				print("Ability pool: cargado ", res.ability_name)
			else:
				print("AVISO: ", path, " no es un AbilityResource")
		else:
			print("AVISO: No existe ", path)

	print("Draft: ", ability_pool.size(), " habilidades en el pool")

## Genera N opciones aleatorias sin repetir
func _pick_random(count: int) -> Array:
	var pool_copy = ability_pool.duplicate()
	pool_copy.shuffle()
	var result = []
	for i in min(count, pool_copy.size()):
		result.append(pool_copy[i])
	return result

## Inicia el draft (llamado por GameManager al final de una ronda)
func start_draft(winner: String, loser: String):
	_winner_name = winner
	_loser_name  = loser

	if winner == "" and loser == "":
		print("Draft: Empate — sin draft")
		draft_completed.emit()
		return

	var gm = get_node_or_null("/root/GameManager")
	var count = 3
	if gm and gm.config:
		count = gm.config.draft_options_count

	# Fase 1: GANADOR elige primero
	_draft_phase     = 1
	_current_options = _pick_random(count)
	print("Draft: ", _winner_name, " (ganador) elige entre: ",
		  _current_options.map(func(a): return a.ability_name))
	show_draft_ui.emit(_current_options, _winner_name, false)

## Selección de opción (llamado por DraftUI)
func on_option_selected(index: int):
	if _draft_phase == 1:
		# Ganador elige
		_selected_by_winner = _current_options[index]
		print("Draft: ", _winner_name, " eligió ", _selected_by_winner.ability_name)

		var remaining = _current_options.duplicate()
		remaining.remove_at(index)

		# Fase 2: PERDEDOR elige de las restantes
		_draft_phase     = 2
		_current_options = remaining
		print("Draft: ", _loser_name, " (perdedor) elige entre: ",
			  remaining.map(func(a): return a.ability_name))
		show_draft_ui.emit(_current_options, _loser_name, false)

	elif _draft_phase == 2:
		var selected_by_loser = _current_options[index]
		print("Draft: ", _loser_name, " eligió ", selected_by_loser.ability_name)

		_draft_phase = 0
		hide_draft_ui.emit()

		# Guardar en GameManager — ACUMULAR (append, no replace)
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			if not gm.player_abilities.has(_winner_name):
				gm.player_abilities[_winner_name] = []
			if not gm.player_abilities.has(_loser_name):
				gm.player_abilities[_loser_name] = []
			gm.player_abilities[_winner_name].append(_selected_by_winner)
			gm.player_abilities[_loser_name].append(selected_by_loser)
			print("Habilidades ", _winner_name, ": ",
				  gm.player_abilities[_winner_name].map(func(a): return a.ability_name))
			print("Habilidades ", _loser_name, ": ",
				  gm.player_abilities[_loser_name].map(func(a): return a.ability_name))

		print("Draft completado!")
		draft_completed.emit()
