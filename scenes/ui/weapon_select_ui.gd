extends CanvasLayer

## UI para elegir el arma activa antes de cada ronda.
## Muestra las 3 armas del loadout del jugador y permite cambiar cuál usar.

signal weapon_selected(index: int)

@onready var title_label     = $MarginContainer/VBoxContainer/TitleLabel
@onready var cards_container = $MarginContainer/VBoxContainer/CardsContainer
@onready var confirm_center  = $MarginContainer/VBoxContainer/ConfirmCenter

var _cards: Array   = []
var _loadout: Array = []
var _selected_index: int  = 0
var _confirm_button: Button = null

# ===== CICLO DE VIDA =====

func _ready():
	visible = false   # SIEMPRE oculto hasta que GameManager lo muestre explícitamente

# ===== PÚBLICO =====

func show_for_player(player_name: String, loadout: Array, current_index: int):
	if loadout.is_empty():
		push_warning("WeaponSelectUI: loadout vacío, ocultando")
		return
	_loadout        = loadout
	_selected_index = current_index
	_clear_all()
	title_label.text = player_name + " — Elige tu arma"
	_build_cards()
	_build_confirm_button()
	visible = true

func hide_select():
	visible = false
	_clear_all()

# ===== CONSTRUCCIÓN (solo se llama UNA vez por show) =====

func _clear_all():
	for c in cards_container.get_children():
		c.queue_free()
	_cards.clear()
	for c in confirm_center.get_children():
		c.queue_free()
	_confirm_button = null

func _build_cards():
	for i in _loadout.size():
		var card = _make_card(_loadout[i], i)
		cards_container.add_child(card)
		_cards.append(card)
	_refresh_card_visuals()

func _build_confirm_button():
	_confirm_button = Button.new()
	_confirm_button.text = "   CONFIRMAR   "
	_confirm_button.add_theme_font_size_override("font_size", 20)
	_confirm_button.custom_minimum_size = Vector2(220, 50)
	_confirm_button.add_theme_stylebox_override("normal", _sb(Color(0.1,0.4,0.2,0.9),  Color(0.2,0.7,0.35,0.7)))
	_confirm_button.add_theme_stylebox_override("hover",  _sb(Color(0.15,0.55,0.28,0.95), Color(0.3,0.85,0.5,0.9)))
	_confirm_button.pressed.connect(_on_confirm)
	confirm_center.add_child(_confirm_button)

# ===== CREACIÓN DE TARJETA (estructura fija, visual se actualiza luego) =====

func _make_card(modifier: BulletModifier, index: int) -> PanelContainer:
	var col = modifier.icon_color if modifier else Color.WHITE

	var card = PanelContainer.new()
	card.name = "Card_%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size   = Vector2(180, 0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Badge (se actualiza en _refresh)
	var badge = Label.new()
	badge.name = "Badge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	vbox.add_child(badge)

	# Nombre
	var nl = Label.new()
	nl.text = (modifier.modifier_name if modifier else "Arma").to_upper()
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", 20)
	nl.add_theme_color_override("font_color", col)
	nl.clip_text = true
	vbox.add_child(nl)

	# Línea de color
	var line = ColorRect.new()
	line.color = col * Color(1, 1, 1, 0.4)
	line.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(line)

	# Descripción
	var desc = RichTextLabel.new()
	desc.text = modifier.description if (modifier and modifier.description != "") else "Sin descripción"
	desc.fit_content = true; desc.scroll_active = false; desc.bbcode_enabled = false
	desc.custom_minimum_size = Vector2(0, 40)
	desc.add_theme_font_size_override("normal_font_size", 12)
	desc.add_theme_color_override("default_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(desc)

	# Stats
	var sep = HSeparator.new(); vbox.add_child(sep)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(grid)
	if modifier:
		_stat(grid, "VEL",   str(int(modifier.speed)),     Color(0.5, 0.8, 1.0))
		_stat(grid, "DMG",   str(modifier.damage),         Color(1.0, 0.5, 0.4))
		_stat(grid, "CD",    str(modifier.cooldown) + "s", Color(0.9, 0.85, 0.4))
		if modifier.bullet_count > 1:
			_stat(grid, "BALAS", str(modifier.bullet_count), Color(1.0, 0.7, 0.3))

	# Spacer
	var sp = Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; vbox.add_child(sp)

	# Botón (se actualiza en _refresh)
	var btn = Button.new()
	btn.name = "Btn"
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(_on_pick.bind(index))
	vbox.add_child(btn)

	return card

# ===== ACTUALIZAR VISUALS SIN RECONSTRUIR =====

func _refresh_card_visuals():
	for i in _cards.size():
		var card = _cards[i]
		if not is_instance_valid(card): continue
		var modifier = _loadout[i]
		var col      = modifier.icon_color if modifier else Color.WHITE
		var is_active = (i == _selected_index)

		# --- Estilo del panel ---
		var sty = StyleBoxFlat.new()
		sty.set_corner_radius_all(12)
		sty.content_margin_left = 14; sty.content_margin_right  = 14
		sty.content_margin_top  = 14; sty.content_margin_bottom = 14
		if is_active:
			sty.bg_color = Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.95)
			sty.border_width_left = 3; sty.border_width_right  = 3
			sty.border_width_top  = 3; sty.border_width_bottom = 3
			sty.border_color = col
		else:
			sty.bg_color = Color(0.1, 0.1, 0.15, 0.95)
			sty.border_width_left = 2; sty.border_width_right  = 2
			sty.border_width_top  = 2; sty.border_width_bottom = 2
			sty.border_color = col * Color(1, 1, 1, 0.4)
		card.add_theme_stylebox_override("panel", sty)

		# --- Badge ---
		var vbox  = card.get_child(0)
		var badge = vbox.get_node_or_null("Badge")
		if badge:
			badge.text = "★ ACTIVA" if is_active else ""
			badge.add_theme_color_override("font_color", col)

		# --- Botón ---
		var btn = vbox.get_node_or_null("Btn")
		if btn:
			btn.text = "MANTENER" if is_active else "EQUIPAR"
			btn.add_theme_stylebox_override("normal", _sb(col * Color(0.35,0.35,0.35,0.85), col * Color(0.6,0.6,0.6,0.5)))
			btn.add_theme_stylebox_override("hover",  _sb(col * Color(0.5, 0.5, 0.5, 0.95), col * Color(0.8,0.8,0.8,0.8)))

# ===== EVENTOS =====

func _on_pick(index: int):
	_selected_index = index
	_refresh_card_visuals()   # Solo actualiza colores/textos, SIN destruir nada

func _on_confirm():
	hide_select()
	weapon_selected.emit(_selected_index)

# ===== HELPERS =====

func _stat(grid: GridContainer, lbl: String, val: String, col: Color):
	var l = Label.new()
	l.text = lbl; l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.45,0.45,0.5)); l.clip_text = true
	grid.add_child(l)
	var v = Label.new()
	v.text = val; v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", col); v.clip_text = true
	grid.add_child(v)

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg; s.set_corner_radius_all(8)
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.border_color = border
	s.content_margin_left = 8; s.content_margin_right  = 8
	s.content_margin_top  = 6; s.content_margin_bottom = 6
	return s
