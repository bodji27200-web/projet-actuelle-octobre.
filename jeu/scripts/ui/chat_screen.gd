class_name ChatScreen
extends Screen
## Discussion à canaux : Général, Commerce, Aide, Guilde, Langues. ◀ ▶ : canal, A : écrire, B : fermer.

const COLORS := {"Général": "f8f8f8", "Commerce": "f8d048", "Aide": "78d878", "Guilde": "c890f8", "Langues": "78c0f8"}
const HELP := {"Général": "Pour discuter de tout.", "Commerce": "Achats, ventes, échanges (voir aussi l'Hôtel des Ventes).",
	"Aide": "Une question sur le jeu ? Demande ici.", "Guilde": "Seuls les membres de ta guilde voient ces messages.",
	"Langues": "Messages dans d'autres langues. Haut / Bas : choisir la langue de tes messages."}

var channel := 0
var _tabs: Array = []
var _log: Label
var _help: Label
var _lang := 0
var _busy := false


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.18, 0.94)
	bg.size = size
	add_child(bg)
	for i in Social.CHANNELS.size():
		var l := Kit.label(self, Social.CHANNELS[i], Vector2(10 + i * 94, 6), 13, Color.WHITE, false)
		_tabs.append(l)
	var p := Kit.panel(self, Rect2(6, 32, 468, 244), Color(0, 0, 0, 0.45), Color("8090c0"))
	_log = Kit.label(p, "", Vector2(8, 2), 12, Color.WHITE, false)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size = Vector2(452, 238)
	_log.clip_text = true
	_help = Kit.label(self, "", Vector2(10, 280), 11, Color("c0c8e0"), false)
	Kit.label(self, "◀ ▶ canal   A : écrire   B : fermer", Vector2(10, 298), 11, Color("c0c8e0"), false)
	Social.chat_in.connect(_on_line)
	_refresh()


func _exit_tree() -> void:
	if Social.chat_in.is_connected(_on_line):
		Social.chat_in.disconnect(_on_line)
	super._exit_tree()


func _ch() -> String:
	return Social.CHANNELS[channel]


func _on_line(ch: String, _l: String) -> void:
	if ch == _ch():
		_refresh()


func _refresh() -> void:
	for i in _tabs.size():
		var c := Color(COLORS[Social.CHANNELS[i]])
		_tabs[i].add_theme_color_override("font_color", c if i == channel else c.darkened(0.55))
		_tabs[i].text = ("▶" if i == channel else "") + Social.CHANNELS[i]
	var lines: Array = Social.chat_logs[_ch()]
	var shown := lines.slice(maxi(0, lines.size() - 13))
	_log.add_theme_color_override("font_color", Color(COLORS[_ch()]))
	_log.text = "\n".join(shown) if shown.size() > 0 else ("(aucun message pour l'instant)" if Net.online() else "Hors ligne : connecte-toi depuis le menu MULTIJOUEUR pour discuter.")
	var h: String = HELP[_ch()]
	if _ch() == "Langues":
		h = "Langue de tes messages : %s (Haut / Bas pour changer)." % Social.LANGS[_lang]
	elif _ch() == "Guilde":
		var g := Social.guild_of(Game.uid)
		h = "Guilde : %s." % g if g != "" else "Tu n'es dans aucune guilde (menu GUILDES)."
	_help.text = h


func _process(_d: float) -> void:
	if _busy:
		return
	if act("b"):
		finish()
	elif act("left"):
		channel = (channel + Social.CHANNELS.size() - 1) % Social.CHANNELS.size()
		_refresh()
	elif act("right"):
		channel = (channel + 1) % Social.CHANNELS.size()
		_refresh()
	elif _ch() == "Langues" and (act("up") or act("down")):
		_lang = (_lang + (1 if act("down") else -1) + Social.LANGS.size()) % Social.LANGS.size()
		var langs: Array = Game.settings.get("chat_langs", ["FR"]).duplicate()
		if not langs.has(Social.LANGS[_lang]):
			langs.append(Social.LANGS[_lang])
			Game.settings["chat_langs"] = langs
		_refresh()
	elif act("a"):
		_write()


func _write() -> void:
	_busy = true
	var t: String = await Game.ui.enter_name("Message (%s) :" % _ch(), "", 60)
	if t.strip_edges() != "":
		Social.say(_ch(), t, Social.LANGS[_lang])
	_refresh()
	_busy = false
