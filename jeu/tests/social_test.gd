extends Node
## Test réseau des fonctions sociales, à lancer deux fois :
##   godot --headless res://tests/social_test.tscn -- host     et     ... -- client
## Synchronisation du monde partagé, chat à canaux, guildes et points, Hôtel des Ventes (vente, achat, paiement),
## échange direct avec évolution, combat classé (Elo), file d'attente avec appariement automatique.

const PORT := 24711

var role := "host"
var world: Node2D
var results := {}
var other_pid := 0


func say(t: String) -> void:
	printerr("[%s] %s" % [role, t])


func check(name: String, ok: bool) -> void:
	results[name] = ok
	say("%s : %s" % [name, "OK" if ok else "ÉCHEC"])


func _ready() -> void:
	role = "client" if OS.get_cmdline_user_args().has("client") else "host"
	seed(11 if role == "host" else 22)
	Game.save_path = "user://test_social_%s.json" % role
	Social.use_store("user://test_store_%s.json" % role)
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
	Game.set_flag("has_starter")
	Game.money = 10000
	if role == "host":
		var l := Pokemon.create(448, 50)
		l.moves = [Pokemon.make_move(396), Pokemon.make_move(370)]
		Game.give_pokemon(l)
		Game.give_pokemon(Pokemon.create(64, 40))
	else:
		var v := Pokemon.create(3, 50)
		v.moves = [Pokemon.make_move(202), Pokemon.make_move(188)]
		Game.give_pokemon(v)
		Game.add_item("rare-candy", 3)
		Game.add_item("potion", 2)
		# Base décorée hors ligne : doit arriver chez l'hôte à la connexion.
		await Social.save_base(Game.uid, [{"id": "plante_verte", "x": 3, "y": 4}])
	world.load_map("centre_jadielle", Vector2i(6, 5), "up")
	_bot.call_deferred()
	if role == "host":
		Net.host(PORT)
	else:
		await get_tree().create_timer(1.5).timeout
		Net.join("127.0.0.1", PORT)
	await _wait(func(): return Net.players.size() > 0, 60.0)
	other_pid = Net.players.keys()[0] if Net.players.size() > 0 else 0
	check("connexion", other_pid != 0)
	await get_tree().create_timer(2.0).timeout
	if role == "host":
		await _host()
	else:
		await _client()
	await get_tree().create_timer(2.0).timeout
	var ok := results.values().all(func(v): return v)
	say("BILAN : %d/%d vérifications OK%s" % [results.values().filter(func(v): return v).size(), results.size(), "" if ok else " — ÉCHECS : " + str(results.keys().filter(func(k): return not results[k]))])
	get_tree().quit()


func _host() -> void:
	var cuid: String = Net.players[other_pid].get("uid", "")
	check("sync : base de l'invitée reçue", Social.store["bases"].has(cuid) and Social.store["bases"][cuid]["items"].size() == 1)
	# Chat
	await _wait(func(): return Social.chat_logs["Commerce"].size() > 0, 10.0)
	check("chat Commerce reçu", Social.chat_logs["Commerce"].size() > 0 and Social.chat_logs["Commerce"][-1].contains("Super Bonbon"))
	# Guilde
	var r: Dictionary = await Social.request("guild_create", {"guild": "Testeurs"})
	check("guilde créée", r.get("ok", false))
	_step.rpc("guild_created")
	await _wait(func(): return Social.guild("Testeurs").get("members", {}).size() == 2, 15.0)
	check("invitée dans la guilde", Social.guild("Testeurs").get("members", {}).size() == 2)
	Social.say("Guilde", "Bonjour la guilde")
	await _wait(func(): return int(Social.guild("Testeurs").get("points", 0)) >= 10, 15.0)
	check("points de guilde (boss = 10)", int(Social.guild("Testeurs").get("points", 0)) == 10)
	# Hôtel des Ventes : l'invitée vend, l'hôte achète.
	await _wait(func(): return Social.gts_listings().size() > 0, 15.0)
	var lst := Social.gts_listings()
	check("annonce visible", lst.size() == 1 and lst[0]["label"] == "Super Bonbon x2")
	var money0 := Game.money
	var b: Dictionary = await Social.request("gts_buy", {"id": lst[0]["id"], "money": Game.money})
	if b.get("ok", false):
		Game.money -= int(b["price"])
		Game.add_item(b["data"]["item"], int(b["data"]["count"]))
	check("achat", b.get("ok", false) and Game.item_count("rare-candy") == 2 and Game.money == money0 - 500)
	var b2: Dictionary = await Social.request("gts_buy", {"id": lst[0]["id"], "money": Game.money})
	check("pas d'achat en double", not b2.get("ok", false))
	_step.rpc("gts_bought")
	# Échange : Kadabra contre une Potion.
	await get_tree().create_timer(1.0).timeout
	Social._trade = {"id": 77, "peer": other_pid, "state": "open"}
	_step.rpc("trade_open")
	await get_tree().create_timer(0.5).timeout
	var potions0 := Game.item_count("potion")
	var offer := {"pokemon": Game.party[1].to_dict(), "where": "party", "index": 1}
	Social.trade_offer({"pokemon": offer["pokemon"]})
	await _wait(func(): return Social.trade_state().has("theirs"), 10.0)
	Social.trade_confirm(true)
	await _wait(func(): return Social.trade_state().get("their_ok", false), 10.0)
	var tr := Social.trade_execute(offer)
	Social.trade_close()
	say("échange hôte : équipe %d, potions %d -> %d, donné %d" % [Game.party.size(), potions0, Game.item_count("potion"), tr["given"]])
	check("échange côté hôte", Game.party.size() == 1 and Game.item_count("potion") == potions0 + 1 and tr["given"] == 64)
	# Combat classé direct.
	await get_tree().create_timer(2.0).timeout
	var res: String = await Social.challenge(other_pid, "ou", true)
	say("combat classé : " + res)
	await _wait(func(): return Social.ladder("ou").size() == 2, 20.0)
	var lad := Social.ladder("ou")
	check("classement OU mis à jour", lad.size() == 2 and lad[0]["elo"] == 1016 and lad[1]["elo"] == 984)
	check("Elo sur la carte de profil", int(Game.stats.get("elo", 0)) in [1016, 984])
	# File d'attente : les deux s'inscrivent, le combat se lance tout seul.
	_step.rpc("queue")
	var q: Dictionary = await Social.join_queue("ou")
	check("inscription file d'attente", q.get("ok", false))
	await _wait(func(): return Social.ladder("ou").size() == 2 and (Social.ladder("ou")[0]["w"] + Social.ladder("ou")[0]["l"]) >= 2, 120.0)
	lad = Social.ladder("ou")
	check("2e combat via la file d'attente", lad.size() == 2 and lad[0]["w"] + lad[0]["l"] == 2 and lad[1]["w"] + lad[1]["l"] == 2)
	_step.rpc("done")


func _client() -> void:
	Social.say("Commerce", "Vends Super Bonbon pas cher")
	await _wait_step("guild_created", 20.0)
	var r: Dictionary = await Social.request("guild_join", {"guild": "Testeurs"})
	check("rejoindre la guilde", r.get("ok", false) and Social.guild_of(Game.uid) == "Testeurs")
	await _wait(func(): return Social.chat_logs["Guilde"].size() > 0, 15.0)
	check("chat de guilde reçu", Social.chat_logs["Guilde"].size() > 0)
	await Social.contribute("boss")
	# Vente.
	Game.remove_item("rare-candy", 2)
	var l: Dictionary = await Social.request("gts_list", {"kind": "item", "data": {"item": "rare-candy", "count": 2}, "label": "Super Bonbon x2", "price": 500})
	check("mise en vente", l.get("ok", false))
	var money0 := Game.money
	await _wait_step("gts_bought", 30.0)
	await _wait(func(): return Game.money > money0, 15.0)
	check("paiement de la vente reçu (500 - 5 %)", Game.money == money0 + 475 and int(Game.stats.get("gts_sold", 0)) == 1)
	# Échange.
	await _wait_step("trade_open", 20.0)
	var potions0 := Game.item_count("potion")
	var offer := {"item": "potion", "count": 1}
	Social.trade_offer(offer)
	await _wait(func(): return Social.trade_state().has("theirs"), 10.0)
	Social.trade_confirm(true)
	await _wait(func(): return Social.trade_state().get("their_ok", false), 10.0)
	var tr := Social.trade_execute(offer)
	Social.trade_close()
	var got: Pokemon = tr["got"]
	var to := got.trade_evolution(tr["given"]) if got != null else 0
	if to != 0:
		got.evolve(to)
	say("échange invitée : reçu %s, équipe %d, potions %d -> %d" % [got.name() if got else "rien", Game.party.size(), potions0, Game.item_count("potion")])
	check("échange reçu + évolution Kadabra -> Alakazam", got != null and got.species == 65 and Game.party.size() == 2 and Game.item_count("potion") == potions0 - 1)
	await _wait_step("queue", 240.0)
	var lad := Social.ladder("ou")
	check("classement OU reçu", lad.size() == 2)
	await get_tree().create_timer(0.5).timeout
	var q: Dictionary = await Social.join_queue("ou")
	check("inscription file (invitée)", q.get("ok", false))
	await _wait_step("done", 240.0)
	lad = Social.ladder("ou")
	check("classement final reçu", lad.size() == 2 and lad[0]["w"] + lad[0]["l"] == 2)


var _steps := {}


@rpc("any_peer", "call_remote", "reliable")
func _step(name: String) -> void:
	_steps[name] = true
	if name == "trade_open":
		Social._trade = {"id": 77, "peer": multiplayer.get_remote_sender_id(), "state": "open"}


func _wait_step(name: String, timeout: float) -> void:
	await _wait(func(): return _steps.has(name), timeout)


func _wait(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return cond.call()


var _shots := 0


## Captures pendant le combat PvP (option « shots », avec affichage).
func _shot_battle() -> void:
	if not OS.get_cmdline_user_args().has("shots") or _shots >= 3:
		return
	for c in Game._stack:
		if c is BattleScreen and c.pvp():
			_shots += 1
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("user://captures")
			get_viewport().get_texture().get_image().save_png("user://captures/6%d_pvp_%s.png" % [_shots, role])
			return


## Robot : appuie sur A dans les dialogues et menus (accepte, attaque avec la 1re capacité).
func _bot() -> void:
	var n := 0
	while true:
		await get_tree().create_timer(0.05).timeout
		n += 1
		if n % 50 == 0:
			await _shot_battle()
		if Game._stack.is_empty():
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
