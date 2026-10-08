extends Node
## Captures de l'écran de combat : animations, puces de stats, météo, INFOS, Méga.
## xvfb-run godot res://tests/battle_shots.tscn

const OUT := "user://captures/"

var ui: Control


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_script(load("res://scripts/ui/ui_root.gd"))
	layer.add_child(ui)
	Game.new_game()
	var me := Pokemon.create(6, 60)
	me.held_item = "charizardite-x"
	me.moves = [Pokemon.make_move(53), Pokemon.make_move(14), Pokemon.make_move(89), Pokemon.make_move(182)]
	Game.party = [me]
	Game.add_item("mega-ring")
	var foe := Pokemon.create(9, 58)
	foe.moves = [Pokemon.make_move(57)]
	for id in [6, 9, 10034]:
		Sprites.get_tex("front", id)
		Sprites.get_tex("back", id)
	for k in 240:
		await get_tree().process_frame
	var bs := BattleScreen.new()
	bs.battle = Battle.new([Game.party], [[foe]], false, [{"name": "Champion Test"}], {"mega": true, "player_names": ["Sacha"]})
	bs.bg = "grass"
	ui.add_child(bs)
	await _wait_menu(bs)
	# Pluie, Champ Électrifié, stats modifiées, pièges.
	var b: Battle = bs.battle
	b.weather = "rain"
	b.weather_turns = 4
	b.terrain = "electric"
	b.terrain_turns = 3
	b.battler(0, 0).stages["atk"] = 2
	b.battler(0, 0).stages["spe"] = -1
	b.battler(1, 0).stages["def"] = -2
	b.sides[1].stealth_rock = true
	b.sides[0].reflect = 3
	bs._weather = "rain"
	bs._update_field()
	for k in 30:
		await get_tree().process_frame
	await _snap("30_combat_meteo_stats")
	# Menu des capacités avec la bascule MÉGA.
	bs._menu_done.emit(0)
	for k in 20:
		await get_tree().process_frame
	await _snap("31_combat_menu_mega")
	bs._menu_done.emit(-1)
	for k in 10:
		await get_tree().process_frame
	# Panneau INFOS.
	bs._menu_done.emit(4)
	for k in 20:
		await get_tree().process_frame
	await _snap("32_combat_infos")
	bs._info_panel.queue_free()
	bs._info_panel = null
	bs._menu_done.emit(-2)
	for k in 10:
		await get_tree().process_frame
	# Animations de capacités (capturées en plein milieu).
	var us: TextureRect = bs._sprites["0:0"]
	var ts: TextureRect = bs._sprites["1:0"]
	var shots := [["flamethrower", "fire", "special", false, []], ["thunderbolt", "electric", "special", false, []],
		["close-combat", "fighting", "physical", true, ["contact"]], ["earthquake", "ground", "physical", false, []],
		["leaf-storm", "grass", "special", false, []], ["protect", "normal", "status", false, []],
		["swords-dance", "normal", "status", false, []], ["shadow-ball", "ghost", "special", false, ["ballistics"]],
		["ice-punch", "ice", "physical", true, ["contact", "punch"]], ["crunch", "dark", "physical", true, ["contact", "bite"]]]
	var n := 33
	for sh in shots:
		var self_t: bool = sh[2] == "status"
		var e := {"side": 0, "slot": 0, "tside": 0 if self_t else 1, "tslot": 0, "type": sh[1], "cat": sh[2], "ident": sh[0], "contact": sh[3], "flags": sh[4]}
		MoveFx.play(bs, bs._fx, us, us if self_t else ts, e)
		for k in (9 if sh[0] not in ["thunderbolt", "protect"] else 6):
			await get_tree().process_frame
		await _snap("%d_anim_%s" % [n, sh[0]])
		n += 1
		for k in 70:
			await get_tree().process_frame
	# Méga-Évolution réelle.
	b.mega_evolve(b.battler(0, 0))
	var evs := b.flush()
	bs._play(evs)
	for k in 20:
		await get_tree().process_frame
	await _snap("%d_mega_evolution" % n)
	for k in 160:
		await get_tree().process_frame
	await _snap("%d_mega_apres" % (n + 1))
	# Combat double : la barre de terrain ne doit pas recouvrir les cadres.
	bs.queue_free()
	Game._stack.clear()
	var p2 := Pokemon.create(25, 50)
	Game.party = [me, p2]
	var bd := BattleScreen.new()
	bd.battle = Battle.new([Game.party], [[Pokemon.create(9, 50), Pokemon.create(3, 50)]], false, [{"name": "Duo Test"}], {"double": true, "player_names": ["Sacha"]})
	bd.bg = "grass"
	ui.add_child(bd)
	await _wait_menu(bd)
	bd.battle.weather = "sun"
	bd.battle.weather_turns = 5
	bd.battle.trick_room = 3
	bd.battle.sides[1].spikes = 2
	bd._weather = "sun"
	bd._update_field()
	for k in 30:
		await get_tree().process_frame
	await _snap("%d_combat_double" % (n + 2))
	printerr("captures dans ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _wait_menu(bs: BattleScreen) -> void:
	for k in 400:
		await get_tree().process_frame
		if bs._menu_active:
			return
		if Game._stack.size() > 0 and Game._stack[-1] is TextBox:
			Game._stack[-1].finish()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
