extends CPUParticles2D

## Partículas de impacto (chispas). Se autodescargan cuando terminan.

func _ready():
	emitting = true
	# Free el nodo cuando termine
	await get_tree().create_timer(lifetime + 0.1).timeout
	queue_free()
