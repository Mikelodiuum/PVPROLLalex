extends CharacterBody2D

## Script principal del jugador. Sirve para P1 y P2 configurando los inputs via inspector.
## Soporta: movimiento, disparo con cooldown, vida, barra de vida, flash de daño,
## freeze (countdown), escudo temporal, y disparos múltiples (shotgun).

@export var bullet_scene: PackedScene
@export var speed := 300.0

# Inputs configurables (permite reusar el mismo script para ambos jugadores)
@export var up_input := "ui_up"
@export var down_input := "ui_down"
@export var left_input := "ui_left"
@export var right_input := "ui_right"
@export var shoot_input := "ui_accept"

# Combate
@export var bullet_modifier: BulletModifier = null
@export var max_health := 100
var current_health: int
var can_shoot: bool = true

# Estado
var frozen := false   # True durante countdown — bloquea movimiento, rotación y disparo
var shield: int = 0   # Escudo temporal (absorbe daño antes de la vida)

# Referencias a la barra de vida
@onready var health_bar = $HealthBarPivot/HealthBar
@onready var health_bar_pivot = $HealthBarPivot

func _ready():
	# El nombre se hereda del nodo en main.tscn (Player1, Player2...)
	add_to_group("players")
	current_health = max_health
	# Inicializar barra de vida
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func _physics_process(delta):
	# Si está congelado (countdown), no procesar input
	if not frozen:
		# === MOVIMIENTO ===
		var direction = Vector2.ZERO
		if Input.is_action_pressed(right_input):
			direction.x += 1
		if Input.is_action_pressed(left_input):
			direction.x -= 1
		if Input.is_action_pressed(down_input):
			direction.y += 1
		if Input.is_action_pressed(up_input):
			direction.y -= 1

		direction = direction.normalized()
		velocity = direction * speed
		move_and_slide()

		# === APUNTADO ===
		var mouse_position = get_global_mouse_position()
		var direction_to_mouse = mouse_position - global_position
		rotation = direction_to_mouse.angle()

		# === DISPARO ===
		if Input.is_action_just_pressed(shoot_input):
			shoot()
	
	# La barra de vida siempre se mantiene horizontal (incluso congelado)
	if health_bar_pivot:
		health_bar_pivot.rotation = -rotation

func shoot():
	if not can_shoot:
		return
	if bullet_scene == null:
		print("ERROR: bullet_scene no asignada")
		return
	
	can_shoot = false
	
	# Soporte multi-bala (shotgun) y ángulo de dispersión
	var count = bullet_modifier.bullet_count if bullet_modifier else 1
	var spread = deg_to_rad(bullet_modifier.spread_angle if bullet_modifier else 0.0)
	var base_dir = (get_global_mouse_position() - $Muzzle.global_position).normalized()
	
	for i in count:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = $Muzzle.global_position
		
		# Calcular dirección con dispersión
		if count > 1 and spread > 0:
			var angle_offset = lerp(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
			bullet.direction = base_dir.rotated(angle_offset)
		else:
			bullet.direction = base_dir
		
		bullet.shooter = self
		if bullet_modifier:
			bullet.modifier = bullet_modifier
		get_parent().add_child(bullet)
	
	# Cooldown del modificador (default 0.5s)
	var cd = bullet_modifier.cooldown if bullet_modifier else 0.5
	await get_tree().create_timer(cd).timeout
	can_shoot = true

func take_damage(amount: int):
	# El escudo absorbe daño primero
	if shield > 0:
		var absorbed = min(shield, amount)
		shield -= absorbed
		amount -= absorbed
		print(name, " escudo absorbe ", absorbed, " (restante: ", shield, ")")
		if amount <= 0:
			_flash_damage()
			return
	
	current_health -= amount
	print(name, " vida:", current_health)
	# Actualizar barra de vida
	if health_bar:
		health_bar.value = current_health
	# Flash rojo de daño
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
