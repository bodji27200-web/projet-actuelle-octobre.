class_name Kit
extends RefCounted
## Petits outils d'interface : cadres façon Pokémon, libellés, barres de PV.

const INK := Color("303030")
const SHADOW := Color("d0d0c8")
const FRAME := Color("4870a0")


static func box_style(bg := Color("f8f8f8"), border := FRAME, radius := 6, width := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func panel(parent: Node, rect: Rect2, bg := Color("f8f8f8"), border := FRAME) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", box_style(bg, border))
	parent.add_child(p)
	return p


static func label(parent: Node, text: String, pos: Vector2, size := 16, color := INK, shadow := true) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color("58d080")
	if ratio > 0.2:
		return Color("f8c030")
	return Color("f05838")


## Barre de PV : un fond et un ColorRect de remplissage (renvoyé).
static func hp_bar(parent: Node, pos: Vector2, width: float, ratio: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.position = pos
	bg.size = Vector2(width + 4, 8)
	bg.color = Color("404848")
	parent.add_child(bg)
	var inner := ColorRect.new()
	inner.position = Vector2(2, 2)
	inner.size = Vector2(width * clampf(ratio, 0, 1), 4)
	inner.color = hp_color(ratio)
	inner.set_meta("full", width)
	bg.add_child(inner)
	return inner


static func set_bar(bar: ColorRect, ratio: float) -> void:
	bar.size.x = bar.get_meta("full") * clampf(ratio, 0, 1)
	bar.color = hp_color(ratio)


static func type_tag(parent: Node, t: String, pos: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(58, 18)
	var s := box_style(Data.TYPE_COLORS.get(t, Color.GRAY), Data.TYPE_COLORS.get(t, Color.GRAY).darkened(0.35), 4, 1)
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	var l := label(p, Data.type_name(t).to_upper(), Vector2(0, -1), 12, Color.WHITE, false)
	l.size = Vector2(58, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return p


const STATUS_TAG := {"psn": ["PSN", "a040a0"], "tox": ["PSN", "a040a0"], "par": ["PAR", "c0a020"],
	"slp": ["SOM", "808080"], "brn": ["BRÛ", "e06030"], "frz": ["GEL", "60b0e0"]}


static func status_tag(parent: Node, status: String, pos: Vector2) -> Control:
	if not STATUS_TAG.has(status):
		return null
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(36, 14)
	var c := Color(STATUS_TAG[status][1])
	p.add_theme_stylebox_override("panel", box_style(c, c.darkened(0.3), 3, 1))
	parent.add_child(p)
	var l := label(p, STATUS_TAG[status][0], Vector2(0, -3), 12, Color.WHITE, false)
	l.size = Vector2(36, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return p


static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()
