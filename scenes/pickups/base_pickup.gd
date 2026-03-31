extends Area2D
class_name BasePickup

## Clase base para todos los pickups del mapa.
## Extiende Area2D con animación flotante, placeholder visual y detección de jugadores.
## Para crear un nuevo pickup: extender esta clase y override apply_effect(player).
##
## collision_layer = 8 (layer 4: pickups)
## collision_mask  = 1 (layer 1: jugadores)

signal picked_up(pickup_type: String, player: Node)

# === CONFIGURACIÓN VISUAL (editable en Inspector) ===
@export_group("Identidad")
@export var pickup_name := "Pickup"
@export var pickup_color := Color.WHITE
@export var pickup_icon_color := Color(1, 1, 1, 0.9)

@export_group("Animación")
@export var float_amplitude := 4.0        ## Pixeles de oscilación arriba/abajo
@export var float_speed := 2.5            ## Velocidad de oscilación
@export var spawn_anim_duration := 0.5    ## Duración animación de aparición (s)
@export var collect_anim_duration := 0.2  ## Duración animación de recogida (s)

@export_group("Colisión")
@export var collision_radius := 18.0      ## Radio de detección del jugador

# === DATOS INTERNOS ===
var _float_time := 0.0
var _base_y := 0.0
var _is_collected := false

func _ready():
	add_to_group("pickups")
	
	# === COLLISION ===
	collision_layer = 8   # Layer 4: Pickups
	collision_mask = 1    # Layer 1: Jugadores
	
	# === COLLISION SHAPE ===
	var shape = CircleShape2D.new()
	shape.radius = collision_radius
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	# Guardar posición base para la flotación
	_base_y = position.y
	
	# Randomizar la fase de flotación para que no todos se muevan sincronizados
	_float_time = randf() * TAU
	
	# Conectar señal de detección
	body_entered.connect(_on_body_entered)
	
	# Animación de aparición (scale de 0 → 1)
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2.ONE, spawn_anim_duration)

func _process(delta):
	if _is_collected:
		return
	
	# === ANIMACIÓN FLOTANTE ===
	_float_time += delta * float_speed
	position.y = _base_y + sin(_float_time) * float_amplitude
	
	# Redibujado para animación de glow
	queue_redraw()

func _on_body_entered(body):
	if _is_collected:
		return
	if body.is_in_group("players"):
		_is_collected = true
		apply_effect(body)
		picked_up.emit(pickup_name, body)
		# Animación de recogida (scale → 0 y desaparece)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "scale", Vector2.ZERO, collect_anim_duration)
		tween.tween_callback(queue_free)

## Override en subclases para aplicar el efecto del pickup
func apply_effect(_player):
	pass

# === PLACEHOLDER VISUAL ===
func _draw():
	# Círculo exterior (glow pulsante)
	var glow_color = pickup_color
	glow_color.a = 0.15 + sin(_float_time * 1.5) * 0.05
	draw_circle(Vector2.ZERO, 22.0, glow_color)
	
	# Círculo principal
	draw_circle(Vector2.ZERO, 14.0, pickup_color)
	
	# Círculo interior más claro (brillo)
	var bright = pickup_color.lightened(0.4)
	bright.a = 0.8
	draw_circle(Vector2(-3, -3), 6.0, bright)
	
	# Borde
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 32, pickup_color.darkened(0.3), 1.5)
	
	# Icono del tipo (override _draw_icon en subclases)
	_draw_icon()

## Override en subclases para dibujar un icono específico
func _draw_icon():
	pass
