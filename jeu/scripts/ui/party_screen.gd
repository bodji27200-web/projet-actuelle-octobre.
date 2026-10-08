class_name PartyScreen
extends Screen
## Équipe Pokémon. Modes : field (menu Start), select (choisir pour un objet), battle (changer en combat).

var mode := "field"
var item := ""
var title := "Choisissez un Pokémon."
var forced := false
var active_index := -1
var blocked: Array = []
var _index := 0
var _swap_from := -1
var _slots: Array = []
var _msg: Label
var _busy := false


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("68a0b0")
	bg.size = Vector2(480, 320)
	add_child(bg)
	var p := Kit.panel(self, Rect2(4, 262, 472, 54))
	_msg = Kit.label(p, title, Vector2(12, 8))
	_build()


func _build() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	for i in Game.PARTY_MAX:
		var rect := Rect2(8 + (i % 2) * 236, 8 + (i / 2) * 84, 228, 78)
		var mon: Pokemon = Game.party[i] if i < Game.party.size() else null
		var border := Color("e05050") if i == _index else Color("405060")
		if i == _swap_from:
			border = Color("e0b030")
		var bgc := Color("f8f8f8") if mon != null else Color("b0c8d0")
		if mon != null and mon.is_fainted():
			bgc = Color("f0d0c8")
		var p := Kit.panel(self, rect, bgc, border)
		_slots.append(p)
		if mon == null:
			continue
		var icon := TextureRect.new()
		icon.position = Vector2(2, 6)
		icon.size = Vector2(60, 45)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if mon.is_egg:
			icon.texture = PixelArt.egg()
		else:
			Sprites.apply(icon, "icon", mon.species)
		p.add_child(icon)
		if mon.is_egg:
			Kit.label(p, "ŒUF", Vector2(64, 4), 15)
			Kit.label(p, "Il éclora en marchant.", Vector2(64, 30), 12, Color("707070"))
			continue
		Kit.name_line(p, mon, Vector2(64, 4), 15)
		Kit.label(p, "N.%d" % mon.level, Vector2(64, 24), 14)
		Kit.status_tag(p, mon.status, Vector2(116, 28))
		Kit.hp_bar(p, Vector2(64, 48), 140, float(mon.hp) / mon.max_hp())
		Kit.label(p, "%d/%d" % [mon.hp, mon.max_hp()], Vector2(140, 54), 13)
		if mode == "select" and ItemUse.is_tm(item):
			var ok := mon.can_learn_tm(Data.items[item]["move"])
			Kit.label(p, "APTE" if ok else "PAS APTE", Vector2(150, 24), 13, Color("3080e0") if ok else Color("c04040"))
		if mode == "select" and item in ItemUse.STONES:
			var ok2 := mon.item_evolution(item) != 0
			Kit.label(p, "APTE" if ok2 else "PAS APTE", Vector2(150, 24), 13, Color("3080e0") if ok2 else Color("c04040"))


func _process(_delta: float) -> void:
	if _busy or Game.party.is_empty():
		if Game.party.is_empty() and act("b"):
			finish(-1)
		return
	var n := Game.party.size()
	var old := _index
	if act("left") or act("up"):
		_index = (_index - (1 if act("left") else 2) + n) % n
	elif act("right") or act("down"):
		_index = (_index + (1 if act("right") else 2)) % n
	if old != _index:
		_build()
		return
	if act("a"):
		_choose()
	elif act("b"):
		if _swap_from >= 0:
			_swap_from = -1
			_msg.text = title
			_build()
		elif not forced:
			finish(-1)


func _choose() -> void:
	if _swap_from >= 0:
		var a: Pokemon = Game.party[_swap_from]
		Game.party[_swap_from] = Game.party[_index]
		Game.party[_index] = a
		_swap_from = -1
		_msg.text = title
		_build()
		return
	match mode:
		"select":
			finish(_index)
		"battle":
			_busy = true
			var c: int = await Game.ui.choose(["ENVOYER", "RÉSUMÉ", "RETOUR"], Vector2(330, 180))
			_busy = false
			if c == 0:
				var mon: Pokemon = Game.party[_index]
				if mon.is_fainted():
					_msg.text = "%s n'a plus d'énergie pour se battre !" % mon.name()
				elif mon.is_egg:
					_msg.text = "Un Œuf ne peut pas combattre !"
				elif _index == active_index or blocked.has(_index):
					_msg.text = "%s est déjà au combat !" % mon.name()
				else:
					finish(_index)
			elif c == 1:
				await _summary()
		_:
			_busy = true
			var c2: int = await Game.ui.choose(["RÉSUMÉ", "DÉPLACER", "RETOUR"], Vector2(330, 180))
			_busy = false
			if c2 == 0:
				await _summary()
			elif c2 == 1:
				_swap_from = _index
				_msg.text = "Avec quel Pokémon échanger ?"
				_build()


func _summary() -> void:
	_busy = true
	var s := SummaryScreen.new()
	s.list = Game.party
	s.index = _index
	await Game.ui.open(s)
	_index = s.index
	_busy = false
	_build()
