class_name Choice
extends Screen
## Menu de choix avec curseur ▶. Renvoie l'indice choisi, ou -1 si annulé avec B.

var options: Array = []
var at := Vector2(-1, -1)
var width := 0.0
var cancel := true
var index := 0
var columns := 1
var _labels: Array = []
var _cursor: Label
var _panel: Panel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := width
	if w <= 0:
		for o in options:
			w = maxf(w, str(o).length() * 9.0 + 44.0)
	width = w
	var rows := ceili(float(options.size()) / columns)
	var h := rows * 22 + 16
	var pos := at
	if pos.x < 0:
		pos = Vector2(476 - w * columns, 240 - h)
	_panel = Kit.panel(self, Rect2(pos, Vector2(w * columns, h)))
	for i in options.size():
		var l := Kit.label(_panel, str(options[i]), Vector2(26 + (i % columns) * w, 6 + (i / columns) * 22))
		_labels.append(l)
	_cursor = Kit.label(_panel, "▶", Vector2(8, 6), 14, Kit.INK, false)
	_move(0)


func _move(d: int) -> void:
	index = clampi(index + d, 0, options.size() - 1)
	_cursor.position = Vector2(8 + (index % columns) * width, 7 + (index / columns) * 22)


func _process(_delta: float) -> void:
	if act("up"):
		_move(-columns)
	elif act("down"):
		_move(columns)
	elif act("left") and columns > 1:
		_move(-1)
	elif act("right") and columns > 1:
		_move(1)
	elif act("a"):
		finish(index)
	elif act("b") and cancel:
		finish(-1)
