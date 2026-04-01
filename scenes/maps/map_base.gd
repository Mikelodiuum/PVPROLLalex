extends Node2D
class_name MapBase

## MapBase — Clase base para TODOS los mapas nuevos del juego.
##
## A diferencia de BaseArena (procedural), aquí las paredes, suelos y
## decoración se colocan directamente en el editor de Godot (editor visual).
##
## ¿Cómo crear un nuevo mapa?
##   1. Crea una nueva escena (Scene > New Scene)
##   2. Pon un nodo raíz Node2D y asígnale este script (map_base.gd)
##   3. Añade tus paredes como nodos StaticBody2D + CollisionShape2D en el editor
##   4. Añade Marker2D con nombres: SpawnP1, SpawnP2, PickupSpawn1, PickupSpawn2...
##   5. Ajusta map_size para que coincida con el tamaño visual de tu mapa
##   6. Referencia la escena en main.tscn (reemplaza el nodo Arena)
##
## IMPORTANTE: Asegúrate de que los StaticBody2D de paredes usen:
##   collision_layer = 4  (capa 3 = paredes)
##   y estén en el grupo "walls"

# ============================================================
# CONFIGURACIÓN (ajusta desde el Inspector o en la propia escena)
# ============================================================

@export_group("Mapa")
@export var map_size := Vector2(3456, 1944)       ## Tamaño TOTAL del mapa en píxeles
@export var background_color := Color(0.09, 0.10, 0.13)  ## Color de fondo del mapa

@export_group("Paredes Perimetrales (Auto)")
@export var auto_perimeter := true                ## true = genera paredes en los bordes
@export var wall_thickness  := 32.0              ## Grosor de las paredes del borde
@export var wall_color       := Color(0.25, 0.28, 0.38)
@export var wall_border_color := Color(0.40, 0.45, 0.58)

# ============================================================
# DATOS INTERNOS
# ============================================================
var player_spawn_points: Array = []
var pickup_spawn_points : Array = []
var _perimeter_rects: Array = []   # Solo para dibujado de las paredes auto

func _ready():
	add_to_group("arena")
	if auto_perimeter:
		_create_perimeter_walls()
	_collect_spawn_points()
	queue_redraw()

# ============================================================
# SPAWN POINTS — recoge automáticamente los Marker2D del editor
# ============================================================
func _collect_spawn_points():
	player_spawn_points.clear()
	pickup_spawn_points.clear()
	for child in get_children():
		if child is Marker2D:
			if child.name.begins_with("SpawnP"):
				player_spawn_points.append(child.global_position)
			elif child.name.begins_with("PickupSpawn"):
				pickup_spawn_points.append(child.global_position)

# ============================================================
# API PÚBLICA (compatible con GameManager)
# ============================================================
func get_player_spawn(index: int) -> Vector2:
	if index < player_spawn_points.size():
		return player_spawn_points[index]
	# Fallback: lados opuestos
	return Vector2(300.0 + index * (map_size.x - 600.0), map_size.y / 2.0)

func get_random_pickup_spawn() -> Vector2:
	if pickup_spawn_points.size() > 0:
		return pickup_spawn_points.pick_random()
	return map_size / 2.0

func get_all_pickup_spawns() -> Array:
	return pickup_spawn_points.duplicate()

## Devuelve los límites del mapa (usado por la Camera2D del jugador)
func get_map_bounds() -> Rect2:
	return Rect2(global_position, map_size)

# ============================================================
# PAREDES PERIMETRALES AUTOMÁTICAS
# ============================================================
func _create_perimeter_walls():
	var t = wall_thickness
	var s = map_size
	var edges = [
		Rect2(0,       0,       s.x, t),       # Arriba
		Rect2(0,       s.y - t, s.x, t),       # Abajo
		Rect2(0,       0,       t,   s.y),      # Izquierda
		Rect2(s.x - t, 0,       t,   s.y),     # Derecha
	]
	for rect in edges:
		_perimeter_rects.append(rect)
		var body = StaticBody2D.new()
		body.position = rect.position + rect.size / 2.0
		body.collision_layer = 4
		body.collision_mask  = 0
		body.add_to_group("walls")
		var shape = RectangleShape2D.new()
		shape.size = rect.size
		var col = CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)
		add_child(body)

# ============================================================
# DIBUJADO PLACEHOLDER
# (Se irá sustituyendo por TileMap o Sprites cuando haya arte)
# ============================================================
func _draw():
	# Fondo completo
	draw_rect(Rect2(Vector2.ZERO, map_size), background_color)

	# Paredes perimetrales auto (si las hay)
	for rect in _perimeter_rects:
		draw_rect(rect, wall_color)
		draw_rect(rect, wall_border_color, false, 2.0)
