extends CharacterBody2D

## Script principal del jugador (Player1).
## Soporta: loadout de armas, cambio de arma activa, habilidades acumuladas,
## movimiento, disparo, vida, escudo, dash, freeze, lifesteal.

@export var bullet_scene: PackedScene
@export var speed := 300.0

@export_group("Cámara")
@export var is_camera_player := false  ## true → esta instancia activa la Camera2D (solo P1)

@export_group("Controles")
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
@export var bullet_modifier: BulletModifier = null   # Fallback / asignado por Inspector
@export var max_health := 100

# === LOADOUT Y HABILIDADES ===
var weapon_loadout: Array     = []   # Array[BulletModifier]  — 3 armas
var active_weapon_index: int  = 0
var active_abilities: Array   = []   # Array[AbilityResource] — acumuladas en partida

# Estadísticas calculadas a partir de las habilidades
var _ab_damage_bonus: int              = 0
var _ab_damage_mult: float             = 1.0
var _ab_speed_bonus: float             = 0.0
var _ab_cooldown_reduction: float      = 0.0
var _ab_lifesteal: float               = 0.0
var _ab_shield_per_round: int          = 0
# Nuevas estadísticas de habilidades
var _ab_bonus_pierce: int              = 0
var _ab_bonus_bullet_speed: float      = 0.0
var _ab_bonus_bullet_count: int        = 0
var _ab_dash_cd_reduction: float       = 0.0
var _ab_bonus_max_health: int          = 0
var _ab_health_regen: float            = 0.0
var _ab_hp_drain: float                = 0.0
var _ab_invincible_during_dash: bool   = false
var _ab_double_shot_chance: float      = 0.0
var _ab_execute_bonus: int             = 0
var _ab_execute_threshold: int         = 0
var _ab_bullets_pierce_walls: bool     = false
var _ab_damage_on_tick: int            = 0
var _ab_tick_duration: float           = 0.0
var _effective_modifier: BulletModifier = null   # Weapon + habilidades combinados
var _base_speed: float                 = 300.0
var _base_max_health: int              = 100
var _base_dash_cooldown: float         = 1.2

# === COMBATE ===
var current_health: int
var can_shoot: bool = true
var shield: int     = 0

# === ESTADO ===
var frozen        := false
var is_dashing    := false
var dash_timer    := 0.0
var _dash_direction := Vector2.ZERO

## Cuando true, este jugador es controlado por BotController (no lee Input).
## Al desactivar bot_p2_enabled en GameConfig, esta variable queda en false
## y Player2 responde a controles físicos normales.
var is_bot := false

@onready var health_bar       = $HealthBarPivot/HealthBar
@onready var health_bar_pivot = $HealthBarPivot
@onready var _camera: Camera2D = $Camera2D if has_node("Camera2D") else null

func _ready():
	add_to_group("players")
	_base_speed         = speed
	_base_max_health    = max_health
	_base_dash_cooldown = dash_cooldown
	current_health      = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value     = current_health
	# Activar cámara solo si este jugador es el principal (P1)
	if _camera:
		_camera.enabled = is_camera_player

## Configura los límites de la cámara según los bordes del mapa.
## Llamado por GameManager tras el spawn, para que la cámara no salga del mapa.
func setup_camera_limits(bounds: Rect2) -> void:
	if _camera and _camera.enabled:
		_camera.limit_left   = int(bounds.position.x)
		_camera.limit_top    = int(bounds.position.y)
		_camera.limit_right  = int(bounds.position.x + bounds.size.x)
		_camera.limit_bottom = int(bounds.position.y + bounds.size.y)

# === LLAMADO POR GameManager AL INICIO DE CADA RONDA ===
func refresh_effective_modifier():
	# 1. Recalcular estadísticas de habilidades
	_ab_damage_bonus            = 0
	_ab_damage_mult             = 1.0
	_ab_speed_bonus             = 0.0
	_ab_cooldown_reduction      = 0.0
	_ab_lifesteal               = 0.0
	_ab_shield_per_round        = 0
	_ab_bonus_pierce            = 0
	_ab_bonus_bullet_speed      = 0.0
	_ab_bonus_bullet_count      = 0
	_ab_dash_cd_reduction       = 0.0
	_ab_bonus_max_health        = 0
	_ab_health_regen            = 0.0
	_ab_hp_drain                = 0.0
	_ab_invincible_during_dash  = false
	_ab_double_shot_chance      = 0.0
	_ab_execute_bonus           = 0
	_ab_execute_threshold       = 0
	_ab_bullets_pierce_walls    = false
	_ab_damage_on_tick          = 0
	_ab_tick_duration           = 0.0

	for ab in active_abilities:
		_ab_damage_bonus           += ab.bonus_damage
		_ab_damage_mult            *= ab.damage_multiplier
		_ab_speed_bonus            += ab.bonus_speed
		_ab_cooldown_reduction     += ab.cooldown_reduction
		_ab_lifesteal              += ab.lifesteal_percent
		_ab_shield_per_round       += ab.shield_per_round
		_ab_bonus_pierce           += ab.bonus_pierce
		_ab_bonus_bullet_speed     += ab.bonus_bullet_speed
		_ab_bonus_bullet_count     += ab.bonus_bullet_count
		_ab_dash_cd_reduction      += ab.dash_cooldown_reduction
		_ab_bonus_max_health       += ab.bonus_max_health
		_ab_health_regen           += ab.health_regen_per_second
		_ab_hp_drain               += ab.hp_drain_per_second
		_ab_double_shot_chance     += ab.double_shot_chance
		_ab_execute_bonus          += ab.execute_bonus_damage
		_ab_execute_threshold       = max(_ab_execute_threshold, ab.execute_threshold)
		if ab.invincible_during_dash:
			_ab_invincible_during_dash = true
		if ab.bullets_pierce_walls:
			_ab_bullets_pierce_walls   = true
		_ab_damage_on_tick         = max(_ab_damage_on_tick, ab.damage_on_tick)
		_ab_tick_duration          = max(_ab_tick_duration,  ab.tick_duration)

	# 2. Obtener arma base
	var base: BulletModifier = null
	if weapon_loadout.size() > 0 and active_weapon_index < weapon_loadout.size():
		base = weapon_loadout[active_weapon_index]
	elif bullet_modifier:
		base = bullet_modifier

	# 3. Construir modificador efectivo
	if base == null:
		_effective_modifier = null
	else:
		_effective_modifier                = BulletModifier.new()
		_effective_modifier.modifier_name  = base.modifier_name
		_effective_modifier.description    = base.description
		_effective_modifier.icon_color     = base.icon_color
		_effective_modifier.speed          = base.speed + _ab_bonus_bullet_speed
		_effective_modifier.damage         = int((base.damage + _ab_damage_bonus) * _ab_damage_mult)
		_effective_modifier.pierce         = base.pierce + _ab_bonus_pierce
		_effective_modifier.lifetime       = base.lifetime
		_effective_modifier.color          = base.color
		_effective_modifier.scale          = base.scale
		_effective_modifier.cooldown       = max(0.1, base.cooldown - _ab_cooldown_reduction)
		_effective_modifier.bullet_count   = base.bullet_count + _ab_bonus_bullet_count
		_effective_modifier.spread_angle   = base.spread_angle

	# 4. Aplicar bonus de velocidad, dash cooldown, vida máxima y escudo
	speed         = _base_speed + _ab_speed_bonus
	shield        = _ab_shield_per_round
	dash_cooldown = max(0.2, _base_dash_cooldown - _ab_dash_cd_reduction)

	# Bonus de HP máximo (solo incremental para no sobreescribir cada ronda)
	var effective_max = _base_max_health + _ab_bonus_max_health
	if max_health != effective_max:
		var diff = effective_max - max_health
		max_health     = effective_max
		current_health = min(max_health, current_health + diff)
		if health_bar:
			health_bar.max_value = max_health
			health_bar.value     = current_health

	print(name, " — arma activa: ", (_effective_modifier.modifier_name if _effective_modifier else "ninguna"),
		  "  habilidades: ", active_abilities.size())

# === Lifesteal callback (llamado por bullet.gd) ===
func on_damage_dealt(amount: int):
	if _ab_lifesteal > 0 and amount > 0:
		var heal = int(amount * _ab_lifesteal)
		current_health = min(max_health, current_health + heal)
		if health_bar:
			health_bar.value = current_health

# === FÍSICA ===
func _physics_process(delta):
	# Regeneración y drenaje de HP (solo cuando no está congelado = durante la ronda)
	if not frozen:
		if _ab_health_regen > 0.0:
			current_health = min(max_health, current_health + _ab_health_regen * delta)
			if health_bar:
				health_bar.value = current_health
		if _ab_hp_drain > 0.0:
			current_health -= _ab_hp_drain * max_health * delta
			if health_bar:
				health_bar.value = current_health
			if current_health <= 0:
				die()
				return

	if not frozen:
		if dash_timer > 0:
			dash_timer -= delta

		if is_dashing:
			velocity = _dash_direction * dash_speed
			move_and_slide()
		elif not is_bot:
			var direction = Vector2.ZERO
			if Input.is_action_pressed(right_input): direction.x += 1
			if Input.is_action_pressed(left_input):  direction.x -= 1
			if Input.is_action_pressed(down_input):  direction.y += 1
			if Input.is_action_pressed(up_input):    direction.y -= 1
			direction = direction.normalized()

			# Dash
			var wants_dash = false
			if dash_input != "" and InputMap.has_action(dash_input):
				wants_dash = Input.is_action_just_pressed(dash_input)
			elif dash_input == "ui_shift":
				wants_dash = Input.is_physical_key_pressed(KEY_SHIFT)

			if wants_dash and dash_timer <= 0 and direction != Vector2.ZERO:
				is_dashing    = true
				dash_timer    = dash_cooldown
				_dash_direction = direction
				if has_node("Sprite2D"):
					var tw = create_tween()
					tw.tween_property($Sprite2D, "modulate:a", 0.3, 0.05)
					tw.tween_property($Sprite2D, "modulate:a", 1.0, dash_duration)
				await get_tree().create_timer(dash_duration).timeout
				is_dashing = false
			else:
				velocity = direction * speed
				move_and_slide()

			# Apuntado
			var mouse_pos = get_global_mouse_position()
			rotation = (mouse_pos - global_position).angle()

			# Disparo
			if Input.is_action_just_pressed(shoot_input):
				shoot()

	if health_bar_pivot:
		health_bar_pivot.rotation = -rotation

# === DISPARO ===
## aim_direction: si != Vector2.ZERO se usa como dirección base (para el bot).
## Si es Vector2.ZERO, se apunta al ratón (comportamiento normal del jugador).
func shoot(aim_direction: Vector2 = Vector2.ZERO) -> void:
	if not can_shoot: return
	if bullet_scene == null:
		print("ERROR: bullet_scene no asignada en ", name)
		return

	# Usar effective modifier si existe, si no bullet_modifier del inspector
	var mod = _effective_modifier if _effective_modifier else bullet_modifier
	if mod == null:
		print("AVISO: ", name, " no tiene modifier. Disparo cancelado.")
		return

	can_shoot = false

	# Disparo afortunado: probabilidad de doblar el daño de este disparo
	var active_mod = mod
	if _ab_double_shot_chance > 0.0 and randf() < _ab_double_shot_chance:
		active_mod                = BulletModifier.new()
		active_mod.modifier_name  = mod.modifier_name
		active_mod.speed          = mod.speed
		active_mod.damage         = mod.damage * 2
		active_mod.pierce         = mod.pierce
		active_mod.lifetime       = mod.lifetime
		active_mod.color          = mod.color
		active_mod.scale          = mod.scale
		active_mod.cooldown       = mod.cooldown
		active_mod.bullet_count   = mod.bullet_count
		active_mod.spread_angle   = mod.spread_angle

	var count    = active_mod.bullet_count
	var spread   = deg_to_rad(active_mod.spread_angle)
	var base_dir: Vector2
	if aim_direction != Vector2.ZERO:
		base_dir = aim_direction.normalized()
	else:
		base_dir = ($Muzzle.global_position).direction_to(get_global_mouse_position())

	for i in count:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = $Muzzle.global_position
		if count > 1 and spread > 0:
			var angle_offset = lerp(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
			bullet.direction = base_dir.rotated(angle_offset)
		else:
			bullet.direction = base_dir
		bullet.shooter          = self
		bullet.modifier         = active_mod
		# Pasar propiedades de habilidades al proyectil
		bullet.pierce_walls       = _ab_bullets_pierce_walls
		bullet.execute_bonus      = _ab_execute_bonus
		bullet.execute_threshold  = _ab_execute_threshold
		bullet.damage_on_tick     = _ab_damage_on_tick
		bullet.tick_duration      = _ab_tick_duration
		get_parent().add_child(bullet)

	await get_tree().create_timer(active_mod.cooldown).timeout
	can_shoot = true

# === DAÑO ===
func take_damage(amount: int):
	# Intangibilidad durante el dash
	if is_dashing and _ab_invincible_during_dash:
		return
	if shield > 0:
		var absorbed = min(shield, amount)
		shield  -= absorbed
		amount  -= absorbed
		print(name, " escudo absorbe ", absorbed, " (restante: ", shield, ")")
		if amount <= 0:
			_flash_damage()
			return

	current_health -= amount
	print(name, " vida: ", current_health)
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
	print(name, " muerto")
	queue_free()

# === DASH EXTERNO (para BotController) ===
## Permite que un controlador externo (bot) active el dash en una dirección.
func request_dash(dir: Vector2) -> void:
	if is_dashing or dash_timer > 0 or dir == Vector2.ZERO:
		return
	is_dashing      = true
	dash_timer      = dash_cooldown
	_dash_direction = dir.normalized()
	if has_node("Sprite2D"):
		var tw = create_tween()
		tw.tween_property($Sprite2D, "modulate:a", 0.3, 0.05)
		tw.tween_property($Sprite2D, "modulate:a", 1.0, dash_duration)
	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false
