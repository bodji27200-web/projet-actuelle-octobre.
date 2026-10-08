class_name KeysScreen
extends Screen
## Modification des touches : choisis une action, puis appuie sur la nouvelle touche.

var _index := 0
var _col := 0
var _labels: Array = []
var _panel: Panel
var _waiting := false
var _actions: Array = []
var _hint: Label
var _skip := -1


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("dde4f0")
	bg.size = size
	add_child(bg)
	Kit.label(self, "TOUCHES", Vector2(14, 6), 20, Color("3060a0"), false)
	_actions = Game.ACTIONS.keys()
	_panel = Kit.panel(self, Rect2(8, 34, 464, 254))
	var hp := Kit.panel(self, Rect2(8, 290, 464, 28))
	_hint = Kit.label(hp, "", Vector2(10, 0), 13)
	_build()


func _rows() -> int:
	return _actions.size() + 1


func _build() -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	for i in _actions.size():
		var a: String = _actions[i]
		var keys := Game.key_list(a)
		_labels.append(Kit.label(_panel, Game.ACTIONS[a][0], Vector2(10, 2 + i * 21), 14, Color("c03030") if i == _index else Kit.INK))
		for c in 2:
			var txt := Game.key_name(keys[c]) if c < keys.size() else "—"
			if _waiting and i == _index and c == _col:
				txt = "..."
			var sel := i == _index and c == _col
			_labels.append(Kit.label(_panel, ("[" + txt + "]") if sel else txt, Vector2(200 + c * 130, 2 + i * 21), 14, Color("c03030") if sel else Kit.INK))
	_labels.append(Kit.label(_panel, "Rétablir les touches par défaut", Vector2(10, 2 + _actions.size() * 21), 14, Color("c03030") if _index == _actions.size() else Color("606060")))
	_hint.text = "Appuie sur la nouvelle touche (Échap pour annuler)" if _waiting else "A : changer   Gauche/Droite : touche 1 ou 2   B : retour"


func _input(event: InputEvent) -> void:
	if not _waiting or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	_waiting = false
	if event.physical_keycode != KEY_ESCAPE or _actions[_index] == "b":
		Game.set_key(_actions[_index], _col, event.physical_keycode)
		Audio.sfx("select")
	_skip = Engine.get_process_frames()
	_build()


func _process(_d: float) -> void:
	if _waiting or _skip >= Engine.get_process_frames() - 1:
		return
	if act("up"):
		_index = (_index - 1 + _rows()) % _rows()
		_build()
	elif act("down"):
		_index = (_index + 1) % _rows()
		_build()
	elif act("left") or act("right"):
		_col = 1 - _col
		_build()
	elif act("a"):
		if _index == _actions.size():
			Game.reset_keys()
			_build()
		else:
			_waiting = true
			_build()
	elif act("b"):
		finish()
