extends Node2D

const RADIUS := 10.0

var t := 0.0


func _process(delta: float) -> void:
	t += delta
	scale = Vector2.ONE * (1.0 + 0.15 * sin(t * 6.0))


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color("ffd54f"))
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color("ffb300"))
