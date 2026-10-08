class_name HatchScreen
extends Screen
## Éclosion d'un Œuf.

var mon: Pokemon
var _spr: TextureRect


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("203040")
	bg.size = size
	add_child(bg)
	_spr = TextureRect.new()
	_spr.position = Vector2(160, 40)
	_spr.size = Vector2(160, 160)
	_spr.pivot_offset = Vector2(80, 80)
	_spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.texture = PixelArt.egg()
	add_child(_spr)
	_run.call_deferred()


func _run() -> void:
	await Game.ui.say("Oh ?")
	for k in 4:
		var tw := create_tween()
		tw.tween_property(_spr, "rotation", 0.25, 0.08)
		tw.tween_property(_spr, "rotation", -0.25, 0.16)
		tw.tween_property(_spr, "rotation", 0.0, 0.08)
		await tw.finished
		await get_tree().create_timer(0.5 - k * 0.1).timeout
	await Game.ui.flash(2)
	Sprites.apply(_spr, "front", mon.species, mon.shiny, PixelArt.placeholder())
	Audio.jingle("evolve")
	Audio.cry(mon.species)
	await Game.ui.say("%s est sorti de l'Œuf !" % Data.pokemon[mon.species]["name"])
	finish(true)
