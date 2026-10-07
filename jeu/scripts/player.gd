extends Node2D

const SPEED := 360.0
const RADIUS := 18.0

var bounds := Rect2()


func _process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += dir * SPEED * delta
	position = position.clamp(bounds.position + Vector2(RADIUS, RADIUS), bounds.end - Vector2(RADIUS, RADIUS))


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color("4fc3f7"))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color.WHITE, 2.0)
