class_name ItemUse
extends RefCounted
## Effets des objets utilisables sur un Pokémon (dans le Sac ou en combat).

const BALLS := ["poke-ball", "great-ball", "ultra-ball", "master-ball", "premier-ball", "net-ball",
	"nest-ball", "repeat-ball", "timer-ball", "luxury-ball", "dusk-ball", "heal-ball", "quick-ball",
	"level-ball", "moon-ball", "heavy-ball", "fast-ball", "friend-ball", "love-ball", "dive-ball"]
const HEAL := {"potion": 20, "super-potion": 60, "hyper-potion": 120, "max-potion": 9999,
	"full-restore": 9999, "fresh-water": 30, "soda-pop": 50, "lemonade": 70, "moomoo-milk": 100}
const CURE := {"antidote": ["psn", "tox"], "paralyze-heal": ["par"], "awakening": ["slp"],
	"burn-heal": ["brn"], "ice-heal": ["frz"], "full-heal": ["psn", "tox", "par", "slp", "brn", "frz"],
	"full-restore": ["psn", "tox", "par", "slp", "brn", "frz"]}
const VITAMINS := {"hp-up": 0, "protein": 1, "iron": 2, "calcium": 3, "zinc": 4, "carbos": 5}
## Baies utilisables hors combat : PV rendus (fraction des PV max si < 1).
const BERRY_HEAL := {"oran-berry": 10, "sitrus-berry": 0.25, "figy-berry": 0.33, "wiki-berry": 0.33, "mago-berry": 0.33,
	"aguav-berry": 0.33, "iapapa-berry": 0.33}
const BERRY_CURE := {"cheri-berry": ["par"], "chesto-berry": ["slp"], "pecha-berry": ["psn", "tox"], "rawst-berry": ["brn"],
	"aspear-berry": ["frz"], "lum-berry": ["par", "slp", "psn", "tox", "brn", "frz"]}
## Bonbons Exp. : points d'expérience donnés.
const EXP_CANDIES := {"exp-candy-xs": 100, "exp-candy-s": 800, "exp-candy-m": 3000, "exp-candy-l": 10000, "exp-candy-xl": 30000}
## Baies qui baissent les EV d'une stat de 10 (et rendent le Pokémon plus amical).
const EV_BERRIES := {"pomeg-berry": 0, "kelpsy-berry": 1, "qualot-berry": 2, "hondew-berry": 3, "grepa-berry": 4, "tamato-berry": 5}
## Objets qui font évoluer quand on les utilise (pierres, Fil de Liaison, pommes, tasses...), calculés depuis les données.
static var _evo_items := {}


static func is_evo_item(item: String) -> bool:
	if _evo_items.is_empty():
		_evo_items["linking-cord"] = true
		for id in Data.pokemon:
			for e in Data.pokemon[id]["evos"]:
				if e.has("item"):
					_evo_items[e["item"]] = true
	return _evo_items.has(item)


## Objet qu'un Pokémon peut tenir.
static func is_holdable(item: String) -> bool:
	return Data.items.get(item, {}).get("held", false)
const BATTLE_ONLY := ["x-attack", "x-defense", "x-sp-atk", "x-sp-def", "x-speed", "x-accuracy", "dire-hit", "guard-spec", "poke-doll"]
const PP_ITEMS := ["ether", "max-ether", "pp-up", "pp-max"]


static func is_ball(item: String) -> bool:
	return BALLS.has(item)


static func is_tm(item: String) -> bool:
	return item.begins_with("tm")


## Aromate : change la nature du Pokémon.
static func is_mint(item: String) -> bool:
	return item.ends_with("-mint")


## Objets d'entraînement (vitamines, Baies, Aromates, Capsule Talent, Capsules d'Argent...) : hors combat seulement.
static func field_only(item: String) -> bool:
	return VITAMINS.has(item) or EV_BERRIES.has(item) or is_mint(item) or EXP_CANDIES.has(item) \
		or item in ["ability-capsule", "ability-patch", "bottle-cap", "gold-bottle-cap"]


static func category(item: String) -> String:
	if is_ball(item):
		return "balls"
	if is_tm(item):
		return "ct"
	if Data.items.get(item, {}).get("key", false):
		return "rares"
	if Data.items.get(item, {}).get("berry", false):
		return "baies"
	if BATTLE_ONLY.has(item) or is_evo_item(item) or item.ends_with("repel") or item == "escape-rope" or item == "rare-candy" or field_only(item) \
			or item.begins_with("exp-candy") or item in ["ability-capsule", "ability-patch", "bottle-cap", "gold-bottle-cap"]:
		return "objets"
	if HEAL.has(item) or CURE.has(item) or PP_ITEMS.has(item) or item in ["revive", "max-revive", "elixir", "max-elixir"]:
		return "soins"
	if is_holdable(item):
		return "tenus"
	return "objets"


## Faut-il choisir une capacité (Huile, PP Plus, Baie Mepo) ?
static func needs_move(item: String) -> bool:
	return PP_ITEMS.has(item) or item == "leppa-berry"


## Faut-il choisir une statistique (Capsule d'Argent : un IV au maximum) ?
static func needs_stat(item: String) -> bool:
	return item == "bottle-cap"


## Objet utilisable sur un Pokémon de l'équipe ?
static func targets_pokemon(item: String) -> bool:
	return HEAL.has(item) or CURE.has(item) or field_only(item) or is_evo_item(item) or BERRY_HEAL.has(item) or BERRY_CURE.has(item) \
		or PP_ITEMS.has(item) or item in ["revive", "max-revive", "elixir", "max-elixir", "rare-candy", "leppa-berry"] or is_tm(item)


## Applique l'objet. Renvoie le message, ou "" si l'objet n'a aucun effet (il n'est alors pas consommé).
## Les Super Bonbons, pierres et CT sont gérés par l'interface (montée de niveau, évolution, apprentissage).
static func apply(mon: Pokemon, item: String, move_index := -1) -> String:
	var n := mon.name()
	if item in ["revive", "max-revive"]:
		if not mon.is_fainted():
			return ""
		mon.hp = mon.max_hp() if item == "max-revive" else maxi(1, mon.max_hp() / 2)
		mon.status = ""
		return "%s est ranimé !" % n
	if mon.is_fainted():
		return ""
	var msgs := []
	if HEAL.has(item) and mon.hp < mon.max_hp():
		var before := mon.hp
		mon.hp = mini(mon.max_hp(), mon.hp + HEAL[item])
		msgs.append("%s récupère %d PV !" % [n, mon.hp - before])
	if CURE.has(item) and CURE[item].has(mon.status):
		mon.status = ""
		mon.sleep_turns = 0
		msgs.append("%s est soigné !" % n)
	if VITAMINS.has(item):
		var i: int = VITAMINS[item]
		var total := 0
		for v in mon.evs:
			total += v
		if mon.evs[i] >= 252 or total >= 510:
			return ""
		mon.evs[i] = mini(252, mon.evs[i] + mini(10, 510 - total))
		mon.recalc_stats()
		mon.happiness = mini(255, mon.happiness + 5)
		msgs.append("%s de %s augmente !" % [Data.STAT_NAMES[i], n])
	if EV_BERRIES.has(item):
		var s: int = EV_BERRIES[item]
		if mon.evs[s] <= 0:
			return ""
		mon.evs[s] = maxi(0, mon.evs[s] - 10)
		mon.recalc_stats()
		mon.happiness = mini(255, mon.happiness + 10)
		msgs.append("%s de %s baisse ! (EV : %d)" % [Data.STAT_NAMES[s], n, mon.evs[s]])
	if is_mint(item):
		var nat := Pokemon.nature_index(item.trim_suffix("-mint"))
		if nat < 0 or nat == mon.nature:
			return ""
		mon.nature = nat
		mon.recalc_stats()
		msgs.append("%s hume l'Aromate... Sa nature devient %s !" % [n, Data.natures[nat]["name"]])
	if BERRY_HEAL.has(item) and mon.hp < mon.max_hp():
		var before2 := mon.hp
		var v = BERRY_HEAL[item]
		mon.hp = mini(mon.max_hp(), mon.hp + (int(v) if v is int else maxi(1, int(mon.max_hp() * v))))
		msgs.append("%s récupère %d PV !" % [n, mon.hp - before2])
	if BERRY_CURE.has(item) and BERRY_CURE[item].has(mon.status):
		mon.status = ""
		mon.sleep_turns = 0
		msgs.append("%s est soigné !" % n)
	if item == "leppa-berry" and move_index >= 0 and move_index < mon.moves.size():
		var lm: Dictionary = mon.moves[move_index]
		if lm["pp"] >= lm["max"]:
			return ""
		lm["pp"] = mini(lm["max"], lm["pp"] + 10)
		msgs.append("Les PP de %s sont restaurés !" % Data.move_name(lm["id"]))
	if item == "ability-capsule":
		var abl: Array = mon.data()["abilities"]
		if abl.size() < 2 or mon.has_hidden_ability():
			return ""
		mon.ability = abl[1] if mon.ability == abl[0] else abl[0]
		msgs.append("Le talent de %s devient %s !" % [n, Data.ability_name(mon.ability)])
	if item == "ability-patch":
		var ha: int = mon.data().get("ha", 0)
		if ha == 0 or mon.ability == ha:
			return ""
		mon.ability = ha
		msgs.append("Le talent de %s devient %s, son talent caché !" % [n, Data.ability_name(ha)])
	if item == "gold-bottle-cap":
		if mon.level < 50 or mon.ivs.all(func(v): return v == 31):
			return ""
		mon.ivs = [31, 31, 31, 31, 31, 31]
		mon.recalc_stats()
		msgs.append("Entraînement Ultime ! Tous les IV de %s sont au maximum !" % n)
	if item == "bottle-cap" and move_index >= 0 and move_index < 6:
		if mon.level < 50 or mon.ivs[move_index] >= 31:
			return ""
		mon.ivs[move_index] = 31
		mon.recalc_stats()
		msgs.append("Entraînement Ultime ! L'IV %s de %s est au maximum !" % [Data.STAT_NAMES[move_index], n])
	if EXP_CANDIES.has(item):
		if mon.level >= 100:
			return ""
		var reached := mon.add_exp(EXP_CANDIES[item])
		msgs.append("%s gagne %d Points Exp. !" % [n, EXP_CANDIES[item]])
		if reached.size() > 0:
			msgs.append("%s monte au niveau %d !" % [n, mon.level])
	if item in ["elixir", "max-elixir"]:
		var any := false
		for m in mon.moves:
			if m["pp"] < m["max"]:
				m["pp"] = m["max"] if item == "max-elixir" else mini(m["max"], m["pp"] + 10)
				any = true
		if any:
			msgs.append("Les PP de %s sont restaurés !" % n)
	if PP_ITEMS.has(item) and move_index >= 0 and move_index < mon.moves.size():
		var m: Dictionary = mon.moves[move_index]
		var mname := Data.move_name(m["id"])
		if item in ["ether", "max-ether"]:
			if m["pp"] >= m["max"]:
				return ""
			m["pp"] = m["max"] if item == "max-ether" else mini(m["max"], m["pp"] + 10)
			msgs.append("Les PP de %s sont restaurés !" % mname)
		else:
			if m["ups"] >= 3:
				return ""
			m["ups"] = 3 if item == "pp-max" else m["ups"] + 1
			var base: int = Data.moves[m["id"]]["pp"]
			var new_max := base + int(base * m["ups"] / 5)
			m["pp"] += new_max - m["max"]
			m["max"] = new_max
			msgs.append("Les PP max de %s augmentent !" % mname)
	return "\n".join(msgs)
