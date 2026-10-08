class_name Events
extends RefCounted
## Scénario et interactions : dialogues, scripts des PNJ, combats (solo et coop), soins, objets, évolutions.

const RIVAL_PICK := {1: 4, 4: 7, 7: 1}
## Partenaires du rival selon son starter (comme dans Rouge Feu).
const RIVAL_MATES := {4: [130, 102], 7: [58, 102], 1: [130, 58]}
## Équipes du rival à chaque rencontre : [espèce ou "starter"/"mate0"/"mate1", niveau].
const RIVAL_TEAMS := {
	3: [[17, 17], [63, 16], [19, 15], ["starter", 18]],
	4: [[17, 25], [64, 20], ["mate0", 22], ["starter", 25]],
	5: [[17, 37], [64, 35], ["mate0", 38], ["mate1", 35], ["starter", 40]],
	6: [[18, 47], [112, 45], [65, 47], ["mate0", 45], ["mate1", 45], ["starter", 53]],
	7: [[18, 59], [65, 57], [112, 59], ["mate0", 61], ["mate1", 61], ["starter", 63]],
}
const FOSSILS := {"helix-fossil": 138, "dome-fossil": 140, "old-amber": 142}


static func ui() -> Node:
	return Game.ui


static func fmt(s: String) -> String:
	return s.replace("{player}", Game.player_name).replace("{rival}", Game.rival_name)


# ---------------------------------------------------------------------------
# Visibilité des PNJ selon l'avancée
# ---------------------------------------------------------------------------

static func npc_hidden(n: Dictionary) -> bool:
	match n.get("kind", ""):
		"starter":
			return Game.flag("took_%d" % n["species"])
		"rival_lab":
			return Game.flag("rival_left_lab")
		"rival22":
			return not Game.flag("has_starter") or Game.flag("rival22_done")
		"rival_final":
			return not Game.flag("badge_8") or Game.flag("rival22_final")
	return false


static func trainer_beaten(_map_id: String, data: Dictionary) -> bool:
	return Game.flag("tr_%s" % data.get("trainer", data.get("id", "")))


# ---------------------------------------------------------------------------
# Menu Start
# ---------------------------------------------------------------------------

static func start_menu(ow: Node) -> void:
	while true:
		var r = await ui().open(StartMenu.new())
		if r == null or r == "close":
			return
		match r:
			"dex":
				await ui().open(PokedexScreen.new())
			"party":
				var ps := PartyScreen.new()
				ps.mode = "field"
				await ui().open(ps)
			"bag":
				await bag_flow(ow)
			"outfits":
				await ui().open(WardrobeScreen.new())
				ow.refresh_player_look()
				if Engine.has_singleton("Net") or ow.has_node("/root/Net"):
					Net.send_state()
			"journal":
				await ui().open(JournalScreen.new())
			"map":
				await ui().open(WorldMapScreen.new())
			"online":
				await ui().open(OnlineScreen.new())
			"card":
				await ui().open(TrainerCard.new())
			"settings":
				await ui().open(SettingsScreen.new())
			"save":
				if await ui().confirm("Voulez-vous sauvegarder la partie ?"):
					Game.pos = ow.player.tile
					Game.facing = ow.player.dir
					Game.save_game()
					Audio.sfx("save")
					await ui().say("%s a sauvegardé la partie." % Game.player_name)
				return


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
	if ow.map_id == "jadielle" and Game.quests.get("main", 0) < 1 and Game.flag("has_starter"):
		Game.set_quest("main", 1)
	return false


static func chen_stops(ow: Node) -> void:
	await ui().say(["Prof. Chen : Hé ! Attends ! Ne pars pas !",
		"C'est dangereux ! Des Pokémon sauvages vivent dans les hautes herbes !",
		"Il te faut ton propre Pokémon pour te protéger. Suis-moi !"])
	await ow.warp_to("labo", Vector2i(6, 7), "up")
	await lab_intro(ow)


static func lab_intro(_ow: Node) -> void:
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
	if kind not in ["item", "starter", "legend"] and n.get("look", "") != "legend":
		w.face(ow.opposite(ow.player.dir))
	match kind:
		"trainer":
			if trainer_beaten(ow.map_id, n):
				await ui().say(Game.trainers[n["trainer"]]["defeat"])
			else:
				await trainer_battle(ow, w)
		"nurse":
			await nurse(ow)
		"mom":
			await mom()
		"shop":
			await shop(n["stock"])
		"outfit_shop":
			await outfit_shop(n["stock"])
		"item":
			await pick_item(ow, w)
		"gift":
			if Game.flag(n["flag"]):
				await ui().say("J'espère que ça t'aide pour ton aventure !")
			else:
				await ui().say(n["text"])
				Game.add_item(n["item"], n["count"])
				Game.set_flag(n["flag"])
				Audio.jingle("item")
				await ui().say("%s reçoit %s x%d !" % [Game.player_name, Data.item_name(n["item"]), n["count"]])
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
		"rival_final":
			await rival_final(ow, w)
		"sister":
			if not Game.flag("sister_gift") and Game.flag("has_starter"):
				await ui().say(["Bonjour {player} ! Mon frère est parti avant toi...", "Tiens, la Carte de Kanto ! Appuie sur la touche CARTE pour l'ouvrir."])
				Game.add_item("town-map")
				Game.add_item("super-potion", 2)
				Game.set_flag("sister_gift")
				Audio.jingle("item")
				await ui().say("%s reçoit la Carte et 2 Super Potions !" % Game.player_name)
			else:
				await ui().say("Mon frère {rival} veut devenir le meilleur Dresseur. Toi aussi, non ?")
		"oldman":
			await old_man()
		"info":
			await info_npc()
		"legend":
			await legend(ow, w)
		"daycare":
			await daycare()
		"fossil":
			await fossil()
		"script":
			await run_script(ow, w, n.get("script", []))
		_:
			await ui().say(n.get("text", ["..."]))


static func sign(_ow: Node, text: String) -> void:
	if text == "@pc":
		if Game.party.is_empty():
			await ui().say("C'est un PC. Il ne contient rien d'intéressant pour l'instant.")
			return
		await ui().say("%s allume le PC." % Game.player_name)
		await ui().open(PCScreen.new())
		return
	if text == "@wardrobe":
		await ui().open(WardrobeScreen.new())
		Game.world.refresh_player_look()
		return
	await ui().say(text.split("\n") if text.length() > 50 else text)


static func mom() -> void:
	if not Game.flag("has_starter"):
		await ui().say(["Maman : {player} ! Le Prof. Chen t'attend dans son labo.", "Il habite juste au sud du village. Vas-y vite !"])
		return
	await ui().say(["Maman : {player} ! Tu as l'air fatigué.", "Repose-toi un peu."])
	Audio.jingle("heal")
	await ui().flash(2)
	Game.heal_party()
	Game.heal_point = {"map": "maison", "x": 4, "y": 3}
	await ui().say(["Maman : Voilà ! Tes Pokémon sont en pleine forme.", "N'oublie pas : la penderie à côté du PC te permet de changer de tenue !"])


static func nurse(ow: Node) -> void:
	await ui().say("Bienvenue au Centre Pokémon ! Nous soignons vos Pokémon gratuitement.")
	if not await ui().confirm("Voulez-vous que je soigne vos Pokémon ?"):
		await ui().say("À bientôt !")
		return
	await ui().say("Je prends vos Pokémon quelques secondes...")
	Audio.jingle("heal")
	await ui().flash(4)
	Game.heal_party()
	if ow.map.get("heal", false):
		Game.heal_point = {"map": ow.map_id, "x": 6, "y": 4}
	else:
		Game.heal_point = {"map": ow.map_id, "x": ow.player.tile.x, "y": ow.player.tile.y}
	await ui().say(["Merci d'avoir attendu. Vos Pokémon sont en pleine forme !", "À bientôt !"])


static func chen_talk() -> void:
	if not Game.flag("has_starter"):
		await ui().say("Prof. Chen : Choisis un Pokémon dans une des Poké Balls sur la table !")
		return
	if Game.item_count("oaks-parcel") > 0:
		Game.remove_item("oaks-parcel")
		Game.set_flag("parcel_done")
		Game.set_quest("main", 3)
		await ui().say(["Prof. Chen : Oh ! Mon colis ! Merci, {player} !", "C'est une Poké Ball spéciale que j'avais commandée... Garde ces Super Balls pour ta peine !"])
		Game.add_item("great-ball", 5)
		Audio.jingle("item")
		await ui().say("Va maintenant à Argenta, au nord de la Forêt de Jade. Le Champion Pierre t'y attend !")
		return
	if Game.caught.size() >= 150 and Game.flag("champion") and not Game.flag("mew_got"):
		await ui().say(["Prof. Chen : Incroyable ! 150 Pokémon capturés !", "Un Pokémon mystérieux est apparu dans mon jardin ce matin... Il t'attendait, je crois."])
		Game.set_flag("mew_got")
		await run_battle([[Pokemon.create(151, 30)]], true, [], {"legend": true})
		return
	await ui().say(["Prof. Chen : Alors, {player}, comment avance ton Pokédex ?",
		"Tu as vu %d Pokémon et tu en as capturé %d." % [Game.seen.size(), Game.caught.size()],
		"Prof. Chen : " + ("Incroyable ! Tu as presque tout complété !" if Game.caught.size() >= 140 else
			"Continue ! Il reste encore beaucoup de Pokémon à découvrir." if Game.caught.size() < 50 else
			"Très bien ! Tu deviens un vrai chercheur !")])


static func old_man() -> void:
	await ui().say(["Vieil homme : Tu veux savoir comment capturer un Pokémon ?",
		"D'abord, affaiblis-le : moins il a de PV, plus il est facile à attraper.",
		"Un Pokémon endormi ou gelé est encore plus facile. Paralysé, brûlé ou empoisonné, ça aide aussi.",
		"Et chaque Ball a son effet : Filet Ball pour Insecte et Eau, Sombre Ball dans les grottes, Rapide Ball au 1er tour, Chrono Ball pour les longs combats...",
		"Allez, va remplir ton Pokédex !"])


static func info_npc() -> void:
	var i: int = await ui().ask("Chercheur : Tu veux une explication sur quoi ?", ["IV", "EV", "NATURES", "SHINY", "ŒUFS", "RIEN"])
	match i:
		0:
			await ui().say(["Les IV sont des valeurs cachées de 0 à 31 pour chaque stat.", "Ils sont tirés au hasard à la naissance du Pokémon et ne changent jamais.", "La page STATS du résumé les affiche !"])
		1:
			await ui().say(["Les EV s'obtiennent en battant des Pokémon : chaque espèce en donne dans une stat précise.", "Max 252 par stat et 510 au total. 4 EV = 1 point de stat au niveau 100.", "Les vitamines (PV Plus, Protéine, Fer...) donnent 10 EV."])
		2:
			await ui().say(["Il existe 25 natures. La plupart augmentent une stat de 10 % et en baissent une autre de 10 %.", "Dans le résumé, la stat montante est en rouge, la descendante en bleu."])
		3:
			await ui().say(["Les Pokémon chromatiques (shiny) ont une couleur différente.", "Il y a 1 chance sur 4096 d'en croiser un. Une étoile apparaît à côté de leur nom !"])
		4:
			await ui().say(["Laisse deux Pokémon du même groupe d'œufs (un mâle, une femelle) à la Pension de la Route 5.", "Métamorph s'entend avec presque tout le monde !", "Ensuite, marche beaucoup avec l'Œuf dans ton équipe pour qu'il éclose."])


# ---------------------------------------------------------------------------
# Interpréteur de scripts (données générées par tools/build_world.py)
# ---------------------------------------------------------------------------

## Exécute une liste de commandes. Renvoie false si le script s'interrompt (combat perdu).
static func run_script(ow: Node, w: Node, cmds: Array) -> bool:
	for c in cmds:
		if not await _cmd(ow, w, c):
			return false
	return true


static func _cmd(ow: Node, w: Node, c: Array) -> bool:
	match c[0]:
		"noop":
			pass
		"say":
			await ui().say(c[1].map(func(s): return fmt(str(s))))
		"if":
			return await run_script(ow, w, c[2] if Game.check(c[1]) else c[3])
		"set":
			Game.set_flag(c[1])
		"give":
			Game.add_item(c[1], c[2])
			Audio.jingle("item")
			await ui().say("%s reçoit %s%s !" % [Game.player_name, Data.item_name(c[1]), "" if c[2] == 1 else " x%d" % c[2]])
		"take":
			Game.remove_item(c[1], c[2])
		"money":
			Game.money += int(c[1])
		"pay":
			if Game.money >= int(c[1]):
				Game.money -= int(c[1])
				return await run_script(ow, w, c[2])
			return await run_script(ow, w, c[3])
		"mon":
			var m := Pokemon.create(int(c[1]), int(c[2]))
			var where := Game.give_pokemon(m)
			Audio.jingle("item")
			await ui().say("%s reçoit %s !" % [Game.player_name, m.name()] + (" Il est envoyé au PC." if where == "pc" else ""))
		"egg":
			Game.give_pokemon(Pokemon.create_egg(int(c[1])))
			Audio.jingle("item")
			await ui().say("%s reçoit un Œuf !" % Game.player_name)
		"outfit":
			if Game.give_outfit(c[1]):
				Audio.jingle("item")
				await ui().say("Nouvelle tenue : « %s » ! Change de tenue depuis le menu (TENUES)." % Game.OUTFITS[c[1]]["name"])
		"badge":
			Game.give_badge(int(c[1]))
			Audio.jingle("badge")
			await ui().say("%s obtient le Badge %s !" % [Game.player_name, ["Roche", "Cascade", "Foudre", "Prisme", "Âme", "Marais", "Volcan", "Terre"][int(c[1]) - 1]])
			if Net.online():
				Net.share_badge(int(c[1]))
		"battle":
			var tid: String = c[1]
			var res: String = await trainer_battle_id(ow, tid, w)
			if res != "win":
				return false
		"league_battle":
			var res2: String = await trainer_battle_id(ow, c[1], w)
			if res2 != "win":
				for k in range(1, 5):
					Game.set_flag("elite_%d_done" % k, false)
				return false
		"double_battle":
			var t: Dictionary = Game.trainers[c[1]]
			var res3: String = await run_battle([make_team(t["team"], t)], false, [t], {"double": true})
			if res3 != "win":
				return false
			Game.set_flag("tr_%s" % c[1])
		"heal":
			Game.heal_party()
		"hide":
			Game.set_flag("hidden_%s_%s" % [ow.map_id, c[1]])
			var hw = ow.find_walker(c[1])
			if hw != null:
				ow.remove_walker(hw)
		"quest":
			Game.set_quest(c[1], int(c[2]))
		"legend":
			var lm := Pokemon.create(int(c[1]), int(c[2]))
			await ui().say("%s : Kyaaah !" % lm.name())
			if lm.species > 0:
				Audio.cry(lm.species)
			var r: String = await run_battle([[lm]], true, [], {"legend": true, "cave": ow.map.get("cave", false)})
			if r in ["win", "caught"]:
				Game.set_flag(c[3])
				if w != null and is_instance_valid(w):
					ow.remove_walker(w)
			else:
				return false
		"boss":
			var bm := make_boss(int(c[1]), int(c[2]))
			var rb: String = await run_battle([[bm]], true, [], {"boss": true, "cave": ow.map.get("cave", false)})
			if rb != "win":
				return false
			Game.set_flag(c[3])
			if w != null and is_instance_valid(w):
				ow.remove_walker(w)
		"choice":
			var i: int = await ui().ask(fmt(c[1]), c[2])
			if i >= 0 and i < c[3].size():
				return await run_script(ow, w, c[3][i])
		"warp":
			await ow.warp_to(c[1], Vector2i(c[2], c[3]), c[4])
		"flash":
			await ui().flash(3)
		"hall_of_fame":
			await hall_of_fame(ow)
		"special":
			return await special(ow, w, c[1], c.slice(2))
	return true


static func special(ow: Node, _w: Node, name: String, args: Array) -> bool:
	match name:
		"shop":
			await shop(args[0])
		"rival_battle":
			return await rival_battle(int(args[0])) == "win"
		"gift_egg":
			var opts: Array = args[0]
			Game.give_pokemon(Pokemon.create_egg(opts[randi() % opts.size()]))
			Audio.jingle("item")
			await ui().say("%s reçoit un Œuf !" % Game.player_name)
			Game.set_quest("pension", 1)
	return true


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
	Audio.jingle("item")
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
	await ui().say(["{rival} : Attends, {player} !", "Voyons voir ce que valent nos Pokémon !", "Allez, viens te battre !"])
	var rmon := Pokemon.create(rid, 5)
	var result: String = await run_battle([[rmon]], false, [{"name": Game.rival_name, "money": 140, "class": "Rival",
		"defeat": "Quoi ?! J'ai choisi le mauvais Pokémon !", "look": "rival"}], {"no_blackout": true, "no_coop": true})
	if result == "win":
		await ui().say("{rival} : Pfff... Je vais entraîner mon Pokémon et je te battrai la prochaine fois !")
	else:
		await ui().say("{rival} : Ha ha ! J'ai gagné ! Mon Pokémon est le meilleur !")
	Game.heal_party()
	await ui().say(["{rival} : Grand-père, je pars à l'aventure ! Salut, minable !"])
	Game.set_flag("rival_left_lab")
	if rival != null and is_instance_valid(rival):
		ow.remove_walker(rival)
	await ui().say(["Prof. Chen : {player}, j'ai une faveur à te demander.",
		"Voici le POKéDEX : il enregistre chaque Pokémon que tu vois ou captures.",
		"Mon rêve est d'avoir une encyclopédie complète des Pokémon du monde !"])
	Game.set_flag("has_dex")
	Audio.jingle("item")
	await ui().say("%s reçoit le POKéDEX !" % Game.player_name)
	Game.add_item("poke-ball", 5)
	await ui().say(["Prof. Chen : Et prends aussi ces Poké Balls.", "%s reçoit 5 Poké Balls !" % Game.player_name,
		"Prof. Chen : Lance-les sur les Pokémon sauvages affaiblis pour les capturer !",
		"Va à Jadielle, au nord. Ton journal (menu JOURNAL) t'indique toujours quoi faire. Bonne chance !"])
	Game.set_quest("main", 1)


static func rival_starter() -> int:
	return RIVAL_PICK.get(Game.starter, 4)


static func evolve_to_level(sid: int, lvl: int) -> int:
	var s := sid
	for i in 3:
		var nxt := 0
		for e in Data.pokemon[s]["evos"]:
			if e.has("level") and lvl >= e["level"]:
				nxt = e["to"]
			elif e.get("item", "") != "" and e["item"] != "linking-cord" and lvl >= 32 and nxt == 0 and s != 133:
				nxt = e["to"]
			elif e.get("item", "") == "linking-cord" and lvl >= 38:
				nxt = e["to"]
		if nxt == 0:
			break
		s = nxt
	return s


static func rival_team(stage: int) -> Array:
	var rs := rival_starter()
	var mates: Array = RIVAL_MATES[rs]
	var team := []
	for e in RIVAL_TEAMS[stage]:
		var sid = e[0]
		if sid is String:
			sid = rs if sid == "starter" else mates[0] if sid == "mate0" else mates[1]
		team.append([evolve_to_level(sid, e[1]), e[1]])
	return team


static func rival_battle(stage: int) -> String:
	var t := {"name": Game.rival_name, "class": "Rival", "money": 100 * RIVAL_TEAMS[stage][-1][1], "potions": 2 if stage >= 5 else 1,
		"defeat": "{rival} : Quoi ?! Encore perdu !", "look": "rival", "kind": "rival" if stage < 7 else "elite", "music": "rival"}
	t["defeat"] = fmt(t["defeat"])
	var res: String = await run_battle([make_team(rival_team(stage), t)], false, [t], {"no_blackout": stage < 7})
	return res


static func rival22(ow: Node, w: Node) -> void:
	await ui().say(["{rival} : Hé ! {player} ! Tu vas à la Ligue Pokémon ?",
		"Oublie ça ! Pas sans Badges ! Mais avant, voyons si tes Pokémon sont devenus plus forts !"])
	var rid := rival_starter()
	var t := {"name": Game.rival_name, "class": "Rival", "money": 280, "defeat": "Pas mal... Mais je deviendrai le meilleur Dresseur du monde !", "look": "rival", "music": "rival"}
	var result: String = await run_battle([make_team([[16, 9], [rid, 9]], t)], false, [t], {"no_blackout": true})
	Game.set_flag("rival22_done")
	if result != "win":
		Game.heal_party()
	await ui().say("{rival} : J'y vais ! On se reverra, {player} !")
	await ui().fade(true, 0.2)
	ow.remove_walker(w)
	await ui().fade(false, 0.2)


static func rival_final(ow: Node, w: Node) -> void:
	await ui().say(["{rival} : {player} ! Toi aussi tu as les 8 Badges ?", "On se retrouve à la Ligue. Mais d'abord, un dernier échauffement !"])
	var res := await rival_battle(6)
	if res == "win":
		Game.set_flag("rival22_final")
		await ui().say("{rival} : Tch... Rendez-vous au Plateau Indigo !")
		ow.remove_walker(w)


# ---------------------------------------------------------------------------
# Équipes adverses (difficulté, boss, camarade en coop)
# ---------------------------------------------------------------------------

## Construit une équipe à partir de [[espèce, niveau], ...] selon la difficulté choisie.
static func make_team(entries: Array, t: Dictionary = {}) -> Array:
	var diff := Game.difficulty()
	var strong: bool = t.get("kind", "") in ["leader", "elite", "rival"]
	var team := []
	for e in entries:
		var lvl: int = e[1]
		if diff == 1:
			lvl = int(round(lvl * (1.1 if strong else 1.05)))
		elif diff == 2:
			lvl = int(round(lvl * (1.2 if strong else 1.1)))
		lvl = clampi(lvl, 1, 100)
		var m := Pokemon.create(evolve_to_level(e[0], lvl) if diff > 0 else e[0], lvl)
		if diff > 0 and strong:
			for i in 6:
				m.ivs[i] = 31 if diff == 2 else maxi(m.ivs[i], 20)
			if diff == 2:
				var best := 1 if m.data()["base"][1] >= m.data()["base"][3] else 3
				m.evs = [4, 0, 0, 0, 0, 252]
				m.evs[best] = 252
			m.recalc_stats()
			m.hp = m.max_hp()
		team.append(m)
	return team


static func make_boss(sid: int, lvl: int) -> Pokemon:
	var m := Pokemon.create(sid, lvl)
	m.boss = true
	var mult := 3
	if Net.coop_ready():
		mult = 5
	m.stats[0] *= mult
	m.hp = m.stats[0]
	for i in 6:
		m.ivs[i] = 31
	return m


## Dresseur « camarade » qui apparaît en coop : même catégorie, équipe équivalente.
static func partner_trainer(t: Dictionary) -> Dictionary:
	var cls: String = t.get("class", "Dresseur")
	var pool: Array = Game.classes.get(cls, {}).get("pool", [])
	if t.get("pool_type") != null and Game.type_pool.has(t["pool_type"]):
		pool = Game.type_pool[t["pool_type"]]
	if pool.is_empty():
		pool = Game.classes["Dresseur"]["pool"]
	var team := []
	for e in t["team"]:
		team.append([evolve_to_level(pool[randi() % pool.size()], e[1]), e[1]])
	var names := ["Léa", "Malo", "Anna", "Yanis", "Chloé", "Lucas", "Manon", "Gabin", "Louise", "Arthur"]
	var name := "%s %s" % [cls, names[randi() % names.size()]]
	if t.get("kind", "") in ["leader", "elite"]:
		name = "Disciple de %s" % t["name"].split(" ")[-1]
	elif cls in ["Sbire Rocket", "Admin Rocket", "Boss Rocket"]:
		name = "Sbire Rocket"
	elif cls == "Rival":
		name = "Ami de %s" % Game.rival_name
	return {"name": name, "class": cls, "team": team, "money": int(t.get("money", 100) / 2), "potions": 0,
		"defeat": "On a perdu...", "look": t.get("look", "ace"), "kind": t.get("kind", "normal")}


# ---------------------------------------------------------------------------
# Dresseurs, Pokémon sauvages, légendaires
# ---------------------------------------------------------------------------

static func trainer_spotted(ow: Node, w: Node) -> void:
	await ow.show_emote(w)
	await ow.approach(w)
	ow.player.face(ow.opposite(w.dir))
	await trainer_battle(ow, w)


static func trainer_battle(ow: Node, w: Node) -> void:
	var tid: String = w.data["trainer"]
	var t: Dictionary = Game.trainers[tid]
	await ui().say(fmt(t["intro"]))
	await trainer_battle_id(ow, tid, w, true)


static func trainer_battle_id(_ow: Node, tid: String, _w: Node = null, skip_intro := true) -> String:
	var t: Dictionary = Game.trainers[tid].duplicate(true)
	t["defeat"] = fmt(t["defeat"])
	var result: String = await run_battle([make_team(t["team"], t)], false, [t], {})
	if result == "win":
		Game.set_flag("tr_%s" % tid)
	return result


static func pick_wild(table: Array) -> Pokemon:
	var total := 0
	for e in table:
		total += e[3]
	var r := randi() % maxi(1, total)
	var pick: Array = table[0]
	for e in table:
		r -= e[3]
		if r < 0:
			pick = e
			break
	return Pokemon.create(pick[0], randi_range(pick[1], pick[2]))


static func wild_encounter(ow: Node, table: Array) -> void:
	var mon := pick_wild(table)
	var lead := Game.lead()
	if Game.repel_steps > 0 and lead != null and mon.level < lead.level:
		return
	var enemies := [[mon]]
	if Net.coop_ready():
		enemies.append([pick_wild(table)])
	await run_battle(enemies, true, [], {"cave": ow.map.get("cave", false), "bg": ow.map.get("battle_bg", "grass")})


static func legend(ow: Node, w: Node) -> void:
	var n: Dictionary = w.data
	if n.has("require") and not Game.check(n["require"]):
		await ui().say("Une présence immense... Mais tu ne te sens pas encore prêt.")
		return
	await ui().say(n["text"])
	if not await ui().confirm("Approcher du Pokémon ?"):
		return
	await run_script(ow, w, [["legend", n["species"], n["level"], n["flag"]]])


static func pick_item(ow: Node, w: Node) -> void:
	var n: Dictionary = w.data
	Game.add_item(n["item"], n["count"])
	Game.set_flag(n["flag"])
	ow.remove_walker(w)
	Audio.jingle("item")
	var name := Data.item_name(n["item"])
	await ui().say("%s trouve %s%s !" % [Game.player_name, name, "" if n["count"] == 1 else " x%d" % n["count"]])


static func shop(stock: Array) -> void:
	await ui().say("Bienvenue ! Que puis-je faire pour vous ?")
	var s := ShopScreen.new()
	s.stock = stock
	await ui().open(s)
	await ui().say("Merci ! Revenez quand vous voulez !")


static func outfit_shop(stock: Array) -> void:
	await ui().say("Bienvenue au rayon mode ! Chaque tenue coûte %d ₽." % Game.OUTFIT_PRICE)
	while true:
		var opts := []
		var ids := []
		for o in stock:
			if not Game.outfits.has(o):
				opts.append(Game.OUTFITS[o]["name"])
				ids.append(o)
		if ids.is_empty():
			await ui().say("Vous avez déjà toutes nos tenues ! Quel style !")
			return
		opts.append("PARTIR")
		var i: int = await ui().ask("Quelle tenue vous ferait plaisir ? (Argent : %d ₽)" % Game.money, opts)
		if i < 0 or i >= ids.size():
			return
		if Game.money < Game.OUTFIT_PRICE:
			await ui().say("Vous n'avez pas assez d'argent...")
			continue
		Game.money -= Game.OUTFIT_PRICE
		Game.give_outfit(ids[i])
		Audio.jingle("item")
		await ui().say("Merci ! La tenue « %s » est à vous. Changez-la depuis le menu TENUES." % opts[i])


static func daycare() -> void:
	if Game.daycare_egg:
		await ui().say("Mamie Rosa : Ah, te voilà ! Pendant que tu marchais, tes Pokémon ont trouvé un Œuf !")
		if Game.party.size() >= Game.PARTY_MAX:
			await ui().say("Mamie Rosa : Mais ton équipe est pleine. Reviens avec une place libre.")
			return
		Game.daycare_egg = false
		Game.give_pokemon(Game.daycare_make_egg())
		Audio.jingle("item")
		Game.set_quest("pension", 2)
		await ui().say("%s reçoit l'Œuf ! Marche beaucoup pour qu'il éclose." % Game.player_name)
		return
	var opts := ["DÉPOSER", "RETIRER", "RIEN"]
	var i: int = await ui().ask("Mamie Rosa : Bienvenue à la Pension ! Je garde %d Pokémon sur 2. Que veux-tu faire ?" % Game.daycare.size(), opts)
	if i == 0:
		if Game.daycare.size() >= 2:
			await ui().say("Mamie Rosa : J'ai déjà deux Pokémon, mon petit.")
			return
		var ps := PartyScreen.new()
		ps.mode = "select"
		ps.title = "Quel Pokémon confier ?"
		var idx = await ui().open(ps)
		if idx == null or idx < 0:
			return
		var mon: Pokemon = Game.party[idx]
		if mon.is_egg or Game.alive_count() <= 1 and mon.can_battle():
			await ui().say("Mamie Rosa : Je ne peux pas prendre celui-là.")
			return
		Game.party.remove_at(idx)
		Game.daycare.append(mon)
		Game.set_quest("pension", 1)
		await ui().say("Mamie Rosa : Je m'occupe bien de %s ! Il gagnera de l'expérience pendant que tu marches." % mon.name())
		if Game.daycare.size() == 2:
			var c := Game.daycare_compat()
			await ui().say(["Mamie Rosa : Ils s'entendent très bien !", "Mamie Rosa : Ils s'apprécient.", "Mamie Rosa : Ils ne s'intéressent pas l'un à l'autre..."][0 if c >= 50 else 1 if c > 0 else 2])
	elif i == 1:
		if Game.daycare.is_empty():
			await ui().say("Mamie Rosa : Je ne garde aucun de tes Pokémon.")
			return
		var names := Game.daycare.map(func(m): return "%s N.%d" % [m.name(), m.level])
		var j: int = await ui().ask("Mamie Rosa : Lequel veux-tu récupérer ?", names)
		if j < 0:
			return
		if Game.party.size() >= Game.PARTY_MAX:
			await ui().say("Mamie Rosa : Ton équipe est pleine !")
			return
		var mon2: Pokemon = Game.daycare[j]
		Game.daycare.remove_at(j)
		Game.party.append(mon2)
		await ui().say("Mamie Rosa : Voici %s ! Il est au niveau %d maintenant." % [mon2.name(), mon2.level])


static func fossil() -> void:
	for item in FOSSILS:
		if Game.item_count(item) > 0:
			await ui().say(["Chercheur : Oh ! C'est un %s ! Je peux ressusciter le Pokémon qui est dedans !" % Data.item_name(item), "Patiente un instant..."])
			Game.remove_item(item)
			await ui().flash(3)
			var m := Pokemon.create(FOSSILS[item], 25)
			Game.give_pokemon(m)
			Audio.jingle("item")
			Game.set_quest("fossile", 2)
			await ui().say("Le fossile est devenu %s !" % m.name())
			return
	await ui().say("Chercheur : J'étudie les fossiles. Si tu en trouves un, apporte-le-moi : je ressusciterai le Pokémon qu'il contient !")


static func hall_of_fame(ow: Node) -> void:
	Audio.play_music("hall")
	var s := HallOfFameScreen.new()
	await ui().open(s)
	Game.heal_party()
	Game.save_game()
	await ui().say(["Félicitations, Maître {player} !", "La Grotte Azurée, au nord-ouest d'Azuria, t'est maintenant ouverte...", "Et le Prof. Chen a peut-être une surprise si tu complètes le Pokédex !"])
	await ow.warp_to("maison", Vector2i(4, 3), "down")


# ---------------------------------------------------------------------------
# Combat complet : solo ou coop, captures, évolutions, défaite
# ---------------------------------------------------------------------------

## enemy_parties : une équipe par adversaire. trainers : infos de chaque dresseur adverse (vide si sauvage).
static func run_battle(enemy_parties: Array, wild: bool, trainers: Array, opts := {}) -> String:
	for team in enemy_parties:
		for m in team:
			Game.see(m.species)
	if Game.alive_count() == 0:
		return "lose"
	# En coop, un camarade dresseur rejoint l'adversaire.
	if Net.coop_ready() and not opts.get("no_coop", false) and not opts.get("double", false):
		if not wild and trainers.size() == 1 and enemy_parties.size() == 1:
			var partner := partner_trainer(trainers[0] if trainers[0].has("team") else {"name": trainers[0].get("name", ""), "class": trainers[0].get("class", "Dresseur"), "team": enemy_parties[0].map(func(m): return [m.species, m.level]), "kind": trainers[0].get("kind", "")})
			trainers = trainers + [partner]
			enemy_parties = enemy_parties + [make_team(partner["team"], partner)]
		return await Net.host_coop_battle(enemy_parties, wild, trainers, opts)
	Audio.play_music(_battle_music(wild, trainers, opts))
	await ui().battle_intro()
	var screen := BattleScreen.new()
	var bopts := {"double": opts.get("double", false), "wild_double": wild and enemy_parties.size() > 1, "boss": opts.get("boss", false),
		"player_names": [Game.player_name]}
	screen.battle = Battle.new([Game.party], enemy_parties, wild, trainers, bopts)
	screen.battle.player_name = Game.player_name
	screen.battle.cave = opts.get("cave", false)
	screen.battle.caught_species = Game.caught.keys()
	screen.battle.exp_share = [Game.flag("exp_share_on"), false]
	screen.bg = opts.get("bg", "cave" if opts.get("cave", false) else "grass")
	var result: String = await ui().open(screen)
	return await after_battle(screen.battle, result, wild, trainers, opts, 0)


static func _battle_music(wild: bool, trainers: Array, opts: Dictionary) -> String:
	if opts.get("legend", false) or opts.get("boss", false):
		return "battle_legend"
	if wild:
		return "battle_wild"
	var t: Dictionary = trainers[0] if trainers.size() > 0 else {}
	if t.get("music", "") != "":
		return t["music"]
	return "battle_trainer"


## Suite du combat pour le joueur local (owner = son indice dans le camp).
static func after_battle(battle: Battle, result: String, wild: bool, trainers: Array, opts: Dictionary, owner: int) -> String:
	if result == "win" and not wild:
		var total := 0
		for t in trainers:
			total += int(t.get("money", 0))
		Game.money += total
		Audio.play_music("victory_trainer")
	elif result in ["win", "caught"] and wild:
		Audio.play_music("victory_wild")
	Game.money += battle.pay_day
	if result == "caught" and battle.caught != null and battle.caught_owner == owner:
		var mon := battle.caught
		var new := not Game.caught.has(mon.species)
		var where := Game.give_pokemon(mon)
		Audio.jingle("catch")
		if new:
			await ui().say("Les données de %s sont ajoutées au Pokédex." % mon.data()["name"])
		if await ui().confirm("Donner un surnom à %s ?" % mon.name()):
			var nick: String = await ui().enter_name("Surnom :", mon.data()["name"], 10)
			mon.nickname = "" if nick == mon.data()["name"] else nick
		if where == "pc":
			await ui().say("%s est envoyé dans le PC." % mon.name())
	if result == "win":
		for m in Game.party:
			if not m.is_egg and Data.ability_ident(m.ability) == "pickup" and randi() % 10 == 0:
				var found: String = ["potion", "super-potion", "great-ball", "ultra-ball", "rare-candy", "full-heal", "ether", "revive"][randi() % 8]
				Game.add_item(found)
				await ui().say("%s a ramassé %s !" % [m.name(), Data.item_name(found)])
	Audio.play_music(Game.world.map.get("music", "route") if Game.world != null and not Game.world.map.is_empty() else "route")
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
	# Évolutions après le combat (Pokémon du joueur local uniquement).
	for i in battle.leveled:
		if battle.sides[0].owners[i] != owner:
			continue
		var mon2: Pokemon = battle.sides[0].party[i]
		var to := mon2.level_evolution()
		if to != 0 and not mon2.is_fainted():
			await evolve(mon2, to)
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


static func hatch(egg: Pokemon) -> void:
	var h := HatchScreen.new()
	h.mon = egg
	await ui().open(h)
	egg.is_egg = false
	egg.egg_steps = 0
	egg.recalc_stats()
	egg.hp = egg.max_hp()
	egg.ot = Game.player_name
	Game.catch_register(egg.species)
	if await ui().confirm("Donner un surnom à %s ?" % egg.data()["name"]):
		var nick: String = await ui().enter_name("Surnom :", egg.data()["name"], 10)
		egg.nickname = "" if nick == egg.data()["name"] else nick
	Game.set_quest("pension", 2)


static func learn_move(mon: Pokemon, mid: int) -> bool:
	var mname := Data.move_name(mid)
	if mon.knows(mid):
		await ui().say("%s connaît déjà %s." % [mon.name(), mname])
		return false
	if mon.moves.size() < 4:
		mon.moves.append(Pokemon.make_move(mid))
		Audio.jingle("levelup")
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
# Multijoueur : discussion et invitations
# ---------------------------------------------------------------------------

static func chat() -> void:
	var text: String = await ui().enter_name("Message pour les autres joueurs :", "", 60)
	if text.strip_edges() != "":
		Net.send_chat(text)


static func talk_player(pid: int) -> void:
	var name: String = Net.players.get(pid, {}).get("name", "?")
	var opts := ["INVITER DANS LE GROUPE" if not Net.in_group() else "QUITTER LE GROUPE", "ANNULER"]
	var i: int = await ui().ask("C'est %s !" % name, opts)
	if i == 0:
		if Net.in_group():
			Net.leave_group()
			await ui().say("Tu as quitté le groupe.")
		else:
			Net.invite(pid)
			await ui().say("Invitation envoyée à %s !" % name)


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
	if Data.items.get(item, {}).get("key", false):
		match item:
			"bicycle":
				if ow.map.get("outdoor", false):
					Game.on_bike = not Game.on_bike
					await ui().say("%s %s la Bicyclette." % [Game.player_name, "enfourche" if Game.on_bike else "descend de"])
				else:
					await ui().say("Ce n'est pas le moment de faire du vélo !")
			"town-map":
				await ui().open(WorldMapScreen.new())
			"exp-share":
				Game.set_flag("exp_share_on", not Game.flag("exp_share_on"))
				await ui().say("Le Multi Exp est %s." % ("activé" if Game.flag("exp_share_on") else "désactivé"))
			"poke-flute":
				await ui().say("%s joue de la Poké Flûte. Quelle jolie mélodie !" % Game.player_name)
				for m in Game.party:
					if m.status == "slp":
						m.status = ""
			_:
				await ui().say(Data.items[item].get("desc", "C'est un objet important."))
		return
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
		if ow.map.get("cave", false) or not ow.map.get("outdoor", true):
			Game.remove_item(item)
			await ui().say("%s utilise la Corde Sortie !" % Game.player_name)
			var hp: Dictionary = Game.heal_point
			await ow.warp_to(hp["map"], Vector2i(hp["x"], hp["y"]), "down")
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
	if mon.is_egg:
		await ui().say("Ça n'aura aucun effet sur un Œuf.")
		return
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
		Audio.jingle("levelup")
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
	Audio.sfx("heal")
	await ui().say(text.split("\n"))
