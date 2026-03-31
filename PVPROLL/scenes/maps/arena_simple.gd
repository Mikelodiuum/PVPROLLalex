extends BaseArena

## Arena simple: primer mapa jugable.
## Paredes perimetrales (auto) + 4 pilares simétricos + cobertura central.
## Layout diseñado para 1152x648.
##
## Para crear un mapa nuevo, copia este archivo y modifica _setup_arena().
## Las paredes perimetrales se crean automáticamente (auto_perimeter = true).

func _setup_arena():
	# 4 pilares simétricos (offset_x=276, offset_y=154 desde el centro)
	add_symmetric_pillars(276, 154, 50)
	
	# Barra de cobertura central (100x20)
	add_cover(arena_size / 2, 100, 20)
