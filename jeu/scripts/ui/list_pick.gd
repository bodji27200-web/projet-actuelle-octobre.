class_name ListPick
extends ItemList2
## Liste à choisir générique : titre, lignes, colonne de droite, description et icône par ligne.
## Renvoie l'indice choisi, ou -1 (B). « tabs » : onglets parcourus avec ◀ ▶ (renvoie {"tab": d}).

var title := ""
var rows: Array = []
var rights: Array = []
var descs: Array = []
## Icône par ligne : ["icon", id_pokémon] ou ["item", id_objet] ou null.
var icons: Array = []
var tabs := false
var bg_color := Color("7890c0")
var _desc: Label
var _icon: TextureRect


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = bg_color
	bg.size = Vector2(480, 320)
	add_child(bg)
	var tp := Kit.panel(self, Rect2(6, 6, 468, 32))
	var t := Kit.label(tp, title, Vector2(10, 1), 15)
	t.clip_text = true
	t.size = Vector2(448, 28)
	_icon = TextureRect.new()
	_icon.position = Vector2(14, 60)
	_icon.size = Vector2(96, 96)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_icon)
	var dp := Kit.panel(self, Rect2(6, 244, 468, 72))
	_desc = Kit.label(dp, "", Vector2(10, 4), 13)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(448, 62)
	build_list(Rect2(122, 42, 352, 200) if _has_icons() else Rect2(6, 42, 468, 200))


func _has_icons() -> bool:
	return icons.any(func(x): return x != null)


func row_count() -> int:
	return rows.size()


func row_text(i: int) -> String:
	return str(rows[i])


func row_right(i: int) -> String:
	return str(rights[i]) if i < rights.size() else ""


func on_change(i: int) -> void:
	_desc.text = str(descs[i]) if i < descs.size() else ("◀ ▶ : changer d'onglet" if tabs else "")
	_icon.texture = null
	if i < icons.size() and icons[i] != null:
		var ic: Array = icons[i]
		Sprites.apply(_icon, ic[0], ic[1])


func on_select(i: int) -> void:
	finish(i)


func on_cancel() -> void:
	finish(-1)


func on_side(d: int) -> void:
	if tabs:
		finish({"tab": d})


## Raccourci : ouvre une liste et renvoie le choix.
static func pick(p_title: String, p_rows: Array, p_rights := [], p_descs := [], p_icons := [], p_tabs := false) -> Variant:
	var lp := ListPick.new()
	lp.title = p_title
	lp.rows = p_rows
	lp.rights = p_rights
	lp.descs = p_descs
	lp.icons = p_icons
	lp.tabs = p_tabs
	return await Game.ui.open(lp)
