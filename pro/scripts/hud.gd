class_name Hud
extends Control
## Interface de Pokémon Revolution Online reproduite à l'écran (1920 x 1080) :
## équipe en haut à gauche, heure locale / heure Poké et lieu en haut à droite, menu circulaire en bas à gauche,
## argent et barre de raccourcis en bas, discussion à onglets en bas à droite, étiquette des autres joueurs.

signal chat_focus_changed(focused: bool)
signal menu_pressed(what: String)

const PANEL := Color8(48, 52, 58, 235)
const PANEL_DARK := Color8(32, 35, 40, 245)
const EDGE := Color8(20, 22, 26)
const RIM := Color8(96, 100, 108)
const TEXT := Color8(236, 238, 242)

## Équipe (comme sur la capture) : icône, nom, sexe, niveau, PV et expérience (0 à 1).
var party := [
	{"id": 5, "name": "Charmeleon", "male": true, "lv": 17, "hp": 0.86, "xp": 0.88},
	{"id": 162, "name": "Furret", "male": false, "lv": 8, "hp": 1.0, "xp": 0.18},
	{"id": 161, "name": "Sentret", "male": false, "lv": 3, "hp": 1.0, "xp": 0.0},
	{"id": 25, "name": "Pikachu", "male": true, "lv": 7, "hp": 1.0, "xp": 0.0},
	{"id": 69, "name": "Bellsprout", "male": false, "lv": 7, "hp": 1.0, "xp": 0.0},
]
var money := 30286
var location := "Route 1"
var player_name := "Sacha"

var f_pix: FontVariation
var f_ui: FontVariation
var f_ui_b: FontVariation
var f_time: FontVariation
var f_px: FontVariation   # Arial sans lissage : les petits textes nets de PRO
var _t1: Label
var _t2: Label
var _loc: Label
var _dn_icon: TextureRect
var _glow: TextureRect
var _chat: RichTextLabel
var _input: LineEdit
var _tabs: Control
var _tab := "Local"
var _lines: Array = []
var _dialog: Control
var _dialog_text: Label
var _toast: Label
var _tags := {}
var _night := true


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_pix = _font("PixelifySans", 500)
	f_ui = _font("Arimo", 400)
	f_ui_b = _font("Arimo", 700)
	f_time = _font("Arimo", 700)
	f_time.spacing_glyph = 1
	var crisp: FontFile = (load("res://assets/fonts/Arimo.ttf") as FontFile).duplicate()
	crisp.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	crisp.hinting = TextServer.HINTING_NORMAL
	f_px = FontVariation.new()
	f_px.base_font = crisp
	f_px.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 400}
	_build_party()
	_build_top_right()
	_build_left_menu()
	_build_bottom_bar()
	_build_chat()
	_build_dialog()
	var now := _clock()
	add_chat("System", "[color=#3ce83c]System: Welcome to Pokemon Revolution! (Silver Server)[/color]", now)
	add_chat("Battle", "[color=#3cc8ff](Battle) Mvtson: holy f[/color]", now)


func _font(file: String, weight: int) -> FontVariation:
	var base: FontFile = load("res://assets/fonts/%s.ttf" % file)
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


# ---------------------------------------------------------------------------------------------------------------
# Outils de dessin
# ---------------------------------------------------------------------------------------------------------------

func _shape(r: Rect2, fn: Callable, parent: Node = self) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(fn.bind(c))
	parent.add_child(c)
	return c


func _box(c: CanvasItem, r: Rect2, col: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	c.draw_style_box(sb, r)


func _label(parent: Node, text: String, pos: Vector2, fsize: int, col: Color, font: Font, outline := 0,
		ocol := Color(0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", ocol)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _icon(parent: Node, path: String, center: Vector2, sz: float, smooth := true) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = Vector2(sz, sz)
	t.position = center - Vector2(sz, sz) / 2
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


## Bouton rond de PRO : anneau sombre, bord clair, fond dégradé.
func _round_button(c: Control, center: Vector2, r: float) -> void:
	c.draw_circle(center + Vector2(0, 1.5), r + 1.5, Color(0, 0, 0, 0.45))
	c.draw_circle(center, r, Color8(30, 33, 38))
	c.draw_circle(center, r - 2, Color8(70, 74, 82))
	c.draw_circle(center + Vector2(0, 1), r - 3.5, Color8(46, 50, 56))
	c.draw_arc(center, r - 2.5, PI * 1.1, PI * 1.9, 24, Color8(120, 124, 132, 160), 1.5, true)


# ---------------------------------------------------------------------------------------------------------------
# Équipe (haut gauche)
# ---------------------------------------------------------------------------------------------------------------

func _build_party() -> void:
	for i in party.size():
		var p: Dictionary = party[i]
		var y := 10 + i * 54
		var slot := _shape(Rect2(8, y, 150, 52), func(c: Control): _draw_slot(p, c))
		var ico := TextureRect.new()
		ico.texture = load("res://assets/icons/%d.png" % p["id"])
		ico.position = Vector2(32 - 34, 25 - 42)
		ico.size = Vector2(68, 56)
		ico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ico)
		_label(slot, p["name"], Vector2(62, 5), 15, TEXT, f_px, 4, EDGE)
		_label(slot, "Lv.", Vector2(22, 33), 9, Color8(246, 200, 48), f_ui_b, 3, EDGE)
		_label(slot, str(p["lv"]), Vector2(35, 27), 15, TEXT, f_px, 4, EDGE)


func _draw_slot(p: Dictionary, c: Control) -> void:
	# Plaque arrondie
	_box(c, Rect2(6, 4, 132, 44), Color(0, 0, 0, 0.35), 11)
	_box(c, Rect2(6, 2, 132, 44), PANEL, 11, EDGE, 1)
	c.draw_line(Vector2(40, 4), Vector2(130, 4), Color8(92, 96, 104, 200), 1.5)
	# Médaillon de l'icône
	var ctr := Vector2(32, 25)
	c.draw_circle(ctr + Vector2(0, 1.5), 25, Color(0, 0, 0, 0.4))
	c.draw_circle(ctr, 24, EDGE)
	c.draw_circle(ctr, 22.5, Color8(58, 62, 70))
	var top := PackedVector2Array()
	for k in 25:
		var a := PI + k * PI / 24
		top.append(ctr + Vector2(cos(a), sin(a)) * 22.5)
	c.draw_colored_polygon(top, Color8(86, 90, 98))
	c.draw_line(ctr + Vector2(-22, 0), ctr + Vector2(22, 0), Color8(124, 128, 136), 2.0)
	# Sexe : symbole dessiné, épais, avec contour sombre
	_gender(c, Vector2(15, 34), p["male"])
	# PV : étiquette dorée, barre verte fine
	_box(c, Rect2(52, 28, 14, 8), Color8(214, 160, 40), 2, Color8(110, 74, 16), 1)
	c.draw_string(f_ui_b, Vector2(53.5, 35), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color8(92, 56, 8))
	_box(c, Rect2(66, 29, 62, 6), Color8(64, 68, 76), 3, EDGE, 1)
	var hp: float = p["hp"]
	var col := Color8(96, 210, 76) if hp > 0.5 else (Color8(246, 196, 40) if hp > 0.2 else Color8(232, 64, 48))
	if hp > 0.0:
		_box(c, Rect2(67, 30.5, 60 * hp, 3), col, 1)
	# Expérience
	_box(c, Rect2(62, 37, 56, 4), Color8(70, 74, 82), 2, EDGE, 1)
	var xp: float = p["xp"]
	if xp > 0.0:
		_box(c, Rect2(63, 38, 54 * xp, 2), Color8(64, 156, 236), 1)


func _gender(c: Control, at: Vector2, male: bool) -> void:
	var col := Color8(70, 180, 246) if male else Color8(244, 96, 180)
	for pass_i in 2:
		var w := 4.2 if pass_i == 0 else 2.0
		var cc := EDGE if pass_i == 0 else col
		if male:
			c.draw_arc(at + Vector2(-1, 1), 3.2, 0, TAU, 20, cc, w, true)
			c.draw_line(at + Vector2(1.5, -1.5), at + Vector2(5, -5), cc, w, true)
			c.draw_line(at + Vector2(2, -5), at + Vector2(5, -5), cc, w, true)
			c.draw_line(at + Vector2(5, -5), at + Vector2(5, -2), cc, w, true)
		else:
			c.draw_arc(at + Vector2(0, -2), 3.2, 0, TAU, 20, cc, w, true)
			c.draw_line(at + Vector2(0, 1.5), at + Vector2(0, 7), cc, w, true)
			c.draw_line(at + Vector2(-2.5, 4.5), at + Vector2(2.5, 4.5), cc, w, true)


# ---------------------------------------------------------------------------------------------------------------
# Haut droite : carte, sac, heures, lune / soleil, lieu
# ---------------------------------------------------------------------------------------------------------------

func _build_top_right() -> void:
	_glow = _icon(self, "res://assets/hud/glow.png", Vector2(1749, 19), 104)
	var tw := create_tween().set_loops()
	_glow.modulate = Color(1.3, 1.3, 1.3)
	tw.tween_property(_glow, "modulate:a", 0.75, 1.2)
	tw.tween_property(_glow, "modulate:a", 1.0, 1.2)
	_shape(Rect2(1660, 0, 260, 70), _draw_top_right)
	_icon(self, "res://assets/hud/map.png", Vector2(1702, 19), 28)
	_icon(self, "res://assets/hud/bag.png", Vector2(1749, 19), 28)
	_dn_icon = _icon(self, "res://assets/hud/moon.png", Vector2(1900, 19), 30)
	_t1 = _label(self, "Local Time: 00:00", Vector2(1781, 2), 11, TEXT, f_time, 3, EDGE)
	_t2 = _label(self, "Poké Time: 00:00", Vector2(1781, 14), 11, TEXT, f_time, 3, EDGE)
	_loc = _label(self, location, Vector2(1640, 41), 17, Color.WHITE, f_ui_b, 6, Color8(10, 10, 14))
	_loc.size = Vector2(275, 24)
	_loc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Languette du bord droit
	_shape(Rect2(1900, 88, 20, 64), func(c: Control):
		_box(c, Rect2(6, 0, 20, 64), PANEL, 7, EDGE, 1))
	_icon(self, "res://assets/hud/arrow_left.png", Vector2(1912, 120), 12)
	for b in [[Vector2(1702, 19), "carte"], [Vector2(1749, 19), "sac"]]:
		_hotspot(Rect2(b[0] - Vector2(19, 19), Vector2(38, 38)), b[1])


func _draw_top_right(c: Control) -> void:
	var o := Vector2(-1660, 0)
	_round_button(c, Vector2(1702, 19) + o, 19)
	_round_button(c, Vector2(1749, 19) + o, 19)
	# Plaque des heures en biseau + étagère dessous
	var shelf := PackedVector2Array([Vector2(1792, 27) + o, Vector2(1892, 27) + o, Vector2(1892, 37) + o, Vector2(1800, 37) + o])
	c.draw_colored_polygon(shelf, Color8(40, 44, 50, 245))
	c.draw_polyline(shelf + PackedVector2Array([shelf[0]]), EDGE, 1.0, true)
	var plate := PackedVector2Array([Vector2(1770, -1) + o, Vector2(1892, -1) + o, Vector2(1892, 28) + o, Vector2(1786, 28) + o,
		Vector2(1774, 20) + o])
	c.draw_colored_polygon(plate, PANEL)
	c.draw_polyline(plate, EDGE, 1.2, true)
	c.draw_line(Vector2(1776, 1) + o, Vector2(1890, 1) + o, Color8(96, 100, 108), 1.0)
	_round_button(c, Vector2(1900, 19) + o, 18)


# ---------------------------------------------------------------------------------------------------------------
# Menu en arc (bas gauche)
# ---------------------------------------------------------------------------------------------------------------

const MENU := [["PvP", "pvp", Vector2(28, 822)], ["Backpack", "backpack", Vector2(22, 870)],
	["Pokedex", "pokedex", Vector2(21, 920)], ["Trainer", "trainer", Vector2(35, 968)], ["Social", "social", Vector2(54, 1015)]]


func _build_left_menu() -> void:
	_shape(Rect2(0, 780, 200, 300), _draw_left_menu)
	for m in MENU:
		var ctr: Vector2 = m[2]
		_label(self, m[0], ctr + Vector2(19, 2), 15, TEXT, f_px, 4, EDGE)
		_icon(self, "res://assets/hud/%s.png" % m[1], ctr, 28)
		_hotspot(Rect2(ctr - Vector2(20, 20), Vector2(110, 40)), m[1])


func _draw_left_menu(c: Control) -> void:
	var o := Vector2(0, -780)
	var arc := PackedVector2Array([Vector2(0, 798), Vector2(26, 796), Vector2(40, 806)])
	for k in 13:
		var t := k / 12.0
		arc.append(Vector2(40 + 8 * sin(t * PI * 0.9) + 26 * t * t, 806 + t * 236))
	arc.append(Vector2(0, 1046))
	var pts := PackedVector2Array()
	for p in arc:
		pts.append(p + o)
	c.draw_colored_polygon(pts, Color8(58, 62, 70, 230))
	c.draw_polyline(pts, EDGE, 1.5, true)
	for m in MENU:
		var ctr: Vector2 = m[2] + o
		var poly := PackedVector2Array([ctr + Vector2(10, 3), ctr + Vector2(108, 3), ctr + Vector2(100, 20), ctr + Vector2(6, 20)])
		c.draw_polygon(poly, PackedColorArray([Color8(176, 178, 184, 235), Color8(150, 152, 158, 0), Color8(120, 122, 128, 0), Color8(120, 122, 128, 235)]))
		_round_button(c, ctr, 20)


# ---------------------------------------------------------------------------------------------------------------
# Barre du bas : menu, argent, raccourcis 1 à 6, cadenas
# ---------------------------------------------------------------------------------------------------------------

func _build_bottom_bar() -> void:
	_shape(Rect2(0, 1030, 420, 50), _draw_bottom_bar)
	_icon(self, "res://assets/hud/menu.png", Vector2(17, 1066), 24)
	var m := _label(self, "₽ " + _thousands(money), Vector2(36, 1056), 14, TEXT, f_ui_b, 2, EDGE)
	m.size = Vector2(98, 20)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 6:
		_label(self, str(i + 1), Vector2(169 + i * 36, 1060), 13, TEXT, f_ui_b, 3, EDGE)
	_icon(self, "res://assets/hud/lock.png", Vector2(381, 1058), 24)
	_hotspot(Rect2(4, 1054, 26, 24), "menu")


func _draw_bottom_bar(c: Control) -> void:
	var o := Vector2(0, -1030)
	var pts := PackedVector2Array()
	for p in [Vector2(0, 1050), Vector2(130, 1050), Vector2(150, 1040), Vector2(390, 1038), Vector2(405, 1048),
			Vector2(408, 1080), Vector2(0, 1080)]:
		pts.append(p + o)
	c.draw_colored_polygon(pts, Color8(52, 56, 62, 240))
	c.draw_polyline(pts, EDGE, 1.5, true)
	c.draw_line(Vector2(2, 1052) + o, Vector2(128, 1052) + o, Color8(96, 100, 108), 1.0)
	_box(c, _ro(Rect2(34, 1055, 100, 22), o), Color8(26, 28, 32), 10, Color8(84, 88, 96), 1)
	for i in 6:
		var r := _ro(Rect2(148 + i * 36, 1044, 32, 32), o)
		_box(c, r, Color8(40, 44, 50), 3, Color8(86, 90, 98), 1)
		c.draw_colored_polygon(PackedVector2Array([r.position + Vector2(18, 31), r.position + Vector2(31, 18), r.position + Vector2(31, 31)]),
			Color8(70, 74, 82))
	_round_button(c, Vector2(381, 1058) + o, 17)


# ---------------------------------------------------------------------------------------------------------------
# Discussion (bas droite)
# ---------------------------------------------------------------------------------------------------------------

const TABS := ["Help", "Other", "Battle", "Trade", "All", "Local"]


func _build_chat() -> void:
	_shape(Rect2(1500, 846, 420, 234), _draw_chat)
	_tabs = Control.new()
	_tabs.position = Vector2(1508, 856)
	_tabs.size = Vector2(412, 20)
	add_child(_tabs)
	for i in TABS.size():
		var l := _label(_tabs, TABS[i], Vector2(i * 67 + 4, 1), 13, TEXT, f_ui, 2, EDGE)
		l.size = Vector2(67, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hit := Control.new()
		hit.position = Vector2(i * 67, 0)
		hit.size = Vector2(67, 20)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_tab = TABS[i]
				queue_redraw_all()
				_refresh_chat())
		_tabs.add_child(hit)
	_icon(self, "res://assets/hud/arrow_down.png", Vector2(1909, 888), 14)
	_chat = RichTextLabel.new()
	_chat.position = Vector2(1513, 884)
	_chat.size = Vector2(390, 166)
	_chat.bbcode_enabled = true
	_chat.scroll_following = true
	_chat.scroll_active = false
	_chat.add_theme_font_override("normal_font", f_ui)
	_chat.add_theme_font_size_override("normal_font_size", 13)
	_chat.add_theme_color_override("default_color", TEXT)
	_chat.add_theme_constant_override("line_separation", 1)
	_chat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chat)
	_input = LineEdit.new()
	_input.position = Vector2(1526, 1055)
	_input.size = Vector2(358, 22)
	_input.placeholder_text = "Press Enter to chat"
	_input.add_theme_font_override("font", f_ui)
	_input.add_theme_font_size_override("font_size", 15)
	_input.add_theme_color_override("font_color", TEXT)
	_input.add_theme_color_override("font_placeholder_color", Color8(150, 154, 162))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(28, 30, 34)
	sb.set_corner_radius_all(9)
	sb.border_color = Color8(80, 84, 92)
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	_input.add_theme_stylebox_override("normal", sb)
	var sbf := sb.duplicate()
	sbf.border_color = Color8(110, 150, 220)
	_input.add_theme_stylebox_override("focus", sbf)
	_input.max_length = 120
	_input.focus_entered.connect(func(): chat_focus_changed.emit(true))
	_input.focus_exited.connect(func(): chat_focus_changed.emit(false))
	_input.text_submitted.connect(_on_submit)
	add_child(_input)
	_icon(self, "res://assets/hud/wrench.png", Vector2(1900, 1066), 20)


func queue_redraw_all() -> void:
	for c in get_children():
		if c is Control:
			c.queue_redraw()


func _draw_chat(c: Control) -> void:
	var o := Vector2(-1500, -846)
	# Fond des messages : bleu nuit en dégradé
	for k in 16:
		var t := k / 15.0
		c.draw_rect(_ro(Rect2(1508, 876 + k * 11, 412, 11), o), Color8(18, 26, 48, 232).lerp(Color8(30, 42, 74, 232), t))
	c.draw_rect(_ro(Rect2(1508, 876, 412, 177), o), Color8(70, 76, 90), false, 1.0)
	# Barre de défilement
	_box(c, _ro(Rect2(1910, 896, 6, 152), o), Color8(40, 46, 62), 3, Color8(76, 82, 98), 1)
	# Onglets
	_box(c, _ro(Rect2(1504, 854, 416, 23), o), Color8(56, 60, 68, 245), 4, EDGE, 1)
	c.draw_line(Vector2(1506, 856) + o, Vector2(1918, 856) + o, Color8(110, 114, 124), 1.0)
	for i in TABS.size():
		var x := 1508 + i * 67
		if TABS[i] == _tab:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x + 8, 855) + o, Vector2(x + 72, 855) + o,
				Vector2(x + 66, 876) + o, Vector2(x + 2, 876) + o]), Color8(24, 54, 116))
		if i > 0:
			c.draw_line(Vector2(x + 8, 857) + o, Vector2(x + 2, 875) + o, Color8(128, 132, 142), 1.0)
	# Barre de saisie
	c.draw_rect(_ro(Rect2(1504, 1052, 416, 28), o), Color8(44, 48, 54, 245))
	c.draw_circle(Vector2(1515, 1066) + o, 6, EDGE)
	c.draw_circle(Vector2(1515, 1066) + o, 4.5, Color8(46, 220, 70))
	c.draw_circle(Vector2(1514, 1065) + o, 1.5, Color8(180, 255, 180))


func add_chat(channel: String, bb: String, time_text := "") -> void:
	var t := time_text if time_text != "" else _clock()
	_lines.append({"ch": channel, "bb": "[%s] %s" % [t, bb]})
	_refresh_chat()


func _refresh_chat() -> void:
	var shown := []
	for l in _lines:
		if _tab in ["All", "Local"] or l["ch"] == _tab or l["ch"] == "System":
			shown.append(l["bb"])
	_chat.text = "\n".join(PackedStringArray(["\n".repeat(12)] + shown))


func _on_submit(text: String) -> void:
	var msg := text.strip_edges()
	_input.text = ""
	if msg != "":
		add_chat("Local", "%s: %s" % [player_name, msg.replace("[", "[lb]")])
	_input.release_focus()


func chat_focused() -> bool:
	return _input.has_focus()


func focus_chat() -> void:
	_input.grab_focus()


# ---------------------------------------------------------------------------------------------------------------
# Heures, jour / nuit
# ---------------------------------------------------------------------------------------------------------------

func set_times(local_text: String, poke_text: String, night: bool) -> void:
	_t1.text = "Local Time: " + local_text
	_t2.text = "Poké Time: " + poke_text
	if night != _night:
		_night = night
		_dn_icon.texture = load("res://assets/hud/moon.png" if night else "res://assets/hud/sun.png")


func set_location(n: String) -> void:
	location = n
	_loc.text = n


func _clock() -> String:
	var d := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [d["hour"], d["minute"], d["second"]]


# ---------------------------------------------------------------------------------------------------------------
# Boîte de dialogue, messages, étiquettes des joueurs
# ---------------------------------------------------------------------------------------------------------------

func _build_dialog() -> void:
	_dialog = _shape(Rect2(560, 880, 800, 130), func(c: Control):
		_box(c, Rect2(0, 0, 800, 130), Color8(22, 26, 34, 236), 14, Color8(104, 110, 124), 2)
		_box(c, Rect2(6, 6, 788, 118), Color(0, 0, 0, 0), 10, Color8(60, 64, 74), 1))
	_dialog_text = _label(_dialog, "", Vector2(28, 22), 22, TEXT, f_ui, 0)
	_dialog_text.size = Vector2(744, 90)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	var arrow := _label(_dialog, "▼", Vector2(764, 98), 16, Color8(240, 200, 60), f_ui_b, 0)
	var tw := create_tween().set_loops()
	tw.tween_property(arrow, "position:y", 102.0, 0.4)
	tw.tween_property(arrow, "position:y", 98.0, 0.4)
	_dialog.visible = false
	_toast = _label(self, "", Vector2(0, 110), 20, Color.WHITE, f_ui_b, 6, EDGE)
	_toast.size = Vector2(1920, 30)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0


func show_dialog(text: String) -> void:
	_dialog_text.text = text
	_dialog.visible = true


func hide_dialog() -> void:
	_dialog.visible = false


func dialog_open() -> bool:
	return _dialog.visible


func toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


## Étiquette jaune au-dessus d'un autre joueur, comme dans PRO (position à l'écran, mise à jour chaque image).
func set_tag(id: String, text: String, screen_pos: Vector2) -> void:
	var l: Label = _tags.get(id)
	if l == null:
		l = _label(self, text, Vector2.ZERO, 17, Color8(255, 214, 60), f_ui, 0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color8(14, 14, 18, 190)
		sb.set_corner_radius_all(4)
		sb.border_color = Color8(70, 70, 60, 200)
		sb.set_border_width_all(1)
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 0
		sb.content_margin_bottom = 1
		l.add_theme_stylebox_override("normal", sb)
		l.reset_size()
		_tags[id] = l
		move_child(l, 0)
	l.position = (screen_pos - Vector2(l.size.x / 2, l.size.y)).round()


func _hotspot(r: Rect2, what: String) -> void:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			menu_pressed.emit(what))
	add_child(c)


func _ro(r: Rect2, o: Vector2) -> Rect2:
	return Rect2(r.position + o, r.size)


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
