extends Node2D
## Le monde : dessin de la carte, déplacements case par case, PNJ, portes et rencontres.

const T := 16
const WALK_TIME := 0.22
const RUN_TIME := 0.12
const WALKABLE := '.,"f v:w_oqm'
const COUNTERS := "CK"
const TILE_NAMES := {".": "grass", ",": "path", '"': "tall", "T": "tree", "~": "water", "f": "flower",
	"=": "fence", "S": "sign", "v": "ledge", ":": "sand", "R": "rock", "w": "marsh", "_": "cave",
	"#": "cavewall", "o": "floor", "q": "tilefloor", "W": "wall", "m": "mat", "X": "table", "B": "shelf",
	"P": "pc", "C": "counter", "K": "shopcounter", "b": "bed", "t": "tv", "p": "plant", "M": "machine", " ": "black"}
const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}


class Walker:
	extends Sprite2D
	var tile := Vector2i.ZERO
	var dir := "down"
	var look := "player"
	var data := {}
	var step_frame := 1

	func face(d: String) -> void:
		dir = d
		refresh(0)

	func refresh(frame: int) -> void:
		if look == "ball":
			texture = PixelArt.ball()
			offset = Vector2(2, 2)
		elif look == "legend":
			pass
		else:
			texture = PixelArt.character(look, dir, frame)

	func place(t: Vector2i) -> void:
		tile = t
		position = Vector2(t * T)


var map_id := ""
var map := {}
var rows: Array = []
var walkers: Array = []
var player: Walker
var busy := false
var moving := false
var frozen := false
var _water_frame := 0
var _water_t := 0.0
var _ground: Node2D
var _actors: Node2D
var _camera: Camera2D
var _blocked := {}
var _doors := {}
var _turn_t := 0.0


func _ready() -> void:
	Game.world = self
	_ground = Node2D.new()
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	_camera = Camera2D.new()
	_camera.zoom = Vector2(2, 2)
	add_child(_camera)
	_camera.make_current()


# ---------------------------------------------------------------------------
# Chargement
# ---------------------------------------------------------------------------

func load_map(id: String, at: Vector2i, facing := "down") -> void:
	map_id = id
	map = Game.maps[id]
	rows = map["rows"]
	Game.map_id = id
	for w in walkers:
		w.queue_free()
	walkers.clear()
	for c in _actors.get_children():
		c.queue_free()
	for c in _ground.get_children():
		c.queue_free()
	_blocked.clear()
	_doors.clear()
	for b in map["buildings"]:
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = PixelArt.building(b["kind"], b["w"], b["h"])
		spr.position = Vector2(b["x"] * T, b["y"] * T)
		spr.z_index = 0
		_ground.add_child(spr)
		for y in range(b["y"], b["y"] + b["h"]):
			for x in range(b["x"], b["x"] + b["w"]):
				_blocked[Vector2i(x, y)] = true
		_doors[Vector2i(b["x"] + b["w"] / 2, b["y"] + b["h"] - 1)] = b
	for n in map["npcs"]:
		if _npc_hidden(n):
			continue
		var w := Walker.new()
		w.centered = false
		w.look = n["look"]
		w.data = n
		w.place(Vector2i(n["x"], n["y"]))
		if n["look"] == "legend":
			w.scale = Vector2(0.4, 0.4)
			w.offset = Vector2(-28, -40)
			Sprites.apply(w, "front", n["species"], false, PixelArt.placeholder())
		w.face(n.get("dir", "down"))
		_actors.add_child(w)
		walkers.append(w)
	player = Walker.new()
	player.centered = false
	player.look = "player"
	player.place(at)
	player.face(facing)
	_actors.add_child(player)
	Game.pos = at
	Game.facing = facing
	_ground.queue_redraw()
	_update_camera()


func _npc_hidden(n: Dictionary) -> bool:
	var f: String = n.get("flag", "")
	if n.get("kind", "") in ["item", "legend"] and f != "" and Game.flag(f):
		return true
	return Events.npc_hidden(n)


func remove_walker(w: Walker) -> void:
	walkers.erase(w)
	w.queue_free()


func find_walker(id: String) -> Walker:
	for w in walkers:
		if w.data.get("id", "") == id:
			return w
	return null


# ---------------------------------------------------------------------------
# Dessin
# ---------------------------------------------------------------------------

func _draw_ground() -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var kind: String = TILE_NAMES.get(ch, "grass")
			var frame := 0
			if kind == "water":
				frame = _water_frame
			elif kind == "flower":
				frame = (x + y) % 2
			_ground.draw_texture(PixelArt.tile(kind, frame), Vector2(x * T, y * T))


func _update_camera() -> void:
	if player == null:
		return
	var view := get_viewport_rect().size / _camera.zoom
	var mw: float = map["w"] * T
	var mh: float = map["h"] * T
	var p := player.position + Vector2(T / 2, T / 2)
	var cx := mw / 2.0 if mw <= view.x else clampf(p.x, view.x / 2, mw - view.x / 2)
	var cy := mh / 2.0 if mh <= view.y else clampf(p.y, view.y / 2, mh - view.y / 2)
	_camera.position = Vector2(roundf(cx), roundf(cy))


# ---------------------------------------------------------------------------
# Règles de déplacement
# ---------------------------------------------------------------------------

func tile_at(t: Vector2i) -> String:
	if t.y < 0 or t.y >= rows.size() or t.x < 0 or t.x >= rows[t.y].length():
		return "T"
	return rows[t.y][t.x]


func walker_at(t: Vector2i) -> Walker:
	for w in walkers:
		if w.tile == t:
			return w
	return null


func can_enter(t: Vector2i, dir: String) -> bool:
	var ch := tile_at(t)
	if _blocked.has(t):
		return false
	if not WALKABLE.contains(ch):
		return false
	if ch == "v" and dir != "down":
		return false
	if walker_at(t) != null:
		return false
	if player != null and player.tile == t:
		return false
	return true


# ---------------------------------------------------------------------------
# Boucle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_water_t += delta
	if _water_t > 0.5:
		_water_t = 0.0
		_water_frame = 1 - _water_frame
		_ground.queue_redraw()
	_update_camera()
	if busy or moving or frozen or Game.ui_busy() or player == null:
		return
	if Input.is_action_just_pressed("start"):
		_run(func(): await Events.start_menu(self))
		return
	if Input.is_action_just_pressed("a"):
		_interact()
		return
	var dir := ""
	for d in ["up", "down", "left", "right"]:
		if Input.is_action_pressed(d):
			dir = d
	if dir == "":
		_turn_t = 0.0
		return
	if dir != player.dir:
		player.face(dir)
		_turn_t = 0.08
		return
	if _turn_t > 0.0:
		_turn_t -= delta
		return
	_try_step(dir)


func _run(c: Callable) -> void:
	busy = true
	await c.call()
	busy = false


func _try_step(dir: String) -> void:
	var target: Vector2i = player.tile + DIRS[dir]
	# Porte d'un bâtiment.
	if _doors.has(target) and dir == "up":
		var b: Dictionary = _doors[target]
		if Game.maps.has(b["to"]):
			_run(func(): await _enter_building(b, target))
		else:
			_run(func(): await Game.ui.say("La porte est fermée à clé."))
		return
	if tile_at(target) == "v" and dir == "down":
		var land := target + Vector2i(0, 1)
		if can_enter(land, dir):
			_run(func(): await _jump(land))
		return
	if not can_enter(target, dir):
		return
	_run(func(): await _step(dir, target))


func _step(dir: String, target: Vector2i) -> void:
	moving = true
	var time := RUN_TIME if Input.is_action_pressed("run") else WALK_TIME
	await walk(player, dir, target, time)
	moving = false
	Game.pos = player.tile
	Game.facing = player.dir
	await _after_step()


func walk(w: Walker, dir: String, target: Vector2i, time := WALK_TIME) -> void:
	w.dir = dir
	w.step_frame = 2 if w.step_frame == 1 else 1
	w.refresh(w.step_frame)
	var tw := create_tween()
	tw.tween_property(w, "position", Vector2(target * T), time)
	w.tile = target
	await get_tree().create_timer(time * 0.5).timeout
	w.refresh(0)
	await tw.finished


func _jump(land: Vector2i) -> void:
	moving = true
	player.refresh(1)
	var start := player.position
	var end := Vector2(land * T)
	player.tile = land
	var tw := create_tween()
	tw.tween_method(func(t: float):
		player.position = start.lerp(end, t) + Vector2(0, -sin(t * PI) * 10), 0.0, 1.0, 0.35)
	await tw.finished
	player.refresh(0)
	moving = false
	Game.pos = land
	await _after_step()


func _enter_building(b: Dictionary, door: Vector2i) -> void:
	Game.return_point = {"map": map_id, "x": door.x, "y": door.y + 1}
	await warp_to(b["to"], Vector2i(b["tx"], b["ty"]), "up")


func warp_to(id: String, at: Vector2i, facing := "down") -> void:
	await Game.ui.fade(true, 0.2)
	load_map(id, at, facing)
	await Game.ui.fade(false, 0.2)


func _after_step() -> void:
	var t := player.tile
	for wp in map["warps"]:
		if wp["x"] == t.x and wp["y"] == t.y:
			await warp_to(wp["to"], Vector2i(wp["tx"], wp["ty"]), wp.get("dir", "down"))
			return
	if await Events.on_step(self):
		return
	if await _check_trainers():
		return
	if Game.repel_steps > 0:
		Game.repel_steps -= 1
		if Game.repel_steps == 0:
			await Game.ui.say("L'effet du Repousse s'est dissipé.")
	var ch := tile_at(t)
	var table := ""
	if ch == '"':
		table = "grass"
	elif ch == "w":
		table = "marsh"
	elif ch == "_" and map.get("cave", false):
		table = "cave"
	if table != "" and map["wild"].has(table) and randf() < map.get("rate", 0.1):
		await Events.wild_encounter(self, map["wild"][table])


func _check_trainers() -> bool:
	for w in walkers:
		if w.data.get("kind", "") != "trainer" or Events.trainer_beaten(map_id, w.data):
			continue
		var d: Vector2i = DIRS[w.dir]
		var t: Vector2i = w.tile
		for i in w.data.get("sight", 4):
			t += d
			if t == player.tile:
				await Events.trainer_spotted(self, w)
				return true
			if not WALKABLE.contains(tile_at(t)) or _blocked.has(t) or walker_at(t) != null:
				break
	return false


func _interact() -> void:
	var front: Vector2i = player.tile + DIRS[player.dir]
	var w := walker_at(front)
	if w == null and COUNTERS.contains(tile_at(front)):
		w = walker_at(front + DIRS[player.dir])
	if w != null:
		_run(func(): await Events.talk(self, w))
		return
	var key := "%d,%d" % [front.x, front.y]
	if map["signs"].has(key):
		_run(func(): await Events.sign(self, map["signs"][key]))
		return
	if tile_at(front) == "P":
		_run(func(): await Events.sign(self, "@pc"))


## Fait marcher un PNJ jusqu'à côté du joueur (dresseurs).
func approach(w: Walker) -> void:
	var d: Vector2i = DIRS[w.dir]
	while w.tile + d != player.tile:
		await walk(w, w.dir, w.tile + d)


func show_emote(w: Walker) -> void:
	var e := Sprite2D.new()
	e.texture = PixelArt.emote()
	e.centered = false
	e.position = Vector2(2, -15)
	w.add_child(e)
	await get_tree().create_timer(0.6).timeout
	e.queue_free()


static func opposite(d: String) -> String:
	return {"up": "down", "down": "up", "left": "right", "right": "left"}[d]
