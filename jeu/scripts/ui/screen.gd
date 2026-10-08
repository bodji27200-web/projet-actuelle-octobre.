class_name Screen
extends Control
## Base des écrans et fenêtres : reçoit les touches seulement quand il est au sommet de la pile.

signal done(result: Variant)

var _finished := false


func _enter_tree() -> void:
	Game.push(self)


func act(action: String) -> bool:
	return Game.pressed(self, action)


func finish(result: Variant = null) -> void:
	if _finished:
		return
	_finished = true
	Game.pop(self)
	done.emit(result)
	queue_free()


func _exit_tree() -> void:
	if not _finished:
		Game.pop(self)
