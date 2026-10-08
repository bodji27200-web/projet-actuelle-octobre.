class_name NameEntry
extends Screen
## Saisie d'un nom (clavier).

var title := ""
var default := ""
var max_len := 12
var _edit: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := Kit.panel(self, Rect2(60, 90, 360, 130))
	Kit.label(p, title, Vector2(14, 10))
	_edit = LineEdit.new()
	_edit.position = Vector2(14, 44)
	_edit.size = Vector2(330, 34)
	_edit.max_length = max_len
	_edit.placeholder_text = default
	_edit.add_theme_font_size_override("font_size", 18)
	p.add_child(_edit)
	Kit.label(p, "Entrée : valider (vide = %s)" % default, Vector2(14, 90), 12, Color("707070"), false)
	_edit.grab_focus.call_deferred()
	_edit.text_submitted.connect(func(_t): _submit())


func _submit() -> void:
	var t := _edit.text.strip_edges()
	finish(t if t != "" else default)
