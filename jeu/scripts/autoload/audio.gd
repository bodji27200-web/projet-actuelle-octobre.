extends Node
## Musique (boucles), jingles, bruitages, et cris officiels des Pokémon (téléchargés via PokeAPI puis gardés en cache).

## Cris « rétro » jusqu'à la 5e génération, cris récents ensuite (et pour les formes).
const CRY_URL := "https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/legacy/%d.ogg"
const CRY_URL_LATEST := "https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/%d.ogg"
const ALIASES := {"gym_battle": "gym_battle"}

var _music: AudioStreamPlayer
var _jingle: AudioStreamPlayer
var _sfx: Array = []
var _current := ""
var _cache := {}
var _cries := {}
var _cry_dl := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_jingle = AudioStreamPlayer.new()
	add_child(_jingle)
	_jingle.finished.connect(func(): _music.stream_paused = false)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	DirAccess.make_dir_recursive_absolute("user://cries")
	apply_volume()


func apply_volume() -> void:
	var m: float = Game.settings.get("music", 0.7)
	var s: float = Game.settings.get("sfx", 0.8)
	_music.volume_db = linear_to_db(maxf(0.0001, m))
	_jingle.volume_db = linear_to_db(maxf(0.0001, m))
	for p in _sfx:
		p.volume_db = linear_to_db(maxf(0.0001, s))


func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
	_cache[path] = st
	return st


func play_music(name: String) -> void:
	if name == "" or name == _current:
		return
	var path := "res://assets/audio/music/%s.ogg" % name
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/music/%s.ogg" % {"trainer": "battle_trainer", "gym": "gym_battle"}.get(name, "route")
	var st := _stream(path)
	if st == null:
		return
	_current = name
	if st is AudioStreamOggVorbis:
		st.loop = not name.begins_with("victory") or true
	_music.stream = st
	_music.stream_paused = false
	_music.play()


func stop_music() -> void:
	_current = ""
	_music.stop()


## Courte musique (soin, capture, badge...) qui met la musique en pause.
func jingle(name: String) -> void:
	var st := _stream("res://assets/audio/music/%s.ogg" % name)
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		st.loop = false
	_music.stream_paused = true
	_jingle.stream = st
	_jingle.play()


func sfx(name: String, volume := 1.0) -> void:
	var st := _stream("res://assets/audio/sfx/%s.ogg" % name)
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		st.loop = false
	for p in _sfx:
		if not p.playing:
			p.stream = st
			p.volume_db = linear_to_db(maxf(0.0001, Game.settings.get("sfx", 0.8) * volume))
			p.play()
			return


## Cri officiel d'un Pokémon (téléchargé la première fois).
func cry(species: int) -> void:
	if not Game.settings.get("cries", true) or species <= 0:
		return
	if _cries.has(species):
		_play_cry(_cries[species])
		return
	var path := "user://cries/%d.ogg" % species
	if FileAccess.file_exists(path):
		var st := AudioStreamOggVorbis.load_from_file(path)
		if st != null:
			_cries[species] = st
			_play_cry(st)
		return
	if _cry_dl.has(species):
		return
	_cry_dl[species] = true
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h, body: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(body)
			f.close()
			var st2 := AudioStreamOggVorbis.load_from_buffer(body)
			if st2 != null:
				_cries[species] = st2)
	req.request((CRY_URL if species <= 649 else CRY_URL_LATEST) % species)


func _play_cry(st: AudioStream) -> void:
	for p in _sfx:
		if not p.playing:
			p.stream = st
			p.volume_db = linear_to_db(maxf(0.0001, Game.settings.get("sfx", 0.8) * 0.8))
			p.play()
			return
