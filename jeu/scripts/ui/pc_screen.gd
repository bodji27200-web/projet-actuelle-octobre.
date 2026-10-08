class_name PCScreen
extends ItemList2
## PC de stockage : retirer, déposer, relâcher, voir le résumé.

var _tab := 0  # 0 = PC (retirer), 1 = équipe (déposer)
var _title: Label
var _busy := false
var _icon: TextureRect
var _info: Label


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("7090c8")
	bg.size = Vector2(480, 320)
	add_child(bg)
	var tp := Kit.panel(self, Rect2(6, 6, 200, 40))
	_title = Kit.label(tp, "", Vector2(10, 4))
	Kit.label(self, "◀ ▶ PC / Équipe   A : options   B : quitter", Vector2(12, 300), 12, Color.WHITE, false)
	_icon = TextureRect.new()
	_icon.position = Vector2(20, 60)
	_icon.size = Vector2(160, 160)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_icon)
	_info = Kit.label(self, "", Vector2(14, 226), 14, Color.WHITE, false)
	build_list(Rect2(212, 6, 262, 228))
	_set_tab(0)


func _list() -> Array:
	return Game.pc if _tab == 0 else Game.party


func _set_tab(t: int) -> void:
	_tab = t
	_title.text = "PC : %d Pokémon" % Game.pc.size() if t == 0 else "ÉQUIPE : %d/6" % Game.party.size()
	_index = 0
	_scroll = 0
	refresh_list()


func row_count() -> int:
	return _list().size()


func row_text(i: int) -> String:
	var m: Pokemon = _list()[i]
	return m.name() + (" ★" if m.shiny else "")


func row_right(i: int) -> String:
	return "N.%d" % _list()[i].level


func on_change(i: int) -> void:
	if _list().is_empty():
		_icon.texture = null
		_info.text = "Vide."
		return
	var m: Pokemon = _list()[i]
	Sprites.apply(_icon, "front", m.species, m.shiny, PixelArt.placeholder())
	_info.text = "%s  %s\n%s" % [m.data()["name"], m.gender_symbol(), " / ".join(m.types().map(func(t): return Data.type_name(t)))]


func on_side(_d: int) -> void:
	if not _busy:
		_set_tab(1 - _tab)


func _process(delta: float) -> void:
	if _busy:
		return
	super._process(delta)


func on_select(i: int) -> void:
	_busy = true
	var verb := "RETIRER" if _tab == 0 else "DÉPOSER"
	var c: int = await Game.ui.choose([verb, "RÉSUMÉ", "RELÂCHER", "RETOUR"], Vector2(330, 150))
	var list := _list()
	var mon: Pokemon = list[i]
	match c:
		0:
			if _tab == 0:
				if Game.party.size() >= Game.PARTY_MAX:
					await Game.ui.say("Votre équipe est pleine !")
				else:
					Game.pc.remove_at(i)
					Game.party.append(mon)
			else:
				if Game.alive_count() <= 1 and not mon.is_fainted() or Game.party.size() <= 1:
					await Game.ui.say("C'est votre dernier Pokémon en forme !")
				else:
					Game.party.remove_at(i)
					mon.heal_full()
					Game.pc.append(mon)
		1:
			var s := SummaryScreen.new()
			s.list = list
			s.index = i
			await Game.ui.open(s)
		2:
			if _tab == 1 and Game.party.size() <= 1:
				await Game.ui.say("C'est votre dernier Pokémon !")
			elif await Game.ui.confirm("Relâcher %s ? C'est définitif !" % mon.name()):
				list.remove_at(i)
				await Game.ui.say("%s est relâché. Au revoir, %s !" % [mon.name(), mon.name()])
	_busy = false
	_set_tab(_tab)
	_index = mini(i, maxi(0, row_count() - 1))
	refresh_list()


func on_cancel() -> void:
	if not _busy:
		finish(null)
