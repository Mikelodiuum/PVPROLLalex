extends Area2D

## Proyectil base. Se mueve en línea recta, aplica daño, soporta penetración.
## Se destruye al golpear paredes o al agotar pierce/lifetime.
## Soporte para: lifesteal, veneno (DoT), atravesar paredes, ejecución.

var direction      := Vector2.ZERO
var shooter: Node  = null
var modifier: BulletModifier = null

var hit_particles_scene = preload("res://scenes/combat/weapons/basic/hit_particles.tscn")

var damage: int       = 20
var pierce: int       = 1
var pierce_count: int = 0
var hit_targets: Array = []

# Propiedades de habilidades pasadas desde player.gd (via modifier o directamente)
var pierce_walls: bool        = false   ## Si true, atraviesa paredes (con -50% daño)
var damage_on_tick: int       = 0       ## Daño de veneno por tick
var tick_duration: float      = 0.0    ## Duración del veneno (s)
var execute_bonus: int        = 0       ## Daño extra si el objetivo tiene ≤ execute_threshold HP
var execute_threshold: int    = 0       ## HP máximo para activar ejecución
var _wall_pierced: bool       = false   ## Para reducir daño solo la primera vez que pasa la pared

func _ready():
	if modifier:
		damage           = modifier.damage
		pierce           = modifier.pierce
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
			if pierce_walls:
				# Atraviesa la pared pero reduce daño al 50% (solo una vez)
				if not _wall_pierced:
					_wall_pierced = true
					damage = max(1, damage / 2)
			else:
				_spawn_hit_particles()
				queue_free()
				return
		if body != shooter and body.has_method("take_damage") and not hit_targets.has(body):
			hit_targets.append(body)
			var actual_damage = damage
			# Ejecución: daño extra si el enemigo tiene pocos HP
			if execute_bonus > 0 and execute_threshold > 0:
				if body.has_method("get") and body.get("current_health") != null:
					if body.current_health <= execute_threshold:
						actual_damage += execute_bonus
			body.take_damage(actual_damage)
			# Lifesteal: notificar al que disparó
			if shooter and shooter.has_method("on_damage_dealt"):
				shooter.on_damage_dealt(actual_damage)
			# Veneno (DoT): aplicar ticks de daño
			if damage_on_tick > 0 and tick_duration > 0.0:
				_apply_poison(body)
			pierce_count += 1
			if pierce_count >= pierce:
				_spawn_hit_particles()
				queue_free()
				return

## Aplica veneno al objetivo: ticks de daño a lo largo de tick_duration segundos
func _apply_poison(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var ticks     := int(tick_duration)
	var dmg_tick  := damage_on_tick
	# Usamos un coroutine simple: un tick por segundo
	for _i in ticks:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			return
		if target.has_method("take_damage"):
			target.take_damage(dmg_tick)

func _spawn_hit_particles():
	if hit_particles_scene:
		var particles = hit_particles_scene.instantiate()
		particles.global_position = global_position
		particles.color = modifier.color if modifier else Color.WHITE
		get_parent().add_child(particles)
