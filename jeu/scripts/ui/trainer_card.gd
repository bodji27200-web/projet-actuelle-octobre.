class_name TrainerCard
extends Screen
## Carte de Dresseur / profil : identité, statistiques, titres. `profile` vide = sa propre carte ;
## sinon c'est la carte d'un autre joueur (reçue par le réseau, lecture seule).

const BADGE_COLORS := ["a0a0a0", "5090f0", "f0d030", "60c060", "c060c0", "f0a030", "e04040", "50b050"]
const PAGES := ["CARTE DE DRESSEUR", "STATISTIQUES", "TITRES"]

var profile := {}
var _page := 0
var _sel := 0
var _scroll := 0
var _body: Panel
var _own := true


func _ready() -> void:
	size = Vector2(480, 320)
	_own = profile.is_empty()
	if _own:
		profile = Profile.card()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.size = Vector2(480, 320)
	add_child(bg)
	_body = Kit.panel(self, Rect2(16, 12, 448, 296), Color("f8e8b0"), Color("c09030"))
	_build()


func _pages() -> int:
	return 3 if _own else 2


func _build() -> void:
	Kit.clear(_body)
	Kit.label(_body, PAGES[_page], Vector2(12, 4), 17, Color("806020"))
	var nav := "◀ %d / %d ▶" % [_page + 1, _pages()]
	Kit.label(_body, nav, Vector2(448 - 14 - Kit.text_width(nav, 13), 8), 13, Color("a08040"), false)
	match _page:
		0:
			_identity()
		1:
			_stats()
		2:
			_titles()
	var hint := "◀ ▶ : page    B : fermer" + ("    A : afficher ce titre" if _page == 2 else "")
	Kit.label(_body, hint, Vector2(12, 270), 11, Color("a08040"), false)


func _identity() -> void:
	var spr := TextureRect.new()
	spr.texture = PixelArt.character(profile.get("look", "boy_classique"), "down", 0)
	spr.position = Vector2(14, 40)
	spr.size = Vector2(96, 96)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.add_child(spr)
	Kit.label(_body, profile.get("name", "?"), Vector2(124, 36), 20)
	Kit.label(_body, "« %s »" % Profile.title_name(profile.get("title", "debutant")), Vector2(124, 64), 14, Color("b07810"))
	var t := int(profile.get("time", 0))
	var lines := [
		"Temps de jeu : %d h %02d min" % [t / 3600, (t / 60) % 60],
		"Pokédex : %d vus, %d capturés" % [profile.get("seen", 0), profile.get("caught", 0)],
		"Argent : %d ₽" % profile.get("money", 0),
		"Classement Elo : %d" % profile.get("elo", 1000),
		"Guilde : %s" % (profile.get("guild", "") if profile.get("guild", "") != "" else "aucune"),
	]
	for i in lines.size():
		Kit.label(_body, lines[i], Vector2(124, 92 + i * 22), 13)
	Kit.label(_body, "BADGES", Vector2(14, 148), 12, Color("806020"))
	var badges: Array = profile.get("badges", [])
	for n in 8:
		var c := ColorRect.new()
		c.size = Vector2(14, 14)
		c.position = Vector2(14 + (n % 4) * 20, 172 + (n / 4) * 20)
		c.color = Color(BADGE_COLORS[n]) if badges.has(n + 1) else Color(0, 0, 0, 0.15)
		_body.add_child(c)
	if profile.get("champion", false):
		Kit.label(_body, "★ Maître de la Ligue", Vector2(124, 204), 13, Color("c02828"))
	# Équipe.
	var party: Array = profile.get("party", [])
	for i in party.size():
		var p: Array = party[i]
		var ic := TextureRect.new()
		ic.position = Vector2(14 + i * 70, 226)
		ic.size = Vector2(40, 30)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		Sprites.apply(ic, "icon", int(p[0]))
		_body.add_child(ic)
		Kit.label(_body, "N.%d%s" % [p[1], " ★" if p[2] else ""], Vector2(52 + i * 70, 236), 11, Color("e0a000") if p[2] else Kit.INK, false)


func _stats() -> void:
	var st: Dictionary = profile.get("stats", {})
	var keys := Profile.STAT_LABELS.keys()
	for i in keys.size():
		var col := i % 2
		var row := i / 2
		Kit.label(_body, "%s : %d" % [Profile.STAT_LABELS[keys[i]], int(st.get(keys[i], 0))], Vector2(14 + col * 214, 36 + row * 22), 12)
	var y := 36 + ((keys.size() + 1) / 2) * 22 + 6
	Kit.label(_body, "Plus gros dégâts infligés :", Vector2(14, y), 13, Color("806020"))
	Kit.label(_body, str(profile.get("best_hit", "aucun")), Vector2(24, y + 22), 13)
	Kit.label(_body, "Titres débloqués : %d / %d" % [profile.get("titles", 1), Profile.TITLES.size()], Vector2(14, y + 48), 13, Color("806020"))


func _titles() -> void:
	var ids := Profile.TITLES.keys()
	var per := 10
	_scroll = clampi(_scroll, maxi(0, _sel - per + 1), _sel)
	for k in per:
		var i := _scroll + k
		if i >= ids.size():
			break
		var id: String = ids[i]
		var t: Array = Profile.TITLES[id]
		var have := Game.titles.has(id)
		var col := Color("c03030") if i == _sel else (Kit.INK if have else Color("a09070"))
		var mark := "✓ " if Game.title == id else ""
		Kit.label(_body, ("▶ " if i == _sel else "   ") + mark + (t[0] if have else "???"), Vector2(12, 34 + k * 22), 13, col, have)
		var fs := 11 if Kit.text_width(t[1], 11) <= 206 else 9
		Kit.label(_body, t[1], Vector2(224, 36 + k * 22 + (11 - fs)), fs, Color("806020") if have else Color("a09070"), false)


func _process(_d: float) -> void:
	if act("b"):
		finish()
		return
	if act("left"):
		_page = (_page + _pages() - 1) % _pages()
		Audio.sfx("select")
		_build()
	elif act("right"):
		_page = (_page + 1) % _pages()
		Audio.sfx("select")
		_build()
	elif _page == 2 and (act("up") or act("down")):
		_sel = (_sel + (1 if act("down") else -1) + Profile.TITLES.size()) % Profile.TITLES.size()
		_build()
	elif act("a"):
		if _page != 2:
			finish()
			return
		var id: String = Profile.TITLES.keys()[_sel]
		if Game.titles.has(id):
			Game.title = id
			profile["title"] = id
			Audio.sfx("select")
			if Game.world != null:
				Game.world.refresh_player_look()
			Net.send_state()
			_build()
		else:
			Audio.sfx("bump", 0.4)
