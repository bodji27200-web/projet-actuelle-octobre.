extends Node
## Route 1 dans le style de Pokémon Revolution Online : déplacement case par case, Reptincel qui suit,
## un autre joueur (Jeremy), hautes herbes, rebords, panneau, feuilles qui tombent, cycle jour / nuit
## sur l'heure Poké, et toute l'interface de PRO (voir hud.gd).
## Touches : flèches ou ZQSD, Maj pour courir, Espace / E pour parler, Entrée pour discuter, F2 avance l'heure Poké.

const T := 32
const WALK := 0.25
const RUN := 0.13
const ZOOM := 2.25
## Heure Poké : 4 fois plus rapide que l'heure locale (décalage choisi pour retrouver la capture : 16:46 -> 01:50).
const POKE_SPEED := 4
const POKE_OFFSET := 406

var data: Dictionary
var rows: Array
var world: Node2D
var ysort: Node2D
var cam: Camera2D
var player: Character
var follower: Character
var jeremy: Character
var hud: Hud
var tint: CanvasModulate
var leaves: CPUParticles2D
var leaves_layer: CanvasLayer
var tufts := {}
var busy := false
var time_shift := 0
var _jeremy_timer := 2.0
var _held := ""
var _turn_wait := 0.0


func _ready() -> void:
	_inputs()
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/route1.json"))
	rows = data["rows"]
	world = Node2D.new()
	add_child(world)
	tint = CanvasModulate.new()
	add_child(tint)
	var ground := Sprite2D.new()
	ground.texture = load("res://assets/world/route1_ground.png")
	ground.centered = false
	world.add_child(ground)
	var under := Node2D.new()
	world.add_child(under)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	world.add_child(ysort)
	# Hautes herbes : la touffe entière au sol, et sa moitié basse par-dessus les personnages (jambes cachées).
	for g in data["grass"]:
		var tex: Texture2D = load("res://assets/" + g["tex"])
		var w := tex.get_width()
		var h := tex.get_height()
		var base := Sprite2D.new()
		base.texture = tex
		base.centered = false
		base.offset = Vector2(-w / 2, -h)
		base.position = Vector2(g["x"], g["y"])
		under.add_child(base)
		var top := Sprite2D.new()
		top.texture = tex
		top.region_enabled = true
		var hh := h / 2 + 1
		top.region_rect = Rect2(0, h - hh, w, hh)
		top.centered = false
		top.offset = Vector2(-w / 2, -hh)
		top.position = Vector2(g["x"], g["y"])
		ysort.add_child(top)
		tufts[Vector2i(int(g["x"]) / T, int(g["y"] - 2) / T)] = [base, top]
	for o in data["objects"]:
		var tex2: Texture2D = load("res://assets/" + o["tex"])
		var s := Sprite2D.new()
		s.texture = tex2
		s.centered = false
		s.offset = Vector2(-tex2.get_width() / 2, -tex2.get_height())
		s.position = Vector2(o["x"], o["y"])
		ysort.add_child(s)
	var start := Vector2i(int(data["start"][0]), int(data["start"][1]))
	player = Character.new()
	player.setup(load("res://assets/chars/player.png"), 24, 32, 4, 30)
	player.dir = "up"
	player.place(start)
	ysort.add_child(player)
	follower = Character.new()
	follower.setup(load("res://assets/chars/charmeleon.png"), 32, 32, 2, 29)
	follower.sprite.scale = Vector2(0.8, 0.8)  # dans PRO, le Pokémon qui suit est plus petit que le dresseur
	follower.dir = "up"
	follower.place(start + Vector2i(0, 1))
	ysort.add_child(follower)
	_anim_follower_idle()
	jeremy = Character.new()
	jeremy.setup(load("res://assets/chars/jeremy.png"), 24, 32, 4, 30)
	jeremy.place(Vector2i(int(data["jeremy"][0]), int(data["jeremy"][1])))
	jeremy.face("left")
	ysort.add_child(jeremy)
	player.face("up")
	follower.face("up")
	cam = Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(data["w"]) * T
	cam.limit_bottom = int(data["h"]) * T
	cam.position = Vector2(0, -12)
	player.add_child(cam)
	cam.make_current()
	_build_leaves()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.set_location(data["name"])
	hud.menu_pressed.connect(func(what: String): hud.toast({"pvp": "PvP : bientôt disponible", "backpack": "Sac : bientôt disponible",
		"pokedex": "Pokédex : bientôt disponible", "trainer": "Carte Dresseur : bientôt disponible", "social": "Social : bientôt disponible",
		"carte": "Carte : bientôt disponible", "sac": "Boutique : bientôt disponible", "menu": "Menu : bientôt disponible"}.get(what, what)))
	_update_time()
	_maybe_screenshot()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_time)
	add_child(timer)


func _inputs() -> void:
	var keys := {"up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S], "left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D],
		"run": [KEY_SHIFT], "talk": [KEY_SPACE, KEY_E], "chat": [KEY_ENTER, KEY_KP_ENTER], "time": [KEY_F2]}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k  # position de la touche : ZQSD sur un clavier AZERTY
			InputMap.action_add_event(a, e)


# ---------------------------------------------------------------------------------------------------------------
# Heure locale / heure Poké, teinte du monde
# ---------------------------------------------------------------------------------------------------------------

func poke_minutes() -> float:
	var t := Time.get_time_dict_from_system()
	var local: float = t["hour"] * 60.0 + t["minute"] + t["second"] / 60.0
	return fposmod(local * POKE_SPEED + POKE_OFFSET + time_shift, 1440.0)


func _update_time() -> void:
	var t := Time.get_time_dict_from_system()
	var pm := poke_minutes()
	var night := pm < 6 * 60 or pm >= 20 * 60
	hud.set_times("%02d:%02d" % [t["hour"], t["minute"]], "%02d:%02d" % [int(pm / 60), int(pm) % 60], night)
	var c := _tint_at(pm / 60.0)
	tint.color = c
	leaves_layer.get_child(0).modulate = Color(1, 1, 1).lerp(c, 0.55)


func _tint_at(h: float) -> Color:
	var keys := [[0.0, Color(0.30, 0.33, 0.56)], [5.0, Color(0.30, 0.33, 0.56)], [7.0, Color(0.92, 0.84, 0.82)],
		[10.0, Color(1, 1, 1)], [17.0, Color(1, 1, 1)], [19.0, Color(0.96, 0.74, 0.62)], [20.5, Color(0.30, 0.33, 0.56)],
		[24.0, Color(0.30, 0.33, 0.56)]]
	for i in keys.size() - 1:
		if h >= keys[i][0] and h <= keys[i + 1][0]:
			var k: float = (h - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
			return (keys[i][1] as Color).lerp(keys[i + 1][1], k)
	return Color.WHITE


func _build_leaves() -> void:
	leaves_layer = CanvasLayer.new()
	leaves_layer.layer = 5
	add_child(leaves_layer)
	leaves = CPUParticles2D.new()
	leaves.texture = load("res://assets/world/leaf.png")
	leaves.amount = 16
	leaves.lifetime = 11.0
	leaves.preprocess = 11.0
	leaves.position = Vector2(1100, -40)
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(1100, 20)
	leaves.direction = Vector2(-0.45, 1)
	leaves.spread = 12.0
	leaves.gravity = Vector2(0, 6)
	leaves.initial_velocity_min = 55.0
	leaves.initial_velocity_max = 95.0
	leaves.angular_velocity_min = -90.0
	leaves.angular_velocity_max = 90.0
	leaves.angle_min = 0.0
	leaves.angle_max = 360.0
	leaves.scale_amount_min = 2.0
	leaves.scale_amount_max = 2.4
	leaves.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leaves_layer.add_child(leaves)


# ---------------------------------------------------------------------------------------------------------------
# Déplacements
# ---------------------------------------------------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("chat") and not hud.chat_focused():
		hud.focus_chat()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("talk") and not hud.chat_focused():
		if hud.dialog_open():
			hud.hide_dialog()
			busy = false
		elif not busy and not player.moving:
			_talk()
	elif e.is_action_pressed("time"):
		time_shift += 180
		_update_time()
		hud.toast("Heure Poké avancée de 3 heures")
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE and hud.chat_focused():
		hud.get_viewport().gui_release_focus()


func _process(delta: float) -> void:
	_update_tag()
	_wander_jeremy(delta)
	if busy or player.moving or hud.chat_focused() or hud.dialog_open():
		return
	var d := ""
	for a in ["up", "down", "left", "right"]:
		if Input.is_action_pressed(a):
			d = a
	if d == "":
		_held = ""
		return
	# Un appui bref tourne le personnage ; maintenir la touche le fait marcher.
	if d != player.dir and _held != d:
		player.face(d)
		_held = d
		_turn_wait = 0.09
		return
	if _turn_wait > 0.0:
		_turn_wait -= delta
		return
	_held = d
	_try_move(d)


func _cell(t: Vector2i) -> String:
	if t.y < 0 or t.y >= rows.size() or t.x < 0 or t.x >= String(rows[0]).length():
		return "#"
	return String(rows[t.y])[t.x]


func _try_move(d: String) -> void:
	var step: Vector2i = Character.DIRS[d]
	var to := player.tile + step
	var c := _cell(to)
	var jump := false
	if to.y <= 0 or to.y >= rows.size() - 1:
		busy = true
		hud.toast("Bourg Palette : bientôt disponible" if to.y > 0 else "Jadielle : bientôt disponible")
		await get_tree().create_timer(0.4).timeout
		busy = false
		return
	if c == "=":
		if d != "down" or _cell(to + step) in ["#", "X", "="]:
			return
		to += step
		jump = true
	elif c in ["#", "X"] or to == jeremy.tile:
		return
	var old := player.tile
	var t := RUN if Input.is_action_pressed("run") else WALK
	if jump:
		t = 0.42
	_follow(old, t)
	await player.walk_to(to, t, jump)
	_rustle(to)


func _follow(target: Vector2i, t: float) -> void:
	var diff := target - follower.tile
	if diff == Vector2i.ZERO:
		return
	follower.face("down" if diff.y > 0 else "up" if diff.y < 0 else "right" if diff.x > 0 else "left")
	follower.walk_to(target, t, abs(diff.x) + abs(diff.y) > 1)


func _rustle(t: Vector2i) -> void:
	if not tufts.has(t):
		return
	for s in tufts[t]:
		var tw := create_tween()
		tw.tween_property(s, "scale", Vector2(1.12, 0.9), 0.08)
		tw.tween_property(s, "scale", Vector2(1, 1), 0.12)


func _anim_follower_idle() -> void:
	# Le Pokémon qui suit piétine sur place, comme dans PRO.
	var timer := Timer.new()
	timer.wait_time = 0.45
	timer.autostart = true
	var flip := [false]
	timer.timeout.connect(func():
		if not follower.moving:
			flip[0] = not flip[0]
			follower.sprite.frame = Character.ROWS[follower.dir] * 2 + (1 if flip[0] else 0))
	add_child(timer)


func _talk() -> void:
	var front: Vector2i = player.tile + Character.DIRS[player.dir]
	var sign: Dictionary = data["sign"]
	if front == Vector2i(int(sign["x"]), int(sign["y"])):
		busy = true
		hud.show_dialog(sign["text"])
	elif front == jeremy.tile:
		busy = true
		jeremy.face({"up": "down", "down": "up", "left": "right", "right": "left"}[player.dir])
		hud.show_dialog("Jeremy : Salut ! Les Roucool sortent surtout le matin. La nuit, c'est plein de Rattata ici !")
	elif front == follower.tile:
		busy = true
		follower.face({"up": "down", "down": "up", "left": "right", "right": "left"}[player.dir])
		hud.show_dialog("Charmeleon a l'air de bonne humeur. Sa flamme brûle fort !")


# ---------------------------------------------------------------------------------------------------------------
# L'autre joueur : se promène et porte son nom au-dessus de la tête
# ---------------------------------------------------------------------------------------------------------------

func _wander_jeremy(delta: float) -> void:
	_jeremy_timer -= delta
	if _jeremy_timer > 0.0 or jeremy.moving or busy:
		return
	_jeremy_timer = randf_range(1.2, 3.5)
	var d: String = ["up", "down", "left", "right"][randi() % 4]
	var to: Vector2i = jeremy.tile + Character.DIRS[d]
	jeremy.face(d)
	if randf() < 0.35:
		return
	var home := Vector2i(int(data["jeremy"][0]), int(data["jeremy"][1]))
	if _cell(to) in ["#", "X", "="] or to == player.tile or to == follower.tile or (to - home).length() > 4.0:
		return
	jeremy.walk_to(to, WALK)


func _update_tag() -> void:
	var vp := get_viewport().get_visible_rect().size
	var head := jeremy.global_position + Vector2(0, -36) + Vector2(0, jeremy.sprite.position.y)
	var screen := (head - cam.get_screen_center_position()) * ZOOM + vp / 2
	hud.set_tag("jeremy", "Jeremy", screen)


## Pour les tests : godot --path pro -- shot=capture.png [time=+N] [walk=updownleft...]
func _maybe_screenshot() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			path = a.substr(5)
		elif a.begins_with("time="):
			time_shift = int(a.substr(5))
			_update_time()
		elif a.begins_with("chat="):
			hud.add_chat("Local", "%s: %s" % [hud.player_name, a.substr(5)])
	if path == "":
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("walk="):
			for ch in a.substr(5).split(","):
				if ch == "":
					continue
				await get_tree().create_timer(0.05).timeout
				player.face(ch)
				await _try_move(ch)
	for k in 40:
		await get_tree().process_frame
	print("case du joueur : ", player.tile, ", du suiveur : ", follower.tile)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
