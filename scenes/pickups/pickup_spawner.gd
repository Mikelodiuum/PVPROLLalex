extends Node
class_name PickupSpawner

## Gestiona el spawn y respawn de pickups en los puntos del mapa.
## Se crea dinámicamente por GameManager al inicio de cada ronda.
## Todos los tiempos son configurables desde el Inspector.

# Scripts de los tipos de pickup disponibles
var pickup_types := [
	preload("res://scenes/pickups/pickup_speed.gd"),
	preload("res://scenes/pickups/pickup_heal.gd"),
	preload("res://scenes/pickups/pickup_shield.gd"),
]

@export_group("Timing")
@export var respawn_time := 8.0           ## Segundos hasta que respawnee un pickup recogido
@export var initial_spawn_delay := 0.0    ## Delay inicial antes del primer spawn (s)
@export var stagger_delay := 0.15         ## Delay entre spawns escalonados (s)
@export var spawn_on_setup := true        ## Si spawnar automáticamente al inicializar

# === DATOS INTERNOS ===
var spawn_points: Array = []
var active_pickups: Dictionary = {}   # spawn_index → pickup_node
var _arena: Node = null

## Inicializa el spawner con los puntos de spawn de la arena
func setup(points: Array, arena: Node):
	spawn_points = points
	_arena = arena
	if spawn_on_setup:
		if initial_spawn_delay > 0:
			await get_tree().create_timer(initial_spawn_delay).timeout
		spawn_all()

## Spawna un pickup aleatorio en cada punto
func spawn_all():
	for i in spawn_points.size():
		if i > 0 and stagger_delay > 0:
			await get_tree().create_timer(stagger_delay).timeout
		spawn_at(i)

## Spawna un pickup en un punto específico
func spawn_at(index: int):
	if index >= spawn_points.size():
		return
	
	# Si ya hay un pickup activo en este punto, no hacer nada
	if active_pickups.has(index) and is_instance_valid(active_pickups[index]):
		return
	
	# Elegir tipo aleatorio
	var pickup_script = pickup_types.pick_random()
	
	# Crear el pickup como Area2D con el script asignado
	var pickup = Area2D.new()
	pickup.set_script(pickup_script)
	pickup.position = spawn_points[index]
	
	# Conectar la señal de recogida
	pickup.picked_up.connect(_on_pickup_collected.bind(index))
	
	# Añadirlo al árbol como hijo de la arena
	_arena.add_child(pickup)
	active_pickups[index] = pickup

## Cuando un pickup es recogido: espera y respawnea otro
func _on_pickup_collected(_type: String, _player: Node, index: int):
	active_pickups.erase(index)
	
	# Esperar respawn_time y spawnear uno nuevo
	await get_tree().create_timer(respawn_time).timeout
	
	# Solo respawnear si el spawner sigue activo (la ronda no ha terminado)
	if is_inside_tree():
		spawn_at(index)

## Limpia todos los pickups activos (llamado al final de ronda)
func cleanup():
	for index in active_pickups:
		var pickup = active_pickups[index]
		if is_instance_valid(pickup):
			pickup.queue_free()
	active_pickups.clear()
