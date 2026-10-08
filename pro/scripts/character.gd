class_name Character
extends Node2D
## Personnage sur la grille : déplacement case par case, animation de marche, ombre au sol.

const T := 32
const DIRS := {"down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0), "up": Vector2i(0, -1)}
const ROWS := {"down": 0, "left": 1, "right": 2, "up": 3}

var sprite: Sprite2D
var tile := Vector2i.ZERO
var dir := "down"
var moving := false
var frames := 4          # images de marche par direction
var _step := 0


func setup(tex: Texture2D, fw: int, fh: int, n_frames: int, feet: int, with_shadow := true) -> void:
	frames = n_frames
	if with_shadow:
		var sh := Sprite2D.new()
		sh.texture = load("res://assets/world/shadow.png")
		sh.position = Vector2(0, -1)
		add_child(sh)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.hframes = n_frames
	sprite.vframes = 4
	sprite.centered = false
	sprite.offset = Vector2(-fw / 2, -feet)
	add_child(sprite)
	face(dir)


func place(t: Vector2i) -> void:
	tile = t
	position = Vector2(t.x * T + T / 2, t.y * T + T - 2)


func face(d: String) -> void:
	dir = d
	sprite.frame = ROWS[d] * frames + (0 if not moving else _anim_frame())


func _anim_frame() -> int:
	return [1, 3][_step % 2] if frames == 4 else (_step % 2)


## Avance d'une case (ou saute un rebord : jump = 2 cases avec un petit bond).
func walk_to(t: Vector2i, time: float, jump := false) -> void:
	moving = true
	_step += 1
	sprite.frame = ROWS[dir] * frames + _anim_frame()
	var target := Vector2(t.x * T + T / 2, t.y * T + T - 2)
	var start := position
	tile = t
	var tw := create_tween()
	if jump:
		tw.tween_method(func(k: float):
			position = start.lerp(target, k)
			sprite.position.y = -sin(k * PI) * 12, 0.0, 1.0, time)
	else:
		tw.tween_property(self, "position", target, time)
		tw.parallel().tween_callback(func(): sprite.frame = ROWS[dir] * frames + (0 if frames == 4 else _step % 2)).set_delay(time * 0.55)
	await tw.finished
	sprite.position.y = 0
	moving = false
	if frames == 4:
		sprite.frame = ROWS[dir] * frames
