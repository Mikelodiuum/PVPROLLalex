extends CanvasLayer

## UI del draft de modificadores post-ronda.
## Muestra cartas con los stats de cada modifier para que el jugador elija.
## Se crea dinámicamente — no necesita .tscn.

var _cards: Array = []             # Array de Panel (las cartas)
var _options: Array = []           # Array de BulletModifier
var _player_name := ""
var _reroll_button: Button = null
var _title_label: Label = null
var _bg_panel: Panel = null
var _draft_manager: DraftManager = null

func setup(draft_mgr: DraftManager):
	_draft_manager = draft_mgr
	_draft_manager.show_draft_ui.connect(_on_show_draft)
	_draft_manager.hide_draft_ui.connect(_on_hide_draft)
	layer = 100  # Encima de todo
	visible = false

func _on_show_draft(options: Array, player_name: String, reroll_available: bool):
	_options = options
	_player_name = player_name
	_clear_ui()
	_build_ui(options, player_name, reroll_available)
	visible = true

func _on_hide_draft():
	visible = false
	_clear_ui()

func _clear_ui():
	for child in get_children():
		child.queue_free()
	_cards.clear()
	_reroll_button = null
	_title_label = null
	_bg_panel = null

func _build_ui(options: Array, player_name: String, reroll_available: bool):
	# === FONDO OSCURO SEMI-TRANSPARENTE ===
	_bg_panel = Panel.new()
	_bg_panel.anchors_preset = Control.PRESET_FULL_RECT
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.75)
	_bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(_bg_panel)
	
	# === CONTENEDOR PRINCIPAL ===
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -350
	vbox.offset_right = 350
	vbox.offset_top = -220
	vbox.offset_bottom = 220
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	# === TÍTULO ===
	_title_label = Label.new()
	_title_label.text = player_name + " — ¡Elige tu modificador!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(_title_label)
	
	# === CONTENEDOR DE CARTAS ===
	var cards_container = HBoxContainer.new()
	cards_container.add_theme_constant_override("separation", 15)
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(cards_container)
	
	# === CREAR CARTAS ===
	for i in options.size():
		var card = _create_card(options[i], i)
		cards_container.add_child(card)
		_cards.append(card)
	
	# === BOTÓN REROLL ===
	if reroll_available:
		_reroll_button = Button.new()
		_reroll_button.text = "🎲  Reroll  (1 uso)"
		_reroll_button.add_theme_font_size_override("font_size", 18)
		_reroll_button.custom_minimum_size = Vector2(200, 45)
		
		var reroll_style = StyleBoxFlat.new()
		reroll_style.bg_color = Color(0.3, 0.25, 0.5, 0.9)
		reroll_style.corner_radius_top_left = 8
		reroll_style.corner_radius_top_right = 8
		reroll_style.corner_radius_bottom_left = 8
		reroll_style.corner_radius_bottom_right = 8
		reroll_style.border_width_left = 2
		reroll_style.border_width_right = 2
		reroll_style.border_width_top = 2
		reroll_style.border_width_bottom = 2
		reroll_style.border_color = Color(0.6, 0.4, 1.0, 0.8)
		_reroll_button.add_theme_stylebox_override("normal", reroll_style)
		
		var reroll_hover = reroll_style.duplicate()
		reroll_hover.bg_color = Color(0.4, 0.35, 0.65, 0.95)
		_reroll_button.add_theme_stylebox_override("hover", reroll_hover)
		
		_reroll_button.pressed.connect(_on_reroll_pressed)
		
		var center = CenterContainer.new()
		center.add_child(_reroll_button)
		vbox.add_child(center)

func _create_card(modifier: BulletModifier, index: int) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(200, 280)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Estilo de la carta
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.18, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = modifier.icon_color * Color(1, 1, 1, 0.6)
	card.add_theme_stylebox_override("panel", style)
	
	# VBox para el contenido de la carta
	var content = VBoxContainer.new()
	content.anchors_preset = Control.PRESET_FULL_RECT
	content.offset_left = 12
	content.offset_right = -12
	content.offset_top = 12
	content.offset_bottom = -12
	content.add_theme_constant_override("separation", 6)
	card.add_child(content)
	
	# Nombre del modifier
	var name_label = Label.new()
	name_label.text = modifier.modifier_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", modifier.icon_color)
	content.add_child(name_label)
	
	# Separador visual
	var sep = HSeparator.new()
	content.add_child(sep)
	
	# Descripción
	var desc_label = Label.new()
	desc_label.text = modifier.description if modifier.description != "" else "Sin descripción"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	desc_label.custom_minimum_size.y = 50
	content.add_child(desc_label)
	
	# Stats
	var stats_text = ""
	stats_text += "⚡ VEL: " + str(int(modifier.speed)) + "\n"
	stats_text += "💥 DMG: " + str(modifier.damage) + "\n"
	stats_text += "⏱️ CD: " + str(modifier.cooldown) + "s\n"
	if modifier.pierce > 1:
		stats_text += "🔱 Pierce: " + str(modifier.pierce) + "\n"
	if modifier.bullet_count > 1:
		stats_text += "🔫 Balas: " + str(modifier.bullet_count) + "\n"
		stats_text += "📐 Spread: " + str(modifier.spread_angle) + "°\n"
	if modifier.scale != 1.0:
		stats_text += "📏 Tamaño: x" + str(modifier.scale) + "\n"
	
	var stats_label = Label.new()
	stats_label.text = stats_text.strip_edges()
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	content.add_child(stats_label)
	
	# Espaciador flexible
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	
	# Botón "Elegir"
	var btn = Button.new()
	btn.text = "Elegir"
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(0, 38)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = modifier.icon_color * Color(0.5, 0.5, 0.5, 0.8)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = modifier.icon_color * Color(0.7, 0.7, 0.7, 0.95)
	btn.add_theme_stylebox_override("hover", btn_hover)
	
	btn.pressed.connect(_on_card_selected.bind(index))
	content.add_child(btn)
	
	return card

func _on_card_selected(index: int):
	if _draft_manager:
		_draft_manager.on_option_selected(index)

func _on_reroll_pressed():
	if _draft_manager:
		_draft_manager.on_reroll()
