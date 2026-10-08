extends Node
## Captures : Pokémon suiveur, nom + titre sur la carte, carte de profil, écrans sociaux.
## xvfb-run godot res://tests/social_shots.tscn

const OUT := "user://captures/"

var world: Node2D
var ui: Control


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	RenderingServer.set_default_clear_color(Color.BLACK)
	world = Node2D.new()
	world.set_script(load("res://scripts/world/overworld.gd"))
	add_child(world)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.set_script(load("res://scripts/ui/ui_root.gd"))
	layer.add_child(ui)
	Game.new_game()
	Game.player_name = "Sacha"
	var c := Pokemon.create(25, 36)
	Game.give_pokemon(c)
	var d := Pokemon.create(6, 50)
	d.shiny = true
	Game.give_pokemon(d)
	Game.give_pokemon(Pokemon.create(448, 50))
	Game.stats = {"wins": 154, "trainers": 98, "leaders": 31, "shinies": 6, "fish": 52, "eggs": 4, "evolutions": 21,
		"best_damage": 1240, "best_hit": "1240 (Lance-Flammes sur Ronflex)", "caught_total": 230, "elo": 1520, "elo_best": 1520}
	Game.badges = [1, 2, 3, 4, 5]
	for i in range(1, 260):
		Game.seen[i] = true
	for i in range(1, 140):
		Game.caught[i] = true
	Profile.check_titles()
	Game.title = "collectionneur_shiny"
	for id in [25, 6, 448, 133, 149, 143, 59, 3]:
		Sprites.get_tex("icon", id)
	for k in 200:
		await get_tree().process_frame
	world.load_map("bourg", Vector2i(10, 8), "down")
	for k in 10:
		await get_tree().process_frame
	# Quelques pas : le suiveur doit prendre la place quittée.
	for dir in ["down", "down", "right", "right"]:
		var t: Vector2i = world.player.tile + world.DIRS[dir]
		if world.can_enter(t, dir):
			await world._step(dir, t)
	for k in 20:
		await get_tree().process_frame
	await _snap("50_suiveur_titre")
	printerr("suiveur : ", world.follower != null, " case ", world.follower.tile if world.follower else Vector2i.ZERO, " joueur ", world.player.tile)
	var tc := TrainerCard.new()
	ui.add_child(tc)
	await _snap("51_profil_identite")
	tc._page = 1
	tc._build()
	await _snap("52_profil_stats")
	tc._page = 2
	tc._build()
	await _snap("53_profil_titres")
	tc.finish()
	# Discussion à canaux.
	Social._add_chat("Commerce", "Lou", "Vends Évoli chromatique, 50 000 ₽ à l'Hôtel des Ventes !", "FR")
	Social._add_chat("Commerce", "Sacha", "Je prends ! Tu peux attendre 5 min ?", "FR")
	Social._add_chat("Général", "Lou", "On fait la Grotte Azurée ce soir ?", "FR")
	var cs := ChatScreen.new()
	cs.channel = 1
	ui.add_child(cs)
	await _snap("54_chat_commerce")
	cs.finish()
	# Liste de l'Hôtel des Ventes (avec icônes).
	var lp := ListPick.new()
	lp.title = "ACHETER — POKéMON (◀ ▶)   Argent : 25 000 ₽"
	lp.rows = ["◆ CHERCHER UN NOM", "Évoli N.25 ★", "Lucario N.50", "Dracolosse N.62"]
	lp.rights = ["", "50 000 ₽", "18 000 ₽", "45 000 ₽"]
	lp.descs = ["", "Vendu par Lou. N.25, Modeste, talent Adaptabilité, IV 160/186, chromatique !", "", ""]
	lp.icons = [null, ["icon", 133], ["icon", 448], ["icon", 149]]
	lp.tabs = true
	ui.add_child(lp)
	lp._index = 1
	lp.refresh_list()
	await _snap("55_hotel_des_ventes")
	lp.finish()
	# Centre Pokémon avec les guichets.
	world.load_map("centre_jadielle", Vector2i(6, 5), "up")
	await _snap("56_centre_guichets")
	# Base secrète décorée.
	Social.use_store("user://test_store_shots.json")
	Game.decor = {"trophy_59": 1}
	Social.save_base(Game.uid, [{"id": "tapis_pokeball", "x": 6, "y": 5}, {"id": "tapis_rouge", "x": 7, "y": 5}, {"id": "tapis_rouge", "x": 8, "y": 5},
		{"id": "peluche_pikachu", "x": 3, "y": 3}, {"id": "peluche_evoli", "x": 4, "y": 3}, {"id": "peluche_ronflex", "x": 5, "y": 3},
		{"id": "plante_verte", "x": 1, "y": 9}, {"id": "palmier", "x": 13, "y": 9}, {"id": "bonsai", "x": 13, "y": 3},
		{"id": "lit", "x": 11, "y": 3}, {"id": "tele", "x": 9, "y": 3}, {"id": "table_bois", "x": 7, "y": 7}, {"id": "chaise", "x": 6, "y": 7},
		{"id": "trophy_59", "x": 2, "y": 6}, {"id": "statue_dracaufeu", "x": 12, "y": 6}, {"id": "fleurs_roses", "x": 3, "y": 9}])
	await SocialMenus.enter_base(world, Game.uid)
	for k in 30:
		await get_tree().process_frame
	await _snap("57_base_secrete")
	printerr("base : ", world.map.get("name"), " ", world._decor.size(), " décos, bloquées ", world._decor_block.size())
	printerr("captures dans ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _snap(name: String) -> void:
	for k in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
