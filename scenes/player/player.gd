extends CharacterBody2D

## Script principal del jugador (Player1).
## Soporta: loadout de armas, cambio de arma activa, habilidades acumuladas,
## movimiento, disparo, vida, escudo, dash, freeze, lifesteal.

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
@export var bullet_modifier: BulletModifier = null   # Fallback / asignado por Inspector
@export var max_health := 100

# === LOADOUT Y HABILIDADES ===
var weapon_loadout: Array     = []   # Array[BulletModifier]  — 3 armas
var active_weapon_index: int  = 0
var active_abilities: Array   = []   # Array[AbilityResource] — acumuladas en partida

# Estadísticas calculadas a partir de las habilidades
var _ab_damage_bonus: int        = 0
var _ab_damage_mult: float       = 1.0
var _ab_speed_bonus: float       = 0.0
var _ab_cooldown_reduction: float = 0.0
var _ab_lifesteal: float         = 0.0
var _ab_shield_per_round: int    = 0
var _effective_modifier: BulletModifier = null   # Weapon + habilidades combinados
var _base_speed: float           = 300.0

# === COMBATE ===
var current_health: int
var can_shoot: bool = true
var shield: int     = 0

# === ESTADO ===
var frozen        := false
var is_dashing    := false
var dash_timer    := 0.0
var _dash_direction := Vector2.ZERO

@onready var health_bar       = $HealthBarPivot/HealthBar
@onready var health_bar_pivot = $HealthBarPivot
@onready var camera           = $Camera2D

func _ready():
	add_to_group("players")
	_base_speed    = speed
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value     = current_health

	if name == "Player1" and camera:
		camera.enabled = true
		var arena = get_tree().get_first_node_in_group("arena")
		if arena:
			camera.limit_left   = 0
			camera.limit_top    = 0
			camera.limit_right  = int(arena.arena_size.x)
			camera.limit_bottom = int(arena.arena_size.y)


# === LLAMADO POR GameManager AL INICIO DE CADA RONDA ===
func refresh_effective_modifier():
	# 1. Recalcular estadísticas de habilidades
	_ab_damage_bonus        = 0
	_ab_damage_mult         = 1.0
	_ab_speed_bonus         = 0.0
	_ab_cooldown_reduction  = 0.0
	_ab_lifesteal           = 0.0
	_ab_shield_per_round    = 0
	for ab in active_abilities:
		_ab_damage_bonus       += ab.bonus_damage
		_ab_damage_mult        *= ab.damage_multiplier
		_ab_speed_bonus        += ab.bonus_speed
		_ab_cooldown_reduction += ab.cooldown_reduction
		_ab_lifesteal          += ab.lifesteal_percent
		_ab_shield_per_round   += ab.shield_per_round

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
		_effective_modifier.speed          = base.speed
		_effective_modifier.damage         = int((base.damage + _ab_damage_bonus) * _ab_damage_mult)
		_effective_modifier.pierce         = base.pierce
		_effective_modifier.lifetime       = base.lifetime
		_effective_modifier.color          = base.color
		_effective_modifier.scale          = base.scale
		_effective_modifier.cooldown       = max(0.1, base.cooldown - _ab_cooldown_reduction)
		_effective_modifier.bullet_count   = base.bullet_count
		_effective_modifier.spread_angle   = base.spread_angle

	# 4. Aplicar bonus de velocidad y escudo
	speed  = _base_speed + _ab_speed_bonus
	shield = _ab_shield_per_round
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
	if not frozen:
		if dash_timer > 0:
			dash_timer -= delta

		if is_dashing:
			velocity = _dash_direction * dash_speed
			move_and_slide()
		else:
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
func shoot():
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

	var count  = mod.bullet_count
	var spread = deg_to_rad(mod.spread_angle)
	var base_dir = ($Muzzle.global_position).direction_to(get_global_mouse_position())

	for i in count:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = $Muzzle.global_position
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

# === DAÑO ===
func take_damage(amount: int):
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
