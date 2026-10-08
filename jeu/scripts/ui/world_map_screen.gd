class_name WorldMapScreen
extends Screen
## Carte de Kanto : toutes les zones extérieures dessinées en petit, avec ta position et celle de ton partenaire.

const C := {".": Color("88d070"), ",": Color("e8d8a0"), '"': Color("308838"), "T": Color("286028"), "~": Color("5888e8"),
	"f": Color("f07878"), "=": Color("f0f0f0"), "S": Color("b48c50"), "v": Color("50a03c"), ":": Color("f0e4b0"), "R": Color("968c78"),
	"w": Color("6ea0d2"), "H": Color("aa7846")}

static var _tex_cache: Texture2D
static var _origin := Vector2i.ZERO

var _map: TextureRect
var _dot: ColorRect
var _pdot: ColorRect
var _t := 0.0
var _label: Label
var _scale := 1.0


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("182848")
	bg.size = size
	add_child(bg)
	if _tex_cache == null:
		_tex_cache = _build_texture()
	_map = TextureRect.new()
	_map.texture = _tex_cache
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sz := Vector2(_tex_cache.get_size())
	_scale = minf(460.0 / sz.x, 290.0 / sz.y)
	_map.size = sz * _scale
	_map.position = Vector2((480 - _map.size.x) / 2, 8)
	add_child(_map)
	for mid in Game.maps:
		var m: Dictionary = Game.maps[mid]
		if m.get("wx") == null or not (mid in ["bourg", "jadielle", "argenta", "azuria", "safrania", "carmin", "lavanville", "celadopole", "parmanie", "cramois", "plateau"]):
			continue
		var l := Kit.label(self, m["name"], _map.position + Vector2(m["wx"] - _origin.x, m["wy"] - _origin.y) * _scale + Vector2(0, -12), 10, Color.WHITE, false)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 3)
	_dot = ColorRect.new()
	_dot.size = Vector2(5, 5)
	_dot.color = Color("ff3030")
	add_child(_dot)
	_pdot = ColorRect.new()
	_pdot.size = Vector2(5, 5)
	_pdot.color = Color("30a0ff")
	_pdot.visible = false
	add_child(_pdot)
	var lp := Kit.panel(self, Rect2(4, 286, 472, 30))
	_label = Kit.label(lp, "", Vector2(10, 0), 14)
	_place()


static func _build_texture() -> Texture2D:
	var minx := 9999
	var miny := 9999
	var maxx := 0
	var maxy := 0
	for mid in Game.maps:
		var m: Dictionary = Game.maps[mid]
		if m.get("wx") == null:
			continue
		minx = mini(minx, m["wx"])
		miny = mini(miny, m["wy"])
		maxx = maxi(maxx, m["wx"] + m["w"])
		maxy = maxi(maxy, m["wy"] + m["h"])
	_origin = Vector2i(minx, miny)
	var img := Image.create(maxx - minx, maxy - miny, false, Image.FORMAT_RGBA8)
	for mid in Game.maps:
		var m: Dictionary = Game.maps[mid]
		if m.get("wx") == null:
			continue
		for y in m["h"]:
			var row: String = m["rows"][y]
			for x in m["w"]:
				img.set_pixel(m["wx"] - minx + x, m["wy"] - miny + y, C.get(row[x], Color("88d070")))
		for b in m["buildings"]:
			var col := Color("e05050") if b["kind"] in ["center", "gym"] else Color("7080a0")
			for y in range(b["y"], b["y"] + b["h"]):
				for x in range(b["x"], b["x"] + b["w"]):
					img.set_pixel(m["wx"] - minx + x, m["wy"] - miny + y, col)
	return ImageTexture.create_from_image(img)


func _world_pos(map_id: String, tile: Vector2i) -> Vector2:
	var m: Dictionary = Game.maps.get(map_id, {})
	if m.get("wx") == null:
		var reg: String = m.get("region", Game.last_outdoor)
		var r: Dictionary = Game.maps.get(reg, Game.maps["bourg"])
		return Vector2(r["wx"] + r["w"] / 2.0, r["wy"] + r["h"] / 2.0)
	return Vector2(m["wx"] + tile.x, m["wy"] + tile.y)


func _place() -> void:
	var p := _world_pos(Game.map_id, Game.pos)
	_dot.position = _map.position + (p - Vector2(_origin)) * _scale - Vector2(2, 2)
	_label.text = "Tu es ici : %s" % Game.maps[Game.map_id]["name"]
	if Net.in_group():
		var st: Dictionary = Net.players[Net.partner]
		var q := _world_pos(st.get("map", "bourg"), Vector2i(st.get("x", 0), st.get("y", 0)))
		_pdot.position = _map.position + (q - Vector2(_origin)) * _scale - Vector2(2, 2)
		_pdot.visible = true
		_label.text += "   •   %s : %s" % [st.get("name", "?"), Game.maps.get(st.get("map", ""), {}).get("name", "?")]


func _process(delta: float) -> void:
	_t += delta
	_dot.visible = int(_t * 3) % 2 == 0
	if act("a") or act("b") or act("map"):
		finish()
