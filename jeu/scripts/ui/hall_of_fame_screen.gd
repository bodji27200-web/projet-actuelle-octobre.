class_name HallOfFameScreen
extends Screen
## Panthéon : l'équipe du nouveau Maître de la Ligue.


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("402010")
	bg.size = size
	add_child(bg)
	var t := Kit.label(self, "PANTHÉON DE LA LIGUE", Vector2(0, 10), 22, Color("f8d030"), false)
	t.size.x = 480
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mons := Game.party.filter(func(m): return not m.is_egg)
	for i in mons.size():
		var m: Pokemon = mons[i]
		var tr := TextureRect.new()
		tr.position = Vector2(20 + (i % 3) * 150, 44 + (i / 3) * 128)
		tr.size = Vector2(96, 96)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		Sprites.apply(tr, "front", m.sprite_id(), m.shiny, PixelArt.placeholder())
		add_child(tr)
		Kit.label(self, "%s N.%d" % [m.name(), m.level], tr.position + Vector2(-4, 96), 13, Color.WHITE, false)
	_run.call_deferred()


func _run() -> void:
	Audio.jingle("badge")
	await Game.ui.say(["Félicitations, %s !" % Game.player_name, "Toi et tes Pokémon entrez au Panthéon de la Ligue Pokémon de Kanto !",
		"Temps de jeu : %s. Pokédex : %d capturés." % [Game.time_text(), Game.caught.size()]])
	finish()
