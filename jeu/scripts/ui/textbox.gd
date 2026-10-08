class_name TextBox
extends Screen
## Boîte de dialogue : texte qui défile lettre par lettre, A pour continuer.

const SPEED := 60.0

var pages: Array = []
var auto := 0.0
var keep_open := false
var _page := 0
var _shown := 0.0
var _wait := 0.0
var _label: Label
var _arrow: Label
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := Kit.panel(self, Rect2(4, 244, 472, 72))
	_label = Kit.label(p, "", Vector2(12, 8))
	_label.size = Vector2(440, 56)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_arrow = Kit.label(p, "▼", Vector2(446, 44), 14, Color("e05050"), false)
	_show_page()


func _show_page() -> void:
	_label.text = str(pages[_page])
	_label.visible_characters = 0
	_shown = 0.0
	_wait = 0.0


func _process(delta: float) -> void:
	_t += delta
	var total := _label.get_total_character_count()
	var fast := Input.is_action_pressed("a") or Input.is_action_pressed("b")
	if _shown < total:
		_shown += delta * SPEED * (3.0 if fast else 1.0)
		_label.visible_characters = int(_shown)
		_arrow.visible = false
		if act("a") or act("b"):
			_shown = total
			_label.visible_characters = -1
		return
	_label.visible_characters = -1
	_arrow.visible = auto <= 0.0 and int(_t * 3) % 2 == 0
	_wait += delta
	if (auto > 0.0 and _wait >= auto) or act("a") or act("b"):
		_page += 1
		if _page >= pages.size():
			finish()
		else:
			_show_page()
