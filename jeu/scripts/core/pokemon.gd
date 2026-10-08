class_name Pokemon
extends RefCounted
## Un Pokémon possédé ou sauvage : statistiques, IV/EV, nature, talent, capacités, expérience.

const SHINY_ODDS := 4096
const HP_TYPES := ["fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
	"fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark"]

var species := 1
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


static func create(sid: int, lvl: int) -> Pokemon:
	var p := Pokemon.new()
	var d: Dictionary = Data.pokemon[sid]
	p.species = sid
	p.level = lvl
	p.exp = Data.exp_at(d["growth"], lvl)
	for i in 6:
		p.ivs[i] = randi_range(0, 31)
	p.nature = randi() % 25
	var ab: Array = d["abilities"]
	p.ability = ab[randi() % ab.size()] if ab.size() > 0 else 0
	if d["gender"] < 0:
		p.gender = 2
	else:
		p.gender = 1 if randi() % 8 < d["gender"] else 0
	p.shiny = randi() % SHINY_ODDS == 0
	p.happiness = d["happiness"]
	p.recalc_stats()
	p.hp = p.stats[0]
	p.reset_moves()
	return p


func data() -> Dictionary:
	return Data.pokemon[species]


func name() -> String:
	if is_egg:
		return "ŒUF"
	return nickname if nickname != "" else data()["name"]


## Peut combattre (ni K.O., ni œuf).
func can_battle() -> bool:
	return not is_egg and hp > 0


static func base_species(sid: int) -> int:
	var s := sid
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
		happiness = mini(255, happiness + 3)
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


func level_evolution() -> int:
	for e in data()["evos"]:
		if e.has("level") and level >= e["level"]:
			return e["to"]
	return 0


func item_evolution(item: String) -> int:
	for e in data()["evos"]:
		if e.get("item", "") == item:
			return e["to"]
	return 0


func evolve(to: int) -> void:
	var old_abilities: Array = data()["abilities"]
	var slot := maxi(0, old_abilities.find(ability))
	species = to
	var ab: Array = data()["abilities"]
	if ab.size() > 0:
		ability = ab[mini(slot, ab.size() - 1)]
	recalc_stats()


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


func gender_symbol() -> String:
	return ["♂", "♀", ""][gender]


func to_dict() -> Dictionary:
	return {
		"species": species, "nickname": nickname, "level": level, "exp": exp, "ivs": ivs, "evs": evs,
		"nature": nature, "ability": ability, "gender": gender, "shiny": shiny, "moves": moves,
		"hp": hp, "status": status, "sleep": sleep_turns, "ball": ball, "happiness": happiness, "ot": ot,
		"egg": is_egg, "egg_steps": egg_steps, "boss": boss, "maxhp": stats[0],
	}


static func from_dict(d: Dictionary) -> Pokemon:
	var p := Pokemon.new()
	p.species = d["species"]
	p.nickname = d.get("nickname", "")
	p.level = d["level"]
	p.exp = d["exp"]
	p.ivs = d["ivs"]
	p.evs = d["evs"]
	p.nature = d["nature"]
	p.ability = d["ability"]
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
