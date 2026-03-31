extends CanvasLayer

## UI del draft de modificadores post-ronda.
## Usa draft_ui.tscn como base con layout apropiado.
## Las cartas se crean dinámicamente pero con tamaño y clipping correctos.

# === REFERENCIAS A NODOS DE LA ESCENA ===
@onready var background = $Background
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var cards_container = $MarginContainer/VBoxContainer/CardsContainer
@onready var reroll_center = $MarginContainer/VBoxContainer/RerollCenter

# === ESTADO INTERNO ===
var _cards: Array = []
var _options: Array = []
var _player_name := ""
var _reroll_button: Button = null
var _draft_manager: DraftManager = null

func setup(draft_mgr: DraftManager):
	_draft_manager = draft_mgr
	_draft_manager.show_draft_ui.connect(_on_show_draft)
	_draft_manager.hide_draft_ui.connect(_on_hide_draft)
	visible = false

func _on_show_draft(options: Array, player_name: String, reroll_available: bool):
	_options = options
	_player_name = player_name
	_clear_cards()
	_populate(options, player_name, reroll_available)
	visible = true

func _on_hide_draft():
	visible = false
	_clear_cards()

func _clear_cards():
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	if _reroll_button and is_instance_valid(_reroll_button):
		_reroll_button.queue_free()
		_reroll_button = null

func _populate(options: Array, player_name: String, reroll_available: bool):
	# Actualizar textos
	title_label.text = player_name + " — ¡Elige tu modificador!"
	if options.size() == 2:
		subtitle_label.text = "El ganador elige de las opciones restantes"
	else:
		subtitle_label.text = "Selecciona una de las opciones"
	
	# Crear cartas
	for i in options.size():
		var card = _create_card(options[i], i)
		cards_container.add_child(card)
		_cards.append(card)
	
	# Botón Reroll
	if reroll_available:
		_reroll_button = Button.new()
		_reroll_button.text = "   Reroll  (1 uso)   "
		_reroll_button.add_theme_font_size_override("font_size", 18)
		_reroll_button.custom_minimum_size = Vector2(220, 45)
		
		var style = _make_stylebox(Color(0.25, 0.2, 0.45, 0.95), Color(0.5, 0.35, 0.9, 0.7))
		_reroll_button.add_theme_stylebox_override("normal", style)
		var hover = _make_stylebox(Color(0.35, 0.28, 0.6, 0.98), Color(0.6, 0.45, 1.0, 0.9))
		_reroll_button.add_theme_stylebox_override("hover", hover)
		var pressed = _make_stylebox(Color(0.2, 0.15, 0.35, 0.98), Color(0.5, 0.35, 0.9, 0.7))
		_reroll_button.add_theme_stylebox_override("pressed", pressed)
		
		_reroll_button.pressed.connect(_on_reroll_pressed)
		reroll_center.add_child(_reroll_button)

func _create_card(modifier: BulletModifier, index: int) -> PanelContainer:
	# PanelContainer para que el contenido se clipee automáticamente
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(180, 0)
	
	# Estilo de la carta
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_corner_radius_all(12)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 3
	style.border_width_bottom = 2
	style.border_color = modifier.icon_color * Color(1, 1, 1, 0.5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)
	
	# Contenedor principal de la carta
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# === NOMBRE ===
	var name_label = Label.new()
	name_label.text = modifier.modifier_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", modifier.icon_color)
	name_label.clip_text = true
	vbox.add_child(name_label)
	
	# === LÍNEA DE COLOR ===
	var color_line = ColorRect.new()
	color_line.color = modifier.icon_color * Color(1, 1, 1, 0.4)
	color_line.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(color_line)
	
	# === DESCRIPCIÓN ===
	var desc_label = RichTextLabel.new()
	desc_label.text = modifier.description if modifier.description != "" else "Sin descripción"
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = false
	desc_label.custom_minimum_size = Vector2(0, 40)
	desc_label.add_theme_font_size_override("normal_font_size", 12)
	desc_label.add_theme_color_override("default_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(desc_label)
	
	# === SEPARADOR ===
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)
	
	# === STATS (Grid para alineación limpia) ===
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(stats_grid)
	
	_add_stat(stats_grid, "VEL", str(int(modifier.speed)), Color(0.5, 0.8, 1.0))
	_add_stat(stats_grid, "DMG", str(modifier.damage), Color(1.0, 0.5, 0.4))
	_add_stat(stats_grid, "CD", str(modifier.cooldown) + "s", Color(0.9, 0.85, 0.4))
	if modifier.pierce > 1:
		_add_stat(stats_grid, "PIERCE", str(modifier.pierce), Color(0.7, 0.5, 1.0))
	if modifier.bullet_count > 1:
		_add_stat(stats_grid, "BALAS", str(modifier.bullet_count), Color(1.0, 0.7, 0.3))
		_add_stat(stats_grid, "SPREAD", str(modifier.spread_angle) + "°", Color(0.8, 0.8, 0.5))
	if modifier.scale != 1.0:
		_add_stat(stats_grid, "SIZE", "x" + str(modifier.scale), Color(0.6, 0.9, 0.6))
	
	# === ESPACIADOR FLEXIBLE ===
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# === BOTÓN ELEGIR ===
	var btn = Button.new()
	btn.text = "ELEGIR"
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(0, 40)
	
	var btn_normal = _make_stylebox(
		modifier.icon_color * Color(0.35, 0.35, 0.35, 0.85),
		modifier.icon_color * Color(0.6, 0.6, 0.6, 0.5)
	)
	btn.add_theme_stylebox_override("normal", btn_normal)
	
	var btn_hover = _make_stylebox(
		modifier.icon_color * Color(0.5, 0.5, 0.5, 0.95),
		modifier.icon_color * Color(0.8, 0.8, 0.8, 0.8)
	)
	btn.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = _make_stylebox(
		modifier.icon_color * Color(0.25, 0.25, 0.25, 0.9),
		modifier.icon_color * Color(0.5, 0.5, 0.5, 0.6)
	)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	
	btn.pressed.connect(_on_card_selected.bind(index))
	vbox.add_child(btn)
	
	return card

# === HELPERS ===

func _add_stat(grid: GridContainer, label_text: String, value_text: String, color: Color):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	lbl.clip_text = true
	grid.add_child(lbl)
	
	var val = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", color)
	val.clip_text = true
	grid.add_child(val)

func _make_stylebox(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = border
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

# === CALLBACKS ===

func _on_card_selected(index: int):
	if _draft_manager:
		_draft_manager.on_option_selected(index)

func _on_reroll_pressed():
	if _draft_manager:
		_draft_manager.on_reroll()
