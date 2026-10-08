extends Node
## État de la partie (équipe, sac, argent, Pokédex, drapeaux d'histoire) + sauvegarde + entrées.

const SAVE_PATH := "user://sauvegarde.json"
const PARTY_MAX := 6

var player_name := "Sacha"
var rival_name := "Régis"
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

var maps := {}
var ui: Node
var world: Node
var _stack: Array = []
var _push_frame := {}
var font: FontFile


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://data/maps.json", FileAccess.READ)
	maps = Data._intify(JSON.parse_string(f.get_as_text()))
	_setup_inputs()
	font = load("res://assets/fonts/Jersey10.ttf")
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	get_tree().root.theme = theme


func _process(delta: float) -> void:
	play_time += delta


func _setup_inputs() -> void:
	var keys := {
		"up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S], "left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D],
		"a": [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER, KEY_E], "b": [KEY_ESCAPE, KEY_BACKSPACE, KEY_X],
		"start": [KEY_TAB, KEY_M], "run": [KEY_SHIFT],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			# Flèches et ZQSD : position physique (fonctionne en AZERTY comme en QWERTY).
			if k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_X]:
				ev.physical_keycode = k
			else:
				ev.keycode = k
			InputMap.action_add_event(action, ev)


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
# Sac, équipe, Pokédex
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
	catch_register(mon.species)
	if party.size() < PARTY_MAX:
		party.append(mon)
		return "party"
	pc.append(mon)
	return "pc"


func heal_party() -> void:
	for m in party:
		m.heal_full()


func alive_count() -> int:
	var n := 0
	for m in party:
		if not m.is_fainted():
			n += 1
	return n


func lead() -> Pokemon:
	for m in party:
		if not m.is_fainted():
			return m
	return party[0] if party.size() > 0 else null


func flag(id: String) -> bool:
	return flags.get(id, false)


func set_flag(id: String, v := true) -> void:
	flags[id] = v


# ---------------------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var d := {
		"player_name": player_name, "rival_name": rival_name, "money": money,
		"party": party.map(func(m): return m.to_dict()), "pc": pc.map(func(m): return m.to_dict()),
		"bag": bag, "flags": flags, "seen": seen.keys(), "caught": caught.keys(),
		"map": map_id, "x": pos.x, "y": pos.y, "facing": facing, "heal": heal_point,
		"repel": repel_steps, "time": play_time, "starter": starter, "return": return_point,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = Data._intify(JSON.parse_string(f.get_as_text()))
	if not d is Dictionary:
		return false
	player_name = d["player_name"]
	rival_name = d.get("rival_name", "Régis")
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
	pos = Vector2i(d["x"], d["y"])
	facing = d["facing"]
	heal_point = d["heal"]
	repel_steps = d.get("repel", 0)
	play_time = d.get("time", 0.0)
	starter = d.get("starter", 0)
	return_point = d.get("return", {})
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


func time_text() -> String:
	var t := int(play_time)
	return "%d:%02d" % [t / 3600, (t / 60) % 60]
