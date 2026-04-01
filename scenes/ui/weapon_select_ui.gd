extends CanvasLayer

## UI compacta (esquina superior derecha) para elegir el arma activa.
## Aparece SIMULTÁNEAMENTE al draft de habilidades, sin bloquearlo.
## El jugador puede confirmar su arma en cualquier momento; next_round()
## solo se llama cuando AMBAS decisiones (arma + habilidad) están hechas.

signal weapon_selected(index: int)

@onready var title_label     = $Panel/Margin/VBox/TitleLabel
@onready var cards_container = $Panel/Margin/VBox/CardsContainer
@onready var confirm_center  = $Panel/Margin/VBox/ConfirmCenter

var _cards: Array           = []
var _loadout: Array         = []
var _selected_index: int    = 0
var _confirm_button: Button = null

# ===== CICLO DE VIDA =====

func _ready() -> void:
	visible = false   # Siempre oculto hasta que GameManager lo solicite

# ===== PÚBLICO =====

## Muestra el mini-panel para que player_name elija entre su loadout.
## Si loadout tiene menos de 2 armas, emite weapon_selected(0) automáticamente
## para no bloquear el flujo.
func show_for_player(player_name: String, loadout: Array, current_index: int) -> void:
	if loadout.size() < 2:
		weapon_selected.emit(0)
		return
	_loadout        = loadout
	_selected_index = clamp(current_index, 0, loadout.size() - 1)
	_clear_all()
	title_label.text = "⚔  " + player_name.to_upper()
	_build_cards()
	_build_confirm_button()
	visible = true

func hide_select() -> void:
	visible = false
	_clear_all()

# ===== CONSTRUCCIÓN (solo al abrir) =====

func _clear_all() -> void:
	for c in cards_container.get_children():
		c.queue_free()
	_cards.clear()
	for c in confirm_center.get_children():
		c.queue_free()
	_confirm_button = null

func _build_cards() -> void:
	for i in _loadout.size():
		var card = _make_card(_loadout[i], i)
		cards_container.add_child(card)
		_cards.append(card)
	_refresh_card_visuals()

func _build_confirm_button() -> void:
	_confirm_button = Button.new()
	_confirm_button.text = "✓  CONFIRMAR"
	_confirm_button.add_theme_font_size_override("font_size", 13)
	_confirm_button.custom_minimum_size = Vector2(170, 30)
	_confirm_button.add_theme_stylebox_override("normal", _sb(Color(0.1, 0.4, 0.2, 0.9),  Color(0.2, 0.7, 0.35, 0.7)))
	_confirm_button.add_theme_stylebox_override("hover",  _sb(Color(0.15, 0.55, 0.28, 0.95), Color(0.3, 0.85, 0.5, 0.9)))
	_confirm_button.pressed.connect(_on_confirm)
	confirm_center.add_child(_confirm_button)

# ===== TARJETA COMPACTA =====

func _make_card(modifier: BulletModifier, index: int) -> PanelContainer:
	var col := modifier.icon_color if modifier else Color.WHITE

	var card := PanelContainer.new()
	card.name = "Card_%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size   = Vector2(72, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	# Badge (★ ACTIVA)
	var badge := Label.new()
	badge.name = "Badge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 9)
	vbox.add_child(badge)

	# Nombre del arma
	var nl := Label.new()
	nl.text = (modifier.modifier_name if modifier else "?").to_upper()
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", 11)
	nl.add_theme_color_override("font_color", col)
	nl.clip_text = true
	vbox.add_child(nl)

	# Línea de color
	var line := ColorRect.new()
	line.color = col * Color(1, 1, 1, 0.4)
	line.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(line)

	# Stats compactos: solo DMG y CD
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 1)
	vbox.add_child(grid)
	if modifier:
		_stat(grid, "DMG", str(modifier.damage),          Color(1.0, 0.5, 0.4))
		_stat(grid, "CD",  str(modifier.cooldown) + "s",  Color(0.9, 0.85, 0.4))

	# Botón de selección
	var btn := Button.new()
	btn.name = "Btn"
	btn.add_theme_font_size_override("font_size", 11)
	btn.custom_minimum_size = Vector2(0, 26)
	btn.pressed.connect(_on_pick.bind(index))
	vbox.add_child(btn)

	return card

# ===== ACTUALIZAR VISUALES SIN RECONSTRUIR =====

func _refresh_card_visuals() -> void:
	for i in _cards.size():
		var card = _cards[i]
		if not is_instance_valid(card): continue
		var modifier  := _loadout[i] as BulletModifier
		var col       := modifier.icon_color if modifier else Color.WHITE
		var is_active := (i == _selected_index)

		# Estilo de fondo
		var sty := StyleBoxFlat.new()
		sty.set_corner_radius_all(8)
		sty.content_margin_left = 6; sty.content_margin_right  = 6
		sty.content_margin_top  = 6; sty.content_margin_bottom = 6
		if is_active:
			sty.bg_color = Color(col.r * 0.2, col.g * 0.2, col.b * 0.2, 0.95)
			sty.border_width_left = 2; sty.border_width_right  = 2
			sty.border_width_top  = 2; sty.border_width_bottom = 2
			sty.border_color = col
		else:
			sty.bg_color = Color(0.08, 0.08, 0.12, 0.95)
			sty.border_width_left = 1; sty.border_width_right  = 1
			sty.border_width_top  = 1; sty.border_width_bottom = 1
			sty.border_color = col * Color(1, 1, 1, 0.3)
		card.add_theme_stylebox_override("panel", sty)

		# Badge y botón
		var vbox: Node = card.get_child(0)
		var badge := vbox.get_node_or_null("Badge") as Label
		if badge:
			badge.text = "★" if is_active else ""
			badge.add_theme_color_override("font_color", col)
		var btn := vbox.get_node_or_null("Btn") as Button
		if btn:
			btn.text = "✓" if is_active else "USAR"
			btn.add_theme_stylebox_override("normal", _sb(col * Color(0.35, 0.35, 0.35, 0.85), col * Color(0.6, 0.6, 0.6, 0.5)))
			btn.add_theme_stylebox_override("hover",  _sb(col * Color(0.5,  0.5,  0.5,  0.95), col * Color(0.8, 0.8, 0.8, 0.8)))

# ===== EVENTOS =====

func _on_pick(index: int) -> void:
	_selected_index = index
	_refresh_card_visuals()

func _on_confirm() -> void:
	hide_select()
	weapon_selected.emit(_selected_index)

# ===== HELPERS =====

func _stat(grid: GridContainer, lbl: String, val: String, col: Color) -> void:
	var l := Label.new()
	l.text = lbl
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	l.clip_text = true
	grid.add_child(l)
	var v := Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 11)
	v.add_theme_color_override("font_color", col)
	v.clip_text = true
	grid.add_child(v)

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(6)
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.border_color = border
	s.content_margin_left = 4; s.content_margin_right  = 4
	s.content_margin_top  = 4; s.content_margin_bottom = 4
	return s
