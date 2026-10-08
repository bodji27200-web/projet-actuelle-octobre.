class_name Ranked
extends RefCounted
## Combats classés entre joueurs : formats Smogon (tiers National Dex réels), clauses, Elo.

## max_tier : tier le plus fort autorisé (« OU » interdit Uber et AG). only_tier : seul ce tier (Little Cup).
const FORMATS := {
	"ou": {"name": "Classé OU", "desc": "Simple 6 contre 6, niveau 100. Interdits : Uber et AG.", "level": 100, "double": false, "max_tier": "OU"},
	"ubers": {"name": "Ubers", "desc": "Simple, niveau 100. Seuls les AG (Arceus, Rayquaza Méga...) sont interdits.", "level": 100, "double": false, "max_tier": "Uber"},
	"uu": {"name": "UnderUsed (UU)", "desc": "Simple, niveau 100. Interdits : OU, UUBL et au-dessus.", "level": 100, "double": false, "max_tier": "UU"},
	"ru": {"name": "RarelyUsed (RU)", "desc": "Simple, niveau 100. Interdits : UU, RUBL et au-dessus.", "level": 100, "double": false, "max_tier": "RU"},
	"lc": {"name": "Little Cup", "desc": "Simple, niveau 5. Seulement les Pokémon de base (tier LC).", "level": 5, "double": false, "only_tier": "LC"},
	"vgc": {"name": "Double (style VGC)", "desc": "Combat double, niveau 50. Clause Objet, 2 légendaires maximum, pas de fabuleux.", "level": 50, "double": true, "max_tier": "Uber", "item_clause": true, "max_legends": 2},
}
## Clauses appliquées à tous les formats (règles de Smogon).
const CLAUSES := ["Clause Sommeil : un seul Pokémon adverse endormi à la fois.", "Clause Espèce : pas deux fois le même Pokémon.",
	"Clause OHKO : Abîme, Guillotine, Empal'Korne et Glaciation interdits.", "Clause Esquive : Reflet et Lilliput interdits.",
	"Clause Lunatique : le talent Lunatique est interdit.", "Clause Combat Sans Fin : match nul au 300e tour."]
const OHKO_MOVES := ["fissure", "guillotine", "horn-drill", "sheer-cold"]
const EVASION_MOVES := ["double-team", "minimize"]
const TURN_LIMIT := 300
const START_ELO := 1000
const K := 32

static var _tiers := {}
static var _order: Array = []


static func _load() -> void:
	if not _tiers.is_empty():
		return
	var f := FileAccess.open("res://data/tiers.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	_tiers = d["tiers"]
	_order = d["order"]


## Tier Smogon d'un identifiant Pokémon (forme comprise).
static func tier_of(pid: int) -> String:
	_load()
	return _tiers.get(str(pid), "RU")


## Rang du tier : 0 = le plus fort (AG). Plus le nombre est grand, plus le Pokémon est faible.
static func rank(t: String) -> int:
	_load()
	var i := _order.find(t)
	return i if i >= 0 else _order.size()


## Tier effectif : celui du Pokémon, ou celui de sa Méga-Évolution s'il tient sa Méga-Gemme.
static func effective_tier(m: Pokemon) -> String:
	var t := tier_of(m.sprite_id())
	if Data.mega_stones.has(m.held_item):
		var mp: int = Data.mega_stones[m.held_item]
		if Data.pokemon.has(mp) and Data.pokemon[mp].get("species", mp) == m.species:
			var mt := tier_of(mp)
			if rank(mt) < rank(t):
				t = mt
	return t


## Liste des problèmes de l'équipe pour ce format (vide = équipe valide).
static func validate(team: Array, fmt: String) -> Array:
	var f: Dictionary = FORMATS[fmt]
	var errs := []
	var mons := team.filter(func(m): return not m.is_egg)
	if mons.size() < (2 if f["double"] else 1):
		errs.append("Il faut au moins %d Pokémon (hors Œufs)." % (2 if f["double"] else 1))
	var seen := {}
	var items := {}
	var legends := 0
	for m: Pokemon in mons:
		var nm := m.name()
		if seen.has(m.species):
			errs.append("Clause Espèce : %s est en double." % Data.pokemon[m.species]["name"])
		seen[m.species] = true
		var t := effective_tier(m)
		if f.has("only_tier"):
			if t != f["only_tier"]:
				errs.append("%s n'est pas autorisé en %s (tier %s)." % [nm, f["name"], t])
		elif rank(t) < rank(f["max_tier"]):
			errs.append("%s est trop fort pour le format %s (tier %s)." % [nm, f["name"], t])
		var d: Dictionary = Data.pokemon[m.species]
		if f.has("max_legends"):
			if d.get("mythical", false):
				errs.append("%s est un Pokémon fabuleux : interdit en %s." % [nm, f["name"]])
			elif d.get("legendary", false):
				legends += 1
		if f.get("item_clause", false) and m.held_item != "":
			if items.has(m.held_item):
				errs.append("Clause Objet : %s est tenu deux fois." % Data.item_name(m.held_item))
			items[m.held_item] = true
		for mv in m.moves:
			var ident: String = Data.moves[mv["id"]]["ident"]
			if ident in OHKO_MOVES:
				errs.append("Clause OHKO : %s connaît %s." % [nm, Data.move_name(mv["id"])])
			if ident in EVASION_MOVES:
				errs.append("Clause Esquive : %s connaît %s." % [nm, Data.move_name(mv["id"])])
		if Data.ability_ident(m.ability) == "moody":
			errs.append("Clause Lunatique : %s a le talent Lunatique." % nm)
	if legends > int(f.get("max_legends", 99)):
		errs.append("%d légendaires : %d au maximum en %s." % [legends, f["max_legends"], f["name"]])
	return errs


## Copies de l'équipe pour le combat : niveau du format, PV et PP au maximum. L'équipe réelle n'est pas touchée.
static func battle_team(team: Array, fmt: String) -> Array:
	var lvl: int = FORMATS[fmt]["level"]
	var out := []
	for m: Pokemon in team:
		if m.is_egg:
			continue
		var c := Pokemon.from_dict(m.to_dict())
		c.level = lvl
		c.recalc_stats()
		c.heal_full()
		c.hp = c.max_hp()
		out.append(c)
	return out


static func expected(a: int, b: int) -> float:
	return 1.0 / (1.0 + pow(10.0, (b - a) / 400.0))


## Nouveaux classements [gagnant, perdant] (ou nul : score 0,5 chacun).
static func elo_after(winner: int, loser: int, draw := false) -> Array:
	var ea := expected(winner, loser)
	var sa := 0.5 if draw else 1.0
	var nw := int(round(winner + K * (sa - ea)))
	var nl := int(round(loser + K * ((1.0 - sa) - (1.0 - ea))))
	return [nw, maxi(100, nl)]
