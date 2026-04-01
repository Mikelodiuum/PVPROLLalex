extends Control

var pool: Array = []
var selected_options: Array = []
var confirm_button: Button

func _ready():
	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.position = get_viewport_rect().size / 2.0
		
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		pool = gm.global_weapon_pool.duplicate()

	_build_ui()

func _build_ui():
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.05, 1.0)
	add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	var tit = Label.new()
	tit.text = "ELIGE TUS 3 ARMAS INICIALES"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 32)
	tit.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	vbox.add_child(tit)
	
	var sub = Label.new()
	sub.text = "Haz clic para seleccionar o quitar las armas.\nEste será tu loadout intercambiable para el resto del combate."
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	
	var grid_center = CenterContainer.new()
	vbox.add_child(grid_center)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid_center.add_child(grid)
	
	for w in pool:
		grid.add_child(_build_card(w))
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	confirm_button = Button.new()
	confirm_button.text = "EMPEZAR BATALLA (0/3)"
	confirm_button.custom_minimum_size = Vector2(300, 60)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.4, 0.15, 0.9)
	bs.set_corner_radius_all(10)
	confirm_button.add_theme_stylebox_override("normal", bs)
	confirm_button.add_theme_font_size_override("font_size", 22)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm)
	vbox.add_child(confirm_button)

func _build_card(weapon: BulletModifier) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(180, 220)
	
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.1, 1)
	s.set_border_width_all(2)
	s.border_color = weapon.icon_color * 0.5
	s.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", s)
	
	# Hover
	var sh = s.duplicate()
	sh.bg_color = Color(0.12, 0.12, 0.15, 1)
	sh.border_color = weapon.icon_color * 0.8
	btn.add_theme_stylebox_override("hover", sh)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	btn.add_child(vbox)
	
	var spc = Control.new(); spc.custom_minimum_size = Vector2(0, 5)
	spc.mouse_filter = Control.MOUSE_FILTER_IGNORE; vbox.add_child(spc)
	
	var lbl = Label.new()
	lbl.text = weapon.modifier_name.to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", weapon.icon_color)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)
	
	var center_grid = CenterContainer.new()
	center_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(center_grid)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_grid.add_child(grid)
	
	_add_stat(grid, "DMG:", str(weapon.damage), Color(1, 0.5, 0.5))
	_add_stat(grid, "VEL:", str(int(weapon.speed)), Color(0.5, 0.8, 1))
	if weapon.pierce > 1: _add_stat(grid, "PRC:", str(weapon.pierce), Color(0.8, 0.5, 1))
	if weapon.bullet_count > 1: _add_stat(grid, "BLT:", str(weapon.bullet_count), Color(1, 0.7, 0.3))
	
	var state_lbl = Label.new()
	state_lbl.name = "StateLabel"
	state_lbl.text = "CLICK PARA AÑADIR"
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	state_lbl.add_theme_font_size_override("font_size", 12)
	state_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	vbox.add_child(Control.new()) # Spacer automatically ignoring mouse
	vbox.add_child(state_lbl)
	
	btn.pressed.connect(_on_card_clicked.bind(weapon, btn, state_lbl))
	return btn

func _add_stat(grid, l_txt, v_txt, col):
	var l=Label.new(); l.text=l_txt; l.add_theme_font_size_override("font_size", 14); l.add_theme_color_override("font_color", Color(0.5,0.5,0.5)); l.mouse_filter=Control.MOUSE_FILTER_IGNORE; grid.add_child(l)
	var v=Label.new(); v.text=v_txt; v.add_theme_font_size_override("font_size", 14); v.add_theme_color_override("font_color", col); v.mouse_filter=Control.MOUSE_FILTER_IGNORE; grid.add_child(v)

func _on_card_clicked(weapon: BulletModifier, btn: Button, lbl: Label):
	var s = btn.get_theme_stylebox("normal").duplicate()
	
	if weapon in selected_options:
		selected_options.erase(weapon)
		lbl.text = "CLICK PARA AÑADIR"
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		s.bg_color = Color(0.08, 0.08, 0.1, 1)
	else:
		if selected_options.size() < 3:
			selected_options.append(weapon)
			lbl.text = "¡EQUIPADA!"
			lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			s.bg_color = weapon.icon_color * 0.4
	
	btn.add_theme_stylebox_override("normal", s)
	
	if selected_options.size() == 3:
		confirm_button.text = "EMPEZAR BATALLA"
		confirm_button.disabled = false
		var cs = confirm_button.get_theme_stylebox("normal").duplicate()
		cs.bg_color = Color(0.2, 0.8, 0.3, 1)
		confirm_button.add_theme_stylebox_override("normal", cs)
	else:
		confirm_button.text = "ELEGIDAS (" + str(selected_options.size()) + "/3)"
		confirm_button.disabled = true
		var cs = confirm_button.get_theme_stylebox("normal").duplicate()
		cs.bg_color = Color(0.1, 0.4, 0.15, 0.9)
		confirm_button.add_theme_stylebox_override("normal", cs)

func _on_confirm():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.player_weapon_loadouts["Player1"] = selected_options.duplicate()
		
		var cpu_pool = pool.duplicate()
		cpu_pool.shuffle()
		gm.player_weapon_loadouts["Player2"] = [cpu_pool[0], cpu_pool[1], cpu_pool[2]] if cpu_pool.size() >= 3 else cpu_pool.duplicate()
	
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
