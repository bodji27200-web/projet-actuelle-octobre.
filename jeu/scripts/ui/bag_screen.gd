class_name BagScreen
extends ItemList2
## Sac : poches OBJETS / SOINS / BAIES / OBJETS TENUS / BALLS / CT / RARES. Renvoie l'objet choisi (ou null).

const POCKETS := ["objets", "soins", "baies", "tenus", "balls", "ct", "rares"]
const POCKET_NAMES := ["OBJETS", "SOINS", "BAIES", "OBJETS TENUS", "BALLS", "CT / CS", "OBJ. RARES"]

static var last_pocket := 1

var mode := "field"
var _items: Array = []
var _title: Label
var _desc: Label
var _icon: TextureRect


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("e0a860")
	bg.size = Vector2(480, 320)
	add_child(bg)
	var tp := Kit.panel(self, Rect2(6, 6, 160, 40), Color("f8f0d8"), Color("a06030"))
	_title = Kit.label(tp, "", Vector2(10, 4), 16)
	Kit.label(self, "◀ ▶ changer de poche", Vector2(14, 52), 12, Color("603010"), false)
	Kit.label(self, "%d ₽" % Game.money, Vector2(14, 72), 15, Color("603010"), false)
	_icon = TextureRect.new()
	_icon.position = Vector2(50, 110)
	_icon.size = Vector2(64, 64)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_icon)
	var dp := Kit.panel(self, Rect2(6, 240, 468, 76), Color("f8f8f8"))
	_desc = Kit.label(dp, "", Vector2(10, 6), 14)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(448, 64)
	_load_pocket()
	build_list(Rect2(176, 6, 298, 228))


func _load_pocket() -> void:
	_items.clear()
	for id in Game.bag:
		if ItemUse.category(id) == POCKETS[last_pocket]:
			_items.append(id)
	_items.sort()
	_title.text = POCKET_NAMES[last_pocket]


func row_count() -> int:
	return _items.size() + 1


func row_text(i: int) -> String:
	return "FERMER LE SAC" if i >= _items.size() else Data.item_name(_items[i])


func row_right(i: int) -> String:
	if i >= _items.size() or ItemUse.is_tm(_items[i]) or Data.items.get(_items[i], {}).get("key", false):
		if i < _items.size() and _items[i] == "exp-share":
			return "ON" if Game.flag("exp_share_on") else "OFF"
		return ""
	return "x%d" % Game.item_count(_items[i])


func on_change(i: int) -> void:
	if i >= _items.size():
		_desc.text = "Fermer le sac."
		_icon.texture = null
		return
	var id: String = _items[i]
	_desc.text = Data.items.get(id, {}).get("desc", "")
	var icon_name := id
	if ItemUse.is_tm(id):
		icon_name = "tm-" + Data.moves[Data.items[id]["move"]]["type"]
	Sprites.apply(_icon, "item", icon_name)


func on_side(d: int) -> void:
	last_pocket = (last_pocket + d + POCKETS.size()) % POCKETS.size()
	_load_pocket()
	_index = 0
	_scroll = 0
	refresh_list()


func on_select(i: int) -> void:
	if i >= _items.size():
		finish(null)
		return
	finish(_items[i])
