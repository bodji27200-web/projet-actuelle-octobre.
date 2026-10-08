extends Node
## Robot joueur : enchaîne le début du jeu en simulant les touches.

var main: Node
var frame := 0
var log_t := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run()


func _process(_d: float) -> void:
	frame += 1
	if frame % 1200 == 0 and Game.world != null and Game.world.player != null:
		var t := _top()
		var info := ""
		if t is TextBox:
			info = str(t.pages)
		print("   [veille] ", _where(), " haut=", t.get_script().resource_path.get_file() if t and t.get_script() else str(t), " ", info.left(120))


func _tap(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame


func _enter() -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_ENTER
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().process_frame
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)
	await get_tree().process_frame


func _top() -> Node:
	return Game._stack[-1] if not Game._stack.is_empty() else null


## Appuie sur A (ou Entrée pour les noms) jusqu'à ce que cond() soit vrai.
func _mash(cond: Callable, limit := 3000) -> bool:
	for i in limit:
		if cond.call():
			return true
		var t := _top()
		if t is NameEntry:
			await _enter()
		elif t is TextBox:
			await _tap("a")
		elif t != null:
			await _tap(["a", "a", "a", "down", "right", "up", "b"][randi() % 7])
		else:
			await get_tree().process_frame
	return false


func _idle() -> bool:
	return Game.world != null and Game.world.player != null and not Game.ui_busy() and not Game.world.busy and not Game.world.moving


func _walk(dir: String, n: int) -> void:
	for i in n:
		await _mash(_idle)
		var e := InputEventAction.new()
		e.action = dir
		e.pressed = true
		Input.parse_input_event(e)
		for f in 30:
			await get_tree().process_frame
			if Game.world.moving or Game.ui_busy():
				break
		var r := InputEventAction.new()
		r.action = dir
		r.pressed = false
		Input.parse_input_event(r)
		await _mash(_idle)


## Va jusqu'à une case (recherche de chemin), en traversant combats et dialogues.
func _goto(target: Vector2i) -> void:
	var start_map: String = Game.world.map_id
	for attempt in 200:
		await _mash(_idle)
		if Game.world.map_id != start_map or Game.world.player.tile == target:
			return
		var path := _path(Game.world.player.tile, target)
		if path.is_empty():
			print("   !! pas de chemin vers ", target, " depuis ", _where())
			return
		await _walk(path[0], 1)


func _path(from: Vector2i, to: Vector2i) -> Array:
	var w = Game.world
	var dirs := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
	var prev := {from: null}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			break
		for d in dirs:
			var n: Vector2i = c + dirs[d]
			if prev.has(n):
				continue
			var ok: bool = w.can_enter(n, d) or (n == to and (w._doors.has(n) or w.tile_at(n) in ",m_.H"))
			if w.tile_at(n) == "v":
				ok = false
			if ok:
				prev[n] = [c, d]
				q.append(n)
	if not prev.has(to):
		return []
	var out := []
	var c2 = to
	while prev[c2] != null:
		out.push_front(prev[c2][1])
		c2 = prev[c2][0]
	return out


func _find_tile(ch: String) -> Vector2i:
	var rows: Array = Game.world.rows
	var p: Vector2i = Game.world.player.tile
	var best := Vector2i(-1, -1)
	var bd := 99999
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == ch and rows[y].length() > x + 1 and rows[y][x + 1] == ch:
				var d := absi(x - p.x) + absi(y - p.y)
				if d < bd and not _path(p, Vector2i(x, y)).is_empty():
					bd = d
					best = Vector2i(x, y)
	return best


func _where() -> String:
	return "%s %s" % [Game.world.map_id, Game.world.player.tile if Game.world.player else "-"]


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	print("1. titre + intro")
	await _mash(_idle)
	print("   -> ", _where(), " nom=", Game.player_name)
	print("2. sortir de la maison")
	await _walk("down", 4)
	print("   -> ", _where())
	print("3. aller au nord (Chen)")
	await _walk("right", 5)
	await _walk("up", 4)
	print("   -> ", _where(), " lab_intro=", Game.flag("lab_intro"))
	print("4. choisir Salamèche")
	await _walk("right", 2)
	await _walk("up", 3)
	await _walk("up", 1)
	print("   pos ", _where())
	await _tap("a")
	await _mash(func(): return Game.flag("has_dex") and _idle(), 20000)
	print("   -> starter=", Game.starter, " équipe=", Game.party.map(func(m): return "%s N.%d PV %d/%d" % [m.name(), m.level, m.hp, m.max_hp()]))
	print("   sac=", Game.bag, " argent=", Game.money)
	var strong := Pokemon.create(6, 40)
	Game.party.push_front(strong)
	print("5. route 1 et hautes herbes")
	await _goto(Vector2i(6, 10))
	print("   -> ", _where())
	var r1: Dictionary = Game.maps["r1"]
	await _goto(Vector2i(10, 0))
	print("   -> ", _where())
	var grass := _find_tile('"')
	var seen0 := Game.seen.size()
	for i in 20:
		await _goto(grass)
		await _goto(grass + Vector2i(1, 0))
	print("   -> ", _where(), " vus=", Game.seen.size() - seen0, " nouveaux, équipe=", Game.party.map(func(m): return "%s N.%d PV %d/%d" % [m.name(), m.level, m.hp, m.max_hp()]))
	print("5b. Jadielle et Centre Pokémon")
	if Game.world.map_id != "r1":
		await _goto(Vector2i(10, 0))
	for k in 3:
		if Game.world.map_id == "jadielle":
			break
		var top := Vector2i(-1, -1)
		for wp in Game.world.map["warps"]:
			if wp["to"] == "jadielle":
				top = Vector2i(wp["x"], wp["y"])
		await _goto(top)
	print("   -> ", _where())
	var door := Vector2i.ZERO
	for b in Game.maps["jadielle"]["buildings"]:
		if b["to"] == "centre_jadielle":
			door = Vector2i(b["x"] + b["w"] / 2, b["y"] + b["h"] - 1)
	await _goto(door)
	print("   -> ", _where())
	await _goto(Vector2i(6, 4))
	await _walk("up", 1)
	await _tap("a")
	await _mash(_idle)
	print("   soigné : ", Game.party.map(func(m): return "%d/%d" % [m.hp, m.max_hp()]), " heal=", Game.heal_point)
	await _goto(Vector2i(6, 7))
	print("   -> ", _where())
	print("5c. colis du vendeur")
	var mart := Vector2i.ZERO
	for b in Game.maps["jadielle"]["buildings"]:
		if b["to"] == "boutique_jadielle":
			mart = Vector2i(b["x"] + b["w"] / 2, b["y"] + b["h"] - 1)
	await _goto(mart)
	await _goto(Vector2i(2, 4))
	await _walk("up", 1)
	await _tap("a")
	await _mash(_idle)
	print("   colis : ", Game.item_count("oaks-parcel"), " quête=", Game.quests.get("main"))
	print("6. menu Start")
	await _tap("start")
	await get_tree().create_timer(0.2).timeout
	print("   top=", _top())
	await _tap("b")
	await _mash(_idle)
	Game.save_game()
	print("FIN DU TEST ", _where())
	get_tree().quit()
