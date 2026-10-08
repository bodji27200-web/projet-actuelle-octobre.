class_name Campaign
extends RefCounted
## La grande suite après la Ligue de Kanto : la Team Rainbow Rocket recrute les chefs des équipes
## criminelles de toutes les régions. On voyage en bateau depuis Carmin-sur-Mer, région par région ;
## chaque région a son repaire à démanteler, son Maître à battre (qui donne un Fragment Arc-en-Ciel),
## ses légendaires cachés dans des lieux dangereux. Huit fragments ouvrent le Château Rocket, puis l'Abîme.

## Ordre de la campagne : chaque région s'ouvre quand la précédente est terminée.
const ORDER := ["sevii", "johto", "hoenn", "sinnoh", "unys", "kalos", "alola", "galar", "paldea"]
const NAMES := {"kanto": "Kanto", "sevii": "Îles Sevii", "johto": "Johto", "hoenn": "Hoenn", "sinnoh": "Sinnoh",
	"unys": "Unys", "kalos": "Kalos", "alola": "Alola", "galar": "Galar", "paldea": "Paldea", "rainbow": "Château Rocket"}


static func ui() -> Node:
	return Game.ui


## Une région est-elle accessible en bateau ?
static func unlocked(realm: String) -> bool:
	match realm:
		"kanto":
			return true
		"sevii":
			return Game.flag("champion")
		"rainbow":
			return ORDER.slice(1).all(func(r): return Game.flag("champion_" + r))
	var i := ORDER.find(realm)
	if i <= 0:
		return false
	var prev: String = ORDER[i - 1]
	return Game.flag("chap_sevii_done") if prev == "sevii" else Game.flag("champion_" + prev)


## Port d'arrivée d'une région : la carte marquée « port » dans les données du monde.
static func port_of(realm: String) -> Dictionary:
	for mid in Game.maps:
		var m: Dictionary = Game.maps[mid]
		if m.has("port") and m.get("realm", "kanto") == realm:
			return {"map": mid, "x": m["port"][0], "y": m["port"][1]}
	return {}


static func special(ow: Node, w: Node, name: String, args: Array) -> bool:
	match name:
		"travel":
			await travel(ow)
		"starter_pick":
			return await starter_pick(args[0], int(args[1]), str(args[2]))
		"starter_rest":
			await starter_rest(args[0], int(args[1]), str(args[2]))
		"rematch":
			return await rematch(ow, int(args[0]))
		"chapter_done":
			await chapter_done(str(args[0]))
		"fragment_count":
			await ui().say("Fragments Arc-en-Ciel : %d / 8." % Game.item_count("fragment-arc"))
		"ev_info":
			await ev_info()
		"finale":
			await finale()
		"abyss_done":
			await abyss_done()
		"goto":
			var m: Dictionary = Game.maps.get(str(args[0]), {})
			if not m.is_empty():
				var a: Array = m.get("arrive", m.get("port", [m["w"] / 2, m["h"] / 2]))
				await ui().flash(2)
				await ow.warp_to(str(args[0]), Vector2i(a[0], a[1]), "down")
	return true


# ---------------------------------------------------------------------------
# Voyages
# ---------------------------------------------------------------------------

static func travel(ow: Node) -> void:
	if Game.item_count("passe-croisiere") == 0:
		await ui().say("Capitaine : Il te faut un Passe Croisière pour embarquer. Le Prof. Chen en donne aux Maîtres de la Ligue !")
		return
	var here := WorldMapScreen.realm_of(ow.map_id)
	var dests := []
	for r in ["kanto"] + ORDER + ["rainbow"]:
		if r != here and unlocked(r) and not port_of(r).is_empty():
			dests.append(r)
	if dests.is_empty():
		await ui().say("Capitaine : Aucune autre destination pour l'instant.")
		return
	var labels: Array = dests.map(func(r): return NAMES.get(r, r).to_upper())
	labels.append("RESTER ICI")
	var i: int = await ui().ask("Capitaine : Où veux-tu aller ?", labels)
	if i < 0 or i >= dests.size():
		return
	var p := port_of(dests[i])
	Audio.sfx("door")
	await ui().say("Le bateau largue les amarres... Cap sur %s !" % NAMES.get(dests[i], dests[i]))
	await ow.warp_to(p["map"], Vector2i(p["x"], p["y"]), "down")
	if not Game.flag("visited_" + dests[i]):
		Game.set_flag("visited_" + dests[i])
		Game.set_quest("chap_" + dests[i], maxi(1, int(Game.quests.get("chap_" + dests[i], 0))))
		await ui().say("Bienvenue à %s ! Consulte ton Journal pour savoir quoi faire." % NAMES.get(dests[i], dests[i]))


# ---------------------------------------------------------------------------
# Starters régionaux
# ---------------------------------------------------------------------------

static func starter_pick(species: Array, lvl: int, flag: String) -> bool:
	if Game.flag(flag):
		return true
	while true:
		var pick = await ListPick.pick("CHOISIS TON POKéMON", species.map(func(s): return Data.pokemon[int(s)]["name"]),
			species.map(func(s): return "/".join(Data.pokemon[int(s)]["types"].map(func(t): return Data.type_name(t)))),
			species.map(func(s): return Data.pokemon[int(s)].get("dex", "")), species.map(func(s): return ["icon", int(s)]))
		if not pick is int or pick < 0:
			return false
		if await ui().confirm("Tu choisis %s ?" % Data.pokemon[int(species[pick])]["name"]):
			var m := Pokemon.create(int(species[pick]), lvl)
			var where := Game.give_pokemon(m)
			Game.set_flag(flag)
			Game.set_flag(flag + "_" + str(species[pick]))
			Audio.jingle("catch")
			await ui().say("%s reçoit %s !%s" % [Game.player_name, m.name(), " Il est envoyé au PC." if where == "pc" else ""])
			return true
	return false


## Après le Maître de la région : le professeur confie les deux autres starters.
static func starter_rest(species: Array, lvl: int, flag: String) -> void:
	if Game.flag(flag + "_rest"):
		return
	for s in species:
		if Game.flag(flag + "_" + str(s)):
			continue
		var m := Pokemon.create(int(s), lvl)
		Game.give_pokemon(m)
		await ui().say("%s reçoit %s !" % [Game.player_name, m.name()])
	Game.set_flag(flag + "_rest")
	Audio.jingle("catch")


# ---------------------------------------------------------------------------
# Revanches des Champions de Kanto (après la Ligue)
# ---------------------------------------------------------------------------

const LEADERS := [["Pierre", "rock"], ["Ondine", "water"], ["Major Bob", "electric"], ["Érika", "grass"],
	["Koga", "poison"], ["Morgane", "psychic"], ["Auguste", "fire"], ["Giovanni", "ground"]]


static func rematch(ow: Node, n: int) -> bool:
	if not Game.flag("champion"):
		await ui().say("Le Champion accepte les revanches... mais seulement contre les Maîtres de la Ligue !")
		return false
	var info: Array = LEADERS[n - 1]
	if not await ui().confirm("%s : Une revanche, Maître ? Mes Pokémon sont au niveau 75 et entraînés à la perfection. Prêt ?" % info[0]):
		return false
	var base: Dictionary = Game.trainers.get("leader_%d" % n, {})
	var pool: Array = Game.type_pool.get(info[1], [])
	var team := []
	var used := {}
	for e in base.get("team", []):
		var sid := Events.evolve_to_level(int(e[0]), 80)
		if not used.has(sid):
			used[sid] = true
			team.append([sid, 75 + team.size(), {"exact": true}])
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 7919 + int(Game.stats.get("leaders", 0))
	while team.size() < 6 and pool.size() > 0:
		var sid2 := Events.evolve_to_level(int(pool[rng.randi() % pool.size()]), 80)
		if not used.has(sid2) and not Data.pokemon[sid2].get("legendary", false):
			used[sid2] = true
			team.append([sid2, 75 + team.size(), {"exact": true}])
	var t := {"id": "rematch_%d" % n, "name": "Champion %s" % info[0], "class": "Champion", "team": team, "kind": "leader",
		"build": "auto", "ai": 3, "money": 20000, "defeat": "Quelle force... Reviens quand tu veux !", "look": base.get("look", "ace")}
	var r: String = await Events.run_battle([Events.make_team(team, t)], false, [t], {})
	return r == "win"


# ---------------------------------------------------------------------------
# Fin de chapitre : Maître de la région battu
# ---------------------------------------------------------------------------

static func chapter_done(realm: String) -> void:
	if Game.flag("champion_" + realm):
		return
	Game.set_flag("champion_" + realm)
	Game.add_item("fragment-arc")
	Audio.jingle("badge")
	await ui().say(["Tu obtiens un Fragment Arc-en-Ciel ! (%d / 8)" % Game.item_count("fragment-arc"),
		"Il a été repris à la Team Rainbow Rocket de %s." % NAMES.get(realm, realm)])
	var i := ORDER.find(realm)
	if i >= 0 and i + 1 < ORDER.size():
		await ui().say("Une nouvelle destination est disponible au port : %s !" % NAMES[ORDER[i + 1]])
	elif unlocked("rainbow"):
		await ui().say(["Les huit fragments brillent ensemble...", "Ils indiquent le repaire de Giovanni : le Château Rocket ! Le capitaine peut t'y emmener."])
	Game.set_quest("chap_" + realm, 9)
	await Profile.announce()


## Giovanni vaincu au Château Rocket : fin de la campagne, l'Abîme s'ouvre.
static func finale() -> void:
	if Game.flag("rainbow_done"):
		return
	Game.set_flag("rainbow_done")
	Game.set_quest("chap_rainbow", 2)
	Audio.jingle("badge")
	await ui().say(["La Team Rainbow Rocket est dissoute ! Les neuf régions sont libres.",
		"Un grondement monte des profondeurs... L'entrée de l'Abîme, sur le parvis du Château, n'est plus scellée."])
	await Profile.announce()


## Gardien de l'Abîme vaincu : Arceus peut être approché.
static func abyss_done() -> void:
	if Game.flag("abyss_done"):
		return
	Game.set_flag("abyss_done")
	Game.set_quest("chap_rainbow", 3)
	Audio.jingle("badge")
	await ui().say("Le Gardien de l'Abîme s'efface dans l'obscurité...")
	await Profile.announce()


# ---------------------------------------------------------------------------
# Rencontres rares (légendaires errants, Pokémon cachés)
# ---------------------------------------------------------------------------

## map["rare"] : [[espèce, niveau, 1 chance sur N, drapeau une fois capturé/vaincu, condition]].
static func rare_check(ow: Node) -> bool:
	var lst: Array = ow.map.get("rare", [])
	for r in lst:
		if Game.flag(str(r[3])) or (r.size() > 4 and not Game.check(r[4])):
			continue
		if randi() % maxi(1, int(r[2])) != 0:
			continue
		var m := Pokemon.create(int(r[0]), int(r[1]))
		await ui().say("Le sol tremble... Un Pokémon extrêmement rare surgit !")
		Audio.cry(m.sprite_id())
		var res: String = await Events.run_battle([[m]], true, [], {"legend": true, "cave": ow.map.get("cave", false)})
		if res == "caught":
			Game.set_flag(str(r[3]))
		elif res == "win":
			await ui().say("%s s'est enfui... Il reviendra peut-être un jour." % m.name())
		return true
	return false


static func ev_info() -> void:
	await ui().say(["Coach : Bienvenue au Centre d'Entraînement EV !", "Chaque salle abrite des Pokémon qui rapportent un seul type d'EV : PV, Attaque, Défense, Attaque Spéciale, Défense Spéciale ou Vitesse.",
		"Avec un Bracelet Macho, un objet Pouvoir ou le Pokérus, tu gagnes encore plus d'EV par combat !",
		"Maximum : 252 dans une statistique, 510 au total. Les Baies réduisent les EV si tu te trompes."])
