extends Node
## Test multijoueur : lancer deux fois (godot --headless res://tests/net_test.tscn -- host / -- client)

var role := "host"
var world: Node2D
var log_lines: Array = []


func say(t: String) -> void:
	printerr("[%s] %s" % [role, t])


func _ready() -> void:
	role = "client" if OS.get_cmdline_user_args().has("client") else "host"
	seed(7 if role == "host" else 99)
	world = Node2D.new()
	world.set_script(load("res://scripts/world/overworld.gd"))
	add_child(world)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var ui := Control.new()
	ui.set_script(load("res://scripts/ui/ui_root.gd"))
	layer.add_child(ui)
	await get_tree().process_frame
	Game.new_game()
	Game.player_name = "Hôte" if role == "host" else "Invitée"
	Game.gender = 0 if role == "host" else 1
	Game.set_flag("has_starter")
	Game.set_flag("has_dex")
	Game.give_pokemon(Pokemon.create(6 if role == "host" else 9, 32))
	Game.give_pokemon(Pokemon.create(25, 30))
	Game.add_item("poke-ball", 10)
	world.load_map("r1", Vector2i(10, 20) if role == "host" else Vector2i(11, 20), "up")
	Net.message.connect(func(t): say("message : " + t))
	_bot.call_deferred()
	if role == "host":
		Net.host(24690)
	else:
		await get_tree().create_timer(1.0).timeout
		Net.join("127.0.0.1", 24690)
	await _wait(func(): return Net.players.size() > 0, 15.0)
	say("connecté, joueurs vus : %s" % str(Net.players.values().map(func(p): return p["name"])))
	await get_tree().create_timer(1.0).timeout
	say("l'autre joueur est affiché sur la carte : %s" % str(world.remotes.size() == 1))
	if role == "host":
		Net.invite(Net.players.keys()[0])
	await _wait(func(): return Net.in_group(), 10.0)
	say("groupe formé : %s" % str(Net.in_group()))
	await get_tree().create_timer(1.0).timeout
	if role == "host":
		await _host_scenario()
	else:
		await _wait(func(): return Game.flag("test_done"), 240.0)
		say("RÉSUMÉ INVITÉE : équipe=%s argent=%d pris=%d" % [str(Game.party.map(func(m): return "%s N.%d exp %d PV %d/%d" % [m.name(), m.level, m.exp, m.hp, m.max_hp()])), Game.money, Game.caught.size()])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _host_scenario() -> void:
	var exp0: int = Game.party[0].exp
	say("coop prêt : %s" % str(Net.coop_ready()))
	say("--- combat sauvage 2v2 ---")
	await Events.wild_encounter(world, Game.maps["r1"]["wild"]["grass"])
	say("fin combat sauvage. exp gagnée hôte : %d" % (Game.party[0].exp - exp0))
	await get_tree().create_timer(2.0).timeout
	say("--- combat dresseurs 2v2 ---")
	var money0 := Game.money
	var r: String = await Events.trainer_battle_id(world, "r2_a")
	say("résultat dresseurs : %s, argent +%d, dresseur battu : %s" % [r, Game.money - money0, str(Game.flag("tr_r2_a"))])
	await get_tree().create_timer(2.0).timeout
	say("--- boss à deux ---")
	var ok: bool = await Events.run_script(world, null, [["boss", 95, 14, "test_boss"]])
	say("boss vaincu : %s" % str(ok and Game.flag("test_boss")))
	await get_tree().create_timer(2.0).timeout
	Net._chat.rpc("Hôte", "fin")
	_finish_partner.call_deferred()
	await get_tree().create_timer(3.0).timeout
	say("RÉSUMÉ HÔTE : équipe=%s argent=%d" % [str(Game.party.map(func(m): return "%s N.%d exp %d PV %d/%d" % [m.name(), m.level, m.exp, m.hp, m.max_hp()])), Game.money])


func _finish_partner() -> void:
	_set_done.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _set_done() -> void:
	Game.set_flag("test_done")


func _wait(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return cond.call()


## Robot : appuie sur A dans les dialogues et menus (attaque toujours avec la 1re capacité).
func _bot() -> void:
	while true:
		await get_tree().create_timer(0.05).timeout
		if Game._stack.is_empty():
			continue
		var top = Game._stack[-1]
		if top is NameEntry:
			top.finish(top.default)
			continue
		var e := InputEventAction.new()
		e.action = "a"
		e.pressed = true
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame
		var r := InputEventAction.new()
		r.action = "a"
		r.pressed = false
		Input.parse_input_event(r)
