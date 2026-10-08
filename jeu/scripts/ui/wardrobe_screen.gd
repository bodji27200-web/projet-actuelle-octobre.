class_name WardrobeScreen
extends Screen
## Garde-robe : choisir sa tenue parmi celles obtenues.

var _index := 0
var _preview: TextureRect
var _labels: Array = []
var _list: Panel
var _info: Label
var _t := 0.0


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("f0d8e8")
	bg.size = size
	add_child(bg)
	Kit.label(self, "TENUES", Vector2(14, 8), 20, Color("a03070"), false)
	_list = Kit.panel(self, Rect2(220, 8, 254, 240))
	var pv := Kit.panel(self, Rect2(14, 44, 196, 204), Color("ffffff"), Color("c08098"))
	_preview = TextureRect.new()
	_preview.position = Vector2(34, 20)
	_preview.size = Vector2(128, 128)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pv.add_child(_preview)
	_info = Kit.label(pv, "", Vector2(10, 158), 14)
	var help := Kit.panel(self, Rect2(4, 256, 472, 60))
	Kit.label(help, "A : porter   B : retour   %d / %d tenues obtenues" % [Game.outfits.size(), Game.OUTFITS.size()], Vector2(10, 4), 14)
	Kit.label(help, "Autres tenues : Magasin de Céladopole, quêtes et boss.", Vector2(10, 26), 13, Color("707070"))
	_index = maxi(0, Game.outfits.find(Game.outfit))
	_build()


func _build() -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	var first := clampi(_index - 4, 0, maxi(0, Game.outfits.size() - 10))
	for k in mini(10, Game.outfits.size()):
		var i := first + k
		var o: String = Game.outfits[i]
		var txt: String = ("▶ " if i == _index else "   ") + Game.OUTFITS[o]["name"] + ("  ✓" if o == Game.outfit else "")
		_labels.append(Kit.label(_list, txt, Vector2(10, 6 + k * 22), 15, Color("c03070") if i == _index else Kit.INK))
	var look := "%s_%s" % ["girl" if Game.gender == 1 else "boy", Game.outfits[_index]]
	_preview.texture = PixelArt.character(look, ["down", "left", "up", "right"][int(_t * 1.5) % 4], 0)
	_info.text = Game.OUTFITS[Game.outfits[_index]]["name"]


func _process(delta: float) -> void:
	_t += delta
	var look := "%s_%s" % ["girl" if Game.gender == 1 else "boy", Game.outfits[_index]]
	_preview.texture = PixelArt.character(look, ["down", "left", "up", "right"][int(_t * 1.5) % 4], 0)
	if act("up"):
		_index = (_index - 1 + Game.outfits.size()) % Game.outfits.size()
		_build()
	elif act("down"):
		_index = (_index + 1) % Game.outfits.size()
		_build()
	elif act("a"):
		Game.outfit = Game.outfits[_index]
		Audio.sfx("select")
		_build()
	elif act("b"):
		finish()
