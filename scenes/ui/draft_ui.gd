extends CanvasLayer

## UI del draft de habilidades post-ronda.
## El ganador elige primero de 3 habilidades; el perdedor elige de las 2 restantes.

@onready var background      = $Background
@onready var title_label     = $MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label  = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var cards_container = $MarginContainer/VBoxContainer/CardsContainer
@onready var reroll_center   = $MarginContainer/VBoxContainer/RerollCenter

var _cards: Array = []
var _options: Array = []
var _draft_manager: DraftManager = null

func setup(draft_mgr: DraftManager):
	_draft_manager = draft_mgr
	_draft_manager.show_draft_ui.connect(_on_show_draft)
	_draft_manager.hide_draft_ui.connect(_on_hide_draft)
	visible = false

func _on_show_draft(options: Array, player_name: String, _reroll_available: bool):
	_options = options
	_clear_cards()
	_populate(options, player_name)
	visible = true

func _on_hide_draft():
	visible = false
	_clear_cards()

func _clear_cards():
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()

func _populate(options: Array, player_name: String):
	var is_winner_turn = (options.size() == 3)
	title_label.text = player_name + " — ¡Elige una habilidad!"
	subtitle_label.text = "Ganador elige primero" if is_winner_turn else "Perdedor elige de las restantes"

	for i in options.size():
		var card = _create_card(options[i], i)
		cards_container.add_child(card)
		_cards.append(card)

func _create_card(ability: AbilityResource, index: int) -> PanelContainer:
	var col = ability.icon_color

	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size   = Vector2(180, 0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_corner_radius_all(12)
	style.border_width_left = 2; style.border_width_right  = 2
	style.border_width_top  = 3; style.border_width_bottom = 2
	style.border_color = col * Color(1, 1, 1, 0.5)
	style.content_margin_left = 14; style.content_margin_right  = 14
	style.content_margin_top  = 14; style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Nombre
	var nl = Label.new()
	nl.text = ability.ability_name.to_upper()
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
	desc.text = ability.description if ability.description != "" else "Sin descripción"
	desc.fit_content = true; desc.scroll_active = false; desc.bbcode_enabled = false
	desc.custom_minimum_size = Vector2(0, 50)
	desc.add_theme_font_size_override("normal_font_size", 12)
	desc.add_theme_color_override("default_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(desc)

	# Separador
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	# Stats de la habilidad
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(grid)

	if ability.bonus_damage != 0:
		_stat(grid, "DAÑO+",    "+" + str(ability.bonus_damage),            Color(1.0, 0.5, 0.4))
	if ability.damage_multiplier != 1.0:
		_stat(grid, "MULT",     "x" + str(snapped(ability.damage_multiplier, 0.01)), Color(1.0, 0.6, 0.3))
	if ability.bonus_speed != 0.0:
		_stat(grid, "VEL+",     "+" + str(int(ability.bonus_speed)),        Color(0.4, 0.9, 0.5))
	if ability.cooldown_reduction != 0.0:
		_stat(grid, "CD-",      "-" + str(ability.cooldown_reduction) + "s",Color(0.9, 0.85, 0.3))
	if ability.shield_per_round != 0:
		_stat(grid, "ESCUDO",   str(ability.shield_per_round) + "/ronda",   Color(0.4, 0.6, 1.0))
	if ability.lifesteal_percent != 0.0:
		_stat(grid, "ROBO VIDA", str(int(ability.lifesteal_percent * 100)) + "%", Color(0.85, 0.2, 0.3))

	# Spacer
	var sp = Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sp)

	# Botón ELEGIR
	var btn = Button.new()
	btn.text = "ELEGIR"
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_stylebox_override("normal",  _stylebox(col * Color(0.35, 0.35, 0.35, 0.85), col * Color(0.6, 0.6, 0.6, 0.5)))
	btn.add_theme_stylebox_override("hover",   _stylebox(col * Color(0.5,  0.5,  0.5,  0.95), col * Color(0.8, 0.8, 0.8, 0.8)))
	btn.add_theme_stylebox_override("pressed", _stylebox(col * Color(0.25, 0.25, 0.25, 0.9),  col * Color(0.5, 0.5, 0.5, 0.6)))
	btn.pressed.connect(_on_card_selected.bind(index))
	vbox.add_child(btn)

	return card

# === HELPERS ===

func _stat(grid: GridContainer, lbl: String, val: String, col: Color):
	var l = Label.new()
	l.text = lbl; l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5)); l.clip_text = true
	grid.add_child(l)
	var v = Label.new()
	v.text = val; v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", col); v.clip_text = true
	grid.add_child(v)

func _stylebox(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg; s.set_corner_radius_all(8)
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.border_color = border
	s.content_margin_left = 8; s.content_margin_right  = 8
	s.content_margin_top  = 6; s.content_margin_bottom = 6
	return s

# === CALLBACKS ===

func _on_card_selected(index: int):
	if _draft_manager:
		_draft_manager.on_option_selected(index)
