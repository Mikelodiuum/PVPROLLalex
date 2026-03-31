extends CanvasLayer

## Menú de equipamiento. El jugador elige 3 armas para su loadout.
## Accesible desde el menú principal. El loadout persiste entre partidas.

signal equipment_confirmed()
signal equipment_cancelled()

@onready var selection_label = $MainPanel/VBoxContainer/SelectionLabel
@onready var weapons_grid    = $MainPanel/VBoxContainer/ScrollContainer/WeaponsGrid
@onready var confirm_button  = $MainPanel/VBoxContainer/BottomBar/ConfirmButton
@onready var back_button     = $MainPanel/VBoxContainer/BottomBar/BackButton

const WEAPON_PATHS := [
	"res://scenes/combat/modifiers/bullet_normal.tres",
	"res://scenes/combat/modifiers/bullet_fast.tres",
	"res://scenes/combat/modifiers/bullet_heavy.tres",
	"res://scenes/combat/modifiers/bullet_shotgun.tres",
	"res://scenes/combat/modifiers/bullet_sniper.tres",
	"res://scenes/combat/modifiers/bullet_toxic.tres",
	"res://scenes/combat/modifiers/bullet_burst.tres",
	"res://scenes/combat/modifiers/bullet_explosive.tres",
]

var _all_weapons: Array = []
var _selected: Array  = []   # indices into _all_weapons (ordered = loadout order)
var _cards: Array     = []

# === CICLO ===

func _ready():
	confirm_button.pressed.connect(_on_confirm)
	back_button.pressed.connect(_on_back)
	_load_weapons()
	visible = false

func show_menu():
	_load_weapons()
	_load_current_loadout()
	_build_cards()
	_update_ui()
	visible = true

# === DATOS ===

func _load_weapons():
	_all_weapons.clear()
	for path in WEAPON_PATHS:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is BulletModifier:
				_all_weapons.append(res)

func _load_current_loadout():
	_selected.clear()
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or not gm.player_loadouts.has("Player1"):
		return
	for weapon in gm.player_loadouts["Player1"]:
		for i in _all_weapons.size():
			if _all_weapons[i].modifier_name == weapon.modifier_name:
				if not _selected.has(i):
					_selected.append(i)
				break

# === TARJETAS ===

func _build_cards():
	for c in _cards:
		if is_instance_valid(c): c.queue_free()
	_cards.clear()
	for i in _all_weapons.size():
		var card = _make_card(_all_weapons[i], i)
		weapons_grid.add_child(card)
		_cards.append(card)

func _make_card(modifier: BulletModifier, index: int) -> PanelContainer:
	var col = modifier.icon_color if modifier else Color.WHITE

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 210)

	var sty = StyleBoxFlat.new()
	sty.set_corner_radius_all(12)
	sty.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	sty.border_width_left = 2; sty.border_width_right  = 2
	sty.border_width_top  = 2; sty.border_width_bottom = 2
	sty.border_color = col * Color(1, 1, 1, 0.3)
	sty.content_margin_left = 12; sty.content_margin_right  = 12
	sty.content_margin_top  = 12; sty.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sty)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Badge slot
	var badge = Label.new()
	badge.name = "Badge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1))
	vbox.add_child(badge)

	# Nombre
	var nl = Label.new()
	nl.text = modifier.modifier_name.to_upper()
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", 17)
	nl.add_theme_color_override("font_color", col)
	nl.clip_text = true
	vbox.add_child(nl)

	var line = ColorRect.new()
	line.color = col * Color(1, 1, 1, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(line)

	# Stats
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(grid)
	_stat(grid, "DMG", str(modifier.damage),         Color(1.0, 0.5, 0.4))
	_stat(grid, "CD",  str(modifier.cooldown) + "s", Color(0.9, 0.85, 0.4))
	_stat(grid, "VEL", str(int(modifier.speed)),     Color(0.5, 0.8, 1.0))
	if modifier.bullet_count > 1:
		_stat(grid, "BALAS", str(modifier.bullet_count), Color(1.0, 0.7, 0.3))

	var sp = Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sp)

	# Botón toggle
	var btn = Button.new()
	btn.name = "ToggleBtn"
	btn.text = "EQUIPAR"
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(_on_toggle.bind(index))
	vbox.add_child(btn)

	return card

# === EVENTOS ===

func _on_toggle(index: int):
	var gm = get_node_or_null("/root/GameManager")
	var max_w = 3
	if gm and gm.config: max_w = gm.config.weapons_per_loadout

	if _selected.has(index):
		_selected.erase(index)
	elif _selected.size() < max_w:
		_selected.append(index)
	_update_ui()

func _on_confirm():
	var loadout = []
	for idx in _selected:
		loadout.append(_all_weapons[idx])
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.player_loadouts["Player1"] = loadout
		print("Loadout guardado: ", loadout.map(func(w): return w.modifier_name))
	equipment_confirmed.emit()
	visible = false

func _on_back():
	equipment_cancelled.emit()
	visible = false

# === UI REFRESH ===

func _update_ui():
	var gm = get_node_or_null("/root/GameManager")
	var max_w = 3
	if gm and gm.config: max_w = gm.config.weapons_per_loadout

	selection_label.text = "Seleccionadas: %d / %d" % [_selected.size(), max_w]
	confirm_button.disabled = (_selected.size() != max_w)

	for i in _cards.size():
		var card = _cards[i]
		if not is_instance_valid(card): continue
		var is_sel = _selected.has(i)
		var modifier = _all_weapons[i]
		var col = modifier.icon_color if modifier else Color.WHITE

		# Actualizar estilo del panel
		var sty = StyleBoxFlat.new()
		sty.set_corner_radius_all(12)
		sty.content_margin_left = 12; sty.content_margin_right  = 12
		sty.content_margin_top  = 12; sty.content_margin_bottom = 12
		if is_sel:
			sty.bg_color = Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.95)
			sty.border_width_left = 3; sty.border_width_right  = 3
			sty.border_width_top  = 3; sty.border_width_bottom = 3
			sty.border_color = col
		else:
			sty.bg_color = Color(0.1, 0.1, 0.15, 0.95)
			sty.border_width_left = 2; sty.border_width_right  = 2
			sty.border_width_top  = 2; sty.border_width_bottom = 2
			sty.border_color = col * Color(1, 1, 1, 0.3)
		card.add_theme_stylebox_override("panel", sty)

		# Actualizar badge y botón
		var vbox = card.get_child(0) if card.get_child_count() > 0 else null
		if vbox == null: continue
		var badge = vbox.get_node_or_null("Badge")
		if badge:
			if is_sel:
				badge.text = "✓ RANURA " + str(_selected.find(i) + 1)
			else:
				badge.text = ""
		var btn = vbox.get_node_or_null("ToggleBtn")
		if btn:
			var full = _selected.size() >= max_w
			if is_sel:
				btn.text     = "QUITAR"
				btn.disabled = false
			else:
				btn.text     = "LLENO" if full else "EQUIPAR"
				btn.disabled = full

# === HELPERS ===

func _stat(grid: GridContainer, lbl: String, val: String, col: Color):
	var l = Label.new()
	l.text = lbl; l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5)); l.clip_text = true
	grid.add_child(l)
	var v = Label.new()
	v.text = val; v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", col); v.clip_text = true
	grid.add_child(v)
