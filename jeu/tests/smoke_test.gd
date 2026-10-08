extends Node
## Test automatique (lancé par le développeur, pas utilisé en jeu) :
## godot --headless res://tests/smoke_test.tscn

var errors := 0


func _ready() -> void:
	seed(1234)
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
		if b.need_switch:
			b.player_switch(b.first_alive(0))
			continue
		var slots := b.usable_slots(0)
		var action := {"type": "move", "slot": slots[randi() % slots.size()] if not slots.is_empty() else -1}
		if slots.is_empty():
			action = {"type": "move", "id": Battle.STRUGGLE}
		var r := randi() % 20
		if r == 0 and b.alive_count(0) > 1:
			for i in b.sides[0].party.size():
				if i != b.sides[0].b.party_index and not b.sides[0].party[i].is_fainted():
					action = {"type": "switch", "index": i}
					break
		elif r == 1:
			action = {"type": "item", "item": "super-potion", "target": b.sides[0].b.party_index}
		elif r == 2:
			action = {"type": "item", "item": "x-attack"}
		b.play_turn(action)


func _test_moves() -> void:
	var ids := Data.moves.keys()
	for id in ids:
		for rep in 3:
			var p := _mk(randi_range(1, 151), 40)
			p.moves = [Pokemon.make_move(id), Pokemon.make_move(33)]
			var e := _mk(randi_range(1, 151), 40)
			e.moves = [Pokemon.make_move(ids[randi() % ids.size()]), Pokemon.make_move(id)]
			var b := Battle.new([p, _mk(25, 30)], [e, _mk(19, 30)], rep == 0, {"name": "Test", "potions": 1})
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
		var b := Battle.new(pp, ep, k % 3 == 0, {"name": "Test", "potions": 2, "money": 100})
		_drive(b, 150)
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
		for item in ItemUse.STONES:
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
	var screens := [PartyScreen.new(), BagScreen.new(), PokedexScreen.new(), TrainerCard.new(), PCScreen.new()]
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
	bs.battle = Battle.new(Game.party, [_mk(16, 5)], true, {})
	ui.add_child(bs)
	for i in 30:
		await get_tree().process_frame
	print("écrans OK")
	Game.save_game()
	assert(Game.load_game())
	print("sauvegarde OK")
