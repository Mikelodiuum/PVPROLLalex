extends CanvasLayer

## Interfaz de Selección de Armas
## Se inyecta dinámicamente y puede operar en dos modos:
## DRAFT: El jugador selecciona 3 armas iniciales de entre todas las disponibles.
## EQUIP: El jugador selecciona 1 arma de su loadout para la próxima ronda.

signal draft_completed(loadout: Array)
signal equip_completed(weapon: BulletModifier)

enum Mode { DRAFT, EQUIP }

var current_mode = Mode.DRAFT
var player_name := ""
var options: Array = []
var selected_options: Array = []

var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var cards_box: Container
var confirm_button: Button

func setup_draft(p_name: String, all_weapons: Array):
	current_mode = Mode.DRAFT
	player_name = p_name
	options = all_weapons.duplicate()
	selected_options.clear()
	_build_ui()

func setup_equip(p_name: String, loadout: Array):
	current_mode = Mode.EQUIP
	player_name = p_name
	options = loadout.duplicate()
	selected_options.clear()
	_build_ui()

func _build_ui():
	# Limpiar si ya existe
	for c in get_children():
		c.queue_free()
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 0.95)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.6, 0.2)
	style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	style.corner_radius_top_left = 12; style.corner_radius_top_right = 12
	style.content_margin_left = 30; style.content_margin_right = 30
	style.content_margin_top = 20; style.content_margin_bottom = 25
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle_label)
	
	if current_mode == Mode.DRAFT:
		title_label.text = player_name + " - CREA TU LOADOUT"
		subtitle_label.text = "Selecciona 3 armas para tu inventario global."
	else:
		title_label.text = player_name + " - EQUIPA TU ARMA"
		subtitle_label.text = "Selecciona el arma con la que saldrás esta ronda."
		
	# Para el draft, usamos GridContainer ya que hay muchas armas.
	# Para el equip (solo 3), usamos HBoxContainer.
	if current_mode == Mode.DRAFT:
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(800, 400)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vbox.add_child(scroll)
		
		var grid = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 15)
		grid.add_theme_constant_override("v_separation", 15)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		cards_box = grid
	else:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(hbox)
		cards_box = hbox
		
	_populate_cards()
	
	if current_mode == Mode.DRAFT:
		confirm_button = Button.new()
		confirm_button.text = "CONFIRMAR DRAFT (0/3)"
		confirm_button.custom_minimum_size = Vector2(250, 50)
		confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.5, 0.2)
		btn_style.corner_radius_bottom_left = 8; btn_style.corner_radius_bottom_right = 8
		btn_style.corner_radius_top_left = 8; btn_style.corner_radius_top_right = 8
		confirm_button.add_theme_stylebox_override("normal", btn_style)
		confirm_button.add_theme_font_size_override("font_size", 18)
		confirm_button.disabled = true
		confirm_button.pressed.connect(_on_confirm_pressed)
		vbox.add_child(confirm_button)

func _populate_cards():
	for i in options.size():
		var weapon = options[i]
		var card = _create_weapon_card(weapon, i)
		cards_box.add_child(card)

func _create_weapon_card(weapon: BulletModifier, index: int) -> Control:
	var pc = PanelContainer.new()
	pc.custom_minimum_size = Vector2(170, 220)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = weapon.icon_color * Color(0.8, 0.8, 0.8)
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 10; style.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)
	
	var title = Label.new()
	title.text = weapon.modifier_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", weapon.icon_color)
	title.add_theme_font_size_override("font_size", 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)
	
	var lin = ColorRect.new()
	lin.custom_minimum_size = Vector2(0, 2)
	lin.color = weapon.icon_color * 0.5
	vbox.add_child(lin)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	vbox.add_child(grid)
	
	_add_stat(grid, "DMG:", str(weapon.damage), Color(1, 0.6, 0.6))
	_add_stat(grid, "VEL:", str(int(weapon.speed)), Color(0.6, 0.8, 1))
	_add_stat(grid, "CD:", str(weapon.cooldown)+"s", Color(1, 0.9, 0.5))
	
	if weapon.pierce > 1: _add_stat(grid, "PRC:", str(weapon.pierce), Color(0.8, 0.5, 1))
	if weapon.bullet_count > 1: _add_stat(grid, "BLT:", str(weapon.bullet_count), Color(1, 0.7, 0.3))
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	var btn = Button.new()
	btn.text = "ELEGIR" if current_mode == Mode.EQUIP else "SELECCIONAR"
	btn.custom_minimum_size = Vector2(0, 35)
	
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = weapon.icon_color * 0.3
	b_style.border_width_left = 1; b_style.border_width_right = 1; b_style.border_width_top = 1; b_style.border_width_bottom = 1
	b_style.border_color = weapon.icon_color
	b_style.corner_radius_bottom_left = 4; b_style.corner_radius_bottom_right = 4
	b_style.corner_radius_top_left = 4; b_style.corner_radius_top_right = 4
	btn.add_theme_stylebox_override("normal", b_style)
	
	btn.pressed.connect(_on_card_clicked.bind(weapon, pc, btn))
	vbox.add_child(btn)
	
	return pc

func _add_stat(grid: GridContainer, lbl: String, val: String, col: Color):
	var l = Label.new()
	l.text = lbl
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.5,0.5,0.5))
	grid.add_child(l)
	var v = Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", col)
	grid.add_child(v)

func _on_card_clicked(weapon: BulletModifier, pc: PanelContainer, btn: Button):
	if current_mode == Mode.EQUIP:
		equip_completed.emit(weapon)
		queue_free()
	else:
		if weapon in selected_options:
			selected_options.erase(weapon)
			btn.text = "SELECCIONAR"
			var s = pc.get_theme_stylebox("panel").duplicate()
			s.bg_color = Color(0.15, 0.15, 0.18, 1.0)
			pc.add_theme_stylebox_override("panel", s)
		else:
			if selected_options.size() < 3:
				selected_options.append(weapon)
				btn.text = "DESMARCAR"
				var s = pc.get_theme_stylebox("panel").duplicate()
				s.bg_color = weapon.icon_color * 0.6
				pc.add_theme_stylebox_override("panel", s)
		
		confirm_button.text = "CONFIRMAR DRAFT (" + str(selected_options.size()) + "/3)"
		confirm_button.disabled = (selected_options.size() != 3)

func _on_confirm_pressed():
	if selected_options.size() == 3:
		draft_completed.emit(selected_options)
		queue_free()
