class_name SummaryScreen
extends Screen
## Résumé d'un Pokémon : infos, stats (avec IV/EV et nature), capacités.

const PAGES := ["INFOS", "STATS", "CAPACITÉS"]
const BALL_NAMES := {}

var list: Array = []
var index := 0
var _page := 0
var _move := 0
var _root: Control


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("e8e0c8")
	bg.size = Vector2(480, 320)
	add_child(bg)
	_root = Control.new()
	add_child(_root)
	_draw_page()


func _process(_delta: float) -> void:
	var redraw := false
	if act("left"):
		_page = (_page + 2) % 3
		redraw = true
	elif act("right"):
		_page = (_page + 1) % 3
		redraw = true
	elif act("up") or act("down"):
		var d := -1 if act("up") else 1
		if _page == 2:
			var mon: Pokemon = list[index]
			_move = clampi(_move + d, 0, mon.moves.size() - 1)
		else:
			index = (index + d + list.size()) % list.size()
			_move = 0
		redraw = true
	elif act("b") or act("a"):
		finish()
		return
	if redraw:
		_draw_page()


func _draw_page() -> void:
	Kit.clear(_root)
	var mon: Pokemon = list[index]
	if mon.is_egg:
		var ep := Kit.panel(_root, Rect2(40, 60, 400, 200), Color("f8f8f0"), Color("a09070"))
		var tr := TextureRect.new()
		tr.texture = PixelArt.egg()
		tr.position = Vector2(150, 10)
		tr.size = Vector2(96, 96)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ep.add_child(tr)
		var l := Kit.label(ep, "", Vector2(16, 120), 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(368, 60)
		l.text = "ŒUF\n" + mon.egg_hint()
		return
	var d := mon.data()
	# Bandeau
	var head := ColorRect.new()
	head.color = Color("d05050")
	head.size = Vector2(480, 26)
	_root.add_child(head)
	for i in 3:
		var t := Kit.label(_root, PAGES[i], Vector2(10 + i * 92, 1), 14, Color.WHITE if i == _page else Color("f0b0b0"), false)
	Kit.label(_root, "◀▶ pages  ▲▼ Pokémon  B retour", Vector2(296, 4), 10, Color.WHITE, false)
	# Colonne gauche : sprite et nom.
	var left := Kit.panel(_root, Rect2(6, 32, 170, 282), Color("f8f8f0"), Color("a09070"))
	var spr := TextureRect.new()
	spr.position = Vector2(13, 40)
	spr.size = Vector2(144, 144)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Sprites.apply(spr, "front", mon.species, mon.shiny, PixelArt.placeholder())
	left.add_child(spr)
	Kit.name_line(left, mon, Vector2(10, 6), 16)
	Kit.label(left, "N.%d" % mon.level, Vector2(10, 24), 14)
	if mon.shiny:
		Kit.label(left, "★ CHROMATIQUE", Vector2(10, 190), 13, Color("e0a000"))
	var y := 210
	for t in mon.types():
		Kit.type_tag(left, t, Vector2(10 + (y - 210) * 0, y))
		y += 22
	Kit.status_tag(left, mon.status, Vector2(110, 212))
	if mon.is_fainted():
		Kit.label(left, "K.O.", Vector2(110, 230), 14, Color("c04040"))
	var right := Kit.panel(_root, Rect2(182, 32, 292, 282), Color("f8f8f0"), Color("a09070"))
	match _page:
		0:
			_info(right, mon, d)
		1:
			_stats(right, mon)
		2:
			_moves(right, mon)


func _row(p: Control, y: int, k: String, v: String, vc := Kit.INK) -> void:
	Kit.label(p, k, Vector2(10, y), 14, Color("806040"))
	var l := Kit.label(p, "", Vector2(110, y), 14, vc)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size.x = 170
	l.text = v


func _info(p: Control, mon: Pokemon, d: Dictionary) -> void:
	_row(p, 4, "N° Pokédex", "%03d" % mon.species)
	_row(p, 22, "Espèce", d["genus"])
	_row(p, 40, "Dresseur", mon.ot if mon.ot != "" else Game.player_name)
	_row(p, 58, "Nature", Data.natures[mon.nature]["name"])
	_row(p, 76, "Ball", Data.item_name(mon.ball))
	_row(p, 94, "Points Exp.", str(mon.exp))
	_row(p, 112, "Niv. suivant", "%d pts" % mon.exp_to_next() if mon.level < 100 else "—")
	_row(p, 130, "Bonheur", "%d / 255" % mon.happiness)
	Kit.label(p, "TALENT : " + Data.ability_name(mon.ability), Vector2(10, 148), 14, Color("c04040"))
	var desc := Kit.label(p, "", Vector2(10, 166), 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size = Vector2(270, 50)
	desc.text = Data.abilities.get(mon.ability, {}).get("desc", "")
	var evo := ""
	for e in d["evos"]:
		var to: String = Data.pokemon[e["to"]]["name"]
		if e.has("level"):
			evo += "%s au N.%d. " % [to, e["level"]]
		else:
			evo += "%s avec %s. " % [to, Data.item_name(e["item"])]
	var ev := Kit.label(p, "", Vector2(10, 238), 13, Color("406080"))
	ev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev.size = Vector2(270, 50)
	ev.text = "Évolution : " + (evo if evo != "" else "aucune")


func _stats(p: Control, mon: Pokemon) -> void:
	var nat: Dictionary = Data.natures[mon.nature]
	Kit.label(p, "STAT", Vector2(10, 4), 13, Color("806040"))
	Kit.label(p, "VALEUR", Vector2(110, 4), 13, Color("806040"))
	Kit.label(p, "IV", Vector2(190, 4), 13, Color("806040"))
	Kit.label(p, "EV", Vector2(234, 4), 13, Color("806040"))
	var total_ev := 0
	for i in 6:
		var y := 26 + i * 26
		var col := Kit.INK
		if nat["up"] == i:
			col = Color("d03030")
		elif nat["down"] == i:
			col = Color("3050c0")
		Kit.label(p, Data.STAT_NAMES[i], Vector2(10, y), 15, col)
		var v := "%d/%d" % [mon.hp, mon.max_hp()] if i == 0 else str(mon.stats[i])
		Kit.label(p, v, Vector2(110, y), 15)
		Kit.label(p, str(mon.ivs[i]), Vector2(190, y), 15, Color("308030") if mon.ivs[i] == 31 else Kit.INK)
		Kit.label(p, str(mon.evs[i]), Vector2(234, y), 15)
		total_ev += mon.evs[i]
	Kit.label(p, "EV au total : %d / 510" % total_ev, Vector2(10, 186), 13)
	var iv_total := 0
	for v in mon.ivs:
		iv_total += v
	Kit.label(p, "IV au total : %d / 186" % iv_total, Vector2(10, 204), 13)
	Kit.label(p, "Puissance Cachée : type %s" % Data.type_name(mon.hidden_power_type()), Vector2(10, 222), 13)
	var exp_bg := ColorRect.new()
	exp_bg.position = Vector2(40, 252)
	exp_bg.size = Vector2(230, 8)
	exp_bg.color = Color("404848")
	p.add_child(exp_bg)
	var exp := ColorRect.new()
	exp.position = Vector2(2, 2)
	exp.size = Vector2(226 * mon.exp_progress(), 4)
	exp.color = Color("48a0f8")
	exp_bg.add_child(exp)
	Kit.label(p, "EXP", Vector2(10, 244), 11, Color("406080"), false)


func _moves(p: Control, mon: Pokemon) -> void:
	for i in mon.moves.size():
		var m: Dictionary = mon.moves[i]
		var md: Dictionary = Data.moves[m["id"]]
		var y := 4 + i * 30
		var typ: String = mon.hidden_power_type() if md["ident"] == "hidden-power" else md["type"]
		Kit.type_tag(p, typ, Vector2(10, y + 2))
		Kit.label(p, ("▶ " if i == _move else "") + md["name"], Vector2(74, y), 15, Color("c04040") if i == _move else Kit.INK)
		Kit.label(p, "PP %d/%d" % [m["pp"], m["max"]], Vector2(200, y), 14)
	if mon.moves.is_empty():
		return
	var sel: Dictionary = Data.moves[mon.moves[_move]["id"]]
	var cat: String = {"physical": "Physique", "special": "Spéciale", "status": "Statut"}[sel["cat"]]
	Kit.label(p, "Catégorie : %s" % cat, Vector2(10, 128), 14, Color("806040"))
	Kit.label(p, "Puissance : %s" % (str(sel["power"]) if sel["power"] > 0 else "—"), Vector2(10, 146), 14, Color("806040"))
	Kit.label(p, "Précision : %s" % (str(sel["acc"]) if sel["acc"] > 0 else "—"), Vector2(150, 146), 14, Color("806040"))
	var desc := Kit.label(p, "", Vector2(10, 168), 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size = Vector2(270, 100)
	desc.text = sel["desc"]
