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
var _reroll_button: Button = null
var _draft_manager: DraftManager = null
var _abilities_panel: PanelContainer = null
var _p1_abilities_lbl: RichTextLabel = null
var _p2_abilities_lbl: RichTextLabel = null
var _weapon_swap_panel: PanelContainer = null

func setup(draft_mgr: DraftManager):
	_draft_manager = draft_mgr
	_draft_manager.show_draft_ui.connect(_on_show_draft)
	_draft_manager.hide_draft_ui.connect(_on_hide_draft)
	visible = false

func _on_show_draft(options: Array, player_name: String, reroll_available: bool):
	_options = options
	_clear_cards()
	_populate(options, player_name, reroll_available)
	_update_abilities_hud()
	_update_weapon_swap_hud(player_name)
	visible = true

func _update_abilities_hud():
	if _abilities_panel == null:
		_abilities_panel = PanelContainer.new()
		_abilities_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_abilities_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_abilities_panel.offset_left = 25
		_abilities_panel.offset_bottom = -25
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
		style.border_color = Color(0.4, 0.4, 0.5)
		style.border_width_left = 1; style.border_width_right = 1; style.border_width_top = 1; style.border_width_bottom = 1
		style.content_margin_left = 12; style.content_margin_right = 12; style.content_margin_top = 12; style.content_margin_bottom = 12
		_abilities_panel.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		_abilities_panel.add_child(vbox)
		
		var title = Label.new()
		title.text = "HUD de Habilidades"
		title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		title.add_theme_font_size_override("font_size", 14)
		vbox.add_child(title)
		
		var hs = HSeparator.new()
		vbox.add_child(hs)
		
		_p1_abilities_lbl = RichTextLabel.new()
		_p1_abilities_lbl.bbcode_enabled = true
		_p1_abilities_lbl.fit_content = true
		_p1_abilities_lbl.custom_minimum_size = Vector2(200, 0)
		vbox.add_child(_p1_abilities_lbl)
		
		var hs2 = HSeparator.new()
		vbox.add_child(hs2)
		
		_p2_abilities_lbl = RichTextLabel.new()
		_p2_abilities_lbl.bbcode_enabled = true
		_p2_abilities_lbl.fit_content = true
		_p2_abilities_lbl.custom_minimum_size = Vector2(200, 0)
		vbox.add_child(_p2_abilities_lbl)
		
		add_child(_abilities_panel)

	# Llenar datos desde el GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		_fill_hud_player(gm, "Player1", _p1_abilities_lbl, "cyan")
		_fill_hud_player(gm, "Player2", _p2_abilities_lbl, "red")

func _fill_hud_player(gm: Node, p_name: String, lbl: RichTextLabel, col_name: String):
	var txt = "[color=" + col_name + "][b]" + p_name + "[/b][/color]\n"
	
	if gm.player_modifiers.has(p_name) and gm.player_modifiers[p_name] != null:
		txt += "- Arma: " + gm.player_modifiers[p_name].modifier_name + "\n"
	else:
		txt += "- Arma: Default\n"

	if gm.player_abilities.has(p_name) and gm.player_abilities[p_name].size() > 0:
		txt += "- Habilidades:\n"
		for ab in gm.player_abilities[p_name]:
			var col_str = ab.icon_color.to_html()
			txt += "  [color=#" + col_str + "]" + ab.ability_name + "[/color]\n"
	else:
		txt += "- Habilidades: Ninguna\n"
	
	lbl.text = txt

func _update_weapon_swap_hud(p_name: String):
	if _weapon_swap_panel != null:
		_weapon_swap_panel.queue_free()
		
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.player_weapon_loadouts.has(p_name): return
	
	_weapon_swap_panel = PanelContainer.new()
	_weapon_swap_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_weapon_swap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_weapon_swap_panel.offset_right = -25
	_weapon_swap_panel.offset_top = 25
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_corner_radius_all(8)
	style.content_margin_left = 15; style.content_margin_right = 15
	style.content_margin_top = 10; style.content_margin_bottom = 15
	_weapon_swap_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_weapon_swap_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "EQUIPAR ARMA (Próxima Ronda)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	
	var loadout = gm.player_weapon_loadouts[p_name]
	var current_equipped = gm.player_modifiers.get(p_name)
	
	for w in loadout:
		var btn = Button.new()
		var is_equipped = (current_equipped != null and w.modifier_name == current_equipped.modifier_name)
		btn.text = "★ " + w.modifier_name.to_upper() if is_equipped else w.modifier_name.to_upper()
		btn.custom_minimum_size = Vector2(100, 35)
		
		var bs = StyleBoxFlat.new()
		bs.bg_color = w.icon_color * 0.4 if is_equipped else Color(0.1, 0.1, 0.1)
		bs.set_border_width_all(2 if is_equipped else 1)
		bs.border_color = w.icon_color if is_equipped else Color(0.3, 0.3, 0.3)
		bs.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_color_override("font_color", Color(1,1,1) if is_equipped else Color(0.6,0.6,0.6))
		
		btn.pressed.connect(func():
			gm.player_modifiers[p_name] = w
			_update_weapon_swap_hud(p_name)
		)
		hbox.add_child(btn)
		
	add_child(_weapon_swap_panel)

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

func _create_card(ability: AbilityResource, index: int) -> PanelContainer:
	# PanelContainer para que el contenido se clipee automáticamente
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(165, 0)
	
	# Estilo de la carta
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 2
	style.border_width_bottom = 1
	style.border_color = ability.icon_color * Color(1, 1, 1, 0.5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	
	# Contenedor principal de la carta
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# === NOMBRE ===
	var name_label = Label.new()
	name_label.text = ability.ability_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", ability.icon_color)
	name_label.clip_text = true
	vbox.add_child(name_label)
	
	# === LÍNEA DE COLOR ===
	var color_line = ColorRect.new()
	color_line.color = ability.icon_color * Color(1, 1, 1, 0.4)
	color_line.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(color_line)
	
	# === DESCRIPCIÓN ===
	var desc_label = RichTextLabel.new()
	desc_label.text = ability.description if ability.description != "" else "Sin descripción"
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = false
	desc_label.custom_minimum_size = Vector2(0, 35)
	desc_label.add_theme_font_size_override("normal_font_size", 11)
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
	
	if ability.bonus_damage != 0:
		_add_stat(stats_grid, "DMG", ("+" if ability.bonus_damage > 0 else "") + str(ability.bonus_damage), Color(1.0, 0.5, 0.4))
	if ability.damage_multiplier != 1.0:
		_add_stat(stats_grid, "DMG x", str(ability.damage_multiplier), Color(1.0, 0.4, 0.3))
	if ability.bonus_speed != 0:
		_add_stat(stats_grid, "VEL", ("+" if ability.bonus_speed > 0 else "") + str(ability.bonus_speed), Color(0.5, 0.8, 1.0))
	if ability.cooldown_reduction > 0:
		_add_stat(stats_grid, "CD", "-" + str(ability.cooldown_reduction) + "s", Color(0.9, 0.85, 0.4))
	if ability.shield_per_round > 0:
		_add_stat(stats_grid, "ESCUDO", "+" + str(ability.shield_per_round), Color(0.4, 0.9, 0.9))
	if ability.lifesteal_percent > 0:
		_add_stat(stats_grid, "ROBO HP", str(ability.lifesteal_percent * 100) + "%", Color(1.0, 0.3, 0.5))
	if ability.bonus_pierce > 0:
		_add_stat(stats_grid, "PIERCE", "+" + str(ability.bonus_pierce), Color(0.7, 0.5, 1.0))
	if ability.bonus_bullet_count > 0:
		_add_stat(stats_grid, "BALAS", "+" + str(ability.bonus_bullet_count), Color(1.0, 0.7, 0.3))
	if ability.damage_on_tick > 0:
		_add_stat(stats_grid, "VENENO", str(ability.damage_on_tick) + "/s", Color(0.2, 0.9, 0.2))
	if ability.health_regen_per_second > 0:
		_add_stat(stats_grid, "REGEN", "+" + str(ability.health_regen_per_second) + "/s", Color(0.4, 1.0, 0.6))
	if ability.bonus_max_health > 0:
		_add_stat(stats_grid, "MAX HP", "+" + str(ability.bonus_max_health), Color(0.9, 0.2, 0.2))
	if ability.dash_cooldown_reduction > 0:
		_add_stat(stats_grid, "DASH CD", "-" + str(ability.dash_cooldown_reduction) + "s", Color(0.7, 0.9, 1.0))
	
	# === ESPACIADOR FLEXIBLE ===
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# === BOTÓN ELEGIR ===
	var btn = Button.new()
	btn.text = "ELEGIR"
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(0, 30)
	
	var btn_normal = _make_stylebox(
		ability.icon_color * Color(0.35, 0.35, 0.35, 0.85),
		ability.icon_color * Color(0.6, 0.6, 0.6, 0.5)
	)
	btn.add_theme_stylebox_override("normal", btn_normal)
	
	var btn_hover = _make_stylebox(
		ability.icon_color * Color(0.5, 0.5, 0.5, 0.95),
		ability.icon_color * Color(0.8, 0.8, 0.8, 0.8)
	)
	btn.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = _make_stylebox(
		ability.icon_color * Color(0.25, 0.25, 0.25, 0.9),
		ability.icon_color * Color(0.5, 0.5, 0.5, 0.6)
	)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	
	btn.pressed.connect(_on_card_selected.bind(index))
	vbox.add_child(btn)
	
	return card

# === HELPERS ===

func _add_stat(grid: GridContainer, label_text: String, value_text: String, color: Color):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	lbl.clip_text = true
	grid.add_child(lbl)
	
	var val = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 12)
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
