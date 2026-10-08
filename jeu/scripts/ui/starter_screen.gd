class_name StarterScreen
extends Screen
## Présente un starter et demande confirmation. Renvoie true si choisi.

var species := 1
var _asked := false


func _ready() -> void:
	size = Vector2(480, 320)
	var d: Dictionary = Data.pokemon[species]
	var p := Kit.panel(self, Rect2(150, 20, 180, 200))
	var spr := TextureRect.new()
	spr.position = Vector2(10, 4)
	spr.size = Vector2(150, 150)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Sprites.apply(spr, "front", species, false, PixelArt.placeholder())
	p.add_child(spr)
	var x := 20
	for t in d["types"]:
		Kit.type_tag(p, t, Vector2(x, 160))
		x += 64
	_ask.call_deferred()


func _ask() -> void:
	var d: Dictionary = Data.pokemon[species]
	var ok: bool = await Game.ui.confirm("Prof. Chen : Tu veux %s, le %s ?" % [d["name"], d["genus"]])
	finish(ok)
