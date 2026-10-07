extends Node2D

const RADIUS := 14.0

var velocity := Vector2.ZERO
var bounds := Rect2()


func _process(delta: float) -> void:
	position += velocity * delta
	# Rebond sur les bords de l'écran.
	if position.x < bounds.position.x + RADIUS or position.x > bounds.end.x - RADIUS:
		velocity.x = -velocity.x
	if position.y < bounds.position.y + RADIUS or position.y > bounds.end.y - RADIUS:
		velocity.y = -velocity.y
	position = position.clamp(bounds.position + Vector2(RADIUS, RADIUS), bounds.end - Vector2(RADIUS, RADIUS))


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color("ef5350"))
