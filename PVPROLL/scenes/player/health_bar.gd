extends ProgressBar

## Script para la barra de vida con colores dinámicos.
## Verde (100%) → Amarillo (50%) → Rojo (0%)
## Se asigna como hijo de HealthBarPivot en la escena del jugador.

# Colores del gradiente de vida
var color_full := Color(0.1, 0.85, 0.25)   # Verde brillante
var color_mid := Color(1.0, 0.82, 0.0)     # Amarillo/dorado
var color_low := Color(0.9, 0.12, 0.12)    # Rojo intenso

# Estilos internos
var fill_style: StyleBoxFlat
var bg_style: StyleBoxFlat

func _ready():
	# Desactivar texto de porcentaje
	show_percentage = false
	
	# === Estilo del fondo (background) ===
	bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.75)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.25, 0.25, 0.25, 0.9)
	
	# === Estilo del relleno (fill) ===
	fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color_full
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	
	# Aplicar estilos
	add_theme_stylebox_override("background", bg_style)
	add_theme_stylebox_override("fill", fill_style)
	
	# Conectar señal para actualizar color cuando cambia el valor
	value_changed.connect(_on_value_changed)
	
	# Inicializar color
	_on_value_changed(value)

func _on_value_changed(new_value: float):
	var ratio = new_value / max_value if max_value > 0 else 0.0
	_update_color(ratio)

func _update_color(ratio: float):
	var color: Color
	if ratio > 0.5:
		# Verde → Amarillo (1.0 → 0.5)
		var t = (ratio - 0.5) / 0.5
		color = color_mid.lerp(color_full, t)
	else:
		# Amarillo → Rojo (0.5 → 0.0)
		var t = ratio / 0.5
		color = color_low.lerp(color_mid, t)
	
	if fill_style:
		fill_style.bg_color = color
