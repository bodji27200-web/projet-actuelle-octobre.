extends Node
## État de la partie (équipe, sac, argent, Pokédex, badges, quêtes, tenues) + sauvegarde + paramètres.

const SAVE_PATH := "user://sauvegarde.json"
const SETTINGS_PATH := "user://parametres.json"
const PARTY_MAX := 6
const RIVAL_NAME := "Régis"

## Actions modifiables dans les paramètres (nom affiché, touches par défaut).
const ACTIONS := {
	"up": ["Haut", [KEY_UP, KEY_W]], "down": ["Bas", [KEY_DOWN, KEY_S]], "left": ["Gauche", [KEY_LEFT, KEY_A]],
	"right": ["Droite", [KEY_RIGHT, KEY_D]], "a": ["Valider (A)", [KEY_ENTER, KEY_SPACE]], "b": ["Retour (B)", [KEY_ESCAPE, KEY_BACKSPACE]],
	"start": ["Menu", [KEY_TAB, KEY_M]], "run": ["Courir", [KEY_SHIFT]], "bike": ["Vélo", [KEY_V]], "map": ["Carte", [KEY_C]],
	"chat": ["Discussion", [KEY_T]],
}

const OUTFITS := {
	"classique": {"name": "Classique", "h": "e03838", "H": "a02020", "c": "3870d0", "C": "28509c", "p": "303850", "b": "c03030"},
	"casquette_bleue": {"name": "Casquette bleue", "h": "3878e0", "H": "2050a0", "c": "f0f0f0", "C": "c0c0c8", "p": "3060c0", "b": "404040"},
	"bleu_marine": {"name": "Bleu marine", "h": "203878", "H": "102050", "c": "304890", "C": "203068", "p": "202838", "b": "f0f0f0"},
	"vert_foret": {"name": "Vert forêt", "h": "40903c", "H": "286828", "c": "58a048", "C": "407838", "p": "604830", "b": "403020"},
	"rose_bonbon": {"name": "Rose bonbon", "h": "f070a8", "H": "c04880", "c": "f8a8c8", "C": "e080a8", "p": "f0f0f0", "b": "f070a8"},
	"noir_minuit": {"name": "Noir minuit", "h": "303038", "H": "181820", "c": "383848", "C": "202030", "p": "181820", "b": "8040c0"},
	"blanc_neige": {"name": "Blanc neige", "h": "f8f8f8", "H": "c8d0e0", "c": "e8f0f8", "C": "b8c8e0", "p": "a0b8d8", "b": "6090d0"},
	"orange_soleil": {"name": "Orange soleil", "h": "f89030", "H": "c06010", "c": "f8c030", "C": "d09020", "p": "805020", "b": "f89030"},
	"chercheur": {"name": "Chercheur", "h": "806040", "H": "604028", "c": "f8f8f8", "C": "d0d0d8", "p": "505870", "b": "403020"},
	"pont_dore": {"name": "Pont Doré", "h": "f0c030", "H": "c09010", "c": "f8e070", "C": "d0b040", "p": "806020", "b": "c09010"},
	"spectre": {"name": "Spectre", "h": "8058b0", "H": "583890", "c": "6848a0", "C": "483078", "p": "302040", "b": "a080d0"},
	"rocket": {"name": "Uniforme Rocket", "h": "303030", "H": "181818", "c": "303030", "C": "202020", "p": "202020", "b": "e03030", "w": "e03030"},
	"safari": {"name": "Gardien du Safari", "h": "c0a060", "H": "907040", "c": "a08850", "C": "806838", "p": "706040", "b": "503820"},
	"dragon": {"name": "Dompteur de dragons", "h": "c03028", "H": "801810", "c": "202838", "C": "101828", "p": "202838", "b": "f0c030"},
	"champion": {"name": "Maître de la Ligue", "h": "f8f8f8", "H": "d0d0d0", "c": "c02828", "C": "901818", "p": "f8f8f8", "b": "f0c030", "w": "f0c030"},
}
const OUTFIT_PRICE := 3000

var player_name := "Sacha"
var gender := 0  # 0 garçon, 1 fille
var rival_name := RIVAL_NAME
var money := 3000
var party: Array = []
var pc: Array = []
var bag := {}
var flags := {}
var seen := {}
var caught := {}
var map_id := "maison"
var pos := Vector2i(4, 3)
var facing := "down"
var heal_point := {"map": "maison", "x": 4, "y": 3}
var repel_steps := 0
var play_time := 0.0
var starter := 0
var return_point := {}
var badges: Array = []
var quests := {}
var outfits: Array = ["classique"]
var outfit := "classique"
var daycare: Array = []
var daycare_steps := 0
var daycare_egg := false
var steps := 0
var on_bike := false
var last_outdoor := "bourg"

var settings := {
	"text_speed": 1, "music": 0.7, "sfx": 0.8, "cries": true, "animations": true, "difficulty": 0,
	"minimap": true, "window": 1, "keys": {},
}

var maps := {}
var trainers := {}
var quest_defs := {}
var classes := {}
var type_pool := {}
var world_rects := {}
var ui: Node
var world: Node
var _stack: Array = []
var _push_frame := {}
var font: FontFile


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://data/world.json", FileAccess.READ)
	var w: Dictionary = Data._intify(JSON.parse_string(f.get_as_text()))
	maps = w["maps"]
	trainers = w["trainers"]
	quest_defs = w["quests"]
	classes = w["classes"]
	type_pool = w["type_pool"]
	world_rects = w["world"]
	load_settings()
	apply_keys()
	font = load("res://assets/fonts/Jersey10Jeu.ttf")
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	get_tree().root.theme = theme
	apply_window.call_deferred()


func _process(delta: float) -> void:
	play_time += delta


# ---------------------------------------------------------------------------
# Paramètres et touches
# ---------------------------------------------------------------------------

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for k in d:
			settings[k] = d[k]


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(settings))


func key_list(action: String) -> Array:
	var custom: Dictionary = settings.get("keys", {})
	if custom.has(action):
		return custom[action].map(func(k): return int(k))
	return ACTIONS[action][1]


func apply_keys() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for k in key_list(action):
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		if action == "a":
			var kp := InputEventKey.new()
			kp.physical_keycode = KEY_KP_ENTER
			InputMap.action_add_event(action, kp)


func set_key(action: String, slot: int, keycode: int) -> void:
	var lst := key_list(action).duplicate()
	while lst.size() <= slot:
		lst.append(0)
	lst[slot] = keycode
	lst = lst.filter(func(k): return k != 0)
	if not settings.has("keys") or not settings["keys"] is Dictionary:
		settings["keys"] = {}
	settings["keys"][action] = lst
	apply_keys()
	save_settings()


func reset_keys() -> void:
	settings["keys"] = {}
	apply_keys()
	save_settings()


func key_name(k: int) -> String:
	if k == 0:
		return "—"
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(k)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k))


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var w: int = int(settings.get("window", 1))
	if w == 3:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(480, 320) * [2, 3, 4][w]


func text_speed() -> float:
	return [35.0, 60.0, 140.0][int(settings.get("text_speed", 1))]


func difficulty() -> int:
	return int(settings.get("difficulty", 0))


# ---------------------------------------------------------------------------
# Pile d'écrans : seul l'écran du dessus reçoit les touches.
# ---------------------------------------------------------------------------

func push(node: Node) -> void:
	_stack.append(node)
	_push_frame[node.get_instance_id()] = Engine.get_process_frames()


func pop(node: Node) -> void:
	_stack.erase(node)
	for n in _stack:
		_push_frame[n.get_instance_id()] = Engine.get_process_frames()


func is_top(node: Node) -> bool:
	if _stack.is_empty() or _stack[-1] != node:
		return false
	return _push_frame.get(node.get_instance_id(), -1) != Engine.get_process_frames()


func ui_busy() -> bool:
	return not _stack.is_empty()


func pressed(node: Node, action: String) -> bool:
	return is_top(node) and Input.is_action_just_pressed(action)


# ---------------------------------------------------------------------------
# Sac, équipe, Pokédex, progression
# ---------------------------------------------------------------------------

func add_item(id: String, n := 1) -> void:
	bag[id] = bag.get(id, 0) + n


func remove_item(id: String, n := 1) -> void:
	bag[id] = bag.get(id, 0) - n
	if bag[id] <= 0:
		bag.erase(id)


func item_count(id: String) -> int:
	return bag.get(id, 0)


func see(sid: int) -> void:
	seen[sid] = true


func catch_register(sid: int) -> void:
	seen[sid] = true
	caught[sid] = true


## Ajoute un Pokémon à l'équipe ou au PC. Renvoie "party" ou "pc".
func give_pokemon(mon: Pokemon) -> String:
	if mon.ot == "":
		mon.ot = player_name
	if not mon.is_egg:
		catch_register(mon.species)
	if party.size() < PARTY_MAX:
		party.append(mon)
		return "party"
	pc.append(mon)
	return "pc"


func heal_party() -> void:
	for m in party:
		if not m.is_egg:
			m.heal_full()


func alive_count() -> int:
	var n := 0
	for m in party:
		if m.can_battle():
			n += 1
	return n


## Région de la carte actuelle (kanto, johto, alola...) : formes régionales, évolutions.
func current_region() -> String:
	return maps.get(map_id, {}).get("realm", "kanto")


func lead() -> Pokemon:
	for m in party:
		if m.can_battle():
			return m
	for m in party:
		if not m.is_egg:
			return m
	return null


func flag(id: String) -> bool:
	return flags.get(id, false)


func set_flag(id: String, v := true) -> void:
	flags[id] = v


func badge_count() -> int:
	return badges.size()


func give_badge(n: int) -> void:
	if not badges.has(n):
		badges.append(n)
	set_flag("badge_%d" % n)


func set_quest(q: String, stage: int) -> void:
	if int(quests.get(q, -1)) < stage:
		quests[q] = stage


func give_outfit(o: String) -> bool:
	if outfits.has(o):
		return false
	outfits.append(o)
	return true


## Nom d'apparence utilisé par PixelArt.character : "boy_classique", "girl_rocket"...
func look() -> String:
	return "%s_%s" % ["girl" if gender == 1 else "boy", outfit]


## Évalue une condition de script ({"flag": f}, {"badges": n}, {"item": id}...).
func check(cond: Variant) -> bool:
	if cond == null or (cond is Dictionary and cond.is_empty()):
		return true
	if cond.has("flag"):
		return flag(cond["flag"])
	if cond.has("not"):
		return not flag(cond["not"])
	if cond.has("badges"):
		return badge_count() >= int(cond["badges"])
	if cond.has("item"):
		return item_count(cond["item"]) > 0
	if cond.has("caught"):
		return caught.size() >= int(cond["caught"])
	if cond.has("party_has"):
		for m in party:
			if m.species == int(cond["party_has"]) and not m.is_egg:
				return true
		return false
	if cond.has("all_flags"):
		for f in cond["all_flags"]:
			if not flag(f):
				return false
		return true
	return true


## Un pas de plus : œufs, pension. Renvoie les œufs qui éclosent.
func on_step() -> Array:
	var hatched := []
	steps += 1
	var fast := false
	for m in party:
		if not m.is_egg and Data.ability_ident(m.ability) in ["flame-body", "magma-armor"]:
			fast = true
	for m in party:
		if m.is_egg:
			m.egg_steps -= 2 if fast else 1
			if m.egg_steps <= 0:
				hatched.append(m)
	if daycare.size() > 0:
		daycare_steps += 1
		for m in daycare:
			if m.level < 100:
				m.add_exp(1)
		if daycare_steps % 256 == 0 and not daycare_egg:
			var c := daycare_compat()
			if item_count("oval-charm") > 0:
				c = mini(88, c + (c / 2 if c >= 50 else c))
			if c > 0 and randi() % 100 < c:
				daycare_egg = true
	return hatched


## Chance (en %) que les deux Pokémon de la pension produisent un Œuf (règles des jeux).
func daycare_compat() -> int:
	if daycare.size() < 2:
		return 0
	var a: Pokemon = daycare[0]
	var b: Pokemon = daycare[1]
	var ga: Array = a.data()["egg_groups"]
	var gb: Array = b.data()["egg_groups"]
	if "no-eggs" in ga or "no-eggs" in gb:
		return 0
	var ditto_a := a.species == 132
	var ditto_b := b.species == 132
	if ditto_a and ditto_b:
		return 0
	if ditto_a or ditto_b:
		return 20
	if a.gender == 2 or b.gender == 2 or a.gender == b.gender:
		return 0
	for g in ga:
		if gb.has(g):
			return 50 if a.species == b.species else 20
	return 0


## Bébés qui ne naissent que si un parent tient l'Encens adapté (sinon l'Œuf donne l'évolution).
const INCENSE_BABIES := {298: "sea-incense", 360: "lax-incense", 406: "rose-incense", 433: "pure-incense",
	438: "rock-incense", 439: "odd-incense", 440: "luck-incense", 446: "full-incense", 458: "wave-incense"}
## Objets Pouvoir : l'IV de cette stat est transmis par le parent qui le tient.
const POWER_ITEMS := {"power-weight": 0, "power-bracer": 1, "power-belt": 2, "power-lens": 3, "power-band": 4, "power-anklet": 5}


## Œuf de la pension, règles des jeux récents :
## Nœud Destin = 5 IV hérités (3 sinon), objets Pouvoir, Pierre Stase = nature transmise,
## talent caché transmis (60 %), Ball de la mère, capacités Œuf des deux parents, forme régionale, Encens.
func daycare_make_egg() -> Pokemon:
	var a: Pokemon = daycare[0]
	var b: Pokemon = daycare[1]
	var mother := a
	if a.species == 132 or (b.gender == 1 and b.species != 132):
		mother = b
	var father := b if mother == a else a
	var parents := [a, b]
	var base := Pokemon.base_species(mother.species)
	if INCENSE_BABIES.has(base) and not (a.held_item == INCENSE_BABIES[base] or b.held_item == INCENSE_BABIES[base]):
		for e in Data.pokemon[base]["evos"]:
			if not e.has("region"):
				base = e["to"]
				break
	if base in [29, 32]:
		base = [29, 32][randi() % 2]
	elif base in [313, 314]:
		base = [313, 314][randi() % 2]
	elif base == 489:
		base = 490
	# Forme régionale de la mère (Goupix d'Alola donne des Goupix d'Alola).
	var egg_id := base
	var region: String = mother.data().get("regional", "")
	if region != "":
		for f in Data.pokemon[base].get("forms", []):
			if Data.pokemon[f].get("regional", "") == region:
				egg_id = f
	var egg := Pokemon.create_egg(egg_id)
	# IV : 3 hérités (5 avec un Nœud Destin), dont celui imposé par un objet Pouvoir.
	var n := 5 if a.held_item == "destiny-knot" or b.held_item == "destiny-knot" else 3
	var idx := [0, 1, 2, 3, 4, 5]
	idx.shuffle()
	var forced := []
	for p in parents:
		if POWER_ITEMS.has(p.held_item):
			forced.append([POWER_ITEMS[p.held_item], p])
	if forced.size() > 0:
		var f: Array = forced[randi() % forced.size()]
		egg.ivs[f[0]] = f[1].ivs[f[0]]
		idx.erase(f[0])
		n -= 1
	for i in n:
		egg.ivs[idx[i]] = parents[randi() % 2].ivs[idx[i]]
	# Nature : Pierre Stase.
	var stones := parents.filter(func(p): return p.held_item == "everstone")
	if stones.size() > 0:
		egg.nature = stones[randi() % stones.size()].nature
	# Talent caché : transmis par la mère (ou le parent qui n'est pas Métamorph).
	var carrier: Pokemon = mother if mother.species != 132 else father
	if carrier.has_hidden_ability() and randf() < 0.6 and egg.data().get("ha", 0) != 0:
		egg.ability = egg.data()["ha"]
	# Ball de la mère.
	if mother.species != 132 and mother.ball not in ["master-ball", "cherish-ball"]:
		egg.ball = mother.ball
	# Capacités Œuf connues par l'un des parents.
	var egg_moves: Array = egg.data().get("egg", [])
	for p in parents:
		for m in p.moves:
			if egg_moves.has(m["id"]) and not egg.knows(m["id"]):
				if egg.moves.size() >= 4:
					egg.moves.pop_front()
				egg.moves.append(Pokemon.make_move(m["id"]))
	egg.recalc_stats()
	egg.hp = egg.max_hp()
	return egg


# ---------------------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_dict() -> Dictionary:
	return {
		"version": 2, "player_name": player_name, "gender": gender, "money": money,
		"party": party.map(func(m): return m.to_dict()), "pc": pc.map(func(m): return m.to_dict()),
		"bag": bag, "flags": flags, "seen": seen.keys(), "caught": caught.keys(),
		"map": map_id, "x": pos.x, "y": pos.y, "facing": facing, "heal": heal_point,
		"repel": repel_steps, "time": play_time, "starter": starter, "return": return_point,
		"badges": badges, "quests": quests, "outfits": outfits, "outfit": outfit,
		"daycare": daycare.map(func(m): return m.to_dict()), "daycare_steps": daycare_steps, "daycare_egg": daycare_egg,
		"steps": steps, "last_outdoor": last_outdoor,
	}


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(save_dict()))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = Data._intify(JSON.parse_string(f.get_as_text()))
	if not d is Dictionary or int(d.get("version", 1)) < 2:
		return false
	player_name = d["player_name"]
	gender = d.get("gender", 0)
	money = d["money"]
	party = d["party"].map(func(x): return Pokemon.from_dict(x))
	pc = d["pc"].map(func(x): return Pokemon.from_dict(x))
	bag = d["bag"]
	flags = d["flags"]
	seen = {}
	for s in d["seen"]:
		seen[int(s)] = true
	caught = {}
	for s in d["caught"]:
		caught[int(s)] = true
	map_id = d["map"]
	if not maps.has(map_id):
		map_id = "maison"
	pos = Vector2i(d["x"], d["y"])
	facing = d["facing"]
	heal_point = d["heal"]
	repel_steps = d.get("repel", 0)
	play_time = d.get("time", 0.0)
	starter = d.get("starter", 0)
	return_point = d.get("return", {})
	badges = d.get("badges", [])
	quests = d.get("quests", {})
	outfits = d.get("outfits", ["classique"])
	outfit = d.get("outfit", "classique")
	daycare = d.get("daycare", []).map(func(x): return Pokemon.from_dict(x))
	daycare_steps = d.get("daycare_steps", 0)
	daycare_egg = d.get("daycare_egg", false)
	steps = d.get("steps", 0)
	last_outdoor = d.get("last_outdoor", "bourg")
	rival_name = RIVAL_NAME
	return true


func new_game() -> void:
	party = []
	pc = []
	bag = {"potion": 1}
	flags = {}
	seen = {}
	caught = {}
	money = 3000
	map_id = "maison"
	pos = Vector2i(4, 3)
	facing = "down"
	heal_point = {"map": "maison", "x": 4, "y": 3}
	play_time = 0.0
	starter = 0
	badges = []
	quests = {"main": 0}
	outfits = ["classique"]
	outfit = "classique"
	daycare = []
	daycare_steps = 0
	daycare_egg = false
	steps = 0
	rival_name = RIVAL_NAME
	last_outdoor = "bourg"


func time_text() -> String:
	var t := int(play_time)
	return "%d:%02d" % [t / 3600, (t / 60) % 60]
