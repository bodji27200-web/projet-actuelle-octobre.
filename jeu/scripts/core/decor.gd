class_name Decor
extends RefCounted
## Décorations de la base secrète : catalogue, prix et pixel art.
## kind : plush (peluche d'un Pokémon), plant, furniture, carpet (au sol, on marche dessus), trophy (boss vaincu),
## statue (grande statue d'un Pokémon). Les trophées ne s'achètent pas : on les gagne en battant les boss.

const CATALOG := {
	"peluche_pikachu": {"name": "Peluche Pikachu", "kind": "plush", "sid": 25, "price": 3000},
	"peluche_evoli": {"name": "Peluche Évoli", "kind": "plush", "sid": 133, "price": 3000},
	"peluche_salameche": {"name": "Peluche Salamèche", "kind": "plush", "sid": 4, "price": 3000},
	"peluche_bulbizarre": {"name": "Peluche Bulbizarre", "kind": "plush", "sid": 1, "price": 3000},
	"peluche_carapuce": {"name": "Peluche Carapuce", "kind": "plush", "sid": 7, "price": 3000},
	"peluche_rondoudou": {"name": "Peluche Rondoudou", "kind": "plush", "sid": 39, "price": 2500},
	"peluche_ronflex": {"name": "Peluche Ronflex", "kind": "plush", "sid": 143, "price": 6000},
	"peluche_lokhlass": {"name": "Peluche Lokhlass", "kind": "plush", "sid": 131, "price": 5000},
	"peluche_psykokwak": {"name": "Peluche Psykokwak", "kind": "plush", "sid": 54, "price": 2500},
	"peluche_togepi": {"name": "Peluche Togepi", "kind": "plush", "sid": 175, "price": 3500},
	"peluche_marill": {"name": "Peluche Marill", "kind": "plush", "sid": 183, "price": 3500},
	"peluche_goupix": {"name": "Peluche Goupix", "kind": "plush", "sid": 37, "price": 3500},
	"peluche_mimiqui": {"name": "Peluche Mimiqui", "kind": "plush", "sid": 778, "price": 5000},
	"peluche_poussifeu": {"name": "Peluche Poussifeu", "kind": "plush", "sid": 255, "price": 3500},
	"peluche_mew": {"name": "Peluche Mew", "kind": "plush", "sid": 151, "price": 12000},
	"peluche_dracaufeu": {"name": "Grosse peluche Dracaufeu", "kind": "plush", "sid": 6, "price": 15000},
	"plante_verte": {"name": "Plante verte", "kind": "plant", "style": 0, "price": 1500},
	"palmier": {"name": "Palmier en pot", "kind": "plant", "style": 1, "price": 2500},
	"cactus": {"name": "Cactus", "kind": "plant", "style": 2, "price": 1200},
	"bonsai": {"name": "Bonsaï", "kind": "plant", "style": 3, "price": 4000},
	"fleurs_roses": {"name": "Pot de fleurs roses", "kind": "plant", "style": 4, "price": 1000},
	"fleurs_jaunes": {"name": "Pot de fleurs jaunes", "kind": "plant", "style": 5, "price": 1000},
	"table_bois": {"name": "Table en bois", "kind": "furniture", "style": "table", "price": 2000},
	"chaise": {"name": "Chaise", "kind": "furniture", "style": "chair", "price": 800},
	"lit": {"name": "Lit douillet", "kind": "furniture", "style": "bed", "price": 5000},
	"bureau": {"name": "Bureau", "kind": "furniture", "style": "desk", "price": 3000},
	"etagere": {"name": "Étagère à livres", "kind": "furniture", "style": "shelf", "price": 3500},
	"tele": {"name": "Télévision", "kind": "furniture", "style": "tv", "price": 6000},
	"coffre": {"name": "Coffre au trésor", "kind": "furniture", "style": "chest", "price": 4500},
	"lampe": {"name": "Lampe", "kind": "furniture", "style": "lamp", "price": 1500},
	"tapis_rouge": {"name": "Tapis rouge", "kind": "carpet", "color": "c04848", "price": 600},
	"tapis_bleu": {"name": "Tapis bleu", "kind": "carpet", "color": "4868c0", "price": 600},
	"tapis_vert": {"name": "Tapis vert", "kind": "carpet", "color": "48a058", "price": 600},
	"tapis_pokeball": {"name": "Tapis Poké Ball", "kind": "carpet", "color": "pokeball", "price": 1500},
	"statue_dracaufeu": {"name": "Statue Dracaufeu", "kind": "statue", "sid": 6, "price": 30000},
	"statue_mewtwo": {"name": "Statue Mewtwo", "kind": "statue", "sid": 150, "price": 50000},
	"statue_lugia": {"name": "Statue Lugia", "kind": "statue", "sid": 249, "price": 50000},
}

static var _cache := {}
static var _mats := {}


## Matériau « pierre » (statue grise) ou « or » (trophée) : l'icône du Pokémon en niveaux de gris teintés.
static func _material(tint: Color) -> ShaderMaterial:
	var key := tint.to_html()
	if _mats.has(key):
		return _mats[key]
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(0.25 + g * 0.9) * tint.rgb, c.a);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", tint)
	_mats[key] = m
	return m


## Infos d'une décoration (les trophées sont générés : « trophy_<espèce> »).
static func info(id: String) -> Dictionary:
	if CATALOG.has(id):
		return CATALOG[id]
	if id.begins_with("trophy_"):
		var sid := int(id.substr(7))
		var n: String = Data.pokemon.get(sid, {}).get("name", "?")
		return {"name": "Trophée : %s Boss" % n, "kind": "trophy", "sid": sid, "price": 0}
	return {"name": "?", "kind": "furniture", "style": "chest", "price": 0}


static func blocks(id: String) -> bool:
	return info(id)["kind"] != "carpet"


## Gagné en battant un boss : ajoute le trophée (une seule fois par boss).
static func give_trophy(sid: int) -> bool:
	var id := "trophy_%d" % sid
	if Game.decor.has(id) or Game.flag("trophy_got_%d" % sid):
		return false
	Game.decor[id] = 1
	Game.set_flag("trophy_got_%d" % sid)
	return true


## Nœud à poser sur la carte (case x, y) : pixel art + éventuellement l'icône du Pokémon.
static func make_node(id: String) -> Node2D:
	var d := info(id)
	var root := Node2D.new()
	var base := Sprite2D.new()
	base.centered = false
	base.texture = texture(id)
	root.add_child(base)
	if d["kind"] in ["plush", "trophy", "statue"]:
		var ic := Sprite2D.new()
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.centered = true
		Sprites.apply(ic, "icon", int(d["sid"]))
		match d["kind"]:
			"plush":
				ic.position = Vector2(8, 4)
				ic.scale = Vector2(0.75, 0.75)
			"trophy":
				ic.position = Vector2(8, 3)
				ic.scale = Vector2(0.6, 0.6)
				ic.material = _material(Color(1.0, 0.82, 0.3))
			"statue":
				ic.position = Vector2(8, -4)
				ic.scale = Vector2(1.0, 1.0)
				ic.material = _material(Color(0.85, 0.85, 0.9))
		root.add_child(ic)
	return root


static func texture(id: String) -> Texture2D:
	var d := info(id)
	var key := "%s_%s" % [d["kind"], str(d.get("style", d.get("color", "")))]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ol := PixelArt.OUTLINE
	match d["kind"]:
		"plush":
			# Coussin sous la peluche.
			PixelArt._rect(img, 2, 11, 12, 4, Color("e0a0b8"))
			PixelArt._rect(img, 2, 15, 12, 1, ol)
			PixelArt._rect(img, 3, 11, 10, 1, Color("f0c8d8"))
		"trophy":
			PixelArt._rect(img, 2, 11, 12, 5, Color("806040"))
			PixelArt._rect(img, 2, 11, 12, 1, Color("a07850"))
			PixelArt._rect(img, 5, 13, 6, 1, Color("f0c030"))
			PixelArt._rect(img, 2, 15, 12, 1, ol)
		"statue":
			PixelArt._rect(img, 2, 11, 12, 5, Color("909098"))
			PixelArt._rect(img, 2, 11, 12, 1, Color("b8b8c0"))
			PixelArt._rect(img, 2, 15, 12, 1, ol)
		"carpet":
			if d["color"] == "pokeball":
				PixelArt._rect(img, 1, 1, 14, 7, Color("e04040"))
				PixelArt._rect(img, 1, 8, 14, 7, Color("f0f0f0"))
				PixelArt._rect(img, 1, 7, 14, 2, ol)
				PixelArt._rect(img, 6, 6, 4, 4, ol)
				PixelArt._rect(img, 7, 7, 2, 2, Color("f0f0f0"))
			else:
				var c := Color(d["color"])
				PixelArt._rect(img, 1, 1, 14, 14, c)
				PixelArt._rect(img, 3, 3, 10, 10, c.lightened(0.18))
				PixelArt._rect(img, 5, 5, 6, 6, c)
		"plant":
			PixelArt._rect(img, 5, 11, 6, 5, Color("b06838"))
			PixelArt._rect(img, 4, 11, 8, 1, Color("c88050"))
			match int(d["style"]):
				0:
					PixelArt._rect(img, 3, 3, 10, 8, Color("3c9848"))
					PixelArt._rect(img, 5, 1, 6, 4, Color("58b860"))
				1:
					PixelArt._rect(img, 7, 4, 2, 7, Color("806040"))
					PixelArt._rect(img, 1, 1, 14, 3, Color("48a050"))
					PixelArt._rect(img, 3, 0, 4, 2, Color("68c070"))
				2:
					PixelArt._rect(img, 6, 2, 4, 9, Color("3c9048"))
					PixelArt._rect(img, 3, 5, 3, 2, Color("3c9048"))
					PixelArt._rect(img, 10, 4, 3, 2, Color("3c9048"))
				3:
					PixelArt._rect(img, 7, 6, 2, 5, Color("705030"))
					PixelArt._rect(img, 2, 2, 12, 5, Color("2c7838"))
				4, 5:
					PixelArt._rect(img, 4, 6, 8, 5, Color("3c9848"))
					var fc := Color("f070a8") if int(d["style"]) == 4 else Color("f8d030")
					for p in [[4, 4], [8, 3], [11, 5], [6, 6]]:
						PixelArt._rect(img, p[0], p[1], 2, 2, fc)
		"furniture":
			match str(d["style"]):
				"table":
					PixelArt._rect(img, 1, 5, 14, 5, Color("b07840"))
					PixelArt._rect(img, 1, 5, 14, 1, Color("d09858"))
					PixelArt._rect(img, 2, 10, 2, 5, Color("805028"))
					PixelArt._rect(img, 12, 10, 2, 5, Color("805028"))
				"chair":
					PixelArt._rect(img, 4, 2, 8, 6, Color("b07840"))
					PixelArt._rect(img, 4, 8, 8, 3, Color("d09858"))
					PixelArt._rect(img, 4, 11, 2, 4, Color("805028"))
					PixelArt._rect(img, 10, 11, 2, 4, Color("805028"))
				"bed":
					PixelArt._rect(img, 1, 1, 14, 14, Color("e8e8f0"))
					PixelArt._rect(img, 1, 6, 14, 9, Color("5878d0"))
					PixelArt._rect(img, 3, 2, 10, 3, Color("ffffff"))
				"desk":
					PixelArt._rect(img, 0, 4, 16, 8, Color("906038"))
					PixelArt._rect(img, 0, 4, 16, 2, Color("b07848"))
					PixelArt._rect(img, 2, 1, 6, 4, Color("e0e0e8"))
				"shelf":
					PixelArt._rect(img, 1, 0, 14, 16, Color("8a5a30"))
					for y in [3, 8, 13]:
						PixelArt._rect(img, 2, y - 2, 12, 2, Color("e05050"))
						PixelArt._rect(img, 6, y - 2, 3, 2, Color("5070d0"))
						PixelArt._rect(img, 2, y, 12, 1, Color("603818"))
				"tv":
					PixelArt._rect(img, 1, 3, 14, 10, Color("383840"))
					PixelArt._rect(img, 2, 4, 12, 7, Color("70b8e8"))
					PixelArt._rect(img, 6, 13, 4, 2, Color("383840"))
				"chest":
					PixelArt._rect(img, 2, 5, 12, 10, Color("a06830"))
					PixelArt._rect(img, 2, 5, 12, 3, Color("c08848"))
					PixelArt._rect(img, 7, 8, 2, 3, Color("f0c030"))
				"lamp":
					PixelArt._rect(img, 4, 1, 8, 5, Color("f8e8a0"))
					PixelArt._rect(img, 7, 6, 2, 8, Color("707078"))
					PixelArt._rect(img, 5, 14, 6, 2, Color("505058"))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
