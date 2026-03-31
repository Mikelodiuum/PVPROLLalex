extends Node
class_name DraftManager

## Gestiona el draft de habilidades entre rondas.
## Flujo: PERDEDOR elige 1 de N habilidades (consolación por elegir primero) →
##        las N-1 restantes pasan al GANADOR → ganador elige 1 (con posible reroll).
## Las habilidades se acumulan (append, no replace).

signal draft_completed()
signal show_draft_ui(options: Array, player_name: String, is_reroll_available: bool)
signal hide_draft_ui()

# Pool de todas las habilidades disponibles para el draft
var ability_pool: Array = []   # Array[AbilityResource]

# Estado del draft actual
var _current_options: Array = []
var _loser_name  := ""
var _winner_name := ""
var _draft_phase := 0          # 0=idle, 1=loser_choosing, 2=winner_choosing
var _selected_by_loser = null  # AbilityResource
var _rerolls_remaining: int = 0

func _ready():
	load_ability_pool()

func load_ability_pool():
	ability_pool.clear()

	var paths := [
		# === HABILIDADES ORIGINALES ===
		"res://scenes/combat/abilities/ab_lifesteal.tres",
		"res://scenes/combat/abilities/ab_damage_boost.tres",
		"res://scenes/combat/abilities/ab_speed_boost.tres",
		"res://scenes/combat/abilities/ab_shield.tres",
		"res://scenes/combat/abilities/ab_cooldown.tres",
		# === HABILIDADES DE PROYECTIL ===
		"res://scenes/combat/abilities/ab_burst.tres",
		"res://scenes/combat/abilities/ab_heavy_bullet.tres",
		"res://scenes/combat/abilities/ab_fast_bullet.tres",
		"res://scenes/combat/abilities/ab_power_mult.tres",
		"res://scenes/combat/abilities/ab_poison.tres",
		"res://scenes/combat/abilities/ab_pierce.tres",
		"res://scenes/combat/abilities/ab_lucky_shot.tres",
		"res://scenes/combat/abilities/ab_execute.tres",
		# === HABILIDADES DE VIDA ===
		"res://scenes/combat/abilities/ab_vitality.tres",
		"res://scenes/combat/abilities/ab_regen.tres",
		"res://scenes/combat/abilities/ab_barrier_big.tres",
		"res://scenes/combat/abilities/ab_lifesteal_big.tres",
		# === HABILIDADES DE MOVIMIENTO ===
		"res://scenes/combat/abilities/ab_max_speed.tres",
		"res://scenes/combat/abilities/ab_dash_boost.tres",
		"res://scenes/combat/abilities/ab_intangibility.tres",
		# === HABILIDADES ESPECIALES ===
		"res://scenes/combat/abilities/ab_ghost.tres",
		"res://scenes/combat/abilities/ab_berserker.tres",
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

func _pick_random(count: int) -> Array:
	var pool_copy = ability_pool.duplicate()
	pool_copy.shuffle()
	var result = []
	for i in min(count, pool_copy.size()):
		result.append(pool_copy[i])
	return result

func start_draft(loser: String, winner: String):
	_loser_name = loser
	_winner_name = winner

	if winner == "" and loser == "":
		print("Draft: Empate — sin draft")
		draft_completed.emit()
		return

	# Fase 1: PERDEDOR elige primero (ahora con los rerolls disponibles)
	var gm = get_node_or_null("/root/GameManager")
	var count = 3
	_rerolls_remaining = 1
	if gm and gm.config:
		count = gm.config.draft_options_count
		_rerolls_remaining = gm.config.loser_reroll_count

	_draft_phase       = 1
	_current_options   = _pick_random(count)
	print("Draft: ", _loser_name, " (perdedor, elige primero) entre: ",
		  _current_options.map(func(a): return a.ability_name),
		  "  rerolls: ", _rerolls_remaining)
	show_draft_ui.emit(_current_options, _loser_name, _rerolls_remaining > 0)
	_check_cpu_auto_pick(_loser_name)

func on_option_selected(index: int):
	if _draft_phase == 1:
		# Perdedor ha elegido
		_selected_by_loser = _current_options[index]
		print("Draft: ", _loser_name, " eligió ", _selected_by_loser.ability_name)

		var remaining = _current_options.duplicate()
		remaining.remove_at(index)

		# Fase 2: GANADOR elige de las restantes (YA NO TIENE REROLL)
		var gm = get_node_or_null("/root/GameManager")
		_rerolls_remaining = 0

		_draft_phase     = 2
		_current_options = remaining
		print("Draft: ", _winner_name, " (ganador) elige entre: ",
			  remaining.map(func(a): return a.ability_name),
			  "  rerolls: ", _rerolls_remaining)
		show_draft_ui.emit(_current_options, _winner_name, false)
		_check_cpu_auto_pick(_winner_name)

	elif _draft_phase == 2:
		# Ganador ha elegido
		var selected_by_winner = _current_options[index]
		print("Draft: ", _winner_name, " eligió ", selected_by_winner.ability_name)

		_draft_phase = 0
		hide_draft_ui.emit()

		# Guardar en GameManager — ACUMULAR (append, no replace)
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			if not gm.player_abilities.has(_winner_name):
				gm.player_abilities[_winner_name] = []
			if not gm.player_abilities.has(_loser_name):
				gm.player_abilities[_loser_name] = []
			gm.player_abilities[_winner_name].append(selected_by_winner)
			gm.player_abilities[_loser_name].append(_selected_by_loser)

		print("Draft completado!")
		draft_completed.emit()

func on_reroll():
	if _draft_phase != 1 or _rerolls_remaining <= 0:
		return
	_rerolls_remaining -= 1
	var count = 3
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.config: count = gm.config.draft_options_count
	
	_current_options = _pick_random(count)
	print("Draft: ", _loser_name, " hace reroll (rerolls restantes: ", _rerolls_remaining, ")")
	show_draft_ui.emit(_current_options, _loser_name, _rerolls_remaining > 0)
	_check_cpu_auto_pick(_loser_name)

# --- Automatización para la IA ---
func _check_cpu_auto_pick(player_name: String):
	# Si el jugador que debe elegir es CPU, elegimos automáticamante.
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.config:
		if player_name == "Player2" and gm.config.p2_is_cpu:
			print("Draft: CPU (Player2) eligiendo automáticamente...")
			# Pequeña demora para que los humanos vean que la IA está "pensando" y evitar crashes de UI
			await get_tree().create_timer(0.6).timeout
			if _draft_phase > 0 and _current_options.size() > 0:
				on_option_selected(randi() % _current_options.size())
