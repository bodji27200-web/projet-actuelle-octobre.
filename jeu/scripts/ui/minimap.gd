extends Control
## Mini-carte en haut à droite : la zone actuelle en petit, ta position (rouge) et ton partenaire (bleu).

const TILE := 2
var _img_tex: TextureRect
var _clip: Control
var _dot: ColorRect
var _pdot: ColorRect
var _name: Label
var _map_id := ""
var _t := 0.0


func _ready() -> void:
	position = Vector2(372, 4)
	size = Vector2(104, 80)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := Kit.panel(self, Rect2(0, 0, 104, 80), Color(0.1, 0.12, 0.2, 0.85), Color("e0e0f0"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip = Control.new()
	_clip.position = Vector2(4, 4)
	_clip.size = Vector2(96, 60)
	_clip.clip_contents = true
	p.add_child(_clip)
	_img_tex = TextureRect.new()
	_img_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clip.add_child(_img_tex)
	_dot = ColorRect.new()
	_dot.size = Vector2(4, 4)
	_dot.color = Color("ff3030")
	_clip.add_child(_dot)
	_pdot = ColorRect.new()
	_pdot.size = Vector2(4, 4)
	_pdot.color = Color("30a0ff")
	_clip.add_child(_pdot)
	_name = Kit.label(p, "", Vector2(4, 62), 10, Color.WHITE, false)
	_name.size = Vector2(96, 14)
	_name.clip_text = true


func _rebuild() -> void:
	_map_id = Game.map_id
	var m: Dictionary = Game.maps[_map_id]
	var img := Image.create(m["w"] * TILE, m["h"] * TILE, false, Image.FORMAT_RGBA8)
	for y in m["h"]:
		var row: String = m["rows"][y]
		for x in m["w"]:
			var c: Color = WorldMapScreen.C.get(row[x], Color("88d070"))
			if row[x] in "_u":
				c = Color("a08868")
			elif row[x] in "#W":
				c = Color("504038")
			elif row[x] in "oq":
				c = Color("e8d8b8")
			img.fill_rect(Rect2i(x * TILE, y * TILE, TILE, TILE), c)
	for b in m["buildings"]:
		img.fill_rect(Rect2i(b["x"] * TILE, b["y"] * TILE, b["w"] * TILE, b["h"] * TILE), Color("e05050") if b["kind"] in ["center", "gym"] else Color("7080a0"))
	_img_tex.texture = ImageTexture.create_from_image(img)
	_img_tex.size = Vector2(img.get_size())
	_name.text = m["name"]


func _process(delta: float) -> void:
	visible = Game.settings.get("minimap", true) and Game.world != null and Game.world.player != null and not Game.ui_busy()
	if not visible:
		return
	if Game.map_id != _map_id:
		_rebuild()
	_t += delta
	var pt: Vector2 = Game.world.player.position / 16.0 * TILE
	var off := -pt + _clip.size / 2
	_img_tex.position = off
	_dot.position = pt + off - Vector2(1, 1)
	_dot.visible = int(_t * 3) % 2 == 0
	_pdot.visible = false
	if Net.in_group() and Game.world.remotes.has(Net.partner):
		_pdot.visible = true
		_pdot.position = Game.world.remotes[Net.partner].position / 16.0 * TILE + off - Vector2(1, 1)
