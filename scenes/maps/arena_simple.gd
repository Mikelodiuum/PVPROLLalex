extends BaseArena

## Arena simple: primer mapa jugable.
## Paredes perimetrales + pilares simétricos + obstáculo central.
## Layout diseñado para 1152x648.

const WALL_THICKNESS := 16.0
const PILLAR_SIZE := 50.0

func _setup_arena():
	_arena_size = Vector2(1152, 648)
	
	# === PAREDES PERIMETRALES ===
	add_wall(Rect2(0, 0, _arena_size.x, WALL_THICKNESS))                                    # Arriba
	add_wall(Rect2(0, _arena_size.y - WALL_THICKNESS, _arena_size.x, WALL_THICKNESS))        # Abajo
	add_wall(Rect2(0, 0, WALL_THICKNESS, _arena_size.y))                                     # Izquierda
	add_wall(Rect2(_arena_size.x - WALL_THICKNESS, 0, WALL_THICKNESS, _arena_size.y))        # Derecha
	
	# === PILARES SIMÉTRICOS (4 esquinas interiores) ===
	add_wall(Rect2(300, 170, PILLAR_SIZE, PILLAR_SIZE))     # Superior izquierdo
	add_wall(Rect2(802, 170, PILLAR_SIZE, PILLAR_SIZE))     # Superior derecho
	add_wall(Rect2(300, 428, PILLAR_SIZE, PILLAR_SIZE))     # Inferior izquierdo
	add_wall(Rect2(802, 428, PILLAR_SIZE, PILLAR_SIZE))     # Inferior derecho
	
	# === COBERTURA CENTRAL (barra horizontal) ===
	add_wall(Rect2(526, 314, 100, 20))
