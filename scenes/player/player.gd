extends CharacterBody2D

## Script principal del jugador — soporta tanto control humano como IA (CPU).
## La IA se activa con set_cpu_mode(true, difficulty) desde GameManager.
## Soporta: loadout de armas, habilidades acumuladas, movimiento, disparo,
## vida, escudo, dash, freeze, lifesteal, regen, drain, veneno, y más.

@export var bullet_scene: PackedScene
@export var speed := 300.0

@export var up_input    := "ui_up"
@export var down_input  := "ui_down"
@export var left_input  := "ui_left"
@export var right_input := "ui_right"
@export var shoot_input := "ui_accept"
@export var dash_input  := "ui_shift"

@export_group("Dash")
@export var dash_speed    := 900.0
@export var dash_duration := 0.15
@export var dash_cooldown := 1.2

@export_group("Combate")
@export var bullet_modifier: BulletModifier = null
@export var max_health := 100

# === LOADOUT Y HABILIDADES ===
var weapon_loadout: Array     = []
var active_weapon_index: int  = 0
var active_abilities: Array   = []

# --- Stats BASE
var _base_speed: float         = 300.0
var _base_max_health: int      = 100
var _base_dash_cooldown: float = 1.2

# --- Stats calculados de habilidades
var _ab_damage_bonus: int         = 0
var _ab_damage_mult: float        = 1.0
var _ab_speed_bonus: float        = 0.0
var _ab_cooldown_reduction: float = 0.0
var _ab_lifesteal: float          = 0.0
var _ab_shield_per_round: int     = 0

var _ab_bullet_speed_mult: float    = 1.0
var _ab_bonus_pierce: int           = 0
var _ab_bonus_bullet_count: int     = 0
var _ab_damage_on_tick: int         = 0
var _ab_tick_duration: float        = 0.0
var _ab_double_shot_chance: float   = 0.0
var _ab_execute_bonus_damage: int   = 0
var _ab_execute_threshold: int      = 0
var _ab_bullets_pierce_walls: bool  = false
var _ab_dash_cooldown_red: float    = 0.0
var _ab_invincible_during_dash: bool = false
var _ab_bonus_max_health: int       = 0
var _ab_health_regen: float         = 0.0
var _ab_hp_drain: float             = 0.0

var _effective_modifier: BulletModifier = null

# === COMBATE ===
var current_health: int
var can_shoot: bool = true
var shield: int     = 0

# === ESTADO ===
var frozen          := false
var is_dashing      := false
var dash_timer      := 0.0
var _dash_time_left := 0.0
var _dash_direction := Vector2.ZERO

var _regen_accumulator: float = 0.0
var _drain_accumulator: float = 0.0

# =========================================================
# === CPU / IA ===
# =========================================================
var is_cpu: bool       = false
var cpu_difficulty: int = 1   # 0=Fácil  1=Normal  2=Difícil

var _cpu_target: Node  = null
var _cpu_hit_timer: float   = 0.0   # tiempo desde el último golpe recibido (activa esquiva)
var _cpu_strafe_dir: float  = 1.0   # dirección de strafe: +1 ó -1
var _cpu_strafe_timer: float = 0.0  # temporizador para cambiar dirección de strafe

## Llamado por GameManager para activar/desactivar la IA y su nivel
func set_cpu_mode(enable: bool, difficulty: int = 1):
	is_cpu         = enable
	cpu_difficulty = difficulty
	print(name, " modo CPU: ", enable, "  dificultad: ", difficulty)

@onready var health_bar       = $HealthBarPivot/HealthBar
@onready var health_bar_pivot = $HealthBarPivot

func _ready():
	add_to_group("players")
	_base_speed         = speed
	_base_max_health    = max_health
	_base_dash_cooldown = dash_cooldown
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value     = current_health

# =========================================================
# LLAMADO POR GameManager AL INICIO DE CADA RONDA
# =========================================================
func refresh_effective_modifier():
	# 1. Resetear stats de habilidades
	_ab_damage_bonus          = 0
	_ab_damage_mult           = 1.0
	_ab_speed_bonus           = 0.0
	_ab_cooldown_reduction    = 0.0
	_ab_lifesteal             = 0.0
	_ab_shield_per_round      = 0
	_ab_bullet_speed_mult     = 1.0
	_ab_bonus_pierce          = 0
	_ab_bonus_bullet_count    = 0
	_ab_damage_on_tick        = 0
	_ab_tick_duration         = 0.0
	_ab_double_shot_chance    = 0.0
	_ab_execute_bonus_damage  = 0
	_ab_execute_threshold     = 0
	_ab_bullets_pierce_walls  = false
	_ab_dash_cooldown_red     = 0.0
	_ab_invincible_during_dash = false
	_ab_bonus_max_health      = 0
	_ab_health_regen          = 0.0
	_ab_hp_drain              = 0.0
	_regen_accumulator        = 0.0
	_drain_accumulator        = 0.0

	# 2. Acumular desde habilidades activas
	for ab in active_abilities:
		_ab_damage_bonus        += ab.bonus_damage
		_ab_damage_mult         *= ab.damage_multiplier
		_ab_speed_bonus         += ab.bonus_speed
		_ab_cooldown_reduction  += ab.cooldown_reduction
		_ab_lifesteal           += ab.lifesteal_percent
		_ab_shield_per_round    += ab.shield_per_round
		_ab_bullet_speed_mult   *= ab.bullet_speed_multiplier
		_ab_bonus_pierce        += ab.bonus_pierce
		_ab_bonus_bullet_count  += ab.bonus_bullet_count
		_ab_damage_on_tick      += ab.damage_on_tick
		if ab.tick_duration > _ab_tick_duration:
			_ab_tick_duration = ab.tick_duration
		_ab_double_shot_chance   = clamp(_ab_double_shot_chance + ab.double_shot_chance, 0.0, 1.0)
		_ab_execute_bonus_damage += ab.execute_bonus_damage
		if ab.execute_threshold > 0:
			_ab_execute_threshold = max(_ab_execute_threshold, ab.execute_threshold)
		if ab.bullets_pierce_walls:
			_ab_bullets_pierce_walls = true
		_ab_dash_cooldown_red   += ab.dash_cooldown_reduction
		if ab.invincible_during_dash:
			_ab_invincible_during_dash = true
		_ab_bonus_max_health    += ab.bonus_max_health
		_ab_health_regen        += ab.health_regen_per_second
		_ab_hp_drain            += ab.hp_drain_per_second

	# 3. Obtener arma base
	var base: BulletModifier = null
	if weapon_loadout.size() > 0 and active_weapon_index < weapon_loadout.size():
		base = weapon_loadout[active_weapon_index]
	elif bullet_modifier:
		base = bullet_modifier

	# 4. Construir modificador efectivo
	if base == null:
		_effective_modifier = null
	else:
		_effective_modifier                       = BulletModifier.new()
		_effective_modifier.modifier_name         = base.modifier_name
		_effective_modifier.description           = base.description
		_effective_modifier.icon_color            = base.icon_color
		_effective_modifier.speed                 = base.speed * _ab_bullet_speed_mult
		_effective_modifier.damage                = int((base.damage + _ab_damage_bonus) * _ab_damage_mult)
		_effective_modifier.pierce                = base.pierce + _ab_bonus_pierce
		_effective_modifier.lifetime              = base.lifetime
		_effective_modifier.color                 = base.color
		_effective_modifier.scale                 = base.scale
		_effective_modifier.cooldown              = max(0.05, base.cooldown - _ab_cooldown_reduction)
		_effective_modifier.bullet_count          = base.bullet_count + _ab_bonus_bullet_count
		_effective_modifier.spread_angle          = base.spread_angle
		_effective_modifier.double_shot_chance    = _ab_double_shot_chance
		_effective_modifier.execute_bonus_damage  = _ab_execute_bonus_damage
		_effective_modifier.execute_threshold     = _ab_execute_threshold
		_effective_modifier.bullets_pierce_walls  = _ab_bullets_pierce_walls
		_effective_modifier.damage_on_tick        = _ab_damage_on_tick
		_effective_modifier.tick_duration         = _ab_tick_duration

	# 5. Aplicar bonus de movimiento y dash
	speed         = _base_speed + _ab_speed_bonus
	shield        = _ab_shield_per_round
	dash_cooldown = max(0.3, _base_dash_cooldown - _ab_dash_cooldown_red)

	# 6. Aplicar bonus de vida máxima
	max_health     = _base_max_health + _ab_bonus_max_health
	current_health = min(current_health, max_health)
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value     = current_health

	print(name, " — arma: ", (_effective_modifier.modifier_name if _effective_modifier else "ninguna"),
		  "  habilidades: ", active_abilities.size(),
		  "  HP máx: ", max_health, "  CPU: ", is_cpu)

# =========================================================
# LIFESTEAL (llamado por bullet.gd)
# =========================================================
func on_damage_dealt(amount: int):
	if _ab_lifesteal > 0 and amount > 0:
		var heal = int(amount * _ab_lifesteal)
		current_health = min(max_health, current_health + heal)
		if health_bar:
			health_bar.value = current_health

# =========================================================
# VENENO (llamado por bullet.gd)
# =========================================================
func apply_poison(tick_damage: int, ticks: int):
	for _i in range(ticks):
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
		
		# Aplica true damage ignorando el escudo para mayor peligrosidad
		current_health -= tick_damage
		print(name, " veneno tic: -", tick_damage, " (HP: ", current_health, ")")
		if health_bar:
			health_bar.value = current_health
		
		# Flash Visual VERDE INTENSO de envenenamiento
		if has_node("Sprite2D"):
			$Sprite2D.modulate = Color(0.2, 0.9, 0.2)
			var tween = create_tween()
			tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.25)
		
		if current_health <= 0:
			die()
			return

# =========================================================
# FÍSICA
# =========================================================
func _physics_process(delta):
	# Si está congelado (countdown), no procesar input ni física
	if not frozen:
		
		# Procesar Unified Dash Logic (resuelve bugs del lambda que crasheaba si el player moría)
		if dash_timer > 0:
			dash_timer -= delta
		if is_dashing:
			_dash_time_left -= delta
			velocity = _dash_direction * dash_speed
			move_and_slide()
			if _dash_time_left <= 0:
				is_dashing = false
		else:
			# Procesar lógica de CPU o humano solo si no está dasheando
			if is_cpu:
				_cpu_process(delta)
			else:
				_human_process(delta)

		# === REGENERACIÓN ===
		if _ab_health_regen > 0:
			_regen_accumulator += _ab_health_regen * delta
			if _regen_accumulator >= 1.0:
				var heal = int(_regen_accumulator)
				_regen_accumulator -= heal
				current_health = min(max_health, current_health + heal)
				if health_bar:
					health_bar.value = current_health

		# === DRENAJE (Berserker) ===
		if _ab_hp_drain > 0:
			_drain_accumulator += max_health * _ab_hp_drain * delta
			if _drain_accumulator >= 1.0:
				var drain = int(_drain_accumulator)
				_drain_accumulator -= drain
				current_health -= drain
				if health_bar:
					health_bar.value = current_health
				if current_health <= 0:
					die()
	
	# La barra de vida siempre se mantiene horizontal
	if health_bar_pivot:
		health_bar_pivot.rotation = -rotation

# =========================================================
# CONTROL HUMANO
# =========================================================
func _human_process(_delta):
	var direction = Vector2.ZERO
	if Input.is_action_pressed(right_input): direction.x += 1
	if Input.is_action_pressed(left_input):  direction.x -= 1
	if Input.is_action_pressed(down_input):  direction.y += 1
	if Input.is_action_pressed(up_input):    direction.y -= 1
	direction = direction.normalized()

	# Dash detect
	var wants_dash = false
	if dash_input != "" and InputMap.has_action(dash_input):
		wants_dash = Input.is_action_just_pressed(dash_input)
	elif dash_input == "ui_shift":
		wants_dash = Input.is_physical_key_pressed(KEY_SHIFT)

	if wants_dash and dash_timer <= 0 and direction != Vector2.ZERO:
		_perform_dash(direction)
	else:
		velocity = direction * speed
		move_and_slide()

	# Apuntado
	rotation = (get_global_mouse_position() - global_position).angle()

	# Disparo
	if Input.is_action_just_pressed(shoot_input):
		shoot()

# =========================================================
# CONTROL CPU / IA
# =========================================================
func _cpu_process(delta):
	# Buscar objetivo (el otro jugador)
	_cpu_target = _cpu_find_target()
	if _cpu_target == null or not is_instance_valid(_cpu_target):
		return

	var to_target  = _cpu_target.global_position - global_position
	var dist       = to_target.length()
	var shoot_range = _cpu_shoot_range()

	# Temporizador de strafe
	_cpu_strafe_timer -= delta
	if _cpu_strafe_timer <= 0.0:
		_cpu_strafe_timer = randf_range(1.2, 2.8)
		_cpu_strafe_dir   = 1.0 if randf() > 0.5 else -1.0

	# Esquiva con dash
	if _cpu_hit_timer > 0:
		_cpu_hit_timer -= delta
		if cpu_difficulty >= 1 and dash_timer <= 0:
			var dodge_dir = to_target.normalized().rotated(PI * 0.5 * _cpu_strafe_dir)
			_perform_dash(dodge_dir)
		return

	# Apuntado con inaccuracy
	var inaccuracy = _cpu_inaccuracy()
	var aim_offset = Vector2(randf_range(-inaccuracy, inaccuracy), randf_range(-inaccuracy, inaccuracy))
	rotation = (_cpu_target.global_position + aim_offset - global_position).angle()

	# Movimiento / Persecucion
	var move_dir: Vector2
	if dist > shoot_range:
		move_dir = to_target.normalized()
	else:
		move_dir = to_target.normalized().rotated(PI * 0.5 * _cpu_strafe_dir)

	velocity = move_dir * speed
	move_and_slide()

	# Disparo recurrente
	if dist <= shoot_range and can_shoot:
		shoot()

func _cpu_find_target() -> Node:
	for node in get_tree().get_nodes_in_group("players"):
		if node != self:
			return node
	return null

func _cpu_shoot_range() -> float:
	match cpu_difficulty:
		0: return 220.0
		1: return 380.0
		2: return 560.0
	return 380.0

func _cpu_inaccuracy() -> float:
	match cpu_difficulty:
		0: return 90.0
		1: return 35.0
		2: return 8.0
	return 35.0

# =========================================================
# ACCIÓN: DASH SHARED Logic
# =========================================================
func _perform_dash(dir: Vector2):
	is_dashing = true
	dash_timer = dash_cooldown
	_dash_time_left = dash_duration
	_dash_direction = dir.normalized()
	
	if has_node("Sprite2D"):
		var tw = create_tween()
		tw.tween_property($Sprite2D, "modulate:a", 0.3, 0.05)
		tw.tween_property($Sprite2D, "modulate:a", 1.0, dash_duration)

# =========================================================
# DISPARO
# =========================================================
func shoot():
	if not can_shoot:
		return
	if bullet_scene == null:
		print("ERROR: bullet_scene no asignada en ", name)
		return

	var mod = _effective_modifier if _effective_modifier else bullet_modifier
	if mod == null:
		return

	can_shoot = false
	var count    = mod.bullet_count
	var spread   = deg_to_rad(mod.spread_angle)
	
	var base_dir = Vector2.RIGHT.rotated(rotation)

	for i in count:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = $Muzzle.global_position
		
		# Dispersión manual de pellets multiples
		if count > 1 and spread > 0:
			var angle_offset = lerp(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
			bullet.direction = base_dir.rotated(angle_offset)
		else:
			bullet.direction = base_dir
			
		bullet.shooter  = self
		bullet.modifier = mod
		get_parent().add_child(bullet)

	await get_tree().create_timer(mod.cooldown).timeout
	can_shoot = true

# =========================================================
# DAÑO
# =========================================================
func take_damage(amount: int):
	# Intangibilidad durante el dash
	if _ab_invincible_during_dash and is_dashing:
		return

	# CPU: activar esquiva
	if is_cpu and cpu_difficulty >= 1:
		_cpu_hit_timer = 0.4

	if shield > 0:
		var absorbed = min(shield, amount)
		shield  -= absorbed
		amount  -= absorbed
		print(name, " escudo absorbe ", absorbed)
		if amount <= 0:
			_flash_damage()
			return

	current_health -= amount
	print(name, " vida restante:", current_health)
	
	if health_bar:
		health_bar.value = current_health
	_flash_damage()
	
	if current_health <= 0:
		die()

func _flash_damage():
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.15)

func die():
	print(name, " ha muerto")
	queue_free()
