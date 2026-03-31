extends BasePickup

## Pickup de Heal: restaura HP instantáneamente (sin sobrepasar max_health).
## Todos los valores son configurables desde el Inspector.

@export_group("Efecto")
@export var heal_amount := 30                          ## HP a restaurar
@export var effect_color := Color(0.2, 1.0, 0.3)      ## Color del flash de curación
@export var flash_duration := 0.4                       ## Duración del flash (s)

func _ready():
	pickup_name = "Heal"
	pickup_color = Color(0.15, 0.9, 0.3)
	pickup_icon_color = Color(0.5, 1.0, 0.6)
	super._ready()

func apply_effect(player):
	var old_health = player.current_health
	
	# Curar sin sobrepasar max_health
	player.current_health = min(player.current_health + heal_amount, player.max_health)
	var actual_heal = player.current_health - old_health
	
	# Actualizar barra de vida
	if player.health_bar:
		player.health_bar.value = player.current_health
	
	# Flash verde de curación
	if player.has_node("Sprite2D"):
		player.get_node("Sprite2D").modulate = effect_color
		var tween = player.create_tween()
		tween.tween_property(player.get_node("Sprite2D"), "modulate", Color.WHITE, flash_duration)
	
	print(player.name, " → Heal! +", actual_heal, " HP (", player.current_health, "/", player.max_health, ")")

func _draw_icon():
	var icon_color = Color(1, 1, 1, 0.85)
	draw_line(Vector2(0, -5), Vector2(0, 5), icon_color, 2.5)
	draw_line(Vector2(-5, 0), Vector2(5, 0), icon_color, 2.5)
