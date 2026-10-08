extends Control
## Racine de l'interface : dialogues, choix, ouverture des écrans, fondus.

var _fade: ColorRect


func _ready() -> void:
	Game.ui = self
	size = Vector2(480, 320)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.size = Vector2(480, 320)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 100
	add_child(_fade)


## Affiche un ou plusieurs messages et attend que le joueur les lise.
func say(text: Variant, auto := 0.0) -> void:
	var pages: Array = text if text is Array else [text]
	pages = pages.map(func(p): return _fmt(str(p)))
	var tb := TextBox.new()
	tb.pages = pages
	tb.auto = auto
	add_child(tb)
	move_child(_fade, -1)
	await tb.done


func _fmt(s: String) -> String:
	return s.replace("{player}", Game.player_name).replace("{rival}", Game.rival_name)


## Message + menu de choix. Renvoie l'indice, ou -1 si annulé.
func ask(text: String, options: Array, cancel := true) -> int:
	var tb := _static_box(_fmt(text))
	var c := Choice.new()
	c.options = options
	c.cancel = cancel
	add_child(c)
	var r: int = await c.done
	tb.queue_free()
	return r


func confirm(text: String) -> bool:
	return await ask(text, ["OUI", "NON"]) == 0


## Ouvre un écran (Screen) et renvoie son résultat.
func open(screen: Screen) -> Variant:
	add_child(screen)
	move_child(_fade, -1)
	return await screen.done


func choose(options: Array, at := Vector2(-1, -1), cancel := true, columns := 1, width := 0.0) -> int:
	var c := Choice.new()
	c.options = options
	c.at = at
	c.cancel = cancel
	c.columns = columns
	c.width = width
	add_child(c)
	return await c.done


func _static_box(text: String) -> Control:
	var holder := Control.new()
	holder.size = Vector2(480, 320)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var p := Kit.panel(holder, Rect2(4, 244, 472, 72))
	var l := Kit.label(p, "", Vector2(12, 8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(440, 56)
	l.text = text
	return holder


func fade(to_black: bool, time := 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if to_black else 0.0, time)
	await tw.finished


func flash(times := 3) -> void:
	for i in times:
		_fade.color = Color(1, 1, 1, 1)
		await get_tree().create_timer(0.06).timeout
		_fade.color = Color(1, 1, 1, 0)
		await get_tree().create_timer(0.06).timeout
	_fade.color = Color(0, 0, 0, 0)


## Saisie d'un nom au clavier.
func enter_name(title: String, default: String, max_len := 12) -> String:
	var s := NameEntry.new()
	s.title = title
	s.default = default
	s.max_len = max_len
	return await open(s)
