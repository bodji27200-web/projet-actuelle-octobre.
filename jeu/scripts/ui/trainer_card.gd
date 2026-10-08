class_name TrainerCard
extends Screen
## Carte de Dresseur.


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = Vector2(480, 320)
	add_child(bg)
	var p := Kit.panel(self, Rect2(40, 40, 400, 220), Color("f8e8b0"), Color("c09030"))
	Kit.label(p, "CARTE DE DRESSEUR", Vector2(14, 8), 18, Color("806020"))
	Kit.label(p, "NOM : %s" % Game.player_name, Vector2(14, 48))
	Kit.label(p, "ARGENT : %d ₽" % Game.money, Vector2(14, 76))
	Kit.label(p, "POKéDEX : %d vus, %d capturés" % [Game.seen.size(), Game.caught.size()], Vector2(14, 104))
	Kit.label(p, "TEMPS DE JEU : %s" % Game.time_text(), Vector2(14, 132))
	Kit.label(p, "POKéMON DANS LE PC : %d" % Game.pc.size(), Vector2(14, 160))
	var spr := TextureRect.new()
	spr.texture = PixelArt.character("player", "down", 0)
	spr.position = Vector2(300, 50)
	spr.size = Vector2(80, 80)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_child(spr)


func _process(_d: float) -> void:
	if act("a") or act("b"):
		finish()
