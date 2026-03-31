extends Area2D

## Proyectil base. Se mueve en línea recta, aplica daño, soporta penetración.
## Se destruye al golpear paredes o al agotar pierce/lifetime.

var direction := Vector2.ZERO
var shooter: Node = null
var modifier: BulletModifier = null

var hit_particles_scene = preload("res://scenes/combat/weapons/basic/hit_particles.tscn")


var damage: int = 20
var pierce: int = 1
var pierce_count: int = 0
var hit_targets: Array = []   # Evita dañar dos veces al mismo

func _ready():
	if modifier:
		damage = modifier.damage
		pierce = modifier.pierce
		
		if has_node("Sprite2D"):
			$Sprite2D.modulate = modifier.color
			$Sprite2D.rotation = direction.angle()
		
		scale = Vector2(modifier.scale, modifier.scale)
		
		# Temporizador de vida
		await get_tree().create_timer(modifier.lifetime).timeout
		queue_free()
	else:
		await get_tree().create_timer(3.0).timeout
		queue_free()

func _physics_process(delta):
	# Movimiento manual
	position += direction * (modifier.speed if modifier else 650.0) * delta
	
	# Detectar colisiones
	var overlapping = get_overlapping_bodies()
	for body in overlapping:
		# Destruir al golpear una pared (sin importar pierce)
		if body.is_in_group("walls"):
			_spawn_hit_particles()
			queue_free()
			return
		# Aplicar daño a jugadores/entidades
		if body != shooter and body.has_method("take_damage") and not hit_targets.has(body):
			hit_targets.append(body)
			body.take_damage(damage)
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
