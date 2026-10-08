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
	for id in [25, 6, 448]:
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
	printerr("captures dans ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _snap(name: String) -> void:
	for k in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
