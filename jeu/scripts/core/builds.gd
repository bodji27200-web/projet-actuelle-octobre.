class_name Builds
extends RefCounted
## Builds compétitifs automatiques pour les dresseurs de fin de jeu : IV parfaits, EV 252/252/4,
## nature adaptée, quatre capacités choisies dans tout ce que le Pokémon peut apprendre (STAB, couverture,
## boost ou soin), talent le plus fort, objet tenu adapté (Méga-Gemme si elle existe).

const SETUP := {"physical": ["swords-dance", "dragon-dance", "bulk-up", "shift-gear", "victory-dance", "coil", "howl", "curse"],
	"special": ["nasty-plot", "calm-mind", "quiver-dance", "tail-glow", "take-heart", "torch-song"]}
const RECOVERY := ["recover", "roost", "slack-off", "soft-boiled", "milk-drink", "moonlight", "morning-sun", "synthesis",
	"shore-up", "strength-sap", "wish", "rest"]
## Capacités à éviter dans un build automatique (recharge, autodestruction, conditions très particulières).
const AVOID := ["hyper-beam", "giga-impact", "blast-burn", "frenzy-plant", "hydro-cannon", "rock-wrecker", "roar-of-time",
	"prismatic-laser", "eternabeam", "meteor-assault", "self-destruct", "explosion", "misty-explosion", "memento",
	"final-gambit", "dream-eater", "last-resort", "belch", "synchronoise", "snore", "spit-up", "natural-gift",
	"burn-up", "double-shock", "focus-punch", "solar-beam", "solar-blade", "sky-attack", "skull-bash", "razor-wind",
	"freeze-shock", "ice-burn", "geomancy", "meteor-beam", "electro-shot", "dig", "dive", "fly", "bounce",
	"phantom-force", "shadow-force", "steel-beam", "mind-blown", "head-smash", "light-of-ruin", "doom-desire",
	"future-sight", "fling", "trump-card", "beat-up", "present", "magnitude", "fishious-rend", "bolt-beak",
	"hidden-power", "struggle", "chatter", "relic-song", "dragon-rage", "sonic-boom", "night-shade", "seismic-toss",
	"super-fang", "endeavor", "counter", "mirror-coat", "metal-burst", "bide", "punishment", "stored-power",
	"power-trip", "rollout", "ice-ball", "fury-cutter", "echoed-voice", "round", "uproar", "thrash", "petal-dance",
	"outrage", "raging-fury", "gigaton-hammer", "blood-moon", "hyperspace-fury", "hyperspace-hole"]
## Talents forts, par ordre de préférence quand le Pokémon a le choix.
const GOOD_ABILITIES := ["huge-power", "pure-power", "speed-boost", "protean", "libero", "adaptability", "magic-guard",
	"regenerator", "beast-boost", "good-as-gold", "protosynthesis", "quark-drive", "intrepid-sword", "dauntless-shield",
	"gorilla-tactics", "drought", "drizzle", "sand-stream", "snow-warning", "multiscale", "unaware", "contrary",
	"moxie", "tough-claws", "sharpness", "sheer-force", "technician", "guts", "poison-heal", "magic-bounce",
	"prankster", "serene-grace", "no-guard", "iron-fist", "strong-jaw", "mega-launcher", "intimidate", "levitate",
	"thick-fat", "volt-absorb", "water-absorb", "flash-fire", "sap-sipper", "storm-drain", "lightning-rod",
	"natural-cure", "clear-body", "sturdy", "swift-swim", "chlorophyll", "sand-rush", "slush-rush", "surge-surfer"]

static func _nature_index(ident: String) -> int:
	for i in Data.natures.size():
		if Data.natures[i].get("ident", "") == ident:
			return i
	return 0


## Toutes les capacités que ce Pokémon peut connaître (niveau, CT, tuteur, œuf).
static func learnable(m: Pokemon) -> Array:
	var d := m.data()
	var out := {}
	for e in d.get("learn", []):
		out[int(e[1])] = true
	for k in ["tm", "tutor", "egg"]:
		for id in d.get(k, []):
			out[int(id)] = true
	return out.keys()


static func _score(m: Pokemon, mv: Dictionary, phys: bool) -> float:
	var power := float(mv.get("power", 0))
	if power <= 0:
		return 0.0
	var acc := float(mv.get("acc", 0))
	var s := power * (acc / 100.0 if acc > 0 else 1.0)
	var hits := (int(mv.get("min_hits", 0)) + int(mv.get("max_hits", 0))) / 2.0
	if hits > 1:
		s *= hits
	if m.types().has(mv["type"]):
		s *= 1.5
	var cat: String = mv.get("cat", "")
	if (cat == "physical") != phys:
		s *= 0.35
	if int(mv.get("prio", 0)) > 0:
		s *= 0.8
	return s


## Applique un build compétitif au Pokémon (il garde son espèce et son niveau).
static func auto(m: Pokemon, allow_mega := true) -> void:
	var d := m.data()
	var base: Array = d["base"]
	var phys: bool = base[1] >= base[3]
	var fast: bool = base[5] >= 80
	var slow: bool = base[5] < 45
	var side := "physical" if phys else "special"
	# Nature, IV, EV.
	var nat := "jolly" if phys and fast else "adamant" if phys else "timid" if fast else "modest"
	if slow:
		nat = "brave" if phys else "quiet"
	m.nature = _nature_index(nat)
	for i in 6:
		m.ivs[i] = 31
	if not phys:
		m.ivs[1] = 0
	if slow:
		m.ivs[5] = 0
	m.evs = [4, 0, 0, 0, 0, 0]
	m.evs[1 if phys else 3] = 252
	if slow:
		m.evs[0] = 252
	else:
		m.evs[5] = 252
	# Talent.
	var abilities: Array = d.get("abilities", []).duplicate()
	if int(d.get("ha", 0)) != 0:
		abilities.append(d["ha"])
	var best := 999
	for a in abilities:
		var r := GOOD_ABILITIES.find(Data.ability_ident(a))
		if r >= 0 and r < best:
			best = r
			m.ability = a
	# Capacités.
	var pool := []
	for id in learnable(m):
		if not Data.moves.has(id):
			continue
		var mv: Dictionary = Data.moves[id]
		if mv["ident"] in AVOID or int(mv.get("acc", 100)) in range(1, 70):
			continue
		pool.append(id)
	var chosen := []
	var types_done := []
	# 1) Meilleure attaque de chaque type du Pokémon (STAB).
	for t in m.types():
		var bid := -1
		var bs := 0.0
		for id in pool:
			if Data.moves[id]["type"] != t:
				continue
			var s := _score(m, Data.moves[id], phys)
			if s > bs:
				bs = s
				bid = id
		if bid >= 0 and not chosen.has(bid):
			chosen.append(bid)
			types_done.append(t)
	# 2) Couverture : l'attaque qui touche en super efficace le plus de types restants.
	var all_types: Array = Data.TYPE_COLORS.keys()
	for k in 2:
		if chosen.size() >= 3:
			break
		var bid2 := -1
		var bs2 := 0.0
		for id in pool:
			var mv2: Dictionary = Data.moves[id]
			if chosen.has(id) or types_done.has(mv2["type"]) or int(mv2.get("power", 0)) <= 0:
				continue
			var cover := 0
			for t2 in all_types:
				if Data.effectiveness(mv2["type"], [t2]) > 1.0:
					cover += 1
			var s2 := _score(m, mv2, phys) * (1.0 + cover * 0.25)
			if s2 > bs2:
				bs2 = s2
				bid2 = id
		if bid2 >= 0:
			chosen.append(bid2)
			types_done.append(Data.moves[bid2]["type"])
	# 3) Boost ou soin.
	for ident in SETUP[side] + RECOVERY:
		if chosen.size() >= 4:
			break
		var id3 := _id_of(ident)
		if id3 > 0 and pool.has(id3) and not chosen.has(id3):
			chosen.append(id3)
			break
	# 4) Compléter avec les meilleures attaques restantes.
	var rest := pool.filter(func(id): return not chosen.has(id) and int(Data.moves[id].get("power", 0)) > 0)
	rest.sort_custom(func(a, b): return _score(m, Data.moves[a], phys) > _score(m, Data.moves[b], phys))
	for id in rest:
		if chosen.size() >= 4:
			break
		chosen.append(id)
	if chosen.size() > 0:
		m.moves = chosen.map(func(id): return Pokemon.make_move(id))
	# Objet tenu.
	m.held_item = _item(m, base, phys, fast, chosen, allow_mega)
	m.recalc_stats()
	m.hp = m.max_hp()


static var _ids := {}


static func _id_of(ident: String) -> int:
	if _ids.is_empty():
		for id in Data.moves:
			_ids[Data.moves[id]["ident"]] = int(id)
	return _ids.get(ident, 0)


static func _item(m: Pokemon, base: Array, phys: bool, fast: bool, chosen: Array, allow_mega: bool) -> String:
	if allow_mega:
		for stone in Data.mega_stones:
			var pid: int = Data.mega_stones[stone]
			if Data.pokemon.has(pid) and Data.pokemon[pid].get("species", pid) == m.species:
				return stone
	var attacks := chosen.filter(func(id): return Data.moves[id]["cat"] != "status").size()
	var bulk: int = base[0] + base[2] + base[4]
	if Data.pokemon[m.species]["evos"].size() > 0:
		return "eviolite"
	if attacks == 4:
		if fast and base[5] < 110:
			return "choice-scarf"
		return "choice-band" if phys else "choice-specs"
	if bulk >= 300:
		return "leftovers" if attacks < 3 else "assault-vest"
	if base[0] + base[2] + base[4] < 200:
		return "focus-sash"
	return "life-orb"
