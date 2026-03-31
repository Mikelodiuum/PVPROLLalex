extends BasePickup

## Pickup de Speed Boost: aumenta la velocidad de movimiento temporalmente.
## Todos los valores son configurables desde el Inspector.

@export_group("Efecto")
@export var boost_duration := 5.0                       ## Duración del boost (s)
@export var speed_multiplier := 1.5                     ## Multiplicador (1.5 = +50%)
@export var effect_color := Color(0.3, 0.85, 1.0)      ## Tinte visual del jugador

func _ready():
	pickup_name = "Speed Boost"
	pickup_color = Color(0.1, 0.85, 1.0)
	pickup_icon_color = Color(0.6, 0.95, 1.0)
	super._ready()

func apply_effect(player):
	var original_speed = player.speed
	
	# Aplicar boost
	player.speed *= speed_multiplier
	
	# Efecto visual: tinte cian en el sprite
	if player.has_node("Sprite2D"):
		player.get_node("Sprite2D").modulate = effect_color
	
	# Timer para revertir
	var timer = get_tree().create_timer(boost_duration)
	timer.timeout.connect(func():
		if is_instance_valid(player):
			player.speed = original_speed
			if player.has_node("Sprite2D"):
				var current_mod = player.get_node("Sprite2D").modulate
				if current_mod.b > 0.8:
					player.get_node("Sprite2D").modulate = Color.WHITE
	)
	
	print(player.name, " → Speed Boost! (", boost_duration, "s, x", speed_multiplier, ")")

func _draw_icon():
	var icon_color = Color(1, 1, 1, 0.85)
	# Flecha 1
	draw_line(Vector2(-5, -3), Vector2(0, 0), icon_color, 2.0)
	draw_line(Vector2(0, 0), Vector2(-5, 3), icon_color, 2.0)
	# Flecha 2
	draw_line(Vector2(0, -3), Vector2(5, 0), icon_color, 2.0)
	draw_line(Vector2(5, 0), Vector2(0, 3), icon_color, 2.0)
