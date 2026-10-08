class_name BattleScreen
extends Screen
## Écran de combat : affiche le moteur Battle et joue ses événements.

const MSG_AUTO := 0.9

var battle: Battle
var _sprites: Array = [null, null]
var _boxes: Array = [null, null]
var _bars: Array = [null, null]
var _hp_labels: Array = [null, null]
var _exp_bar: ColorRect
var _shown_hp: Array = [0, 0]
var _bottom: Panel
var _prompt: Label
var _menu_panel: Panel
var _menu_labels: Array = []
var _menu_cursor: Label
var _menu_index := 0
var _menu_cols := 2
var _menu_cancel := false
var _menu_on_move: Callable
var _menu_active := false
var _info: Panel
var _info_pp: Label
var _info_type: Label
var _home := [Vector2.ZERO, Vector2.ZERO]
var _box_species := [0, 0]
var _bg: Control
var _ball_spr: TextureRect

signal _menu_done(index: int)


func _ready() -> void:
	size = Vector2(480, 320)
	_build()
	_run()


# ---------------------------------------------------------------------------
# Construction de l'écran
# ---------------------------------------------------------------------------

func _build() -> void:
	_bg = Control.new()
	_bg.size = Vector2(480, 320)
	_bg.draw.connect(_draw_bg)
	add_child(_bg)
	for side in 2:
		var tr := TextureRect.new()
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if side == 1:
			tr.size = Vector2(144, 144)
			_home[1] = Vector2(292, 14)
		else:
			tr.size = Vector2(192, 192)
			_home[0] = Vector2(34, 92)
		tr.position = _home[side]
		tr.pivot_offset = tr.size / 2
		tr.visible = false
		add_child(tr)
		_sprites[side] = tr
	_bottom = Kit.panel(self, Rect2(4, 244, 472, 72), Color("f8f8f8"), Color("c04848"))
	_prompt = Kit.label(_bottom, "", Vector2(12, 8))
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.size = Vector2(240, 56)
	_ball_spr = TextureRect.new()
	_ball_spr.texture = PixelArt.ball()
	_ball_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball_spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ball_spr.size = Vector2(24, 24)
	_ball_spr.pivot_offset = Vector2(12, 12)
	_ball_spr.visible = false
	add_child(_ball_spr)


func _draw_bg() -> void:
	_bg.draw_rect(Rect2(0, 0, 480, 140), Color("f8f0d0"))
	_bg.draw_rect(Rect2(0, 140, 480, 180), Color("d8e8b0"))
	for i in 6:
		_bg.draw_rect(Rect2(0, 20 + i * 18, 480, 2), Color("f0e4b8"))
	_ellipse(Vector2(364, 150), Vector2(92, 22), Color("b8d088"), Color("90a868"))
	_ellipse(Vector2(130, 262), Vector2(110, 26), Color("b8d088"), Color("90a868"))


func _ellipse(c: Vector2, r: Vector2, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_bg.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	_bg.draw_polyline(pts, edge, 2.0)


func _make_box(side: int) -> void:
	if _boxes[side] != null:
		_boxes[side].queue_free()
	var b: Battle.Battler = battle.sides[side].b
	var mon := b.mon
	var rect := Rect2(12, 14, 214, 52) if side == 1 else Rect2(256, 160, 216, 72)
	var p := Kit.panel(self, rect, Color("f8f8e0"), Color("506050"))
	move_child(p, _bottom.get_index())
	_boxes[side] = p
	_box_species[side] = mon.species
	var name := mon.name() + (" ★" if mon.shiny else "")
	Kit.label(p, name, Vector2(10, 2), 15)
	var g := Kit.label(p, mon.gender_symbol(), Vector2(140, 2), 15, Color("3068d8") if mon.gender == 0 else Color("e05878"))
	g.visible = mon.gender < 2
	Kit.label(p, "N.%d" % mon.level, Vector2(164, 2), 15)
	Kit.label(p, "PV", Vector2(40, 22), 12, Color("e0a020"), false)
	_bars[side] = Kit.hp_bar(p, Vector2(62, 26), 132, float(mon.hp) / mon.max_hp())
	_shown_hp[side] = mon.hp
	Kit.status_tag(p, mon.status, Vector2(4, 24))
	if side == 0:
		_hp_labels[0] = Kit.label(p, "%d/%d" % [mon.hp, mon.max_hp()], Vector2(120, 34), 15)
		var bg := ColorRect.new()
		bg.position = Vector2(30, 58)
		bg.size = Vector2(170, 5)
		bg.color = Color("404848")
		p.add_child(bg)
		_exp_bar = ColorRect.new()
		_exp_bar.position = Vector2(1, 1)
		_exp_bar.size = Vector2(168 * mon.exp_progress(), 3)
		_exp_bar.color = Color("48a0f8")
		bg.add_child(_exp_bar)
	else:
		if Game.caught.has(mon.species):
			var ball := TextureRect.new()
			ball.texture = PixelArt.ball()
			ball.position = Vector2(8, 26)
			ball.size = Vector2(12, 12)
			p.add_child(ball)


func _set_sprite(side: int, mon: Pokemon, species := 0, shiny := false) -> void:
	var tr: TextureRect = _sprites[side]
	var sid := species if species != 0 else mon.species
	var sh := shiny if species != 0 else mon.shiny
	Sprites.apply(tr, "back" if side == 0 else "front", sid, sh, PixelArt.placeholder())
	tr.modulate = Color.WHITE
	tr.position = _home[side]
	tr.scale = Vector2.ONE
	tr.visible = true


# ---------------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------------

func _run() -> void:
	await get_tree().process_frame
	await _play(battle.start())
	while not battle.over:
		if battle.need_switch:
			var idx: int = await _pick_switch(true)
			await _play(battle.player_switch(idx))
			continue
		var action = await _choose_action()
		if action == null:
			continue
		_prompt.text = ""
		await _play(battle.play_turn(action))
	await get_tree().create_timer(0.3).timeout
	finish(battle.result)


func _say(text: String) -> void:
	_prompt.text = ""
	await Game.ui.say(text, MSG_AUTO)


func _play(events: Array) -> void:
	var i := 0
	while i < events.size():
		var e: Dictionary = events[i]
		match e["t"]:
			"msg":
				await _say(e["text"])
			"trainer_say":
				await _say("%s : %s" % [battle.trainer.get("name", ""), e["text"]])
			"send":
				var side: int = e["side"]
				var mon: Pokemon = e["mon"]
				_set_sprite(side, mon)
				_make_box(side)
				await _appear(side, mon)
			"recall":
				await _tween_scale(_sprites[e["side"]], 0.0, 0.25)
				_sprites[e["side"]].visible = false
			"hp":
				await _anim_hp(e["side"], e["hp"], e["max"])
			"faint":
				await _faint(e["side"])
			"anim":
				await _anim(e["side"], e["kind"])
			"refresh":
				for s in 2:
					if battle.sides[s].b != null and _boxes[s] != null:
						var keep: int = _shown_hp[s]
						_make_box(s)
						_shown_hp[s] = keep
						_update_hp_display(s, keep, battle.sides[s].b.mon.max_hp())
			"exp":
				if e["active"]:
					var levels_follow := false
					for j in range(i + 1, events.size()):
						if events[j]["t"] == "level" and events[j]["index"] == e["index"]:
							levels_follow = true
							break
					var mon: Pokemon = Game.party[e["index"]]
					await _tween_exp(1.0 if levels_follow else mon.exp_progress())
			"level":
				if e["active"]:
					var keep_hp: int = _shown_hp[0]
					_make_box(0)
					_shown_hp[0] = keep_hp
					_update_hp_display(0, keep_hp, battle.sides[0].b.mon.max_hp())
					_exp_bar.size.x = 0
					var last := true
					for j in range(i + 1, events.size()):
						if events[j]["t"] == "level" and events[j]["index"] == e["index"]:
							last = false
							break
					if last:
						await _tween_exp(Game.party[e["index"]].exp_progress())
			"learn":
				await Events.learn_move(e["mon"], e["move"])
			"ball":
				await _ball(e["shakes"], e["caught"])
			"hide":
				_sprites[e["side"]].visible = not e["on"]
			"sub":
				_sprites[e["side"]].modulate.a = 0.55 if e["on"] else 1.0
			"transform":
				Sprites.apply(_sprites[e["side"]], "back" if e["side"] == 0 else "front", e["species"], e["shiny"], PixelArt.placeholder())
			"weather", "end":
				pass
		i += 1


# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------

func _appear(side: int, mon: Pokemon) -> void:
	var tr: TextureRect = _sprites[side]
	tr.scale = Vector2(0.1, 0.1)
	tr.modulate = Color(3, 3, 3, 1)
	var tw := create_tween().set_parallel()
	tw.tween_property(tr, "scale", Vector2.ONE, 0.3)
	tw.tween_property(tr, "modulate", Color.WHITE, 0.45)
	await tw.finished
	if mon.shiny:
		for k in 3:
			tr.modulate = Color(1.6, 1.6, 0.8)
			await get_tree().create_timer(0.08).timeout
			tr.modulate = Color.WHITE
			await get_tree().create_timer(0.08).timeout


func _tween_scale(node: Control, s: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(s, s), t)
	await tw.finished


func _anim_hp(side: int, hp: int, mx: int) -> void:
	if _bars[side] == null:
		return
	var from: int = _shown_hp[side]
	var tw := create_tween()
	tw.tween_method(func(v: float): _update_hp_display(side, int(round(v)), mx), float(from), float(hp), clampf(absf(hp - from) / float(mx) * 1.2, 0.15, 0.8))
	await tw.finished
	_shown_hp[side] = hp


func _update_hp_display(side: int, hp: int, mx: int) -> void:
	if _bars[side] == null or not is_instance_valid(_bars[side]):
		return
	Kit.set_bar(_bars[side], float(hp) / maxf(1, mx))
	if side == 0 and _hp_labels[0] != null and is_instance_valid(_hp_labels[0]):
		_hp_labels[0].text = "%d/%d" % [hp, mx]


func _tween_exp(ratio: float) -> void:
	if _exp_bar == null or not is_instance_valid(_exp_bar):
		return
	var tw := create_tween()
	tw.tween_property(_exp_bar, "size:x", 168.0 * ratio, 0.6)
	await tw.finished


func _faint(side: int) -> void:
	var tr: TextureRect = _sprites[side]
	var tw := create_tween().set_parallel()
	tw.tween_property(tr, "position:y", tr.position.y + 80, 0.4)
	tw.tween_property(tr, "modulate:a", 0.0, 0.4)
	await tw.finished
	tr.visible = false
	if _boxes[side] != null:
		_boxes[side].queue_free()
		_boxes[side] = null
		_bars[side] = null


func _anim(side: int, kind: String) -> void:
	var tr: TextureRect = _sprites[side]
	if not tr.visible:
		return
	var base := tr.modulate
	match kind:
		"hit":
			for k in 3:
				tr.modulate.a = 0.0
				await get_tree().create_timer(0.06).timeout
				tr.modulate.a = base.a
				await get_tree().create_timer(0.06).timeout
		"stat_up", "stat_down":
			var c := Color(0.6, 0.8, 1.6) if kind == "stat_up" else Color(1.6, 0.6, 0.6)
			var tw := create_tween()
			tw.tween_property(tr, "modulate", c, 0.15)
			tw.tween_property(tr, "modulate", base, 0.25)
			await tw.finished
		_:
			var col: Color = {"status_psn": Color(1.3, 0.6, 1.4), "status_tox": Color(1.3, 0.6, 1.4),
				"status_par": Color(1.6, 1.5, 0.5), "status_slp": Color(0.7, 0.7, 0.8), "status_brn": Color(1.7, 0.8, 0.5),
				"status_frz": Color(0.7, 1.2, 1.7), "status_conf": Color(1.4, 1.2, 1.4)}.get(kind, Color(1.3, 1.3, 1.3))
			var tw2 := create_tween()
			tw2.tween_property(tr, "modulate", col, 0.15)
			tw2.tween_property(tr, "position:x", tr.position.x + 4, 0.05)
			tw2.tween_property(tr, "position:x", tr.position.x - 4, 0.1)
			tw2.tween_property(tr, "position:x", tr.position.x, 0.05)
			tw2.tween_property(tr, "modulate", base, 0.2)
			await tw2.finished


func _ball(shakes: int, caught: bool) -> void:
	var target: TextureRect = _sprites[1]
	var dest := target.position + Vector2(60, 70)
	_ball_spr.position = Vector2(40, 200)
	_ball_spr.rotation = 0
	_ball_spr.modulate = Color.WHITE
	_ball_spr.visible = true
	var start := _ball_spr.position
	var tw := create_tween()
	tw.tween_method(func(t: float):
		_ball_spr.position = start.lerp(dest, t) + Vector2(0, -sin(t * PI) * 90)
		_ball_spr.rotation = t * TAU * 2, 0.0, 1.0, 0.6)
	await tw.finished
	if shakes < 0:
		var tw0 := create_tween()
		tw0.tween_property(_ball_spr, "position", _ball_spr.position + Vector2(80, 60), 0.3)
		await tw0.finished
		_ball_spr.visible = false
		return
	target.modulate = Color(3, 3, 3, 1)
	await _tween_scale(target, 0.0, 0.25)
	var tw2 := create_tween()
	tw2.tween_property(_ball_spr, "position:y", dest.y + 50, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw2.finished
	for k in shakes:
		await get_tree().create_timer(0.35).timeout
		var tw3 := create_tween()
		tw3.tween_property(_ball_spr, "rotation", 0.4, 0.1)
		tw3.tween_property(_ball_spr, "rotation", -0.4, 0.2)
		tw3.tween_property(_ball_spr, "rotation", 0.0, 0.1)
		await tw3.finished
	await get_tree().create_timer(0.4).timeout
	if caught:
		_ball_spr.modulate = Color(0.6, 0.6, 0.6)
		await get_tree().create_timer(0.3).timeout
	else:
		_ball_spr.visible = false
		target.modulate = Color.WHITE
		await _tween_scale(target, 1.0, 0.2)


# ---------------------------------------------------------------------------
# Menus du joueur
# ---------------------------------------------------------------------------

func _choose_action() -> Variant:
	var lock := battle.locked_move(0)
	if lock != 0:
		return {"type": "move", "slot": -1}
	var b: Battle.Battler = battle.sides[0].b
	while true:
		_prompt.text = "Que doit faire\n%s ?" % b.mon.name()
		var i: int = await _menu(["ATTAQUE", "SAC", "POKéMON", "FUITE"], Rect2(256, 244, 220, 72), 2, false)
		match i:
			0:
				if battle.usable_slots(0).is_empty():
					return {"type": "move", "id": Battle.STRUGGLE}
				var slot: int = await _move_menu()
				if slot >= 0:
					return {"type": "move", "slot": slot}
			1:
				var bag := BagScreen.new()
				bag.mode = "battle"
				var item = await Game.ui.open(bag)
				if item == null:
					continue
				var act = await _item_action(item)
				if act != null:
					return act
			2:
				var idx: int = await _pick_switch(false)
				if idx >= 0:
					if battle.trapped(b):
						await _say("%s ne peut pas être rappelé !" % b.mon.name())
						continue
					return {"type": "switch", "index": idx}
			3:
				if not battle.wild:
					await _say("Impossible de fuir un combat de Dresseur !")
					continue
				return {"type": "run"}
	return null


func _move_menu() -> int:
	var b: Battle.Battler = battle.sides[0].b
	var ms := b.moves()
	var labels := []
	for m in ms:
		labels.append(Data.move_name(m["id"]))
	while labels.size() < 4:
		labels.append("-")
	_info = Kit.panel(self, Rect2(330, 244, 146, 72))
	_info_pp = Kit.label(_info, "", Vector2(10, 6))
	_info_type = Kit.label(_info, "", Vector2(10, 32))
	_prompt.text = ""
	var on_move := func(idx: int) -> void:
		if idx < ms.size():
			var m: Dictionary = ms[idx]
			_info_pp.text = "PP  %d/%d" % [m["pp"], m["max"]]
			var md: Dictionary = Data.moves[m["id"]]
			var typ: String = b.mon.hidden_power_type() if md["ident"] == "hidden-power" else md["type"]
			_info_type.text = "TYPE/%s" % Data.type_name(typ).to_upper()
			var eff := Data.effectiveness(typ, battle.sides[1].b.types)
			_info_type.add_theme_color_override("font_color", Color("d03030") if eff > 1.0 and md["cat"] != "status" else Color("3050c0") if eff < 1.0 and md["cat"] != "status" else Kit.INK)
		else:
			_info_pp.text = ""
			_info_type.text = ""
	while true:
		var i: int = await _menu(labels, Rect2(4, 244, 326, 72), 2, true, on_move)
		if i < 0:
			_info.queue_free()
			return -1
		if i >= ms.size():
			continue
		if ms[i]["pp"] <= 0:
			await _say("Il n'y a plus de PP pour cette capacité !")
			continue
		if not battle.can_use(b, i):
			await _say("%s ne peut pas utiliser cette capacité !" % b.mon.name())
			continue
		_info.queue_free()
		return i
	return -1


func _pick_switch(forced: bool) -> int:
	while true:
		var ps := PartyScreen.new()
		ps.mode = "battle"
		ps.forced = forced
		ps.active_index = battle.sides[0].b.party_index if battle.sides[0].b != null else -1
		var idx = await Game.ui.open(ps)
		if idx == null or idx < 0:
			if forced:
				continue
			return -1
		return idx
	return -1


func _item_action(item: String) -> Variant:
	if ItemUse.is_ball(item):
		if not battle.wild:
			await _say("Le Dresseur bloque la Ball ! Pas de vol !")
			return null
		if Game.party.size() >= Game.PARTY_MAX and Game.pc.size() >= 600:
			await _say("Il n'y a plus de place !")
			return null
		Game.remove_item(item)
		return {"type": "ball", "item": item}
	if item in ItemUse.BATTLE_ONLY:
		Game.remove_item(item)
		return {"type": "item", "item": item}
	if not ItemUse.targets_pokemon(item) or ItemUse.is_tm(item) or item in ItemUse.STONES or item == "rare-candy" or ItemUse.VITAMINS.has(item):
		await _say("Ce n'est pas le moment d'utiliser ça !")
		return null
	var ps := PartyScreen.new()
	ps.mode = "select"
	ps.item = item
	ps.title = "Sur quel Pokémon ?"
	var idx = await Game.ui.open(ps)
	if idx == null or idx < 0:
		return null
	var mon: Pokemon = Game.party[idx]
	var move_index := -1
	if ItemUse.needs_move(item):
		var opts := []
		for m in mon.moves:
			opts.append("%s %d/%d" % [Data.move_name(m["id"]), m["pp"], m["max"]])
		move_index = await Game.ui.ask("Quelle capacité ?", opts)
		if move_index < 0:
			return null
	var test := Pokemon.from_dict(mon.to_dict())
	if ItemUse.apply(test, item, move_index) == "":
		await _say("Ça n'aura aucun effet.")
		return null
	Game.remove_item(item)
	return {"type": "item", "item": item, "target": idx, "move": move_index}


## Petit menu interne au combat (curseur, A pour valider, B pour annuler si autorisé).
func _menu(labels: Array, rect: Rect2, cols: int, cancel: bool, on_move := Callable()) -> int:
	_menu_panel = Kit.panel(self, rect)
	_menu_labels = []
	var cw := (rect.size.x - 20) / cols
	for i in labels.size():
		var l := Kit.label(_menu_panel, str(labels[i]), Vector2(26 + (i % cols) * cw, 6 + (i / cols) * 26), 15)
		_menu_labels.append(l)
	_menu_cursor = Kit.label(_menu_panel, "▶", Vector2(8, 7), 14, Kit.INK, false)
	_menu_cols = cols
	_menu_cancel = cancel
	_menu_on_move = on_move
	_menu_index = mini(_menu_index, labels.size() - 1) if not cancel else 0
	_menu_set(_menu_index, cw)
	_menu_active = true
	var r: int = await _menu_done
	_menu_active = false
	_menu_panel.queue_free()
	return r


func _menu_set(i: int, cw := -1.0) -> void:
	_menu_index = clampi(i, 0, _menu_labels.size() - 1)
	var w := cw if cw > 0 else (_menu_panel.size.x - 20) / _menu_cols
	_menu_cursor.position = Vector2(8 + (_menu_index % _menu_cols) * w, 7 + (_menu_index / _menu_cols) * 26)
	if _menu_on_move.is_valid():
		_menu_on_move.call(_menu_index)


func _process(_delta: float) -> void:
	if not _menu_active:
		return
	if act("up"):
		_menu_set(_menu_index - _menu_cols)
	elif act("down"):
		_menu_set(_menu_index + _menu_cols)
	elif act("left"):
		_menu_set(_menu_index - 1)
	elif act("right"):
		_menu_set(_menu_index + 1)
	elif act("a"):
		_menu_done.emit(_menu_index)
	elif act("b") and _menu_cancel:
		_menu_done.emit(-1)
