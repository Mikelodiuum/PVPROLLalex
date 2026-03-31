extends Area2D

## Proyectil base. Se mueve en línea recta, aplica daño, soporta penetración.
## Se destruye al golpear paredes o al agotar pierce/lifetime.

var direction      := Vector2.ZERO
var shooter: Node  = null
var modifier: BulletModifier = null

var hit_particles_scene = preload("res://scenes/combat/weapons/basic/hit_particles.tscn")

var damage: int      = 20
var pierce: int      = 1
var pierce_count: int = 0
var hit_targets: Array = []

func _ready():
	if modifier:
		damage = modifier.damage
		pierce = modifier.pierce
		if has_node("Sprite2D"):
			$Sprite2D.modulate  = modifier.color
			$Sprite2D.rotation  = direction.angle()
		scale = Vector2(modifier.scale, modifier.scale)
		await get_tree().create_timer(modifier.lifetime).timeout
		queue_free()
	else:
		await get_tree().create_timer(3.0).timeout
		queue_free()

func _physics_process(delta):
	position += direction * (modifier.speed if modifier else 650.0) * delta

	var overlapping = get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("walls"):
			_spawn_hit_particles()
			queue_free()
			return
		if body != shooter and body.has_method("take_damage") and not hit_targets.has(body):
			hit_targets.append(body)
			body.take_damage(damage)
			# === LIFESTEAL: notificar al que disparó ===
			if shooter and shooter.has_method("on_damage_dealt"):
				shooter.on_damage_dealt(damage)
			pierce_count += 1
			if pierce_count >= pierce:
				_spawn_hit_particles()
				queue_free()
				return

func _spawn_hit_particles():
	if hit_particles_scene:
		var particles = hit_particles_scene.instantiate()
		particles.global_position = global_position
		particles.color = modifier.color if modifier else Color.WHITE
		get_parent().add_child(particles)
