class_name ItemList2
extends Screen
## Liste défilante générique (sac, boutique, PC, Pokédex) : sous-classes fournissent les lignes.

const VISIBLE := 9

var _index := 0
var _scroll := 0
var _list_panel: Panel
var _rows: Array = []
var _cursor: Label


func row_count() -> int:
	return 0


func row_text(_i: int) -> String:
	return ""


func row_right(_i: int) -> String:
	return ""


func on_select(_i: int) -> void:
	pass


func on_cancel() -> void:
	finish(null)


func on_change(_i: int) -> void:
	pass


func on_side(_d: int) -> void:
	pass


func build_list(rect: Rect2) -> void:
	_list_panel = Kit.panel(self, rect)
	_cursor = Kit.label(_list_panel, "▶", Vector2(6, 6), 14, Kit.INK, false)
	refresh_list()


func refresh_list() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	var n := row_count()
	_index = clampi(_index, 0, maxi(0, n - 1))
	if _index < _scroll:
		_scroll = _index
	if _index >= _scroll + VISIBLE:
		_scroll = _index - VISIBLE + 1
	for k in VISIBLE:
		var i := _scroll + k
		if i >= n:
			break
		var l := Kit.label(_list_panel, row_text(i), Vector2(24, 6 + k * 22), 15)
		_rows.append(l)
		var rt := row_right(i)
		if rt != "":
			var r := Kit.label(_list_panel, rt, Vector2(_list_panel.size.x - 110, 6 + k * 22), 15)
			r.size.x = 96
			r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_rows.append(r)
	_cursor.visible = n > 0
	_cursor.position = Vector2(6, 7 + (_index - _scroll) * 22)
	on_change(_index)


func _process(_delta: float) -> void:
	var n := row_count()
	if act("up") and n > 0:
		_index = (_index - 1 + n) % n
		refresh_list()
	elif act("down") and n > 0:
		_index = (_index + 1) % n
		refresh_list()
	elif act("left"):
		on_side(-1)
	elif act("right"):
		on_side(1)
	elif act("a") and n > 0:
		on_select(_index)
	elif act("b"):
		on_cancel()
