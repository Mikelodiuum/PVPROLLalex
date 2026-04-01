extends Node2D
class_name BaseArena

## Clase base para todos los mapas del juego.
## La lógica visual (paredes, fondo, obstáculos) se define directamente
## en la escena .tscn, editando nodos en el editor de Godot.
##
## Para crear un mapa nuevo:
##   1. Crear carpeta scenes/maps/mapNombre/
##   2. Crear un .gd que extienda BaseArena (puede estar vacío)
##   3. Crear un .tscn con:
##      - StaticBody2D (collision_layer=4, grupo "walls") para cada pared/obstáculo
##      - Marker2D llamados SpawnP1, SpawnP2 para spawn de jugadores
##      - Marker2D llamados PickupSpawn1, PickupSpawn2... para pickups
##   4. Ajustar arena_size en el Inspector al tamaño real del mapa

@export_group("Dimensiones")
@export var arena_size := Vector2(6144, 2048)   ## Tamaño total del mapa en píxeles

# Spawn points (recogidos automáticamente de los Marker2D hijos)
var player_spawn_points: Array = []
var pickup_spawn_points: Array = []

func _ready():
	add_to_group("arena")
	_collect_spawn_points()

func _collect_spawn_points():
	for child in get_children():
		if child is Marker2D:
			if child.name.begins_with("SpawnP"):
				player_spawn_points.append(child.global_position)
			elif child.name.begins_with("PickupSpawn"):
				pickup_spawn_points.append(child.global_position)

# ============================================
# API QUE NECESITA EL GAMEMANAGER
# ============================================

func get_player_spawn(index: int) -> Vector2:
	if index < player_spawn_points.size():
		return player_spawn_points[index]
	return Vector2(200 + index * 5744, arena_size.y / 2.0)

func get_random_pickup_spawn() -> Vector2:
	if pickup_spawn_points.size() > 0:
		return pickup_spawn_points.pick_random()
	return arena_size / 2.0

func get_all_pickup_spawns() -> Array:
	return pickup_spawn_points.duplicate()
