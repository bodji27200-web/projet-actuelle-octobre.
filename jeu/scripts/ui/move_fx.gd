class_name MoveFx
extends RefCounted
## Animations des capacités en combat, entièrement en pixel art généré (aucune image externe).
## Chaque capacité est rangée dans une « mise en scène » (contact, coup de poing, morsure, tranchant, rayon,
## projectile, onde, tempête, séisme, chute de rochers, protection, soin, hausse/baisse de stats...)
## et colorée selon son type.

const TYPE_FX := {
	"normal": {"c": Color("f8f8e8"), "c2": Color("c8c8a8"), "p": "star"},
	"fighting": {"c": Color("f87850"), "c2": Color("c03028"), "p": "star"},
	"flying": {"c": Color("e0e8ff"), "c2": Color("a890f0"), "p": "feather"},
	"poison": {"c": Color("d070e0"), "c2": Color("8030a0"), "p": "bubble"},
	"ground": {"c": Color("e8c878"), "c2": Color("a08040"), "p": "rock"},
	"rock": {"c": Color("c8a868"), "c2": Color("806030"), "p": "rock"},
	"bug": {"c": Color("c8d850"), "c2": Color("789018"), "p": "spark"},
	"ghost": {"c": Color("9878c8"), "c2": Color("402858"), "p": "wisp"},
	"steel": {"c": Color("e0e0f0"), "c2": Color("8888a8"), "p": "shard"},
	"fire": {"c": Color("ffb040"), "c2": Color("e83818"), "p": "flame"},
	"water": {"c": Color("78b8ff"), "c2": Color("3060d0"), "p": "drop"},
	"grass": {"c": Color("90e068"), "c2": Color("388828"), "p": "leaf"},
	"electric": {"c": Color("fff070"), "c2": Color("e8b800"), "p": "spark"},
	"psychic": {"c": Color("ff90c0"), "c2": Color("d03878"), "p": "ring"},
	"ice": {"c": Color("c8f0ff"), "c2": Color("68b0d8"), "p": "shard"},
	"dragon": {"c": Color("a078ff"), "c2": Color("5028c0"), "p": "flame"},
	"dark": {"c": Color("706070"), "c2": Color("281820"), "p": "wisp"},
	"fairy": {"c": Color("ffc0e0"), "c2": Color("e070a8"), "p": "heart"},
}

static var _tex := {}


# ---------------------------------------------------------------------------
# Particules (petites images pixel art générées une fois)
# ---------------------------------------------------------------------------

static func _make(name: String, rows: Array, col: Color, col2: Color) -> Texture2D:
	var key := "%s_%s_%s" % [name, col.to_html(), col2.to_html()]
	if _tex.has(key):
		return _tex[key]
	var h := rows.size()
	var w: int = rows[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var ch: String = rows[y][x]
			if ch == "x":
				img.set_pixel(x, y, col)
			elif ch == "o":
				img.set_pixel(x, y, col2)
			elif ch == "w":
				img.set_pixel(x, y, Color(1, 1, 1, 0.95))
			elif ch == "k":
				img.set_pixel(x, y, Color(0.12, 0.12, 0.14))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


const SHAPES := {
	"star": ["...x...", "...x...", ".xxwxx.", "xxwwwxx", ".xxwxx.", "...x...", "...x..."],
	"spark": ["x...x", ".xwx.", "..w..", ".xwx.", "x...x"],
	"flame": ["...x....", "..xx....", "..xxx...", ".xxoxx..", ".xooox..", "xxowoxx.", "xoowwoxx", "xowwwwox", ".xowwox.", "..xxxx.."],
	"drop": ["..x...", "..x...", ".xxx..", ".xwxx.", "xwxxxx", "xxxxox", ".xxox.", "..xx.."],
	"leaf": ["....xxx", "..xxwxx", ".xxwxx.", "xxwxxx.", "xoxx...", "o......"],
	"rock": ["..oooo..", ".oxxxxo.", "oxxwxxxo", "oxxxxxxo", "oxxxxoxo", "oxxxxxxo", ".oxxxxo.", "..oooo.."],
	"shard": ["..w..", ".wxw.", ".xxx.", ".xxx.", "xxxxx", ".xxx.", ".xox.", "..o.."],
	"bubble": [".oooo.", "o..w.o", "o....o", "o....o", "o....o", ".oooo."],
	"ring": ["..xxxx..", ".x....x.", "x......x", "x......x", "x......x", "x......x", ".x....x.", "..xxxx.."],
	"heart": [".xx.xx.", "xwxxxxx", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."],
	"wisp": ["..xxx...", ".xxxxx..", "xxkxkxx.", "xxxxxxx.", ".xxxxxx.", "..xxxxxx", "...x.xx.", ".....x.."],
	"feather": ["......xx", ".....xwx", "....xwx.", "...xwx..", "..xwx...", ".xox....", "xo......"],
	"note": ["..xxxx", "..x..x", "..x..x", "..x..x", "xxx.xx", "xxx.xx"],
	"bolt": ["...xxx", "..xxx.", ".xxx..", "xxxxxx", "...xx.", "..xx..", ".xx...", "xx...."],
	"fist": [".xxxx...", "xxxxxxx.", "xwxwxwxx", "xxxxxxxx", "xxxxxxxx", "oxxxxxxo", ".oxxxxo.", "..oooo.."],
	"foot": ["..xxxx..", ".xxxxxx.", ".xxxxxx.", "..xxxxx.", "..xxxxxx", ".xxxxxxx", "xxxxxxxx", ".oooooo."],
	"arrow_up": ["...x...", "..xxx..", ".xxxxx.", "xxxxxxx", "..xxx..", "..xxx..", "..xxx.."],
	"arrow_down": ["..xxx..", "..xxx..", "..xxx..", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."],
	"z": ["xxxxx", "...x.", "..x..", ".x...", "xxxxx"],
	"plus": ["..x..", "..x..", "xxxxx", "..x..", "..x.."],
	"dust": [".xx.", "xxxx", "xxxx", ".xx."],
}


static func tex(shape: String, typ := "normal", col := Color.TRANSPARENT) -> Texture2D:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["normal"])
	var c: Color = col if col.a > 0.0 else fx["c"]
	var c2: Color = fx["c2"] if col.a == 0.0 else col.darkened(0.35)
	return _make(shape, SHAPES[shape], c, c2)


## Crée une particule (TextureRect) sur la couche d'effets.
static func part(layer: Control, shape: String, typ: String, pos: Vector2, scale := 2.0, col := Color.TRANSPARENT) -> TextureRect:
	scale *= 1.5
	var r := TextureRect.new()
	r.texture = tex(shape, typ, col)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.size = r.texture.get_size() * scale
	r.pivot_offset = r.size / 2
	r.position = pos - r.size / 2
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r


static func _wait(host: Node, t: float) -> void:
	await host.get_tree().create_timer(t).timeout


# ---------------------------------------------------------------------------
# Choix de la mise en scène
# ---------------------------------------------------------------------------

## Mise en scène d'une capacité selon son nom, ses drapeaux et sa catégorie.
static func style(ident: String, cat: String, typ: String, flags: Array, contact: bool, self_target: bool) -> String:
	if ident in ["protect", "detect", "kings-shield", "spiky-shield", "baneful-bunker", "obstruct", "silk-trap", "burning-bulwark",
			"endure", "wide-guard", "quick-guard", "reflect", "light-screen", "aurora-veil", "safeguard", "mist", "substitute"]:
		return "shield"
	if ident in ["earthquake", "magnitude", "bulldoze", "fissure", "precipice-blades", "lands-wrath", "stomping-tantrum", "high-horsepower", "headlong-rush"]:
		return "quake"
	if ident in ["rock-slide", "stone-edge", "rock-tomb", "meteor-mash", "avalanche", "icicle-crash", "rock-wrecker", "head-smash", "diamond-storm", "stealth-rock", "spikes", "toxic-spikes", "draco-meteor", "hail", "blizzard", "sky-drop"]:
		return "fall"
	if ident in ["thunder", "thunderbolt", "thunder-shock", "zap-cannon", "bolt-strike", "wildbolt-storm", "thunder-cage", "supercell-slam", "electro-drift", "thunderclap"] or (typ == "electric" and cat == "special" and not "pulse" in ident):
		return "lightning"
	if "dance" in ident and cat == "status" or ident in ["swords-dance", "dragon-dance", "quiver-dance", "victory-dance", "shell-smash", "nasty-plot", "calm-mind", "bulk-up", "growth", "work-up", "coil", "agility", "rock-polish", "iron-defense", "amnesia", "cosmic-power", "belly-drum", "no-retreat", "clangorous-soul", "fillet-away", "shift-gear", "geomancy", "tail-glow", "hone-claws", "focus-energy", "charge", "stockpile", "defense-curl", "harden", "withdraw", "barrier", "acid-armor", "minimize", "double-team", "sharpen", "meditate", "howl", "tidy-up", "take-heart", "shelter", "autotomize"]:
		return "buff"
	if has(flags, "heal") or ident in ["recover", "roost", "wish", "rest", "synthesis", "moonlight", "morning-sun", "soft-boiled", "milk-drink", "slack-off", "shore-up", "heal-pulse", "floral-healing", "life-dew", "jungle-healing", "lunar-blessing", "aqua-ring", "ingrain", "heal-bell", "aromatherapy", "refresh", "purify", "healing-wish", "lunar-dance", "strength-sap", "pain-split"]:
		return "heal"
	if cat == "status":
		if self_target:
			return "buff"
		if has(flags, "powder") or ident in ["toxic", "will-o-wisp", "thunder-wave", "glare", "confuse-ray", "hypnosis", "yawn", "leech-seed", "toxic-thread", "spore", "lovely-kiss", "sing", "supersonic", "sweet-kiss", "dark-void", "grass-whistle", "attract", "charm", "captivate"]:
			return "status"
		return "debuff"
	if has(flags, "sound"):
		return "sound"
	if has(flags, "punch"):
		return "punch"
	if has(flags, "bite"):
		return "bite"
	if has(flags, "slicing") or "claw" in ident or ident in ["slash", "cut", "fury-swipes", "scratch", "x-scissor", "cross-poison", "night-slash", "psycho-cut", "aerial-ace", "dual-chop"]:
		return "slash"
	if "kick" in ident or ident in ["stomp", "jump-kick", "high-jump-kick", "trop-kick", "double-kick", "low-sweep", "triple-axel", "blaze-kick", "axe-kick"]:
		return "kick"
	if has(flags, "pulse") or "pulse" in ident or ident in ["dark-pulse", "aura-sphere", "dragon-pulse", "water-pulse", "origin-pulse", "terrain-pulse", "psywave", "extrasensory", "psychic", "psyshock", "psystrike", "expanding-force", "mystical-power", "lumina-crash"]:
		return "pulse"
	if "beam" in ident or "ray" in ident or "cannon" in ident or "laser" in ident or ident in ["hyper-beam", "solar-beam", "solar-blade", "flash-cannon", "hydro-pump", "flamethrower", "fire-blast", "dragon-energy", "steel-beam", "prismatic-laser", "moongeist-beam", "photon-geyser", "eternabeam", "dynamax-cannon", "core-enforcer", "fleur-cannon", "moonblast", "dazzling-gleam", "draining-kiss", "giga-drain", "mega-drain", "absorb", "hydro-cannon", "blast-burn", "frenzy-plant", "armor-cannon", "electro-shot"]:
		return "beam"
	if "storm" in ident or "wind" in ident or ident in ["gust", "twister", "hurricane", "air-cutter", "air-slash", "heat-wave", "petal-blizzard", "leaf-storm", "fire-spin", "whirlpool", "sand-tomb", "magma-storm", "bleakwind-storm", "springtide-storm", "sandsear-storm", "surf", "muddy-water", "sludge-wave", "discharge", "lava-plume", "boomburst", "overheat", "eruption", "water-spout"]:
		return "storm"
	if contact:
		return "tackle"
	if cat == "physical":
		return "throw"
	return "orb"


static func has(arr: Array, v: String) -> bool:
	return arr.has(v)


# ---------------------------------------------------------------------------
# Lecture d'une animation
# ---------------------------------------------------------------------------

## host : l'écran de combat ; layer : couche d'effets ; us / ts : sprites du lanceur et de la cible.
static func play(host: Control, layer: Control, us: TextureRect, ts: TextureRect, e: Dictionary) -> void:
	var typ: String = e.get("type", "normal")
	var ident: String = e.get("ident", "")
	var self_target: bool = us == ts or e.get("tside", 1) == e.get("side", 0) and e.get("tslot", 0) == e.get("slot", 0)
	var st := style(ident, e.get("cat", "physical"), typ, e.get("flags", []), e.get("contact", false), self_target)
	var a := _center(us)
	var b := _center(ts)
	match st:
		"tackle":
			await _lunge(host, us, ts, b, typ)
		"punch":
			await _lunge(host, us, ts, b, typ, "fist")
		"kick":
			await _lunge(host, us, ts, b, typ, "foot")
		"bite":
			await _bite(host, layer, b, typ)
		"slash":
			await _slash(host, layer, b, typ)
		"beam":
			await _beam(host, layer, a, b, typ)
		"orb":
			await _projectile(host, layer, a, b, typ)
		"throw":
			await _projectile(host, layer, a, b, typ, 3)
		"pulse":
			await _pulse(host, layer, a, b, typ)
		"storm":
			await _storm(host, layer, b, typ)
		"quake":
			await _quake(host, layer, ts, typ)
		"fall":
			await _fall(host, layer, b, typ)
		"lightning":
			await _lightning(host, layer, b, typ)
		"sound":
			await _sound(host, layer, a, b, typ)
		"shield":
			await _shield(host, layer, a, typ)
		"heal":
			await _heal(host, layer, a)
		"buff":
			await _arrows(host, layer, a, true, typ)
		"debuff":
			await _arrows(host, layer, b, false, typ)
		"status":
			await _status_cloud(host, layer, b, typ)
	if st in ["tackle", "punch", "kick", "bite", "slash", "beam", "orb", "throw", "pulse", "storm", "fall", "lightning", "sound"]:
		await _impact(host, layer, b, typ)


static func _center(r: TextureRect) -> Vector2:
	if r == null:
		return Vector2(240, 120)
	return r.position + r.size * Vector2(0.5, 0.58)


## Le lanceur bondit vers la cible (contact), avec un poing ou un pied pour les frappes.
static func _lunge(host: Control, us: TextureRect, ts: TextureRect, b: Vector2, typ: String, extra := "") -> void:
	if us == null:
		return
	var home := us.position
	var dir := (b - _center(us)).normalized()
	var tw := host.create_tween()
	tw.tween_property(us, "position", home + dir * 46.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(us, "position", home, 0.18)
	await _wait(host, 0.1)
	if extra != "":
		var p := part(host.get_meta("fx_layer"), extra, typ, b + Vector2(-20, -10), 3.0)
		var tw2 := host.create_tween().set_parallel()
		tw2.tween_property(p, "position", p.position + Vector2(20, 10), 0.12)
		tw2.tween_property(p, "scale", Vector2(1.4, 1.4), 0.12)
		await tw2.finished
		p.queue_free()
	await tw.finished


static func _bite(host: Control, layer: Control, b: Vector2, typ: String) -> void:
	var top := ColorRect.new()
	var bot := ColorRect.new()
	for r in [top, bot]:
		r.color = Color(1, 1, 1, 0.95)
		r.size = Vector2(96, 12)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(r)
	top.position = b + Vector2(-48, -46)
	bot.position = b + Vector2(-48, 34)
	var teeth := []
	for i in 5:
		for r2 in [top, bot]:
			var t := ColorRect.new()
			t.color = Color(1, 1, 1)
			t.size = Vector2(10, 10)
			t.position = Vector2(6 + i * 19, 12 if r2 == top else -10)
			r2.add_child(t)
	var tw := host.create_tween().set_parallel()
	tw.tween_property(top, "position:y", b.y - 12, 0.14).set_ease(Tween.EASE_IN)
	tw.tween_property(bot, "position:y", b.y + 2, 0.14).set_ease(Tween.EASE_IN)
	await tw.finished
	await _wait(host, 0.08)
	top.queue_free()
	bot.queue_free()


static func _slash(host: Control, layer: Control, b: Vector2, typ: String) -> void:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["normal"])
	for i in 3:
		var l := Line2D.new()
		l.width = 5.0
		l.default_color = Color(1, 1, 1, 0.95) if i == 1 else fx["c"]
		var off := Vector2(i * 12 - 12, 0)
		l.add_point(b + Vector2(-34, -30) + off)
		l.add_point(b + Vector2(-34, -30) + off)
		layer.add_child(l)
		var tw := host.create_tween()
		tw.tween_method(func(t: float): l.set_point_position(1, b + Vector2(-34, -30) + off + Vector2(64, 60) * t), 0.0, 1.0, 0.1)
		await tw.finished
		var tw2 := host.create_tween()
		tw2.tween_property(l, "modulate:a", 0.0, 0.2)
		tw2.finished.connect(l.queue_free)
	await _wait(host, 0.1)


static func _beam(host: Control, layer: Control, a: Vector2, b: Vector2, typ: String) -> void:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["normal"])
	var outer := Line2D.new()
	outer.width = 20.0
	outer.default_color = Color(fx["c2"], 0.85)
	var inner := Line2D.new()
	inner.width = 8.0
	inner.default_color = Color(1, 1, 1, 0.95)
	for l in [outer, inner]:
		l.add_point(a)
		l.add_point(a)
		layer.add_child(l)
	var tw := host.create_tween()
	tw.tween_method(func(t: float):
		outer.set_point_position(1, a.lerp(b, t))
		inner.set_point_position(1, a.lerp(b, t)), 0.0, 1.0, 0.2)
	await tw.finished
	# Le rayon ondule un instant.
	for k in 4:
		outer.width = 26.0 if k % 2 == 0 else 16.0
		var sp := part(layer, TYPE_FX.get(typ, TYPE_FX["normal"])["p"], typ, a.lerp(b, randf()), 2.0)
		var twp := host.create_tween()
		twp.tween_property(sp, "modulate:a", 0.0, 0.25)
		twp.finished.connect(sp.queue_free)
		await _wait(host, 0.05)
	var tw2 := host.create_tween().set_parallel()
	tw2.tween_property(outer, "modulate:a", 0.0, 0.2)
	tw2.tween_property(inner, "modulate:a", 0.0, 0.2)
	await tw2.finished
	outer.queue_free()
	inner.queue_free()


static func _projectile(host: Control, layer: Control, a: Vector2, b: Vector2, typ: String, n := 1) -> void:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["normal"])
	for i in n:
		var p := part(layer, fx["p"] if n > 1 else "ring" if typ == "psychic" else fx["p"], typ, a, 3.0)
		var trail := part(layer, "dust", typ, a, 2.0)
		var tw := host.create_tween().set_parallel()
		var dest := b + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		tw.tween_property(p, "position", dest - p.size / 2, 0.28).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p, "rotation", TAU, 0.28)
		tw.tween_property(trail, "position", a.lerp(dest, 0.7) - trail.size / 2, 0.28)
		tw.tween_property(trail, "modulate:a", 0.0, 0.28)
		tw.finished.connect(func():
			p.queue_free()
			trail.queue_free())
		if i < n - 1:
			await _wait(host, 0.08)
		else:
			await tw.finished


static func _pulse(host: Control, layer: Control, a: Vector2, b: Vector2, typ: String) -> void:
	for i in 4:
		var p := part(layer, "ring", typ, a, 2.0)
		var tw := host.create_tween().set_parallel()
		tw.tween_property(p, "position", b - p.size / 2, 0.35)
		tw.tween_property(p, "scale", Vector2(3.0, 3.0), 0.35)
		tw.tween_property(p, "modulate:a", 0.2, 0.35)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.07)
	await _wait(host, 0.3)


static func _storm(host: Control, layer: Control, b: Vector2, typ: String) -> void:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["normal"])
	var parts := []
	for i in 14:
		var p := part(layer, fx["p"], typ, b + Vector2(randf_range(-60, 60), randf_range(-50, 50)), 2.0)
		parts.append(p)
	var t0 := 0.0
	while t0 < 0.6:
		for i in parts.size():
			var p: TextureRect = parts[i]
			var ang := t0 * 9.0 + i
			p.position = b + Vector2(cos(ang) * (30 + i * 3), sin(ang) * (18 + i * 2)) - p.size / 2
			p.rotation = ang
		await host.get_tree().process_frame
		t0 += host.get_process_delta_time()
	for p in parts:
		p.queue_free()


static func _quake(host: Control, layer: Control, ts: TextureRect, typ: String) -> void:
	var home := host.position
	for i in 10:
		host.position = home + Vector2(randf_range(-5, 5), randf_range(-3, 3))
		if i % 2 == 0 and ts != null:
			var d := part(layer, "dust", typ, _center(ts) + Vector2(randf_range(-50, 50), 30), 3.0)
			var tw := host.create_tween()
			tw.tween_property(d, "position:y", d.position.y - 20, 0.3)
			tw.parallel().tween_property(d, "modulate:a", 0.0, 0.3)
			tw.finished.connect(d.queue_free)
		await _wait(host, 0.04)
	host.position = home


static func _fall(host: Control, layer: Control, b: Vector2, typ: String) -> void:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["normal"])
	for i in 6:
		var x := b.x + randf_range(-40, 40)
		var p := part(layer, fx["p"] if typ in ["rock", "ground", "ice", "steel"] else "rock", typ, Vector2(x, b.y - 120), 3.0)
		var tw := host.create_tween()
		tw.tween_property(p, "position:y", b.y + randf_range(-10, 20), 0.22).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "modulate:a", 0.0, 0.12)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.06)
	await _wait(host, 0.2)


static func _lightning(host: Control, layer: Control, b: Vector2, typ: String) -> void:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["electric"])
	var l := Line2D.new()
	l.width = 5.0
	l.default_color = Color(1, 1, 0.8)
	var y := b.y - 140.0
	var x := b.x
	l.add_point(Vector2(x, y))
	while y < b.y:
		y += 18
		x += randf_range(-14, 14)
		l.add_point(Vector2(x, y))
	layer.add_child(l)
	var glow := l.duplicate()
	glow.width = 12.0
	glow.default_color = Color(fx["c"], 0.6)
	layer.add_child(glow)
	layer.move_child(glow, l.get_index())
	host.modulate = Color(1.4, 1.4, 1.2)
	await _wait(host, 0.08)
	host.modulate = Color.WHITE
	await _wait(host, 0.12)
	for k in 3:
		var s := part(layer, "spark", typ, b + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 3.0)
		var tw := host.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.3)
		tw.finished.connect(s.queue_free)
	l.queue_free()
	glow.queue_free()


static func _sound(host: Control, layer: Control, a: Vector2, b: Vector2, typ: String) -> void:
	for i in 5:
		var p := part(layer, "note", typ, a + Vector2(0, randf_range(-20, 20)), 3.0)
		var tw := host.create_tween().set_parallel()
		tw.tween_property(p, "position", b + Vector2(randf_range(-20, 20), randf_range(-30, 10)) - p.size / 2, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p, "modulate:a", 0.3, 0.4)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.07)
	await _wait(host, 0.3)


static func _shield(host: Control, layer: Control, a: Vector2, typ: String) -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 6:
		var ang := TAU * i / 6.0 + PI / 6.0
		pts.append(Vector2(cos(ang), sin(ang)) * 56.0)
	poly.polygon = pts
	poly.color = Color(0.5, 1.0, 0.8, 0.35)
	poly.position = a
	layer.add_child(poly)
	var line := Line2D.new()
	for p in pts:
		line.add_point(p)
	line.add_point(pts[0])
	line.width = 3.0
	line.default_color = Color(0.8, 1.0, 0.9, 0.95)
	poly.add_child(line)
	poly.scale = Vector2(0.2, 0.2)
	var tw := host.create_tween()
	tw.tween_property(poly, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(poly, "modulate:a", 0.0, 0.2)
	await tw.finished
	poly.queue_free()


static func _heal(host: Control, layer: Control, a: Vector2) -> void:
	for i in 9:
		var p := part(layer, "plus", "grass", a + Vector2(randf_range(-40, 40), randf_range(0, 40)), 2.0, Color("80f0a0"))
		var tw := host.create_tween().set_parallel()
		tw.tween_property(p, "position:y", p.position.y - 50, 0.5)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.05)
	await _wait(host, 0.35)


static func _arrows(host: Control, layer: Control, a: Vector2, up: bool, typ: String) -> void:
	var col := Color("f86848") if up else Color("4878f8")
	for i in 12:
		var p := part(layer, "arrow_up" if up else "arrow_down", typ, a + Vector2(randf_range(-36, 36), randf_range(-10, 30) if up else randf_range(-50, -10)), 2.0, col)
		var tw := host.create_tween().set_parallel()
		tw.tween_property(p, "position:y", p.position.y + (-40 if up else 40), 0.45)
		tw.tween_property(p, "modulate:a", 0.0, 0.45)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.04)
	await _wait(host, 0.3)


static func _status_cloud(host: Control, layer: Control, b: Vector2, typ: String) -> void:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["normal"])
	for i in 10:
		var p := part(layer, "dust" if typ in ["grass", "bug", "poison"] else fx["p"], typ, b + Vector2(randf_range(-40, 40), -60), 3.0)
		var tw := host.create_tween().set_parallel()
		tw.tween_property(p, "position:y", b.y + randf_range(-10, 30), 0.5)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.04)
	await _wait(host, 0.35)


## Éclat d'impact sur la cible (étoiles et particules du type).
static func _impact(host: Control, layer: Control, b: Vector2, typ: String) -> void:
	var fx: Dictionary = TYPE_FX.get(typ, TYPE_FX["normal"])
	var parts := []
	var flash := part(layer, "star", typ, b, 5.0, Color(1, 1, 1, 0.9))
	parts.append([flash, Vector2.ZERO])
	for i in 8:
		var ang := TAU * i / 8.0
		var p := part(layer, "star" if i % 2 == 0 else fx["p"], typ, b, 2.0)
		parts.append([p, Vector2(cos(ang), sin(ang)) * randf_range(30, 50)])
	var tw := host.create_tween().set_parallel()
	for pd in parts:
		var p: TextureRect = pd[0]
		tw.tween_property(p, "position", p.position + pd[1], 0.22)
		tw.tween_property(p, "modulate:a", 0.0, 0.22)
	await tw.finished
	for pd in parts:
		pd[0].queue_free()


## Méga-Évolution : une sphère arc-en-ciel enveloppe le Pokémon.
static func mega(host: Control, layer: Control, r: TextureRect) -> void:
	var a := _center(r)
	var cols := [Color("ff6060"), Color("ffc040"), Color("80f080"), Color("60c0ff"), Color("c080ff")]
	for i in 15:
		var p := part(layer, "spark", "normal", a + Vector2(cos(i) * 60, sin(i) * 60), 3.0, cols[i % cols.size()])
		var tw := host.create_tween().set_parallel()
		tw.tween_property(p, "position", a - p.size / 2, 0.4)
		tw.tween_property(p, "rotation", TAU, 0.4)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.03)
	r.modulate = Color(3, 3, 3)
	await _wait(host, 0.25)
	var tw2 := host.create_tween()
	tw2.tween_property(r, "modulate", Color.WHITE, 0.35)
	await tw2.finished


## Puissance Z : une aura dorée entoure le Pokémon.
static func z_aura(host: Control, layer: Control, r: TextureRect) -> void:
	var a := _center(r)
	for i in 12:
		var p := part(layer, "star", "electric", a + Vector2(randf_range(-50, 50), 40), 3.0, Color("ffe060"))
		var tw := host.create_tween().set_parallel()
		tw.tween_property(p, "position:y", p.position.y - 90, 0.5)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.03)
	await _wait(host, 0.3)


## Statuts : petites particules (Zzz, éclairs, flammes, glace, bulles, étoiles de confusion).
static func status(host: Control, layer: Control, r: TextureRect, kind: String) -> void:
	var a := _center(r) + Vector2(0, -30)
	var shape: String = {"status_slp": "z", "status_par": "bolt", "status_brn": "flame", "status_frz": "shard",
		"status_psn": "bubble", "status_tox": "bubble", "status_conf": "star"}.get(kind, "star")
	var typ: String = {"status_slp": "normal", "status_par": "electric", "status_brn": "fire", "status_frz": "ice",
		"status_psn": "poison", "status_tox": "poison", "status_conf": "psychic"}.get(kind, "normal")
	for i in 5:
		var p := part(layer, shape, typ, a + Vector2(randf_range(-30, 30), randf_range(-10, 10)), 2.0)
		var tw := host.create_tween().set_parallel()
		tw.tween_property(p, "position:y", p.position.y - 24, 0.45)
		tw.tween_property(p, "modulate:a", 0.0, 0.45)
		tw.finished.connect(p.queue_free)
		await _wait(host, 0.06)
