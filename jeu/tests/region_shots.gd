extends Node
## Captures des régions de la campagne : xvfb-run godot res://tests/region_shots.tscn -- <id_carte> <id_carte>...
## Sans argument : une sélection de cartes. Vérifie aussi que chaque carte se charge sans erreur.

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
	Game.give_pokemon(Pokemon.create(157, 50))
	Game.settings["names"] = false
	var ids: Array = Array(OS.get_cmdline_user_args())
	var all := ids.has("all")
	if ids.is_empty() or all:
		ids = []
		for mid in Game.maps:
			if all or mid.begins_with("jo_"):
				ids.append(mid)
	for k in 120:
		await get_tree().process_frame
	var n := 0
	var loaded := 0
	for mid in ids:
		if not Game.maps.has(mid):
			printerr("carte inconnue : ", mid)
			continue
		var at := _entry(mid)
		world.load_map(mid, at, "down")
		loaded += 1
		if not all:
			for k in 6:
				await get_tree().process_frame
			await _snap("7%02d_%s" % [n, mid])
			n += 1
		else:
			await get_tree().process_frame
	if not all:
		world.load_map(ids[0], _entry(ids[0]), "down")
		var wm := WorldMapScreen.new()
		ui.add_child(wm)
		await _snap("7%02d_carte_monde" % n)
		wm.finish()
	printerr("cartes chargées : ", loaded)
	get_tree().quit()


## Une case où le joueur peut se tenir : l'arrivée d'une porte ou d'un passage vers cette carte.
func _entry(mid: String) -> Vector2i:
	var m: Dictionary = Game.maps[mid]
	if m.has("port"):
		return Vector2i(m["port"][0], m["port"][1])
	for other in Game.maps.values():
		for w in other["warps"]:
			if w["to"] == mid:
				return Vector2i(w["tx"], w["ty"])
		for b in other["buildings"]:
			if b["to"] == mid:
				return Vector2i(b["tx"], b["ty"])
	return Vector2i(m["w"] / 2, m["h"] / 2)


func _snap(name: String) -> void:
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
