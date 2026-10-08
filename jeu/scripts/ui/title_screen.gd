class_name TitleScreen
extends Screen
## Écran titre. Renvoie "continue" ou "new".

var _press: Label
var _t := 0.0
var _menu := false


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("203868")
	bg.size = Vector2(480, 320)
	add_child(bg)
	var title := Kit.label(self, "POKéMON", Vector2(0, 30), 56, Color("f8d030"), false)
	title.size.x = 480
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("2850a0"))
	title.add_theme_constant_override("outline_size", 10)
	var sub := Kit.label(self, "Version Kanto", Vector2(0, 100), 20, Color.WHITE, false)
	sub.size.x = 480
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spr := TextureRect.new()
	spr.position = Vector2(176, 120)
	spr.size = Vector2(128, 128)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Sprites.apply(spr, "front", [6, 3, 9, 25, 150][randi() % 5], false)
	add_child(spr)
	_press = Kit.label(self, "Appuie sur ENTRÉE", Vector2(0, 262), 18, Color.WHITE, false)
	_press.size.x = 480
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help := Kit.label(self, "Flèches/ZQSD : bouger   Entrée/Espace : A   Échap : B   Tab : menu   Maj : courir", Vector2(0, 298), 11, Color("a0b8e0"), false)
	help.size.x = 480
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	_t += delta
	_press.visible = int(_t * 2) % 2 == 0 and not _menu
	if not _menu and act("a"):
		_menu = true
		var opts := ["CONTINUER", "NOUVELLE PARTIE"] if Game.has_save() else ["NOUVELLE PARTIE"]
		var i: int = await Game.ui.choose(opts, Vector2(150, 180), false, 1, 180)
		var choice: String = opts[i]
		if choice == "NOUVELLE PARTIE" and Game.has_save():
			if not await Game.ui.confirm("Une sauvegarde existe. L'écraser en commençant une nouvelle partie ?"):
				_menu = false
				return
		finish("continue" if choice == "CONTINUER" else "new")
