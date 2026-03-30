extends CharacterBody2D
@export var bullet_scene: PackedScene
#permite:asignar la escena desde el editor/desacoplar código de recursos
@export var speed := 300.0
#velocidad definida del personaje
@export var max_health := 100
var current_health := max_health

func _physics_process(delta):
	var direction = Vector2.ZERO

	if Input.is_action_pressed("ui_right_p2"):
		direction.x += 1
	if Input.is_action_pressed("ui_left_p2"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down_p2"):
		direction.y += 1
	if Input.is_action_pressed("ui_up_p2"):
		direction.y -= 1

	direction = direction.normalized()
	#esto se encarga de que la velocidad en las diagonales sea la misma que en las recta (.normalized)
	velocity = direction * speed
	move_and_slide()
	#creo que eso ultimo es lo encargado de que todo lo anterior pase
	
	var mouse_position = get_global_mouse_position()
	var direction_to_mouse = mouse_position - global_position
	rotation = direction_to_mouse.angle()
	#esto se encarga de ver donde mira el pj donde esta el cursor calcular el ángulo de diferencia y rotar al pj ese ángulo para que mire al cursor
	if Input.is_action_just_pressed("ui_accept_p2"):
		shoot()
	#cuando usas el uiaccept realiza la función shoot
func shoot():
	var bullet = bullet_scene.instantiate()
	bullet.global_position = $Muzzle.global_position
	bullet.direction = (get_global_mouse_position() - bullet.global_position).normalized()
	bullet.shooter = self  # importante: la bala “recuerda” quién disparó
	get_parent().add_child(bullet)

func take_damage(amount: int):
	current_health -= amount
	print("Vida actual:", current_health)
	if current_health <= 0:
		die()

func _ready():
	name = "Player2"
	add_to_group("players")

func die():
	print("Player muerto")
	queue_free() # eliminar el jugador, luego lo manejaremos en el sistema de rondas
