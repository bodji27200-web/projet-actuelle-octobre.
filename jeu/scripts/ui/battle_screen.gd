class_name BattleScreen
extends Screen
## Écran de combat : simple ou double, solo ou coop. Joue les événements du moteur Battle.

const MSG_AUTO := 0.9
const BG := {
	"grass": [Color("f8f0d0"), Color("d8e8b0"), Color("b8d088"), Color("90a868")],
	"forest": [Color("c8e0b0"), Color("88b070"), Color("78a058"), Color("587840")],
	"cave": [Color("8c7860"), Color("6c5840"), Color("a08868"), Color("705838")],
	"water": [Color("c8e0f8"), Color("88b0e8"), Color("a8c8f0"), Color("6890c8")],
	"indoor": [Color("e8e0f0"), Color("c8c0d8"), Color("d8d0e8"), Color("a098b8")],
}

var battle: Battle
var bg := "grass"
## Coop : {"role": "host"/"guest", "bid": id, "local_owner": 0/1, "peer": id réseau}
var coop := {}
var _sprites := {}      # "side:slot" -> TextureRect
var _home := {}
var _sizes := {}
var _boxes := {}
var _bars := {}
var _hp_labels := {}
var _exp_bars := {}
var _shown_hp := {}
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
var _bg: Control
var _ball_spr: TextureRect
var _layout_double := false
var _fx: Control
var _weather_fx: Control
var _field_bar: Label
var _chips := {}
var _field := {}
var _weather := ""
var _terrain := ""
var _wt := 0.0
var _info_panel: Control
var _want_mega := false
var _want_z := false

signal _menu_done(index: int)


func _ready() -> void:
	size = Vector2(480, 320)
	_bg = Control.new()
	_bg.size = Vector2(480, 320)
	_bg.draw.connect(_draw_bg)
	add_child(_bg)
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
	# Couches d'effets : météo (en continu) et animations des capacités.
	_weather_fx = Control.new()
	_weather_fx.size = Vector2(480, 244)
	_weather_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_fx.draw.connect(_draw_weather)
	add_child(_weather_fx)
	_fx = Control.new()
	_fx.size = Vector2(480, 320)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	set_meta("fx_layer", _fx)
	var strip := ColorRect.new()
	strip.color = Color(0, 0, 0, 0.35)
	strip.position = Vector2(0, 0)
	strip.size = Vector2(480, 13)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.visible = false
	add_child(strip)
	set_meta("strip", strip)
	_field_bar = Kit.label(self, "", Vector2(6, -2), 10, Color.WHITE, false)
	_field_bar.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_field_bar.add_theme_constant_override("shadow_offset_x", 1)
	_field_bar.add_theme_constant_override("shadow_offset_y", 1)
	move_child(_bottom, -1)
	_run()


func role() -> String:
	return coop.get("role", "solo")


func local_owner() -> int:
	return coop.get("local_owner", 0)


func _key(side: int, slot: int) -> String:
	return "%d:%d" % [side, slot]


# ---------------------------------------------------------------------------
# Disposition
# ---------------------------------------------------------------------------

func _setup_layout() -> void:
	_layout_double = battle.is_double()
	for k in _sprites:
		_sprites[k].queue_free()
	_sprites.clear()
	for side in 2:
		var n: int = battle.sides[side].slots.size()
		for slot in n:
			var tr := TextureRect.new()
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var sz: float
			var pos: Vector2
			if side == 1:
				sz = 144.0 if n == 1 else 112.0
				pos = Vector2(292, 14) if n == 1 else Vector2(250 + slot * 100, 30 - slot * 14)
			else:
				sz = 192.0 if n == 1 else 150.0
				pos = Vector2(34, 92) if n == 1 else Vector2(0 + slot * 120, 110 + slot * 8)
			tr.size = Vector2(sz, sz)
			tr.position = pos
			tr.pivot_offset = tr.size / 2
			tr.visible = false
			add_child(tr)
			move_child(tr, _weather_fx.get_index())
			var k := _key(side, slot)
			_sprites[k] = tr
			_home[k] = pos
			_sizes[k] = sz
	_bg.queue_redraw()


## Changements de stats visibles sous le nom : « ATQ+2 VIT-1 » (rouge = hausse, bleu = baisse).
func _update_chip(k: String) -> void:
	if not _chips.has(k) or not is_instance_valid(_chips[k]):
		return
	var parts: PackedStringArray = k.split(":")
	var b := battle.battler(int(parts[0]), int(parts[1]))
	if b == null:
		return
	var names := {"atk": "ATQ", "def": "DÉF", "spa": "A.SP", "spd": "D.SP", "spe": "VIT", "acc": "PRÉ", "eva": "ESQ"}
	var txt := []
	var up := 0
	var down := 0
	for key in ["atk", "def", "spa", "spd", "spe", "acc", "eva"]:
		var v: int = b.stages[key]
		if v != 0:
			txt.append("%s%s%d" % [names[key], "+" if v > 0 else "", v])
			if v > 0:
				up += 1
			else:
				down += 1
	if b.confusion > 0:
		txt.append("CONF")
	if b.substitute > 0:
		txt.append("CLONE")
	if b.mega:
		txt.append("MÉGA")
	var chip: Label = _chips[k]
	chip.text = " ".join(txt)
	chip.add_theme_color_override("font_color", Color("c03020") if up > 0 and down == 0 else Color("2048c0") if down > 0 and up == 0 else Color("704070"))


## Barre d'état du terrain : météo, champ, Distorsion, Gravité, protections et pièges de chaque camp.
func _update_field() -> void:
	for k in _chips:
		_update_chip(k)
	var parts := []
	if battle.weather != "":
		parts.append(Battle.WEATHER_NAMES.get(battle.weather, battle.weather))
	if battle.terrain != "":
		parts.append(Battle.TERRAIN_NAMES.get(battle.terrain, battle.terrain))
	if battle.trick_room > 0:
		parts.append("Distorsion")
	if battle.gravity > 0:
		parts.append("Gravité")
	for s in 2:
		var side: Battle.BSide = battle.sides[s]
		var sp := []
		if side.reflect > 0:
			sp.append("Protection")
		if side.light_screen > 0:
			sp.append("Mur Lumière")
		if side.aurora_veil > 0:
			sp.append("Voile Aurore")
		if side.tailwind > 0:
			sp.append("Vent Arrière")
		if side.stealth_rock:
			sp.append("Piège de Roc")
		if side.spikes > 0:
			sp.append("Picots x%d" % side.spikes)
		if side.toxic_spikes > 0:
			sp.append("Pics Toxik x%d" % side.toxic_spikes)
		if side.sticky_web:
			sp.append("Toile Gluante")
		if sp.size() > 0:
			parts.append(("Vous : " if s == 0 else "Adversaire : ") + ", ".join(sp))
	_field_bar.text = "  |  ".join(parts)
	get_meta("strip").visible = parts.size() > 0
	_weather = battle.weather
	if _terrain != battle.terrain:
		_terrain = battle.terrain
		_bg.queue_redraw()


func _draw_weather() -> void:
	match _weather:
		"rain", "heavy-rain":
			for i in 40:
				var x := fmod(i * 53.0 + _wt * 300.0, 520.0) - 20.0
				var y := fmod(i * 37.0 + _wt * 420.0, 250.0)
				_weather_fx.draw_line(Vector2(x, y), Vector2(x - 4, y + 10), Color(0.6, 0.7, 1.0, 0.6), 1.0)
		"snow", "hail":
			for i in 34:
				var x2 := fmod(i * 61.0 + sin(_wt * 2.0 + i) * 10.0, 480.0)
				var y2 := fmod(i * 29.0 + _wt * 50.0, 244.0)
				_weather_fx.draw_rect(Rect2(x2, y2, 2, 2), Color(1, 1, 1, 0.85))
		"sandstorm":
			for i in 40:
				var x3 := fmod(i * 47.0 + _wt * 380.0, 500.0) - 10.0
				var y3 := fmod(i * 23.0, 244.0)
				_weather_fx.draw_line(Vector2(x3, y3), Vector2(x3 + 8, y3 + 1), Color(0.85, 0.7, 0.45, 0.6), 1.0)
		"sun", "harsh-sun":
			_weather_fx.draw_rect(Rect2(0, 0, 480, 244), Color(1.0, 0.85, 0.4, 0.10 + 0.03 * sin(_wt * 3.0)))
		"strong-winds":
			for i in 20:
				var x4 := fmod(i * 71.0 + _wt * 500.0, 520.0) - 20.0
				_weather_fx.draw_line(Vector2(x4, 20 + i * 11), Vector2(x4 + 22, 20 + i * 11), Color(0.9, 0.9, 1.0, 0.4), 1.0)


func _draw_bg() -> void:
	var c: Array = BG.get(bg, BG["grass"])
	_bg.draw_rect(Rect2(0, 0, 480, 140), c[0])
	_bg.draw_rect(Rect2(0, 140, 480, 180), c[1])
	for i in 6:
		_bg.draw_rect(Rect2(0, 20 + i * 18, 480, 2), c[0].darkened(0.04))
	if _terrain != "":
		var tc: Color = {"electric": Color(1.0, 0.95, 0.4, 0.35), "grassy": Color(0.4, 0.9, 0.4, 0.35), "misty": Color(1.0, 0.7, 0.9, 0.35),
			"psychic": Color(0.9, 0.5, 1.0, 0.35)}.get(_terrain, Color.TRANSPARENT)
		_bg.draw_rect(Rect2(0, 140, 480, 180), tc)
	if _layout_double:
		_ellipse(Vector2(350, 140), Vector2(120, 24), c[2], c[3])
		_ellipse(Vector2(150, 262), Vector2(150, 28), c[2], c[3])
	else:
		_ellipse(Vector2(364, 150), Vector2(92, 22), c[2], c[3])
		_ellipse(Vector2(130, 262), Vector2(110, 26), c[2], c[3])


func _ellipse(c: Vector2, r: Vector2, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_bg.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	_bg.draw_polyline(pts, edge, 2.0)


func _box_rect(side: int, slot: int) -> Rect2:
	if not _layout_double:
		return Rect2(12, 14, 214, 52) if side == 1 else Rect2(256, 160, 216, 72)
	if side == 1:
		return Rect2(6, 16 + slot * 50, 200, 46)
	return Rect2(272, 146 + slot * 48, 204, 46)


func _make_box(side: int, slot: int) -> void:
	var k := _key(side, slot)
	if _boxes.has(k) and is_instance_valid(_boxes[k]):
		_boxes[k].queue_free()
	var b: Battle.Battler = battle.battler(side, slot)
	if b == null:
		return
	var mon := b.mon
	var rect := _box_rect(side, slot)
	var mine := side == 0 and b.owner == local_owner()
	var p := Kit.panel(self, rect, Color("f8f8e0") if mine or side == 1 else Color("e8f0f8"), Color("506050"))
	move_child(p, _bottom.get_index())
	_boxes[k] = p
	var small := _layout_double
	var fs := 13 if small else 15
	var ty := 0 if small else 2
	Kit.name_line(p, mon, Vector2(10, ty), fs)
	var lv := "N.%d" % mon.level
	Kit.label(p, lv, Vector2(rect.size.x - 12 - Kit.text_width(lv, fs), ty), fs)
	Kit.label(p, "PV", Vector2(40, 14 if small else 22), 11, Color("e0a020"), false)
	var bar_w := rect.size.x - 82
	_bars[k] = Kit.hp_bar(p, Vector2(62, 19 if small else 26), bar_w, float(mon.hp) / mon.max_hp())
	_shown_hp[k] = mon.hp
	Kit.status_tag(p, mon.status, Vector2(4, 21 if small else 24))
	if side == 1 and Game.caught.has(mon.species) and not mon.boss:
		var ball := TextureRect.new()
		ball.texture = PixelArt.ball()
		ball.position = Vector2(rect.size.x - 20, 26)
		ball.size = Vector2(12, 12)
		p.add_child(ball)
	if side == 1 and mon.boss:
		Kit.label(p, "BOSS", Vector2(rect.size.x - 54, 28 if small else 32), 11, Color("c02020"), false)
	var chip := Kit.label(p, "", Vector2(10 if side == 1 else 8, 30 if small else 36), 10, Color("303030"), false)
	chip.clip_text = true
	chip.size = Vector2(rect.size.x - 20 if side == 1 else 108.0, 14)
	_chips[k] = chip
	_update_chip(k)
	if side == 0:
		if small:
			if not mine:
				Kit.label(p, battle.owner_name(0, b.owner), Vector2(10, 26), 10, Color("406080"), false)
			_hp_labels[k] = Kit.label(p, "%d/%d" % [mon.hp, mon.max_hp()], Vector2(rect.size.x - 70, 25), 10)
		else:
			_hp_labels[k] = Kit.label(p, "%d/%d" % [mon.hp, mon.max_hp()], Vector2(120, 34), 15)
		if mine:
			var bg2 := ColorRect.new()
			bg2.position = Vector2(30, rect.size.y - 6 if small else 58)
			bg2.size = Vector2(rect.size.x - 110 if small else rect.size.x - 46, 3 if small else 5)
			bg2.color = Color("404848")
			p.add_child(bg2)
			var e := ColorRect.new()
			e.position = Vector2(1, 1)
			e.size = Vector2((bg2.size.x - 2) * mon.exp_progress(), bg2.size.y - 2)
			e.color = Color("48a0f8")
			e.set_meta("full", bg2.size.x - 2)
			bg2.add_child(e)
			_exp_bars[k] = e


func _set_sprite(side: int, slot: int, mon: Pokemon, species := 0, shiny := false) -> void:
	var k := _key(side, slot)
	var tr: TextureRect = _sprites[k]
	var sid := species if species != 0 else mon.sprite_id()
	var sh := shiny if species != 0 else mon.shiny
	Sprites.apply(tr, "back" if side == 0 else "front", sid, sh, PixelArt.placeholder())
	tr.modulate = Color.WHITE
	tr.position = _home[k]
	tr.scale = Vector2.ONE * (1.25 if mon.boss else 1.0)
	tr.visible = true


# ---------------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------------

func _run() -> void:
	await get_tree().process_frame
	if role() == "guest":
		await _guest_loop()
		return
	_setup_layout()
	var evs := battle.start()
	_share(evs)
	await _play(evs)
	while not battle.over:
		if battle.need_switch.size() > 0:
			var n: Dictionary = battle.need_switch[0]
			var idx: int
			if role() == "host" and n["owner"] != local_owner():
				_prompt.text = "En attente de %s..." % battle.owner_name(0, n["owner"])
				Net.ask_switch(coop["bid"], coop["peer"], n["slot"], battle)
				var a: Dictionary = await Net.wait_action(coop["bid"], 100 + n["slot"], coop["peer"])
				idx = a.get("index", -1)
				var bench := battle.bench(0, n["owner"])
				if not bench.has(idx):
					idx = bench[0] if bench.size() > 0 else -1
			else:
				idx = await _pick_switch(n["slot"], true)
			if idx < 0:
				battle.need_switch.erase(n)
				continue
			evs = battle.player_switch(n["slot"], idx)
			_share(evs)
			await _play(evs)
			continue
		var acts := {}
		var remote_slots := []
		for k in battle.sides[0].slots.size():
			var b := battle.battler(0, k)
			if b == null or not b.alive():
				continue
			if b.owner == local_owner():
				var a2 = await _choose_action(k)
				acts[k] = a2
				if a2.get("type", "") in ["run"]:
					break
			else:
				remote_slots.append(k)
		if role() == "host" and remote_slots.size() > 0 and not acts.values().any(func(x): return x.get("type", "") == "run"):
			_prompt.text = "En attente de %s..." % battle.owner_name(0, 1)
			Net.ask_actions(coop["bid"], coop["peer"], remote_slots, battle)
			for k in remote_slots:
				acts[k] = await Net.wait_action(coop["bid"], k, coop["peer"])
		_prompt.text = ""
		evs = battle.play_turn(acts)
		_share(evs)
		await _play(evs)
	await get_tree().create_timer(0.3).timeout
	finish(battle.result)


func _share(evs: Array) -> void:
	if role() == "host":
		Net.send_events(coop["bid"], coop["peer"], evs, battle)


## Invité : affiche ce que l'hôte envoie et répond quand on lui demande d'agir.
func _guest_loop() -> void:
	var first := true
	while true:
		var m: Dictionary = await Net.next_coop(coop["bid"])
		match m["kind"]:
			"lost":
				await _say("La connexion avec ton partenaire a été perdue...")
				finish("run")
				return
			"events":
				battle.apply_snapshot(m["data"]["snap"])
				_sync_party()
				if first:
					_setup_layout()
					first = false
				await _play(m["data"]["events"])
			"ask":
				battle.apply_snapshot(m["data"]["snap"])
				_sync_party()
				for k in m["data"]["slots"]:
					var a = await _choose_action(k)
					Net.send_action(coop["bid"], coop["peer"], k, a)
				_prompt.text = "En attente de %s..." % battle.owner_name(0, 0)
			"switch":
				battle.apply_snapshot(m["data"]["snap"])
				_sync_party()
				var idx := await _pick_switch(m["data"]["slot"], true)
				Net.send_action(coop["bid"], coop["peer"], 100 + m["data"]["slot"], {"index": idx})
			"end":
				coop["end"] = m["data"]
				await get_tree().create_timer(0.3).timeout
				finish(m["data"]["result"])
				return


## Invité : l'écran Équipe montre l'état réel (copie reçue de l'hôte).
func _sync_party() -> void:
	if role() != "guest":
		return
	var mine := []
	for i in battle.sides[0].party.size():
		if battle.sides[0].owners[i] == local_owner():
			mine.append(battle.sides[0].party[i])
	if not mine.is_empty():
		Game.party = mine


func _offset() -> int:
	var o := 0
	for i in battle.sides[0].owners.size():
		if battle.sides[0].owners[i] < local_owner():
			o += 1
	return o


func _say(text: String) -> void:
	_prompt.text = ""
	await Game.ui.say(text, MSG_AUTO)


func _play(events: Array) -> void:
	var i := 0
	while i < events.size():
		var e: Dictionary = events[i]
		var k := _key(e.get("side", 0), e.get("slot", 0))
		match e["t"]:
			"msg":
				await _say(e["text"])
			"trainer_say":
				await _say(e["text"])
			"send":
				var mon: Pokemon = battle.sides[e["side"]].party[e["index"]] if e.has("index") and e["index"] < battle.sides[e["side"]].party.size() else e.get("mon")
				if mon == null:
					i += 1
					continue
				if not _sprites.has(k):
					_setup_layout()
				_set_sprite(e["side"], e["slot"], mon)
				_make_box(e["side"], e["slot"])
				if Game.settings.get("cries", true):
					Audio.cry(mon.sprite_id())
				await _appear(k, mon)
			"recall":
				if _sprites.has(k):
					await _tween_scale(_sprites[k], 0.0, 0.25)
					_sprites[k].visible = false
			"hp":
				await _anim_hp(k, e["hp"], e["max"])
			"faint":
				Audio.sfx("faint")
				await _faint(k)
			"anim":
				await _anim(k, e["kind"])
			"refresh":
				for key in _boxes.keys():
					var parts: PackedStringArray = key.split(":")
					var b := battle.battler(int(parts[0]), int(parts[1]))
					if b != null and b.alive() and is_instance_valid(_boxes[key]):
						var keep: int = _shown_hp.get(key, b.mon.hp)
						_make_box(int(parts[0]), int(parts[1]))
						_shown_hp[key] = keep
						_update_hp_display(key, keep, b.mon.max_hp())
			"exp":
				if e["active"] and e.get("owner", 0) == local_owner():
					var sk := _key(0, e["slot"])
					var levels_follow := false
					for j in range(i + 1, events.size()):
						if events[j]["t"] == "level" and events[j]["index"] == e["index"]:
							levels_follow = true
							break
					var mon2: Pokemon = battle.sides[0].party[e["index"]]
					Audio.sfx("exp")
					await _tween_exp(sk, 1.0 if levels_follow else mon2.exp_progress())
			"level":
				if e["active"]:
					var sk2 := _key(0, e["slot"])
					var keep_hp: int = _shown_hp.get(sk2, 0)
					_make_box(0, e["slot"])
					_shown_hp[sk2] = keep_hp
					var b2 := battle.battler(0, e["slot"])
					if b2 != null:
						_update_hp_display(sk2, keep_hp, b2.mon.max_hp())
					if _exp_bars.has(sk2) and is_instance_valid(_exp_bars[sk2]):
						_exp_bars[sk2].size.x = 0
					if e.get("owner", 0) == local_owner():
						Audio.jingle("levelup")
						var last := true
						for j in range(i + 1, events.size()):
							if events[j]["t"] == "level" and events[j]["index"] == e["index"]:
								last = false
								break
						if last:
							await _tween_exp(sk2, battle.sides[0].party[e["index"]].exp_progress())
			"learn":
				if e.get("owner", 0) == local_owner():
					if role() == "guest":
						if not coop.has("learn"):
							coop["learn"] = []
						coop["learn"].append({"index": e["index"] - _offset(), "move": e["move"]})
					else:
						await Events.learn_move(battle.sides[0].party[e["index"]], e["move"])
			"ball":
				await _ball(_key(1, e.get("slot", 0)), e["shakes"], e["caught"])
			"hide":
				if _sprites.has(k):
					_sprites[k].visible = not e["on"]
			"sub":
				if _sprites.has(k):
					_sprites[k].modulate.a = 0.55 if e["on"] else 1.0
			"transform":
				if _sprites.has(k):
					Sprites.apply(_sprites[k], "back" if e["side"] == 0 else "front", e["species"], e["shiny"], PixelArt.placeholder())
			"form":
				if _sprites.has(k) and _sprites[k].visible:
					Sprites.apply(_sprites[k], "back" if e["side"] == 0 else "front", e["sprite"], e.get("shiny", false), PixelArt.placeholder())
					if not e.get("reset", false):
						var keep2: int = _shown_hp.get(k, 0)
						_make_box(e["side"], e["slot"])
						_shown_hp[k] = keep2
			"move_anim":
				if Game.settings.get("animations", true):
					var uk := _key(e["side"], e["slot"])
					var tk := _key(e["tside"], e["tslot"])
					await MoveFx.play(self, _fx, _sprites.get(uk), _sprites.get(tk, _sprites.get(uk)), e)
			"field":
				_field = e
				_update_field()
			"weather":
				_weather = e.get("w", "")
			"terrain":
				_terrain = e.get("terrain", "")
				_bg.queue_redraw()
		i += 1


# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------

func _appear(k: String, mon: Pokemon) -> void:
	var tr: TextureRect = _sprites[k]
	var target := tr.scale
	tr.scale = Vector2(0.1, 0.1)
	tr.modulate = Color(3, 3, 3, 1)
	var tw := create_tween().set_parallel()
	tw.tween_property(tr, "scale", target, 0.3)
	tw.tween_property(tr, "modulate", Color.WHITE, 0.45)
	await tw.finished
	if mon.shiny:
		Audio.sfx("shiny")
		for n in 3:
			tr.modulate = Color(1.6, 1.6, 0.8)
			await get_tree().create_timer(0.08).timeout
			tr.modulate = Color.WHITE
			await get_tree().create_timer(0.08).timeout


func _tween_scale(node: Control, s: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(s, s), t)
	await tw.finished


func _anim_hp(k: String, hp: int, mx: int) -> void:
	if not _bars.has(k) or not is_instance_valid(_bars[k]):
		return
	var from: int = _shown_hp.get(k, hp)
	if hp < from:
		Audio.sfx("hit")
	var tw := create_tween()
	tw.tween_method(func(v: float): _update_hp_display(k, int(round(v)), mx), float(from), float(hp), clampf(absf(hp - from) / float(maxi(1, mx)) * 1.2, 0.15, 0.8))
	await tw.finished
	_shown_hp[k] = hp


func _update_hp_display(k: String, hp: int, mx: int) -> void:
	if not _bars.has(k) or not is_instance_valid(_bars[k]):
		return
	Kit.set_bar(_bars[k], float(hp) / maxf(1, mx))
	if _hp_labels.has(k) and is_instance_valid(_hp_labels[k]):
		_hp_labels[k].text = "%d/%d" % [hp, mx]


func _tween_exp(k: String, ratio: float) -> void:
	if not _exp_bars.has(k) or not is_instance_valid(_exp_bars[k]):
		return
	var e: ColorRect = _exp_bars[k]
	var tw := create_tween()
	tw.tween_property(e, "size:x", e.get_meta("full") * ratio, 0.6)
	await tw.finished


func _faint(k: String) -> void:
	if not _sprites.has(k):
		return
	var tr: TextureRect = _sprites[k]
	var tw := create_tween().set_parallel()
	tw.tween_property(tr, "position:y", tr.position.y + 80, 0.4)
	tw.tween_property(tr, "modulate:a", 0.0, 0.4)
	await tw.finished
	tr.visible = false
	if _boxes.has(k) and is_instance_valid(_boxes[k]):
		_boxes[k].queue_free()
	_boxes.erase(k)
	_bars.erase(k)


func _anim(k: String, kind: String) -> void:
	if not _sprites.has(k):
		return
	var tr: TextureRect = _sprites[k]
	if not tr.visible or not Game.settings.get("animations", true):
		return
	var base := tr.modulate
	if kind.begins_with("status_"):
		MoveFx.status(self, _fx, tr, kind)
	match kind:
		"mega":
			await MoveFx.mega(self, _fx, tr)
			return
		"zmove":
			await MoveFx.z_aura(self, _fx, tr)
			return
		"hit":
			for n in 3:
				tr.modulate.a = 0.0
				await get_tree().create_timer(0.06).timeout
				tr.modulate.a = base.a
				await get_tree().create_timer(0.06).timeout
		"stat_up", "stat_down":
			Audio.sfx(kind)
			var c := Color(0.6, 0.8, 1.6) if kind == "stat_up" else Color(1.6, 0.6, 0.6)
			var tw := create_tween()
			tw.tween_property(tr, "modulate", c, 0.15)
			tw.tween_property(tr, "modulate", base, 0.25)
			await tw.finished
		_:
			if kind.begins_with("aura_"):
				var ac: Color = {"aura_fire": Color(1.6, 0.8, 0.5), "aura_steel": Color(1.2, 1.2, 1.5), "aura_electric": Color(1.6, 1.5, 0.6),
					"aura_ghost": Color(1.0, 0.7, 1.5), "aura_dragon": Color(1.1, 0.8, 1.7), "aura_grass": Color(0.8, 1.6, 0.8),
					"aura_dark": Color(0.7, 0.6, 0.8)}.get(kind, Color(1.4, 1.4, 1.4))
				tr.set_meta("aura", ac)
				var tw3 := create_tween()
				tw3.tween_property(tr, "modulate", ac, 0.3)
				await tw3.finished
				return
			var col: Color = {"status_psn": Color(1.3, 0.6, 1.4), "status_tox": Color(1.3, 0.6, 1.4),
				"status_par": Color(1.6, 1.5, 0.5), "status_slp": Color(0.7, 0.7, 0.8), "status_brn": Color(1.7, 0.8, 0.5),
				"status_frz": Color(0.7, 1.2, 1.7), "status_conf": Color(1.4, 1.2, 1.4)}.get(kind, Color(1.3, 1.3, 1.3))
			var x0 := tr.position.x
			var tw2 := create_tween()
			tw2.tween_property(tr, "modulate", col, 0.15)
			tw2.tween_property(tr, "position:x", x0 + 4, 0.05)
			tw2.tween_property(tr, "position:x", x0 - 4, 0.1)
			tw2.tween_property(tr, "position:x", x0, 0.05)
			tw2.tween_property(tr, "modulate", base, 0.2)
			await tw2.finished


func _ball(k: String, shakes: int, caught: bool) -> void:
	if not _sprites.has(k):
		k = _key(1, 0)
	var target: TextureRect = _sprites[k]
	var dest := target.position + target.size * Vector2(0.42, 0.5)
	_ball_spr.position = Vector2(40, 200)
	_ball_spr.rotation = 0
	_ball_spr.modulate = Color.WHITE
	_ball_spr.visible = true
	var start := _ball_spr.position
	Audio.sfx("throw")
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
	var scale0 := target.scale
	await _tween_scale(target, 0.0, 0.25)
	var tw2 := create_tween()
	tw2.tween_property(_ball_spr, "position:y", dest.y + 40, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw2.finished
	for n in shakes:
		await get_tree().create_timer(0.35).timeout
		Audio.sfx("shake")
		var tw3 := create_tween()
		tw3.tween_property(_ball_spr, "rotation", 0.4, 0.1)
		tw3.tween_property(_ball_spr, "rotation", -0.4, 0.2)
		tw3.tween_property(_ball_spr, "rotation", 0.0, 0.1)
		await tw3.finished
	await get_tree().create_timer(0.4).timeout
	if caught:
		_ball_spr.modulate = Color(0.6, 0.6, 0.6)
		Audio.sfx("click")
		await get_tree().create_timer(0.3).timeout
	else:
		Audio.sfx("break_free")
		_ball_spr.visible = false
		target.modulate = Color.WHITE
		await _tween_scale(target, scale0.x, 0.2)


# ---------------------------------------------------------------------------
# Menus du joueur
# ---------------------------------------------------------------------------

func _choose_action(slot: int) -> Dictionary:
	var lock := battle.locked_move(0, slot)
	if lock != 0:
		return {"type": "move", "slot": -1}
	var b := battle.battler(0, slot)
	while true:
		_prompt.text = "Que doit faire\n%s ?" % b.mon.name()
		var i: int = await _menu(["ATTAQUE", "SAC", "POKéMON", "FUITE", "INFOS"], Rect2(256, 244, 220, 72), 2, false)
		match i:
			4:
				await _show_info()
				continue
			0:
				if battle.usable_slots(0, slot).is_empty():
					return {"type": "move", "id": Battle.STRUGGLE}
				var ms: int = await _move_menu(slot)
				if ms >= 0:
					var target = await _pick_target(b, Data.moves[b.moves()[ms]["id"]])
					if target == null:
						continue
					var a := {"type": "move", "slot": ms}
					a.merge(target)
					if _want_mega and battle.can_mega_evolve(b):
						a["mega"] = true
					if _want_z and battle.can_z_move(b, b.moves()[ms]["id"]):
						a["z"] = true
					_want_mega = false
					_want_z = false
					return a
			1:
				var bag := BagScreen.new()
				bag.mode = "battle"
				var item = await Game.ui.open(bag)
				if item == null:
					continue
				var act = await _item_action(item, b)
				if act != null:
					return act
			2:
				var idx: int = await _pick_switch(slot, false)
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
	return {}


## Choix de la cible quand il y a plusieurs Pokémon possibles. Renvoie {} si inutile, null si annulé.
func _pick_target(b: Battle.Battler, m: Dictionary) -> Variant:
	var tgt: String = m["target"]
	if not battle.is_double() or tgt in Battle.SELF_TARGETS or tgt in Battle.SPREAD_TARGETS or tgt in ["entire-field", "opponents-field", "all-pokemon"]:
		return {}
	var options := []
	var labels := []
	for f: Battle.Battler in battle.foes(b):
		options.append({"target_side": 1, "target_slot": f.slot})
		labels.append(f.mon.name())
	var al := battle.ally(b)
	if al != null and m["cat"] != "status":
		options.append({"target_side": 0, "target_slot": al.slot})
		labels.append(al.mon.name() + " (allié)")
	if options.size() <= 1:
		return options[0] if options.size() == 1 else {}
	_prompt.text = "Quelle cible ?"
	var i: int = await _menu(labels, Rect2(256, 244, 220, 72), 1, true)
	if i < 0:
		return null
	return options[i]


## Fiche détaillée du combat : stats modifiées, statuts, objets connus, effets de terrain.
func _show_info() -> void:
	_info_panel = Kit.panel(self, Rect2(6, 6, 468, 308), Color("f8f8f0"), Color("4870a0"))
	var y := 6
	Kit.label(_info_panel, "ÉTAT DU COMBAT", Vector2(10, y), 15, Color("4870a0"))
	y += 22
	var head := []
	if battle.weather != "":
		head.append("Météo : %s (%d tours)" % [Battle.WEATHER_NAMES.get(battle.weather, battle.weather), battle.weather_turns])
	if battle.terrain != "":
		head.append("%s (%d tours)" % [Battle.TERRAIN_NAMES.get(battle.terrain, battle.terrain), battle.terrain_turns])
	if battle.trick_room > 0:
		head.append("Distorsion (%d)" % battle.trick_room)
	Kit.label(_info_panel, " | ".join(head) if head.size() > 0 else "Aucun effet de terrain.", Vector2(10, y), 11)
	y += 18
	var names := {"atk": "Atq", "def": "Déf", "spa": "AtqS", "spd": "DéfS", "spe": "Vit", "acc": "Pré", "eva": "Esq"}
	for s in [1, 0]:
		for bt: Battle.Battler in battle.sides[s].slots:
			if bt == null or not bt.alive():
				continue
			var st := []
			for key in ["atk", "def", "spa", "spd", "spe", "acc", "eva"]:
				var v: int = bt.stages[key]
				st.append("%s %s%d" % [names[key], "+" if v > 0 else "", v])
			var extra := []
			if bt.mon.status != "":
				extra.append({"psn": "Empoisonné", "tox": "Gravement empoisonné", "par": "Paralysé", "slp": "Endormi", "brn": "Brûlé", "frz": "Gelé"}.get(bt.mon.status, ""))
			if bt.confusion > 0:
				extra.append("Confus")
			if bt.seeded:
				extra.append("Vampigraine")
			if bt.substitute > 0:
				extra.append("Clone")
			if bt.taunt > 0:
				extra.append("Provoqué")
			if bt.encore_turns > 0:
				extra.append("Encore")
			if bt.trap_turns > 0:
				extra.append("Piégé")
			if bt.side == 0 and bt.item != "":
				extra.append("Objet : " + Data.item_name(bt.item))
			if bt.side == 0:
				extra.append("Talent : " + Data.ability_name(bt.ability))
			var title := "%s %s N.%d — %s" % ["◀" if s == 1 else "▶", bt.mon.name(), bt.mon.level, " / ".join(bt.types.map(func(t): return Data.type_name(t)))]
			Kit.label(_info_panel, title, Vector2(10, y), 13, Color("c03020") if s == 1 else Color("2048c0"))
			y += 18
			Kit.label(_info_panel, "  ".join(st), Vector2(18, y), 11)
			y += 15
			if extra.size() > 0:
				var l := Kit.label(_info_panel, "", Vector2(18, y), 11, Color("606060"))
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.size = Vector2(440, 30)
				l.text = ", ".join(extra)
				y += 16
			y += 4
	for s in 2:
		var side: Battle.BSide = battle.sides[s]
		var sp := []
		for pair in [["reflect", "Protection"], ["light_screen", "Mur Lumière"], ["aurora_veil", "Voile Aurore"], ["tailwind", "Vent Arrière"],
				["safeguard", "Rune Protect"], ["mist", "Brume"]]:
			if side.get(pair[0]) > 0:
				sp.append("%s (%d)" % [pair[1], side.get(pair[0])])
		if side.stealth_rock:
			sp.append("Piège de Roc")
		if side.spikes > 0:
			sp.append("Picots x%d" % side.spikes)
		if side.toxic_spikes > 0:
			sp.append("Pics Toxik x%d" % side.toxic_spikes)
		if side.sticky_web:
			sp.append("Toile Gluante")
		if sp.size() > 0:
			Kit.label(_info_panel, ("Votre camp : " if s == 0 else "Camp adverse : ") + ", ".join(sp), Vector2(10, mini(y, 270)), 11, Color("806040"))
			y += 16
	Kit.label(_info_panel, "A / B : fermer", Vector2(370, 290), 10, Color("808080"), false)
	await _menu_done


func _move_menu(slot: int) -> int:
	var b := battle.battler(0, slot)
	var ms := b.moves()
	var labels := []
	for m in ms:
		var md: Dictionary = Data.moves[m["id"]]
		if _want_z and battle.can_z_move(b, m["id"]):
			labels.append(battle.z_move(b, md)["name"])
		else:
			labels.append(Data.move_name(m["id"]))
	while labels.size() < 4:
		labels.append("-")
	var mega_ok := battle.can_mega_evolve(b)
	var z_ok := false
	for m2 in ms:
		if battle.can_z_move(b, m2["id"]):
			z_ok = true
	if mega_ok:
		labels.append("◆ MÉGA : %s" % ("OUI" if _want_mega else "NON"))
	if z_ok:
		labels.append("◆ CAPACITÉ Z : %s" % ("OUI" if _want_z else "NON"))
	_info = Kit.panel(self, Rect2(330, 244, 146, 72))
	_info_pp = Kit.label(_info, "", Vector2(10, 6))
	_info_type = Kit.label(_info, "", Vector2(10, 32))
	_prompt.text = ""
	var foe_types: Array = battle.foe(b).types if battle.foe(b) != null else []
	var on_move := func(idx: int) -> void:
		if idx < ms.size():
			var m: Dictionary = ms[idx]
			_info_pp.text = "PP  %d/%d" % [m["pp"], m["max"]]
			var md: Dictionary = Data.moves[m["id"]]
			var typ: String = b.mon.hidden_power_type() if md["ident"] == "hidden-power" else md["type"]
			_info_type.text = "TYPE/%s" % Data.type_name(typ).to_upper()
			var eff := Data.effectiveness(typ, foe_types)
			_info_type.add_theme_color_override("font_color", Color("d03030") if eff > 1.0 and md["cat"] != "status" else Color("3050c0") if eff < 1.0 and md["cat"] != "status" else Kit.INK)
		else:
			_info_pp.text = ""
			_info_type.text = ""
	while true:
		var i: int = await _menu(labels, Rect2(4, 244, 326, 72), 2, true, on_move)
		if i < 0:
			_info.queue_free()
			_want_mega = false
			_want_z = false
			return -1
		if i >= 4:
			# Bascule Méga / Z puis on rouvre le menu.
			var is_mega: bool = mega_ok and i == 4
			if is_mega:
				_want_mega = not _want_mega
			else:
				_want_z = not _want_z
			_info.queue_free()
			return await _move_menu(slot)
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


## Choisit un Pokémon de réserve pour l'emplacement `slot`. Renvoie l'indice dans l'équipe du combat.
func _pick_switch(slot: int, forced: bool) -> int:
	var off := _offset()
	var on_field := []
	for b: Battle.Battler in battle.sides[0].slots:
		if b != null and b.alive() and b.owner == local_owner():
			on_field.append(b.party_index - off)
	while true:
		var ps := PartyScreen.new()
		ps.mode = "battle"
		ps.forced = forced
		ps.active_index = on_field[0] if on_field.size() > 0 else -1
		ps.blocked = on_field
		var idx = await Game.ui.open(ps)
		if idx == null or idx < 0:
			if forced:
				if battle.bench(0, local_owner()).is_empty():
					return -1
				continue
			return -1
		return idx + off
	return -1


func _item_action(item: String, b: Battle.Battler) -> Variant:
	if ItemUse.is_ball(item):
		if not battle.wild:
			await _say("Le Dresseur bloque la Ball ! Pas de vol !")
			return null
		var foes := battle.foes(b)
		var target_slot: int = foes[0].slot if foes.size() > 0 else 0
		if foes.size() > 1:
			_prompt.text = "Sur quel Pokémon ?"
			var i: int = await _menu(foes.map(func(f): return f.mon.name()), Rect2(256, 244, 220, 72), 1, true)
			if i < 0:
				return null
			target_slot = foes[i].slot
		Game.remove_item(item)
		return {"type": "ball", "item": item, "target": target_slot}
	if item in ItemUse.BATTLE_ONLY:
		Game.remove_item(item)
		return {"type": "item", "item": item}
	if not ItemUse.targets_pokemon(item) or ItemUse.is_tm(item) or ItemUse.is_evo_item(item) or item == "rare-candy" or ItemUse.field_only(item):
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
	return {"type": "item", "item": item, "target": idx + _offset(), "move": move_index}


## Petit menu interne au combat (curseur, A pour valider, B pour annuler si autorisé).
func _menu(labels: Array, rect: Rect2, cols: int, cancel: bool, on_move := Callable()) -> int:
	_menu_panel = Kit.panel(self, rect)
	_menu_labels = []
	var cw := (rect.size.x - 20) / cols
	var rows_n := ceili(float(labels.size()) / cols)
	var rh: float = 26.0 if rows_n <= 2 else (rect.size.y - 12) / rows_n
	if rows_n == 3:
		rh = 20
	elif rows_n > 3:
		_menu_panel.size.y = rows_n * 22 + 14
		_menu_panel.position.y = 316 - _menu_panel.size.y
		rh = 22
	for i in labels.size():
		var l := Kit.label(_menu_panel, str(labels[i]), Vector2(26 + (i % cols) * cw, 6 + (i / cols) * rh), 15)
		_menu_labels.append(l)
	_menu_cursor = Kit.label(_menu_panel, "▶", Vector2(8, 7), 14, Kit.INK, false)
	_menu_cursor.set_meta("rh", rh)
	_menu_cols = cols
	_menu_cancel = cancel
	_menu_on_move = on_move
	_menu_index = mini(_menu_index, labels.size() - 1) if not cancel else 0
	_menu_set(_menu_index, cw)
	_menu_active = true
	var r: int = await _menu_done
	_menu_active = false
	_menu_panel.queue_free()
	Audio.sfx("select")
	return r


func _menu_set(i: int, cw := -1.0) -> void:
	_menu_index = clampi(i, 0, _menu_labels.size() - 1)
	var w := cw if cw > 0 else (_menu_panel.size.x - 20) / _menu_cols
	var rh: float = _menu_cursor.get_meta("rh", 26)
	_menu_cursor.position = Vector2(8 + (_menu_index % _menu_cols) * w, 7 + (_menu_index / _menu_cols) * rh)
	if _menu_on_move.is_valid():
		_menu_on_move.call(_menu_index)


func _process(delta: float) -> void:
	if _weather != "" and Game.settings.get("animations", true):
		_wt += delta
		_weather_fx.queue_redraw()
	elif _wt != 0.0:
		_wt = 0.0
		_weather_fx.queue_redraw()
	if _info_panel != null:
		if act("a") or act("b"):
			_info_panel.queue_free()
			_info_panel = null
			_menu_done.emit(-2)
		return
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
