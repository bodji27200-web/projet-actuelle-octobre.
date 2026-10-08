extends Node
## Télécharge les sprites officiels (PokeAPI) la première fois, puis les garde en cache
## dans user://sprites. Rien n'est inclus dans le projet : il faut Internet au premier lancement.

signal loaded(key: String)

const BASE := "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/"
const MAX_PARALLEL := 4

var _tex := {}
var _queue: Array = []
var _active := 0
var _failed := {}
var _attempt := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://sprites")
	# Préchargement en arrière-plan : faces, dos et icônes des 151.
	for i in range(1, 152):
		_enqueue(key("front", i, false), false)
	for i in range(1, 152):
		_enqueue(key("icon", i, false), false)
	for i in range(1, 152):
		_enqueue(key("back", i, false), false)


func key(kind: String, id: Variant, shiny: bool) -> String:
	return "%s_%s%s" % [kind, str(id), "_s" if shiny else ""]


## Adresse du sprite. `attempt` > 0 : sources de secours (le style Noir/Blanc couvre les 1025 Pokémon,
## mais pas toutes les formes ; les icônes s'arrêtent à la 8e génération).
func _url(k: String, attempt := 0) -> String:
	var parts := k.split("_")
	var kind := parts[0]
	var id := parts[1]
	var shiny := parts.size() > 2
	var sh := "shiny/" if shiny else ""
	match kind:
		"front":
			if attempt == 0:
				return BASE + "pokemon/versions/generation-v/black-white/%s%s.png" % [sh, id]
			if attempt == 1:
				return BASE + "pokemon/%s%s.png" % [sh, id]
		"back":
			if attempt == 0:
				return BASE + "pokemon/versions/generation-v/black-white/back/%s%s.png" % [sh, id]
			if attempt == 1:
				return BASE + "pokemon/back/%s%s.png" % [sh, id]
		"icon":
			var n := int(id)
			var sources := []
			if n <= 809 or n > 10000:
				sources.append(BASE + "pokemon/versions/generation-vii/icons/%s.png" % id)
			if n <= 898 or n > 10000:
				sources.append(BASE + "pokemon/versions/generation-viii/icons/%s.png" % id)
			sources.append(BASE + "pokemon/versions/generation-v/black-white/%s.png" % id)
			sources.append(BASE + "pokemon/%s.png" % id)
			if attempt < sources.size():
				return sources[attempt]
		"item":
			if attempt == 0:
				return BASE + "items/%s.png" % id
	return ""


func _path(k: String) -> String:
	return "user://sprites/%s.png" % k


## Renvoie la texture si elle est prête, sinon null (et lance le téléchargement en priorité).
func get_tex(kind: String, id: Variant, shiny := false) -> Texture2D:
	var k := key(kind, id, shiny)
	if _tex.has(k):
		return _tex[k]
	if FileAccess.file_exists(_path(k)):
		var img := Image.load_from_file(_path(k))
		if img != null and not img.is_empty():
			var t := ImageTexture.create_from_image(img)
			_tex[k] = t
			return t
	_enqueue(k, true)
	return null


## Affecte la texture à un TextureRect / Sprite2D, maintenant ou dès qu'elle est téléchargée.
func apply(node: Node, kind: String, id: Variant, shiny := false, fallback: Texture2D = null) -> void:
	var t := get_tex(kind, id, shiny)
	node.set("texture", t if t != null else fallback)
	if t != null:
		return
	var k := key(kind, id, shiny)
	var cb := func(done_key: String) -> void:
		if done_key == k and is_instance_valid(node):
			node.set("texture", _tex.get(k))
	loaded.connect(cb)
	node.tree_exiting.connect(func():
		if loaded.is_connected(cb):
			loaded.disconnect(cb))


func _enqueue(k: String, priority: bool) -> void:
	if _tex.has(k) or _failed.has(k) or FileAccess.file_exists(_path(k)):
		return
	if _queue.has(k):
		if priority:
			_queue.erase(k)
			_queue.push_front(k)
		return
	if priority:
		_queue.push_front(k)
	else:
		_queue.append(k)
	_pump()


func _pump() -> void:
	while _active < MAX_PARALLEL and not _queue.is_empty():
		var k: String = _queue.pop_front()
		if FileAccess.file_exists(_path(k)):
			continue
		_active += 1
		var req := HTTPRequest.new()
		req.timeout = 20.0
		add_child(req)
		req.request_completed.connect(_on_done.bind(k, req))
		if req.request(_url(k, _attempt.get(k, 0))) != OK:
			_on_done(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), k, req)


func _on_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, k: String, req: HTTPRequest) -> void:
	_active -= 1
	req.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0:
		var img := Image.new()
		if img.load_png_from_buffer(body) == OK:
			img.save_png(_path(k))
			_tex[k] = ImageTexture.create_from_image(img)
			loaded.emit(k)
	else:
		# Source suivante, s'il y en a une.
		var nxt: int = _attempt.get(k, 0) + 1
		if _url(k, nxt) != "":
			_attempt[k] = nxt
			_queue.push_front(k)
		else:
			_failed[k] = true
	_pump()
