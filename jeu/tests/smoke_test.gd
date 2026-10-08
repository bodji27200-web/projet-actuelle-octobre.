extends Node
## Test automatique (lancé par le développeur, pas utilisé en jeu) :
## godot --headless res://tests/smoke_test.tscn

var errors := 0


func _ready() -> void:
	seed(1234)
	# Sauvegarde à part : le test ne doit jamais toucher la vraie sauvegarde du joueur.
	Game.save_path = "user://test_smoke.json"
	_test_moves()
	_test_random_battles()
	_test_catch()
	_test_evolutions()
	await _test_world_and_screens()
	print("SMOKE TEST TERMINÉ")
	get_tree().quit()


func _mk(sid: int, lvl: int) -> Pokemon:
	return Pokemon.create(sid, lvl)


func _drive(b: Battle, max_turns := 60) -> void:
	b.start()
	var n := 0
	while not b.over and n < max_turns:
		n += 1
		if b.need_switch.size() > 0:
			var ns: Dictionary = b.need_switch[0]
			var bench := b.bench(0, ns["owner"])
			b.player_switch(ns["slot"], bench[0])
			continue
		var acts := {}
		for k in b.sides[0].slots.size():
			var me := b.battler(0, k)
			if me == null or not me.alive():
				continue
			var slots := b.usable_slots(0, k)
			var foes := b.foes(me)
			var tgt: int = foes[randi() % foes.size()].slot if foes.size() > 0 else 0
			var action := {"type": "move", "slot": slots[randi() % slots.size()] if not slots.is_empty() else -1, "target_side": 1, "target_slot": tgt}
			if slots.is_empty():
				action = {"type": "move", "id": Battle.STRUGGLE}
			var r := randi() % 20
			var bench2 := b.bench(0, me.owner)
			if r == 0 and bench2.size() > 0:
				action = {"type": "switch", "index": bench2[0]}
			elif r == 1:
				action = {"type": "item", "item": "super-potion", "target": me.party_index}
			elif r == 2:
				action = {"type": "item", "item": "x-attack"}
			acts[k] = action
		b.play_turn(acts)


func _test_moves() -> void:
	var ids := Data.moves.keys()
	for id in ids:
		for rep in 3:
			var p := _mk(randi_range(1, 151), 40)
			p.moves = [Pokemon.make_move(id), Pokemon.make_move(33)]
			var e := _mk(randi_range(1, 151), 40)
			e.moves = [Pokemon.make_move(ids[randi() % ids.size()]), Pokemon.make_move(id)]
			var b: Battle
			match rep:
				0:
					b = Battle.new([p, _mk(25, 30)], [e, _mk(19, 30)], true, {})
				1:
					b = Battle.new([[p, _mk(25, 30)], [_mk(7, 30)]], [[e], [_mk(19, 30)]], false, [{"name": "A", "potions": 1}, {"name": "B"}])
				_:
					b = Battle.new([p, _mk(25, 30), _mk(1, 30)], [e, _mk(19, 30), _mk(4, 30)], false, {"name": "Duo"}, {"double": true})
			_drive(b, 12)
	print("capacités testées : ", ids.size())


func _test_random_battles() -> void:
	for k in 250:
		var pp := []
		var ep := []
		for i in randi_range(1, 6):
			pp.append(_mk(randi_range(1, 151), randi_range(2, 100)))
		for i in randi_range(1, 6):
			ep.append(_mk(randi_range(1, 151), randi_range(2, 100)))
		var b: Battle
		match k % 5:
			0:
				b = Battle.new(pp, ep, false, {"name": "Test", "potions": 2, "money": 100})
			1:
				b = Battle.new(pp, [ep[0]], true, {})
			2:
				var pp2 := [_mk(randi_range(1, 151), 50), _mk(randi_range(1, 151), 50)]
				b = Battle.new([pp, pp2], [[ep[0]], [_mk(randi_range(1, 151), 40)]], true, {}, {"wild_double": true})
			3:
				var pp3 := [_mk(randi_range(1, 151), 50)]
				var boss := _mk(randi_range(1, 151), 45)
				boss.boss = true
				boss.stats[0] *= 3
				boss.hp = boss.stats[0]
				b = Battle.new([pp, pp3], [boss], true, {}, {"boss": true})
			_:
				b = Battle.new([pp, [_mk(randi_range(1, 151), 50)]], [ep, [_mk(randi_range(1, 151), 50)]], false, [{"name": "T1", "potions": 1}, {"name": "T2"}])
		_drive(b, 150)
		if b.over and k % 50 == 0:
			print("  combat ", k, " (", ["simple", "sauvage", "2 sauvages coop", "boss coop", "2 dresseurs coop"][k % 5], ") -> ", b.result, " en ", b.turn, " tours")
	print("combats aléatoires OK")


func _test_catch() -> void:
	var ok := 0
	for k in 200:
		var e := _mk(randi_range(1, 151), randi_range(2, 60))
		var b := Battle.new([_mk(6, 50)], [e], true)
		b.start()
		var ball: String = ItemUse.BALLS[k % ItemUse.BALLS.size()]
		b.play_turn({"type": "ball", "item": ball})
		if b.result == "caught":
			ok += 1
		b.play_turn({"type": "run"})
	print("captures réussies : ", ok, "/200")


func _test_evolutions() -> void:
	for sid in Data.pokemon:
		var m := _mk(sid, 5)
		for lv in range(5, 101):
			m.add_exp(m.exp_to_next())
			var to := m.level_evolution()
			if to != 0:
				m.evolve(to)
		for item in ["fire-stone", "water-stone", "thunder-stone", "leaf-stone", "moon-stone", "linking-cord", "sun-stone", "ice-stone", "shiny-stone", "dusk-stone", "dawn-stone"]:
			var t := m.item_evolution(item)
			if t != 0:
				m.evolve(t)
		var d := Pokemon.from_dict(m.to_dict())
		assert(d.level == 100)
	print("évolutions OK")


func _test_world_and_screens() -> void:
	var world := Node2D.new()
	world.set_script(load("res://scripts/world/overworld.gd"))
	add_child(world)
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_script(load("res://scripts/ui/ui_root.gd"))
	layer.add_child(ui)
	await get_tree().process_frame
	Game.new_game()
	Game.give_pokemon(_mk(4, 12))
	Game.give_pokemon(_mk(25, 9))
	Game.add_item("tm24")
	Game.add_item("ultra-ball", 3)
	Game.seen[25] = true
	for id in Game.maps:
		var m: Dictionary = Game.maps[id]
		world.load_map(id, Vector2i(m["warps"][0]["tx"] if m["warps"].size() > 0 else 1, m["warps"][0]["ty"] if m["warps"].size() > 0 else 1))
		await get_tree().process_frame
	print("cartes OK")
	Game.party.append(Pokemon.create_egg(4))
	var screens := [PartyScreen.new(), BagScreen.new(), PokedexScreen.new(), TrainerCard.new(), PCScreen.new(), StartMenu.new(),
		WardrobeScreen.new(), JournalScreen.new(), WorldMapScreen.new(), SettingsScreen.new(), KeysScreen.new(), OnlineScreen.new()]
	var s2 := SummaryScreen.new()
	s2.list = Game.party
	screens.append(s2)
	var shop := ShopScreen.new()
	shop.stock = ["poke-ball", "tm01", "potion"]
	screens.append(shop)
	for s in screens:
		ui.add_child(s)
		await get_tree().process_frame
		await get_tree().process_frame
		s.finish(null)
	var bs := BattleScreen.new()
	bs.battle = Battle.new([Game.party, [_mk(7, 10)]], [[_mk(16, 5)], [_mk(19, 5)]], true, {}, {"wild_double": true, "player_names": ["A", "B"]})
	ui.add_child(bs)
	for i in 30:
		await get_tree().process_frame
	print("écrans OK")
	Game.save_game()
	assert(Game.load_game())
	DirAccess.remove_absolute(Game.save_path)
	print("sauvegarde OK")
