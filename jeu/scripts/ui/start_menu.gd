class_name StartMenu
extends Screen
## Menu Start : liste d'entrées avec icône et description. Renvoie la clé choisie.

const ICONS := {"dex": "f05050", "party": "f8c030", "bag": "c08040", "outfits": "e070b0", "journal": "60a0e0",
	"map": "60c070", "online": "8070e0", "card": "e0a040", "settings": "909090", "save": "40a0a0", "close": "c0c0c0"}
const DESC := {"dex": "Les Pokémon que tu as vus et capturés.", "party": "Ton équipe : résumé, ordre, IV/EV.",
	"bag": "Objets, soins, Balls et CT.", "outfits": "Change de tenue.", "journal": "Ce que tu dois faire et tes quêtes.",
	"map": "La carte de Kanto.", "online": "Jouer avec un ami : héberger, rejoindre, groupe.",
	"card": "Ta Carte de Dresseur et tes Badges.", "settings": "Son, texte, difficulté, touches...", "save": "Sauvegarder la partie.", "close": "Fermer le menu."}

static var last := 0

var _entries: Array = []
var _labels: Array = []
var _cursor: ColorRect
var _desc: Label


func _ready() -> void:
	size = Vector2(480, 320)
	if Game.flag("has_dex"):
		_entries.append(["dex", "POKéDEX"])
	if Game.party.size() > 0:
		_entries.append(["party", "POKéMON"])
	_entries.append(["bag", "SAC"])
	_entries.append(["outfits", "TENUES"])
	_entries.append(["journal", "JOURNAL"])
	_entries.append(["map", "CARTE"])
	_entries.append(["online", "MULTIJOUEUR"])
	_entries.append(["card", Game.player_name.to_upper()])
	_entries.append(["settings", "PARAMÈTRES"])
	_entries.append(["save", "SAUVER"])
	_entries.append(["close", "FERMER"])
	var h := _entries.size() * 22 + 16
	var p := Kit.panel(self, Rect2(330, 6, 144, h), Color("f8f8f8"), Color("3868a0"))
	_cursor = ColorRect.new()
	_cursor.color = Color("d8e8f8")
	_cursor.size = Vector2(132, 21)
	p.add_child(_cursor)
	for i in _entries.size():
		var icon := ColorRect.new()
		icon.color = Color(ICONS[_entries[i][0]])
		icon.position = Vector2(10, 12 + i * 22)
		icon.size = Vector2(10, 10)
		p.add_child(icon)
		_labels.append(Kit.label(p, _entries[i][1], Vector2(28, 3 + i * 22), 15))
	var dp := Kit.panel(self, Rect2(4, 272, 472, 44), Color("f8f8f8"), Color("3868a0"))
	_desc = Kit.label(dp, "", Vector2(10, 4), 14)
	last = clampi(last, 0, _entries.size() - 1)
	_move(0)


func _move(d: int) -> void:
	last = (last + d + _entries.size()) % _entries.size()
	_cursor.position = Vector2(6, 6 + last * 22)
	_desc.text = DESC[_entries[last][0]]
	if d != 0:
		Audio.sfx("select", 0.5)


func _process(_d: float) -> void:
	if act("up"):
		_move(-1)
	elif act("down"):
		_move(1)
	elif act("a"):
		Audio.sfx("select")
		finish(_entries[last][0])
	elif act("b") or act("start"):
		finish("close")
