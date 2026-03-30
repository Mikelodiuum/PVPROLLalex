extends Area2D

var direction := Vector2.ZERO
var shooter: Node = null
var modifier: BulletModifier = null

var damage: int = 20
var pierce: int = 1
var pierce_count: int = 0
var hit_targets: Array = []   # Evita dañar dos veces al mismo

func _ready():
	if modifier:
		print("Aplicando modifier: velocidad=", modifier.speed, " daño=", modifier.damage)
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
		print("Sin modifier, velocidad por defecto 650")
		await get_tree().create_timer(3.0).timeout
		queue_free()

func _physics_process(delta):
	# Movimiento manual
	position += direction * (modifier.speed if modifier else 650.0) * delta
	
	# Detectar colisiones
	var overlapping = get_overlapping_bodies()
	for body in overlapping:
		if body != shooter and body.has_method("take_damage") and not hit_targets.has(body):
			hit_targets.append(body)
			body.take_damage(damage)
			pierce_count += 1
			if pierce_count >= pierce:
				queue_free()
				return
