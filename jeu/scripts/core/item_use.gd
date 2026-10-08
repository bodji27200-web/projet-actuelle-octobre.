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
const STONES := ["fire-stone", "water-stone", "thunder-stone", "leaf-stone", "moon-stone", "linking-cord"]
const BATTLE_ONLY := ["x-attack", "x-defense", "x-sp-atk", "x-sp-def", "x-speed", "x-accuracy", "dire-hit", "guard-spec"]
const PP_ITEMS := ["ether", "max-ether", "pp-up", "pp-max"]


static func is_ball(item: String) -> bool:
	return BALLS.has(item)


static func is_tm(item: String) -> bool:
	return item.begins_with("tm")


static func category(item: String) -> String:
	if is_ball(item):
		return "balls"
	if is_tm(item):
		return "ct"
	if Data.items.get(item, {}).get("key", false):
		return "rares"
	if BATTLE_ONLY.has(item) or STONES.has(item) or item.ends_with("repel") or item == "escape-rope" or item == "rare-candy" or VITAMINS.has(item):
		return "objets"
	return "soins"


## Faut-il choisir une capacité (Huile, PP Plus) ?
static func needs_move(item: String) -> bool:
	return PP_ITEMS.has(item)


## Objet utilisable sur un Pokémon de l'équipe ?
static func targets_pokemon(item: String) -> bool:
	return HEAL.has(item) or CURE.has(item) or VITAMINS.has(item) or STONES.has(item) \
		or PP_ITEMS.has(item) or item in ["revive", "max-revive", "elixir", "max-elixir", "rare-candy"] or is_tm(item)


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
