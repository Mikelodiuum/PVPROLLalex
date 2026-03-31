extends Node2D
class_name BaseArena

## Clase base para todas las arenas del juego.
## Define la interfaz para crear paredes, gestionar spawn points y dibujar placeholders.
##
## Para crear un mapa nuevo:
##   1. Crear un .gd que extienda BaseArena
##   2. Override _setup_arena() y usar los helpers (add_symmetric_pillars, add_cover, etc.)
##   3. Crear un .tscn con Marker2D para spawn points (SpawnP1, SpawnP2, PickupSpawn...)
##   4. Si auto_perimeter = true, las paredes del borde se crean solas
##
## Ejemplo mínimo (el .gd):
##   extends BaseArena
##   func _setup_arena():
##       add_symmetric_pillars(200, 150, 40)
##       add_cover(arena_size / 2, 80, 15)

# === DIMENSIONES (editable en Inspector) ===
@export_group("Dimensiones")
@export var arena_size := Vector2(1152, 648)     ## Tamaño total de la arena en pixeles
@export var wall_thickness := 16.0               ## Grosor de las paredes perimetrales

# === COLORES PLACEHOLDER ===
@export_group("Colores Placeholder")
@export var background_color := Color(0.11, 0.12, 0.15)
@export var wall_color := Color(0.28, 0.32, 0.40)
@export var wall_border_color := Color(0.38, 0.42, 0.52)
@export var obstacle_color := Color(0.35, 0.38, 0.48)   ## Color para obstáculos internos

# === OPCIONES ===
@export_group("Opciones")
@export var auto_perimeter := true     ## Crear paredes perimetrales automáticamente
@export var draw_debug_grid := false   ## Dibujar grid de referencia (debug)
@export var grid_spacing := 50.0       ## Espaciado del grid de debug

# === DATOS INTERNOS ===
var _wall_rects: Array = []
var _obstacle_rects: Array = []   # Separados para poder colorearlos diferente

# Spawn points (recogidos automáticamente de los Marker2D hijos)
var player_spawn_points: Array = []
var pickup_spawn_points: Array = []

func _ready():
	add_to_group("arena")
	if auto_perimeter:
		_add_perimeter_walls()
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

# ============================================
# API PARA CREAR PAREDES (bajo nivel)
# ============================================

## Añade una pared (StaticBody2D) con la posición y tamaño indicados
func add_wall(rect: Rect2, is_obstacle := false):
	if is_obstacle:
		_obstacle_rects.append(rect)
	else:
		_wall_rects.append(rect)
	
	var body = StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	body.collision_layer = 4     # Layer 3 = paredes
	body.collision_mask = 0
	body.add_to_group("walls")
	
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	var col = CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

# ============================================
# HELPERS PARA CREAR MAPAS RÁPIDO
# ============================================

## Crea las 4 paredes perimetrales (llamado automáticamente si auto_perimeter = true)
func _add_perimeter_walls():
	var t = wall_thickness
	var s = arena_size
	add_wall(Rect2(0, 0, s.x, t))                   # Arriba
	add_wall(Rect2(0, s.y - t, s.x, t))             # Abajo
	add_wall(Rect2(0, 0, t, s.y))                    # Izquierda
	add_wall(Rect2(s.x - t, 0, t, s.y))             # Derecha

## Crea un pilar cuadrado centrado en la posición dada
func add_pillar(center: Vector2, size: float = 50.0):
	var half = size / 2.0
	add_wall(Rect2(center.x - half, center.y - half, size, size), true)

## Crea 4 pilares simétricos respecto al centro de la arena
## offset_x/offset_y = distancia desde el centro hasta el pilar
func add_symmetric_pillars(offset_x: float, offset_y: float, size: float = 50.0):
	var cx = arena_size.x / 2.0
	var cy = arena_size.y / 2.0
	add_pillar(Vector2(cx - offset_x, cy - offset_y), size)
	add_pillar(Vector2(cx + offset_x, cy - offset_y), size)
	add_pillar(Vector2(cx - offset_x, cy + offset_y), size)
	add_pillar(Vector2(cx + offset_x, cy + offset_y), size)

## Crea una barra de cobertura centrada en la posición dada
func add_cover(center: Vector2, width: float, height: float):
	add_wall(Rect2(center.x - width / 2.0, center.y - height / 2.0, width, height), true)

## Crea 2 coberturas simétricas horizontalmente respecto al centro
func add_symmetric_covers_h(offset_x: float, offset_y: float, width: float, height: float):
	var cx = arena_size.x / 2.0
	var cy = arena_size.y / 2.0
	add_cover(Vector2(cx - offset_x, cy + offset_y), width, height)
	add_cover(Vector2(cx + offset_x, cy + offset_y), width, height)

## Crea 2 coberturas simétricas verticalmente respecto al centro
func add_symmetric_covers_v(offset_x: float, offset_y: float, width: float, height: float):
	var cx = arena_size.x / 2.0
	var cy = arena_size.y / 2.0
	add_cover(Vector2(cx + offset_x, cy - offset_y), width, height)
	add_cover(Vector2(cx + offset_x, cy + offset_y), width, height)

## Crea una cruz de paredes centrada en la posición dada
func add_cross(center: Vector2, arm_length: float, thickness: float):
	add_cover(center, arm_length * 2, thickness)   # Barra horizontal
	add_cover(center, thickness, arm_length * 2)    # Barra vertical

## Crea una L de paredes (esquina) — útil para coberturas en esquina
func add_l_shape(corner: Vector2, length: float, thickness: float, flip_x := false, flip_y := false):
	var dx = -1.0 if flip_x else 1.0
	var dy = -1.0 if flip_y else 1.0
	# Barra horizontal
	add_wall(Rect2(corner.x, corner.y, length * dx, thickness), true)
	# Barra vertical
	add_wall(Rect2(corner.x, corner.y, thickness, length * dy), true)

# ============================================
# API PARA SPAWN POINTS
# ============================================

func get_player_spawn(index: int) -> Vector2:
	if index < player_spawn_points.size():
		return player_spawn_points[index]
	# Fallback: posiciones por defecto (lados opuestos)
	return Vector2(200 + index * 600, arena_size.y / 2.0)

func get_random_pickup_spawn() -> Vector2:
	if pickup_spawn_points.size() > 0:
		return pickup_spawn_points.pick_random()
	return arena_size / 2.0

func get_all_pickup_spawns() -> Array:
	return pickup_spawn_points.duplicate()

# ============================================
# DIBUJADO PLACEHOLDER
# TODO: Reemplazar con TileMap/Sprites cuando haya arte
# ============================================

func _draw():
	# Fondo
	draw_rect(Rect2(Vector2.ZERO, arena_size), background_color)
	
	# Grid de debug (opcional)
	if draw_debug_grid:
		var grid_color = Color(1, 1, 1, 0.05)
		var x = 0.0
		while x <= arena_size.x:
			draw_line(Vector2(x, 0), Vector2(x, arena_size.y), grid_color, 1.0)
			x += grid_spacing
		var y = 0.0
		while y <= arena_size.y:
			draw_line(Vector2(0, y), Vector2(arena_size.x, y), grid_color, 1.0)
			y += grid_spacing
	
	# Paredes perimetrales
	for rect in _wall_rects:
		draw_rect(rect, wall_color)
		draw_rect(rect, wall_border_color, false, 2.0)
	
	# Obstáculos internos (color diferenciado)
	for rect in _obstacle_rects:
		draw_rect(rect, obstacle_color)
		draw_rect(rect, wall_border_color, false, 2.0)
