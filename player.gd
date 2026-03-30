extends CharacterBody2D

@export var bullet_scene: PackedScene
@export var speed := 300.0

@export var up_input := "ui_up"
@export var down_input := "ui_down"
@export var left_input := "ui_left"
@export var right_input := "ui_right"
@export var shoot_input := "ui_accept"

@export var max_health := 100
var current_health := max_health

func _physics_process(delta):
	var direction = Vector2.ZERO

	if Input.is_action_pressed(right_input):
		direction.x += 1
	if Input.is_action_pressed(left_input):
		direction.x -= 1
	if Input.is_action_pressed(down_input):
		direction.y += 1
	if Input.is_action_pressed(up_input):
		direction.y -= 1

	direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()

	var mouse_position = get_global_mouse_position()
	var direction_to_mouse = mouse_position - global_position
	rotation = direction_to_mouse.angle()

	if Input.is_action_just_pressed(shoot_input):
		shoot()

func shoot():
	if bullet_scene == null:
		print("ERROR: bullet_scene no asignada")
		return

	var bullet = bullet_scene.instantiate()
	bullet.global_position = $Muzzle.global_position
	bullet.direction = (get_global_mouse_position() - bullet.global_position).normalized()
	bullet.shooter = self
	get_parent().add_child(bullet)

func take_damage(amount: int):
	current_health -= amount
	print(name, "vida:", current_health)
	if current_health <= 0:
		die()

func _ready():
	name = "Player1" 
	add_to_group("players")

func die():
	print(name, "muerto")
	queue_free()
