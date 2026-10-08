extends Node
## Captures d'écran de contrôle : godot res://tests/screenshots.tscn (avec affichage).

const OUT := "user://captures/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var world := Node2D.new()
	world.set_script(load("res://scripts/world/overworld.gd"))
	add_child(world)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var ui := Control.new()
	ui.set_script(load("res://scripts/ui/ui_root.gd"))
	layer.add_child(ui)
	Game.new_game()
	var c := Pokemon.create(6, 36)
	c.shiny = true
	Game.give_pokemon(c)
	Game.give_pokemon(Pokemon.create(25, 22))
	Game.give_pokemon(Pokemon.create(130, 30))
	Game.party[1].status = "par"
	Game.party[1].hp = 20
	for id in ["poke-ball", "ultra-ball", "potion", "super-potion", "rare-candy", "fire-stone", "tm24", "tm13"]:
		Game.add_item(id, 3)
	for i in range(1, 40):
		Game.seen[i] = true
	for i in range(1, 20):
		Game.caught[i] = true
	# Laisser le temps aux sprites de se télécharger.
	for i in range(1, 152):
		Sprites.get_tex("front", i)
	Sprites.get_tex("back", 6, true)
	Sprites.get_tex("front", 6, true)
	for k in 240:
		await get_tree().process_frame
	await _shot("01_titre", TitleScreen.new(), ui)
	world.load_map("bourg", Vector2i(10, 6), "down")
	await _snap("02_bourg")
	world.load_map("labo", Vector2i(8, 4), "up")
	await _snap("03_labo")
	world.load_map("jadielle", Vector2i(10, 8), "down")
	await _snap("04_jadielle")
	world.load_map("plaine", Vector2i(18, 22), "up")
	await _snap("05_plaine")
	world.load_map("grotte", Vector2i(14, 20), "up")
	await _snap("06_grotte")
	world.load_map("centre_jadielle", Vector2i(6, 4), "up")
	ui.say("Bienvenue au Centre Pokémon ! Nous soignons vos Pokémon gratuitement. Voulez-vous que je soigne vos Pokémon ?")
	for k in 200:
		await get_tree().process_frame
	await _snap("07_centre_dialogue")
	Game._stack[-1].finish()
	printerr("combat...")
	var bs := BattleScreen.new()
	bs.battle = Battle.new(Game.party, [Pokemon.create(9, 34)], false, {"name": "Topdresseur Hugo"})
	ui.add_child(bs)
	for k in 200:
		await get_tree().process_frame
		if bs._menu_active:
			break
		if Game._stack.size() > 0 and Game._stack[-1] is TextBox:
			Game._stack[-1].finish()
	printerr("menu actif=", bs._menu_active, " pile=", Game._stack)
	await _snap("08_combat")
	bs._menu_done.emit(0)
	for k in 30:
		await get_tree().process_frame
	await _snap("09_combat_attaques")
	bs.queue_free()
	Game._stack.clear()
	for c2 in ui.get_children():
		if c2 is Screen:
			c2.queue_free()
	await get_tree().process_frame
	printerr("écrans...")
	await _shot("10_equipe", PartyScreen.new(), ui)
	var s := SummaryScreen.new()
	s.list = Game.party
	await _shot("11_resume_infos", s, ui, 0)
	s = SummaryScreen.new()
	s.list = Game.party
	s._page = 1
	await _shot("12_resume_stats", s, ui)
	s = SummaryScreen.new()
	s.list = Game.party
	s._page = 2
	await _shot("13_resume_capacites", s, ui)
	BagScreen.last_pocket = 2
	await _shot("14_sac", BagScreen.new(), ui)
	await _shot("15_pokedex", PokedexScreen.new(), ui)
	var shop := ShopScreen.new()
	shop.stock = Game.maps["boutique_jadielle"]["npcs"][0]["stock"]
	await _shot("16_boutique", shop, ui)
	var ev := EvolutionScreen.new()
	ev.mon = Pokemon.create(25, 30)
	ev.to = 26
	ui.add_child(ev)
	for k in 30:
		await get_tree().process_frame
	await _snap("17_evolution")
	printerr("captures dans ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _shot(name: String, scr: Control, ui: Node, _page := -1) -> void:
	printerr("  ", name)
	ui.add_child(scr)
	for k in 20:
		await get_tree().process_frame
	await _snap(name)
	if scr is Screen:
		scr.finish(null)
	await get_tree().process_frame


func _snap(name: String) -> void:
	for k in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
