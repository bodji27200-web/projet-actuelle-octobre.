extends Node2D
## Jeu d'arcade : ramasse les pièces jaunes, évite les boules rouges.
## Déplacement : flèches ou ZQSD/WASD. Rejouer : Entrée ou R.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const CoinScript := preload("res://scripts/coin.gd")

const SAFE_SPAWN_DISTANCE := 200.0

var bounds := Rect2()
var player: Node2D
var coin: Node2D
var enemies: Array[Node2D] = []
var score := 0
var best := 0
var is_game_over := false
var spawn_timer := 0.0

var hud: Label
var message: Label


func _ready() -> void:
	_setup_inputs()
	bounds = Rect2(Vector2.ZERO, get_viewport_rect().size)

	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 24)
	ui.add_child(hud)
	message = Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 40)
	ui.add_child(message)

	_start()


func _setup_inputs() -> void:
	var bindings := {
		"move_left": [KEY_LEFT, KEY_A, KEY_Q],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W, KEY_Z],
		"move_down": [KEY_DOWN, KEY_S],
		"restart": [KEY_ENTER, KEY_R],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)


func _start() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	if player:
		player.queue_free()
	if coin:
		coin.queue_free()

	score = 0
	spawn_timer = 0.0
	is_game_over = false
	message.text = ""

	player = PlayerScript.new()
	player.bounds = bounds
	player.position = bounds.get_center()
	add_child(player)

	coin = CoinScript.new()
	add_child(coin)
	_move_coin()

	_spawn_enemy()
	_update_hud()


func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_action_just_pressed("restart"):
			_start()
		return

	# Une nouvelle boule toutes les 5 s, de plus en plus vite avec le score.
	spawn_timer += delta
	if spawn_timer >= 5.0:
		spawn_timer = 0.0
		_spawn_enemy()

	if player.position.distance_to(coin.position) < player.RADIUS + coin.RADIUS:
		score += 1
		_move_coin()
		_update_hud()

	for e in enemies:
		if player.position.distance_to(e.position) < player.RADIUS + e.RADIUS:
			_game_over()
			return


func _spawn_enemy() -> void:
	var e: Node2D = EnemyScript.new()
	e.bounds = bounds
	e.position = _random_point_away_from_player()
	var speed := 150.0 + score * 8.0
	e.velocity = Vector2.RIGHT.rotated(randf() * TAU) * speed
	add_child(e)
	enemies.append(e)


func _move_coin() -> void:
	coin.position = _random_point_away_from_player()


func _random_point_away_from_player() -> Vector2:
	var margin := 40.0
	var p := Vector2.ZERO
	for i in 20:
		p = Vector2(
			randf_range(margin, bounds.size.x - margin),
			randf_range(margin, bounds.size.y - margin))
		if p.distance_to(player.position) > SAFE_SPAWN_DISTANCE:
			break
	return p


func _game_over() -> void:
	is_game_over = true
	best = max(best, score)
	_update_hud()
	message.text = "PERDU !  Score : %d\nEntrée ou R pour rejouer" % score


func _update_hud() -> void:
	hud.text = "Score : %d    Record : %d" % [score, best]


func _draw() -> void:
	draw_rect(bounds, Color("1b1f2a"))
	var step := 48.0
	var x := 0.0
	while x < bounds.size.x:
		draw_line(Vector2(x, 0), Vector2(x, bounds.size.y), Color(1, 1, 1, 0.04))
		x += step
	var y := 0.0
	while y < bounds.size.y:
		draw_line(Vector2(0, y), Vector2(bounds.size.x, y), Color(1, 1, 1, 0.04))
		y += step
