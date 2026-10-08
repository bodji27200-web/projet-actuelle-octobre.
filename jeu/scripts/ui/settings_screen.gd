class_name SettingsScreen
extends Screen
## Paramètres : vitesse du texte, volumes, cris, animations, difficulté, fenêtre, mini-carte, touches.

const ITEMS := [
	["text_speed", "Vitesse du texte", ["Lente", "Normale", "Rapide"]],
	["music", "Musique", []],
	["sfx", "Bruitages", []],
	["cries", "Cris des Pokémon", ["Non", "Oui"]],
	["animations", "Animations de combat", ["Non", "Oui"]],
	["difficulty", "Difficulté", ["Normale", "Difficile", "Extrême"]],
	["minimap", "Mini-carte", ["Non", "Oui"]],
	["follower", "Pokémon qui te suit", ["Non", "Oui"]],
	["names", "Noms et titres sur la carte", ["Non", "Oui"]],
	["window", "Fenêtre", ["x2", "x3", "x4", "Plein écran"]],
	["keys", "Touches", []],
	["back", "Retour", []],
]
const DIFF_DESC := ["Comme dans les jeux originaux.", "Les Champions et le rival sont plus forts (IV élevés, niveaux +10 %).",
	"Ultra difficile : IV parfaits, EV optimisés, niveaux +20 %. Bonne chance !"]

var _index := 0
var _labels: Array = []
var _panel: Panel
var _desc: Label
var _busy := false


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("dde4f0")
	bg.size = size
	add_child(bg)
	Kit.label(self, "PARAMÈTRES", Vector2(14, 6), 20, Color("3060a0"), false)
	_panel = Kit.panel(self, Rect2(8, 36, 464, 232))
	var dp := Kit.panel(self, Rect2(8, 272, 464, 44))
	_desc = Kit.label(dp, "", Vector2(10, 4), 13)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(444, 36)
	_build()


func _value_text(key: String, opts: Array) -> String:
	var v = Game.settings.get(key)
	if key in ["music", "sfx"]:
		var n := int(round(float(v) * 10))
		return "◀ " + "■".repeat(n) + "□".repeat(10 - n) + " ▶"
	if key == "keys" or key == "back":
		return ""
	if v is bool:
		v = 1 if v else 0
	return "◀ %s ▶" % opts[clampi(int(v), 0, opts.size() - 1)]


func _build() -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	for i in ITEMS.size():
		var it: Array = ITEMS[i]
		var col := Color("c03030") if i == _index else Kit.INK
		_labels.append(Kit.label(_panel, ("▶ " if i == _index else "   ") + it[1], Vector2(10, 3 + i * 19), 15, col))
		_labels.append(Kit.label(_panel, _value_text(it[0], it[2]), Vector2(240, 3 + i * 19), 15, col))
	var key: String = ITEMS[_index][0]
	_desc.text = DIFF_DESC[Game.difficulty()] if key == "difficulty" else "Gauche / Droite pour modifier. A pour ouvrir. B pour revenir." if key != "keys" else "Change les touches du clavier à ta guise."


func _change(d: int) -> void:
	var it: Array = ITEMS[_index]
	var key: String = it[0]
	match key:
		"music", "sfx":
			Game.settings[key] = clampf(float(Game.settings[key]) + d * 0.1, 0.0, 1.0)
			Audio.apply_volume()
		"cries", "animations", "minimap", "follower", "names":
			Game.settings[key] = not Game.settings[key]
			if key in ["follower", "names"] and Game.world != null:
				Game.world.refresh_player_look()
		"text_speed", "difficulty", "window":
			Game.settings[key] = (int(Game.settings[key]) + d + it[2].size()) % it[2].size()
			if key == "window":
				Game.apply_window()
		_:
			return
	Game.save_settings()
	Audio.sfx("select")
	_build()


func _process(_d: float) -> void:
	if _busy:
		return
	if act("up"):
		_index = (_index - 1 + ITEMS.size()) % ITEMS.size()
		_build()
	elif act("down"):
		_index = (_index + 1) % ITEMS.size()
		_build()
	elif act("left"):
		_change(-1)
	elif act("right"):
		_change(1)
	elif act("a"):
		var key: String = ITEMS[_index][0]
		if key == "keys":
			_busy = true
			await Game.ui.open(KeysScreen.new())
			_busy = false
		elif key == "back":
			finish()
		else:
			_change(1)
	elif act("b"):
		finish()
