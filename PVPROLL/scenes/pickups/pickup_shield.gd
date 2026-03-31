extends BasePickup

## Pickup de Shield: otorga escudo temporal que absorbe daño.
## Todos los valores son configurables desde el Inspector.

@export_group("Efecto")
@export var shield_amount := 40                        ## Puntos de escudo
@export var shield_duration := 6.0                      ## Duración del escudo (s)
@export var effect_color := Color(0.7, 0.4, 1.0)      ## Tinte visual del jugador

func _ready():
	pickup_name = "Shield"
	pickup_color = Color(0.6, 0.25, 0.95)
	pickup_icon_color = Color(0.75, 0.5, 1.0)
	super._ready()

func apply_effect(player):
	# Aplicar escudo
	player.shield = shield_amount
	
	# Efecto visual: tinte morado
	if player.has_node("Sprite2D"):
		player.get_node("Sprite2D").modulate = effect_color
	
	# Timer para quitar escudo
	var timer = get_tree().create_timer(shield_duration)
	timer.timeout.connect(func():
		if is_instance_valid(player):
			player.shield = 0
			if player.has_node("Sprite2D"):
				var current_mod = player.get_node("Sprite2D").modulate
				if current_mod.r < 0.8 and current_mod.b > 0.8:
					player.get_node("Sprite2D").modulate = Color.WHITE
	)
	
	print(player.name, " → Shield! ", shield_amount, " puntos (", shield_duration, "s)")

func _draw_icon():
	var icon_color = Color(1, 1, 1, 0.85)
	var points = PackedVector2Array([
		Vector2(0, -6), Vector2(5, -2), Vector2(5, 2),
		Vector2(0, 6), Vector2(-5, 2), Vector2(-5, -2),
	])
	draw_polyline(points, icon_color, 1.5)
	draw_line(points[-1], points[0], icon_color, 1.5)
