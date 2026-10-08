class_name TrainerCard
extends Screen
## Carte de Dresseur.


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = Vector2(480, 320)
	add_child(bg)
	var p := Kit.panel(self, Rect2(40, 36, 400, 240), Color("f8e8b0"), Color("c09030"))
	Kit.label(p, "CARTE DE DRESSEUR", Vector2(14, 8), 18, Color("806020"))
	Kit.label(p, "NOM : %s" % Game.player_name, Vector2(14, 48))
	Kit.label(p, "ARGENT : %d ₽" % Game.money, Vector2(14, 76))
	Kit.label(p, "POKéDEX : %d vus, %d capturés" % [Game.seen.size(), Game.caught.size()], Vector2(14, 104))
	Kit.label(p, "TEMPS DE JEU : %s" % Game.time_text(), Vector2(14, 132))
	Kit.label(p, "BADGES : %d / 8" % Game.badge_count(), Vector2(14, 160))
	for n in 8:
		var c := ColorRect.new()
		c.size = Vector2(18, 18)
		c.position = Vector2(14 + n * 24, 188)
		c.color = [Color("a0a0a0"), Color("5090f0"), Color("f0d030"), Color("60c060"), Color("c060c0"), Color("f0a030"), Color("e04040"), Color("50b050")][n] if Game.badges.has(n + 1) else Color(0, 0, 0, 0.15)
		p.add_child(c)
	var spr := TextureRect.new()
	spr.texture = PixelArt.character(Game.look(), "down", 0)
	spr.position = Vector2(300, 50)
	spr.size = Vector2(80, 80)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_child(spr)


func _process(_d: float) -> void:
	if act("a") or act("b"):
		finish()
