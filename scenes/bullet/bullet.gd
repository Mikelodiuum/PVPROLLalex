extends CharacterBody2D

@export var speed := 650.0
var direction := Vector2.ZERO
var shooter: Node = null  # referencia del jugador que disparó

func _physics_process(delta):
	velocity = direction * speed
	move_and_slide()

	for i in range(get_slide_collision_count()):
		var collider = get_slide_collision(i).get_collider()
		if collider != shooter and collider.has_method("take_damage"):
			collider.take_damage(20)
			queue_free()
			break
