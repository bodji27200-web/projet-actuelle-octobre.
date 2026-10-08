extends Node
## Données du jeu (générées par tools/build_data.py) : Pokémon, capacités, talents, objets.

const TYPES := ["normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
	"fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark", "fairy"]

const TYPE_COLORS := {
	"normal": Color("a8a878"), "fighting": Color("c03028"), "flying": Color("a890f0"),
	"poison": Color("a040a0"), "ground": Color("e0c068"), "rock": Color("b8a038"),
	"bug": Color("a8b820"), "ghost": Color("705898"), "steel": Color("b8b8d0"),
	"fire": Color("f08030"), "water": Color("6890f0"), "grass": Color("78c850"),
	"electric": Color("f8d030"), "psychic": Color("f85888"), "ice": Color("98d8d8"),
	"dragon": Color("7038f8"), "dark": Color("705848"), "fairy": Color("ee99ac"),
}

## Multiplicateurs attaquant -> défenseur (les cases absentes valent 1).
const CHART := {
	"normal": {"rock": 0.5, "ghost": 0.0, "steel": 0.5},
	"fighting": {"normal": 2.0, "flying": 0.5, "poison": 0.5, "rock": 2.0, "bug": 0.5, "ghost": 0.0, "steel": 2.0, "psychic": 0.5, "ice": 2.0, "dark": 2.0, "fairy": 0.5},
	"flying": {"fighting": 2.0, "rock": 0.5, "bug": 2.0, "steel": 0.5, "grass": 2.0, "electric": 0.5},
	"poison": {"poison": 0.5, "ground": 0.5, "rock": 0.5, "ghost": 0.5, "steel": 0.0, "grass": 2.0, "fairy": 2.0},
	"ground": {"flying": 0.0, "poison": 2.0, "rock": 2.0, "bug": 0.5, "steel": 2.0, "fire": 2.0, "grass": 0.5, "electric": 2.0},
	"rock": {"fighting": 0.5, "flying": 2.0, "ground": 0.5, "bug": 2.0, "steel": 0.5, "fire": 2.0, "ice": 2.0},
	"bug": {"fighting": 0.5, "flying": 0.5, "poison": 0.5, "ghost": 0.5, "steel": 0.5, "fire": 0.5, "grass": 2.0, "psychic": 2.0, "dark": 2.0, "fairy": 0.5},
	"ghost": {"normal": 0.0, "ghost": 2.0, "psychic": 2.0, "dark": 0.5},
	"steel": {"rock": 2.0, "steel": 0.5, "fire": 0.5, "water": 0.5, "electric": 0.5, "ice": 2.0, "fairy": 2.0},
	"fire": {"rock": 0.5, "bug": 2.0, "steel": 2.0, "fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 2.0, "dragon": 0.5},
	"water": {"ground": 2.0, "rock": 2.0, "fire": 2.0, "water": 0.5, "grass": 0.5, "dragon": 0.5},
	"grass": {"flying": 0.5, "poison": 0.5, "ground": 2.0, "rock": 2.0, "bug": 0.5, "steel": 0.5, "fire": 0.5, "water": 2.0, "grass": 0.5, "dragon": 0.5},
	"electric": {"flying": 2.0, "ground": 0.0, "water": 2.0, "grass": 0.5, "electric": 0.5, "dragon": 0.5},
	"psychic": {"fighting": 2.0, "poison": 2.0, "steel": 0.5, "psychic": 0.5, "dark": 0.0},
	"ice": {"flying": 2.0, "ground": 2.0, "steel": 0.5, "fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 0.5, "dragon": 2.0},
	"dragon": {"steel": 0.5, "dragon": 2.0, "fairy": 0.0},
	"dark": {"fighting": 0.5, "ghost": 2.0, "psychic": 2.0, "dark": 0.5, "fairy": 0.5},
	"fairy": {"fighting": 2.0, "poison": 0.5, "steel": 0.5, "fire": 0.5, "dragon": 2.0, "dark": 2.0},
}

const STAT_NAMES := ["PV", "Attaque", "Défense", "Atq. Spé.", "Déf. Spé.", "Vitesse"]

var pokemon := {}
var moves := {}
var abilities := {}
var items := {}
var natures: Array = []
var characteristics: Array = []
var exp_table := {}
var type_names := {}


func _ready() -> void:
	pokemon = _int_keys(_load("pokemon"))
	moves = _int_keys(_load("moves"))
	abilities = _int_keys(_load("abilities"))
	items = _load("items")
	var misc: Dictionary = _load("misc")
	natures = misc["natures"]
	characteristics = misc.get("characteristics", [])
	type_names = misc["types"]
	exp_table = _int_keys(misc["exp"])


func _load(file: String) -> Variant:
	var f := FileAccess.open("res://data/%s.json" % file, FileAccess.READ)
	return _intify(JSON.parse_string(f.get_as_text()))


## JSON ne connaît que les flottants : on remet les entiers en int.
func _intify(v: Variant) -> Variant:
	if v is float and v == floor(v):
		return int(v)
	if v is Array:
		var out := []
		for x in v:
			out.append(_intify(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _intify(v[k])
		return out
	return v


func _int_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[int(k)] = d[k]
	return out


func effectiveness(move_type: String, defender_types: Array) -> float:
	var m := 1.0
	var row: Dictionary = CHART.get(move_type, {})
	for t in defender_types:
		m *= row.get(t, 1.0)
	return m


func exp_at(growth: int, level: int) -> int:
	return exp_table[growth][clampi(level, 1, 100)]


func type_name(t: String) -> String:
	return type_names.get(t, t)


func move_name(id: int) -> String:
	return moves[id]["name"] if moves.has(id) else "???"


func item_name(id: String) -> String:
	return items[id]["name"] if items.has(id) else id


func ability_name(id: int) -> String:
	return abilities[id]["name"] if abilities.has(id) else "—"


func ability_ident(id: int) -> String:
	return abilities[id]["ident"] if abilities.has(id) else ""
