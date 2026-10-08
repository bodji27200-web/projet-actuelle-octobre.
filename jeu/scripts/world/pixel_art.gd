class_name PixelArt
extends RefCounted
## Tuiles, personnages et bâtiments en pixel art, dessinés par code (aucun fichier image).

const T := 16
const OUTLINE := Color("202020")

static var _cache := {}


static func _img(w := T, h := T) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## Dessine un motif texte : chaque caractère est une couleur de la palette, "." = transparent.
static func _stamp(img: Image, rows: Array, pal: Dictionary, ox := 0, oy := 0, flip := false) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or not pal.has(ch):
				continue
			var xx := (row.length() - 1 - x) if flip else x
			_px(img, ox + xx, oy + y, pal[ch])


# ---------------------------------------------------------------------------
# Tuiles
# ---------------------------------------------------------------------------

static func tile(kind: String, frame := 0) -> Texture2D:
	var key := "tile_%s_%d" % [kind, frame]
	if _cache.has(key):
		return _cache[key]
	var img := _img()
	match kind:
		"grass":
			_grass(img)
		"path":
			_rect(img, 0, 0, T, T, Color("e8d8a0"))
			for p in [[2, 3], [9, 1], [13, 7], [5, 10], [11, 13], [1, 14], [7, 6]]:
				_px(img, p[0], p[1], Color("d0bc80"))
				_px(img, p[0] + 1, p[1], Color("d8c890"))
		"sand":
			_rect(img, 0, 0, T, T, Color("f0e4b0"))
			for p in [[3, 4], [10, 2], [12, 11], [6, 13], [1, 9]]:
				_px(img, p[0], p[1], Color("dccc90"))
		"tall":
			_grass(img)
			_tall(img)
		"marsh":
			_rect(img, 0, 0, T, T, Color("70a8d8"))
			_tall(img, Color("2c7848"), Color("58a860"))
		"tree":
			_grass(img)
			_tree(img)
		"water":
			_rect(img, 0, 0, T, T, Color("5888e8"))
			var off := frame * 4
			for y in [3, 11]:
				for x in 5:
					_px(img, (x + off + (y % 8)) % T, y, Color("a8c8f8"))
					_px(img, (x + off + 8 + (y % 8)) % T, y + 1, Color("88b0f0"))
		"flower":
			_grass(img)
			var c := Color("f05050") if frame == 0 else Color("f8f8f8")
			for p in [[3, 3], [11, 4], [6, 10], [13, 12]]:
				_stamp(img, [".w.", "wyw", ".w."], {"w": c, "y": Color("f8d030")}, p[0] - 1, p[1] - 1)
		"fence":
			_grass(img)
			_rect(img, 0, 5, T, 2, Color("f8f8f8"))
			_rect(img, 0, 10, T, 2, Color("f8f8f8"))
			_rect(img, 0, 7, T, 1, Color("a0a0a0"))
			_rect(img, 0, 12, T, 1, Color("a0a0a0"))
			_rect(img, 2, 3, 3, 12, Color("f8f8f8"))
			_rect(img, 11, 3, 3, 12, Color("f8f8f8"))
			_rect(img, 2, 14, 3, 1, Color("909090"))
			_rect(img, 11, 14, 3, 1, Color("909090"))
		"sign":
			_grass(img)
			_rect(img, 7, 9, 2, 6, Color("806040"))
			_rect(img, 2, 2, 12, 8, Color("c89858"))
			_rect(img, 2, 2, 12, 1, Color("604020"))
			_rect(img, 2, 9, 12, 1, Color("604020"))
			_rect(img, 2, 2, 1, 8, Color("604020"))
			_rect(img, 13, 2, 1, 8, Color("604020"))
			_rect(img, 4, 4, 8, 1, Color("806040"))
			_rect(img, 4, 6, 6, 1, Color("806040"))
		"ledge":
			_grass(img)
			_rect(img, 0, 11, T, 2, Color("58a048"))
			_rect(img, 0, 13, T, 2, Color("387830"))
			for x in range(0, T, 4):
				_px(img, x + 1, 12, Color("90d070"))
		"rock":
			_grass(img)
			_stamp(img, [
				"................", "................", ".....kkkkkk.....", "...kkllllllkk...",
				"..kllwwllllllk..", "..klwwllllllmk..", ".kllllllllllmmk.", ".klllllllllmmmk.",
				".kllllllllmmmmk.", ".kmlllllllmmmmk.", ".kmmllllmmmmmmk.", "..kmmmmmmmmmmk..",
				"...kkkkkkkkkk...", "................", "................", "................"],
				{"k": OUTLINE, "l": Color("b0a890"), "m": Color("807860"), "w": Color("e0d8c0")})
		"cave":
			_rect(img, 0, 0, T, T, Color("b89878"))
			for p in [[2, 2], [9, 5], [13, 12], [4, 11], [11, 1]]:
				_px(img, p[0], p[1], Color("a08060"))
				_px(img, p[0] + 1, p[1] + 1, Color("c8a888"))
		"cavewall":
			_rect(img, 0, 0, T, T, Color("6c5038"))
			_rect(img, 0, 12, T, 4, Color("50382a"))
			for p in [[1, 2, 6], [8, 1, 7], [3, 7, 9], [11, 8, 4]]:
				_rect(img, p[0], p[1], p[2], 3, Color("8c6c4c"))
				_rect(img, p[0], p[1], p[2], 1, Color("a8886a"))
		"floor":
			_rect(img, 0, 0, T, T, Color("e8c890"))
			_rect(img, 0, 7, T, 1, Color("c8a070"))
			_rect(img, 0, 15, T, 1, Color("c8a070"))
			_rect(img, 5, 0, 1, 7, Color("c8a070"))
			_rect(img, 12, 8, 1, 7, Color("c8a070"))
		"tilefloor":
			_rect(img, 0, 0, T, T, Color("f0f0f0"))
			_rect(img, 0, 0, T, 1, Color("d0d0d8"))
			_rect(img, 0, 0, 1, T, Color("d0d0d8"))
			_rect(img, 8, 0, 1, T, Color("e0e0e8"))
			_rect(img, 0, 8, T, 1, Color("e0e0e8"))
		"wall":
			_rect(img, 0, 0, T, T, Color("f8f0d8"))
			_rect(img, 0, 12, T, 4, Color("b8a078"))
			_rect(img, 0, 12, T, 1, Color("806848"))
			for x in range(2, T, 6):
				_rect(img, x, 2, 1, 9, Color("e8dcc0"))
		"mat":
			_rect(img, 0, 0, T, T, Color("e8c890"))
			_rect(img, 1, 4, 14, 9, Color("d04040"))
			_rect(img, 2, 5, 12, 7, Color("e86060"))
		"table":
			_rect(img, 0, 0, T, T, Color("e8c890"))
			_rect(img, 0, 2, T, 10, Color("a06830"))
			_rect(img, 0, 2, T, 2, Color("c88848"))
			_rect(img, 1, 12, 2, 4, Color("704818"))
			_rect(img, 13, 12, 2, 4, Color("704818"))
		"shelf":
			_rect(img, 0, 0, T, T, Color("805030"))
			for y in [2, 9]:
				_rect(img, 1, y, 14, 6, Color("402818"))
				var cols := [Color("d04040"), Color("4060d0"), Color("40a040"), Color("e0c040"), Color("a050c0")]
				for i in 6:
					_rect(img, 2 + i * 2, y + 1, 2, 5, cols[(i + y) % cols.size()])
		"pc":
			_rect(img, 0, 0, T, T, Color("e8c890"))
			_rect(img, 1, 1, 14, 14, Color("c0c8d0"))
			_rect(img, 3, 3, 10, 7, Color("304860"))
			_rect(img, 4, 4, 5, 3, Color("70b0f0"))
			_rect(img, 3, 12, 10, 2, Color("8890a0"))
		"counter":
			_rect(img, 0, 0, T, T, Color("f0f0f0"))
			_rect(img, 0, 4, T, 12, Color("d85858"))
			_rect(img, 0, 4, T, 3, Color("f8f8f8"))
			_rect(img, 0, 7, T, 1, Color("a03838"))
		"shopcounter":
			_rect(img, 0, 0, T, T, Color("f0f0f0"))
			_rect(img, 0, 4, T, 12, Color("5878c8"))
			_rect(img, 0, 4, T, 3, Color("f8f8f8"))
			_rect(img, 0, 7, T, 1, Color("384890"))
		"bed":
			_rect(img, 0, 0, T, T, Color("e8c890"))
			_rect(img, 1, 0, 14, 16, Color("8058c0"))
			_rect(img, 2, 1, 12, 4, Color("f8f8f8"))
			_rect(img, 1, 6, 14, 1, Color("6040a0"))
		"tv":
			_rect(img, 0, 0, T, T, Color("e8c890"))
			_rect(img, 1, 2, 14, 11, Color("383838"))
			_rect(img, 3, 4, 10, 7, Color("70a0d0"))
			_rect(img, 4, 13, 8, 2, Color("585858"))
		"plant":
			_rect(img, 0, 0, T, T, Color("e8c890"))
			_stamp(img, ["....gg..gg......", "...gLLggLLg.....", "..gLLLgLLLLg....", "...gLLLLLLg.....",
				"..gLLgLLgLLg....", "...ggLLLLgg.....", ".....gLLg.......", "....kppppk......",
				"....kppppk......", ".....kppk......."],
				{"g": Color("287028"), "L": Color("58b048"), "k": OUTLINE, "p": Color("c06838")}, 3, 4)
		"machine":
			_rect(img, 0, 0, T, T, Color("f0f0f0"))
			_rect(img, 1, 1, 14, 14, Color("a8a8b8"))
			_rect(img, 3, 3, 10, 5, Color("50d070"))
			for i in 3:
				_rect(img, 3 + i * 4, 10, 2, 2, Color("e04040"))
		"black":
			_rect(img, 0, 0, T, T, Color("000000"))
		_:
			_rect(img, 0, 0, T, T, Color("ff00ff"))
	var tex := _tex(img)
	_cache[key] = tex
	return tex


static func _grass(img: Image) -> void:
	_rect(img, 0, 0, T, T, Color("88d070"))
	for p in [[2, 2], [10, 3], [6, 8], [13, 10], [3, 13], [9, 14]]:
		_px(img, p[0], p[1], Color("68b050"))
		_px(img, p[0] + 1, p[1] - 1, Color("68b050"))
		_px(img, p[0] + 2, p[1], Color("68b050"))


static func _tall(img: Image, dark := Color("308838"), light := Color("58b850")) -> void:
	var blade := ["d...d", "dl.ld", ".dld.", "dlldd", ".ddd."]
	for p in [[1, 1], [9, 0], [5, 6], [11, 8], [0, 10], [7, 11]]:
		_stamp(img, blade, {"d": dark, "l": light}, p[0], p[1])


static func _tree(img: Image) -> void:
	_stamp(img, [
		".....kkkkkk.....", "...kkGGGGGGkk...", "..kGGLLGGGGGGk..", ".kGLLLGGGGGGGGk.",
		".kGLLGGGGGLGGDk.", "kGGGGGGGLLLGGDDk", "kGGGGGGGGGGGDDDk", "kDGGGGLLGGGGGDDk",
		".kDGGLLLGGGDDDk.", ".kDDGGGGGGDDDDk.", "..kDDDDDDDDDDk..", "...kkkDDDDkkk...",
		"......kttk......", "......kttk......", ".....kttttk.....", "......kkkk......"],
		{"k": Color("184818"), "G": Color("48a048"), "L": Color("78c868"), "D": Color("307830"), "t": Color("886038")})


# ---------------------------------------------------------------------------
# Bâtiments
# ---------------------------------------------------------------------------

## kind : house, lab, center, mart, gym. Taille en tuiles. La porte est en bas, au centre.
static func building(kind: String, w: int, h: int) -> Texture2D:
	var key := "b_%s_%d_%d" % [kind, w, h]
	if _cache.has(key):
		return _cache[key]
	var W := w * T
	var H := h * T
	var img := _img(W, H)
	var roof: Color = {"house": Color("d85040"), "lab": Color("8890a0"), "center": Color("e85858"), "mart": Color("4878d8"), "gym": Color("a07848")}.get(kind, Color("d85040"))
	var roof_dark := roof.darkened(0.3)
	var wall := Color("f8f0e0") if kind != "lab" else Color("f0f0f0")
	var roof_h := int(H * 0.5)
	# Toit
	_rect(img, 0, 0, W, roof_h, roof)
	for y in range(3, roof_h, 4):
		_rect(img, 0, y, W, 1, roof_dark)
	_rect(img, 0, roof_h - 2, W, 2, roof_dark.darkened(0.3))
	_rect(img, 0, 0, W, 1, OUTLINE)
	_rect(img, 0, 0, 1, roof_h, OUTLINE)
	_rect(img, W - 1, 0, 1, roof_h, OUTLINE)
	# Murs
	_rect(img, 1, roof_h, W - 2, H - roof_h, wall)
	_rect(img, 0, roof_h, 1, H - roof_h, OUTLINE)
	_rect(img, W - 1, roof_h, 1, H - roof_h, OUTLINE)
	_rect(img, 0, H - 1, W, 1, OUTLINE)
	_rect(img, 1, H - 3, W - 2, 2, wall.darkened(0.2))
	# Fenêtres
	var wy := roof_h + 4
	for wx in range(6, W - 12, 24):
		if absi(wx + 5 - W / 2) < 14:
			continue
		_rect(img, wx, wy, 11, 9, Color("405870"))
		_rect(img, wx + 1, wy + 1, 9, 7, Color("88c0f0"))
		_rect(img, wx + 5, wy + 1, 1, 7, Color("405870"))
	# Porte
	var dx := (w / 2) * T + 2
	_rect(img, dx, H - 14, 12, 13, Color("504030"))
	_rect(img, dx + 1, H - 13, 10, 12, Color("806040") if kind != "center" and kind != "mart" else Color("a8d0f0"))
	if kind == "center" or kind == "mart":
		_rect(img, dx + 6, H - 13, 1, 12, Color("506070"))
	# Enseigne
	if kind in ["center", "mart", "gym"]:
		var sx := W / 2 - 14
		var sy := roof_h - 12
		_rect(img, sx, sy, 28, 10, Color("f8f8f8"))
		_rect(img, sx, sy, 28, 1, OUTLINE)
		_rect(img, sx, sy + 9, 28, 1, OUTLINE)
		var letter: Color = roof.darkened(0.1)
		if kind == "center":
			_rect(img, sx + 12, sy + 2, 4, 6, letter)
			_rect(img, sx + 10, sy + 4, 8, 2, letter)
		elif kind == "mart":
			_rect(img, sx + 9, sy + 2, 10, 6, letter)
			_rect(img, sx + 11, sy + 3, 6, 2, Color("f8f8f8"))
		else:
			_rect(img, sx + 10, sy + 2, 8, 6, letter)
	var tex := _tex(img)
	_cache[key] = tex
	return tex


# ---------------------------------------------------------------------------
# Personnages
# ---------------------------------------------------------------------------

const LOOKS := {
	"player": {"h": "e03838", "H": "a02020", "w": "f8f8f8", "g": "503020", "c": "3870d0", "C": "28509c", "p": "303850", "b": "c03030"},
	"rival": {"h": "906030", "H": "684420", "w": "906030", "g": "906030", "c": "7050b0", "C": "503888", "p": "404040", "b": "604030"},
	"mom": {"h": "c06040", "H": "a04828", "w": "c06040", "g": "c06040", "c": "f0a0b0", "C": "d07888", "p": "f0a0b0", "b": "806060"},
	"chen": {"h": "c8c8c8", "H": "a0a0a0", "w": "c8c8c8", "g": "c8c8c8", "c": "f0f0f0", "C": "c0c0c8", "p": "806050", "b": "604030"},
	"nurse": {"h": "f088a8", "H": "d06080", "w": "f8f8f8", "g": "f088a8", "c": "f8f8f8", "C": "f0c0d0", "p": "f8f8f8", "b": "f088a8"},
	"clerk": {"h": "3858a8", "H": "283878", "w": "f8f8f8", "g": "402818", "c": "4878d8", "C": "3058a8", "p": "303030", "b": "303030"},
	"youngster": {"h": "f0c030", "H": "c09020", "w": "f8f8f8", "g": "402818", "c": "f0f0f0", "C": "c0c0c0", "p": "3060c0", "b": "c03030"},
	"bugcatcher": {"h": "f8f8f8", "H": "c0c0c0", "w": "40a040", "g": "402818", "c": "60b060", "C": "408040", "p": "c09858", "b": "604030"},
	"lass": {"h": "e09040", "H": "b06820", "w": "e09040", "g": "e09040", "c": "e04870", "C": "b03050", "p": "4060c0", "b": "604030"},
	"hiker": {"h": "805030", "H": "603818", "w": "805030", "g": "403020", "c": "c09048", "C": "906830", "p": "604828", "b": "403020"},
	"ace": {"h": "303030", "H": "181818", "w": "f0d040", "g": "303030", "c": "303848", "C": "202838", "p": "202020", "b": "a02020"},
	"oldman": {"h": "e0e0e0", "H": "b0b0b0", "w": "e0e0e0", "g": "e0e0e0", "c": "a08060", "C": "806040", "p": "605040", "b": "403020"},
	"girl": {"h": "402818", "H": "301808", "w": "402818", "g": "402818", "c": "f0d040", "C": "c0a020", "p": "e05050", "b": "604030"},
	"scientist": {"h": "607080", "H": "405060", "w": "607080", "g": "607080", "c": "f8f8f8", "C": "c8c8d0", "p": "404858", "b": "303030"},
}

const DOWN := [
	["................", ".....kkkkkk.....", "....khhhhhhk....", "...khhhwwhhhk...", "...khhhhhhhhk...",
	"..kHHHHHHHHHHk..", "..kgssssssssgk..", "..kgsessssesgk..", "...kssssssssk...", ".....kssssk.....",
	"...kcccwwccck...", "..ksccccccccsk..", "..ksCccccccCsk..", "...kppppppppk...", "...kppk..kppk...", "...kbbk..kbbk..."],
	["................", ".....kkkkkk.....", "....khhhhhhk....", "...khhhwwhhhk...", "...khhhhhhhhk...",
	"..kHHHHHHHHHHk..", "..kgssssssssgk..", "..kgsessssesgk..", "...kssssssssk...", ".....kssssk.....",
	"...kcccwwccck...", "..ksccccccccsk..", "..ksCccccccCsk..", "...kppppppppk...", "...kppk...kpk...", "...kbbk....k...."],
]
const UP := [
	["................", ".....kkkkkk.....", "....khhhhhhk....", "...khhhhhhhhk...", "...khhhhhhhhk...",
	"..khhhhhhhhhhk..", "..kggggggggggk..", "..kggggggggggk..", "...kggggggggk...", ".....kssssk.....",
	"...kcccccccck...", "..ksccccccccsk..", "..ksCccccccCsk..", "...kppppppppk...", "...kppk..kppk...", "...kbbk..kbbk..."],
	["................", ".....kkkkkk.....", "....khhhhhhk....", "...khhhhhhhhk...", "...khhhhhhhhk...",
	"..khhhhhhhhhhk..", "..kggggggggggk..", "..kggggggggggk..", "...kggggggggk...", ".....kssssk.....",
	"...kcccccccck...", "..ksccccccccsk..", "..ksCccccccCsk..", "...kppppppppk...", "...kppk...kpk...", "...kbbk....k...."],
]
const LEFT := [
	["................", ".....kkkkkk.....", "....khhhhhhk....", "...khhhhhhhhk...", "...khhhhhhhhk...",
	".kHHHHHHHhhhk...", "..ksssssgggk....", "..kesssssggk....", "...ksssssgk.....", "....kssssk......",
	"....kccccck.....", "....kcsscck.....", "....kccccck.....", "....kpppppk.....", "....kppkppk.....", "....kbbkbbk....."],
	["................", ".....kkkkkk.....", "....khhhhhhk....", "...khhhhhhhhk...", "...khhhhhhhhk...",
	".kHHHHHHHhhhk...", "..ksssssgggk....", "..kesssssggk....", "...ksssssgk.....", "....kssssk......",
	"....kccccck.....", "....kcsscck.....", "....kccccck.....", "....kpppppk.....", "...kppk.kpk.....", "..kbbk...kbk...."],
]


## Renvoie la texture d'un personnage : dir = "down"/"up"/"left"/"right", frame 0 (arrêt) ou 1/2 (marche).
static func character(look: String, dir: String, frame: int) -> Texture2D:
	var key := "c_%s_%s_%d" % [look, dir, frame]
	if _cache.has(key):
		return _cache[key]
	var l: Dictionary = LOOKS.get(look, LOOKS["player"])
	var pal := {"k": OUTLINE, "s": Color("f8c898"), "e": OUTLINE}
	for k in l:
		pal[k] = Color(l[k])
	var img := _img()
	var flip := false
	var rows: Array
	match dir:
		"down":
			rows = DOWN[0 if frame == 0 else 1]
			flip = frame == 2
		"up":
			rows = UP[0 if frame == 0 else 1]
			flip = frame == 2
		"left":
			rows = LEFT[0 if frame == 0 else 1]
		_:
			rows = LEFT[0 if frame == 0 else 1]
			flip = true
	_stamp(img, rows, pal, 0, 0, flip)
	var tex := _tex(img)
	_cache[key] = tex
	return tex


static func ball(open := false) -> Texture2D:
	var key := "ball_%s" % open
	if _cache.has(key):
		return _cache[key]
	var img := _img(12, 12)
	_stamp(img, ["....kkkk....", "..kkrrrrkk..", ".krrwrrrrrk.", ".krwrrrrrrk.", "krrrrrrrrrrk", "kkkkkwwkkkkk",
		"kwwwkwwkwwwk", "kwwwwkkwwwwk", ".kwwwwwwwwk.", ".kwwwwwwwwk.", "..kkwwwwkk..", "....kkkk...."],
		{"k": OUTLINE, "r": Color("e83838"), "w": Color("f8f8f8")})
	var tex := _tex(img)
	_cache[key] = tex
	return tex


static func emote() -> Texture2D:
	if _cache.has("emote"):
		return _cache["emote"]
	var img := _img(12, 14)
	_stamp(img, ["kkkkkkkkkkkk", "kwwwwwwwwwwk", "kwwwwrrwwwwk", "kwwwwrrwwwwk", "kwwwwrrwwwwk", "kwwwwrrwwwwk",
		"kwwwwrrwwwwk", "kwwwwwwwwwwk", "kwwwwrrwwwwk", "kwwwwwwwwwwk", "kkkkkkwkkkkk", ".....kwk....", "......k.....", "............"],
		{"k": OUTLINE, "w": Color("f8f8f8"), "r": Color("e03030")})
	var tex := _tex(img)
	_cache["emote"] = tex
	return tex


## Silhouette de remplacement tant que le vrai sprite n'est pas téléchargé.
static func placeholder() -> Texture2D:
	if _cache.has("placeholder"):
		return _cache["placeholder"]
	var img := _img(96, 96)
	for y in 96:
		for x in 96:
			var d := Vector2(x - 48, y - 56).length()
			if d < 26:
				img.set_pixel(x, y, Color(0.25, 0.25, 0.3, 0.8))
	var tex := _tex(img)
	_cache["placeholder"] = tex
	return tex
