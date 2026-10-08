class_name Pokemon
extends RefCounted
## Un Pokémon possédé ou sauvage : statistiques, IV/EV, nature, talent, capacités, expérience.

const SHINY_ODDS := 4096
const HP_TYPES := ["fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
	"fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark"]

var species := 1
## Forme (identifiant Pokémon 10xxx : forme régionale...), 0 = forme normale.
var form := 0
var nickname := ""
var level := 1
var exp := 0
var ivs: Array = [0, 0, 0, 0, 0, 0]
var evs: Array = [0, 0, 0, 0, 0, 0]
var nature := 0
var ability := 0
var gender := 2  # 0 mâle, 1 femelle, 2 aucun
var shiny := false
var moves: Array = []  # [{id, pp, max, ups}]
var hp := 1
var status := ""  # "", par, slp, psn, tox, brn, frz
var sleep_turns := 0
var ball := "poke-ball"
var happiness := 70
var ot := ""
var stats: Array = [1, 1, 1, 1, 1, 1]
var is_egg := false
var egg_steps := 0
## Pokémon boss (donjons) : PV multipliés, ne se sauvegarde pas.
var boss := false
## Objet tenu (identifiant d'objet), "" si rien.
var held_item := ""
## Pokérus : 0 jamais eu, 1 à 4 = contaminé (jours restants), -1 = guéri (double toujours les EV).
var pokerus := 0
## Compteurs pour les évolutions spéciales (coups critiques, capacité utilisée, dégâts subis...).
var counters := {}


## sid : numéro d'espèce, ou identifiant d'une forme (10xxx). hidden : talent caché.
static func create(sid: int, lvl: int, hidden := false) -> Pokemon:
	var p := Pokemon.new()
	var d: Dictionary = Data.pokemon[sid]
	p.species = d.get("species", sid)
	p.form = sid if sid != p.species else 0
	p.level = lvl
	p.exp = Data.exp_at(d["growth"], lvl)
	for i in 6:
		p.ivs[i] = randi_range(0, 31)
	p.nature = randi() % 25
	var ab: Array = d["abilities"]
	p.ability = ab[randi() % ab.size()] if ab.size() > 0 else 0
	if hidden and d.get("ha", 0) != 0:
		p.ability = d["ha"]
	if d["gender"] < 0:
		p.gender = 2
	else:
		p.gender = 1 if randi() % 8 < d["gender"] else 0
	# Charme Chroma : 3 fois plus de chances (1/1365), comme dans les jeux.
	p.shiny = randi() % (SHINY_ODDS / 3 if Game.item_count("shiny-charm") > 0 else SHINY_ODDS) == 0
	p.happiness = d["happiness"]
	p.recalc_stats()
	p.hp = p.stats[0]
	p.reset_moves()
	return p


func data() -> Dictionary:
	return Data.pokemon[form if form != 0 else species]


## Identifiant à utiliser pour les sprites et les cris (forme incluse).
func sprite_id() -> int:
	return form if form != 0 else species


## « Forme d'Alola »... ou "" pour la forme normale.
func form_label() -> String:
	return data().get("form_name", "") if form != 0 else ""


func has_hidden_ability() -> bool:
	return ability != 0 and ability == data().get("ha", 0)


func name() -> String:
	if is_egg:
		return "ŒUF"
	return nickname if nickname != "" else data()["name"]


## Peut combattre (ni K.O., ni œuf).
func can_battle() -> bool:
	return not is_egg and hp > 0


static func base_species(sid: int) -> int:
	var s: int = Data.pokemon[sid].get("species", sid) if Data.pokemon.has(sid) else sid
	while Data.pokemon[s]["evolves_from"] != 0 and Data.pokemon.has(Data.pokemon[s]["evolves_from"]):
		s = Data.pokemon[s]["evolves_from"]
	return s


static func create_egg(sid: int) -> Pokemon:
	var p := Pokemon.create(base_species(sid), 1)
	p.is_egg = true
	p.egg_steps = Data.pokemon[p.species]["hatch"] * 256
	p.happiness = 120
	return p


## Message du résumé, comme dans les jeux (pas de compteur visible).
func egg_hint() -> String:
	var cycles := egg_steps / 256
	if cycles > 10:
		return "Cet Œuf va sûrement mettre du temps à éclore."
	if cycles > 5:
		return "Qu'est-ce qui va en sortir ? Ça va prendre du temps."
	if cycles > 1:
		return "Il bouge de temps en temps. Il devrait bientôt éclore."
	return "Il fait du bruit ! Il va éclore très bientôt !"


func types() -> Array:
	return data()["types"]


func is_fainted() -> bool:
	return hp <= 0 or is_egg


func max_hp() -> int:
	return stats[0]


func recalc_stats() -> void:
	var base: Array = data()["base"]
	var nat: Dictionary = Data.natures[nature]
	var old_max: int = stats[0]
	for i in 6:
		var core := int((2 * base[i] + ivs[i] + int(evs[i] / 4)) * level / 100)
		if i == 0:
			stats[0] = 1 if species == 0 else core + level + 10
		else:
			var v := float(core + 5)
			if nat["up"] == i:
				v *= 1.1
			elif nat["down"] == i:
				v *= 0.9
			stats[i] = int(v)
	if old_max > 1 and hp > 0:
		hp = clampi(hp + stats[0] - old_max, 1, stats[0])


func reset_moves() -> void:
	moves.clear()
	var ids := []
	for e in data()["learn"]:
		if e[0] <= level and not ids.has(e[1]):
			ids.append(e[1])
	for id in ids.slice(maxi(0, ids.size() - 4)):
		moves.append(make_move(id))


static func make_move(id: int) -> Dictionary:
	var pp: int = Data.moves[id]["pp"]
	return {"id": id, "pp": pp, "max": pp, "ups": 0}


func knows(id: int) -> bool:
	for m in moves:
		if m["id"] == id:
			return true
	return false


## Capacités apprises en atteignant exactement ce niveau.
func moves_at(lvl: int) -> Array:
	var out := []
	for e in data()["learn"]:
		if e[0] == lvl and not knows(e[1]) and not out.has(e[1]):
			out.append(e[1])
	return out


func can_learn_tm(move_id: int) -> bool:
	return data()["tm"].has(move_id)


func exp_to_next() -> int:
	if level >= 100:
		return 0
	return Data.exp_at(data()["growth"], level + 1) - exp


func exp_progress() -> float:
	if level >= 100:
		return 1.0
	var lo := Data.exp_at(data()["growth"], level)
	var hi := Data.exp_at(data()["growth"], level + 1)
	return clampf(float(exp - lo) / float(maxi(1, hi - lo)), 0.0, 1.0)


## Ajoute de l'expérience et renvoie la liste des niveaux atteints.
func add_exp(amount: int) -> Array:
	var reached := []
	exp = mini(exp + amount, Data.exp_at(data()["growth"], 100))
	while level < 100 and exp >= Data.exp_at(data()["growth"], level + 1):
		level += 1
		recalc_stats()
		happiness = mini(255, happiness + (5 if held_item == "soothe-bell" else 3))
		reached.append(level)
	return reached


func add_evs(yield_evs: Array) -> void:
	for i in 6:
		var total := 0
		for v in evs:
			total += v
		var add := mini(yield_evs[i], 510 - total)
		evs[i] = mini(252, evs[i] + maxi(0, add))
	recalc_stats()


# ---------------------------------------------------------------------------
# Évolutions : toutes les conditions des jeux (niveau, objet, objet tenu, heure, bonheur,
# capacité connue, équipe, région, échange, conditions spéciales).
# ---------------------------------------------------------------------------

## Moment de la journée selon l'horloge de l'ordinateur, comme dans les jeux.
static func time_of_day() -> String:
	var h: int = Time.get_time_dict_from_system()["hour"]
	if h == 17:
		return "dusk"
	return "day" if h >= 6 and h < 18 else "night"


## Vérifie les conditions communes (objet tenu, heure, sexe, bonheur, capacité, équipe...).
func _evo_ok(e: Dictionary, ctx: Dictionary) -> bool:
	if e.has("held") and held_item != e["held"]:
		return false
	if e.has("time"):
		var now: String = ctx.get("time", time_of_day())
		if e["time"] == "day" and now == "night" or e["time"] == "night" and now != "night" or e["time"] == "dusk" and now != "dusk":
			return false
	if e.has("gender") and gender != e["gender"]:
		return false
	if e.has("happiness") and happiness < e["happiness"]:
		return false
	if e.has("move") and not knows(e["move"]):
		return false
	if e.has("move_type"):
		var ok := false
		for m in moves:
			if Data.moves[m["id"]]["type"] == e["move_type"]:
				ok = true
		if not ok:
			return false
	var party: Array = ctx.get("party", [])
	if e.has("party") and not party.any(func(o): return o != self and o.species == e["party"] and not o.is_egg):
		return false
	if e.has("party_type") and not party.any(func(o): return o != self and not o.is_egg and o.types().has(e["party_type"])):
		return false
	if e.has("stats"):
		var d := signi(stats[1] - stats[2])
		if d != e["stats"]:
			return false
	if e.has("region") and ctx.get("region", "") != e["region"]:
		return false
	if e.has("natures") and not e["natures"].has(Data.natures[nature].get("ident", "")):
		return false
	if e.has("steps") and int(counters.get("steps", 0)) < e["steps"] and not ctx.get("ignore_steps", false):
		return false
	if e.get("group", false) and not ctx.get("group", false):
		return false
	if e.has("chance") and stable_roll() >= e["chance"]:
		return false
	if e.has("terrain") and ctx.get("terrain", "grass") != e["terrain"]:
		return false
	return true


## Valeur fixe de 0 à 99 propre à ce Pokémon (comme sa « personnalité » dans les jeux) :
## décide par exemple si Chenipotte devient Armulys ou Blindalys.
func stable_roll() -> int:
	var h := nature * 7 + gender * 13
	for i in 6:
		h = h * 31 + ivs[i]
	return absi(h) % 100


## Cible d'évolution (identifiant Pokémon, forme incluse) ou 0.
## trigger : "level" (montée de niveau), "item", "trade", ou une condition spéciale.
func evolution_target(trigger: String, item := "", ctx := {}) -> int:
	if is_egg or held_item == "everstone" and trigger != "item":
		return 0
	var best := 0
	var best_score := -1
	var cumul := 0
	for e in data()["evos"]:
		var ok := false
		match trigger:
			"level":
				ok = not e.has("item") and not e.get("trade", false) and (not e.has("special") or e["special"] in ["shed", "spin"]) \
					and (not e.has("level") or level >= e["level"]) and (e.has("level") or e.size() > 1)
			"item":
				ok = e.get("item", "") == item or item == "linking-cord" and e.get("trade", false)
			"trade":
				ok = e.get("trade", false) and (not e.has("trade_with") or ctx.get("trade_with", 0) == e["trade_with"])
			_:
				ok = e.get("special", "") == trigger
		if trigger == "level" and e.get("special", "") == "shed":
			ok = false
		# Évolutions au hasard (Chenipotte) : la « personnalité » choisit une seule branche.
		if e.has("chance"):
			var lo := cumul
			cumul += int(e["chance"])
			if not ok or stable_roll() < lo or stable_roll() >= cumul:
				continue
			var e2: Dictionary = e.duplicate()
			e2.erase("chance")
			if not _evo_ok(e2, ctx):
				continue
		elif not ok or not _evo_ok(e, ctx):
			continue
		var target: int = e.get("to_form", e["to"])
		# La règle la plus précise gagne (Nymphali avant Mentali, forme régionale avant la normale).
		var score: int = e.size() + (10 if e.has("region") else 0) + (5 if e.has("move_type") or e.has("move") else 0)
		if score > best_score:
			best = target
			best_score = score
	return best


func level_evolution(ctx := {}) -> int:
	return evolution_target("level", "", _ctx(ctx))


func item_evolution(item: String, ctx := {}) -> int:
	return evolution_target("item", item, _ctx(ctx))


func trade_evolution(partner_species := 0) -> int:
	return evolution_target("trade", "", _ctx({"trade_with": partner_species}))


## Contexte du jeu : région de la carte, équipe, heure.
func _ctx(ctx: Dictionary) -> Dictionary:
	var out := ctx.duplicate()
	if not out.has("party"):
		out["party"] = Game.party
	if not out.has("region"):
		out["region"] = Game.current_region()
	if not out.has("terrain"):
		var mp: Dictionary = Game.maps.get(Game.map_id, {})
		out["terrain"] = "cave" if mp.get("cave", false) else "grass" if mp.get("outdoor", true) else "building"
	if not out.has("group"):
		out["group"] = Net.in_group() if Net.has_method("in_group") else false
	return out


## Augmente un compteur d'évolution spéciale (coups critiques, capacité utilisée...).
func count(key: String, n := 1) -> void:
	counters[key] = int(counters.get(key, 0)) + n


## Évolutions spéciales déclenchées par un compteur (vérifiées après chaque combat).
func special_evolution() -> int:
	for e in data()["evos"]:
		var sp: String = e.get("special", "")
		var ok := false
		match sp:
			"three-critical-hits":
				ok = counters.get("crits_battle", 0) >= 3
			"take-damage":
				ok = counters.get("damage", 0) >= 49
			"recoil-damage":
				ok = counters.get("recoil", 0) >= 294
			"use-move", "agile-style-move", "strong-style-move":
				ok = counters.get("move_%d" % e.get("used_move", 0), 0) >= e.get("count", 20)
			"three-defeated-bisharp":
				ok = held_item == "leaders-crest" or counters.get("bisharp", 0) >= 3
		if ok and _evo_ok(e, _ctx({})):
			return e.get("to_form", e["to"])
	return 0


## Évolue vers `to` (numéro d'espèce ou identifiant de forme). Le talent garde son emplacement.
func evolve(to: int) -> void:
	var old_abilities: Array = data()["abilities"]
	var was_hidden := has_hidden_ability()
	var slot := maxi(0, old_abilities.find(ability))
	for e in data()["evos"]:
		if e.get("to_form", e["to"]) == to and e.has("held") and held_item == e["held"]:
			held_item = ""
	var d: Dictionary = Data.pokemon[to]
	species = d.get("species", to)
	form = to if to != species else 0
	var ab: Array = data()["abilities"]
	if was_hidden and data().get("ha", 0) != 0:
		ability = data()["ha"]
	elif ab.size() > 0:
		ability = ab[mini(slot, ab.size() - 1)]
	counters.clear()
	recalc_stats()


## Condition d'évolution en clair : « Raichu avec Pierre Foudre », « Mentali (bonheur, le jour) »...
static func evo_text(e: Dictionary) -> String:
	var to: int = e.get("to_form", e["to"])
	var name: String = Data.pokemon[to]["name"] if Data.pokemon.has(to) else "?"
	if Data.pokemon.has(to) and Data.pokemon[to].get("form_name", "") != "":
		name += " (" + Data.pokemon[to]["form_name"] + ")"
	var parts := []
	if e.has("level"):
		parts.append("au N.%d" % e["level"])
	if e.has("item"):
		parts.append("avec " + Data.item_name(e["item"]))
	if e.get("trade", false):
		parts.append("par échange (ou Fil de Liaison)")
	if e.has("held"):
		parts.append("en tenant " + Data.item_name(e["held"]))
	if e.has("happiness"):
		parts.append("très heureux")
	if e.has("time"):
		parts.append({"day": "le jour", "night": "la nuit", "dusk": "au crépuscule"}.get(e["time"], e["time"]))
	if e.has("gender"):
		parts.append("femelle" if e["gender"] == 1 else "mâle")
	if e.has("move"):
		parts.append("en connaissant " + Data.move_name(e["move"]))
	if e.has("move_type"):
		parts.append("avec une capacité " + Data.type_name(e["move_type"]))
	if e.has("party"):
		parts.append("avec %s dans l'équipe" % Data.pokemon[e["party"]]["name"])
	if e.has("party_type"):
		parts.append("avec un Pokémon %s dans l'équipe" % Data.type_name(e["party_type"]))
	if e.has("stats"):
		parts.append(["Attaque = Défense", "Attaque > Défense"][e["stats"]] if e["stats"] >= 0 else "Attaque < Défense")
	if e.has("region"):
		parts.append("dans la région " + e["region"].capitalize())
	match e.get("special", ""):
		"three-critical-hits":
			parts.append("après 3 coups critiques en un combat")
		"take-damage":
			parts.append("après avoir subi 49 PV de dégâts")
		"recoil-damage":
			parts.append("après 294 PV de contrecoup")
		"use-move", "agile-style-move", "strong-style-move":
			parts.append("après %d %s" % [e.get("count", 20), Data.move_name(e.get("used_move", 0))])
		"three-defeated-bisharp":
			parts.append("après avoir battu 3 Scalproie (ou avec l'Emblème du Général)")
		"gimmighoul-coins":
			parts.append("avec la Pièce de Mordudor")
		"spin":
			parts.append("avec une Sucrerie")
		"shed":
			parts.append("(apparaît en plus, s'il reste de la place)")
	if parts.is_empty():
		parts.append("en montant de niveau")
	return name + " " + ", ".join(parts)


## Capacités apprises au moment de l'évolution (niveau 0 dans les jeux récents).
func evolution_moves() -> Array:
	var out := []
	for e in data()["learn"]:
		if e[0] == 0 and not knows(e[1]) and not out.has(e[1]):
			out.append(e[1])
	return out


func heal_full() -> void:
	if boss:
		return
	hp = stats[0]
	status = ""
	sleep_turns = 0
	for m in moves:
		m["pp"] = m["max"]


func hidden_power_type() -> String:
	var t := 0
	var order := [0, 1, 2, 5, 3, 4]
	for i in 6:
		t += (ivs[order[i]] & 1) << i
	return HP_TYPES[int(t * 15 / 63)]


## Caractère (« Il aime la vitesse ») : il dépend du meilleur IV et de sa valeur modulo 5.
## En cas d'égalité : PV, Attaque, Défense, Vitesse, Atq. Spé., Déf. Spé.
func characteristic() -> String:
	var best := 0
	for i in [0, 1, 2, 5, 3, 4]:
		if ivs[i] > ivs[best]:
			best = i
	for c in Data.characteristics:
		if c["stat"] == best and c["mod"] == ivs[best] % 5:
			return c["text"]
	return ""


## Indice de nature à partir de son identifiant anglais (« adamant »), -1 si inconnu.
static func nature_index(ident: String) -> int:
	for i in Data.natures.size():
		if Data.natures[i].get("ident", "") == ident:
			return i
	return -1


func gender_symbol() -> String:
	return ["♂", "♀", ""][gender]


func to_dict() -> Dictionary:
	return {
		"species": species, "nickname": nickname, "level": level, "exp": exp, "ivs": ivs, "evs": evs,
		"nature": nature, "ability": ability, "gender": gender, "shiny": shiny, "moves": moves,
		"hp": hp, "status": status, "sleep": sleep_turns, "ball": ball, "happiness": happiness, "ot": ot,
		"egg": is_egg, "egg_steps": egg_steps, "boss": boss, "maxhp": stats[0],
		"form": form, "held": held_item, "pokerus": pokerus, "counters": counters,
	}


static func from_dict(d: Dictionary) -> Pokemon:
	var p := Pokemon.new()
	p.species = d["species"]
	p.form = d.get("form", 0)
	if not Data.pokemon.has(p.form):
		p.form = 0
	p.held_item = d.get("held", "")
	p.pokerus = d.get("pokerus", 0)
	p.counters = d.get("counters", {})
	p.nickname = d.get("nickname", "")
	p.level = d["level"]
	p.exp = d["exp"]
	p.ivs = d["ivs"]
	p.evs = d["evs"]
	p.nature = d["nature"]
	p.ability = d["ability"]
	if not Data.abilities.has(p.ability):
		p.ability = p.data()["abilities"][0] if p.data()["abilities"].size() > 0 else 0
	p.gender = d["gender"]
	p.shiny = d["shiny"]
	p.moves = d["moves"]
	p.status = d.get("status", "")
	p.sleep_turns = d.get("sleep", 0)
	p.ball = d.get("ball", "poke-ball")
	p.happiness = d.get("happiness", 70)
	p.ot = d.get("ot", "")
	p.is_egg = d.get("egg", false)
	p.egg_steps = d.get("egg_steps", 0)
	p.boss = d.get("boss", false)
	p.recalc_stats()
	if p.boss:
		p.stats[0] = d.get("maxhp", p.stats[0])
	p.hp = clampi(d["hp"], 0, p.stats[0])
	return p
