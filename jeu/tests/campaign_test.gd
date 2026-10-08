extends Node
## Test de la campagne d'après-Ligue, joué dans le vrai moteur (dialogues, menus, combats) :
##   godot --headless --fixed-fps 60 res://tests/campaign_test.tscn
## Bateau vers le Château Rocket, Giovanni, Gardien de l'Abîme, Pokémon Titan, starter de Paldea,
## Maître des Capacités. Les combats sont joués en appuyant sur des touches, avec une équipe de niveau 100.

var world: Node2D
var ui: Control
var ok := 0
var fail := 0
var failures: Array = []
## Option à choisir dans le prochain menu (texte exact), sinon touches au hasard.
var want := ""


func check(cond: bool, what: String) -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		failures.append(what)
	print(("   OK  " if cond else "   ÉCHEC  ") + what)


func _ready() -> void:
	seed(7)
	Game.save_path = "user://test_campaign.json"
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
	Game.player_name = "Test"
	for sid in [150, 384, 445, 248, 376, 149]:
		var m := Pokemon.create(sid, 100)
		Builds.auto(m, false)
		Game.give_pokemon(m)
	for f in ["has_dex", "has_starter", "champion", "chap_sevii_done"]:
		Game.set_flag(f)
	for r in Campaign.ORDER.slice(1):
		Game.set_flag("champion_" + r)
	Game.add_item("passe-croisiere")
	Game.add_item("full-restore", 50)
	world.load_map("carmin", Vector2i(10, 10), "down")
	for k in 30:
		await get_tree().process_frame
	await _run()
	print("\n=== CAMPAGNE : %d vérifications OK, %d échecs ===" % [ok, fail])
	for f in failures:
		print("  ÉCHEC : ", f)
	DirAccess.remove_absolute(Game.save_path)
	get_tree().quit()


func _run() -> void:
	print("1. Bateau vers le Château Rocket")
	want = "CHÂTEAU ROCKET"
	await _talk("capitaine")
	check(world.map_id == "cr_quai", "Le capitaine emmène au Quai du Château (%s)" % world.map_id)
	check(Game.flag("visited_rainbow") and int(Game.quests.get("chap_rainbow", 0)) == 1, "Quête du Château commencée")

	print("2. Giovanni au sommet du Château")
	await _fight_npc("cr_chateau_4", "giovanni_final", "rainbow_done")
	check(Game.flag("rainbow_done"), "Giovanni vaincu : fin de la Team Rainbow Rocket")
	check(Game.item_count("master-ball") >= 1, "Giovanni laisse une Master Ball")
	check(int(Game.quests.get("chap_rainbow", 0)) == 2, "Quête du Château à l'étape de l'Abîme")
	check(Game.titles.has("fleau_rainbow"), "Titre « Fléau de la Team Rainbow » débloqué")

	print("3. Gardien de l'Abîme")
	await _fight_npc("cr_abime_10", "gardien", "abyss_done")
	check(Game.flag("abyss_done"), "Gardien de l'Abîme vaincu")
	check(Game.titles.has("survivant_abime"), "Titre « Survivant de l'Abîme » débloqué")

	print("4. Arceus")
	want = "OUI"
	world.load_map("cr_abime_10", _beside("arceus", "cr_abime_10"), "down")
	await _settle()
	var before := Game.party.size() + Game.pc.size()
	await _talk("arceus")
	var caught := Game.party.size() + Game.pc.size() == before + 1
	print("   capturé : ", caught)
	# Capturé : il disparaît et le drapeau est posé. Sinon (K.O., fuite) : il reste là et revient plus tard.
	check(Game.flag("leg_493") == caught, "Drapeau d'Arceus posé seulement s'il est capturé")
	check((world.find_walker("arceus") == null) == caught, "Arceus reste sur la carte tant qu'il n'est pas capturé")

	print("5. Pokémon Titan de Paldea")
	await _fight_npc("pa_ouest1", "titan_lestombaile", "boss_titan_lestombaile")
	check(Game.flag("boss_titan_lestombaile"), "Titan Lestombaile vaincu")
	check(int(Game.quests.get("q_paldea_titans", 0)) == 1, "Quête des Titans commencée")
	check(Game.decor.has("trophy_962"), "Trophée du Titan pour la Base Secrète")

	print("6. Starter de Paldea")
	want = ""
	world.load_map("labo_paldea", Vector2i(6, 4), "up")
	await _settle()
	var n0 := Game.party.size() + Game.pc.size()
	await _talk("professeur")
	check(Game.flag("starter_paldea"), "Le Directeur Clavel confie un starter")
	var got := Game.party + Game.pc
	check(Game.party.size() + Game.pc.size() == n0 + 1 and [906, 909, 912].has(got.back().species if Game.pc.size() == 0 else Game.pc.back().species),
		"Le starter est Poussacha, Chochodile ou Coiffeton")

	print("7. Maître des Capacités")
	world.load_map("centre_pa_mesaledo", Vector2i(3, 3), "up")
	await _settle()
	var mon: Pokemon = Game.party[0]
	var old_moves: Array = mon.moves.map(func(m): return m["id"])
	await _talk("maitre_capacites")
	var new_moves: Array = mon.moves.map(func(m): return m["id"])
	check(new_moves != old_moves, "Une capacité a été réapprise (%s -> %s)" % [old_moves, new_moves])
	check(not Game.ui_busy(), "Retour au jeu après le Maître des Capacités")


## Va sur la carte, parle au PNJ et rejoue jusqu'à la victoire (3 essais, l'équipe est soignée entre deux).
func _fight_npc(mid: String, nid: String, flag: String) -> void:
	for attempt in 3:
		Game.heal_party()
		world.load_map(mid, _beside(nid, mid), "down")
		await _settle()
		if world.find_walker(nid) == null:
			check(false, "PNJ %s présent sur %s" % [nid, mid])
			return
		await _talk(nid)
		if Game.flag(flag):
			return
		print("   (défaite, nouvel essai)")


## Case libre à côté d'un PNJ (sur la carte actuelle ou une autre).
func _beside(nid: String, mid := "") -> Vector2i:
	var m: Dictionary = Game.maps[mid if mid != "" else world.map_id]
	for n in m["npcs"]:
		if n["id"] == nid:
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var p: Vector2i = Vector2i(n["x"], n["y"]) + d
				var ch: String = m["rows"][p.y][p.x]
				if "._quv:,\"f".contains(ch) and not m["npcs"].any(func(o): return o["x"] == p.x and o["y"] == p.y):
					return p
	return Vector2i(m["w"] / 2, m["h"] / 2)


func _settle() -> void:
	for k in 10:
		await get_tree().process_frame


## Parle au PNJ en appuyant sur les touches jusqu'à ce que tout soit refermé.
func _talk(nid: String) -> void:
	var w = world.find_walker(nid)
	if w == null:
		check(false, "PNJ %s trouvé sur %s" % [nid, world.map_id])
		return
	var done := [false]
	_autopilot(done)
	await Events.talk(world, w)
	done[0] = true
	await _settle()


func _top() -> Node:
	return Game._stack[-1] if not Game._stack.is_empty() else null


## Joue à la place du joueur : textes (A), menus (option voulue, sinon OUI, sinon au hasard), listes (premier choix).
func _autopilot(done: Array) -> void:
	var frames := 0
	while not done[0] and frames < 60000:
		frames += 1
		var t := _top()
		if frames % 5000 == 0:
			var info := ""
			if t is BattleScreen and t.battle != null:
				var b: Battle = t.battle
				var labels: Array = t._menu_labels.filter(func(l): return is_instance_valid(l)).map(func(l): return l.text)
				info = "tour %d, PV %s contre %s, invite=%s, menu=%s (%d), actif=%s" % [b.turn, b.sides[0].party.map(func(m): return m.hp),
					b.sides[1].party.map(func(m): return m.hp), t._prompt.text.replace("\n", " "), labels, t._menu_index,
					t._menu_active]
			print("   [pilote] ", frames, " ", t.get_script().resource_path.get_file() if t != null and t.get_script() else str(t), " ", info)
		if t == null:
			await get_tree().process_frame
			continue
		if t is TextBox:
			await _tap("a")
		elif t is Choice:
			var opts: Array = t.options
			var target := opts.find(want) if want != "" else -1
			if target < 0:
				target = opts.find("OUI")
			if target >= 0:
				t.index = target
				await _tap("a")
			else:
				await _tap("a")
		elif t is NameEntry:
			await _enter()
		elif t is ListPick:
			t.finish(0)
			await get_tree().process_frame
		elif t is PartyScreen:
			# Le premier Pokémon en forme (après un K.O., il faut en envoyer un autre).
			var pick := -1 if t.mode == "battle" else 0
			for i in Game.party.size():
				if Game.party[i].hp > 0 and not Game.party[i].is_egg and not (t.mode == "battle" and t.blocked.has(i)):
					pick = i
					break
			t.finish(pick)
			await get_tree().process_frame
		elif t is BattleScreen:
			# En combat : surtout A (attaquer), parfois changer de capacité ou de cible.
			await _tap(["a", "a", "a", "a", "down", "right", "up", "left"][randi() % 8])
		else:
			await _tap(["a", "a", "a", "down", "right", "up", "b"][randi() % 7])


func _enter() -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_ENTER
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().process_frame
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)
	await get_tree().process_frame


func _tap(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame
