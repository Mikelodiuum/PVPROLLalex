extends Node
class_name BotController

## IA de combate para Player2 (CPU bot).
## Se inyecta como nodo hijo de Player2 por GameManager al inicio de cada ronda.
##
## Estados:
##   SEARCH — No ve al enemigo. Patrulla con sesgo al centro.
##   CHASE  — Ve al enemigo pero está lejos. Se acerca.
##   ATTACK — En rango. Dispara y strafe lateral.
##   DODGE  — Bala detectada. Dash perpendicular.
##
## Para sustituir por jugador real: desactivar bot_p2_enabled en GameConfig.
## Este nodo NO se inyecta y Player2 usa controles físicos normales.

enum State { SEARCH, CHASE, ATTACK, DODGE }

# ── Refs externas ─────────────────────────────────────────────────────────────
var player: CharacterBody2D = null   ## Nodo Player2 que controlamos
var config: GameConfig      = null   ## Para leer dificultad

# ── Parámetros por dificultad [FÁCIL=0, NORMAL=1, DIFÍCIL=2] ─────────────────
const VISION_RANGE     := [450.0, 700.0, 950.0]
const SHOOT_RANGE      := [340.0, 540.0, 740.0]
const DODGE_ALERT_DIST := [175.0, 200.0, 225.0]
const DODGE_CHANCE_ARR := [0.35,  0.65,  0.92]
const AIM_WOBBLE_DEG   := [24.0,  10.0,  2.5]
const STRAFE_FACTOR    := [0.45,  0.75,  1.0]
const REACT_DELAY      := [0.28,  0.16,  0.06]

# ── Estado interno ────────────────────────────────────────────────────────────
var _state      := State.SEARCH
var _prev_state := State.SEARCH

var _wp           := Vector2.ZERO  # waypoint de búsqueda
var _wp_timer     := 0.0

var _dodge_pending    := false
var _dodge_dir        := Vector2.ZERO
var _react_countdown  := 0.0

var _strafe_sign  := 1.0
var _strafe_timer := 0.0

var _target:    Node  = null
var _diff:      int   = 1
var _map_bounds := Rect2(0.0, 0.0, 3456.0, 1944.0)

# =============================================================================
func _ready() -> void:
	# Buscar al otro jugador como objetivo
	for p in get_tree().get_nodes_in_group("players"):
		if p != player:
			_target = p
			break

	# Límites del mapa
	var arena = get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("get_map_bounds"):
		_map_bounds = arena.get_map_bounds()

	# Caché de dificultad
	if config:
		_diff = clamp(int(config.bot_p2_difficulty), 0, 2)

	_pick_search_waypoint()

# =============================================================================
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	if player.frozen:
		return

	# Durante el dash, player.gd maneja la física; solo actualizamos el estado
	if player.is_dashing:
		if _state == State.DODGE:
			pass   # esperamos a que termine
		return

	# Si estábamos en DODGE y el dash ya terminó (frame siguiente)
	if _state == State.DODGE:
		_exit_dodge()
		return

	_check_dodge_needed(delta)

	match _state:
		State.SEARCH:  _tick_search(delta)
		State.CHASE:   _tick_chase()
		State.ATTACK:  _tick_attack(delta)
		State.DODGE:   pass   # gestionado arriba

	player.move_and_slide()

# =============================================================================
# DETECCIÓN Y ESQUIVA
# =============================================================================
func _check_dodge_needed(delta: float) -> void:
	# Si ya hay una esquiva pendiente, hacer countdown
	if _dodge_pending:
		_react_countdown -= delta
		if _react_countdown <= 0.0:
			_dodge_pending   = false
			_react_countdown = 0.0
			_enter_dodge()
		return

	var alert: float = DODGE_ALERT_DIST[_diff]

	for b in get_tree().get_nodes_in_group("bullets"):
		if not is_instance_valid(b):
			continue
		if b.get("shooter") == player:
			continue

		var dist := player.global_position.distance_to(b.global_position)
		if dist > alert:
			continue

		var bdir: Vector2 = b.get("direction") if b.get("direction") != null else Vector2.ZERO
		if bdir == Vector2.ZERO:
			continue

		# ¿Se mueve hacia el bot?
		var to_bot: Vector2 = (player.global_position - b.global_position).normalized()
		if bdir.normalized().dot(to_bot) < 0.5:
			continue

		# Tirada de dado: ¿el bot reacciona?
		if randf() > DODGE_CHANCE_ARR[_diff]:
			return

		# Dirección perpendicular aleatoria
		var side    := 1.0 if randf() > 0.5 else -1.0
		_dodge_dir       = bdir.normalized().rotated(PI * 0.5 * side)
		_dodge_pending   = true
		_react_countdown = REACT_DELAY[_diff]
		return

func _enter_dodge() -> void:
	_prev_state = _state
	_state      = State.DODGE
	if player.has_method("request_dash"):
		player.request_dash(_dodge_dir)

func _exit_dodge() -> void:
	_state = _prev_state
	if _state == State.SEARCH:
		_pick_search_waypoint()

# =============================================================================
# SEARCH
# =============================================================================
func _tick_search(delta: float) -> void:
	if _can_see_target():
		_state = State.CHASE
		return

	_wp_timer -= delta
	if _wp_timer <= 0.0 or player.global_position.distance_to(_wp) < 80.0:
		_pick_search_waypoint()

	var dir := player.global_position.direction_to(_wp)
	player.velocity = dir * player.speed
	player.rotation = dir.angle()

func _pick_search_waypoint() -> void:
	_wp_timer = 2.0 + randf() * 2.0
	var center := _map_bounds.get_center()
	if randf() < 0.65:
		# Sesgo al centro con algo de ruido
		_wp = center + Vector2(randf_range(-260.0, 260.0), randf_range(-260.0, 260.0))
	else:
		var m := 150.0
		_wp = Vector2(
			randf_range(_map_bounds.position.x + m, _map_bounds.end.x - m),
			randf_range(_map_bounds.position.y + m, _map_bounds.end.y - m)
		)

# =============================================================================
# CHASE
# =============================================================================
func _tick_chase() -> void:
	if not _can_see_target():
		_state = State.SEARCH
		_pick_search_waypoint()
		return

	var dist := player.global_position.distance_to(_target.global_position)
	if dist <= SHOOT_RANGE[_diff]:
		_state = State.ATTACK
		_strafe_timer = 0.0
		return

	var dir := player.global_position.direction_to(_target.global_position)
	player.velocity = dir * player.speed
	player.rotation = dir.angle()

# =============================================================================
# ATTACK
# =============================================================================
func _tick_attack(delta: float) -> void:
	if not _can_see_target():
		_state = State.SEARCH
		_pick_search_waypoint()
		return

	var dist    := player.global_position.distance_to(_target.global_position)
	var dir_to  := player.global_position.direction_to(_target.global_position)

	if dist > SHOOT_RANGE[_diff] * 1.25:
		_state = State.CHASE
		return

	# Apuntar al objetivo
	player.rotation = dir_to.angle()

	# Strafe lateral: cambiar dirección periódicamente
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_sign  = 1.0 if randf() > 0.5 else -1.0
		_strafe_timer = 0.85 + randf() * 0.9

	var perp := dir_to.rotated(PI * 0.5) * _strafe_sign
	var sf: float = STRAFE_FACTOR[_diff]

	# Control de distancia: mantener range ideal (~60% del shoot_range)
	var ideal: float = SHOOT_RANGE[_diff] * 0.6
	var ap     := 0.0
	if dist < ideal * 0.55:
		ap = -0.8
	elif dist > ideal * 1.55:
		ap = 0.9

	player.velocity = (perp * sf + dir_to * ap * (1.0 - sf * 0.4)) * player.speed

	# Disparar con puntería escalada por dificultad
	if player.can_shoot:
		var wobble  := deg_to_rad(AIM_WOBBLE_DEG[_diff])
		var aim_dir := dir_to.rotated(randf_range(-wobble, wobble))
		player.shoot(aim_dir)

# =============================================================================
# UTILIDADES
# =============================================================================
func _can_see_target() -> bool:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		return false
	return player.global_position.distance_to(_target.global_position) <= VISION_RANGE[_diff]
