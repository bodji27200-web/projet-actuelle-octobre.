class_name EvolutionScreen
extends Screen
## Animation d'évolution. B pour l'annuler. Renvoie true si le Pokémon a évolué.

var mon: Pokemon
var to := 0
var _spr: TextureRect
var _cancel := false
var _running := true


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("182030")
	bg.size = Vector2(480, 320)
	add_child(bg)
	_spr = TextureRect.new()
	_spr.position = Vector2(144, 30)
	_spr.size = Vector2(192, 192)
	_spr.pivot_offset = Vector2(96, 96)
	_spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	Sprites.get_tex("front", to, mon.shiny)
	Sprites.apply(_spr, "front", mon.species, mon.shiny, PixelArt.placeholder())
	_run.call_deferred()


func _process(_d: float) -> void:
	if _running and Input.is_action_just_pressed("b"):
		_cancel = true


func _run() -> void:
	var old_name := mon.name()
	await Game.ui.say("Quoi ? %s évolue !" % old_name)
	var old_tex := _spr.texture
	var new_tex: Texture2D = Sprites.get_tex("front", to, mon.shiny)
	if new_tex == null:
		new_tex = PixelArt.placeholder()
	_spr.modulate = Color(4, 4, 4)
	var delay := 0.5
	for i in 14:
		if _cancel:
			break
		_spr.texture = new_tex if i % 2 == 0 else old_tex
		await get_tree().create_timer(delay).timeout
		delay = maxf(0.06, delay * 0.8)
	_running = false
	if _cancel:
		_spr.texture = old_tex
		_spr.modulate = Color.WHITE
		await Game.ui.say("Hein ? %s a arrêté d'évoluer !" % old_name)
		finish(false)
		return
	await Game.ui.flash(2)
	mon.evolve(to)
	Sprites.apply(_spr, "front", to, mon.shiny, PixelArt.placeholder())
	_spr.modulate = Color.WHITE
	await Game.ui.say("Félicitations ! Votre %s a évolué en %s !" % [old_name, mon.data()["name"]])
	finish(true)
