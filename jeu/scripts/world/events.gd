class_name Events
extends RefCounted
## Scénario et interactions : dialogues, combats, soins, boutique, objets, évolutions.

const RIVAL_PICK := {1: 4, 4: 7, 7: 1}


static func ui() -> Node:
	return Game.ui


# ---------------------------------------------------------------------------
# Visibilité des PNJ selon l'avancée
# ---------------------------------------------------------------------------

static func npc_hidden(n: Dictionary) -> bool:
	var id: String = n.get("id", "")
	match n.get("kind", ""):
		"starter":
			return Game.flag("took_%d" % n["species"])
		"rival_lab":
			return Game.flag("rival_left_lab")
		"rival22":
			return not Game.flag("has_starter") or Game.flag("rival22_done")
	return false


static func trainer_beaten(map_id: String, data: Dictionary) -> bool:
	return Game.flag("tr_%s_%s" % [map_id, data["id"]])


# ---------------------------------------------------------------------------
# Menu Start
# ---------------------------------------------------------------------------

static func start_menu(ow: Node) -> void:
	while true:
		var opts := []
		if Game.flag("has_dex"):
			opts.append("POKéDEX")
		if Game.party.size() > 0:
			opts.append("POKéMON")
		opts += ["SAC", Game.player_name, "SAUVER", "FERMER"]
		var i: int = await ui().choose(opts, Vector2(340, 8))
		if i < 0 or opts[i] == "FERMER":
			return
		match opts[i]:
			"POKéDEX":
				await ui().open(PokedexScreen.new())
			"POKéMON":
				var ps := PartyScreen.new()
				ps.mode = "field"
				await ui().open(ps)
			"SAC":
				await bag_flow(ow)
			"SAUVER":
				if await ui().confirm("Voulez-vous sauvegarder la partie ?"):
					Game.pos = ow.player.tile
					Game.facing = ow.player.dir
					Game.save_game()
					await ui().say("%s a sauvegardé la partie." % Game.player_name)
				return
			_:
				await ui().open(TrainerCard.new())


# ---------------------------------------------------------------------------
# Déplacements spéciaux
# ---------------------------------------------------------------------------

static func on_step(ow: Node) -> bool:
	var t: Vector2i = ow.player.tile
	if ow.map_id == "bourg" and t.y <= 1 and not Game.flag("has_starter"):
		await chen_stops(ow)
		return true
	if ow.map_id == "labo" and not Game.flag("lab_intro"):
		await lab_intro(ow)
		return true
	return false


static func chen_stops(ow: Node) -> void:
	await ui().say(["Prof. Chen : Hé ! Attends ! Ne pars pas !",
		"C'est dangereux ! Des Pokémon sauvages vivent dans les hautes herbes !",
		"Il te faut ton propre Pokémon pour te protéger. Suis-moi !"])
	await ow.warp_to("labo", Vector2i(6, 7), "up")
	await lab_intro(ow)


static func lab_intro(ow: Node) -> void:
	Game.set_flag("lab_intro")
	await ui().say(["{rival} : Grand-père ! J'en ai marre d'attendre !",
		"Prof. Chen : {rival} ? Ah oui... Je t'avais dit de venir, toi aussi. Patience !",
		"Prof. Chen : {player}, sur cette table, il y a trois Pokémon.",
		"Ils sont dans des Poké Balls. Tu peux en choisir un. Vas-y !",
		"{rival} : Hé ! Et moi alors ?",
		"Prof. Chen : Sois patient, {rival}. Tu choisiras après lui."])


# ---------------------------------------------------------------------------
# Parler
# ---------------------------------------------------------------------------

static func talk(ow: Node, w: Node) -> void:
	var n: Dictionary = w.data
	var kind: String = n.get("kind", "")
	if kind not in ["item", "starter", "legend"]:
		w.face(ow.opposite(ow.player.dir))
	match kind:
		"trainer":
			if trainer_beaten(ow.map_id, n):
				await ui().say(n["trainer"]["defeat"])
			else:
				await trainer_battle(ow, w)
		"nurse":
			await nurse(ow)
		"mom":
			await mom()
		"shop":
			await ui().say("Bienvenue ! Que puis-je faire pour vous ?")
			var shop := ShopScreen.new()
			shop.stock = n["stock"]
			await ui().open(shop)
			await ui().say("Merci ! Revenez quand vous voulez !")
		"item":
			await pick_item(ow, w)
		"gift":
			if Game.flag(n["flag"]):
				await ui().say("J'espère que ça t'aide pour ton aventure !")
			else:
				await ui().say(n["text"])
				Game.add_item(n["item"], n["count"])
				Game.set_flag(n["flag"])
				await ui().say("%s reçoit %s !" % [Game.player_name, Data.item_name(n["item"])])
		"chen":
			await chen_talk()
		"rival_lab":
			if Game.flag("has_starter"):
				await ui().say("{rival} : Mon Pokémon a l'air plus fort que le tien !")
			else:
				await ui().say("{rival} : Vas-y, choisis ! Je prendrai le meilleur ensuite.")
		"starter":
			await choose_starter(ow, w)
		"rival22":
			await rival22(ow, w)
		"sister":
			if not Game.flag("sister_gift") and Game.flag("has_starter"):
				await ui().say(["Bonjour {player} ! Mon frère est parti avant toi...", "Tiens, ça te sera utile !"])
				Game.add_item("super-potion", 2)
				Game.set_flag("sister_gift")
				await ui().say("%s reçoit 2 Super Potions !" % Game.player_name)
			else:
				await ui().say("Mon frère {rival} veut devenir le meilleur Dresseur. Toi aussi, non ?")
		"oldman":
			await old_man()
		"info":
			await info_npc()
		"legend":
			await legend(ow, w)
		_:
			await ui().say(n.get("text", ["..."]))


static func sign(ow: Node, text: String) -> void:
	if text == "@pc":
		if Game.party.is_empty():
			await ui().say("C'est un PC. Il ne contient rien d'intéressant pour l'instant.")
			return
		await ui().say("%s allume le PC." % Game.player_name)
		await ui().open(PCScreen.new())
		return
	await ui().say(text.split("\n") if text.length() > 60 else text)


static func mom() -> void:
	if not Game.flag("has_starter"):
		await ui().say(["Maman : {player} ! Le Prof. Chen t'attend dans son labo.", "Il habite juste au sud du village. Vas-y vite !"])
		return
	await ui().say(["Maman : {player} ! Tu as l'air fatigué.", "Repose-toi un peu."])
	await ui().flash(2)
	Game.heal_party()
	Game.heal_point = {"map": "maison", "x": 4, "y": 3}
	await ui().say("Maman : Voilà ! Tes Pokémon sont en pleine forme. Bonne chance !")


static func nurse(ow: Node) -> void:
	await ui().say("Bienvenue au Centre Pokémon ! Nous soignons vos Pokémon gratuitement.")
	if not await ui().confirm("Voulez-vous que je soigne vos Pokémon ?"):
		await ui().say("À bientôt !")
		return
	await ui().say("Je prends vos Pokémon quelques secondes...")
	await ui().flash(4)
	Game.heal_party()
	if not Game.return_point.is_empty():
		Game.heal_point = {"map": ow.map_id, "x": 6, "y": 4}
	await ui().say(["Merci d'avoir attendu. Vos Pokémon sont en pleine forme !", "À bientôt !"])


static func chen_talk() -> void:
	if not Game.flag("has_starter"):
		await ui().say("Prof. Chen : Choisis un Pokémon dans une des Poké Balls sur la table !")
		return
	var seen := Game.seen.size()
	var caught := Game.caught.size()
	await ui().say(["Prof. Chen : Alors, {player}, comment avance ton Pokédex ?",
		"Tu as vu %d Pokémon et tu en as capturé %d." % [seen, caught],
		"Prof. Chen : " + ("Incroyable ! Tu as tout complété !" if caught >= 151 else
			"Continue ! Il reste encore beaucoup de Pokémon à découvrir." if caught < 50 else
			"Très bien ! Tu deviens un vrai chercheur !")])


static func old_man() -> void:
	await ui().say(["Vieil homme : Tu veux savoir comment capturer un Pokémon ?",
		"D'abord, affaiblis-le : moins il a de PV, plus il est facile à attraper.",
		"Un Pokémon endormi ou gelé est encore plus facile. Paralysé, brûlé ou empoisonné, ça aide aussi.",
		"Et chaque Ball a son effet : la Filet Ball pour les Insectes et l'Eau, la Sombre Ball dans les grottes, la Rapide Ball au premier tour...",
		"Allez, va remplir ton Pokédex !"])


static func info_npc() -> void:
	var i: int = await ui().ask("Chercheur : Tu veux une explication sur quoi ?", ["IV", "EV", "NATURES", "SHINY", "TALENTS", "RIEN"])
	match i:
		0:
			await ui().say(["Les IV sont des valeurs cachées de 0 à 31 pour chaque stat.", "Ils sont tirés au hasard à la naissance du Pokémon et ne changent jamais.", "Regarde le résumé de tes Pokémon : la page STATS les affiche !"])
		1:
			await ui().say(["Les EV s'obtiennent en battant des Pokémon : chaque espèce en donne dans une stat précise.", "Max 252 par stat et 510 au total. 4 EV = 1 point de stat au niveau 100.", "Les vitamines (PV Plus, Protéine, Fer...) donnent 10 EV."])
		2:
			await ui().say(["Il existe 25 natures. La plupart augmentent une stat de 10 % et en baissent une autre de 10 %.", "Dans le résumé, la stat montante est en rouge, la descendante en bleu."])
		3:
			await ui().say(["Les Pokémon chromatiques (shiny) ont une couleur différente.", "Il y a 1 chance sur 4096 d'en croiser un. Une étoile apparaît à côté de leur nom !"])
		4:
			await ui().say(["Chaque Pokémon a un talent : Intimidation baisse l'Attaque adverse, Statik peut paralyser au contact...", "Le résumé du Pokémon te montre son talent et ce qu'il fait."])


# ---------------------------------------------------------------------------
# Starter et rival
# ---------------------------------------------------------------------------

static func choose_starter(ow: Node, w: Node) -> void:
	if Game.flag("has_starter"):
		await ui().say("Ce sont les Pokémon du Prof. Chen.")
		return
	if not Game.flag("lab_intro"):
		await ui().say("Une Poké Ball. Il y a un Pokémon dedans.")
		return
	var sid: int = w.data["species"]
	var info := StarterScreen.new()
	info.species = sid
	var ok: bool = await ui().open(info)
	if not ok:
		return
	var mon := Pokemon.create(sid, 5)
	mon.ot = Game.player_name
	Game.give_pokemon(mon)
	Game.starter = sid
	Game.set_flag("has_starter")
	Game.set_flag("took_%d" % sid)
	ow.remove_walker(w)
	await ui().say("%s reçoit %s du Prof. Chen !" % [Game.player_name, mon.name()])
	if await ui().confirm("Voulez-vous donner un surnom à %s ?" % mon.name()):
		mon.nickname = await ui().enter_name("Surnom de %s :" % mon.data()["name"], mon.data()["name"], 10)
		if mon.nickname == mon.data()["name"]:
			mon.nickname = ""
	var rid: int = RIVAL_PICK[sid]
	var rival = ow.find_walker("rival")
	var rball = ow.find_walker("ball%d" % rid)
	await ui().say("{rival} : Alors je prends celui-là !")
	if rival != null and rball != null:
		while rival.tile.y > rball.tile.y + 1:
			await ow.walk(rival, "up", rival.tile + Vector2i(0, -1))
		while rival.tile.x != rball.tile.x:
			var d := "right" if rball.tile.x > rival.tile.x else "left"
			var next: Vector2i = rival.tile + (Vector2i(1, 0) if d == "right" else Vector2i(-1, 0))
			if ow.walker_at(next) != null or next == ow.player.tile:
				break
			await ow.walk(rival, d, next)
		rival.face("up")
		ow.remove_walker(rball)
	Game.set_flag("took_%d" % rid)
	Game.see(rid)
	await ui().say("{rival} reçoit %s du Prof. Chen !" % Data.pokemon[rid]["name"])
	if rival != null:
		rival.face(ow.opposite(ow.player.dir) if rival.tile.distance_to(ow.player.tile) <= 1 else "down")
	await ui().say(["{rival} : Attends, {player} !", "Voyons voir ce que valent nos Pokémon !", "Allez, viens te battre !"])
	var rmon := Pokemon.create(rid, 5)
	var result: String = await run_battle([rmon], false, {"name": Game.rival_name, "money": 140,
		"defeat": "Quoi ?! J'ai choisi le mauvais Pokémon !"}, {"no_blackout": true})
	if result == "win":
		await ui().say("{rival} : Pfff... Je vais entraîner mon Pokémon et je te battrai la prochaine fois !")
	else:
		await ui().say("{rival} : Ha ha ! J'ai gagné ! Mon Pokémon est le meilleur !")
	Game.heal_party()
	await ui().say(["{rival} : Grand-père, je pars à l'aventure ! Salut, minable !"])
	Game.set_flag("rival_left_lab")
	if rival != null:
		ow.remove_walker(rival)
	await ui().say(["Prof. Chen : {player}, j'ai une faveur à te demander.",
		"Voici le POKéDEX : il enregistre chaque Pokémon que tu vois ou captures.",
		"Mon rêve est d'avoir une encyclopédie complète des Pokémon du monde !"])
	Game.set_flag("has_dex")
	await ui().say("%s reçoit le POKéDEX !" % Game.player_name)
	Game.add_item("poke-ball", 5)
	await ui().say(["Prof. Chen : Et prends aussi ces Poké Balls.", "%s reçoit 5 Poké Balls !" % Game.player_name,
		"Prof. Chen : Lance-les sur les Pokémon sauvages affaiblis pour les capturer !",
		"Va à Jadielle, au nord. Bonne chance, {player} !"])


static func rival22(ow: Node, w: Node) -> void:
	await ui().say(["{rival} : Hé ! {player} ! Tu vas à la Ligue Pokémon ?",
		"Oublie ça ! Pas sans Badges ! Mais avant, voyons si tes Pokémon sont devenus plus forts !"])
	var rid: int = RIVAL_PICK.get(Game.starter, 4)
	var team := [Pokemon.create(16, 9), Pokemon.create(rid, 9)]
	var result: String = await run_battle(team, false, {"name": Game.rival_name, "money": 280,
		"defeat": "Pas mal... Mais je deviendrai le meilleur Dresseur du monde !"}, {"no_blackout": true})
	Game.set_flag("rival22_done")
	if result != "win":
		Game.heal_party()
	await ui().say("{rival} : J'y vais ! On se reverra, {player} !")
	await ui().fade(true, 0.2)
	ow.remove_walker(w)
	await ui().fade(false, 0.2)


# ---------------------------------------------------------------------------
# Dresseurs, Pokémon sauvages, légendaires
# ---------------------------------------------------------------------------

static func trainer_spotted(ow: Node, w: Node) -> void:
	await ow.show_emote(w)
	await ow.approach(w)
	ow.player.face(ow.opposite(w.dir))
	await trainer_battle(ow, w)


static func trainer_battle(ow: Node, w: Node) -> void:
	var tr: Dictionary = w.data["trainer"]
	await ui().say(tr["intro"])
	var team := []
	for e in tr["team"]:
		team.append(Pokemon.create(e[0], e[1]))
	var result: String = await run_battle(team, false, tr)
	if result == "win":
		Game.set_flag("tr_%s_%s" % [ow.map_id, w.data["id"]])


static func wild_encounter(ow: Node, table: Array) -> void:
	var total := 0
	for e in table:
		total += e[3]
	var r := randi() % total
	var pick: Array = table[0]
	for e in table:
		r -= e[3]
		if r < 0:
			pick = e
			break
	var lvl := randi_range(pick[1], pick[2])
	var lead := Game.lead()
	if Game.repel_steps > 0 and lead != null and lvl < lead.level:
		return
	var mon := Pokemon.create(pick[0], lvl)
	await run_battle([mon], true, {}, {"cave": ow.map.get("cave", false)})


static func legend(ow: Node, w: Node) -> void:
	var n: Dictionary = w.data
	await ui().say(n["text"])
	if not await ui().confirm("Approcher du Pokémon ?"):
		return
	await ui().say("%s : Kyaaah !" % Data.pokemon[n["species"]]["name"])
	var mon := Pokemon.create(n["species"], n["level"])
	var result: String = await run_battle([mon], true, {}, {"cave": true})
	if result in ["win", "caught"]:
		Game.set_flag(n["flag"])
		ow.remove_walker(w)


static func pick_item(ow: Node, w: Node) -> void:
	var n: Dictionary = w.data
	Game.add_item(n["item"], n["count"])
	Game.set_flag(n["flag"])
	ow.remove_walker(w)
	var name := Data.item_name(n["item"])
	await ui().say("%s trouve %s%s !" % [Game.player_name, name, "" if n["count"] == 1 else " x%d" % n["count"]])


# ---------------------------------------------------------------------------
# Combat complet : écran, captures, évolutions, défaite
# ---------------------------------------------------------------------------

static func run_battle(enemy: Array, wild: bool, trainer: Dictionary, opts := {}) -> String:
	for m in enemy:
		Game.see(m.species)
	if Game.alive_count() == 0:
		return "lose"
	await ui().flash(3)
	var screen := BattleScreen.new()
	screen.battle = Battle.new(Game.party, enemy, wild, trainer)
	screen.battle.player_name = Game.player_name
	screen.battle.cave = opts.get("cave", false)
	screen.battle.caught_species = Game.caught.keys()
	var result: String = await ui().open(screen)
	var battle: Battle = screen.battle
	if result == "win" and not wild:
		Game.money += int(trainer.get("money", 0))
	Game.money += battle.pay_day
	if result == "caught":
		var mon := battle.caught
		var new := not Game.caught.has(mon.species)
		var where := Game.give_pokemon(mon)
		if new:
			await ui().say("Les données de %s sont ajoutées au Pokédex." % mon.data()["name"])
		if await ui().confirm("Donner un surnom à %s ?" % mon.name()):
			var nick: String = await ui().enter_name("Surnom :", mon.data()["name"], 10)
			mon.nickname = "" if nick == mon.data()["name"] else nick
		if where == "pc":
			await ui().say("%s est envoyé dans le PC." % mon.name())
	for m in Game.party:
		if m.ability != 0 and Data.ability_ident(m.ability) == "pickup" and randi() % 10 == 0 and result == "win":
			var found: String = ["potion", "super-potion", "great-ball", "ultra-ball", "rare-candy", "full-heal", "ether", "revive"][randi() % 8]
			Game.add_item(found)
			await ui().say("%s a ramassé %s !" % [m.name(), Data.item_name(found)])
	if result == "lose":
		if opts.get("no_blackout", false):
			return result
		var lost := Game.money / 2
		Game.money -= lost
		await ui().say("%s perd %d ₽..." % [Game.player_name, lost])
		Game.heal_party()
		var hp: Dictionary = Game.heal_point
		await Game.world.warp_to(hp["map"], Vector2i(hp["x"], hp["y"]), "down")
		return result
	# Évolutions après le combat.
	for i in battle.leveled:
		if i < Game.party.size():
			var mon: Pokemon = Game.party[i]
			var to := mon.level_evolution()
			if to != 0 and not mon.is_fainted():
				await evolve(mon, to)
	return result


static func evolve(mon: Pokemon, to: int) -> bool:
	var ev := EvolutionScreen.new()
	ev.mon = mon
	ev.to = to
	var ok: bool = await ui().open(ev)
	if not ok:
		await ui().say("%s n'a pas évolué." % mon.name())
		return false
	Game.catch_register(to)
	for mid in mon.moves_at(mon.level):
		await learn_move(mon, mid)
	return true


static func learn_move(mon: Pokemon, mid: int) -> bool:
	var mname := Data.move_name(mid)
	if mon.knows(mid):
		await ui().say("%s connaît déjà %s." % [mon.name(), mname])
		return false
	if mon.moves.size() < 4:
		mon.moves.append(Pokemon.make_move(mid))
		await ui().say("%s apprend %s !" % [mon.name(), mname])
		return true
	await ui().say(["%s veut apprendre %s." % [mon.name(), mname], "Mais %s connaît déjà quatre capacités." % mon.name()])
	while true:
		if await ui().confirm("Oublier une capacité pour apprendre %s ?" % mname):
			var opts := []
			for m in mon.moves:
				opts.append("%s (%d/%d PP)" % [Data.move_name(m["id"]), m["pp"], m["max"]])
			var i: int = await ui().ask("Quelle capacité oublier ?", opts)
			if i >= 0:
				var old := Data.move_name(mon.moves[i]["id"])
				mon.moves[i] = Pokemon.make_move(mid)
				await ui().say(["1, 2 et... Tadaaa !", "%s oublie %s..." % [mon.name(), old], "Et apprend %s !" % mname])
				return true
		elif await ui().confirm("Abandonner l'apprentissage de %s ?" % mname):
			await ui().say("%s n'a pas appris %s." % [mon.name(), mname])
			return false
	return false


# ---------------------------------------------------------------------------
# Objets hors combat
# ---------------------------------------------------------------------------

static func bag_flow(ow: Node) -> void:
	while true:
		var bag := BagScreen.new()
		bag.mode = "field"
		var item = await ui().open(bag)
		if item == null:
			return
		await use_item_field(ow, item)


static func use_item_field(ow: Node, item: String) -> void:
	if ItemUse.is_ball(item) or item in ItemUse.BATTLE_ONLY:
		await ui().say("Ce n'est pas le moment d'utiliser ça !")
		return
	if item.ends_with("repel"):
		var steps: int = {"repel": 100, "super-repel": 200, "max-repel": 250}[item]
		Game.repel_steps = steps
		Game.remove_item(item)
		await ui().say("%s utilise %s ! Les Pokémon faibles ne s'approcheront plus." % [Game.player_name, Data.item_name(item)])
		return
	if item == "escape-rope":
		if ow.map.get("cave", false):
			Game.remove_item(item)
			await ui().say("%s utilise la Corde Sortie !" % Game.player_name)
			await ow.warp_to("plaine", Vector2i(19, 4), "down")
		else:
			await ui().say("Ce n'est pas le moment d'utiliser ça !")
		return
	if not ItemUse.targets_pokemon(item):
		await ui().say("Ce n'est pas le moment d'utiliser ça !")
		return
	var ps := PartyScreen.new()
	ps.mode = "select"
	ps.item = item
	ps.title = "Sur quel Pokémon ?"
	var idx = await ui().open(ps)
	if idx == null or idx < 0:
		return
	var mon: Pokemon = Game.party[idx]
	if ItemUse.is_tm(item):
		var mid: int = Data.items[item]["move"]
		await ui().say("%s contient %s." % [Data.item_name(item).split(" ")[0], Data.move_name(mid)])
		if not mon.can_learn_tm(mid):
			await ui().say("%s ne peut pas apprendre %s." % [mon.name(), Data.move_name(mid)])
			return
		await learn_move(mon, mid)
		return
	if item in ItemUse.STONES:
		var to := mon.item_evolution(item)
		if to == 0:
			await ui().say("Ça n'aura aucun effet.")
			return
		Game.remove_item(item)
		await evolve(mon, to)
		return
	if item == "rare-candy":
		if mon.level >= 100 or mon.is_fainted():
			await ui().say("Ça n'aura aucun effet.")
			return
		Game.remove_item(item)
		mon.add_exp(mon.exp_to_next())
		await ui().say("%s monte au niveau %d !" % [mon.name(), mon.level])
		for mid in mon.moves_at(mon.level):
			await learn_move(mon, mid)
		var evo := mon.level_evolution()
		if evo != 0:
			await evolve(mon, evo)
		return
	var move_index := -1
	if ItemUse.needs_move(item):
		var opts := []
		for m in mon.moves:
			opts.append("%s %d/%d" % [Data.move_name(m["id"]), m["pp"], m["max"]])
		move_index = await ui().ask("Quelle capacité ?", opts)
		if move_index < 0:
			return
	var text := ItemUse.apply(mon, item, move_index)
	if text == "":
		await ui().say("Ça n'aura aucun effet.")
		return
	Game.remove_item(item)
	await ui().say(text.split("\n"))
