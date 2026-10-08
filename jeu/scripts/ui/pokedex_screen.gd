class_name PokedexScreen
extends ItemList2
## Pokédex : 151 Pokémon, vus / capturés, fiche détaillée.

var _sprite: TextureRect
var _name: Label
var _detail: Control
var _busy := false


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("c83838")
	bg.size = Vector2(480, 320)
	add_child(bg)
	Kit.label(self, "POKéDEX", Vector2(14, 8), 18, Color.WHITE, false)
	Kit.label(self, "VUS : %d   PRIS : %d" % [Game.seen.size(), Game.caught.size()], Vector2(14, 34), 14, Color.WHITE, false)
	var sp := Kit.panel(self, Rect2(10, 60, 196, 196))
	_sprite = TextureRect.new()
	_sprite.position = Vector2(14, 14)
	_sprite.size = Vector2(160, 160)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.add_child(_sprite)
	_name = Kit.label(self, "", Vector2(14, 266), 15, Color.WHITE, false)
	Kit.label(self, "A : fiche   B : retour", Vector2(14, 296), 12, Color("f8d0d0"), false)
	build_list(Rect2(214, 8, 260, 228))


func row_count() -> int:
	return 151


func row_text(i: int) -> String:
	var sid := i + 1
	var mark := "● " if Game.caught.has(sid) else "   "
	return "%s%03d %s" % [mark, sid, Data.pokemon[sid]["name"] if Game.seen.has(sid) else "----------"]


func on_change(i: int) -> void:
	var sid := i + 1
	if Game.seen.has(sid):
		Sprites.apply(_sprite, "front", sid, false, PixelArt.placeholder())
		_sprite.modulate = Color.WHITE if Game.caught.has(sid) else Color(0.15, 0.15, 0.2)
		_name.text = "%s — %s" % [Data.pokemon[sid]["name"], Data.pokemon[sid]["genus"]]
	else:
		_sprite.texture = null
		_name.text = "???"


func _process(delta: float) -> void:
	if _detail != null:
		if act("b") or act("a"):
			_detail.queue_free()
			_detail = null
		return
	super._process(delta)


func on_select(i: int) -> void:
	var sid := i + 1
	if not Game.seen.has(sid):
		return
	var d: Dictionary = Data.pokemon[sid]
	_detail = Kit.panel(self, Rect2(10, 10, 460, 300), Color("f8f8f0"), Color("a03030"))
	var spr := TextureRect.new()
	spr.position = Vector2(8, 8)
	spr.size = Vector2(140, 140)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Sprites.apply(spr, "front", sid, false, PixelArt.placeholder())
	_detail.add_child(spr)
	Kit.label(_detail, "N°%03d  %s" % [sid, d["name"]], Vector2(160, 8), 18)
	Kit.label(_detail, "Pokémon %s" % d["genus"].replace("Pokémon ", ""), Vector2(160, 32), 14)
	var x := 160
	for t in d["types"]:
		Kit.type_tag(_detail, t, Vector2(x, 56))
		x += 64
	var caught := Game.caught.has(sid)
	Kit.label(_detail, "Taille : %.1f m    Poids : %.1f kg" % [d["height"] / 10.0, d["weight"] / 10.0] if caught else "Taille : ???    Poids : ???", Vector2(160, 82), 14)
	if caught:
		var names := ["PV", "Atq", "Déf", "AtqS", "DéfS", "Vit"]
		for k in 6:
			Kit.label(_detail, "%s %d" % [names[k], d["base"][k]], Vector2(160 + (k % 3) * 96, 104 + (k / 3) * 20), 13, Color("806040"))
		var txt := Kit.label(_detail, "", Vector2(10, 160), 15)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.size = Vector2(436, 120)
		txt.text = d["dex"]
	else:
		Kit.label(_detail, "Capture ce Pokémon pour en savoir plus.", Vector2(10, 170), 15, Color("808080"))
