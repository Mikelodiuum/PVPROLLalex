extends Area2D

## Proyectil base. Se mueve en línea recta, aplica daño, soporta penetración.
## Lee propiedades especiales de modifier (calculadas por player.gd):
##   - bullets_pierce_walls → atraviesa paredes con -50% daño (una vez)
##   - double_shot_chance   → probabilidad de doble daño por bala
##   - execute_bonus_damage → daño extra si objetivo tiene <= execute_threshold HP
##   - damage_on_tick       → veneno: daño por tick durante tick_duration segundos

var direction := Vector2.ZERO
var shooter: Node = null
var modifier: BulletModifier = null

var hit_particles_scene = preload("res://scenes/combat/weapons/basic/hit_particles.tscn")

<<<<<<< Updated upstream

var damage: int = 20
var pierce: int = 1
=======
var damage: int       = 20
var pierce: int       = 1
>>>>>>> Stashed changes
var pierce_count: int = 0
var hit_targets: Array = []   # Evita dañar dos veces al mismo

# Fantasma: la bala sólo puede halvar el daño por pared una vez
var _wall_pierced: bool = false

func _ready():
	if modifier:
		damage = modifier.damage
		pierce = modifier.pierce
		
		if has_node("Sprite2D"):
			$Sprite2D.modulate = modifier.color
			$Sprite2D.rotation = direction.angle()
<<<<<<< Updated upstream
		
=======
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
		# Destruir al golpear una pared (sin importar pierce)
		if body.is_in_group("walls"):
			_spawn_hit_particles()
			queue_free()
			return
		# Aplicar daño a jugadores/entidades
		if body != shooter and body.has_method("take_damage") and not hit_targets.has(body):
			hit_targets.append(body)
			body.take_damage(damage)
=======

		# === PAREDES ===
		if body.is_in_group("walls"):
			if modifier and modifier.bullets_pierce_walls and not _wall_pierced:
				# Fantasma: atraviesa la pared pero pierde el 50% del daño
				_wall_pierced = true
				damage = max(1, damage / 2)
			elif not (modifier and modifier.bullets_pierce_walls):
				# Bala normal: se destruye al tocar pared
				_spawn_hit_particles()
				queue_free()
				return

		# === IMPACTO EN JUGADOR ===
		if body != shooter and body.has_method("take_damage") and not hit_targets.has(body):
			hit_targets.append(body)

			var final_damage = damage

			# --- Ejecución: daño bonus si el objetivo está bajo de vida ---
			if modifier and modifier.execute_threshold > 0 and modifier.execute_bonus_damage > 0:
				if "current_health" in body and body.current_health <= modifier.execute_threshold:
					final_damage += modifier.execute_bonus_damage

			# --- Azar: 25% de probabilidad de doble daño por bala ---
			if modifier and modifier.double_shot_chance > 0:
				if randf() < modifier.double_shot_chance:
					final_damage *= 2

			body.take_damage(final_damage)

			# --- Lifesteal: notificar al que disparó ---
			if shooter and shooter.has_method("on_damage_dealt"):
				shooter.on_damage_dealt(final_damage)

			# --- Veneno: delegar al objetivo para que maneje su propio timer ---
			if modifier and modifier.damage_on_tick > 0 and modifier.tick_duration > 0:
				if body.has_method("apply_poison"):
					body.apply_poison(modifier.damage_on_tick, int(modifier.tick_duration))

>>>>>>> Stashed changes
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
