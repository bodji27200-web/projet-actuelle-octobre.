extends Node2D
## Le monde : dessin de la carte, déplacements case par case, PNJ, portes, rencontres, autres joueurs.

const T := 16
const WALK_TIME := 0.22
const RUN_TIME := 0.12
const BIKE_TIME := 0.08
const WALKABLE := '.,"f v:w_oqmuH<>'
const COUNTERS := "CK"
const TILE_NAMES := {".": "grass", ",": "path", '"': "tall", "T": "tree", "~": "water", "f": "flower",
	"=": "fence", "S": "sign", "v": "ledge", ":": "sand", "R": "rock", "w": "marsh", "_": "cave",
	"#": "cavewall", "o": "floor", "q": "tilefloor", "W": "wall", "m": "mat", "X": "table", "B": "shelf",
	"P": "pc", "C": "counter", "K": "shopcounter", "b": "bed", "t": "tv", "p": "plant", "M": "machine", " ": "black",
	"H": "bridge", "u": "towerfloor", "O": "statue", "<": "stairs_up", ">": "stairs_down"}
const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
const THEME_TINT := {"ice": Color(0.82, 0.95, 1.25), "tower": Color(0.92, 0.82, 1.1), "volcano": Color(1.25, 0.82, 0.72),
	"rocket": Color(0.82, 0.82, 0.92), "mansion": Color(1.05, 0.9, 0.8), "forest": Color(0.8, 0.92, 0.82),
	"rock": Color(1.05, 0.95, 0.85), "water": Color(0.85, 0.95, 1.15), "electric": Color(1.1, 1.08, 0.85),
	"grass": Color(0.9, 1.1, 0.9), "poison": Color(1.0, 0.88, 1.08), "psychic": Color(1.1, 0.9, 1.0),
	"fire": Color(1.15, 0.9, 0.85), "ground": Color(1.1, 1.0, 0.85), "abyss": Color(0.62, 0.5, 0.88)}


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
## Autres joueurs (id réseau -> Walker).
var remotes := {}
var _water_frame := 0
var _water_t := 0.0
var _ground: Node2D
var _actors: Node2D
var _camera: Camera2D
var _blocked := {}
var _doors := {}
var _turn_t := 0.0
var _tint := Color.WHITE
var _bobber: Sprite2D
## Pokémon suiveur (1er Pokémon de l'équipe) : case et direction.
var follower: Follower
var _follow_species := -1
## Base secrète : décorations posées et cases qu'elles occupent.
var _decor: Array = []
var _decor_block := {}


## Petit Pokémon en pixel art qui suit un dresseur (icône officielle, sautille en marchant).
class Follower:
	extends Sprite2D
	var tile := Vector2i.ZERO
	var dir := "down"
	var sid := 0
	var shiny := false
	var _t := 0.0
	var _hop := 0.0

	func setup(p_sid: int, p_shiny: bool) -> void:
		sid = p_sid
		shiny = p_shiny
		centered = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		Sprites.apply(self, "icon", sid, false, null)
		_fit()
		if not Sprites.loaded.is_connected(_on_loaded):
			Sprites.loaded.connect(_on_loaded)

	func _on_loaded(_k: String) -> void:
		_fit()

	func _fit() -> void:
		if texture == null:
			return
		var w := texture.get_width()
		scale = Vector2.ONE * (1.0 if w <= 40 else 0.5 if w <= 72 else 0.34)

	func place(t: Vector2i) -> void:
		tile = t
		position = Vector2(t * 16) + Vector2(8, 4)

	func face(d: String) -> void:
		dir = d
		flip_h = d == "right"

	func _process(delta: float) -> void:
		_t += delta
		# Sautille doucement sur place, et plus fort en marchant.
		var bob := -1.0 if int(_t * 3.0) % 2 == 0 else 0.0
		offset.y = (bob - _hop) / maxf(scale.y, 0.01)
		_hop = maxf(0.0, _hop - delta * 20.0)
		if shiny and randi() % 90 == 0:
			modulate = Color(1.4, 1.4, 1.1)
		else:
			modulate = modulate.lerp(Color.WHITE, 0.2)

	func hop() -> void:
		_hop = 3.0


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
	Social.changed.connect(func(c: String):
		if c == "bases" and map.has("base_owner"):
			refresh_decor())


# ---------------------------------------------------------------------------
# Chargement
# ---------------------------------------------------------------------------

func load_map(id: String, at: Vector2i, facing := "down") -> void:
	map_id = id
	map = Game.maps[id]
	rows = map["rows"]
	Game.map_id = id
	if map.get("outdoor", false) and map.get("wx") != null:
		Game.last_outdoor = id
	elif Game.maps.has(map.get("region", "")):
		Game.last_outdoor = map["region"]
	if map.get("outdoor", false) == false:
		Game.on_bike = false
	_tint = THEME_TINT.get(map.get("theme", ""), Color.WHITE)
	for w in walkers:
		w.queue_free()
	walkers.clear()
	for c in _actors.get_children():
		c.queue_free()
	for c in _ground.get_children():
		c.queue_free()
	remotes.clear()
	_blocked.clear()
	_doors.clear()
	for b in map["buildings"]:
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = PixelArt.building(b["kind"], b["w"], b["h"])
		spr.position = Vector2(b["x"] * T, b["y"] * T)
		_ground.add_child(spr)
		for y in range(b["y"], b["y"] + b["h"]):
			for x in range(b["x"], b["x"] + b["w"]):
				_blocked[Vector2i(x, y)] = true
		_doors[Vector2i(b["x"] + b["w"] / 2, b["y"] + b["h"] - 1)] = b
	for n in map["npcs"]:
		if npc_hidden(n):
			continue
		var w := Walker.new()
		w.centered = false
		w.look = n["look"]
		w.data = n
		w.place(Vector2i(n["x"], n["y"]))
		if n["look"] == "legend":
			if int(n.get("species", 0)) > 0:
				w.scale = Vector2(0.4, 0.4)
				w.offset = Vector2(-28, -40)
				Sprites.apply(w, "front", n["species"], false, PixelArt.placeholder())
		w.face(n.get("dir", "down"))
		_actors.add_child(w)
		walkers.append(w)
	_decor.clear()
	refresh_decor()
	at = _safe_spot(at)
	player = Walker.new()
	player.centered = false
	player.look = Game.look()
	player.place(at)
	player.face(facing)
	_actors.add_child(player)
	follower = null
	_follow_species = -1
	refresh_player_look()
	if follower != null:
		var back: Vector2i = at - DIRS[facing]
		follower.place(back if can_enter(back, facing) else at)
		follower.face(facing)
	Game.pos = at
	Game.facing = facing
	_ground.queue_redraw()
	_update_camera()
	Audio.play_music(map.get("music", "route"))
	if has_node("/root/Net"):
		Net.send_state()


func npc_hidden(n: Dictionary) -> bool:
	var f: String = n.get("flag", "")
	if n.get("kind", "") in ["item", "legend"] and f != "" and Game.flag(f):
		return true
	if Game.flag("hidden_%s_%s" % [map_id, n["id"]]):
		return true
	if n.has("hide_if") and Game.check(n["hide_if"]):
		return true
	return Events.npc_hidden(n)


func refresh_player_look() -> void:
	if player == null:
		return
	player.look = Game.look()
	player.refresh(0)
	set_name_tag(player, Game.player_name, Game.title)
	_update_follower()


## Nom du dresseur et, juste en dessous, son titre (au-dessus de la tête).
func set_name_tag(w: Node2D, pname: String, title_id: String) -> void:
	var tag: Node2D = w.get_node_or_null("Tag")
	if not Game.settings.get("names", true):
		if tag != null:
			tag.queue_free()
		return
	if tag == null:
		tag = Node2D.new()
		tag.name = "Tag"
		tag.z_index = 5
		for k in 2:
			var lbl := Label.new()
			lbl.name = ["Nom", "Titre"][k]
			lbl.position = Vector2(-52, -25 + k * 9)
			lbl.size = Vector2(120, 10)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color.WHITE if k == 0 else Color("f8d048"))
			lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl.add_theme_constant_override("outline_size", 3)
			tag.add_child(lbl)
		w.add_child(tag)
	tag.get_node("Nom").text = pname
	tag.get_node("Titre").text = Profile.title_name(title_id) if title_id != "" else ""


## Le Pokémon suiveur : le premier Pokémon de l'équipe encore debout (pas un Œuf).
func lead_follower() -> Pokemon:
	if not Game.settings.get("follower", true):
		return null
	for m in Game.party:
		if not m.is_egg and m.hp > 0:
			return m
	return null


func _update_follower() -> void:
	var m := lead_follower()
	var sid := -1 if m == null else m.sprite_id() * (2 if m.shiny else 1)
	if sid == _follow_species and (follower != null) == (m != null):
		return
	_follow_species = sid
	var at: Vector2i = player.tile - DIRS[player.dir]
	var d := player.dir
	if follower != null:
		at = follower.tile
		d = follower.dir
		follower.queue_free()
		follower = null
	if m == null:
		Net.send_state()
		return
	follower = Follower.new()
	follower.setup(m.sprite_id(), m.shiny)
	follower.place(at if can_enter(at, d) or at == player.tile else player.tile)
	follower.face(d)
	_actors.add_child(follower)
	Net.send_state()


## Le suiveur prend la place que le joueur vient de quitter.
func _follow(from: Vector2i, time: float) -> void:
	if follower == null:
		return
	var d := follower.dir
	var delta := from - follower.tile
	for k in DIRS:
		if DIRS[k] == delta:
			d = k
	follower.face(d)
	follower.hop()
	if absi(delta.x) + absi(delta.y) > 1:
		follower.place(from)
		return
	follower.tile = from
	var tw := create_tween()
	tw.tween_property(follower, "position", Vector2(from * T) + Vector2(8, 4), time)


## Case d'arrivée praticable : si la case demandée est bloquée (vieille sauvegarde, carte régénérée),
## la case libre la plus proche.
func _safe_spot(at: Vector2i) -> Vector2i:
	var free := func(p: Vector2i) -> bool:
		return p.y >= 0 and p.y < rows.size() and p.x >= 0 and p.x < rows[p.y].length() \
			and WALKABLE.contains(tile_at(p)) and not _blocked.has(p) and walker_at(p) == null
	if free.call(at):
		return at
	for r in range(1, 40):
		for dy in range(-r, r + 1):
			for dx in [-(r - absi(dy)), r - absi(dy)]:
				var p := at + Vector2i(dx, dy)
				if free.call(p):
					return p
	return at


func remove_walker(w: Walker) -> void:
	walkers.erase(w)
	# Caché tout de suite, libéré au prochain changement de carte : le script qui le retire (boss vaincu,
	# légendaire capturé...) continue après et y fait encore référence.
	w.visible = false


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
			if kind == "rock" and map.get("cave", false):
				kind = "rock_cave"
			var frame := 0
			if kind == "water" or kind == "bridge":
				frame = _water_frame if kind == "water" else 0
			elif kind == "flower":
				frame = (x + y) % 2
			_ground.draw_texture(PixelArt.tile(kind, frame), Vector2(x * T, y * T), _tint)


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
	if _blocked.has(t) or _decor_block.has(t):
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
	_update_remotes(delta)
	if player != null and not moving:
		_update_follower()
	if busy or moving or frozen or Game.ui_busy() or player == null:
		return
	if Input.is_action_just_pressed("start"):
		_run(func(): await Events.start_menu(self))
		return
	if Input.is_action_just_pressed("map"):
		_run(func(): await Game.ui.open(WorldMapScreen.new()))
		return
	if Input.is_action_just_pressed("chat") and has_node("/root/Net") and Net.online():
		_run(func(): await Events.chat())
		return
	if Input.is_action_just_pressed("bike") and Game.item_count("bicycle") > 0:
		if map.get("outdoor", false):
			Game.on_bike = not Game.on_bike
			Audio.sfx("select")
		else:
			_run(func(): await Game.ui.say("Ce n'est pas le moment de faire du vélo !"))
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
		if has_node("/root/Net"):
			Net.send_state()
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
	if _doors.has(target) and dir == "up":
		var b: Dictionary = _doors[target]
		if not Game.maps.has(b["to"]):
			_run(func(): await Game.ui.say("La porte est fermée à clé."))
		elif b.has("require") and not Game.check(b["require"]):
			_run(func(): await Game.ui.say(b.get("locked", "La porte est fermée à clé.")))
		else:
			_run(func(): await _enter_building(b, target))
		return
	if tile_at(target) == "v" and dir == "down":
		var land := target + Vector2i(0, 1)
		if can_enter(land, dir):
			_run(func(): await _jump(land))
		return
	if not can_enter(target, dir):
		if not Game.ui_busy():
			Audio.sfx("bump", 0.4)
		return
	_run(func(): await _step(dir, target))


func _step(dir: String, target: Vector2i) -> void:
	moving = true
	var time := WALK_TIME
	if Game.on_bike:
		time = BIKE_TIME
	elif Input.is_action_pressed("run"):
		time = RUN_TIME
	_follow(player.tile, time)
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
	if w == player:
		Net.send_state()
	await get_tree().create_timer(time * 0.5).timeout
	if is_instance_valid(w):
		w.refresh(0)
	await tw.finished


func _jump(land: Vector2i) -> void:
	moving = true
	player.refresh(1)
	Audio.sfx("jump")
	var start := player.position
	var end := Vector2(land * T)
	if follower != null:
		follower.place(land - Vector2i(0, 1))
		follower.face("down")
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
	Audio.sfx("door")
	await warp_to(b["to"], Vector2i(b["tx"], b["ty"]), "up")


func warp_to(id: String, at: Vector2i, facing := "down") -> void:
	await Game.ui.fade(true, 0.2)
	load_map(id, at, facing)
	await Game.ui.fade(false, 0.2)


func _after_step() -> void:
	var t := player.tile
	for wp in map["warps"]:
		if wp["x"] == t.x and wp["y"] == t.y:
			Audio.sfx("door")
			if wp["to"] == "@return":
				var rp: Dictionary = Game.return_point
				await warp_to(rp.get("map", Game.last_outdoor), Vector2i(rp.get("x", 5), rp.get("y", 5)), "down")
				return
			await warp_to(wp["to"], Vector2i(wp["tx"], wp["ty"]), wp.get("dir", "down"))
			return
	for egg in Game.on_step():
		await Events.hatch(egg)
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
	elif ch in "_uq" and (map.get("cave", false) or not map.get("outdoor", true)):
		# Grottes, mais aussi tours, manoirs et repaires : on y croise des Pokémon partout sur le sol.
		table = "grass" if map["wild"].has("grass") else "cave"
	# Pas d'« await » dans une condition « and » : il ferait perdre une image même quand la condition est fausse.
	if table != "" and map.has("rare"):
		if await Campaign.rare_check(self):
			return
	# Rune Purifiante tenue par le premier Pokémon : un tiers de rencontres en moins.
	var rate: float = map.get("rate", 0.1) * (0.67 if Game.lead() != null and Game.lead().held_item == "cleanse-tag" else 1.0)
	if table != "" and map["wild"].has(table) and randf() < rate:
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
	for pid in remotes:
		if remotes[pid].tile == front:
			_run(func(): await Events.talk_player(pid))
			return
	if follower != null and follower.tile == front and lead_follower() != null:
		_run(func(): await Events.talk_follower(lead_follower()))
		return
	var key := "%d,%d" % [front.x, front.y]
	if map["signs"].has(key):
		_run(func(): await Events.sign(self, map["signs"][key]))
		return
	if tile_at(front) == "P":
		_run(func(): await Events.sign(self, "@pc"))
	elif Events.water_ahead(self) and not Events.owned_rods().is_empty():
		_run(func(): await Events.fish_prompt(self))


## Décorations de la base secrète (redessinées quand quelqu'un décore).
func refresh_decor() -> void:
	for n in _decor:
		if is_instance_valid(n):
			n.queue_free()
	_decor.clear()
	_decor_block.clear()
	var owner: String = map.get("base_owner", "")
	if owner == "":
		return
	for it in Social.base(owner).get("items", []):
		var id: String = it["id"]
		var at := Vector2i(int(it["x"]), int(it["y"]))
		var node := Decor.make_node(id)
		node.position = Vector2(at * T)
		if Decor.blocks(id):
			_actors.add_child(node)
			_decor_block[at] = true
		else:
			_ground.add_child(node)
		_decor.append(node)


## Case de la base où l'on peut poser une décoration.
func base_free(t: Vector2i) -> bool:
	if not map.has("base_owner") or not tile_at(t) in ["o", "q"] or _decor_block.has(t) or walker_at(t) != null:
		return false
	for it in Social.base(map["base_owner"]).get("items", []):
		if int(it["x"]) == t.x and int(it["y"]) == t.y:
			return false
	for wp in map["warps"]:
		if wp["x"] == t.x and (wp["y"] == t.y or wp["y"] == t.y + 1):
			return false
	return t != player.tile


func front_tile() -> Vector2i:
	return player.tile + DIRS[player.dir]


## Bouchon de pêche sur la case d'eau devant le joueur : "cast" (flotte), "bite" (plonge), "" (retiré).
func fish_bobber(state: String) -> void:
	if _bobber != null and is_instance_valid(_bobber):
		_bobber.queue_free()
	_bobber = null
	if state == "":
		return
	var front := front_tile()
	_bobber = Sprite2D.new()
	_bobber.texture = PixelArt.bobber()
	_bobber.centered = false
	var base := Vector2(front.x * T + 4, front.y * T + 4)
	_bobber.position = base + (Vector2(0, 3) if state == "bite" else Vector2.ZERO)
	_actors.add_child(_bobber)
	# Ligne tendue entre la main du joueur et le bouchon.
	var hand: Vector2 = player.position + {"down": Vector2(13, 10), "up": Vector2(3, 6), "left": Vector2(1, 9), "right": Vector2(15, 9)}[player.dir]
	var line := Line2D.new()
	line.width = 1.0
	line.default_color = Color(0.12, 0.12, 0.12, 0.75)
	line.points = PackedVector2Array([hand - _bobber.position, Vector2(4, 1)])
	line.show_behind_parent = true
	_bobber.add_child(line)
	if state == "cast":
		var tw := _bobber.create_tween().set_loops()
		tw.tween_property(_bobber, "position:y", base.y + 1, 0.35)
		tw.tween_property(_bobber, "position:y", base.y, 0.35)


## Fait marcher un PNJ jusqu'à côté du joueur (dresseurs).
func approach(w: Walker) -> void:
	var d: Vector2i = DIRS[w.dir]
	while w.tile + d != player.tile:
		await walk(w, w.dir, w.tile + d)


func show_emote(w: Node2D) -> void:
	var e := Sprite2D.new()
	e.texture = PixelArt.emote()
	e.centered = false
	e.position = Vector2(2, -15)
	w.add_child(e)
	Audio.sfx("alert")
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(e):
		e.queue_free()


static func opposite(d: String) -> String:
	return {"up": "down", "down": "up", "left": "right", "right": "left"}[d]


# ---------------------------------------------------------------------------
# Autres joueurs (multijoueur)
# ---------------------------------------------------------------------------

func remote_update(pid: int, st: Dictionary) -> void:
	if player == null:
		return
	if st.get("map", "") != map_id:
		remote_leave(pid)
		return
	var w: Walker
	if not remotes.has(pid):
		w = Walker.new()
		w.centered = false
		w.place(Vector2i(st["x"], st["y"]))
		_actors.add_child(w)
		remotes[pid] = w
	w = remotes[pid]
	var old_tile := w.tile
	w.look = st.get("look", "boy_classique")
	w.dir = st.get("dir", "down")
	w.tile = Vector2i(st["x"], st["y"])
	w.set_meta("target", Vector2(w.tile * T))
	w.refresh(0)
	set_name_tag(w, st.get("name", "?") + (" ★" if st.get("group", false) else ""), st.get("title", ""))
	# Son Pokémon suiveur.
	var fl: Array = st.get("follow", [])
	var rf: Follower = w.get_meta("follower") if w.has_meta("follower") else null
	if rf != null and (fl.is_empty() or rf.sid != int(fl[0]) or rf.shiny != bool(fl[1]) or not Game.settings.get("follower", true)):
		rf.queue_free()
		rf = null
		w.remove_meta("follower")
	if rf == null and not fl.is_empty() and Game.settings.get("follower", true):
		rf = Follower.new()
		rf.setup(int(fl[0]), bool(fl[1]))
		rf.place(w.tile - DIRS.get(w.dir, Vector2i.ZERO))
		rf.face(w.dir)
		_actors.add_child(rf)
		w.set_meta("follower", rf)
	if rf != null and old_tile != w.tile:
		var gap: Vector2i = old_tile - rf.tile
		for k in DIRS:
			if DIRS[k] == gap:
				rf.face(k)
		rf.hop()
		if (w.tile - old_tile).length() > 1.5:
			rf.place(w.tile - DIRS.get(w.dir, Vector2i.ZERO))
		else:
			rf.tile = old_tile
			var tw := rf.create_tween()
			tw.tween_property(rf, "position", Vector2(old_tile * T) + Vector2(8, 4), 0.18)


func remote_leave(pid: int) -> void:
	if remotes.has(pid):
		if remotes[pid].has_meta("follower"):
			remotes[pid].get_meta("follower").queue_free()
		remotes[pid].queue_free()
		remotes.erase(pid)


func _update_remotes(delta: float) -> void:
	for pid in remotes:
		var w: Walker = remotes[pid]
		var target: Vector2 = w.get_meta("target", w.position)
		if w.position.distance_to(target) > 0.5:
			w.position = w.position.move_toward(target, delta * 90.0)
			w.refresh(1 if int(Time.get_ticks_msec() / 150) % 2 == 0 else 2)
		elif w.position != target:
			w.position = target
			w.refresh(0)
