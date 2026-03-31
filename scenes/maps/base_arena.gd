extends Node2D
class_name BaseArena

## Clase base para todas las arenas del juego.
## Define la interfaz para crear paredes, gestionar spawn points y dibujar placeholders.
## Para crear un mapa nuevo:
##   1. Crear un .gd que extienda BaseArena
##   2. Override _setup_arena() para definir paredes con add_wall()
##   3. Crear un .tscn con Marker2D para spawn points (SpawnP1, SpawnP2, PickupSpawn...)

# === COLORES PLACEHOLDER (fáciles de cambiar cuando haya sprites) ===
@export var background_color := Color(0.11, 0.12, 0.15)
@export var wall_color := Color(0.28, 0.32, 0.40)
@export var wall_border_color := Color(0.38, 0.42, 0.52)

# === DATOS INTERNOS ===
var _wall_rects: Array = []    # Array de Rect2 para dibujar
var _arena_size := Vector2(1152, 648)

# Spawn points (recogidos automáticamente de los Marker2D hijos)
var player_spawn_points: Array = []
var pickup_spawn_points: Array = []

func _ready():
	add_to_group("arena")
	_setup_arena()
	_collect_spawn_points()
	queue_redraw()

# Override en subclases para definir el layout del mapa
func _setup_arena():
	pass

func _collect_spawn_points():
	for child in get_children():
		if child is Marker2D:
			if child.name.begins_with("SpawnP"):
				player_spawn_points.append(child.global_position)
			elif child.name.begins_with("PickupSpawn"):
				pickup_spawn_points.append(child.global_position)

# === API PARA CREAR PAREDES ===

func add_wall(rect: Rect2):
	_wall_rects.append(rect)
	
	var body = StaticBody2D.new()
	# Posicionar en el centro del rectángulo
	body.position = rect.position + rect.size / 2.0
	# Layer 3 = bit 2 = valor 4 (paredes)
	body.collision_layer = 4
	body.collision_mask = 0
	body.add_to_group("walls")
	
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	var col = CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

# === API PARA SPAWN POINTS ===

func get_player_spawn(index: int) -> Vector2:
	if index < player_spawn_points.size():
		return player_spawn_points[index]
	# Fallback: posiciones por defecto
	return Vector2(200 + index * 600, _arena_size.y / 2.0)

func get_random_pickup_spawn() -> Vector2:
	if pickup_spawn_points.size() > 0:
		return pickup_spawn_points.pick_random()
	return _arena_size / 2.0

func get_all_pickup_spawns() -> Array:
	return pickup_spawn_points.duplicate()

# === DIBUJADO PLACEHOLDER ===
# TODO: Reemplazar con TileMap/Sprites cuando haya arte

func _draw():
	# Fondo
	draw_rect(Rect2(Vector2.ZERO, _arena_size), background_color)
	
	# Paredes con borde sutil
	for rect in _wall_rects:
		draw_rect(rect, wall_color)
		# Borde superior/izquierdo más claro (efecto 3D simple)
		draw_rect(rect, wall_border_color, false, 2.0)
