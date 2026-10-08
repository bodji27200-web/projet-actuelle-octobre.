class_name Battle
extends RefCounted
## Moteur de combat (simple, double, coop) avec les règles des jeux récents :
## capacités, talents et objets tenus de toutes les générations, Méga-Évolution, capacités Z,
## météo, champs, pièges. Ne dessine rien : chaque action renvoie une liste d'événements
## ({"t": "msg"/"hp"/"send"/"faint"/"anim"/...}) que l'écran de combat joue ensuite.

const STAGE_KEYS := ["hp", "atk", "def", "spa", "spd", "spe", "acc", "eva"]
const STAT_LABEL := {"atk": "L'Attaque", "def": "La Défense", "spa": "L'Attaque Spéciale",
	"spd": "La Défense Spéciale", "spe": "La Vitesse", "acc": "La Précision", "eva": "L'Esquive"}
const STAT_INDEX := {"atk": 1, "def": 2, "spa": 3, "spd": 4, "spe": 5}
const STRUGGLE := 165
const SELF_TARGETS := ["user", "users-field", "user-and-allies", "all-allies", "user-or-ally", "ally"]
const SPREAD_TARGETS := ["all-opponents", "all-other-pokemon"]
const FIELD_TARGETS := ["entire-field", "opponents-field", "users-field", "all-pokemon"]
## Capacités en deux tours (message du premier tour). Les semi-invulnérables cachent le Pokémon.
const TWO_TURN := {"fly": "%s s'envole !", "dig": "%s s'enterre !", "dive": "%s plonge !",
	"bounce": "%s bondit très haut !", "solar-beam": "%s absorbe la lumière !", "solar-blade": "%s absorbe la lumière !",
	"skull-bash": "%s baisse la tête !", "sky-attack": "%s est entouré d'une lumière intense !",
	"razor-wind": "%s crée un tourbillon !", "phantom-force": "%s disparaît !", "shadow-force": "%s disparaît !",
	"freeze-shock": "%s est entouré d'un air glacial !", "ice-burn": "%s est entouré d'un air glacial !",
	"geomancy": "%s absorbe l'énergie !", "meteor-beam": "%s déborde d'énergie cosmique !",
	"electro-shot": "%s absorbe de l'électricité !", "sky-drop": "%s s'envole avec sa cible !"}
const SEMI_INVULN := ["fly", "dig", "dive", "bounce", "phantom-force", "shadow-force", "sky-drop"]
const OHKO := ["fissure", "guillotine", "horn-drill", "sheer-cold"]
const RAMPAGE := ["thrash", "petal-dance", "outrage", "raging-fury"]
const RECHARGE := ["hyper-beam", "giga-impact", "blast-burn", "hydro-cannon", "frenzy-plant", "rock-wrecker",
	"roar-of-time", "prismatic-laser", "eternabeam", "meteor-assault"]
const STATUS_TEXT := {"psn": "%s est empoisonné !", "tox": "%s est gravement empoisonné !",
	"par": "%s est paralysé ! Il aura du mal à attaquer !", "slp": "%s s'endort !",
	"brn": "%s est brûlé !", "frz": "%s est gelé !"}
const AILMENT_STATUS := {"paralysis": "par", "sleep": "slp", "freeze": "frz", "burn": "brn", "poison": "psn"}
const TRAP_MOVES := ["bind", "wrap", "fire-spin", "clamp", "whirlpool", "sand-tomb", "magma-storm", "infestation",
	"snap-trap", "thunder-cage"]
const WEATHER_NAMES := {"rain": "Pluie", "sun": "Zénith", "sandstorm": "Tempête de sable", "hail": "Grêle",
	"snow": "Neige", "heavy-rain": "Pluie battante", "harsh-sun": "Soleil intense", "strong-winds": "Vent mystérieux"}
const TERRAIN_NAMES := {"electric": "Champ Électrifié", "grassy": "Champ Herbu", "misty": "Champ Brumeux", "psychic": "Champ Psychique"}

## Objets qui renforcent un type de 20 % (et Plaques, Encens).
const TYPE_ITEMS := {"silk-scarf": "normal", "black-belt": "fighting", "sharp-beak": "flying", "poison-barb": "poison",
	"soft-sand": "ground", "hard-stone": "rock", "silver-powder": "bug", "spell-tag": "ghost", "metal-coat": "steel",
	"charcoal": "fire", "mystic-water": "water", "miracle-seed": "grass", "magnet": "electric", "twisted-spoon": "psychic",
	"never-melt-ice": "ice", "dragon-fang": "dragon", "black-glasses": "dark", "fairy-feather": "fairy",
	"sea-incense": "water", "wave-incense": "water", "rose-incense": "grass", "odd-incense": "psychic", "rock-incense": "rock",
	"flame-plate": "fire", "splash-plate": "water", "zap-plate": "electric", "meadow-plate": "grass", "icicle-plate": "ice",
	"fist-plate": "fighting", "toxic-plate": "poison", "earth-plate": "ground", "sky-plate": "flying", "mind-plate": "psychic",
	"insect-plate": "bug", "stone-plate": "rock", "spooky-plate": "ghost", "draco-plate": "dragon", "dread-plate": "dark",
	"iron-plate": "steel", "pixie-plate": "fairy"}
const PLATES := ["flame-plate", "splash-plate", "zap-plate", "meadow-plate", "icicle-plate", "fist-plate", "toxic-plate",
	"earth-plate", "sky-plate", "mind-plate", "insect-plate", "stone-plate", "spooky-plate", "draco-plate", "dread-plate",
	"iron-plate", "pixie-plate"]
## Baies qui divisent par deux un coup super efficace d'un type (Baie Zalis : tout coup Normal).
const RESIST_BERRIES := {"occa-berry": "fire", "passho-berry": "water", "wacan-berry": "electric", "rindo-berry": "grass",
	"yache-berry": "ice", "chople-berry": "fighting", "kebia-berry": "poison", "shuca-berry": "ground", "coba-berry": "flying",
	"payapa-berry": "psychic", "tanga-berry": "bug", "charti-berry": "rock", "kasib-berry": "ghost", "haban-berry": "dragon",
	"colbur-berry": "dark", "babiri-berry": "steel", "roseli-berry": "fairy", "chilan-berry": "normal"}
## Baies de soin et de statut.
const PINCH_STAT_BERRIES := {"liechi-berry": "atk", "ganlon-berry": "def", "salac-berry": "spe", "petaya-berry": "spa", "apicot-berry": "spd"}
const STATUS_BERRIES := {"cheri-berry": ["par"], "chesto-berry": ["slp"], "pecha-berry": ["psn", "tox"], "rawst-berry": ["brn"],
	"aspear-berry": ["frz"], "lum-berry": ["par", "slp", "psn", "tox", "brn", "frz", "conf"], "persim-berry": ["conf"]}
const CONFUSE_BERRIES := ["figy-berry", "wiki-berry", "mago-berry", "aguav-berry", "iapapa-berry"]
const WEATHER_ROCKS := {"rain": "damp-rock", "sun": "heat-rock", "sandstorm": "smooth-rock", "hail": "icy-rock", "snow": "icy-rock"}
const TERRAIN_SEEDS := {"electric": "electric-seed", "grassy": "grassy-seed", "misty": "misty-seed", "psychic": "psychic-seed"}
const MEMORIES := {"fighting-memory": "fighting", "flying-memory": "flying", "poison-memory": "poison", "ground-memory": "ground",
	"rock-memory": "rock", "bug-memory": "bug", "ghost-memory": "ghost", "steel-memory": "steel", "fire-memory": "fire",
	"water-memory": "water", "grass-memory": "grass", "electric-memory": "electric", "psychic-memory": "psychic",
	"ice-memory": "ice", "dragon-memory": "dragon", "dark-memory": "dark", "fairy-memory": "fairy"}
const DRIVES := {"douse-drive": "water", "shock-drive": "electric", "burn-drive": "fire", "chill-drive": "ice"}
## Talents qui changent le type des capacités Normal (+20 %).
const ATE_ABILITIES := {"pixilate": "fairy", "aerilate": "flying", "refrigerate": "ice", "galvanize": "electric", "dragonize": "dragon"}
## Talents ignorés par Brise Moule / Turbo Brasier / Téra-Voltage.
const BREAKABLE := ["battle-armor", "clear-body", "damp", "dry-skin", "filter", "flash-fire", "flower-gift", "heatproof",
	"hyper-cutter", "immunity", "inner-focus", "insomnia", "keen-eye", "leaf-guard", "levitate", "lightning-rod", "limber",
	"magma-armor", "marvel-scale", "motor-drive", "oblivious", "own-tempo", "sand-veil", "shell-armor", "shield-dust", "simple",
	"snow-cloak", "solid-rock", "soundproof", "sticky-hold", "storm-drain", "sturdy", "suction-cups", "tangled-feet",
	"thick-fat", "unaware", "vital-spirit", "volt-absorb", "water-absorb", "water-veil", "white-smoke", "wonder-guard",
	"big-pecks", "contrary", "friend-guard", "heavy-metal", "light-metal", "magic-bounce", "multiscale", "sap-sipper",
	"telepathy", "wonder-skin", "aroma-veil", "bulletproof", "flower-veil", "fur-coat", "overcoat", "sweet-veil",
	"dazzling", "disguise", "fluffy", "queenly-majesty", "water-bubble", "mirror-armor", "punk-rock", "ice-scales",
	"ice-face", "pastel-veil", "armor-tail", "earth-eater", "good-as-gold", "purifying-salt", "well-baked-body",
	"wind-rider", "guard-dog", "thermal-exchange", "tera-shell", "prism-armor", "shadow-shield", "full-metal-body"]
## Talents qu'on ne peut ni copier ni échanger.
const UNCOPYABLE := ["multitype", "stance-change", "schooling", "comatose", "shields-down", "disguise", "rks-system",
	"battle-bond", "power-construct", "ice-face", "gulp-missile", "zero-to-hero", "commander", "tera-shift", "trace",
	"wonder-guard", "illusion", "imposter", "receiver", "power-of-alchemy", "neutralizing-gas", "hunger-switch", "as-one-glastrier",
	"as-one-spectrier", "protosynthesis", "quark-drive", "flower-gift", "forecast"]


class Battler:
	var mon: Pokemon
	var side := 0
	var slot := 0
	var owner := 0
	var party_index := 0
	var stages := {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0, "acc": 0, "eva": 0}
	var types: Array = []
	var ability := 0
	var item := ""
	var item_lost := ""
	var berry_eaten := false
	var form_id := 0
	var f_stats: Array = []
	var mega := false
	var confusion := 0
	var flinch := false
	var seeded := false
	var seeded_by: Battler = null
	var substitute := 0
	var trap_turns := 0
	var trap_move := ""
	var trap_by: Battler = null
	var charging := 0
	var charge_target := {}
	var invuln := ""
	var recharge := false
	var rampage := 0
	var rampage_move := 0
	var disable_move := 0
	var disable_turns := 0
	var encore_move := 0
	var encore_turns := 0
	var taunt := 0
	var protect_chain := 0
	var protected := false
	var protect_kind := ""
	var endure := false
	var focus_energy := false
	var crit_bonus := 0
	var rage := false
	var last_move := 0
	var last_failed := false
	var transformed := false
	var t_moves: Array = []
	var t_stats: Array = []
	var cursed := false
	var nightmare := false
	var perish := 0
	var destiny_bond := false
	var grudge := false
	var ingrain := false
	var aqua_ring := false
	var yawn := 0
	var charged := false
	var stockpile := 0
	var curled := false
	var minimized := false
	var foresight := false
	var miracle_eye := false
	var mean_look := false
	var attract := false
	var attract_by: Battler = null
	var torment := false
	var uproar := 0
	var lock_on := false
	var rollout := 0
	var fury_cutter := 0
	var echo := 0
	var turns := 0
	var toxic_n := 0
	var flash_fire := false
	var imprison := false
	var moved := false
	var hit_phys := 0
	var hit_spec := 0
	var last_dmg := 0
	var hit_by_foe := false
	var fainted := false
	var empty := false
	var choice_move := 0
	var unburden := false
	var suppressed := false
	var heal_block := 0
	var embargo := 0
	var magnet_rise := 0
	var telekinesis := 0
	var grounded := false
	var laser_focus := 0
	var salt_cure := false
	var glaive := false
	var octolock: Battler = null
	var tar_shot := false
	var throat_chop := 0
	var no_retreat := false
	var power_trick := false
	var stock_def := 0
	var stock_spd := 0
	var raised_turn := false
	var lowered_turn := false
	var truant_off := false
	var slow_start := 0
	var proto := ""
	var added_type := ""
	var disguise_broken := false
	var ice_face_broken := false
	var gulp := ""
	var micle := false
	var custap := false
	var quick := false
	var focus_punch := false
	var beak_blast := false
	var shell_trap := false
	var helping := false
	var center := false
	var magic_coat := false
	var snatch := false
	var electrify := false
	var powder := false
	var syrup := 0
	var used_moves: Array = []
	var damaged_turn := false
	var switched_in := true
	var intimidated := false

	func moves() -> Array:
		return t_moves if transformed else mon.moves

	## Stat brute (sans modificateur) : forme de combat, Morphing, Astuce Force.
	func raw(i: int) -> int:
		var s: int
		if transformed:
			s = t_stats[i]
		elif f_stats.size() == 6:
			s = f_stats[i]
		else:
			s = mon.stats[i]
		if power_trick and (i == 1 or i == 2):
			var other := 2 if i == 1 else 1
			s = t_stats[other] if transformed else (f_stats[other] if f_stats.size() == 6 else mon.stats[other])
		return s

	func alive() -> bool:
		return not empty and not fainted and mon.hp > 0

	func max_hp() -> int:
		return mon.max_hp()

	func hp_frac() -> float:
		return float(mon.hp) / maxf(1.0, mon.max_hp())

	func sprite_id() -> int:
		return form_id if form_id != 0 else mon.sprite_id()


class BSide:
	var party: Array = []      # tous les Pokémon du camp (plusieurs dresseurs possibles)
	var owners: Array = []     # propriétaire de chaque Pokémon (indice de dresseur)
	var slots: Array = []      # Battler sur le terrain, un par emplacement
	var slot_owner: Array = [] # dresseur qui contrôle chaque emplacement
	var names: Array = []      # nom de chaque dresseur du camp
	var reflect := 0
	var light_screen := 0
	var aurora_veil := 0
	var mist := 0
	var safeguard := 0
	var tailwind := 0
	var lucky_chant := 0
	var spikes := 0
	var toxic_spikes := 0
	var stealth_rock := false
	var sticky_web := false
	var future_turns := 0
	var future_damage := 0
	var future_slot := 0
	var wish_turns := 0
	var wish_hp := 0
	var wish_slot := 0
	var healing_wish := false
	var wide_guard := false
	var quick_guard := false
	var mat_block := false
	var crafty_shield := false
	var fainted_count := 0
	var fainted_last_turn := false
	var mega_used := {}
	var z_used := {}

	var b: Battler:
		get:
			return slots[0] if slots.size() > 0 else null


var sides: Array = [BSide.new(), BSide.new()]
var wild := true
var trainer := {}
var trainers: Array = []
var player_name := "Vous"
var weather := ""
var weather_turns := 0
var terrain := ""
var terrain_turns := 0
var trick_room := 0
var wonder_room := 0
var magic_room := 0
var gravity := 0
var fairy_lock := 0
var mud_sport := 0
var water_sport := 0
var ion_deluge := false
var turn := 0
var events: Array = []
var over := false
var result := ""
## Emplacements du joueur à remplacer : [{slot, owner, baton}]
var need_switch: Array = []
var escape_attempts := 0
var participants := {}
var leveled := {}
var cave := false
## Combat contre un Pokémon pêché (Scuba Ball plus efficace).
var fishing := false
var ai_potions := 0
var pay_day := 0
var caught: Pokemon = null
var caught_owner := 0
var caught_species := []
var actions := {}
var _spread := false
var _order: Array = []
var _cur_move := {}
var _last_move_used := 0
## Tests : force la réussite des jets de précision.
var always_hit := false
## Multi Exp activé, par dresseur du camp du joueur.
var exp_share: Array = [false, false]
## Niveau d'intelligence de l'IA adverse (0 sauvage, 1 dresseur, 2 Champion, 3 fin de jeu).
var ai_level := 1
## Le joueur peut-il méga-évoluer / utiliser une capacité Z (objet rare).
var can_mega := [false, false]
var can_z := [false, false]
## En coop : qui, dans le camp du joueur, possède le Méga-Anneau / le Bracelet Z (vide = tout le monde).
var mega_owners := []
var z_owners := []
var aura := ""
## Plus gros coup infligé par chaque dresseur du camp du joueur : {dmg, move, target}.
var best_hit := [{}, {}]
## Combat entre joueurs : le camp 1 est joué par l'autre joueur (pas d'IA, pas d'expérience, pas d'argent).
var pvp := false
## Clause Sommeil (Smogon) : un seul Pokémon adverse endormi à la fois par vos capacités.
var sleep_clause := false
## Clause de combat sans fin : match nul au-delà de ce nombre de tours (0 = pas de limite).
var turn_limit := 0
## PvP : emplacements du camp 1 à remplacer (choix de l'autre joueur).
var foe_need_switch: Array = []


## p_parties / e_parties : une équipe par dresseur du camp.
## opts : double (2 emplacements même avec un seul dresseur), boss (le Pokémon adverse est un boss),
## ai (niveau de l'IA), aura (boss à aura : "fire", "dragon"...).
func _init(p_parties: Array, e_parties: Array, is_wild: bool, trainer_infos: Variant = {}, opts := {}) -> void:
	wild = is_wild
	if trainer_infos is Dictionary:
		trainers = [trainer_infos] if not trainer_infos.is_empty() else []
	else:
		trainers = trainer_infos
	trainer = trainers[0] if trainers.size() > 0 else {}
	for t in trainers:
		ai_potions += int(t.get("potions", 0))
	# Compatibilité : une simple liste de Pokémon = une seule équipe.
	if p_parties.size() > 0 and p_parties[0] is Pokemon:
		p_parties = [p_parties]
	if e_parties.size() > 0 and e_parties[0] is Pokemon:
		e_parties = [e_parties] if not (is_wild and opts.get("wild_double", false)) else e_parties.map(func(m): return [m])
	_fill(sides[0], p_parties, opts.get("double", false), opts.get("player_names", []))
	_fill(sides[1], e_parties, opts.get("double", false) and e_parties.size() == 1, trainers.map(func(t): return t.get("name", "")))
	if opts.get("boss", false):
		for m in sides[1].party:
			m.boss = true
	ai_level = int(opts.get("ai", 0 if is_wild else 1))
	for t in trainers:
		ai_level = maxi(ai_level, int(t.get("ai", 0)))
	aura = opts.get("aura", "")
	can_mega = [opts.get("mega", false), not is_wild and ai_level >= 2]
	can_z = [opts.get("zmove", false), not is_wild and ai_level >= 2]
	mega_owners = opts.get("mega_owners", [])
	z_owners = opts.get("z_owners", [])
	pvp = opts.get("pvp", false)
	sleep_clause = opts.get("sleep_clause", pvp)
	turn_limit = int(opts.get("turn_limit", 0))
	if pvp:
		ai_level = 0
		can_mega[1] = opts.get("foe_mega", false)
		can_z[1] = opts.get("foe_zmove", false)


func _fill(side: BSide, parties: Array, double: bool, names: Array) -> void:
	for o in parties.size():
		for m in parties[o]:
			side.party.append(m)
			side.owners.append(o)
	side.names = names
	var n := parties.size()
	if n == 1 and double:
		side.slot_owner = [0, 0]
	else:
		side.slot_owner = range(n)
	side.slots.resize(side.slot_owner.size())


func is_double() -> bool:
	return sides[0].slots.size() > 1 or sides[1].slots.size() > 1


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

func msg(text: String) -> void:
	events.append({"t": "msg", "text": text})


func flush() -> Array:
	var out := events
	events = []
	return out


func actives(side_i := -1) -> Array:
	var out := []
	for s in ([0, 1] if side_i < 0 else [side_i]):
		for b: Battler in sides[s].slots:
			if b != null and b.alive():
				out.append(b)
	if side_i < 0:
		out.sort_custom(func(a, c): return speed(a) > speed(c) if trick_room == 0 else speed(a) < speed(c))
	return out


## Pokémon sur le terrain, sans tri (utilisé par les talents pour éviter une boucle avec la vitesse).
func _on_field() -> Array:
	var out := []
	for s in [0, 1]:
		for b in sides[s].slots:
			if b != null and b.alive():
				out.append(b)
	return out


func _first_active(side_i: int) -> Battler:
	var a := actives(side_i)
	return a[0] if a.size() > 0 else null


func foes(b: Battler) -> Array:
	return actives(1 - b.side)


func ally(b: Battler) -> Battler:
	for o: Battler in actives(b.side):
		if o != b:
			return o
	return null


## Adversaire par défaut (celui en face, sinon le premier debout).
func foe(b: Battler) -> Battler:
	var f := foes(b)
	if f.is_empty():
		var any: Battler = sides[1 - b.side].slots[0]
		return any
	for o in f:
		if o.slot == b.slot:
			return o
	return f[0]


func nm(b: Battler) -> String:
	if pvp:
		# Jeton résolu par chaque écran selon son point de vue (« adverse » pour l'autre camp).
		return "\u0001%d|%s\u0002" % [b.side, b.mon.name()]
	if b.side == 0:
		return b.mon.name()
	return b.mon.name() + (" sauvage" if wild else " ennemi")


## Talent actif (Gaz Inhibiteur, Suc Digestif et Brise Moule l'annulent).
func ab(b: Battler) -> String:
	if b == null or b.suppressed:
		return ""
	var id := Data.ability_ident(b.ability)
	if id != "neutralizing-gas" and id not in UNCOPYABLE and b.item != "ability-shield":
		for o: Battler in _on_field():
			if o != b and Data.ability_ident(o.ability) == "neutralizing-gas" and not o.suppressed:
				return ""
	return id


## Talent du défenseur, sauf si l'attaquant l'ignore (Brise Moule...).
func dab(u: Battler, t: Battler) -> String:
	var a := ab(t)
	if u != null and u != t and a in BREAKABLE and t.item != "ability-shield":
		var ua := ab(u)
		if ua in ["mold-breaker", "turboblaze", "teravolt", "mycelium-might"]:
			if ua != "mycelium-might" or _cur_move.get("cat", "") == "status":
				return ""
		if _cur_move.get("ident", "") in ["sunsteel-strike", "moongeist-beam", "photon-geyser", "light-that-burns-the-sky"]:
			return ""
	return a


## Objet tenu actif (Sabotage, Embargo, Zone Magique et Maladresse l'annulent).
func it(b: Battler) -> String:
	if b == null or b.item == "" or b.embargo > 0 or magic_room > 0 or ab(b) == "klutz":
		return ""
	return b.item


func has_type(b: Battler, typ: String) -> bool:
	return b.types.has(typ) or b.added_type == typ


func all_types(b: Battler) -> Array:
	var out := b.types.duplicate()
	if b.added_type != "" and not out.has(b.added_type):
		out.append(b.added_type)
	if out.is_empty():
		out = ["normal"] if b.types.is_empty() and b.added_type == "" else out
	return out


func weather_on() -> String:
	for b: Battler in _on_field():
		if ab(b) in ["cloud-nine", "air-lock"]:
			return ""
	return weather


## Météo vue par ce Pokémon (Parapluie Solide ignore pluie et soleil).
func weather_for(b: Battler) -> String:
	var w := weather_on()
	if it(b) == "utility-umbrella" and w in ["rain", "sun", "heavy-rain", "harsh-sun"]:
		return ""
	return w


func is_rain(b: Battler = null) -> bool:
	var w := weather_for(b) if b != null else weather_on()
	return w == "rain" or w == "heavy-rain"


func is_sun(b: Battler = null) -> bool:
	var w := weather_for(b) if b != null else weather_on()
	return w == "sun" or w == "harsh-sun"


func move_data(id: int) -> Dictionary:
	return Data.moves[id] if Data.moves.has(id) else Data.moves[STRUGGLE]


func has_flag(m: Dictionary, f: String) -> bool:
	return m.get("flags", []).has(f)


func hp_event(b: Battler) -> void:
	events.append({"t": "hp", "side": b.side, "slot": b.slot, "hp": b.mon.hp, "max": b.mon.max_hp()})


func anim(b: Battler, kind: String) -> void:
	events.append({"t": "anim", "side": b.side, "slot": b.slot, "kind": kind})


## Animation d'une capacité (l'écran choisit l'effet selon le type et la catégorie).
func move_anim(u: Battler, t: Battler, m: Dictionary) -> void:
	events.append({"t": "move_anim", "side": u.side, "slot": u.slot, "tside": t.side if t != null else 1 - u.side,
		"tslot": t.slot if t != null else 0, "type": _move_type(u, m), "cat": m["cat"], "ident": m["ident"],
		"contact": has_flag(m, "contact"), "flags": m.get("flags", [])})


func refresh() -> void:
	events.append({"t": "refresh"})


## Envoie l'état visible (stats modifiées, météo, champ, pièges) à l'écran.
func field_event() -> void:
	var st := []
	for s in 2:
		var sd := []
		for b in sides[s].slots:
			sd.append(null if b == null else {"stages": b.stages.duplicate(), "conf": b.confusion > 0, "sub": b.substitute > 0,
				"seeded": b.seeded, "taunt": b.taunt, "encore": b.encore_turns, "item": b.item, "mega": b.mega})
		var side: BSide = sides[s]
		st.append({"slots": sd, "reflect": side.reflect, "light_screen": side.light_screen, "aurora_veil": side.aurora_veil,
			"tailwind": side.tailwind, "spikes": side.spikes, "toxic_spikes": side.toxic_spikes,
			"stealth_rock": side.stealth_rock, "sticky_web": side.sticky_web, "safeguard": side.safeguard, "mist": side.mist})
	events.append({"t": "field", "weather": weather, "terrain": terrain, "trick_room": trick_room, "gravity": gravity, "sides": st})


func stage_mult(s: int) -> float:
	return (2.0 + s) / 2.0 if s >= 0 else 2.0 / (2.0 - s)


func acc_mult(s: int) -> float:
	return (3.0 + s) / 3.0 if s >= 0 else 3.0 / (3.0 - s)


## Le Pokémon touche-t-il le sol (Lévitation, Ballon, Vol Magnétik, Gravité, Anti-Air...).
func grounded(b: Battler) -> bool:
	if gravity > 0 or b.grounded or b.ingrain or it(b) == "iron-ball":
		return true
	if has_type(b, "flying") or ab(b) == "levitate" or it(b) == "air-balloon" or b.magnet_rise > 0 or b.telekinesis > 0:
		return false
	return true


func is_grounded_immune(b: Battler) -> bool:
	return not grounded(b)


func trapped(b: Battler) -> bool:
	if has_type(b, "ghost") or it(b) == "shed-shell":
		return false
	for o: Battler in foes(b):
		var a := ab(o)
		if a == "arena-trap" and grounded(b):
			return true
		if a == "shadow-tag" and ab(b) != "shadow-tag":
			return true
		if a == "magnet-pull" and has_type(b, "steel"):
			return true
	return b.trap_turns > 0 or b.mean_look or b.ingrain or b.octolock != null or b.no_retreat or fairy_lock > 0


func battler(side_i: int, slot: int) -> Battler:
	var s: BSide = sides[side_i]
	return s.slots[slot] if slot < s.slots.size() else null


# ---------------------------------------------------------------------------
# Statistiques effectives (étages, talents, objets)
# ---------------------------------------------------------------------------

## Statistique utilisée en combat. i : 1 Atq, 2 Déf, 3 Atq Spé, 4 Déf Spé, 5 Vit.
## stage : étage à appliquer (le calcul des dégâts le règle lui-même pour Inconscient / critiques).
func stat_value(b: Battler, i: int, stage := 999) -> float:
	var idx := i
	if wonder_room > 0 and (i == 2 or i == 4):
		idx = 4 if i == 2 else 2
	var v := float(b.raw(idx))
	var key: String = STAGE_KEYS[i]
	var s: int = b.stages[key] if stage == 999 else stage
	v *= stage_mult(s)
	var a := ab(b)
	var item := it(b)
	var sp := b.mon.species
	match i:
		1:
			if a in ["huge-power", "pure-power"]:
				v *= 2.0
			if a == "hustle" or a == "gorilla-tactics":
				v *= 1.5
			if a == "guts" and b.mon.status != "":
				v *= 1.5
			if a == "slow-start" and b.slow_start > 0:
				v *= 0.5
			if a == "defeatist" and b.hp_frac() <= 0.5:
				v *= 0.5
			if a == "flower-gift" and is_sun(b):
				v *= 1.5
			if a == "orichalcum-pulse" and is_sun(b):
				v *= 4.0 / 3.0
			if item == "choice-band":
				v *= 1.5
			if item == "light-ball" and sp == 25:
				v *= 2.0
			if item == "thick-club" and sp in [104, 105]:
				v *= 2.0
			if b.proto == "atk":
				v *= 1.3
		2:
			if a == "marvel-scale" and b.mon.status != "":
				v *= 1.5
			if a == "fur-coat":
				v *= 2.0
			if a == "grass-pelt" and terrain == "grassy":
				v *= 1.5
			if item == "eviolite" and not b.mon.data()["evos"].is_empty():
				v *= 1.5
			if item == "metal-powder" and sp == 132 and not b.transformed:
				v *= 2.0
			if b.proto == "def":
				v *= 1.3
		3:
			if a == "solar-power" and is_sun(b):
				v *= 1.5
			if a in ["plus", "minus"] and ally(b) != null and ab(ally(b)) in ["plus", "minus"]:
				v *= 1.5
			if a == "defeatist" and b.hp_frac() <= 0.5:
				v *= 0.5
			if a == "hadron-engine" and terrain == "electric":
				v *= 4.0 / 3.0
			if item == "choice-specs":
				v *= 1.5
			if item == "light-ball" and sp == 25:
				v *= 2.0
			if item == "deep-sea-tooth" and sp == 366:
				v *= 2.0
			if b.proto == "spa":
				v *= 1.3
		4:
			if item == "assault-vest":
				v *= 1.5
			if item == "eviolite" and not b.mon.data()["evos"].is_empty():
				v *= 1.5
			if item == "deep-sea-scale" and sp == 366:
				v *= 2.0
			if a == "flower-gift" and is_sun(b):
				v *= 1.5
			if (has_type(b, "rock") and weather_on() == "sandstorm"):
				v *= 1.5
			if b.proto == "spd":
				v *= 1.3
	if i == 2 and has_type(b, "ice") and weather_on() == "snow":
		v *= 1.5
	# Talents « de ruine » : baissent la stat de tous les autres Pokémon.
	for o: Battler in _on_field():
		if o == b:
			continue
		var oa := ab(o)
		if (oa == "tablets-of-ruin" and i == 1) or (oa == "vessel-of-ruin" and i == 3) \
				or (oa == "sword-of-ruin" and i == 2) or (oa == "beads-of-ruin" and i == 4):
			v *= 0.75
	return v


func speed(b: Battler) -> float:
	var v := stat_value(b, 5)
	var a := ab(b)
	var w := weather_for(b)
	if b.mon.status == "par" and a != "quick-feet":
		v *= 0.5
	if sides[b.side].tailwind > 0:
		v *= 2.0
	if (w in ["rain", "heavy-rain"] and a == "swift-swim") or (w in ["sun", "harsh-sun"] and a == "chlorophyll") \
			or (w == "sandstorm" and a == "sand-rush") or (w in ["hail", "snow"] and a == "slush-rush") \
			or (terrain == "electric" and a == "surge-surfer"):
		v *= 2.0
	if a == "unburden" and b.unburden:
		v *= 2.0
	if a == "quick-feet" and b.mon.status != "":
		v *= 1.5
	if a == "slow-start" and b.slow_start > 0:
		v *= 0.5
	if b.proto == "spe":
		v *= 1.5
	var item := it(b)
	if item == "choice-scarf":
		v *= 1.5
	if item in ["iron-ball", "macho-brace", "power-weight", "power-bracer", "power-belt", "power-lens", "power-band", "power-anklet"]:
		v *= 0.5
	if item == "quick-powder" and b.mon.species == 132 and not b.transformed:
		v *= 2.0
	return v


## Poids en hg (Métallo-Peau / Poids Plume / Allègement...).
func weight(b: Battler) -> float:
	var w := float(b.mon.data()["weight"])
	if b.form_id != 0 and Data.pokemon.has(b.form_id):
		w = float(Data.pokemon[b.form_id]["weight"])
	match ab(b):
		"heavy-metal":
			w *= 2.0
		"light-metal":
			w *= 0.5
	if it(b) == "float-stone":
		w *= 0.5
	return maxf(1.0, w)


func usable_slots(side_i: int, slot := 0) -> Array:
	var b := battler(side_i, slot)
	var out := []
	if b == null:
		return out
	for i in b.moves().size():
		if can_use(b, i):
			out.append(i)
	return out


func can_use(b: Battler, slot: int) -> bool:
	var ms := b.moves()
	if slot < 0 or slot >= ms.size():
		return false
	var m: Dictionary = ms[slot]
	var id: int = m["id"]
	var md := move_data(id)
	if m["pp"] <= 0:
		return false
	if b.disable_move == id:
		return false
	if b.encore_turns > 0 and b.encore_move != id:
		return false
	if b.taunt > 0 and md["cat"] == "status":
		return false
	if b.torment and b.last_move == id:
		return false
	if b.heal_block > 0 and has_flag(md, "heal"):
		return false
	if gravity > 0 and has_flag(md, "gravity"):
		return false
	if b.throat_chop > 0 and has_flag(md, "sound"):
		return false
	if it(b) == "assault-vest" and md["cat"] == "status":
		return false
	if b.choice_move != 0 and b.choice_move != id and (it(b).begins_with("choice-") or ab(b) == "gorilla-tactics"):
		var still := false
		for mm in b.moves():
			if mm["id"] == b.choice_move:
				still = true
		if still:
			return false
	if md["ident"] in ["gigaton-hammer", "blood-moon"] and b.last_move == id:
		return false
	if md["ident"] == "belch" and not b.berry_eaten:
		return false
	if md["ident"] == "stuff-cheeks" and not Data.items.get(b.item, {}).get("berry", false):
		return false
	for o: Battler in foes(b):
		if o.imprison:
			for om in o.moves():
				if om["id"] == id:
					return false
	return true


## Capacité imposée (charge, mania, repos après Ultralaser…) : 0 = libre, -1 = doit se reposer.
func locked_move(side_i: int, slot := 0) -> int:
	var b := battler(side_i, slot)
	if b == null:
		return 0
	if b.recharge:
		return -1
	if b.charging:
		return b.charging
	if b.rampage > 0:
		return b.rampage_move
	if b.rollout > 0:
		return b.last_move if b.last_move != 0 else 205
	if b.uproar > 0:
		return 253
	return 0


## Indices (dans side.party) des Pokémon du dresseur `owner` pouvant combattre et pas déjà sur le terrain.
func bench(side_i: int, owner: int) -> Array:
	var s: BSide = sides[side_i]
	var out := []
	for i in s.party.size():
		if s.owners[i] != owner or not s.party[i].can_battle():
			continue
		var on_field := false
		for b in s.slots:
			if b != null and b.party_index == i and b.alive():
				on_field = true
		if not on_field:
			out.append(i)
	return out


func first_alive(side_i: int, owner := -1) -> int:
	var s: BSide = sides[side_i]
	for i in s.party.size():
		if (owner < 0 or s.owners[i] == owner) and s.party[i].can_battle():
			return i
	return -1


func alive_count(side_i: int, owner := -1) -> int:
	var n := 0
	var s: BSide = sides[side_i]
	for i in s.party.size():
		if (owner < 0 or s.owners[i] == owner) and s.party[i].can_battle():
			n += 1
	return n


func owner_name(side_i: int, owner: int) -> String:
	var s: BSide = sides[side_i]
	if owner < s.names.size() and str(s.names[owner]) != "":
		return s.names[owner]
	return trainer.get("name", "Le Dresseur") if side_i == 1 else player_name


# ---------------------------------------------------------------------------
# Entrée en combat et changements
# ---------------------------------------------------------------------------

func start() -> Array:
	var e: BSide = sides[1]
	if wild:
		var names := []
		for k in e.slots.size():
			var idx := _next_for_slot(1, k)
			if idx >= 0:
				_send(1, k, idx, false)
				names.append(e.party[idx].name())
		if names.size() == 2:
			msg("Un %s et un %s sauvages apparaissent !" % names)
		elif names.size() == 1:
			msg("Un %s sauvage apparaît !" % names[0])
		if e.party.size() > 0 and e.party[0].boss:
			msg("%s dégage une aura terrifiante ! C'est un Pokémon BOSS !" % names[0])
	else:
		if pvp:
			msg("Combat classé : %s contre %s !" % [owner_name(0, 0), owner_name(1, 0)])
		elif trainers.size() >= 2:
			msg("%s et %s veulent se battre !" % [trainers[0].get("name", ""), trainers[1].get("name", "")])
		else:
			msg("%s veut se battre !" % trainer.get("name", "Le Dresseur"))
		for k in e.slots.size():
			var idx := _next_for_slot(1, k)
			if idx >= 0:
				_send(1, k, idx)
	for k in sides[0].slots.size():
		var idx := _next_for_slot(0, k)
		if idx >= 0:
			_send(0, k, idx)
	if e.party.size() > 0 and e.party[0].boss:
		for b: Battler in actives(1):
			for key in ["atk", "def", "spa", "spd", "spe"]:
				b.stages[key] = 1
		msg("Les statistiques du boss augmentent !")
	if aura != "":
		_apply_aura()
	_entry_abilities()
	field_event()
	return flush()


## Boss à aura : chaque aura donne un avantage permanent au boss (et, contre un dresseur à aura,
## à chacun de ses Pokémon dès qu'il entre en combat).
var _aura_started := false


func _apply_aura() -> void:
	for b: Battler in actives(1):
		_aura_on(b)
	_aura_started = true


func _aura_on(b: Battler) -> void:
	anim(b, "aura_" + aura)
	match aura:
		"fire":
			msg("Une aura brûlante entoure %s ! Ses attaques sont plus puissantes." % nm(b))
			b.stages["atk"] = mini(6, b.stages["atk"] + 1)
			b.stages["spa"] = mini(6, b.stages["spa"] + 1)
		"steel":
			msg("Une aura d'acier entoure %s ! Il est plus résistant." % nm(b))
			b.stages["def"] = mini(6, b.stages["def"] + 2)
			b.stages["spd"] = mini(6, b.stages["spd"] + 2)
		"electric":
			msg("Une aura électrique entoure %s ! Il est plus rapide." % nm(b))
			b.stages["spe"] = mini(6, b.stages["spe"] + 2)
		"ghost":
			msg("Une aura spectrale entoure %s ! Il est difficile à toucher." % nm(b))
			b.stages["eva"] = mini(6, b.stages["eva"] + 1)
		"dragon":
			msg("Une aura draconique entoure %s ! Toutes ses stats augmentent." % nm(b))
			for k in ["atk", "def", "spa", "spd", "spe"]:
				b.stages[k] = mini(6, b.stages[k] + 1)
		"grass":
			msg("Une aura végétale entoure %s ! Il régénère ses PV." % nm(b))
			b.ingrain = true
			b.aqua_ring = true
		"dark":
			msg("Une aura ténébreuse entoure %s ! Ses coups critiques sont fréquents." % nm(b))
			b.crit_bonus += 2
		"water":
			msg("Une aura aquatique entoure %s ! L'eau le protège et le soigne." % nm(b))
			b.aqua_ring = true
			b.stages["def"] = mini(6, b.stages["def"] + 1)
			b.stages["spd"] = mini(6, b.stages["spd"] + 1)
		"ice":
			msg("Une aura glaciale entoure %s ! Il devient vif et coriace." % nm(b))
			b.stages["spe"] = mini(6, b.stages["spe"] + 1)
			b.stages["def"] = mini(6, b.stages["def"] + 1)
		"psychic":
			msg("Une aura psychique entoure %s ! Ses pouvoirs décuplent." % nm(b))
			b.stages["spa"] = mini(6, b.stages["spa"] + 2)
			b.stages["acc"] = mini(6, b.stages["acc"] + 1)
		"fairy":
			msg("Une aura féerique entoure %s ! Son équipe est protégée des statuts." % nm(b))
			sides[1].safeguard = 999
			b.stages["spd"] = mini(6, b.stages["spd"] + 1)
		"fighting":
			msg("Une aura combative entoure %s ! Sa force explose." % nm(b))
			b.stages["atk"] = mini(6, b.stages["atk"] + 2)
		"rock":
			msg("Une aura minérale entoure %s ! Il devient dur comme la pierre." % nm(b))
			b.stages["def"] = mini(6, b.stages["def"] + 2)
			b.stages["atk"] = mini(6, b.stages["atk"] + 1)
		"ground":
			msg("Une aura tellurique entoure %s ! Le sol tremble sous sa force." % nm(b))
			b.stages["atk"] = mini(6, b.stages["atk"] + 1)
			b.stages["def"] = mini(6, b.stages["def"] + 1)
			b.stages["spd"] = mini(6, b.stages["spd"] + 1)
		"flying":
			msg("Une aura de tempête entoure %s ! Il fend l'air à toute vitesse." % nm(b))
			b.stages["spe"] = mini(6, b.stages["spe"] + 1)
			b.stages["eva"] = mini(6, b.stages["eva"] + 1)
			b.stages["atk"] = mini(6, b.stages["atk"] + 1)


func _next_for_slot(side_i: int, slot: int) -> int:
	var s: BSide = sides[side_i]
	var owner: int = s.slot_owner[slot]
	var b := bench(side_i, owner)
	return b[0] if b.size() > 0 else -1


## Stats d'une forme de combat (Méga, Primo, Forme Lame...) avec les IV/EV/nature du Pokémon.
func _form_stats(mon: Pokemon, pid: int) -> Array:
	if not Data.pokemon.has(pid):
		return mon.stats.duplicate()
	var base: Array = Data.pokemon[pid]["base"]
	var nat: Dictionary = Data.natures[mon.nature]
	var out := [mon.stats[0], 0, 0, 0, 0, 0]
	for i in range(1, 6):
		var v := float(int((2 * base[i] + mon.ivs[i] + int(mon.evs[i] / 4)) * mon.level / 100) + 5)
		if nat["up"] == i:
			v *= 1.1
		elif nat["down"] == i:
			v *= 0.9
		out[i] = int(v)
	return out


## Change la forme d'un Pokémon pendant le combat (et prévient l'écran).
func set_form(b: Battler, pid: int, keep_ability := false) -> void:
	if not Data.pokemon.has(pid):
		return
	b.form_id = pid if pid != b.mon.sprite_id() else 0
	b.f_stats = _form_stats(b.mon, pid) if b.form_id != 0 else []
	b.types = Data.pokemon[pid]["types"].duplicate()
	if not keep_ability:
		var abl: Array = Data.pokemon[pid]["abilities"]
		if abl.size() > 0:
			b.ability = abl[0]
	events.append({"t": "form", "side": b.side, "slot": b.slot, "sprite": b.sprite_id(), "shiny": b.mon.shiny})


## Forme liée à un nom (« aegislash-blade ») : identifiant Pokémon, 0 si absente.
func form_pid(species: int, form: String) -> int:
	for f in Data.pokemon[species].get("forms", []):
		if Data.pokemon[f].get("form", "") == form:
			return f
	return 0


## Méga-Gemme correspondant au Pokémon (ou Draco Ascension pour Rayquaza) : forme Méga, sinon 0.
func mega_target(b: Battler) -> int:
	if b.mega or b.transformed:
		return 0
	if b.mon.species == 384:
		for mv in b.moves():
			if move_data(mv["id"])["ident"] == "dragon-ascent":
				return form_pid(384, "mega")
		return 0
	var stones: Dictionary = Data.mega_stones
	if stones.has(b.item):
		var pid: int = stones[b.item]
		if Data.pokemon[pid]["species"] == b.mon.species:
			return pid
	return 0


func can_mega_evolve(b: Battler) -> bool:
	if b.side == 0 and b.owner < mega_owners.size() and not mega_owners[b.owner]:
		return false
	return can_mega[b.side] and not sides[b.side].mega_used.get(b.owner, false) and mega_target(b) != 0


func mega_evolve(b: Battler) -> void:
	var pid := mega_target(b)
	if pid == 0:
		return
	sides[b.side].mega_used[b.owner] = true
	msg("%s réagit à la Méga-Gemme de %s !" % [Data.item_name(b.item) if b.item != "" else "L'énergie", nm(b)])
	anim(b, "mega")
	b.mega = true
	set_form(b, pid)
	msg("%s méga-évolue en %s !" % [nm(b), Data.pokemon[pid].get("form_name", Data.pokemon[pid]["name"])])
	_entry_ability(b)
	field_event()


func _send(side_i: int, slot: int, idx: int, announce := true, keep_stages := false) -> void:
	var side: BSide = sides[side_i]
	var old: Battler = side.slots[slot]
	var b := Battler.new()
	b.mon = side.party[idx]
	b.side = side_i
	b.slot = slot
	b.owner = side.owners[idx]
	b.party_index = idx
	b.types = b.mon.types().duplicate()
	b.ability = b.mon.ability
	b.item = b.mon.held_item
	if Data.ability_ident(b.ability) == "slow-start":
		b.slow_start = 5
	if keep_stages and old != null:
		b.stages = old.stages.duplicate()
		b.confusion = old.confusion
		b.substitute = old.substitute
		b.seeded = old.seeded
		b.seeded_by = old.seeded_by
		b.focus_energy = old.focus_energy
		b.crit_bonus = old.crit_bonus
		b.cursed = old.cursed
		b.perish = old.perish
		b.ingrain = old.ingrain
		b.aqua_ring = old.aqua_ring
		b.magnet_rise = old.magnet_rise
		b.power_trick = old.power_trick
		b.heal_block = old.heal_block
		b.embargo = old.embargo
	side.slots[slot] = b
	if side_i == 0:
		for e: Battler in actives(1):
			_add_participant(e.party_index, idx)
	else:
		participants[idx] = []
		for p: Battler in actives(0):
			_add_participant(idx, p.party_index)
	if announce:
		if pvp:
			msg("%s envoie %s !" % [owner_name(side_i, b.owner), b.mon.name()])
		elif side_i == 0:
			msg("Go ! %s !" % b.mon.name() if b.owner == 0 or sides[0].names.size() < 2 else "%s envoie %s !" % [owner_name(0, b.owner), b.mon.name()])
		else:
			msg("%s envoie %s !" % [owner_name(1, b.owner), b.mon.name()])
	events.append({"t": "send", "side": side_i, "slot": slot, "mon": b.mon, "index": idx, "owner": b.owner})
	# Formes à l'entrée (Primo-Résurgence, Zacian Roi du Combat, Giratina Originel...).
	_entry_form(b)
	if side_i == 1 and aura != "" and _aura_started:
		_aura_on(b)
	if side.healing_wish:
		side.healing_wish = false
		if b.mon.hp < b.mon.max_hp() or b.mon.status != "":
			b.mon.hp = b.mon.max_hp()
			b.mon.status = ""
			msg("Le Vœu Soin rétablit %s !" % nm(b))
			hp_event(b)
			refresh()
	_entry_hazards(b)


func _entry_form(b: Battler) -> void:
	var sp := b.mon.species
	var item := b.item
	if (sp == 382 and item == "blue-orb") or (sp == 383 and item == "red-orb"):
		msg("Primo-Résurgence de %s ! Il retrouve sa forme originelle !" % nm(b))
		set_form(b, form_pid(sp, "primal"))
		anim(b, "mega")
	elif sp == 888 and item == "rusted-sword":
		set_form(b, form_pid(888, "crowned"), true)
		msg("%s brandit l'Épée Rouillée !" % nm(b))
	elif sp == 889 and item == "rusted-shield":
		set_form(b, form_pid(889, "crowned"), true)
		msg("%s brandit le Bouclier Rouillé !" % nm(b))
	elif sp == 487 and item in ["griseous-orb", "griseous-core"]:
		set_form(b, form_pid(487, "origin"), true)
	elif sp == 483 and item == "adamant-crystal":
		set_form(b, form_pid(483, "origin"), true)
	elif sp == 484 and item == "lustrous-globe":
		set_form(b, form_pid(484, "origin"), true)
	elif sp == 493 and item in PLATES:
		b.types = [TYPE_ITEMS[item]]
	elif sp == 773 and MEMORIES.has(item):
		b.types = [MEMORIES[item]]


## Picots, Piège de Roc, Pics Toxik, Toile Gluante.
func _entry_hazards(b: Battler) -> void:
	var side: BSide = sides[b.side]
	if it(b) == "heavy-duty-boots" or not b.alive():
		return
	var magic := ab(b) == "magic-guard"
	if side.spikes > 0 and grounded(b) and not magic:
		var frac: int = [8, 6, 4][side.spikes - 1]
		msg("%s est blessé par les picots !" % nm(b))
		_hurt(b, maxi(1, b.mon.max_hp() / frac))
	if side.stealth_rock and b.alive() and not magic:
		var eff := Data.effectiveness("rock", all_types(b))
		msg("Des pierres pointues s'enfoncent dans %s !" % nm(b))
		_hurt(b, maxi(1, int(b.mon.max_hp() * eff / 8.0)))
	if side.toxic_spikes > 0 and b.alive() and grounded(b):
		if has_type(b, "poison"):
			side.toxic_spikes = 0
			msg("Les Pics Toxik disparaissent !")
		elif not has_type(b, "steel"):
			_set_status(b, "tox" if side.toxic_spikes >= 2 else "psn", null, false)
	if side.sticky_web and b.alive() and grounded(b):
		msg("%s est pris dans une toile gluante !" % nm(b))
		_stage(b, "spe", -1, null)


func _add_participant(enemy_idx: int, player_idx: int) -> void:
	if not participants.has(enemy_idx):
		participants[enemy_idx] = []
	if not participants[enemy_idx].has(player_idx):
		participants[enemy_idx].append(player_idx)


func _entry_abilities() -> void:
	for b: Battler in actives():
		_entry_ability(b)
	for b: Battler in actives():
		_entry_item(b)


## Objets qui s'activent à l'entrée.
func _entry_item(b: Battler) -> void:
	if b == null or not b.alive():
		return
	match it(b):
		"air-balloon":
			msg("%s flotte grâce à son Ballon !" % nm(b))
		"room-service":
			if trick_room > 0:
				_consume(b)
				msg("%s utilise son Service Chambre !" % nm(b))
				_stage(b, "spe", -1, b)
		"booster-energy":
			if ab(b) in ["protosynthesis", "quark-drive"] and b.proto == "":
				_consume(b)
				_activate_proto(b, true)
	if TERRAIN_SEEDS.has(terrain) and it(b) == TERRAIN_SEEDS[terrain]:
		_consume(b)
		msg("%s utilise sa %s !" % [nm(b), Data.item_name(TERRAIN_SEEDS[terrain])])
		_stage(b, "spd" if terrain in ["misty", "psychic"] else "def", 1, b)


## Paléosynthèse / Charge Quantique : la meilleure stat augmente (soleil, Champ Électrifié ou Énergie Booster).
func _activate_proto(b: Battler, booster: bool) -> void:
	var best := "atk"
	var bv := -1.0
	for k in ["atk", "def", "spa", "spd", "spe"]:
		var v := float(b.raw(STAT_INDEX[k]))
		if v > bv:
			bv = v
			best = k
	b.proto = best
	msg("%s de %s s'active%s ! %s augmente !" % [Data.ability_name(b.ability), nm(b), " grâce à l'Énergie Booster" if booster else "", STAT_LABEL[best]])


func _set_weather(w: String, src: Battler, turns := 5) -> bool:
	if weather == w or (weather in ["heavy-rain", "harsh-sun", "strong-winds"] and w not in ["heavy-rain", "harsh-sun", "strong-winds"]):
		return false
	weather = w
	weather_turns = turns
	if src != null and WEATHER_ROCKS.has(w) and it(src) == WEATHER_ROCKS[w]:
		weather_turns = 8
	if w in ["heavy-rain", "harsh-sun", "strong-winds"]:
		weather_turns = 9999
	msg({"rain": "Il commence à pleuvoir !", "sun": "Le soleil brille fort !", "sandstorm": "Une tempête de sable se lève !",
		"hail": "Il commence à grêler !", "snow": "Il commence à neiger !", "heavy-rain": "Une pluie battante s'abat !",
		"harsh-sun": "Le soleil devient brûlant !", "strong-winds": "Un vent mystérieux protège les Pokémon Vol !"}[w])
	events.append({"t": "weather", "w": w})
	for b: Battler in _on_field():
		_weather_reactions(b)
	field_event()
	return true


## Réactions à la météo : Météo (Morphéo), Paléosynthèse...
func _weather_reactions(b: Battler) -> void:
	if b.mon.species == 351 and ab(b) == "forecast":
		var form := "sunny" if is_sun(b) else "rainy" if is_rain(b) else "snowy" if weather_on() in ["hail", "snow"] else ""
		var pid := form_pid(351, form) if form != "" else 351
		if pid != 0 and pid != b.sprite_id():
			set_form(b, pid, true)
	if ab(b) == "protosynthesis" and b.proto == "" and is_sun(b):
		_activate_proto(b, false)


func _set_terrain(t: String, src: Battler) -> bool:
	if terrain == t:
		return false
	terrain = t
	terrain_turns = 8 if src != null and it(src) == "terrain-extender" else 5
	msg({"electric": "De l'électricité parcourt le terrain !", "grassy": "De l'herbe recouvre le terrain !",
		"misty": "La brume recouvre le terrain !", "psychic": "Le sol devient bizarre !"}[t])
	events.append({"t": "terrain", "terrain": t})
	for b: Battler in _on_field():
		if TERRAIN_SEEDS.has(t) and it(b) == TERRAIN_SEEDS[t]:
			_consume(b)
			msg("%s utilise sa %s !" % [nm(b), Data.item_name(TERRAIN_SEEDS[t])])
			_stage(b, "spd" if t in ["misty", "psychic"] else "def", 1, b)
		if ab(b) == "quark-drive" and b.proto == "" and t == "electric":
			_activate_proto(b, false)
		if ab(b) == "mimicry":
			b.types = [{"electric": "electric", "grassy": "grass", "misty": "fairy", "psychic": "psychic"}[t]]
			msg("%s change de type !" % nm(b))
	field_event()
	return true


func _entry_ability(b: Battler) -> void:
	if b == null or not b.alive():
		return
	var o := foe(b)
	match ab(b):
		"intimidate":
			msg("Intimidation de %s !" % nm(b))
			for f: Battler in foes(b):
				_intimidated(f, b)
		"drizzle":
			_set_weather("rain", b)
		"drought":
			_set_weather("sun", b)
		"sand-stream":
			_set_weather("sandstorm", b)
		"snow-warning":
			_set_weather("snow", b)
		"primordial-sea":
			_set_weather("heavy-rain", b)
		"desolate-land":
			_set_weather("harsh-sun", b)
		"delta-stream":
			_set_weather("strong-winds", b)
		"orichalcum-pulse":
			_set_weather("sun", b)
		"electric-surge", "hadron-engine":
			_set_terrain("electric", b)
		"psychic-surge":
			_set_terrain("psychic", b)
		"misty-surge":
			_set_terrain("misty", b)
		"grassy-surge":
			_set_terrain("grassy", b)
		"trace":
			if o != null and o.ability != 0 and Data.ability_ident(o.ability) not in UNCOPYABLE:
				b.ability = o.ability
				msg("%s copie le talent %s !" % [nm(b), Data.ability_name(o.ability)])
				_entry_ability(b)
		"download":
			if o != null:
				var stat := "atk" if stat_value(o, 2) < stat_value(o, 4) else "spa"
				msg("Télécharge de %s s'active !" % nm(b))
				_stage(b, stat, 1, b)
		"forewarn":
			if o != null:
				var best := 0
				for m in o.moves():
					if best == 0 or move_data(m["id"])["power"] > move_data(best)["power"]:
						best = m["id"]
				if best:
					msg("Anticipation : %s détecte %s !" % [nm(b), Data.move_name(best)])
		"anticipation":
			for f: Battler in foes(b):
				for m in f.moves():
					var md := move_data(m["id"])
					if md["cat"] != "status" and Data.effectiveness(md["type"], all_types(b)) > 1.0 or md["ident"] in OHKO:
						msg("%s frissonne !" % nm(b))
						return
		"frisk":
			for f: Battler in foes(b):
				if f.item != "":
					msg("Fouille : %s tient %s." % [nm(f), Data.item_name(f.item)])
		"pressure":
			msg("%s exerce sa Pression !" % nm(b))
		"mold-breaker":
			msg("%s brise le moule !" % nm(b))
		"turboblaze":
			msg("%s dégage une aura flamboyante !" % nm(b))
		"teravolt":
			msg("%s dégage une aura électrique !" % nm(b))
		"neutralizing-gas":
			msg("Un gaz inhibiteur se répand !")
		"unnerve", "as-one-glastrier", "as-one-spectrier":
			msg("L'équipe adverse est trop tendue pour manger des Baies !")
		"air-lock", "cloud-nine":
			msg("Les effets de la météo disparaissent.")
		"dark-aura":
			msg("%s dégage une aura ténébreuse !" % nm(b))
		"fairy-aura":
			msg("%s dégage une aura féerique !" % nm(b))
		"aura-break":
			msg("%s inverse les auras !" % nm(b))
		"imposter":
			if o != null and not o.transformed and o.substitute == 0:
				_transform(b, o)
		"intrepid-sword":
			if not b.mon.counters.get("intrepid", false):
				_stage(b, "atk", 1, b)
		"dauntless-shield":
			if not b.mon.counters.get("dauntless", false):
				_stage(b, "def", 1, b)
		"screen-cleaner":
			for s: BSide in sides:
				s.reflect = 0
				s.light_screen = 0
				s.aurora_veil = 0
			msg("Les protections disparaissent !")
		"curious-medicine":
			var al := ally(b)
			if al != null:
				for k in al.stages:
					al.stages[k] = 0
		"costar":
			var al2 := ally(b)
			if al2 != null:
				b.stages = al2.stages.duplicate()
				msg("%s copie les changements de stats de %s !" % [nm(b), nm(al2)])
		"supersweet-syrup":
			if not b.mon.counters.get("syrup", false):
				b.mon.counters["syrup"] = true
				msg("Un parfum sucré se répand !")
				for f: Battler in foes(b):
					_stage(f, "eva", -1, b)
		"hospitality":
			var al3 := ally(b)
			if al3 != null and al3.mon.hp < al3.mon.max_hp():
				msg("%s sert du thé à %s !" % [nm(b), nm(al3)])
				_heal(al3, al3.mon.max_hp() / 4)
		"slow-start":
			msg("%s a du mal à démarrer !" % nm(b))
		"protosynthesis":
			if is_sun(b):
				_activate_proto(b, false)
		"quark-drive":
			if terrain == "electric":
				_activate_proto(b, false)
		"vessel-of-ruin", "sword-of-ruin", "tablets-of-ruin", "beads-of-ruin":
			msg("%s de %s affaiblit les autres Pokémon !" % [Data.ability_name(b.ability), nm(b)])
		"comatose":
			msg("%s est dans un état second !" % nm(b))
		"mimicry":
			if terrain != "":
				b.types = [{"electric": "electric", "grassy": "grass", "misty": "fairy", "psychic": "psychic"}[terrain]]
		"forecast":
			_weather_reactions(b)
		"zero-to-hero":
			if b.mon.species == 964 and b.mon.counters.get("hero", false):
				set_form(b, form_pid(964, "hero"), true)
				msg("%s est devenu un héros !" % nm(b))
		"schooling":
			_check_forms(b)
	_weather_reactions(b)


## Intimidation sur un adversaire (Attention, Benêt, Tempo Perso, Querelleur, Garde Chien...).
func _intimidated(f: Battler, src: Battler) -> void:
	var a := ab(f)
	if f.substitute > 0:
		return
	if a in ["inner-focus", "oblivious", "own-tempo", "scrappy"]:
		msg("%s de %s le protège !" % [Data.ability_name(f.ability), nm(f)])
	elif a == "guard-dog":
		_stage(f, "atk", 1, f)
	else:
		_stage(f, "atk", -1, src)
	if a == "rattled":
		_stage(f, "spe", 1, f)
	if it(f) == "adrenaline-orb":
		_consume(f)
		_stage(f, "spe", 1, f)


## Formes qui changent pendant le combat (Banc, Mode Transe, Bouclier-Carcan...).
func _check_forms(b: Battler) -> void:
	if not b.alive():
		return
	var sp := b.mon.species
	match ab(b):
		"schooling":
			if sp == 746 and b.mon.level >= 20:
				var school := b.hp_frac() > 0.25
				var pid := form_pid(746, "school") if school else 746
				if pid != 0 and pid != b.sprite_id():
					set_form(b, pid, true)
					msg("%s forme un banc !" % nm(b) if school else "Le banc de %s se disperse..." % nm(b))
		"zen-mode":
			if sp == 555 and b.hp_frac() <= 0.5:
				var zen := form_pid(555, "zen") if b.mon.form == 0 else form_pid(555, "galar-zen")
				if zen != 0 and b.form_id != zen:
					set_form(b, zen, true)
					msg("%s entre en Mode Transe !" % nm(b))
		"shields-down":
			if sp == 774:
				var core := b.hp_frac() <= 0.5
				if core and b.form_id == 0:
					var pid2 := form_pid(774, "red")
					if pid2 != 0:
						set_form(b, pid2, true)
						msg("Le bouclier de %s se brise !" % nm(b))
		"power-construct":
			if sp == 718 and b.hp_frac() <= 0.5 and b.form_id == 0:
				var pid3 := form_pid(718, "complete")
				if pid3 != 0:
					var old_max := b.mon.max_hp()
					set_form(b, pid3, true)
					msg("%s prend sa Forme Parfaite !" % nm(b))
					b.mon.hp += maxi(0, b.mon.max_hp() - old_max)


func _switch_out(b: Battler) -> void:
	var a := ab(b)
	if a == "natural-cure" and b.mon.status != "":
		b.mon.status = ""
	if a == "regenerator" and b.mon.hp > 0:
		b.mon.hp = mini(b.mon.max_hp(), b.mon.hp + b.mon.max_hp() / 3)
	if a == "zero-to-hero" and b.mon.species == 964:
		b.mon.counters["hero"] = true
	b.mon.held_item = b.item
	for o: Battler in _on_field():
		if o.mean_look:
			o.mean_look = false
		if o.attract_by == b:
			o.attract = false
		if o.trap_by == b:
			o.trap_turns = 0
		if o.octolock == b:
			o.octolock = null
		if o.seeded_by == b:
			pass
	events.append({"t": "form", "side": b.side, "slot": b.slot, "sprite": b.mon.sprite_id(), "shiny": b.mon.shiny, "reset": true})


## Remplace le Pokémon de l'emplacement `slot` du joueur par party[idx].
func player_switch(slot: int, idx: int = -999) -> Array:
	if idx == -999:
		idx = slot
		slot = need_switch[0]["slot"] if need_switch.size() > 0 else 0
	var bp := false
	for n in need_switch.duplicate():
		if n["slot"] == slot:
			bp = n.get("baton", false)
			need_switch.erase(n)
	var b: Battler = sides[0].slots[slot]
	if b != null and b.alive() and not bp:
		_switch_out(b)
	if b != null and b.alive():
		events.append({"t": "recall", "side": 0, "slot": slot})
	_send(0, slot, idx, true, bp)
	if bp and b != null and b.mon.counters.get("shed_tail", 0) > 0:
		sides[0].slots[slot].substitute = b.mon.counters["shed_tail"]
		b.mon.counters.erase("shed_tail")
		events.append({"t": "sub", "side": 0, "slot": slot, "on": true})
	_entry_ability(sides[0].slots[slot])
	_entry_item(sides[0].slots[slot])
	for n in need_switch.duplicate():
		if bench(0, n["owner"]).is_empty():
			need_switch.erase(n)
			var eb: Battler = sides[0].slots[n["slot"]]
			if eb != null and not eb.alive():
				eb.empty = true
	_check_end()
	field_event()
	return flush()


## Fin du combat : l'objet tenu suit le Pokémon (consommé = perdu ; Sabotage = rendu, comme dans les jeux).
func _finish_items() -> void:
	for s: BSide in sides:
		for b: Battler in s.slots:
			if b != null:
				b.mon.held_item = b.item
	for s: BSide in sides:
		for m: Pokemon in s.party:
			if m.counters.has("knocked"):
				if m.held_item == "":
					m.held_item = m.counters["knocked"]
				m.counters.erase("knocked")
			m.counters.erase("crits_battle")
			m.counters.erase("metronome_n")


# ---------------------------------------------------------------------------
# Tour de combat
# ---------------------------------------------------------------------------

## actions : {emplacement_joueur: action}. Une action seule est acceptée pour le combat simple.
## Action de capacité : {"type": "move", "slot", "target_side", "target_slot", "mega": bool, "z": bool}.
func play_turn(player_actions: Dictionary, foe_actions := {}) -> Array:
	if player_actions.has("type"):
		player_actions = {0: player_actions}
	turn += 1
	for s: BSide in sides:
		s.wide_guard = false
		s.quick_guard = false
		s.mat_block = false
		s.crafty_shield = false
	for b: Battler in actives():
		b.flinch = false
		b.protected = false
		b.protect_kind = ""
		b.endure = false
		b.moved = false
		b.hit_phys = 0
		b.hit_spec = 0
		b.hit_by_foe = false
		b.raised_turn = false
		b.lowered_turn = false
		b.helping = false
		b.center = false
		b.magic_coat = false
		b.snatch = false
		b.electrify = false
		b.powder = false
		b.quick = false
		b.custap = false
		b.damaged_turn = false
		b.focus_punch = false
		b.beak_blast = false
		b.shell_trap = false
		b.glaive = false
	ion_deluge = false
	actions = {}
	for k in player_actions:
		var b := battler(0, int(k))
		if b != null and b.alive():
			actions[b] = player_actions[k]
	for b: Battler in actives(1):
		if pvp:
			var fa: Dictionary = foe_actions.get(b.slot, foe_actions.get(str(b.slot), {}))
			actions[b] = fa if fa.get("type", "") in ["move", "switch", "run"] else _pvp_default(b)
		else:
			actions[b] = _ai_action(b)
	# PvP : abandon d'un des deux joueurs.
	if pvp:
		for b: Battler in actions:
			if actions[b].get("type", "") == "run":
				_forfeit(b.side)
				return flush()

	# Actions prioritaires : fuite, Balls, objets, changements.
	for b: Battler in actives(0):
		var a: Dictionary = actions.get(b, {})
		match a.get("type", ""):
			"run":
				_try_run()
			"ball":
				_throw_ball(a["item"], a.get("target", -1))
			"item":
				_use_item(b, a["item"], a.get("target", b.party_index), a.get("move", -1))
			"switch":
				_do_switch(b, a["index"])
		if over:
			return flush()
	for b: Battler in actives(1):
		var a2: Dictionary = actions.get(b, {})
		if a2.get("type", "") == "item":
			_ai_use_potion(b)
		elif a2.get("type", "") == "switch":
			_do_switch(b, a2["index"])

	# Méga-Évolutions (avant toutes les capacités, la vitesse de la nouvelle forme compte).
	for b: Battler in actions:
		if is_instance_valid(b) and b.alive() and actions[b].get("type", "") == "move" and actions[b].get("mega", false) and can_mega_evolve(b):
			mega_evolve(b)

	# Capacités : priorité, Vive Griffe / Baie Chérim, puis vitesse (inversée sous Distorsion).
	var movers := []
	for b: Battler in actions:
		if actions[b].get("type", "") == "move" and is_instance_valid(b) and sides[b.side].slots[b.slot] == b:
			movers.append(b)
			_pre_move(b)
	movers.shuffle()
	movers.sort_custom(func(a, c): return _goes_before(a, c))
	_order = movers
	for b: Battler in movers:
		if over:
			break
		if not b.alive() or sides[b.side].slots[b.slot] != b:
			continue
		_do_move(b, actions[b])
		b.moved = true
		_after_move_items(b)
		_check_end()
		if over:
			break
	if not over:
		_end_of_turn()
		_check_end()
	if not over and turn_limit > 0 and turn >= turn_limit:
		over = true
		result = "draw"
		_finish_items()
		msg("Le combat dure depuis %d tours : match nul !" % turn)
		events.append({"t": "end", "result": "draw"})
	field_event()
	return flush()


## PvP : action par défaut si l'autre joueur n'a rien envoyé (1re capacité utilisable, sinon Lutte).
func _pvp_default(b: Battler) -> Dictionary:
	var usable := usable_slots(1, b.slot)
	if locked_move(1, b.slot) != 0:
		return {"type": "move", "slot": -1}
	if usable.is_empty():
		return {"type": "move", "id": STRUGGLE}
	return {"type": "move", "slot": usable[0], "target_side": 0, "target_slot": 0}


## PvP : un joueur abandonne.
func forfeit(side_i: int) -> void:
	if not over:
		_forfeit(side_i)


func _forfeit(side_i: int) -> void:
	over = true
	result = "lose" if side_i == 0 else "win"
	_finish_items()
	msg("%s abandonne le combat !" % owner_name(side_i, 0))
	events.append({"t": "end", "result": result})


## PvP : l'autre joueur choisit le Pokémon qui remplace celui mis K.O.
func foe_switch(slot: int, idx: int) -> Array:
	for n in foe_need_switch.duplicate():
		if n["slot"] == slot:
			foe_need_switch.erase(n)
	if not bench(1, sides[1].slot_owner[slot]).has(idx):
		var bl := bench(1, sides[1].slot_owner[slot])
		if bl.is_empty():
			return flush()
		idx = bl[0]
	_send(1, slot, idx)
	_entry_ability(sides[1].slots[slot])
	_entry_item(sides[1].slots[slot])
	_check_end()
	field_event()
	return flush()


## Préparatifs avant l'ordre d'action : Mitra-Poing, Bec-Canon, Carapiège, Vive Griffe, Baie Chérim.
func _pre_move(b: Battler) -> void:
	var id := _action_move_id(b)
	var ident: String = move_data(id)["ident"]
	match ident:
		"focus-punch":
			b.focus_punch = true
			msg("%s se concentre !" % nm(b))
		"beak-blast":
			b.beak_blast = true
			msg("%s fait chauffer son bec !" % nm(b))
		"shell-trap":
			b.shell_trap = true
			msg("%s pose un piège de carapace !" % nm(b))
	if _priority(b) <= 0:
		if it(b) == "quick-claw" and randi() % 5 == 0:
			b.quick = true
			msg("La Vive Griffe de %s lui permet d'agir en premier !" % nm(b))
		elif it(b) == "custap-berry" and b.hp_frac() <= (0.5 if ab(b) == "gluttony" else 0.25) and _can_eat(b):
			b.custap = true
			msg("%s mange sa Baie Chérim et agit en premier !" % nm(b))
			_consume(b, true)
		elif ab(b) == "quick-draw" and move_data(id)["cat"] != "status" and randi() % 10 < 3:
			b.quick = true
			msg("Tir Vif de %s : il agit en premier !" % nm(b))


func _goes_before(a: Battler, c: Battler) -> bool:
	var pa := _priority(a)
	var pc := _priority(c)
	if pa != pc:
		return pa > pc
	var qa := a.quick or a.custap
	var qc := c.quick or c.custap
	if qa != qc:
		return qa
	var la := it(a) in ["lagging-tail", "full-incense"] or ab(a) == "stall"
	var lc := it(c) in ["lagging-tail", "full-incense"] or ab(c) == "stall"
	if la != lc:
		return lc
	var sa := speed(a)
	var sc := speed(c)
	if trick_room > 0:
		return sa < sc
	return sa > sc


func _do_switch(b: Battler, idx: int) -> void:
	if pvp:
		msg("%s rappelle %s !" % [owner_name(b.side, b.owner), b.mon.name()])
	elif b.side == 0:
		msg("%s, reviens !" % b.mon.name())
	else:
		msg("%s rappelle %s !" % [owner_name(1, b.owner), b.mon.name()])
	# Poursuite frappe double un Pokémon qui s'enfuit.
	for o: Battler in foes(b):
		var oa: Dictionary = actions.get(o, {})
		if oa.get("type", "") == "move" and not o.moved and move_data(_action_move_id(o))["ident"] == "pursuit":
			msg("%s poursuit %s !" % [nm(o), nm(b)])
			var pm := move_data(_action_move_id(o)).duplicate()
			pm["power"] = 80
			_damage_move(o, b, pm)
			o.moved = true
			if not b.alive():
				return
	events.append({"t": "recall", "side": b.side, "slot": b.slot})
	_switch_out(b)
	_send(b.side, b.slot, idx)
	_entry_ability(sides[b.side].slots[b.slot])
	_entry_item(sides[b.side].slots[b.slot])


func _action_move_id(b: Battler) -> int:
	var a: Dictionary = actions.get(b, {})
	if a.has("id"):
		return a["id"]
	var lock := locked_move(b.side, b.slot)
	if lock > 0:
		return lock
	var slot: int = a.get("slot", -1)
	if b.encore_turns > 0:
		for i in b.moves().size():
			if b.moves()[i]["id"] == b.encore_move:
				slot = i
	if slot < 0 or slot >= b.moves().size():
		return STRUGGLE
	return b.moves()[slot]["id"]


func _priority(b: Battler) -> int:
	if locked_move(b.side, b.slot) == -1:
		return 0
	var m := move_data(_action_move_id(b))
	var p: int = m["prio"]
	var a := ab(b)
	if a == "prankster" and m["cat"] == "status":
		p += 1
	if a == "gale-wings" and m["type"] == "flying" and b.mon.hp == b.mon.max_hp():
		p += 1
	if a == "triage" and (has_flag(m, "heal") or m.get("drain", 0) > 0):
		p += 3
	if m["ident"] == "grassy-glide" and terrain == "grassy" and grounded(b):
		p += 1
	return p


## Cible choisie (ou par défaut), avec repli si elle est K.O.
func _chosen_target(u: Battler, a: Dictionary) -> Battler:
	if a.has("target_side"):
		var t := battler(a["target_side"], a.get("target_slot", 0))
		if t != null and t.alive():
			return t
		if a["target_side"] == u.side:
			var al := ally(u)
			if al != null:
				return al
	var f := foes(u)
	if f.is_empty():
		return null
	# Par Ici / Poudre Fureur attirent les attaques.
	for o: Battler in f:
		if o.center:
			return o
	if a.has("target_slot") and not a.has("target_side"):
		for o in f:
			if o.slot == a["target_slot"]:
				return o
	return f[randi() % f.size()] if f.size() > 1 and not a.has("target_slot") else f[0]


func _do_move(u: Battler, action: Dictionary) -> void:
	u.last_failed = false
	if u.recharge:
		u.recharge = false
		msg("%s doit se reposer !" % nm(u))
		return
	if ab(u) == "truant":
		u.truant_off = not u.truant_off
		if not u.truant_off:
			msg("%s paresse !" % nm(u))
			return
	var lock := locked_move(u.side, u.slot)
	var id := _action_move_id(u)
	var continuing := lock > 0
	var t: Battler = null
	if continuing and not u.charge_target.is_empty():
		t = _chosen_target(u, u.charge_target)
	else:
		t = _chosen_target(u, action)
	var slot := -1
	for i in u.moves().size():
		if u.moves()[i]["id"] == id:
			slot = i
	if not continuing and id != STRUGGLE and (slot < 0 or u.moves()[slot]["pp"] <= 0):
		id = STRUGGLE
		slot = -1
	if not _can_act(u, id):
		u.charging = 0
		if u.invuln != "":
			u.invuln = ""
			events.append({"t": "hide", "side": u.side, "slot": u.slot, "on": false})
		u.rampage = 0
		u.rollout = 0
		u.uproar = 0
		u.fury_cutter = 0
		u.last_failed = true
		return
	if not continuing and id != STRUGGLE:
		if not can_use(u, slot):
			msg("%s ne peut pas utiliser %s !" % [nm(u), Data.move_name(id)])
			u.last_failed = true
			return
		var cost := 1
		for f: Battler in foes(u):
			if ab(f) == "pressure":
				cost += 1
		u.moves()[slot]["pp"] = maxi(0, u.moves()[slot]["pp"] - cost)
		u.charge_target = action.duplicate()
		if it(u).begins_with("choice-") or ab(u) == "gorilla-tactics":
			u.choice_move = id
	if id == STRUGGLE and not continuing:
		msg("%s n'a plus de capacité utilisable !" % nm(u))
	var m := move_data(id)
	# Capacité Z : une fois par combat, avec le Cristal Z du bon type.
	if action.get("z", false) and not continuing and can_z_move(u, id):
		m = z_move(u, m)
		sides[u.side].z_used[u.owner] = true
		msg("%s libère toute sa puissance Z !" % nm(u))
		anim(u, "zmove")
	msg("%s utilise %s !" % [nm(u), m["name"]])
	_cur_move = m
	if m["ident"] not in ["mirror-move", "copycat"]:
		_last_move_used = id
	u.mon.count("move_%d" % id)
	if m["ident"] == "rage-fist":
		pass
	if id != 118 and id != 119:
		u.last_move = id
	if m["ident"] != "rage":
		u.rage = false
	if m["ident"] != "fury-cutter":
		u.fury_cutter = 0
	if m["ident"] != "echoed-voice":
		u.echo = 0
	if m["ident"] not in ["protect", "detect", "endure", "kings-shield", "spiky-shield", "baneful-bunker", "obstruct",
			"silk-trap", "burning-bulwark", "wide-guard", "quick-guard"]:
		u.protect_chain = 0
	# Danseuse : un autre Pokémon copie les danses.
	var dancers := []
	if has_flag(m, "dance"):
		for o: Battler in _on_field():
			if o != u and ab(o) == "dancer":
				dancers.append(o)
	# Capacités qui touchent plusieurs Pokémon.
	if m["target"] in SPREAD_TARGETS and not TWO_TURN.has(m["ident"]):
		var targets := foes(u) if m["target"] == "all-opponents" else actives().filter(func(x): return x != u)
		if targets.is_empty():
			_fail()
			u.last_failed = true
		else:
			_spread = targets.size() > 1
			for t2: Battler in targets:
				if t2.alive() and u.alive():
					_execute(u, t2, m)
			_spread = false
	else:
		if t == null and _targets_foe(m):
			_fail()
			u.last_failed = true
		else:
			_execute(u, t if t != null else foe(u), m)
	if u.alive() and u.rampage > 0 and m["ident"] in RAMPAGE:
		u.rampage -= 1
		if u.rampage == 0:
			msg("%s est épuisé par sa colère !" % nm(u))
			_confuse(u, u, true)
	_cur_move = {}
	for d: Battler in dancers:
		if d.alive():
			msg("%s se met à danser aussi !" % nm(d))
			_execute(d, foe(d) if _targets_foe(m) else d, m)


func _can_act(u: Battler, id: int) -> bool:
	var mon := u.mon
	var md := move_data(id)
	var ident: String = md["ident"]
	if mon.status == "slp":
		mon.sleep_turns -= 2 if ab(u) == "early-bird" else 1
		if mon.sleep_turns <= 0:
			mon.status = ""
			msg("%s se réveille !" % nm(u))
			u.nightmare = false
			refresh()
		elif ident != "snore" and ident != "sleep-talk":
			msg("%s dort profondément." % nm(u))
			return false
	if ab(u) == "comatose" and ident not in ["snore", "sleep-talk"]:
		pass
	if mon.status == "frz":
		if randi() % 5 == 0 or has_flag(md, "defrost") or ident in ["flame-wheel", "sacred-fire", "flare-blitz", "scald",
				"steam-eruption", "burn-up", "pyro-ball", "scorching-sands", "matcha-gotcha"]:
			mon.status = ""
			msg("%s n'est plus gelé !" % nm(u))
			refresh()
		else:
			msg("%s est gelé ! Il ne peut pas bouger !" % nm(u))
			return false
	if u.flinch:
		msg("%s a peur et ne peut pas attaquer !" % nm(u))
		if ab(u) == "steadfast":
			_stage(u, "spe", 1, u)
		return false
	if u.taunt > 0 and md["cat"] == "status" and ident != "struggle":
		msg("%s ne peut pas utiliser %s à cause de la Provoc !" % [nm(u), md["name"]])
		return false
	if gravity > 0 and has_flag(md, "gravity"):
		msg("%s ne peut pas utiliser %s à cause de la Gravité !" % [nm(u), md["name"]])
		return false
	if u.heal_block > 0 and has_flag(md, "heal"):
		msg("%s ne peut pas se soigner !" % nm(u))
		return false
	if u.confusion > 0:
		u.confusion -= 1
		if u.confusion == 0:
			msg("%s n'est plus confus !" % nm(u))
		else:
			msg("%s est confus..." % nm(u))
			if randi() % 3 == 0:
				msg("Il se blesse dans sa confusion !")
				var a: float = stat_value(u, 1)
				var d: float = stat_value(u, 2)
				var dmg := int(int(int(2 * u.mon.level / 5 + 2) * 40 * a / maxf(1.0, d)) / 50) + 2
				anim(u, "hit")
				_hurt(u, dmg)
				return false
	if mon.status == "par" and randi() % 4 == 0:
		msg("%s est paralysé ! Il ne peut pas attaquer !" % nm(u))
		return false
	if u.attract:
		msg("%s est amoureux de %s !" % [nm(u), nm(u.attract_by) if u.attract_by != null else "son adversaire"])
		if randi() % 2 == 0:
			msg("L'amour empêche %s d'attaquer !" % nm(u))
			return false
	if u.focus_punch and u.hit_by_foe and ident == "focus-punch":
		msg("%s perd sa concentration et ne peut pas attaquer !" % nm(u))
		return false
	return true


func _execute(u: Battler, t: Battler, m: Dictionary) -> void:
	var ident: String = m["ident"]
	# Capacités en deux tours (Herbe Pouvoir les lance tout de suite).
	if TWO_TURN.has(ident):
		if u.charging != m["id"]:
			var instant := (ident in ["solar-beam", "solar-blade"] and is_sun(u)) or (ident == "electro-shot" and is_rain(u))
			if not instant:
				u.charging = m["id"]
				msg(TWO_TURN[ident] % nm(u))
				if ident == "skull-bash":
					_stage(u, "def", 1, u)
				if ident in ["meteor-beam", "electro-shot"]:
					_stage(u, "spa", 1, u)
				if it(u) == "power-herb":
					_consume(u)
					msg("%s est prêt grâce à l'Herbe Pouvoir !" % nm(u))
				else:
					if SEMI_INVULN.has(ident):
						u.invuln = ident
						events.append({"t": "hide", "side": u.side, "slot": u.slot, "on": true})
					return
		u.charging = 0
		if u.invuln != "":
			u.invuln = ""
			events.append({"t": "hide", "side": u.side, "slot": u.slot, "on": false})
	if t != null and t != u and _blocked_by_protect(u, t, m):
		u.last_failed = true
		_end_rollout(u)
		return
	# Reflet Magik / Miroir Magik renvoient les capacités de statut.
	if t != null and t != u and has_flag(m, "reflectable") and (t.magic_coat or dab(u, t) == "magic-bounce") and not u.magic_coat:
		msg("%s renvoie %s !" % [nm(t), m["name"]])
		t.magic_coat = true
		_execute(t, u, m)
		t.magic_coat = false
		return
	if _special_move(u, t, m):
		return
	if m["cat"] == "status":
		_status_move(u, t, m)
	else:
		_damage_move(u, t, m)


func _targets_foe(m: Dictionary) -> bool:
	return not SELF_TARGETS.has(m["target"]) and m["target"] not in FIELD_TARGETS


func _fail() -> void:
	msg("Mais cela échoue !")


## Abri et ses variantes, Garde Large, Prévention, Tatamigaeshi, Vigilance.
func _blocked_by_protect(u: Battler, t: Battler, m: Dictionary) -> bool:
	if t.side == u.side and not _targets_foe(m):
		return false
	var ident: String = m["ident"]
	var ts: BSide = sides[t.side]
	if t.side != u.side:
		if ts.wide_guard and m["target"] in SPREAD_TARGETS:
			msg("La Garde Large protège %s !" % nm(t))
			return true
		if ts.quick_guard and _priority(u) > 0 and _targets_foe(m):
			msg("Prévention protège %s !" % nm(t))
			return true
		if ts.mat_block and m["cat"] != "status":
			msg("Tatamigaeshi protège %s !" % nm(t))
			return true
		if ts.crafty_shield and m["cat"] == "status" and _targets_foe(m):
			msg("Vigilance protège %s !" % nm(t))
			return true
	if not t.protected:
		return false
	# Les capacités sans le drapeau « protect » passent l'Abri (la 9e génération n'a pas de drapeaux : on suppose que si).
	if not has_flag(m, "protect") and m.get("gen", 1) < 9:
		return false
	if ident in ["feint", "shadow-force", "phantom-force", "hyperspace-hole", "hyperspace-fury", "hyper-drill", "mighty-cleave"]:
		t.protected = false
		msg("%s brise la protection de %s !" % [nm(u), nm(t)])
		return false
	if ab(u) == "unseen-fist" and has_flag(m, "contact"):
		return false
	if t.protect_kind in ["kings-shield", "obstruct", "silk-trap"] and m["cat"] == "status":
		return false
	msg("%s se protège !" % nm(t))
	if has_flag(m, "contact") and it(u) != "protective-pads" and not (has_flag(m, "punch") and it(u) == "punching-glove"):
		match t.protect_kind:
			"spiky-shield":
				msg("%s est blessé par le Pico-Défense !" % nm(u))
				_hurt(u, u.mon.max_hp() / 8)
			"kings-shield":
				_stage(u, "atk", -1, t)
			"baneful-bunker":
				_set_status(u, "psn", t, false)
			"obstruct":
				_stage(u, "def", -2, t)
			"silk-trap":
				_stage(u, "spe", -1, t)
			"burning-bulwark":
				_set_status(u, "brn", t, false)
	if ident in ["jump-kick", "high-jump-kick", "axe-kick", "supercell-slam"]:
		msg("%s s'écrase au sol !" % nm(u))
		_hurt(u, u.mon.max_hp() / 2)
	return true


func _hits(u: Battler, t: Battler, m: Dictionary) -> bool:
	if always_hit and t.invuln == "":
		return true
	var ident: String = m["ident"]
	var ua := ab(u)
	var ta := dab(u, t)
	if t.invuln != "":
		var ok := false
		match t.invuln:
			"fly", "bounce", "sky-drop":
				ok = ident in ["gust", "twister", "thunder", "sky-uppercut", "hurricane", "smack-down", "thousand-arrows"]
			"dig":
				ok = ident in ["earthquake", "magnitude", "fissure"]
			"dive":
				ok = ident in ["surf", "whirlpool"]
		if not ok and ua != "no-guard" and ta != "no-guard":
			return false
	var acc: int = m["acc"]
	var w := weather_for(t)
	if ident in ["thunder", "hurricane", "bleakwind-storm", "wildbolt-storm", "sandsear-storm"]:
		if w in ["rain", "heavy-rain"]:
			return true
		if w in ["sun", "harsh-sun"] and ident in ["thunder", "hurricane"]:
			acc = 50
	if ident == "blizzard" and w in ["hail", "snow"]:
		return true
	if ident == "toxic" and has_type(u, "poison"):
		return true
	if ident in OHKO:
		return true
	if acc == 0 or ua == "no-guard" or ta == "no-guard" or t.telekinesis > 0 and ident not in OHKO:
		return true
	if u.lock_on:
		u.lock_on = false
		return true
	if m["cat"] == "status" and ta == "wonder-skin" and _targets_foe(m):
		acc = mini(acc, 50)
	var eva: int = 0 if (t.foresight or t.miracle_eye or ua in ["keen-eye", "minds-eye", "unaware"] or ident in ["chip-away", "sacred-sword", "darkest-lariat"]) else t.stages["eva"]
	if ta == "unaware":
		eva = t.stages["eva"]
	var s := clampi((0 if ta == "unaware" else u.stages["acc"]) - eva, -6, 6)
	var p := acc * acc_mult(s)
	if ua == "compound-eyes":
		p *= 1.3
	if ua == "victory-star" or (ally(u) != null and ab(ally(u)) == "victory-star"):
		p *= 1.1
	if ua == "hustle" and m["cat"] == "physical":
		p *= 0.8
	if gravity > 0:
		p *= 5.0 / 3.0
	var ui := it(u)
	if ui == "wide-lens":
		p *= 1.1
	if ui == "zoom-lens" and t.moved:
		p *= 1.2
	if u.micle:
		p *= 1.2
		u.micle = false
	if (ta == "sand-veil" and w == "sandstorm") or (ta == "snow-cloak" and w in ["hail", "snow"]):
		p *= 0.8
	if ta == "tangled-feet" and t.confusion > 0:
		p *= 0.5
	if it(t) in ["bright-powder", "lax-incense"]:
		p *= 0.9
	return randf() * 100.0 < p


# ---------------------------------------------------------------------------
# Capacités Z
# ---------------------------------------------------------------------------

func z_crystal(b: Battler) -> Dictionary:
	return Data.z_crystals.get(b.item, {})


func can_z_move(b: Battler, move_id: int) -> bool:
	if b.side == 0 and b.owner < z_owners.size() and not z_owners[b.owner]:
		return false
	if not can_z[b.side] or sides[b.side].z_used.get(b.owner, false):
		return false
	var z := z_crystal(b)
	if z.is_empty():
		return false
	var md := move_data(move_id)
	if z.has("type"):
		return md["type"] == z["type"]
	return move_id == z.get("move", -1) and (z.get("species", 0) == 0 or b.mon.sprite_id() == z["species"] or b.mon.species == z["species"])


## Puissance d'une capacité Z selon la puissance de base (table officielle).
static func z_power(base: int) -> int:
	if base <= 55:
		return 100
	if base <= 65:
		return 120
	if base <= 75:
		return 140
	if base <= 85:
		return 160
	if base <= 95:
		return 175
	if base <= 100:
		return 180
	if base <= 110:
		return 185
	if base <= 125:
		return 190
	if base <= 130:
		return 195
	return 200


func z_move(b: Battler, m: Dictionary) -> Dictionary:
	var z := z_crystal(b)
	var out := m.duplicate(true)
	out["z"] = true
	out["acc"] = 0
	if m["cat"] == "status":
		out["z_status"] = true
		out["name"] = "Z-" + m["name"]
		return out
	out["name"] = z.get("name", m["name"])
	out["power"] = int(z["power"]) if z.get("power", 0) > 0 else z_power(m["power"])
	out["flags"] = m.get("flags", []).filter(func(f): return f != "contact" or not z.has("type")) + ["z"]
	out["min_hits"] = 0
	out["max_hits"] = 0
	if z.get("z", "") == "guardian-of-alola":
		out["ident"] = "guardian-of-alola"
	if z.get("z", "") == "extreme-evoboost":
		out["ident"] = "extreme-evoboost"
		out["cat"] = "status"
	return out


# ---------------------------------------------------------------------------
# Types et efficacité
# ---------------------------------------------------------------------------

func _move_type(u: Battler, m: Dictionary) -> String:
	var ident: String = m["ident"]
	var typ: String = m["type"]
	match ident:
		"hidden-power":
			typ = u.mon.hidden_power_type()
		"weather-ball":
			var w := weather_for(u)
			typ = {"rain": "water", "heavy-rain": "water", "sun": "fire", "harsh-sun": "fire", "sandstorm": "rock",
				"hail": "ice", "snow": "ice"}.get(w, "normal")
		"judgment":
			if TYPE_ITEMS.has(u.item) and u.item in PLATES:
				typ = TYPE_ITEMS[u.item]
		"multi-attack":
			typ = MEMORIES.get(u.item, "normal")
		"techno-blast":
			typ = DRIVES.get(u.item, "normal")
		"natural-gift":
			if Data.items.get(u.item, {}).has("ng"):
				typ = Data.items[u.item]["ng"][0]
		"terrain-pulse":
			if terrain != "" and grounded(u):
				typ = {"electric": "electric", "grassy": "grass", "misty": "fairy", "psychic": "psychic"}[terrain]
		"aura-wheel":
			if u.form_id != 0 and u.mon.species == 877:
				typ = "dark"
		"revelation-dance":
			typ = u.types[0] if u.types.size() > 0 else "normal"
		"raging-bull":
			var f: String = u.mon.data().get("form", "")
			typ = "fighting" if "combat" in f else "fire" if "blaze" in f else "water" if "aqua" in f else "normal"
		"ivy-cudgel":
			typ = {"wellspring-mask": "water", "hearthflame-mask": "fire", "cornerstone-mask": "rock"}.get(u.item, "grass")
		"tera-starstorm":
			typ = "normal"
	var a := ab(u)
	if a == "normalize":
		typ = "normal"
	elif ATE_ABILITIES.has(a) and typ == "normal" and ident not in ["weather-ball", "judgment", "multi-attack", "techno-blast", "natural-gift", "terrain-pulse", "struggle"]:
		typ = ATE_ABILITIES[a]
	elif a == "liquid-voice" and has_flag(m, "sound"):
		typ = "water"
	if u.electrify or (ion_deluge and typ == "normal"):
		typ = "electric"
	return typ


func _type_eff(u: Battler, t: Battler, typ: String, ident: String) -> float:
	var tt := all_types(t)
	if (t.foresight or ab(u) in ["scrappy", "minds-eye"]) and typ in ["normal", "fighting"]:
		tt.erase("ghost")
	if t.miracle_eye and typ == "psychic":
		tt.erase("dark")
	if it(t) == "ring-target":
		var keep := []
		for x in tt:
			if Data.effectiveness(typ, [x]) != 0.0:
				keep.append(x)
		tt = keep if keep.size() > 0 else ["normal"]
	var e := Data.effectiveness(typ, tt)
	if ident == "freeze-dry" and tt.has("water"):
		e *= 4.0
	if ident == "flying-press":
		e *= Data.effectiveness("flying", tt)
	if typ == "ground" and not grounded(t) and ident != "thousand-arrows":
		e = 0.0
	if ident == "thousand-arrows" and tt.has("flying") and not grounded(t):
		e = 1.0
	if weather_on() == "strong-winds" and tt.has("flying") and Data.effectiveness(typ, ["flying"]) > 1.0:
		e /= 2.0
	if t.tar_shot and typ == "fire":
		e *= 2.0
	return e


## Talents (et objets) qui absorbent ou annulent une attaque. Renvoie true si l'attaque est stoppée.
func _absorb(u: Battler, t: Battler, typ: String, m: Dictionary) -> bool:
	if t == u:
		return false
	var ident: String = m["ident"]
	var ta := dab(u, t)
	match ta:
		"volt-absorb":
			if typ == "electric":
				msg("Absorbe-Volt de %s !" % nm(t))
				_heal(t, t.mon.max_hp() / 4)
				return true
		"water-absorb", "dry-skin":
			if typ == "water":
				msg("%s de %s !" % [Data.ability_name(t.ability), nm(t)])
				_heal(t, t.mon.max_hp() / 4)
				return true
		"earth-eater":
			if typ == "ground":
				msg("Absorbe-Terre de %s !" % nm(t))
				_heal(t, t.mon.max_hp() / 4)
				return true
		"lightning-rod", "motor-drive":
			if typ == "electric":
				msg("%s de %s attire l'attaque !" % [Data.ability_name(t.ability), nm(t)])
				_stage(t, "spa" if ta == "lightning-rod" else "spe", 1, t)
				return true
		"storm-drain":
			if typ == "water":
				msg("Lavabo de %s attire l'attaque !" % nm(t))
				_stage(t, "spa", 1, t)
				return true
		"sap-sipper":
			if typ == "grass":
				msg("Herbivore de %s !" % nm(t))
				_stage(t, "atk", 1, t)
				return true
		"flash-fire":
			if typ == "fire":
				t.flash_fire = true
				msg("Torche de %s renforce ses attaques Feu !" % nm(t))
				return true
		"well-baked-body":
			if typ == "fire":
				msg("Corps Cuit de %s !" % nm(t))
				_stage(t, "def", 2, t)
				return true
		"wind-rider":
			if has_flag(m, "wind"):
				msg("Surf Céleste de %s !" % nm(t))
				_stage(t, "atk", 1, t)
				return true
		"soundproof":
			if has_flag(m, "sound"):
				msg("Anti-Bruit de %s le protège !" % nm(t))
				return true
		"bulletproof":
			if has_flag(m, "ballistics"):
				msg("Pare-Balles de %s le protège !" % nm(t))
				return true
		"damp":
			if ident in ["self-destruct", "explosion", "mind-blown", "misty-explosion"]:
				msg("Moiteur de %s empêche l'explosion !" % nm(t))
				return true
		"wonder-guard":
			if m["cat"] != "status" and _type_eff(u, t, typ, ident) <= 1.0 and ident != "struggle":
				msg("Garde Mystik de %s le protège !" % nm(t))
				return true
		"telepathy":
			if t.side == u.side and m["cat"] != "status":
				msg("%s esquive l'attaque de son allié !" % nm(t))
				return true
		"good-as-gold":
			if m["cat"] == "status" and _targets_foe(m):
				msg("Corps en Or de %s le protège !" % nm(t))
				return true
		"queenly-majesty", "dazzling", "armor-tail":
			if _priority(u) > 0 and _targets_foe(m) and t.side != u.side:
				msg("%s de %s empêche l'attaque !" % [Data.ability_name(t.ability), nm(t)])
				return true
		"overcoat":
			if has_flag(m, "powder"):
				msg("Envelocape de %s le protège !" % nm(t))
				return true
	var al := ally(t)
	if al != null and dab(u, al) in ["queenly-majesty", "dazzling", "armor-tail"] and _priority(u) > 0 and t.side != u.side:
		msg("%s de %s empêche l'attaque !" % [Data.ability_name(al.ability), nm(al)])
		return true
	if has_flag(m, "powder") and (has_type(t, "grass") or it(t) == "safety-goggles"):
		msg("Ça n'affecte pas %s..." % nm(t))
		return true
	if _priority(u) > 0 and terrain == "psychic" and grounded(t) and t.side != u.side and _targets_foe(m):
		msg("Le Champ Psychique protège %s !" % nm(t))
		return true
	if ab(u) == "prankster" and m["cat"] == "status" and has_type(t, "dark") and t.side != u.side and _targets_foe(m):
		msg("Ça n'affecte pas %s..." % nm(t))
		return true
	if typ == "ground" and it(t) == "air-balloon" and m["cat"] != "status" and ident != "thousand-arrows":
		msg("Ça n'affecte pas %s..." % nm(t))
		return true
	return false


# ---------------------------------------------------------------------------
# Puissance et dégâts
# ---------------------------------------------------------------------------

func _base_power(u: Battler, t: Battler, m: Dictionary) -> int:
	var ident: String = m["ident"]
	var p: int = m["power"]
	var hp := u.hp_frac()
	match ident:
		"flail", "reversal":
			var r := int(48 * u.mon.hp / maxi(1, u.mon.max_hp()))
			p = 200 if r < 2 else 150 if r < 5 else 100 if r < 10 else 80 if r < 17 else 40 if r < 33 else 20
		"return":
			p = maxi(1, int(u.mon.happiness * 10 / 25))
		"frustration":
			p = maxi(1, int((255 - u.mon.happiness) * 10 / 25))
		"low-kick", "grass-knot":
			var w := weight(t)
			p = 20 if w < 100 else 40 if w < 250 else 60 if w < 500 else 80 if w < 1000 else 100 if w < 2000 else 120
		"heavy-slam", "heat-crash":
			var ratio := weight(u) / weight(t)
			p = 120 if ratio >= 5 else 100 if ratio >= 4 else 80 if ratio >= 3 else 60 if ratio >= 2 else 40
		"eruption", "water-spout", "dragon-energy":
			p = maxi(1, int(150 * hp))
		"wring-out", "crush-grip":
			p = maxi(1, int(120 * t.hp_frac()))
		"hard-press":
			p = maxi(1, int(100 * t.hp_frac()))
		"gyro-ball":
			p = mini(150, int(25 * speed(t) / maxf(1.0, speed(u))) + 1)
		"electro-ball":
			var r2 := speed(u) / maxf(1.0, speed(t))
			p = 150 if r2 >= 4 else 120 if r2 >= 3 else 80 if r2 >= 2 else 60 if r2 >= 1 else 40
		"stored-power", "power-trip":
			var boosts := 0
			for k in u.stages:
				boosts += maxi(0, u.stages[k])
			p = 20 + 20 * boosts
		"punishment":
			var tb := 0
			for k in t.stages:
				tb += maxi(0, t.stages[k])
			p = mini(200, 60 + 20 * tb)
		"rollout", "ice-ball":
			p = 30 * int(pow(2, 5 - maxi(1, u.rollout))) * (2 if u.curled else 1)
		"fury-cutter":
			p = mini(160, 40 * int(pow(2, u.fury_cutter)))
		"echoed-voice":
			p = mini(200, 40 * (u.echo + 1))
		"spit-up":
			p = 100 * u.stockpile
		"facade":
			if u.mon.status != "":
				p *= 2
		"hex", "infernal-parade":
			if t.mon.status != "" or dab(u, t) == "comatose":
				p *= 2
		"venoshock", "barb-barrage":
			if t.mon.status in ["psn", "tox"]:
				p *= 2
		"brine":
			if t.hp_frac() <= 0.5:
				p *= 2
		"revenge", "avalanche":
			if u.hit_by_foe:
				p *= 2
		"payback":
			if t.moved:
				p *= 2
		"assurance":
			if t.damaged_turn:
				p *= 2
		"retaliate":
			if sides[u.side].fainted_last_turn:
				p *= 2
		"acrobatics":
			if u.item == "":
				p *= 2
		"knock-off":
			if t.item != "" and not _item_locked(t):
				p = int(p * 1.5)
		"smelling-salts":
			if t.mon.status == "par":
				p *= 2
		"wake-up-slap":
			if t.mon.status == "slp":
				p *= 2
		"weather-ball":
			if weather_for(u) != "":
				p *= 2
		"terrain-pulse":
			if terrain != "" and grounded(u):
				p *= 2
		"solar-beam", "solar-blade":
			if weather_for(u) in ["rain", "heavy-rain", "sandstorm", "hail", "snow"]:
				p /= 2
		"stomp", "body-slam", "dragon-rush", "heat-crash", "heavy-slam", "flying-press", "steamroller", "malicious-moonsault":
			if t.minimized:
				p *= 2
		"earthquake", "magnitude", "bulldoze":
			if t.invuln == "dig":
				p *= 2
			if terrain == "grassy" and grounded(t):
				p /= 2
		"surf", "whirlpool":
			if t.invuln == "dive":
				p *= 2
		"gust", "twister":
			if t.invuln in ["fly", "bounce", "sky-drop"]:
				p *= 2
		"hidden-power":
			p = 60
		"trump-card":
			var left := 5
			for mv in u.moves():
				if mv["id"] == m["id"]:
					left = mv["pp"]
			p = 200 if left <= 0 else 80 if left == 1 else 60 if left == 2 else 50 if left == 3 else 40
		"natural-gift":
			if Data.items.get(u.item, {}).has("ng"):
				p = int(Data.items[u.item]["ng"][1])
		"fling":
			p = int(Data.items.get(u.item, {}).get("fling", 30))
		"beat-up":
			p = 10
		"last-respects":
			p = mini(5050, 50 + 50 * sides[u.side].fainted_count)
		"rage-fist":
			p = mini(350, 50 + 50 * int(u.mon.counters.get("hits", 0)))
		"bolt-beak", "fishious-rend":
			if not t.moved:
				p *= 2
		"lash-out":
			if u.lowered_turn:
				p *= 2
		"burning-jealousy", "alluring-voice":
			pass
		"temper-flare", "stomping-tantrum":
			if u.last_failed:
				p *= 2
		"fickle-beam":
			if randi() % 10 < 3:
				p *= 2
				msg("%s a de la chance !" % nm(u))
		"expanding-force":
			if terrain == "psychic" and grounded(u):
				p = int(p * 1.5)
		"rising-voltage":
			if terrain == "electric" and grounded(t):
				p *= 2
		"misty-explosion":
			if terrain == "misty" and grounded(u):
				p = int(p * 1.5)
		"psyblade":
			if terrain == "electric":
				p = int(p * 1.5)
		"grav-apple":
			if gravity > 0:
				p = int(p * 1.5)
		"pursuit":
			pass
		"round":
			pass
		"triple-kick", "triple-axel":
			pass
		"collision-course", "electro-drift":
			if _type_eff(u, t, _move_type(u, m), ident) > 1.0:
				p = int(p * 4 / 3)
		"tera-blast":
			pass
		"present":
			pass
		"spirit-shackle":
			pass
	return maxi(1, p)


## Modificateurs de puissance : talents, objets, champs, Coup d'Main.
func _power_mods(u: Battler, t: Battler, m: Dictionary, typ: String, p: int, dry := false) -> int:
	var ident: String = m["ident"]
	var f := 1.0
	var a := ab(u)
	if u.charged and typ == "electric":
		f *= 2.0
	if u.helping:
		f *= 1.5
	if mud_sport > 0 and typ == "electric":
		f *= 1.0 / 3.0
	if water_sport > 0 and typ == "fire":
		f *= 1.0 / 3.0
	if terrain == "electric" and typ == "electric" and grounded(u):
		f *= 1.3
	if terrain == "grassy" and typ == "grass" and grounded(u):
		f *= 1.3
	if terrain == "psychic" and typ == "psychic" and grounded(u):
		f *= 1.3
	if terrain == "misty" and typ == "dragon" and grounded(t):
		f *= 0.5
	match a:
		"technician":
			if p <= 60:
				f *= 1.5
		"iron-fist":
			if has_flag(m, "punch"):
				f *= 1.2
		"strong-jaw":
			if has_flag(m, "bite"):
				f *= 1.5
		"mega-launcher":
			if has_flag(m, "pulse"):
				f *= 1.5
		"sharpness":
			if has_flag(m, "slicing"):
				f *= 1.5
		"tough-claws":
			if has_flag(m, "contact"):
				f *= 1.3
		"reckless":
			if m.get("drain", 0) < 0 or ident in ["jump-kick", "high-jump-kick", "axe-kick", "supercell-slam"]:
				f *= 1.2
		"sheer-force":
			if _has_secondary(m):
				f *= 1.3
		"sand-force":
			if weather_on() == "sandstorm" and typ in ["rock", "ground", "steel"]:
				f *= 1.3
		"analytic":
			var last := true
			for o: Battler in _on_field():
				if o != u and not o.moved:
					last = false
			if last:
				f *= 1.3
		"overgrow", "blaze", "torrent", "swarm":
			var boosted: String = {"overgrow": "grass", "blaze": "fire", "torrent": "water", "swarm": "bug"}[a]
			if typ == boosted and u.mon.hp * 3 <= u.mon.max_hp():
				f *= 1.5
		"rivalry":
			if u.mon.gender < 2 and t.mon.gender < 2:
				f *= 1.25 if u.mon.gender == t.mon.gender else 0.75
		"flare-boost":
			if u.mon.status == "brn" and m["cat"] == "special":
				f *= 1.5
		"toxic-boost":
			if u.mon.status in ["psn", "tox"] and m["cat"] == "physical":
				f *= 1.5
		"punk-rock":
			if has_flag(m, "sound"):
				f *= 1.3
		"steelworker", "steely-spirit":
			if typ == "steel":
				f *= 1.5
		"transistor":
			if typ == "electric":
				f *= 1.3
		"dragons-maw":
			if typ == "dragon":
				f *= 1.5
		"rocky-payload":
			if typ == "rock":
				f *= 1.5
		"water-bubble":
			if typ == "water":
				f *= 2.0
		"normalize":
			f *= 1.2
		"supreme-overlord":
			f *= 1.0 + 0.1 * mini(5, sides[u.side].fainted_count)
	if ATE_ABILITIES.has(a) and m["type"] == "normal" and typ != "normal":
		f *= 1.2
	if ally(u) != null:
		var al := ab(ally(u))
		if al == "battery" and m["cat"] == "special":
			f *= 1.3
		if al == "power-spot":
			f *= 1.3
		if al == "steely-spirit" and typ == "steel":
			f *= 1.5
	if u.flash_fire and typ == "fire":
		f *= 1.5
	# Auras (Aura Ténébreuse, Aura Féerique, Aura Inversée).
	var dark_aura := false
	var fairy_aura := false
	var aura_break := false
	for o: Battler in _on_field():
		match ab(o):
			"dark-aura":
				dark_aura = true
			"fairy-aura":
				fairy_aura = true
			"aura-break":
				aura_break = true
	if (dark_aura and typ == "dark") or (fairy_aura and typ == "fairy"):
		f *= 0.75 if aura_break else 4.0 / 3.0
	var ta := dab(u, t)
	match ta:
		"thick-fat":
			if typ in ["fire", "ice"]:
				f *= 0.5
		"heatproof":
			if typ == "fire":
				f *= 0.5
		"dry-skin":
			if typ == "fire":
				f *= 1.25
		"water-bubble":
			if typ == "fire":
				f *= 0.5
		"purifying-salt":
			if typ == "ghost":
				f *= 0.5
		"fluffy":
			if has_flag(m, "contact"):
				f *= 0.5
			if typ == "fire":
				f *= 2.0
		"punk-rock":
			if has_flag(m, "sound"):
				f *= 0.5
	# Objets de l'attaquant.
	var item := it(u)
	if TYPE_ITEMS.has(item) and TYPE_ITEMS[item] == typ:
		f *= 1.2
	if item == typ + "-gem" and m["cat"] != "status" and ident not in ["struggle"] and not m.get("z", false):
		if not dry:
			_consume(u)
			msg("Le Joyau %s renforce l'attaque de %s !" % [Data.type_name(typ), nm(u)])
		f *= 1.3
	if item == "muscle-band" and m["cat"] == "physical":
		f *= 1.1
	if item == "wise-glasses" and m["cat"] == "special":
		f *= 1.1
	if item == "punching-glove" and has_flag(m, "punch"):
		f *= 1.1
	if item == "soul-dew" and u.mon.species in [380, 381] and typ in ["dragon", "psychic"]:
		f *= 1.2
	if item in ["adamant-orb", "adamant-crystal"] and u.mon.species == 483 and typ in ["dragon", "steel"]:
		f *= 1.2
	if item in ["lustrous-orb", "lustrous-globe"] and u.mon.species == 484 and typ in ["dragon", "water"]:
		f *= 1.2
	if item in ["griseous-orb", "griseous-core"] and u.mon.species == 487 and typ in ["dragon", "ghost"]:
		f *= 1.2
	if item in ["wellspring-mask", "hearthflame-mask", "cornerstone-mask"] and u.mon.species == 1017:
		f *= 1.2
	return maxi(1, int(p * f))


## La capacité a-t-elle un effet secondaire (Sans Limite, Écran Poudre, Cape Furtive).
func _has_secondary(m: Dictionary) -> bool:
	return (m.get("ail_ch", 0) > 0 and m["cat"] != "status") or m.get("flinch", 0) > 0 or (m.get("mcat", 0) == 6 and m.get("stat_ch", 0) < 100) \
		or (m.get("mcat", 0) in [6, 7] and m.get("stat_ch", 0) > 0 and m.get("stat_ch", 0) < 100) or m["ident"] in ["tri-attack", "secret-power", "dire-claw"]


## Attaque utilisée (Tricherie : celle de la cible ; Bad Body Press : la Défense).
func _attack_stat(u: Battler, t: Battler, m: Dictionary, crit: bool, phys: bool) -> float:
	var src := t if m["ident"] == "foul-play" else u
	var idx := 1 if phys else 3
	if m["ident"] == "body-press":
		idx = 2
	var s: int = src.stages[STAGE_KEYS[idx]]
	if dab(u, t) == "unaware" and src == u:
		s = 0
	if crit:
		s = maxi(s, 0)
	return stat_value(src, idx, s)


func _defense_stat(u: Battler, t: Battler, m: Dictionary, crit: bool, phys: bool) -> float:
	var idx := 2 if phys or m["ident"] in ["psyshock", "psystrike", "secret-sword"] else 4
	var s: int = t.stages[STAGE_KEYS[idx]]
	if ab(u) == "unaware" or m["ident"] in ["chip-away", "sacred-sword", "darkest-lariat"]:
		s = 0
	if crit:
		s = mini(s, 0)
	return stat_value(t, idx, s)


func _calc_damage(u: Battler, t: Battler, m: Dictionary, power: int, eff: float, crit: bool, rand := true) -> int:
	var phys: bool = m["cat"] == "physical"
	if m["ident"] in ["photon-geyser", "shell-side-arm", "tera-blast", "light-that-burns-the-sky"]:
		phys = stat_value(u, 1) > stat_value(u, 3)
	var a := _attack_stat(u, t, m, crit, phys)
	var d := _defense_stat(u, t, m, crit, phys)
	var dmg := int(int(int(2 * u.mon.level / 5 + 2) * power * a / maxf(1.0, d)) / 50) + 2
	var typ := _move_type(u, m)
	if _spread:
		dmg = int(dmg * 0.75)
	var w := weather_for(t)
	if (w in ["sun", "harsh-sun"] and typ == "fire") or (w in ["rain", "heavy-rain"] and typ == "water"):
		dmg = int(dmg * 1.5)
	elif (w in ["sun", "harsh-sun"] and typ == "water" and m["ident"] != "hydro-steam") or (w in ["rain", "heavy-rain"] and typ == "fire"):
		dmg = int(dmg * 0.5)
	elif w in ["sun", "harsh-sun"] and m["ident"] == "hydro-steam":
		dmg = int(dmg * 1.5)
	if u.glaive:
		pass
	if t.glaive:
		dmg *= 2
	if crit:
		dmg = int(dmg * (2.25 if ab(u) == "sniper" else 1.5))
	if rand:
		dmg = int(dmg * randi_range(85, 100) / 100.0)
	else:
		dmg = int(dmg * 0.925)
	var stab := has_type(u, typ) or (ab(u) in ["protean", "libero"])
	if stab:
		dmg = int(dmg * (2.0 if ab(u) == "adaptability" else 1.5))
	dmg = int(dmg * eff)
	var ua := ab(u)
	var ta := dab(u, t)
	if phys and u.mon.status == "brn" and ua != "guts" and m["ident"] != "facade":
		dmg = int(dmg * 0.5)
	# Modificateurs finaux.
	var f := 1.0
	if not crit and ua != "infiltrator":
		var ts: BSide = sides[t.side]
		if ts.aurora_veil > 0 or (phys and ts.reflect > 0) or (not phys and ts.light_screen > 0):
			f *= 2.0 / 3.0 if is_double() else 0.5
	if eff < 1.0 and ua == "tinted-lens":
		f *= 2.0
	if eff > 1.0 and ta in ["filter", "solid-rock", "prism-armor"]:
		f *= 0.75
	if eff > 1.0 and ua == "neuroforce":
		f *= 1.25
	if ta in ["multiscale", "shadow-shield"] and t.mon.hp == t.mon.max_hp():
		f *= 0.5
	if ta == "ice-scales" and not phys:
		f *= 0.5
	if ally(t) != null and ab(ally(t)) == "friend-guard":
		f *= 0.75
	if ua == "sniper" and false:
		pass
	var item := it(u)
	if item == "expert-belt" and eff > 1.0:
		f *= 1.2
	if item == "life-orb":
		f *= 1.3
	if item == "metronome":
		var n := int(u.mon.counters.get("metronome_n", 0))
		f *= minf(2.0, 1.0 + 0.2 * n)
	# Baies qui réduisent un coup super efficace.
	var tb := it(t)
	if RESIST_BERRIES.has(tb) and RESIST_BERRIES[tb] == typ and (eff > 1.0 or typ == "normal") and _can_eat(t) and rand:
		_consume(t, true)
		msg("%s mange sa %s et réduit les dégâts !" % [nm(t), Data.item_name(tb)])
		f *= 0.25 if ab(t) == "ripen" else 0.5
	return maxi(1, int(dmg * f))


func _crit(u: Battler, t: Battler, m: Dictionary) -> bool:
	if dab(u, t) in ["battle-armor", "shell-armor"] or sides[t.side].lucky_chant > 0:
		return false
	var ident: String = m["ident"]
	if ident in ["storm-throw", "frost-breath", "surging-strikes", "wicked-blow", "flower-trick", "zippy-zap"] or u.laser_focus > 0:
		return true
	if ab(u) == "merciless" and t.mon.status in ["psn", "tox"]:
		return true
	var stage: int = m.get("crit", 0) + (2 if u.focus_energy else 0) + u.crit_bonus
	if ab(u) == "super-luck":
		stage += 1
	var item := it(u)
	if item in ["scope-lens", "razor-claw"]:
		stage += 1
	if item in ["leek", "stick"] and u.mon.species in [83, 865]:
		stage += 2
	if item == "lucky-punch" and u.mon.species == 113:
		stage += 2
	var odds: int = [24, 8, 2, 1][mini(stage, 3)]
	return randi() % odds == 0


# ---------------------------------------------------------------------------
# Capacités offensives
# ---------------------------------------------------------------------------

## Conditions d'échec avant de frapper (Coup Bas, Bluff, Coup Victorieux...). Renvoie true si ça échoue.
func _attack_fails(u: Battler, t: Battler, m: Dictionary) -> bool:
	var ident: String = m["ident"]
	match ident:
		"sucker-punch", "thunderclap":
			var ta: Dictionary = actions.get(t, {})
			var tm := move_data(_action_move_id(t)) if ta.get("type", "") == "move" else {}
			if t.moved or tm.is_empty() or tm["cat"] == "status":
				return true
		"upper-hand":
			var ta2: Dictionary = actions.get(t, {})
			if t.moved or ta2.get("type", "") != "move" or _priority(t) <= 0:
				return true
		"fake-out", "first-impression", "mat-block":
			if u.turns > 0:
				return true
		"last-resort":
			if u.moves().size() < 2:
				return true
			for mv in u.moves():
				if mv["id"] != m["id"] and not u.used_moves.has(mv["id"]):
					return true
		"burn-up":
			if not has_type(u, "fire"):
				return true
		"double-shock":
			if not has_type(u, "electric"):
				return true
		"poltergeist":
			if t.item == "":
				return true
		"steel-roller", "ice-spinner":
			if ident == "steel-roller" and terrain == "":
				return true
		"dream-eater":
			if t.mon.status != "slp" and dab(u, t) != "comatose":
				return true
		"synchronoise":
			var shared := false
			for ty in all_types(u):
				if has_type(t, ty):
					shared = true
			if not shared:
				return true
		"natural-gift", "fling":
			if u.item == "" or (ident == "natural-gift" and not Data.items.get(u.item, {}).get("berry", false)) or _item_locked(u):
				return true
		"spit-up":
			if u.stockpile == 0:
				return true
		"belch":
			if not u.berry_eaten:
				return true
		"aura-wheel":
			if u.mon.species != 877:
				return true
		"hyperspace-fury":
			if u.mon.species != 720:
				return true
	return false


func _damage_move(u: Battler, t: Battler, m: Dictionary) -> void:
	var ident: String = m["ident"]
	if t == null or t.mon.hp <= 0:
		_fail()
		u.last_failed = true
		return
	u.used_moves.append(m["id"])
	var typ := _move_type(u, m)
	if _attack_fails(u, t, m):
		_fail()
		u.last_failed = true
		_end_rollout(u)
		return
	if ident in OHKO:
		_ohko(u, t, m)
		return
	var multi_acc := ident in ["triple-kick", "triple-axel", "population-bomb"]
	if not multi_acc and not _hits(u, t, m):
		msg("%s évite l'attaque !" % nm(t))
		_missed(u, m)
		return
	var eff := _type_eff(u, t, typ, ident)
	if _absorb(u, t, typ, m):
		_end_rollout(u)
		return
	if eff == 0.0 and ident not in ["guardian-of-alola"]:
		msg("Ça n'affecte pas %s..." % nm(t))
		_missed(u, m)
		return
	move_anim(u, t, m)

	# Dégâts fixes.
	var fixed := -1
	match ident:
		"seismic-toss", "night-shade":
			fixed = u.mon.level
		"dragon-rage":
			fixed = 40
		"sonic-boom":
			fixed = 20
		"super-fang", "natures-madness", "ruination":
			fixed = maxi(1, t.mon.hp / 2)
		"guardian-of-alola":
			fixed = maxi(1, t.mon.hp * 3 / 4)
		"psywave":
			fixed = maxi(1, int(u.mon.level * randi_range(50, 150) / 100))
		"final-gambit":
			fixed = u.mon.hp
		"endeavor":
			if t.mon.hp <= u.mon.hp:
				_fail()
				return
			fixed = t.mon.hp - u.mon.hp
		"counter":
			if u.hit_phys <= 0:
				_fail()
				return
			fixed = u.hit_phys * 2
		"mirror-coat":
			if u.hit_spec <= 0:
				_fail()
				return
			fixed = u.hit_spec * 2
		"metal-burst", "comeuppance":
			if u.last_dmg <= 0 or not u.hit_by_foe:
				_fail()
				return
			fixed = int(u.last_dmg * 1.5)
		"present":
			var r := randi() % 10
			if r < 2:
				msg("%s récupère des PV !" % nm(t))
				_heal(t, t.mon.max_hp() / 4)
				return
	if ident == "magnitude":
		var r2 := randi() % 100
		var lv := 4 if r2 < 5 else 5 if r2 < 15 else 6 if r2 < 35 else 7 if r2 < 65 else 8 if r2 < 85 else 9 if r2 < 95 else 10
		m = m.duplicate()
		m["power"] = [10, 30, 50, 70, 90, 110, 150][lv - 4]
		msg("Ampleur %d !" % lv)
	if ident == "present":
		m = m.duplicate()
		var r3 := randi() % 8
		m["power"] = 40 if r3 < 4 else 80 if r3 < 7 else 120
	if ident in ["rollout", "ice-ball"] and u.rollout == 0:
		u.rollout = 5
	if ident == "fury-cutter":
		u.fury_cutter = mini(u.fury_cutter + 1, 4)
	if ident == "echoed-voice":
		u.echo = mini(u.echo + 1, 4)

	# Nombre de coups.
	var hits := 1
	if m.get("min_hits", 0) > 0:
		if m["min_hits"] == m["max_hits"]:
			hits = m["min_hits"]
		elif ab(u) == "skill-link":
			hits = m["max_hits"]
		elif ident == "population-bomb":
			hits = 10
		elif it(u) == "loaded-dice":
			hits = randi_range(4, 5)
		else:
			var r := randi() % 100
			hits = 2 if r < 35 else 3 if r < 70 else 4 if r < 85 else 5
	if ident in ["triple-kick", "triple-axel"]:
		hits = 3
	if ident == "beat-up":
		hits = 0
		for i in sides[u.side].party.size():
			if sides[u.side].owners[i] == u.owner and sides[u.side].party[i].can_battle():
				hits += 1
	var parental: bool = ab(u) == "parental-bond" and hits == 1 and fixed < 0 and not m.get("z", false) and not _spread
	if parental:
		hits = 2
	var total := 0
	var landed := 0
	var crit_any := false
	var subst_hit := false
	var sheer := ab(u) == "sheer-force" and _has_secondary(m)
	for h in hits:
		if t.mon.hp <= 0 or u.mon.hp <= 0:
			break
		if multi_acc and h > 0 or (ident == "population-bomb" and it(u) != "loaded-dice"):
			if not _hits(u, t, m):
				if h == 0:
					msg("%s évite l'attaque !" % nm(t))
					_missed(u, m)
					return
				break
		elif multi_acc and h == 0 and not _hits(u, t, m):
			msg("%s évite l'attaque !" % nm(t))
			_missed(u, m)
			return
		var crit := false
		var dmg := fixed
		if fixed < 0:
			crit = _crit(u, t, m)
			var bp := _base_power(u, t, m)
			if ident == "triple-kick":
				bp = 10 * (h + 1)
			elif ident == "triple-axel":
				bp = 20 * (h + 1)
			dmg = _calc_damage(u, t, m, _power_mods(u, t, m, typ, bp), eff, crit)
			if parental and h == 1:
				dmg = maxi(1, dmg / 4)
		landed += 1
		# Clone (sauf sons et Infiltration).
		if t.substitute > 0 and not has_flag(m, "sound") and ab(u) != "infiltrator" and t != u:
			subst_hit = true
			anim(t, "hit")
			t.substitute -= dmg
			msg("Le clone encaisse les dégâts à la place de %s !" % nm(t))
			if t.substitute <= 0:
				t.substitute = 0
				msg("Le clone de %s disparaît !" % nm(t))
				events.append({"t": "sub", "side": t.side, "slot": t.slot, "on": false})
			total += dmg
			continue
		# Déguisement (Mimiqui) et Tête de Gel (Bekaglaçon).
		var ta := dab(u, t)
		if ta == "disguise" and not t.disguise_broken and t.mon.species == 778:
			t.disguise_broken = true
			msg("Le déguisement de %s tombe !" % nm(t))
			set_form(t, form_pid(778, "busted"), true)
			_hurt(t, t.mon.max_hp() / 8)
			continue
		if ta == "ice-face" and not t.ice_face_broken and m["cat"] == "physical" and t.mon.species == 875:
			t.ice_face_broken = true
			msg("La Tête de Gel de %s se brise !" % nm(t))
			set_form(t, form_pid(875, "noice"), true)
			continue
		if ident in ["false-swipe", "hold-back"]:
			dmg = mini(dmg, t.mon.hp - 1)
		var full := t.mon.hp == t.mon.max_hp()
		if dmg >= t.mon.hp:
			if t.endure:
				dmg = t.mon.hp - 1
				msg("%s tient bon !" % nm(t))
			elif full and ta == "sturdy":
				dmg = t.mon.hp - 1
				msg("Fermeté de %s ! Il tient bon !" % nm(t))
			elif full and it(t) == "focus-sash":
				dmg = t.mon.hp - 1
				_consume(t)
				msg("%s tient bon grâce à sa Ceinture Force !" % nm(t))
			elif it(t) == "focus-band" and randi() % 10 == 0:
				dmg = t.mon.hp - 1
				msg("%s tient bon grâce à son Bandeau !" % nm(t))
		anim(t, "hit")
		dmg = mini(dmg, t.mon.hp)
		t.mon.hp -= dmg
		hp_event(t)
		total += dmg
		t.last_dmg = dmg
		t.damaged_turn = true
		t.mon.count("damage", dmg)
		t.mon.count("hits")
		if crit:
			crit_any = true
			u.mon.count("crits_battle")
			msg("Coup critique !")
			if ta == "anger-point" and t.mon.hp > 0:
				t.stages["atk"] = 6
				msg("Colérique : l'Attaque de %s est au maximum !" % nm(t))
		if m["cat"] == "physical":
			t.hit_phys = dmg
		else:
			t.hit_spec = dmg
		if t.side != u.side:
			t.hit_by_foe = true
		if t.rage and t.mon.hp > 0:
			msg("La rage de %s augmente !" % nm(t))
			_stage(t, "atk", 1, t)
		if t.beak_blast and has_flag(m, "contact") and u.mon.status == "":
			_set_status(u, "brn", t, false)
		if has_flag(m, "contact") and it(u) != "protective-pads" and not (has_flag(m, "punch") and it(u) == "punching-glove") and ab(u) != "long-reach":
			_contact_effects(u, t)
		_after_hit(u, t, m, typ, eff, dmg)
		if u.mon.hp <= 0:
			break
	if landed == 0:
		return
	if fixed < 0:
		if eff > 1.0:
			msg("C'est super efficace !")
		elif eff < 1.0:
			msg("Ce n'est pas très efficace...")
	if hits > 1 and landed > 0:
		msg("Touché %d fois !" % landed)
	# Plus gros coup du joueur (carte de profil).
	if u.side == 0 and t.side == 1 and total > int(best_hit[u.owner].get("dmg", 0)):
		best_hit[u.owner] = {"dmg": total, "move": m.get("name", "?"), "target": t.mon.name()}
	_after_damage(u, t, m, typ, total, landed, subst_hit, sheer, eff)


## Attaque ratée : Pied Sauté, Pied Voltige, Glas de Soin, roulade...
func _missed(u: Battler, m: Dictionary) -> void:
	_end_rollout(u)
	u.last_failed = true
	if m["ident"] in ["jump-kick", "high-jump-kick", "axe-kick", "supercell-slam"]:
		msg("%s s'écrase au sol !" % nm(u))
		_hurt(u, u.mon.max_hp() / 2)
	if it(u) == "blunder-policy" and m["ident"] not in OHKO:
		_consume(u)
		_stage(u, "spe", 2, u)


## Réactions au contact physique (talents et objets des deux côtés).
func _contact_effects(u: Battler, t: Battler) -> void:
	var ta := ab(t)
	var ua := ab(u)
	if u.mon.hp > 0:
		match ta:
			"rough-skin", "iron-barbs":
				msg("%s est blessé par %s de %s !" % [nm(u), Data.ability_name(t.ability), nm(t)])
				_hurt(u, u.mon.max_hp() / 8)
			"gooey", "tangling-hair":
				_stage(u, "spe", -1, t)
			"mummy", "lingering-aroma":
				if ua not in UNCOPYABLE and ua != ta:
					u.ability = t.ability
					msg("Le talent de %s devient %s !" % [nm(u), Data.ability_name(t.ability)])
			"wandering-spirit":
				if ua not in UNCOPYABLE:
					var a := u.ability
					u.ability = t.ability
					t.ability = a
					msg("%s et %s échangent leurs talents !" % [nm(u), nm(t)])
			"perish-body":
				if u.perish == 0:
					u.perish = 4
				if t.perish == 0:
					t.perish = 4
				msg("Les deux Pokémon seront K.O. dans 3 tours !")
		if randi() % 10 < 3 and u.mon.hp > 0:
			match ta:
				"static":
					_set_status(u, "par", t, false)
				"poison-point":
					_set_status(u, "psn", t, false)
				"flame-body":
					_set_status(u, "brn", t, false)
				"effect-spore":
					if not has_type(u, "grass") and ua != "overcoat" and it(u) != "safety-goggles":
						_set_status(u, ["psn", "par", "slp"][randi() % 3], t, false)
				"cute-charm":
					_attract(u, t, false)
		if it(t) == "rocky-helmet" and u.mon.hp > 0:
			msg("%s est blessé par le Casque Brut de %s !" % [nm(u), nm(t)])
			_hurt(u, u.mon.max_hp() / 6)
		if it(t) == "sticky-barb" and u.item == "" and u.mon.hp > 0:
			u.item = t.item
			t.item = ""
			msg("Le Piquant s'accroche à %s !" % nm(u))
	if t.mon.hp > 0:
		if ua == "poison-touch" and randi() % 10 < 3:
			_set_status(t, "psn", u, false)
		if ta == "pickpocket" and t.item == "" and u.item != "" and not _item_locked(u) and u.mon.hp > 0:
			t.item = u.item
			u.item = ""
			msg("%s vole %s de %s !" % [nm(t), Data.item_name(t.item), nm(u)])


## Réactions du défenseur à chaque coup (talents, objets, baies).
func _after_hit(u: Battler, t: Battler, m: Dictionary, typ: String, eff: float, dmg: int) -> void:
	var ta := ab(t)
	if t.mon.hp > 0:
		match ta:
			"weak-armor":
				if m["cat"] == "physical":
					_stage(t, "def", -1, t)
					_stage(t, "spe", 2, t)
			"stamina":
				_stage(t, "def", 1, t)
			"justified":
				if typ == "dark":
					_stage(t, "atk", 1, t)
			"rattled":
				if typ in ["bug", "ghost", "dark"]:
					_stage(t, "spe", 1, t)
			"water-compaction":
				if typ == "water":
					_stage(t, "def", 2, t)
			"steam-engine":
				if typ in ["fire", "water"]:
					_stage(t, "spe", 6, t)
			"thermal-exchange":
				if typ == "fire":
					_stage(t, "atk", 1, t)
			"color-change":
				if not has_type(t, typ) and typ != "":
					t.types = [typ]
					msg("%s devient du type %s !" % [nm(t), Data.type_name(typ)])
			"cotton-down":
				for o: Battler in _on_field():
					if o != t:
						_stage(o, "spe", -1, t)
			"sand-spit":
				_set_weather("sandstorm", t)
			"seed-sower":
				_set_terrain("grassy", t)
			"electromorphosis", "wind-power":
				if ta == "electromorphosis" or has_flag(m, "wind"):
					t.charged = true
					msg("%s se charge en électricité !" % nm(t))
			"toxic-debris":
				if m["cat"] == "physical" and sides[u.side].toxic_spikes < 2:
					sides[u.side].toxic_spikes += 1
					msg("Des pics toxiques se répandent autour de l'équipe adverse !")
			"berserk", "anger-shell":
				var before := float(t.mon.hp + dmg) / t.mon.max_hp()
				if before > 0.5 and t.hp_frac() <= 0.5:
					if ta == "berserk":
						_stage(t, "spa", 1, t)
					else:
						_stage(t, "def", -1, t)
						_stage(t, "spd", -1, t)
						_stage(t, "atk", 1, t)
						_stage(t, "spa", 1, t)
						_stage(t, "spe", 1, t)
			"cursed-body":
				if u.disable_turns == 0 and randi() % 10 < 3 and u != t:
					u.disable_move = m["id"]
					u.disable_turns = 4
					msg("Corps Maudit : %s de %s est bloqué !" % [m["name"], nm(u)])
			"gulp-missile":
				pass
		_check_forms(t)
		# Objets du défenseur.
		var item := it(t)
		match item:
			"weakness-policy":
				if eff > 1.0:
					_consume(t)
					msg("%s active sa Vulné-Assurance !" % nm(t))
					_stage(t, "atk", 2, t)
					_stage(t, "spa", 2, t)
			"absorb-bulb":
				if typ == "water":
					_consume(t)
					_stage(t, "spa", 1, t)
			"cell-battery":
				if typ == "electric":
					_consume(t)
					_stage(t, "atk", 1, t)
			"luminous-moss":
				if typ == "water":
					_consume(t)
					_stage(t, "spd", 1, t)
			"snowball":
				if typ == "ice":
					_consume(t)
					_stage(t, "atk", 1, t)
			"kee-berry":
				if m["cat"] == "physical" and _can_eat(t):
					_consume(t, true)
					_stage(t, "def", 1, t)
			"maranga-berry":
				if m["cat"] == "special" and _can_eat(t):
					_consume(t, true)
					_stage(t, "spd", 1, t)
			"enigma-berry":
				if eff > 1.0 and _can_eat(t):
					_consume(t, true)
					_heal(t, t.mon.max_hp() / 4)
			"air-balloon":
				_consume(t)
				msg("Le Ballon de %s éclate !" % nm(t))
		if item in ["jaboca-berry", "rowap-berry"] and _can_eat(t) and u.mon.hp > 0:
			if (item == "jaboca-berry" and m["cat"] == "physical") or (item == "rowap-berry" and m["cat"] == "special"):
				_consume(t, true)
				msg("%s est blessé par la %s de %s !" % [nm(u), Data.item_name(item), nm(t)])
				_hurt(u, u.mon.max_hp() / 8)
		_check_hp_items(t)
	else:
		# K.O. : Boom Final, Expulsion.
		if ta == "aftermath" and has_flag(m, "contact") and u.mon.hp > 0:
			msg("%s est blessé par Boom Final !" % nm(u))
			_hurt(u, u.mon.max_hp() / 4)
		if ta == "innards-out" and u.mon.hp > 0:
			msg("%s est blessé par Expuls'Organes !" % nm(u))
			_hurt(u, dmg)


func _after_damage(u: Battler, t: Battler, m: Dictionary, typ: String, total: int, landed: int, subst_hit: bool, sheer: bool, eff: float) -> void:
	var ident: String = m["ident"]
	# Vol de vie, contrecoup.
	var drain: int = m.get("drain", 0)
	if total > 0 and drain > 0 and u.mon.hp > 0:
		var amount := maxi(1, int(total * drain / 100))
		if it(u) == "big-root":
			amount = int(amount * 1.3)
		if dab(u, t) == "liquid-ooze":
			msg("%s aspire le Suintement !" % nm(u))
			_hurt(u, amount)
		elif u.mon.hp < u.mon.max_hp() and u.heal_block == 0:
			msg("L'énergie de %s est drainée !" % nm(t))
			_heal(u, amount)
	elif total > 0 and (drain < 0 or m["id"] == STRUGGLE):
		if m["id"] == STRUGGLE:
			msg("%s est blessé par le contrecoup !" % nm(u))
			_hurt(u, maxi(1, u.mon.max_hp() / 4))
		elif ab(u) not in ["rock-head", "magic-guard"]:
			var recoil := maxi(1, int(total * -drain / 100))
			msg("%s est blessé par le contrecoup !" % nm(u))
			u.mon.count("recoil", recoil)
			_hurt(u, recoil)
	if ident in ["steel-beam", "mind-blown", "chloroblast"] and u.mon.hp > 0 and ab(u) != "magic-guard":
		msg("%s perd des PV !" % nm(u))
		_hurt(u, (u.mon.max_hp() + 1) / 2)
	if ident in ["self-destruct", "explosion", "misty-explosion", "final-gambit"] and u.mon.hp > 0:
		u.mon.hp = 0
		hp_event(u)
		_faint(u)
	# Objets de l'attaquant après les dégâts.
	var item := it(u)
	if total > 0 and u.mon.hp > 0:
		if item == "life-orb" and ab(u) != "magic-guard" and not sheer:
			msg("%s perd des PV à cause de l'Orbe Vie !" % nm(u))
			_hurt(u, maxi(1, u.mon.max_hp() / 10))
		if item == "shell-bell" and u.mon.hp < u.mon.max_hp():
			msg("%s récupère des PV grâce au Grelot Coque !" % nm(u))
			_heal(u, maxi(1, total / 8))
		if item == "throat-spray" and has_flag(m, "sound"):
			_consume(u)
			_stage(u, "spa", 1, u)
	if landed > 0 and item in ["kings-rock", "razor-fang"] and m.get("flinch", 0) == 0 and not t.moved and t.mon.hp > 0 and randi() % 10 == 0:
		t.flinch = true
	if item == "metronome":
		if u.last_move == m["id"]:
			u.mon.count("metronome_n")
		else:
			u.mon.counters["metronome_n"] = 0
	# Effets propres à certaines capacités.
	match ident:
		"hyper-beam", "giga-impact", "blast-burn", "hydro-cannon", "frenzy-plant", "rock-wrecker", "roar-of-time",\
				"prismatic-laser", "eternabeam", "meteor-assault":
			if u.mon.hp > 0:
				u.recharge = true
		"pay-day":
			pay_day += 5 * u.mon.level
			msg("Des pièces tombent partout !")
		"make-it-rain":
			pay_day += 5 * u.mon.level
			msg("Une pluie de pièces s'abat !")
		"rapid-spin", "mortal-spin":
			var us: BSide = sides[u.side]
			if u.seeded or u.trap_turns > 0 or us.spikes > 0 or us.stealth_rock or us.toxic_spikes > 0 or us.sticky_web:
				msg("%s se libère !" % nm(u))
			u.seeded = false
			u.trap_turns = 0
			us.spikes = 0
			us.stealth_rock = false
			us.toxic_spikes = 0
			us.sticky_web = false
			if ident == "rapid-spin":
				_stage(u, "spe", 1, u)
		"brick-break", "psychic-fangs", "raging-bull":
			var ts: BSide = sides[t.side]
			if ts.reflect > 0 or ts.light_screen > 0 or ts.aurora_veil > 0:
				ts.reflect = 0
				ts.light_screen = 0
				ts.aurora_veil = 0
				msg("Les protections adverses volent en éclats !")
		"knock-off":
			if t.item != "" and not _item_locked(t) and t.mon.hp >= 0 and dab(u, t) != "sticky-hold":
				msg("%s fait tomber %s de %s !" % [nm(u), Data.item_name(t.item), nm(t)])
				t.mon.counters["knocked"] = t.item
				t.item = ""
				_unburden(t)
		"thief", "covet":
			if u.item == "" and t.item != "" and not _item_locked(t) and dab(u, t) != "sticky-hold" and u.mon.hp > 0:
				u.item = t.item
				t.item = ""
				msg("%s vole %s de %s !" % [nm(u), Data.item_name(u.item), nm(t)])
				_unburden(t)
		"bug-bite", "pluck":
			if Data.items.get(t.item, {}).get("berry", false) and dab(u, t) != "sticky-hold":
				var berry := t.item
				t.item = ""
				msg("%s mange la %s de %s !" % [nm(u), Data.item_name(berry), nm(t)])
				_eat_berry(u, berry)
		"incinerate":
			if Data.items.get(t.item, {}).get("berry", false) or t.item.ends_with("-gem"):
				msg("La %s de %s brûle !" % [Data.item_name(t.item), nm(t)])
				t.item = ""
		"smack-down", "thousand-arrows":
			if t.mon.hp > 0 and not grounded(t):
				t.grounded = true
				t.magnet_rise = 0
				t.telekinesis = 0
				msg("%s tombe au sol !" % nm(t))
		"spirit-shackle", "anchor-shot", "thousand-waves", "jaw-lock":
			if t.mon.hp > 0 and not has_type(t, "ghost"):
				t.mean_look = true
				if ident == "jaw-lock":
					u.mean_look = true
		"clear-smog":
			if t.mon.hp > 0:
				for k in t.stages:
					t.stages[k] = 0
				msg("Les changements de stats de %s sont annulés !" % nm(t))
		"sparkling-aria":
			if t.mon.status == "brn":
				t.mon.status = ""
				refresh()
				msg("%s n'est plus brûlé !" % nm(t))
		"stone-axe":
			if not sides[t.side].stealth_rock:
				sides[t.side].stealth_rock = true
				msg("Des pierres pointues flottent autour de l'équipe adverse !")
		"ceaseless-edge":
			if sides[t.side].spikes < 3:
				sides[t.side].spikes += 1
				msg("Des picots sont dispersés autour de l'équipe adverse !")
		"ice-spinner", "steel-roller":
			if terrain != "":
				terrain = ""
				terrain_turns = 0
				msg("Le champ disparaît !")
				events.append({"t": "terrain", "terrain": ""})
		"salt-cure":
			if t.mon.hp > 0 and not t.salt_cure:
				t.salt_cure = true
				msg("%s est couvert de sel !" % nm(t))
		"glaive-rush":
			u.glaive = true
		"double-shock":
			u.types.erase("electric")
			if u.types.is_empty():
				u.types = ["normal"]
			msg("%s a utilisé toute son électricité !" % nm(u))
		"burn-up":
			u.types.erase("fire")
			if u.types.is_empty():
				u.types = ["normal"]
			msg("%s a utilisé tout son feu !" % nm(u))
		"fell-stinger":
			if t.mon.hp <= 0:
				_stage(u, "atk", 3, u)
		"relic-song":
			if u.mon.species == 648:
				var pid := form_pid(648, "pirouette") if u.form_id == 0 else 648
				set_form(u, pid, true)
		"natural-gift", "fling":
			if u.item != "":
				var it2 := u.item
				_consume(u, ident == "natural-gift")
				if ident == "fling" and t.mon.hp > 0:
					_fling_effect(u, t, it2)
		"u-turn", "volt-switch", "flip-turn":
			if u.mon.hp > 0 and not over:
				_pivot(u)
		"dragon-tail", "circle-throw":
			if t.mon.hp > 0 and not subst_hit:
				_force_switch(u, t)
		"uproar":
			if u.uproar == 0:
				u.uproar = 3
				msg("%s fait un BROUHAHA !" % nm(u))
				for ob: Battler in actives():
					if ob.mon.status == "slp":
						ob.mon.status = ""
						msg("%s se réveille !" % nm(ob))
		"spit-up":
			u.stockpile = 0
			_stage(u, "def", -u.stock_def, u)
			_stage(u, "spd", -u.stock_spd, u)
			u.stock_def = 0
			u.stock_spd = 0
		"genesis-supernova":
			_set_terrain("psychic", u)
		"stoked-sparksurfer":
			if t.mon.hp > 0:
				_set_status(t, "par", u, false)
		"extreme-evoboost":
			for k in ["atk", "def", "spa", "spd", "spe"]:
				_stage(u, k, 2, u)
		"splintered-stormshards":
			terrain = ""
		"alluring-voice":
			if t.raised_turn and t.mon.hp > 0:
				_confuse(t, u, false)
		"burning-jealousy":
			if t.raised_turn and t.mon.hp > 0:
				_set_status(t, "brn", u, false)
		"psychic-noise":
			if t.mon.hp > 0 and t.heal_block == 0:
				t.heal_block = 2
				msg("%s ne peut plus se soigner !" % nm(t))
		"throat-chop":
			if t.mon.hp > 0:
				t.throat_chop = 2
		"order-up":
			_stage(u, "atk", 1, u)
		"spectral-thief":
			pass
		"core-enforcer":
			if t.moved and t.mon.hp > 0:
				t.suppressed = true
				msg("Le talent de %s est neutralisé !" % nm(t))
		"sky-drop":
			pass
	if ident in RAMPAGE and u.rampage == 0:
		u.rampage = randi_range(2, 3)
		u.rampage_move = m["id"]
	if ident in ["rollout", "ice-ball"]:
		u.rollout -= 1
	if ident == "rage":
		u.rage = true
	# Effets secondaires (Sans Limite les supprime, Écran Poudre et Cape Furtive les bloquent).
	if landed > 0 and not subst_hit and t.mon.hp > 0 and not sheer:
		_secondary(u, t, m)
	if landed > 0 and m.get("mcat", 0) == 7 and u.mon.hp > 0 and not (sheer and m.get("stat_ch", 100) < 100):
		var ch: int = m["stat_ch"] if m["stat_ch"] > 0 else 100
		if randi() % 100 < _chance(u, ch):
			for sc in m["stats"]:
				_stage(u, STAGE_KEYS[sc[0] - 1], sc[1], u)
	if ident == "flame-wheel" and u.mon.status == "frz":
		u.mon.status = ""
	if t.mon.hp <= 0:
		_faint(t)
		_on_ko(u, t, m)
	_check_hp_items(u)


## Talents et effets qui se déclenchent quand on met un adversaire K.O.
func _on_ko(u: Battler, t: Battler, m: Dictionary) -> void:
	if t.destiny_bond and u.mon.hp > 0 and u.side != t.side:
		msg("%s entraîne %s avec lui !" % [nm(t), nm(u)])
		u.mon.hp = 0
		hp_event(u)
		_faint(u)
	if t.grudge:
		for mv in u.moves():
			if mv["id"] == m["id"]:
				mv["pp"] = 0
				msg("%s perd tous les PP de %s à cause de la Rancune !" % [nm(u), m["name"]])
	if u.mon.hp <= 0:
		return
	if t.mon.species == 625 and u.mon.species == 625:
		u.mon.count("bisharp")
	match ab(u):
		"moxie", "chilling-neigh", "as-one-glastrier":
			_stage(u, "atk", 1, u)
		"grim-neigh", "as-one-spectrier":
			_stage(u, "spa", 1, u)
		"beast-boost":
			var best := "atk"
			var bv := -1.0
			for k in ["atk", "def", "spa", "spd", "spe"]:
				var v := float(u.raw(STAT_INDEX[k]))
				if v > bv:
					bv = v
					best = k
			_stage(u, best, 1, u)
		"battle-bond":
			if u.mon.species == 658 and not u.mega:
				_stage(u, "atk", 1, u)
				_stage(u, "spa", 1, u)
				_stage(u, "spe", 1, u)
	if ally(t) != null and ab(ally(t)) in ["receiver", "power-of-alchemy"] and Data.ability_ident(t.ability) not in UNCOPYABLE:
		ally(t).ability = t.ability


## Demi-Tour, Change Éclair, Volte-Face : le lanceur revient (le joueur choisit le remplaçant).
func _pivot(u: Battler) -> void:
	var options := bench(u.side, u.owner)
	if options.is_empty() or (u.side == 1 and wild):
		return
	if u.side == 0:
		msg("%s revient vers %s !" % [nm(u), owner_name(0, u.owner)])
		need_switch.append({"slot": u.slot, "owner": u.owner, "baton": false, "pivot": true})
	else:
		var idx := _ai_next(u.owner)
		if idx < 0:
			idx = options[0]
		msg("%s revient vers %s !" % [nm(u), owner_name(1, u.owner)])
		events.append({"t": "recall", "side": 1, "slot": u.slot})
		_switch_out(u)
		_send(1, u.slot, idx)
		_entry_ability(sides[1].slots[u.slot])
		_entry_item(sides[1].slots[u.slot])


func _end_rollout(u: Battler) -> void:
	u.rollout = 0
	u.rampage = 0
	u.fury_cutter = 0


func _chance(u: Battler, c: int) -> int:
	return c * 2 if ab(u) == "serene-grace" else c


func _secondary(u: Battler, t: Battler, m: Dictionary) -> void:
	if (dab(u, t) == "shield-dust" or it(t) == "covert-cloak") and t != u:
		return
	var ident: String = m["ident"]
	if ident == "tri-attack":
		if randi() % 100 < _chance(u, 20):
			_set_status(t, ["par", "brn", "frz"][randi() % 3], u, false)
		return
	if ident == "dire-claw":
		if randi() % 100 < _chance(u, 50):
			_set_status(t, ["psn", "par", "slp"][randi() % 3], u, false)
		return
	if ident == "secret-power":
		if randi() % 100 < _chance(u, 30):
			_set_status(t, "par", u, false)
		return
	if m.get("ail", "none") != "none" and m.get("ail_ch", 0) > 0 and randi() % 100 < _chance(u, m["ail_ch"]):
		_ailment(u, t, m["ail"], false, ident)
	if m.get("flinch", 0) > 0 and not t.moved and dab(u, t) != "inner-focus" and randi() % 100 < _chance(u, m["flinch"]):
		t.flinch = true
	elif ab(u) == "stench" and not t.moved and randi() % 10 == 0:
		t.flinch = true
	if ab(u) == "toxic-chain" and randi() % 10 < 3:
		_set_status(t, "tox", u, false)
	if m.get("mcat", 0) == 6:
		var ch: int = m["stat_ch"] if m["stat_ch"] > 0 else 100
		if randi() % 100 < _chance(u, ch):
			for sc in m["stats"]:
				_stage(t, STAGE_KEYS[sc[0] - 1], sc[1], u)


## Dégommage : effet de l'objet lancé.
func _fling_effect(u: Battler, t: Battler, item: String) -> void:
	match item:
		"flame-orb":
			_set_status(t, "brn", u, false)
		"toxic-orb":
			_set_status(t, "tox", u, false)
		"light-ball":
			_set_status(t, "par", u, false)
		"poison-barb":
			_set_status(t, "psn", u, false)
		"kings-rock", "razor-fang":
			if not t.moved:
				t.flinch = true
		"white-herb":
			for k in t.stages:
				t.stages[k] = maxi(0, t.stages[k])
		"mental-herb":
			t.attract = false
			t.taunt = 0
			t.encore_turns = 0
	if Data.items.get(item, {}).get("berry", false):
		_eat_berry(t, item)


func _ohko(u: Battler, t: Battler, m: Dictionary) -> void:
	if t.mon.level > u.mon.level or (m["ident"] == "sheer-cold" and has_type(t, "ice")):
		_fail()
		return
	if Data.effectiveness(m["type"], all_types(t)) == 0.0 or (m["type"] == "ground" and not grounded(t)):
		msg("Ça n'affecte pas %s..." % nm(t))
		return
	if dab(u, t) == "sturdy" or t.mon.boss:
		msg("%s ne peut pas être mis K.O. en un coup !" % nm(t))
		return
	var acc := 30 + u.mon.level - t.mon.level
	if m["ident"] == "sheer-cold" and not has_type(u, "ice"):
		acc -= 10
	if ab(u) != "no-guard" and dab(u, t) != "no-guard" and randi() % 100 >= acc and not always_hit:
		msg("%s évite l'attaque !" % nm(t))
		return
	move_anim(u, t, m)
	anim(t, "hit")
	t.mon.hp = 0
	hp_event(t)
	msg("K.O. en un coup !")
	_faint(t)


# ---------------------------------------------------------------------------
# Capacités de statut
# ---------------------------------------------------------------------------

func _status_move(u: Battler, t: Battler, m: Dictionary) -> void:
	var on_foe := _targets_foe(m)
	var ident: String = m["ident"]
	u.used_moves.append(m["id"])
	if m.get("z_status", false):
		_z_status_bonus(u, m)
	if on_foe:
		if t == null or t.mon.hp <= 0:
			_fail()
			u.last_failed = true
			return
		if _absorb(u, t, m["type"], m):
			return
		if not _hits(u, t, m):
			msg("%s évite l'attaque !" % nm(t))
			u.last_failed = true
			return
		if t.substitute > 0 and t != u and not has_flag(m, "sound") and not has_flag(m, "authentic") and ab(u) != "infiltrator" \
				and ident not in ["roar", "whirlwind", "haze", "perish-song", "curse", "transform", "sketch", "play-nice"]:
			_fail()
			u.last_failed = true
			return
	move_anim(u, t if on_foe else u, m)
	match m.get("mcat", 0):
		1:
			var target := u if not on_foe else t
			if ident in ["thunder-wave"] and Data.effectiveness("electric", all_types(t)) == 0.0:
				msg("Ça n'affecte pas %s..." % nm(t))
				u.last_failed = true
				return
			if ident == "will-o-wisp" and has_type(t, "fire"):
				msg("Ça n'affecte pas %s..." % nm(t))
				u.last_failed = true
				return
			if not _ailment(u, target, m["ail"], true, ident):
				u.last_failed = true
				return
		2:
			var target2 := t if on_foe else u
			if m["target"] in ["user-and-allies", "all-allies"]:
				for al: Battler in actives(u.side):
					for sc in m["stats"]:
						_stage(al, STAGE_KEYS[sc[0] - 1], sc[1], u)
				return
			var any := false
			for sc in m["stats"]:
				if _stage(target2, STAGE_KEYS[sc[0] - 1], sc[1], u):
					any = true
			if not any and m["stats"].size() > 0:
				u.last_failed = true
			match ident:
				"minimize":
					u.minimized = true
				"defense-curl":
					u.curled = true
				"charge":
					u.charged = true
					msg("%s se charge en électricité !" % nm(u))
				"autotomize":
					msg("%s s'allège !" % nm(u))
				"take-heart":
					if u.mon.status != "":
						u.mon.status = ""
						refresh()
				"no-retreat":
					u.no_retreat = true
				"stuff-cheeks":
					if Data.items.get(u.item, {}).get("berry", false):
						var berry := u.item
						_consume(u, true)
						_eat_berry(u, berry)
		3:
			_heal_move(u, m)
		5:
			for sc in m["stats"]:
				_stage(t, STAGE_KEYS[sc[0] - 1], sc[1], u)
			if ident == "tar-shot":
				t.tar_shot = true
				msg("%s est couvert de goudron !" % nm(t))
			elif ident == "toxic-thread":
				_set_status(t, "psn", u, true)
			else:
				_confuse(t, u, false)
		10:
			_field_move(u, m)
		11:
			_side_move(u, m)
		12:
			_force_switch(u, t)
		_:
			if m["stats"].size() > 0:
				for sc in m["stats"]:
					_stage(t if on_foe else u, STAGE_KEYS[sc[0] - 1], sc[1], u)
			else:
				_fail()
				u.last_failed = true


## Capacité Z de statut : bonus avant l'effet (version simplifiée de la table officielle).
func _z_status_bonus(u: Battler, m: Dictionary) -> void:
	var ident: String = m["ident"]
	if ident in ["curse"] and has_type(u, "ghost") or has_flag(m, "heal") or ident in ["memento", "parting-shot"]:
		msg("%s récupère ses PV grâce à la puissance Z !" % nm(u))
		_heal(u, u.mon.max_hp())
		return
	for k in u.stages:
		if u.stages[k] < 0:
			u.stages[k] = 0
	var best := "atk" if stat_value(u, 1) >= stat_value(u, 3) else "spa"
	_stage(u, best, 1, u)


func _heal_move(u: Battler, m: Dictionary) -> void:
	var ident: String = m["ident"]
	var target := u
	if ident in ["heal-pulse", "floral-healing"] or m["target"] in ["selected-pokemon", "all-opponents"]:
		var tgt: Battler = _chosen_target(u, actions.get(u, {}))
		if tgt != null:
			target = tgt
	if ident in ["life-dew", "jungle-healing", "lunar-blessing"]:
		for al: Battler in actives(u.side):
			if al.mon.hp < al.mon.max_hp():
				_heal(al, al.mon.max_hp() / 4)
				msg("%s récupère des PV !" % nm(al))
			if ident != "life-dew" and al.mon.status != "":
				al.mon.status = ""
				refresh()
		return
	if target.mon.hp >= target.mon.max_hp():
		msg("Les PV de %s sont au maximum !" % nm(target))
		u.last_failed = true
		return
	var frac := 0.5
	if ident in ["synthesis", "moonlight", "morning-sun"]:
		var w := weather_for(u)
		frac = 2.0 / 3.0 if w in ["sun", "harsh-sun"] else 0.25 if w != "" else 0.5
	elif ident == "shore-up":
		frac = 2.0 / 3.0 if weather_on() == "sandstorm" else 0.5
	elif ident == "floral-healing":
		frac = 2.0 / 3.0 if terrain == "grassy" else 0.5
	elif ident == "heal-pulse" and ab(u) == "mega-launcher":
		frac = 0.75
	elif ident == "swallow":
		if u.stockpile == 0:
			_fail()
			return
		frac = [0.25, 0.5, 1.0][u.stockpile - 1]
		u.stockpile = 0
		_stage(u, "def", -u.stock_def, u)
		_stage(u, "spd", -u.stock_spd, u)
		u.stock_def = 0
		u.stock_spd = 0
	_heal(target, maxi(1, int(target.mon.max_hp() * frac)))
	msg("%s récupère des PV !" % nm(target))
	if ident == "roost" and has_type(u, "flying"):
		u.types.erase("flying")
		if u.types.is_empty():
			u.types = ["normal"]
		u.mon.counters["roost"] = true


func _field_move(u: Battler, m: Dictionary) -> void:
	var ident: String = m["ident"]
	match ident:
		"haze":
			for ob: Battler in actives():
				for k in ob.stages:
					ob.stages[k] = 0
			msg("Les changements de stats sont annulés !")
		"rain-dance", "sunny-day", "sandstorm", "hail", "snowscape", "chilly-reception":
			var w: String = {"rain-dance": "rain", "sunny-day": "sun", "sandstorm": "sandstorm", "hail": "snow", "snowscape": "snow",
				"chilly-reception": "snow"}[ident]
			if not _set_weather(w, u):
				_fail()
				u.last_failed = true
		"electric-terrain", "grassy-terrain", "misty-terrain", "psychic-terrain":
			if not _set_terrain(ident.split("-")[0], u):
				_fail()
				u.last_failed = true
		"trick-room":
			trick_room = 0 if trick_room > 0 else 5
			msg("%s tord l'espace-temps !" % nm(u) if trick_room > 0 else "L'espace-temps redevient normal !")
			for b: Battler in _on_field():
				if trick_room > 0 and it(b) == "room-service":
					_consume(b)
					_stage(b, "spe", -1, b)
		"wonder-room":
			wonder_room = 0 if wonder_room > 0 else 5
			msg("La Défense et la Défense Spéciale sont échangées !" if wonder_room > 0 else "La Zone Étrange disparaît.")
		"magic-room":
			magic_room = 0 if magic_room > 0 else 5
			msg("Les objets tenus n'ont plus d'effet !" if magic_room > 0 else "La Zone Magique disparaît.")
		"gravity":
			if gravity > 0:
				_fail()
				return
			gravity = 5
			msg("La gravité s'intensifie !")
			for b: Battler in _on_field():
				if b.invuln in ["fly", "bounce", "sky-drop"]:
					b.invuln = ""
					b.charging = 0
					events.append({"t": "hide", "side": b.side, "slot": b.slot, "on": false})
				b.magnet_rise = 0
				b.telekinesis = 0
		"mud-sport":
			mud_sport = 5
			msg("Les attaques Électrik sont affaiblies !")
		"water-sport":
			water_sport = 5
			msg("Les attaques Feu sont affaiblies !")
		"fairy-lock":
			fairy_lock = 2
			msg("Plus personne ne peut fuir au prochain tour !")
		"ion-deluge":
			ion_deluge = true
			msg("Une pluie de particules électriques s'abat !")
		"perish-song":
			for ob: Battler in actives():
				if ob.perish == 0 and ab(ob) != "soundproof":
					ob.perish = 4
			msg("Tous les Pokémon entendant ce chant seront K.O. dans 3 tours !")
		"flower-shield", "rototiller":
			for ob: Battler in actives():
				if has_type(ob, "grass") and (ident == "flower-shield" or grounded(ob)):
					if ident == "flower-shield":
						_stage(ob, "def", 1, u)
					else:
						_stage(ob, "atk", 1, u)
						_stage(ob, "spa", 1, u)
		"court-change":
			var a: BSide = sides[0]
			var b: BSide = sides[1]
			for key in ["reflect", "light_screen", "aurora_veil", "mist", "safeguard", "tailwind", "spikes", "toxic_spikes", "stealth_rock", "sticky_web"]:
				var tmp = a.get(key)
				a.set(key, b.get(key))
				b.set(key, tmp)
			msg("%s échange les effets de terrain !" % nm(u))
		_:
			_fail()
			u.last_failed = true
	field_event()


func _side_move(u: Battler, m: Dictionary) -> void:
	var s: BSide = sides[u.side]
	var o: BSide = sides[1 - u.side]
	var clay := it(u) == "light-clay"
	match m["ident"]:
		"reflect":
			if s.reflect > 0:
				_fail()
				return
			s.reflect = 8 if clay else 5
			msg("Protection augmente la Défense de l'équipe !")
		"light-screen":
			if s.light_screen > 0:
				_fail()
				return
			s.light_screen = 8 if clay else 5
			msg("Mur Lumière augmente la Défense Spéciale de l'équipe !")
		"aurora-veil":
			if s.aurora_veil > 0 or weather_on() not in ["hail", "snow"]:
				_fail()
				return
			s.aurora_veil = 8 if clay else 5
			msg("Le Voile Aurore protège l'équipe !")
		"mist":
			if s.mist > 0:
				_fail()
				return
			s.mist = 5
			msg("L'équipe est entourée de brume !")
		"safeguard":
			if s.safeguard > 0:
				_fail()
				return
			s.safeguard = 5
			msg("L'équipe est protégée par un voile mystique !")
		"tailwind":
			if s.tailwind > 0:
				_fail()
				return
			s.tailwind = 4
			msg("Un vent arrière souffle derrière l'équipe !")
			for al: Battler in actives(u.side):
				if ab(al) == "wind-rider":
					_stage(al, "atk", 1, al)
		"lucky-chant":
			s.lucky_chant = 5
			msg("L'équipe est protégée des coups critiques !")
		"spikes":
			if o.spikes >= 3:
				_fail()
				return
			o.spikes += 1
			msg("Des picots sont dispersés autour de l'équipe adverse !")
		"toxic-spikes":
			if o.toxic_spikes >= 2:
				_fail()
				return
			o.toxic_spikes += 1
			msg("Des pics toxiques sont dispersés autour de l'équipe adverse !")
		"stealth-rock":
			if o.stealth_rock:
				_fail()
				return
			o.stealth_rock = true
			msg("Des pierres pointues flottent autour de l'équipe adverse !")
		"sticky-web":
			if o.sticky_web:
				_fail()
				return
			o.sticky_web = true
			msg("Une toile gluante s'étend sous l'équipe adverse !")
		"wide-guard":
			s.wide_guard = true
			msg("La Garde Large protège l'équipe !")
		"quick-guard":
			s.quick_guard = true
			msg("Prévention protège l'équipe !")
		"crafty-shield":
			s.crafty_shield = true
			msg("Vigilance protège l'équipe !")
		_:
			_fail()
	field_event()


func _force_switch(u: Battler, t: Battler) -> void:
	if dab(u, t) == "suction-cups" or t.ingrain or t.mon.boss:
		_fail()
		return
	if dab(u, t) == "guard-dog":
		_fail()
		return
	if wild:
		if is_double() or t.side == 0:
			_fail()
			return
		msg("%s est emporté au loin !" % nm(t))
		over = true
		result = "run"
		events.append({"t": "end", "result": "run"})
		return
	var options := bench(t.side, t.owner)
	if options.is_empty():
		return
	var idx: int = options[randi() % options.size()]
	events.append({"t": "recall", "side": t.side, "slot": t.slot})
	_switch_out(t)
	_send(t.side, t.slot, idx, false)
	msg("%s est envoyé au combat !" % sides[t.side].party[idx].name())
	_entry_ability(sides[t.side].slots[t.slot])
	_entry_item(sides[t.side].slots[t.slot])


## Protections : Abri, Détection, Bouclier Royal, Pico-Défense, Blockhaus, Barricade...
func _protect(u: Battler, kind: String) -> bool:
	var t := foe(u)
	var last := true
	for o: Battler in _on_field():
		if o != u and not o.moved:
			last = false
	if last and _on_field().size() > 1:
		_fail()
		u.protect_chain = 0
		return false
	if randi() % int(pow(3, mini(u.protect_chain, 6))) != 0:
		_fail()
		u.protect_chain = 0
		return false
	u.protect_chain += 1
	if kind == "endure":
		u.endure = true
		msg("%s se prépare à encaisser !" % nm(u))
	else:
		u.protected = true
		u.protect_kind = kind
		msg("%s se protège !" % nm(u))
	return true


## Morphing (et Imposteur).
func _transform(u: Battler, t: Battler) -> void:
	u.transformed = true
	u.types = all_types(t).duplicate()
	u.t_stats = [u.mon.stats[0], t.raw(1), t.raw(2), t.raw(3), t.raw(4), t.raw(5)]
	u.stages = t.stages.duplicate()
	u.ability = t.ability
	u.t_moves = []
	for mv in t.moves():
		u.t_moves.append({"id": mv["id"], "pp": 5, "max": 5, "ups": 0})
	events.append({"t": "transform", "side": u.side, "slot": u.slot, "species": t.sprite_id(), "shiny": t.mon.shiny})
	msg("%s se transforme en %s !" % [nm(u), t.mon.data()["name"]])


## Capacités au fonctionnement unique. Renvoie true si l'effet a été entièrement géré ici.
func _special_move(u: Battler, t: Battler, m: Dictionary) -> bool:
	var ident: String = m["ident"]
	match ident:
		"splash", "celebrate", "hold-hands", "happy-hour":
			msg("Mais rien ne se passe !" if ident == "splash" else "Quelle ambiance !")
		"teleport":
			if wild and not trapped(u) and u.side == 0 or wild and u.side == 1 and not is_double():
				msg("%s se téléporte !" % nm(u))
				over = true
				result = "run"
				events.append({"t": "end", "result": "run"})
			elif not wild:
				_pivot(u)
			else:
				_fail()
		"protect", "detect", "endure", "kings-shield", "spiky-shield", "baneful-bunker", "obstruct", "silk-trap", "burning-bulwark":
			_protect(u, "endure" if ident == "endure" else ident)
		"rest":
			if u.mon.hp >= u.mon.max_hp() or ab(u) in ["insomnia", "vital-spirit", "comatose", "sweet-veil"] or (terrain in ["electric", "misty"] and grounded(u)):
				_fail()
				return true
			u.mon.status = "slp"
			u.mon.sleep_turns = 3
			u.mon.counters.erase("foe_sleep")
			u.mon.hp = u.mon.max_hp()
			hp_event(u)
			refresh()
			msg("%s dort et récupère tous ses PV !" % nm(u))
			_check_hp_items(u)
		"substitute":
			var cost := u.mon.max_hp() / 4
			if u.substitute > 0 or u.mon.hp <= cost:
				_fail()
				return true
			u.mon.hp -= cost
			hp_event(u)
			u.substitute = cost + 1
			events.append({"t": "sub", "side": u.side, "slot": u.slot, "on": true})
			msg("%s crée un clone !" % nm(u))
		"shed-tail":
			var cost2 := (u.mon.max_hp() + 1) / 2
			if u.substitute > 0 or u.mon.hp <= cost2 or bench(u.side, u.owner).is_empty():
				_fail()
				return true
			u.mon.hp -= cost2
			hp_event(u)
			msg("%s se sépare de sa queue et crée un clone !" % nm(u))
			u.mon.counters["shed_tail"] = cost2 + 1
			_baton(u)
		"focus-energy":
			if u.focus_energy:
				_fail()
				return true
			u.focus_energy = true
			msg("%s se concentre !" % nm(u))
		"dragon-cheer":
			var al := ally(u)
			if al == null:
				_fail()
				return true
			al.crit_bonus += 2 if has_type(al, "dragon") else 1
			msg("%s encourage %s !" % [nm(u), nm(al)])
		"laser-focus":
			u.laser_focus = 2
			msg("%s se concentre intensément !" % nm(u))
		"disable":
			if t.last_move == 0 or t.disable_turns > 0 or not _hits(u, t, m) or dab(u, t) == "aroma-veil":
				_fail()
				return true
			t.disable_move = t.last_move
			t.disable_turns = 4
			msg("%s de %s est bloqué !" % [Data.move_name(t.last_move), nm(t)])
		"mimic", "sketch":
			if t.last_move == 0 or t.last_move in [STRUGGLE, 102, 118, 166] or u.moves().any(func(x): return x["id"] == t.last_move):
				_fail()
				return true
			for mv in u.moves():
				if mv["id"] == m["id"]:
					mv["id"] = t.last_move
					var pp: int = move_data(t.last_move)["pp"]
					mv["pp"] = 5 if ident == "mimic" else pp
					mv["max"] = mv["pp"]
			msg("%s apprend %s !" % [nm(u), Data.move_name(t.last_move)])
		"metronome", "assist", "copycat", "me-first", "nature-power", "mirror-move", "sleep-talk":
			var call := _called_move(u, t, ident)
			if call == 0:
				_fail()
				return true
			var picked := move_data(call)
			msg("%s utilise %s !" % [nm(u), picked["name"]])
			if ident == "me-first":
				picked = picked.duplicate()
				picked["power"] = int(picked["power"] * 1.5)
			var tgt := t if t != null and t.alive() else foe(u)
			if picked["target"] in SPREAD_TARGETS:
				for t2: Battler in (foes(u) if picked["target"] == "all-opponents" else actives().filter(func(x): return x != u)):
					_execute(u, t2, picked)
			else:
				_execute(u, tgt if _targets_foe(picked) else u, picked)
		"snore":
			if u.mon.status != "slp" and ab(u) != "comatose":
				_fail()
				return true
			return false
		"transform":
			if t.transformed or t.substitute > 0 or u.transformed:
				_fail()
				return true
			_transform(u, t)
		"conversion":
			var typ: String = move_data(u.moves()[0]["id"])["type"]
			if u.types == [typ]:
				_fail()
				return true
			u.types = [typ]
			msg("%s devient du type %s !" % [nm(u), Data.type_name(typ)])
		"conversion-2":
			if t.last_move == 0:
				_fail()
				return true
			var atk_type: String = move_data(t.last_move)["type"]
			var opts2 := []
			for typ2 in Data.TYPES:
				if Data.effectiveness(atk_type, [typ2]) < 1.0:
					opts2.append(typ2)
			var nt: String = opts2[randi() % opts2.size()]
			u.types = [nt]
			msg("%s devient du type %s !" % [nm(u), Data.type_name(nt)])
		"camouflage":
			var ct: String = {"electric": "electric", "grassy": "grass", "misty": "fairy", "psychic": "psychic"}.get(terrain, "normal")
			u.types = [ct]
			msg("%s devient du type %s !" % [nm(u), Data.type_name(ct)])
		"soak", "magic-powder":
			var nt2 := "water" if ident == "soak" else "psychic"
			if t.types == [nt2] or dab(u, t) in ["multitype", "rks-system"]:
				_fail()
				return true
			t.types = [nt2]
			msg("%s devient du type %s !" % [nm(t), Data.type_name(nt2)])
		"trick-or-treat", "forests-curse":
			var add := "ghost" if ident == "trick-or-treat" else "grass"
			if has_type(t, add):
				_fail()
				return true
			t.added_type = add
			msg("%s devient aussi du type %s !" % [nm(t), Data.type_name(add)])
		"reflect-type":
			u.types = all_types(t).duplicate()
			msg("%s prend le type de %s !" % [nm(u), nm(t)])
		"mind-reader", "lock-on":
			u.lock_on = true
			msg("%s vise %s !" % [nm(u), nm(t)])
		"curse":
			if has_type(u, "ghost"):
				if t.cursed:
					_fail()
					return true
				_hurt(u, u.mon.max_hp() / 2)
				t.cursed = true
				msg("%s sacrifie des PV et maudit %s !" % [nm(u), nm(t)])
			else:
				_stage(u, "spe", -1, u)
				_stage(u, "atk", 1, u)
				_stage(u, "def", 1, u)
		"spite":
			for mv in t.moves():
				if mv["id"] == t.last_move and mv["pp"] > 0:
					var lost := mini(4, mv["pp"])
					mv["pp"] -= lost
					msg("Les PP de %s de %s baissent de %d !" % [Data.move_name(mv["id"]), nm(t), lost])
					return true
			_fail()
		"belly-drum", "fillet-away", "clangorous-soul":
			var cost3 := u.mon.max_hp() / (3 if ident == "clangorous-soul" else 2)
			if u.mon.hp <= cost3 or (ident == "belly-drum" and u.stages["atk"] >= 6):
				_fail()
				return true
			_hurt(u, cost3)
			if ident == "belly-drum":
				u.stages["atk"] = 6
				msg("%s sacrifie des PV et monte son Attaque au maximum !" % nm(u))
				anim(u, "stat_up")
			elif ident == "fillet-away":
				for k in ["atk", "spa", "spe"]:
					_stage(u, k, 2, u)
			else:
				for k in ["atk", "def", "spa", "spd", "spe"]:
					_stage(u, k, 1, u)
		"shell-smash":
			_stage(u, "def", -1, u)
			_stage(u, "spd", -1, u)
			_stage(u, "atk", 2, u)
			_stage(u, "spa", 2, u)
			_stage(u, "spe", 2, u)
			if it(u) == "white-herb":
				_white_herb(u)
		"destiny-bond":
			u.destiny_bond = true
			msg("%s veut emmener son ennemi avec lui !" % nm(u))
		"grudge":
			u.grudge = true
			msg("%s veut se venger !" % nm(u))
		"mean-look", "block", "spider-web":
			if t.mean_look or has_type(t, "ghost"):
				_fail()
				return true
			t.mean_look = true
			msg("%s ne peut plus s'enfuir !" % nm(t))
		"octolock":
			if t.octolock != null or has_type(t, "ghost"):
				_fail()
				return true
			t.octolock = u
			msg("%s est pris dans l'Octoprise !" % nm(t))
		"no-retreat":
			if u.no_retreat:
				_fail()
				return true
			for k in ["atk", "def", "spa", "spd", "spe"]:
				_stage(u, k, 1, u)
			u.no_retreat = true
		"baton-pass":
			if bench(u.side, u.owner).is_empty() or (u.side == 1 and wild):
				_fail()
				return true
			msg("%s passe le relais !" % nm(u))
			_baton(u)
		"parting-shot":
			var any := _stage(t, "atk", -1, u)
			any = _stage(t, "spa", -1, u) or any
			if any:
				_pivot(u)
		"encore":
			if t.last_move == 0 or t.encore_turns > 0 or t.last_move in [STRUGGLE, 227, 102, 118, 119] or dab(u, t) == "aroma-veil":
				_fail()
				return true
			t.encore_move = t.last_move
			t.encore_turns = 3
			msg("%s doit refaire %s !" % [nm(t), Data.move_name(t.last_move)])
		"psych-up":
			u.stages = t.stages.duplicate()
			msg("%s copie les changements de stats de %s !" % [nm(u), nm(t)])
		"heart-swap", "power-swap", "guard-swap", "speed-swap":
			var keys: Array = {"heart-swap": ["atk", "def", "spa", "spd", "spe", "acc", "eva"], "power-swap": ["atk", "spa"],
				"guard-swap": ["def", "spd"], "speed-swap": []}[ident]
			for k in keys:
				var tmp: int = u.stages[k]
				u.stages[k] = t.stages[k]
				t.stages[k] = tmp
			msg("%s échange ses changements de stats avec %s !" % [nm(u), nm(t)])
		"power-split", "guard-split":
			var idx_pair: Array = [1, 3] if ident == "power-split" else [2, 4]
			for i in idx_pair:
				var avg := (u.raw(i) + t.raw(i)) / 2
				for b in [u, t]:
					if b.f_stats.size() != 6:
						b.f_stats = b.mon.stats.duplicate()
					b.f_stats[i] = avg
			msg("%s partage sa puissance avec %s !" % [nm(u), nm(t)])
		"pain-split":
			var avg_hp := (u.mon.hp + t.mon.hp) / 2
			u.mon.hp = mini(u.mon.max_hp(), avg_hp)
			t.mon.hp = mini(t.mon.max_hp(), avg_hp)
			hp_event(u)
			hp_event(t)
			msg("Les deux Pokémon partagent leurs PV !")
		"topsy-turvy":
			for k in t.stages:
				t.stages[k] = -t.stages[k]
			msg("Les changements de stats de %s sont inversés !" % nm(t))
		"power-trick":
			u.power_trick = not u.power_trick
			msg("%s échange son Attaque et sa Défense !" % nm(u))
		"acupressure":
			var choices := []
			for k in ["atk", "def", "spa", "spd", "spe", "acc", "eva"]:
				if u.stages[k] < 6:
					choices.append(k)
			if choices.is_empty():
				_fail()
				return true
			_stage(u, choices[randi() % choices.size()], 2, u)
		"future-sight", "doom-desire":
			var fs: BSide = sides[t.side]
			if fs.future_turns > 0:
				_fail()
				return true
			fs.future_turns = 3
			fs.future_slot = t.slot
			var fm := m.duplicate()
			fm["cat"] = "special"
			fs.future_damage = _calc_damage(u, t, fm, m["power"], _type_eff(u, t, m["type"], ident), false)
			msg("%s prévoit une attaque !" % nm(u) if ident == "future-sight" else "%s invoque un Vœu Destructeur !" % nm(u))
		"stockpile":
			if u.stockpile >= 3:
				_fail()
				return true
			u.stockpile += 1
			msg("%s stocke %d !" % [nm(u), u.stockpile])
			if _stage(u, "def", 1, u):
				u.stock_def += 1
			if _stage(u, "spd", 1, u):
				u.stock_spd += 1
		"memento":
			_stage(t, "atk", -2, u)
			_stage(t, "spa", -2, u)
			u.mon.hp = 0
			hp_event(u)
			_faint(u)
		"healing-wish", "lunar-dance":
			if bench(u.side, u.owner).is_empty():
				_fail()
				return true
			sides[u.side].healing_wish = true
			u.mon.hp = 0
			hp_event(u)
			_faint(u)
		"wish":
			var ws: BSide = sides[u.side]
			if ws.wish_turns > 0:
				_fail()
				return true
			ws.wish_turns = 2
			ws.wish_hp = u.mon.max_hp() / 2
			ws.wish_slot = u.slot
			msg("%s fait un vœu !" % nm(u))
		"revival-blessing":
			var dead := []
			for i in sides[u.side].party.size():
				var pm: Pokemon = sides[u.side].party[i]
				if sides[u.side].owners[i] == u.owner and pm.hp <= 0 and not pm.is_egg:
					dead.append(pm)
			if dead.is_empty():
				_fail()
				return true
			var back: Pokemon = dead[0]
			back.hp = back.max_hp() / 2
			msg("%s est ranimé !" % back.name())
			refresh()
		"follow-me", "rage-powder", "spotlight":
			if not is_double():
				_fail()
				return true
			u.center = true
			msg("%s attire l'attention !" % nm(u))
		"helping-hand":
			var al2 := ally(u)
			if al2 == null:
				_fail()
				return true
			al2.helping = true
			msg("%s est prêt à aider %s !" % [nm(u), nm(al2)])
		"after-you", "quash", "instruct", "ally-switch":
			msg("%s agit avec fair-play." % nm(u) if ident == "after-you" else "Mais rien de spécial ne se passe.")
		"snatch":
			u.snatch = true
			msg("%s attend une capacité à voler !" % nm(u))
		"magic-coat":
			u.magic_coat = true
			msg("%s s'entoure d'un reflet magique !" % nm(u))
		"trick", "switcheroo":
			if (u.item == "" and t.item == "") or _item_locked(u) or _item_locked(t) or dab(u, t) == "sticky-hold" or t.mon.boss:
				_fail()
				return true
			var tmp_item := u.item
			u.item = t.item
			t.item = tmp_item
			msg("%s échange son objet avec %s !" % [nm(u), nm(t)])
			if u.item != "":
				msg("%s obtient %s." % [nm(u), Data.item_name(u.item)])
			if t.item != "":
				msg("%s obtient %s." % [nm(t), Data.item_name(t.item)])
			u.choice_move = 0
			t.choice_move = 0
		"bestow":
			if u.item == "" or t.item != "" or _item_locked(u):
				_fail()
				return true
			t.item = u.item
			u.item = ""
			msg("%s donne %s à %s !" % [nm(u), Data.item_name(t.item), nm(t)])
		"recycle":
			if u.item != "" or u.item_lost == "":
				_fail()
				return true
			u.item = u.item_lost
			u.item_lost = ""
			msg("%s récupère %s !" % [nm(u), Data.item_name(u.item)])
		"embargo":
			t.embargo = 5
			msg("%s ne peut plus utiliser d'objets !" % nm(t))
		"heal-block":
			t.heal_block = 5
			msg("%s ne peut plus se soigner !" % nm(t))
		"magnet-rise":
			if u.magnet_rise > 0 or u.ingrain or gravity > 0:
				_fail()
				return true
			u.magnet_rise = 5
			msg("%s lévite grâce à l'électromagnétisme !" % nm(u))
		"telekinesis":
			if t.telekinesis > 0 or t.ingrain or gravity > 0:
				_fail()
				return true
			t.telekinesis = 3
			msg("%s est soulevé dans les airs !" % nm(t))
		"taunt":
			if t.taunt > 0 or dab(u, t) in ["oblivious", "aroma-veil"]:
				_fail()
				return true
			t.taunt = 3
			msg("%s se laisse provoquer !" % nm(t))
			if it(t) == "mental-herb":
				_consume(t)
				t.taunt = 0
				msg("L'Herbe Mental de %s le calme !" % nm(t))
		"torment":
			if t.torment:
				_fail()
				return true
			t.torment = true
			msg("%s est tourmenté !" % nm(t))
		"role-play", "doodle":
			if t.ability == u.ability or Data.ability_ident(t.ability) in UNCOPYABLE:
				_fail()
				return true
			u.ability = t.ability
			if ident == "doodle" and ally(u) != null:
				ally(u).ability = t.ability
			msg("%s copie le talent %s !" % [nm(u), Data.ability_name(t.ability)])
			_entry_ability(u)
		"skill-swap":
			if Data.ability_ident(u.ability) in UNCOPYABLE or Data.ability_ident(t.ability) in UNCOPYABLE:
				_fail()
				return true
			var a := u.ability
			u.ability = t.ability
			t.ability = a
			msg("%s échange son talent avec %s !" % [nm(u), nm(t)])
		"entrainment":
			if Data.ability_ident(u.ability) in UNCOPYABLE or Data.ability_ident(t.ability) in ["truant", "multitype", "stance-change"]:
				_fail()
				return true
			t.ability = u.ability
			msg("Le talent de %s devient %s !" % [nm(t), Data.ability_name(u.ability)])
		"worry-seed", "simple-beam":
			var target_ab := "insomnia" if ident == "worry-seed" else "simple"
			if Data.ability_ident(t.ability) in UNCOPYABLE + ["truant", target_ab]:
				_fail()
				return true
			for id in Data.abilities:
				if Data.abilities[id]["ident"] == target_ab:
					t.ability = id
			msg("Le talent de %s devient %s !" % [nm(t), Data.ability_name(t.ability)])
			if ident == "worry-seed" and t.mon.status == "slp":
				t.mon.status = ""
				refresh()
		"gastro-acid":
			if t.suppressed or Data.ability_ident(t.ability) in ["multitype", "stance-change", "schooling", "comatose"]:
				_fail()
				return true
			t.suppressed = true
			msg("Le talent de %s est neutralisé !" % nm(t))
		"imprison":
			u.imprison = true
			msg("%s scelle les capacités communes !" % nm(u))
		"refresh", "purify":
			var tgt2 := u if ident == "refresh" else t
			if not tgt2.mon.status in ["psn", "tox", "par", "brn", "frz", "slp"]:
				_fail()
				return true
			tgt2.mon.status = ""
			refresh()
			msg("%s est soigné !" % nm(tgt2))
			if ident == "purify":
				_heal(u, u.mon.max_hp() / 2)
		"aromatherapy", "heal-bell":
			for i in sides[u.side].party.size():
				if sides[u.side].owners[i] == u.owner:
					sides[u.side].party[i].status = ""
			refresh()
			msg("Un parfum apaisant soigne toute l'équipe !")
		"psycho-shift":
			if u.mon.status == "" or t.mon.status != "":
				_fail()
				return true
			if _set_status(t, u.mon.status, u, true):
				u.mon.status = ""
				refresh()
		"nightmare":
			if t.mon.status != "slp" or t.nightmare:
				_fail()
				return true
			t.nightmare = true
			msg("%s fait un cauchemar !" % nm(t))
		"leech-seed":
			if has_type(t, "grass") or t.seeded or t.substitute > 0:
				msg("Ça n'affecte pas %s..." % nm(t))
				return true
			if not _hits(u, t, m):
				msg("%s évite l'attaque !" % nm(t))
				return true
			t.seeded = true
			t.seeded_by = u
			msg("%s est infecté !" % nm(t))
		"ingrain":
			if u.ingrain:
				_fail()
				return true
			u.ingrain = true
			msg("%s plante ses racines !" % nm(u))
		"aqua-ring":
			if u.aqua_ring:
				_fail()
				return true
			u.aqua_ring = true
			msg("%s s'entoure d'un voile d'eau !" % nm(u))
		"yawn":
			if t.yawn > 0 or t.mon.status != "" or t.substitute > 0 or sides[t.side].safeguard > 0:
				_fail()
				return true
			t.yawn = 2
			msg("%s rend %s somnolent !" % [nm(u), nm(t)])
		"attract":
			_attract(t, u, true)
		"foresight", "odor-sleuth", "miracle-eye":
			if ident == "miracle-eye":
				t.miracle_eye = true
			else:
				t.foresight = true
			t.stages["eva"] = mini(t.stages["eva"], 0)
			msg("%s est identifié !" % nm(t))
		"rage":
			u.rage = true
			return false
		"bide":
			_fail()
		"swallow":
			_heal_move(u, m)
		"whirlwind", "roar":
			_force_switch(u, t)
		"defog":
			_stage(t, "eva", -1, u)
			for s: BSide in sides:
				s.spikes = 0
				s.toxic_spikes = 0
				s.stealth_rock = false
				s.sticky_web = false
			var ts: BSide = sides[t.side]
			ts.reflect = 0
			ts.light_screen = 0
			ts.aurora_veil = 0
			ts.safeguard = 0
			ts.mist = 0
			if terrain != "":
				terrain = ""
				events.append({"t": "terrain", "terrain": ""})
			msg("Le vent balaie tout le terrain !")
			field_event()
		"tidy-up":
			for s2: BSide in sides:
				s2.spikes = 0
				s2.toxic_spikes = 0
				s2.stealth_rock = false
				s2.sticky_web = false
			for b: Battler in _on_field():
				if b.substitute > 0:
					b.substitute = 0
					events.append({"t": "sub", "side": b.side, "slot": b.slot, "on": false})
			msg("%s fait le ménage !" % nm(u))
			_stage(u, "atk", 1, u)
			_stage(u, "spe", 1, u)
			field_event()
		"chilly-reception":
			_set_weather("snow", u)
			_pivot(u)
		"strength-sap":
			var atk := int(stat_value(t, 1))
			if t.stages["atk"] <= -6:
				_fail()
				return true
			_stage(t, "atk", -1, u)
			_heal(u, atk)
			msg("%s draine la force de %s !" % [nm(u), nm(t)])
		"electrify":
			t.electrify = true
			msg("Les capacités de %s deviennent Électrik !" % nm(t))
		"powder":
			t.powder = true
			msg("%s est couvert de poudre explosive !" % nm(t))
		"mat-block":
			if u.turns > 0:
				_fail()
				return true
			sides[u.side].mat_block = true
			msg("%s dresse un tatami !" % nm(u))
		"coaching", "aromatic-mist", "decorate":
			var al3 := ally(u) if ident != "decorate" else t
			if al3 == null:
				_fail()
				return true
			for sc in m["stats"]:
				_stage(al3, STAGE_KEYS[sc[0] - 1], sc[1], u)
		"spicy-extract":
			_stage(t, "atk", 2, u)
			_stage(t, "def", -2, u)
		"teatime":
			for b: Battler in _on_field():
				if Data.items.get(b.item, {}).get("berry", false):
					var br := b.item
					_consume(b, true)
					_eat_berry(b, br)
		"corrosive-gas":
			for b: Battler in _on_field():
				if b != u and b.item != "" and not _item_locked(b) and ab(b) != "sticky-hold":
					msg("L'objet de %s fond !" % nm(b))
					b.item = ""
		"sky-drop":
			return false
		"extreme-evoboost":
			for k in ["atk", "def", "spa", "spd", "spe"]:
				_stage(u, k, 2, u)
		"geomancy":
			_stage(u, "spa", 2, u)
			_stage(u, "spd", 2, u)
			_stage(u, "spe", 2, u)
		"conversion-z":
			pass
		_:
			return false
	return true


## Relais (et Queue Délestée) : le remplaçant garde les changements de stats.
func _baton(u: Battler) -> void:
	if u.side == 0:
		need_switch.append({"slot": u.slot, "owner": u.owner, "baton": true})
	else:
		var bl := bench(u.side, u.owner)
		if bl.is_empty():
			return
		events.append({"t": "recall", "side": 1, "slot": u.slot})
		var shed: int = u.mon.counters.get("shed_tail", 0)
		u.mon.counters.erase("shed_tail")
		_send(1, u.slot, bl[0], true, shed == 0)
		if shed > 0:
			sides[1].slots[u.slot].substitute = shed
			events.append({"t": "sub", "side": 1, "slot": u.slot, "on": true})
		_entry_ability(sides[1].slots[u.slot])


## Capacité appelée par Métronome, Photocopie, Moi d'Abord, Force Nature, Mimique, Blabla Dodo.
func _called_move(u: Battler, t: Battler, ident: String) -> int:
	var banned := ["metronome", "struggle", "mimic", "mirror-move", "sleep-talk", "counter", "protect", "detect", "endure",
		"destiny-bond", "transform", "assist", "copycat", "me-first", "nature-power", "sketch", "focus-punch", "trick",
		"switcheroo", "thief", "covet", "baneful-bunker", "kings-shield", "spiky-shield", "obstruct", "snatch", "chatter", "bide"]
	match ident:
		"metronome":
			var pool := []
			for id in Data.moves:
				if Data.moves[id]["ident"] not in banned:
					pool.append(id)
			return pool[randi() % pool.size()]
		"assist":
			var pool2 := []
			for i in sides[u.side].party.size():
				var pm: Pokemon = sides[u.side].party[i]
				if pm != u.mon and sides[u.side].owners[i] == u.owner:
					for mv in pm.moves:
						if move_data(mv["id"])["ident"] not in banned:
							pool2.append(mv["id"])
			return pool2[randi() % pool2.size()] if pool2.size() > 0 else 0
		"copycat":
			return _last_move_used if _last_move_used != 0 and move_data(_last_move_used)["ident"] not in banned else 0
		"mirror-move":
			return t.last_move if t != null and t.last_move != 0 and move_data(t.last_move)["ident"] not in banned else 0
		"me-first":
			if t == null or t.moved:
				return 0
			var tid := _action_move_id(t)
			return tid if move_data(tid)["cat"] != "status" else 0
		"nature-power":
			var by_terrain := {"electric": "thunderbolt", "grassy": "energy-ball", "misty": "moonblast", "psychic": "psychic"}
			var name: String = by_terrain.get(terrain, "tri-attack")
			for id in Data.moves:
				if Data.moves[id]["ident"] == name:
					return id
			return 0
		"sleep-talk":
			if u.mon.status != "slp" and ab(u) != "comatose":
				return 0
			var opts := []
			for mv in u.moves():
				var md := move_data(mv["id"])
				if md["ident"] not in banned + ["uproar"] and not TWO_TURN.has(md["ident"]):
					opts.append(mv["id"])
			return opts[randi() % opts.size()] if opts.size() > 0 else 0
	return 0


# ---------------------------------------------------------------------------
# Statuts, stats, PV
# ---------------------------------------------------------------------------

func _ailment(u: Battler, t: Battler, ail: String, from_status_move: bool, ident: String) -> bool:
	if AILMENT_STATUS.has(ail):
		var st: String = AILMENT_STATUS[ail]
		if ident in ["toxic", "poison-fang", "malignant-chain"]:
			st = "tox"
		return _set_status(t, st, u, from_status_move)
	match ail:
		"confusion":
			return _confuse(t, u, from_status_move)
		"infatuation":
			return _attract(t, u, from_status_move)
		"trap":
			if t.trap_turns == 0 and t.mon.hp > 0 and not has_type(t, "ghost"):
				t.trap_turns = 7 if it(u) == "grip-claw" else randi_range(4, 5)
				t.trap_move = ident
				t.trap_by = u
				msg("%s est piégé par %s !" % [nm(t), Data.move_name(_move_id(ident))])
			return true
		"nightmare", "torment", "disable", "yawn", "leech-seed", "perish-song", "ingrain", "heal-block", "embargo", "telekinesis":
			return true
	if from_status_move:
		_fail()
	return false


func _move_id(ident: String) -> int:
	for id in Data.moves:
		if Data.moves[id]["ident"] == ident:
			return id
	return 0


func _set_status(t: Battler, st: String, src: Battler, loud: bool) -> bool:
	var mon := t.mon
	if mon.hp <= 0:
		return false
	var fail := ""
	var ta := dab(src, t) if src != null else ab(t)
	var corrosion := src != null and ab(src) == "corrosion"
	if mon.status != "" or ta == "comatose":
		fail = "%s est déjà touché par un statut !" % nm(t)
	elif src != t and sides[t.side].safeguard > 0 and (src == null or ab(src) != "infiltrator"):
		fail = "%s est protégé par Rune Protect !" % nm(t)
	elif terrain == "misty" and grounded(t):
		fail = "Le Champ Brumeux protège %s !" % nm(t)
	elif st == "slp" and terrain == "electric" and grounded(t):
		fail = "Le Champ Électrifié empêche %s de s'endormir !" % nm(t)
	elif st == "brn" and (has_type(t, "fire") or ta in ["water-veil", "water-bubble", "thermal-exchange"]):
		fail = "Ça n'affecte pas %s..." % nm(t)
	elif st == "par" and (has_type(t, "electric") or ta == "limber"):
		fail = "Ça n'affecte pas %s..." % nm(t)
	elif st in ["psn", "tox"] and ((has_type(t, "poison") or has_type(t, "steel")) and not corrosion or ta in ["immunity", "pastel-veil"]):
		fail = "Ça n'affecte pas %s..." % nm(t)
	elif st == "frz" and (has_type(t, "ice") or is_sun(t) or ta == "magma-armor"):
		fail = "Ça n'affecte pas %s..." % nm(t)
	elif st == "slp" and (ta in ["insomnia", "vital-spirit", "sweet-veil"] or actives().any(func(x): return x.uproar > 0)):
		fail = "%s ne peut pas s'endormir !" % nm(t)
	elif ta == "leaf-guard" and is_sun(t):
		fail = "Feuille Garde protège %s !" % nm(t)
	elif ta == "purifying-salt":
		fail = "Sel Purificateur protège %s !" % nm(t)
	elif ta == "shields-down" and t.form_id == 0 and t.mon.species == 774:
		fail = "Bouclier-Carcan protège %s !" % nm(t)
	elif ally(t) != null and ab(ally(t)) in ["pastel-veil"] and st in ["psn", "tox"]:
		fail = "Voile Pastel protège %s !" % nm(t)
	elif ally(t) != null and ab(ally(t)) == "sweet-veil" and st == "slp":
		fail = "Voile Sucré protège %s !" % nm(t)
	elif ta == "flower-veil" and has_type(t, "grass") and src != t:
		fail = "Flora-Voile protège %s !" % nm(t)
	elif st == "slp" and sleep_clause and src != null and src.side != t.side \
			and sides[t.side].party.any(func(p): return p != mon and p.hp > 0 and p.status == "slp" and p.counters.get("foe_sleep", false)):
		fail = "Clause Sommeil : un seul Pokémon peut être endormi à la fois !"
	if t.substitute > 0 and src != t and loud:
		fail = "Mais cela échoue !"
	if fail != "":
		if loud:
			msg(fail)
		return false
	mon.status = st
	if st == "slp":
		mon.sleep_turns = randi_range(2, 4)
		mon.counters["foe_sleep"] = src != null and src.side != t.side
	if st == "tox":
		t.toxic_n = 0
	anim(t, "status_" + st)
	refresh()
	msg(STATUS_TEXT[st] % nm(t))
	if ta == "synchronize" and src != null and src != t and st in ["psn", "tox", "par", "brn"]:
		msg("Synchro de %s !" % nm(t))
		_set_status(src, "psn" if st == "tox" else st, null, false)
	_status_berry(t)
	return true


func _confuse(t: Battler, src: Battler, loud: bool) -> bool:
	if t.mon.hp <= 0:
		return false
	if t.confusion > 0:
		if loud:
			msg("%s est déjà confus !" % nm(t))
		return false
	if ab(t) == "own-tempo" or (src != t and sides[t.side].safeguard > 0) or (terrain == "misty" and grounded(t)):
		if loud:
			_fail()
		return false
	t.confusion = randi_range(2, 5)
	anim(t, "status_conf")
	msg("%s est confus !" % nm(t))
	_status_berry(t)
	return true


func _attract(t: Battler, src: Battler, loud: bool) -> bool:
	if t.attract or t.mon.gender == 2 or src.mon.gender == 2 or t.mon.gender == src.mon.gender or ab(t) in ["oblivious", "aroma-veil"]:
		if loud:
			_fail()
		return false
	t.attract = true
	t.attract_by = src
	msg("%s tombe amoureux !" % nm(t))
	if it(t) == "mental-herb":
		_consume(t)
		t.attract = false
		msg("L'Herbe Mental de %s le guérit !" % nm(t))
	elif it(t) == "destiny-knot" and src.attract == false:
		_attract(src, t, false)
	return true


## Modifie un niveau de stat. Renvoie true si quelque chose a changé.
func _stage(t: Battler, key: String, delta: int, src: Battler) -> bool:
	if t == null or t.mon.hp <= 0 or delta == 0:
		return false
	var ta := ab(t)
	if ta == "contrary":
		delta = -delta
	if ta == "simple":
		delta *= 2
	if delta < 0 and src != t:
		if sides[t.side].mist > 0 and (src == null or ab(src) != "infiltrator"):
			msg("%s est protégé par la brume !" % nm(t))
			return false
		var tda := dab(src, t) if src != null else ta
		if tda in ["clear-body", "white-smoke", "full-metal-body"] or (tda == "keen-eye" and key == "acc") \
				or (tda in ["hyper-cutter"] and key == "atk") or (tda == "big-pecks" and key == "def") \
				or (tda == "minds-eye" and key == "acc") or it(t) == "clear-amulet":
			msg("%s de %s empêche la baisse !" % [Data.ability_name(t.ability) if it(t) != "clear-amulet" else "L'Amulette Claire", nm(t)])
			return false
		if tda == "flower-veil" and has_type(t, "grass"):
			return false
		if tda == "mirror-armor" and src != null:
			msg("Armure Miroir de %s renvoie la baisse !" % nm(t))
			return _stage(src, key, delta, null)
		if t.substitute > 0 and src != null:
			return false
	var label: String = STAT_LABEL[key] + " de " + nm(t)
	var cur: int = t.stages[key]
	var nv := clampi(cur + delta, -6, 6)
	if nv == cur:
		msg(label + (" ne peut plus augmenter !" if delta > 0 else " ne peut plus baisser !"))
		return false
	t.stages[key] = nv
	var n := absi(nv - cur)
	if delta > 0:
		t.raised_turn = true
		anim(t, "stat_up")
		msg(label + [" augmente !", " augmente beaucoup !", " augmente énormément !"][mini(n, 3) - 1])
		# Opportuniste et Herbe Miroir : copient la hausse adverse.
		for o: Battler in foes(t):
			if ab(o) == "opportunist" or it(o) == "mirror-herb":
				if it(o) == "mirror-herb" and ab(o) != "opportunist":
					_consume(o)
				o.stages[key] = clampi(o.stages[key] + n, -6, 6)
				msg("%s copie la hausse de stat !" % nm(o))
	else:
		t.lowered_turn = true
		anim(t, "stat_down")
		msg(label + [" baisse !", " baisse beaucoup !", " baisse énormément !"][mini(n, 3) - 1])
		if src != t and src != null:
			if ta == "competitive":
				msg("Battant de %s s'active !" % nm(t))
				_stage(t, "spa", 2, t)
			elif ta == "defiant":
				msg("Acharné de %s s'active !" % nm(t))
				_stage(t, "atk", 2, t)
		if it(t) == "white-herb":
			_white_herb(t)
		if it(t) == "eject-pack" and bench(t.side, t.owner).size() > 0:
			_consume(t)
			msg("%s est éjecté par son Sac Éjection !" % nm(t))
			_pivot(t)
	return true


func _white_herb(t: Battler) -> void:
	var any := false
	for k in t.stages:
		if t.stages[k] < 0:
			t.stages[k] = 0
			any = true
	if any:
		_consume(t)
		msg("L'Herbe Blanche de %s restaure ses stats !" % nm(t))


func _hurt(b: Battler, amount: int) -> void:
	if b.mon.hp <= 0:
		return
	b.mon.hp = maxi(0, b.mon.hp - maxi(1, amount))
	hp_event(b)
	if b.mon.hp <= 0:
		_faint(b)
	else:
		_check_hp_items(b)
		_check_forms(b)


func _heal(b: Battler, amount: int) -> void:
	if b.mon.hp <= 0 or b.heal_block > 0:
		return
	b.mon.hp = mini(b.mon.max_hp(), b.mon.hp + maxi(1, amount))
	hp_event(b)
	_check_forms(b)


func _faint(b: Battler) -> void:
	if b.fainted:
		return
	b.fainted = true
	b.mon.hp = 0
	b.mon.status = ""
	b.charging = 0
	b.invuln = ""
	b.mon.held_item = b.item
	sides[b.side].fainted_count += 1
	sides[b.side].fainted_last_turn = true
	events.append({"t": "faint", "side": b.side, "slot": b.slot})
	msg("%s est K.O. !" % nm(b))
	if b.side == 1 and not pvp:
		_give_exp(b)


# ---------------------------------------------------------------------------
# Objets tenus et baies
# ---------------------------------------------------------------------------

## Objet qu'on ne peut ni voler ni échanger (Méga-Gemmes, Plaques d'Arceus, Cristaux Z...).
func _item_locked(b: Battler) -> bool:
	var item := b.item
	if item == "":
		return false
	if Data.mega_stones.has(item) or Data.z_crystals.has(item):
		return true
	if item in ["red-orb", "blue-orb", "rusted-sword", "rusted-shield", "booster-energy"] or (b.mon.species == 493 and item in PLATES):
		return true
	if (b.mon.species == 773 and MEMORIES.has(item)) or (b.mon.species == 487 and item in ["griseous-orb", "griseous-core"]):
		return true
	return false


func _unburden(b: Battler) -> void:
	if ab(b) == "unburden":
		b.unburden = true


## Consomme l'objet tenu (Recyclage peut le récupérer). berry : c'est une baie mangée.
func _consume(b: Battler, berry := false) -> void:
	if b.item == "":
		return
	b.item_lost = b.item
	b.item = ""
	if berry:
		b.berry_eaten = true
		if ab(b) == "cheek-pouch":
			_heal(b, b.mon.max_hp() / 3)
		if ab(b) == "cud-chew":
			b.mon.counters["cud"] = b.item_lost
	_unburden(b)


## Une baie peut-elle être mangée (Tension adverse l'empêche).
func _can_eat(b: Battler) -> bool:
	for o: Battler in foes(b):
		if ab(o) in ["unnerve", "as-one-glastrier", "as-one-spectrier"]:
			return false
	return true


## Effet d'une baie mangée (par son porteur, Picore, Dégommage ou Mâchouille).
func _eat_berry(b: Battler, berry: String) -> void:
	var ripe := 2.0 if ab(b) == "ripen" else 1.0
	match berry:
		"oran-berry":
			_heal(b, int(10 * ripe))
		"sitrus-berry":
			_heal(b, int(b.mon.max_hp() / 4 * ripe))
		"leppa-berry":
			for mv in b.moves():
				if mv["pp"] < mv["max"]:
					mv["pp"] = mini(mv["max"], mv["pp"] + 10)
					break
		"lansat-berry":
			b.crit_bonus += 2
			msg("%s est gonflé à bloc !" % nm(b))
		"starf-berry":
			_stage(b, ["atk", "def", "spa", "spd", "spe"][randi() % 5], int(2 * ripe), b)
		"micle-berry":
			b.micle = true
		_:
			if PINCH_STAT_BERRIES.has(berry):
				_stage(b, PINCH_STAT_BERRIES[berry], int(ripe), b)
			elif berry in CONFUSE_BERRIES:
				_heal(b, int(b.mon.max_hp() / 3 * ripe))
			elif STATUS_BERRIES.has(berry):
				var cures: Array = STATUS_BERRIES[berry]
				if cures.has(b.mon.status):
					b.mon.status = ""
					refresh()
					msg("%s est soigné !" % nm(b))
				if cures.has("conf") and b.confusion > 0:
					b.confusion = 0
					msg("%s n'est plus confus !" % nm(b))
	msg("%s mange sa %s !" % [nm(b), Data.item_name(berry)])


## Baies et objets qui guérissent un statut dès qu'il apparaît.
func _status_berry(b: Battler) -> void:
	var item := it(b)
	if STATUS_BERRIES.has(item) and _can_eat(b):
		var cures: Array = STATUS_BERRIES[item]
		if cures.has(b.mon.status) or (cures.has("conf") and b.confusion > 0):
			_consume(b, true)
			_eat_berry(b, item)
	if item == "mental-herb" and (b.attract or b.taunt > 0 or b.encore_turns > 0 or b.disable_turns > 0):
		_consume(b)
		b.attract = false
		b.taunt = 0
		b.encore_turns = 0
		b.disable_turns = 0
		b.disable_move = 0
		msg("L'Herbe Mental de %s le libère !" % nm(b))


## Baies qui s'activent selon les PV (Sitrus, Oran, baies de stats...).
func _check_hp_items(b: Battler) -> void:
	if b == null or not b.alive() or b.item == "":
		return
	var item := it(b)
	var frac := b.hp_frac()
	var pinch := 0.5 if ab(b) == "gluttony" else 0.25
	if not Data.items.get(item, {}).get("berry", false) or not _can_eat(b):
		return
	var eat := false
	if item in ["oran-berry", "sitrus-berry"] and frac <= 0.5:
		eat = true
	elif item in CONFUSE_BERRIES and frac <= pinch:
		eat = true
	elif (PINCH_STAT_BERRIES.has(item) or item in ["lansat-berry", "starf-berry", "micle-berry"]) and frac <= pinch:
		eat = true
	if eat:
		_consume(b, true)
		_eat_berry(b, item)


## Après chaque capacité du lanceur : Carton Rouge, Bouton Fuite (du défenseur), Sac Éjection...
func _after_move_items(u: Battler) -> void:
	for t: Battler in _on_field():
		if t == u or not t.hit_by_foe or t.last_dmg <= 0 or t.side == u.side:
			continue
		if not t.damaged_turn:
			continue
		match it(t):
			"red-card":
				if u.alive() and not over:
					_consume(t)
					msg("%s brandit son Carton Rouge !" % nm(t))
					_force_switch(t, u)
			"eject-button":
				if bench(t.side, t.owner).size() > 0 and not over:
					_consume(t)
					msg("%s est éjecté par son Bouton Fuite !" % nm(t))
					_pivot(t)
		t.damaged_turn = false


# ---------------------------------------------------------------------------
# Expérience
# ---------------------------------------------------------------------------

## Expérience (formule des jeux récents) : elle baisse quand ton Pokémon est plus fort que l'adversaire.
static func exp_gain(base: int, foe_level: int, my_level: int, trainer_battle: bool, shared: int) -> int:
	var a := 1.5 if trainer_battle else 1.0
	var scale := pow((2.0 * foe_level + 10.0) / (foe_level + my_level + 10.0), 2.5)
	return maxi(1, int(a * base * foe_level / 5.0 / maxi(1, shared) * scale) + 1)


## Objets qui doublent les EV gagnés (Bracelet Macho) ou en ajoutent (objets Pouvoir), Pokérus.
static func ev_yield(mon: Pokemon, base_ev: Array) -> Array:
	var out := base_ev.duplicate()
	var power := {"power-weight": 0, "power-bracer": 1, "power-belt": 2, "power-lens": 3, "power-band": 4, "power-anklet": 5}
	if mon.held_item == "macho-brace":
		for i in 6:
			out[i] *= 2
	elif power.has(mon.held_item):
		out[power[mon.held_item]] += 8
	if mon.pokerus != 0:
		for i in 6:
			out[i] *= 2
	return out


func _give_exp(enemy: Battler) -> void:
	var idxs := []
	for i in participants.get(enemy.party_index, []):
		if sides[0].party[i].can_battle():
			idxs.append(i)
	if idxs.is_empty():
		return
	var base: int = enemy.mon.data()["exp"]
	if enemy.mon.boss:
		base *= 3
	# Multi Exp : les Pokémon qui n'ont pas combattu reçoivent la moitié.
	var shared := {}
	for i in sides[0].party.size():
		var o: int = sides[0].owners[i]
		if o < exp_share.size() and exp_share[o] and not idxs.has(i) and sides[0].party[i].can_battle():
			shared[i] = true
	for i in idxs + shared.keys():
		var mon: Pokemon = sides[0].party[i]
		mon.add_evs(ev_yield(mon, enemy.mon.data()["ev"]))
		if mon.level >= 100:
			continue
		var gained := exp_gain(base, enemy.mon.level, mon.level, not wild, idxs.size() if not shared.has(i) else 2)
		if mon.held_item == "lucky-egg":
			gained = int(gained * 1.5)
		if mon.ot != "" and mon.ot != player_name and sides[0].owners[i] == 0:
			gained = int(gained * 1.5)
		msg("%s gagne %d Points Exp. !" % [mon.name(), gained])
		var reached := mon.add_exp(gained)
		var on_field: Battler = null
		for p: Battler in sides[0].slots:
			if p != null and p.party_index == i and p.alive():
				on_field = p
		var owner: int = sides[0].owners[i]
		events.append({"t": "exp", "index": i, "owner": owner, "active": on_field != null, "slot": on_field.slot if on_field else -1})
		for lv in reached:
			leveled[i] = true
			events.append({"t": "level", "index": i, "owner": owner, "active": on_field != null, "slot": on_field.slot if on_field else -1, "level": lv})
			msg("%s monte au niveau %d !" % [mon.name(), lv])
			for mid in mon.moves_at(lv):
				if mon.moves.size() < 4:
					mon.moves.append(Pokemon.make_move(mid))
					msg("%s apprend %s !" % [mon.name(), Data.move_name(mid)])
				else:
					events.append({"t": "learn", "mon": mon, "move": mid, "index": i, "owner": owner})
		if on_field != null:
			if on_field.f_stats.size() == 6 and on_field.form_id != 0 and Data.pokemon.has(on_field.form_id):
				on_field.f_stats = _form_stats(mon, on_field.form_id)
			hp_event(on_field)


# ---------------------------------------------------------------------------
# Fin de tour
# ---------------------------------------------------------------------------

func _end_of_turn() -> void:
	var w := weather_on()
	if weather != "":
		weather_turns -= 1
		if weather_turns <= 0:
			msg({"rain": "La pluie s'arrête.", "sun": "Le soleil s'affaiblit.", "sandstorm": "La tempête de sable se calme.",
				"hail": "La grêle s'arrête.", "snow": "La neige s'arrête.", "heavy-rain": "La pluie s'arrête.",
				"harsh-sun": "Le soleil s'affaiblit.", "strong-winds": "Le vent se calme."}[weather])
			weather = ""
			events.append({"t": "weather", "w": ""})
		else:
			msg({"rain": "La pluie continue de tomber.", "sun": "Le soleil brille.", "sandstorm": "La tempête de sable fait rage.",
				"hail": "La grêle continue de tomber.", "snow": "La neige continue de tomber.", "heavy-rain": "La pluie battante continue.",
				"harsh-sun": "Le soleil est brûlant.", "strong-winds": "Le vent mystérieux souffle."}[weather])
	# Vœu.
	for s: BSide in sides:
		if s.wish_turns > 0:
			s.wish_turns -= 1
			if s.wish_turns == 0:
				var wb := battler(sides.find(s), s.wish_slot)
				if wb != null and wb.alive():
					msg("Le vœu se réalise !")
					_heal(wb, s.wish_hp)
	for b: Battler in actives():
		var side: BSide = sides[b.side]
		if not b.alive():
			continue
		b.turns += 1
		b.switched_in = false
		var mx := b.mon.max_hp()
		var a := ab(b)
		var magic := a == "magic-guard"
		var bw := weather_for(b)
		if w == "sandstorm" and not (has_type(b, "rock") or has_type(b, "ground") or has_type(b, "steel")) \
				and a not in ["sand-veil", "magic-guard", "sand-rush", "sand-force", "overcoat"] and b.invuln == "" and it(b) != "safety-goggles":
			msg("La tempête de sable blesse %s !" % nm(b))
			_hurt(b, mx / 16)
		if w == "hail" and not has_type(b, "ice") and a not in ["magic-guard", "ice-body", "snow-cloak", "overcoat", "slush-rush"] and b.invuln == "" and it(b) != "safety-goggles":
			msg("La grêle blesse %s !" % nm(b))
			_hurt(b, mx / 16)
		if not b.alive():
			continue
		match a:
			"dry-skin":
				if bw in ["rain", "heavy-rain"]:
					_heal(b, mx / 8)
				elif bw in ["sun", "harsh-sun"]:
					_hurt(b, mx / 8)
			"solar-power":
				if bw in ["sun", "harsh-sun"]:
					_hurt(b, mx / 8)
			"rain-dish":
				if bw in ["rain", "heavy-rain"] and b.mon.hp < mx:
					_heal(b, mx / 16)
			"ice-body":
				if w in ["hail", "snow"] and b.mon.hp < mx:
					_heal(b, mx / 16)
			"hydration":
				if bw in ["rain", "heavy-rain"] and b.mon.status != "":
					b.mon.status = ""
					msg("Hydratation soigne %s !" % nm(b))
					refresh()
			"healer":
				var al := ally(b)
				if al != null and al.mon.status != "" and randi() % 10 < 3:
					al.mon.status = ""
					refresh()
		if side.future_turns > 0 and b == battler(b.side, side.future_slot):
			side.future_turns -= 1
			if side.future_turns == 0 and b.mon.hp > 0:
				msg("%s subit l'attaque prévue !" % nm(b))
				anim(b, "hit")
				_hurt(b, side.future_damage)
		if b.mon.hp <= 0:
			continue
		# Champ Herbu, Anneau Hydro, Racines, Restes, Boue Noire.
		if terrain == "grassy" and grounded(b) and b.mon.hp < mx:
			_heal(b, mx / 16)
		if b.aqua_ring and b.mon.hp < mx:
			msg("%s récupère des PV grâce à l'Anneau Hydro !" % nm(b))
			_heal(b, int(mx / 16 * (1.3 if it(b) == "big-root" else 1.0)))
		if b.ingrain and b.mon.hp < mx:
			msg("%s absorbe des nutriments avec ses racines !" % nm(b))
			_heal(b, int(mx / 16 * (1.3 if it(b) == "big-root" else 1.0)))
		var item := it(b)
		if item == "leftovers" and b.mon.hp < mx:
			msg("%s récupère des PV grâce aux Restes !" % nm(b))
			_heal(b, mx / 16)
		if item == "black-sludge":
			if has_type(b, "poison"):
				if b.mon.hp < mx:
					msg("%s récupère des PV grâce à la Boue Noire !" % nm(b))
					_heal(b, mx / 16)
			elif not magic:
				msg("%s est blessé par la Boue Noire !" % nm(b))
				_hurt(b, mx / 8)
		if b.seeded and not magic:
			var o: Battler = b.seeded_by
			var drained := mini(b.mon.hp, maxi(1, mx / 8))
			msg("Vampigraine draine l'énergie de %s !" % nm(b))
			_hurt(b, drained)
			if o != null and o.alive():
				if a == "liquid-ooze":
					_hurt(o, drained)
				else:
					_heal(o, int(drained * (1.3 if it(o) == "big-root" else 1.0)))
		if b.mon.hp <= 0:
			continue
		if not magic:
			match b.mon.status:
				"psn":
					if a == "poison-heal":
						_heal(b, mx / 8)
					else:
						msg("%s souffre du poison !" % nm(b))
						_hurt(b, mx / 8)
				"tox":
					b.toxic_n += 1
					if a == "poison-heal":
						_heal(b, mx / 8)
					else:
						msg("%s souffre du poison !" % nm(b))
						_hurt(b, mx * b.toxic_n / 16)
				"brn":
					msg("%s souffre de sa brûlure !" % nm(b))
					_hurt(b, mx / (32 if a == "heatproof" else 16))
			if b.nightmare and b.mon.status == "slp" and b.mon.hp > 0:
				msg("%s est pris dans un cauchemar !" % nm(b))
				_hurt(b, mx / 4)
			for o2: Battler in foes(b):
				if ab(o2) == "bad-dreams" and (b.mon.status == "slp" or a == "comatose") and b.mon.hp > 0:
					msg("%s fait un mauvais rêve !" % nm(b))
					_hurt(b, mx / 8)
			if b.cursed and b.mon.hp > 0:
				msg("%s est touché par la malédiction !" % nm(b))
				_hurt(b, mx / 4)
			if b.salt_cure and b.mon.hp > 0:
				msg("%s est rongé par le sel !" % nm(b))
				_hurt(b, mx / (4 if has_type(b, "water") or has_type(b, "steel") else 8))
			if b.trap_turns > 0 and b.mon.hp > 0:
				b.trap_turns -= 1
				if b.trap_turns == 0 or b.trap_by == null or not b.trap_by.alive():
					b.trap_turns = 0
					msg("%s est libéré !" % nm(b))
				else:
					msg("%s est blessé par %s !" % [nm(b), Data.move_name(_move_id(b.trap_move))])
					_hurt(b, mx / (6 if it(b.trap_by) == "binding-band" else 8))
		if b.octolock != null and b.mon.hp > 0:
			_stage(b, "def", -1, b.octolock)
			_stage(b, "spd", -1, b.octolock)
		if b.mon.status != "slp":
			b.nightmare = false
		if b.mon.hp <= 0:
			continue
		match a:
			"shed-skin":
				if b.mon.status != "" and randi() % 3 == 0:
					b.mon.status = ""
					msg("Mue soigne %s !" % nm(b))
					refresh()
			"speed-boost":
				if b.turns > 0:
					_stage(b, "spe", 1, b)
			"moody":
				var up := ["atk", "def", "spa", "spd", "spe"].filter(func(k): return b.stages[k] < 6)
				if up.size() > 0:
					var k1: String = up[randi() % up.size()]
					_stage(b, k1, 2, b)
					var down := ["atk", "def", "spa", "spd", "spe"].filter(func(k): return k != k1 and b.stages[k] > -6)
					if down.size() > 0:
						_stage(b, down[randi() % down.size()], -1, b)
			"harvest":
				if b.item == "" and Data.items.get(b.item_lost, {}).get("berry", false) and (is_sun(b) or randi() % 2 == 0):
					b.item = b.item_lost
					b.item_lost = ""
					msg("%s récolte une %s !" % [nm(b), Data.item_name(b.item)])
			"pickup":
				pass
			"slow-start":
				if b.slow_start > 0:
					b.slow_start -= 1
					if b.slow_start == 0:
						msg("%s est enfin prêt !" % nm(b))
			"hunger-switch":
				if b.mon.species == 877:
					var pid := form_pid(877, "hangry") if b.form_id == 0 else 877
					set_form(b, pid, true)
			"cud-chew":
				if b.mon.counters.has("cud"):
					var berry: String = b.mon.counters["cud"]
					b.mon.counters.erase("cud")
					_eat_berry(b, berry)
		_check_forms(b)
		# Orbes Toxique et Flamme.
		if item == "toxic-orb" and b.mon.status == "":
			_set_status(b, "tox", b, false)
		if item == "flame-orb" and b.mon.status == "":
			_set_status(b, "brn", b, false)
		if b.uproar > 0:
			b.uproar -= 1
			if b.uproar == 0:
				msg("%s se calme." % nm(b))
		if b.disable_turns > 0:
			b.disable_turns -= 1
			if b.disable_turns == 0:
				b.disable_move = 0
				msg("La capacité de %s n'est plus bloquée !" % nm(b))
		if b.encore_turns > 0:
			b.encore_turns -= 1
			if b.encore_turns == 0:
				msg("L'Encore de %s prend fin !" % nm(b))
		for key in ["taunt", "heal_block", "embargo", "magnet_rise", "telekinesis", "laser_focus", "throat_chop"]:
			if b.get(key) > 0:
				b.set(key, b.get(key) - 1)
		if b.yawn > 0:
			b.yawn -= 1
			if b.yawn == 0:
				_set_status(b, "slp", null, false)
		if b.perish > 0:
			b.perish -= 1
			msg("Le compte à rebours de %s passe à %d !" % [nm(b), b.perish])
			if b.perish == 0:
				_hurt(b, b.mon.hp)
		if b.mon.counters.get("roost", false):
			b.mon.counters.erase("roost")
			b.types = b.mon.types().duplicate() if b.form_id == 0 else Data.pokemon[b.form_id]["types"].duplicate()
		b.charged = b.charged and b.last_move == 268
		_check_hp_items(b)
	for s in sides:
		for key in ["reflect", "light_screen", "aurora_veil", "mist", "safeguard", "tailwind", "lucky_chant"]:
			if s.get(key) > 0:
				s.set(key, s.get(key) - 1)
				if s.get(key) == 0:
					msg({"reflect": "La Protection disparaît.", "light_screen": "Le Mur Lumière disparaît.",
						"aurora_veil": "Le Voile Aurore disparaît.", "mist": "La brume se dissipe.",
						"safeguard": "Le voile mystique disparaît.", "tailwind": "Le vent arrière tombe.",
						"lucky_chant": "L'Air Veinard prend fin."}[key])
		s.fainted_last_turn = false
	if terrain != "":
		terrain_turns -= 1
		if terrain_turns <= 0:
			msg("Le %s disparaît." % TERRAIN_NAMES[terrain])
			terrain = ""
			events.append({"t": "terrain", "terrain": ""})
	for key in ["trick_room", "wonder_room", "magic_room", "gravity", "fairy_lock", "mud_sport", "water_sport"]:
		if get(key) > 0:
			set(key, get(key) - 1)
			if get(key) == 0:
				match key:
					"trick_room":
						msg("L'espace-temps redevient normal.")
					"gravity":
						msg("La gravité redevient normale.")
					"wonder_room":
						msg("La Zone Étrange disparaît.")
					"magic_room":
						msg("La Zone Magique disparaît.")


## Après chaque action : remplacements, victoire ou défaite.
func _check_end() -> void:
	if over:
		return
	var enemy_left := alive_count(1)
	var player_left := alive_count(0)
	if enemy_left == 0 or player_left == 0:
		if player_left == 0:
			_lose()
		else:
			_win()
		return
	# Remplacements adverses (automatiques ; en PvP, l'autre joueur choisit).
	for k in sides[1].slots.size():
		var b: Battler = sides[1].slots[k]
		if pvp and b != null and not b.alive() and not b.empty:
			if bench(1, sides[1].slot_owner[k]).is_empty():
				b.empty = true
			elif not foe_need_switch.any(func(n): return n["slot"] == k):
				foe_need_switch.append({"slot": k, "owner": sides[1].slot_owner[k]})
			continue
		if b != null and not b.alive() and not b.empty:
			var nxt := _ai_next(sides[1].slot_owner[k])
			if nxt >= 0 and not wild:
				_send(1, k, nxt)
				_entry_ability(sides[1].slots[k])
				_entry_item(sides[1].slots[k])
			else:
				b.empty = true
	# Remplacements du joueur (il choisit).
	for k in sides[0].slots.size():
		var b2: Battler = sides[0].slots[k]
		if b2 != null and not b2.alive() and not b2.empty:
			var owner: int = sides[0].slot_owner[k]
			if bench(0, owner).is_empty():
				b2.empty = true
			elif not need_switch.any(func(n): return n["slot"] == k):
				need_switch.append({"slot": k, "owner": owner, "baton": false})


func _win() -> void:
	over = true
	result = "win"
	_finish_items()
	if pvp:
		msg("%s remporte le combat !" % owner_name(0, 0))
		events.append({"t": "end", "result": "win"})
		return
	if not wild:
		var total := 0
		for t in trainers:
			total += int(t.get("money", 100))
		for p: Battler in sides[0].slots:
			if p != null and p.mon.held_item in ["amulet-coin", "luck-incense"]:
				total *= 2
				break
		if trainers.size() >= 2:
			msg("Vous avez battu %s et %s !" % [trainers[0].get("name", ""), trainers[1].get("name", "")])
		else:
			msg("Vous avez battu %s !" % trainer.get("name", "le Dresseur"))
		for t in trainers:
			if t.get("defeat", "") != "":
				events.append({"t": "trainer_say", "text": "%s : %s" % [t.get("name", ""), t["defeat"]]})
		msg("Vous remportez %d ₽ !" % total)
	if pay_day > 0:
		msg("Vous ramassez %d ₽ !" % pay_day)
	events.append({"t": "end", "result": "win"})


func _lose() -> void:
	over = true
	result = "lose"
	_finish_items()
	if pvp:
		msg("%s remporte le combat !" % owner_name(1, 0))
		events.append({"t": "end", "result": "lose"})
		return
	msg("Vous n'avez plus de Pokémon en forme !")
	msg("Vous êtes pris de panique et perdez connaissance...")
	events.append({"t": "end", "result": "lose"})


# ---------------------------------------------------------------------------
# Fuite, Balls, objets
# ---------------------------------------------------------------------------

func _try_run() -> void:
	if over:
		return
	var p := _first_active(0)
	var e := _first_active(1)
	if p == null or e == null:
		return
	if e.mon.boss:
		msg("Impossible de fuir face à un boss !")
		return
	if ab(p) == "run-away" or has_type(p, "ghost") or it(p) == "smoke-ball":
		msg("Vous prenez la fuite !")
		over = true
		result = "run"
		_finish_items()
		events.append({"t": "end", "result": "run"})
		return
	for b: Battler in actives(0):
		if trapped(b):
			msg("Impossible de fuir !")
			return
	escape_attempts += 1
	var fast := 0.0
	for b: Battler in actives(1):
		fast = maxf(fast, speed(b))
	var f := int(speed(p) * 128 / maxf(1.0, fast)) + 30 * escape_attempts
	if speed(p) >= fast or f > 255 or randi() % 256 < f:
		msg("Vous prenez la fuite !")
		over = true
		result = "run"
		_finish_items()
		events.append({"t": "end", "result": "run"})
	else:
		msg("Impossible de fuir !")


func ball_bonus(item: String, t: Battler) -> float:
	var mon := t.mon
	var p: Battler = _first_active(0) if _first_active(0) != null else sides[0].slots[0]
	match item:
		"great-ball":
			return 1.5
		"ultra-ball":
			return 2.0
		"net-ball":
			return 3.5 if (mon.types().has("water") or mon.types().has("bug")) else 1.0
		"nest-ball":
			return maxf(1.0, (41 - mon.level) / 10.0)
		"repeat-ball":
			return 3.5 if caught_species.has(mon.species) else 1.0
		"timer-ball":
			return minf(4.0, 1.0 + turn * 1229.0 / 4096.0)
		"dusk-ball":
			return 3.5 if cave or Pokemon.time_of_day() == "night" else 1.0
		"dive-ball":
			return 3.5 if fishing else 1.0
		"quick-ball":
			return 5.0 if turn <= 1 else 1.0
		"level-ball":
			var r := float(p.mon.level) / maxf(1.0, mon.level)
			return 8.0 if r >= 4.0 else 4.0 if r >= 2.0 else 2.0 if r > 1.0 else 1.0
		"moon-ball":
			for e in mon.data()["evos"]:
				if e.get("item", "") == "moon-stone":
					return 4.0
			return 1.0
		"fast-ball":
			return 4.0 if mon.data()["base"][5] >= 100 else 1.0
		"love-ball":
			return 8.0 if p.mon.species == mon.species and p.mon.gender < 2 and mon.gender < 2 and p.mon.gender != mon.gender else 1.0
		"lure-ball":
			return 4.0 if fishing else 1.0
		"dream-ball":
			return 4.0 if mon.status == "slp" else 1.0
		"beast-ball":
			return 0.1
	return 1.0


## Probabilité qu'une Ball capture (0 à 1), formule des générations 3/4. Sert aussi aux tests.
func catch_chance(item: String, t: Battler) -> float:
	if item == "master-ball":
		return 1.0
	var rate: float = t.mon.data()["catch"]
	if item == "heavy-ball":
		var w: int = t.mon.data()["weight"]
		rate = maxf(1.0, rate + (-20 if w < 1000 else 0 if w < 2000 else 20 if w < 3000 else 30))
	if t.mon.boss:
		rate = maxf(1.0, rate / 3.0)
	var mx := float(t.mon.max_hp())
	var st := 1.0
	if t.mon.status in ["slp", "frz"]:
		st = 2.5
	elif t.mon.status != "":
		st = 1.5
	var a := ((3.0 * mx - 2.0 * t.mon.hp) * rate * ball_bonus(item, t)) / (3.0 * mx) * st
	if a >= 255.0:
		return 1.0
	var b := 1048560.0 / sqrt(sqrt(16711680.0 / maxf(1.0, a)))
	return pow(b / 65536.0, 4.0)


func _throw_ball(item: String, target_slot := -1) -> void:
	msg("%s lance une %s !" % [player_name, Data.item_name(item)])
	var targets := actives(1)
	if targets.is_empty():
		return
	var t: Battler = targets[0]
	for x in targets:
		if x.slot == target_slot:
			t = x
	if t.mon.boss:
		events.append({"t": "ball", "shakes": -1, "caught": false, "ball": item, "slot": t.slot})
		msg("Le boss dévie la Ball d'un coup de patte ! Impossible de le capturer.")
		return
	if not wild:
		events.append({"t": "ball", "shakes": -1, "caught": false, "ball": item, "slot": t.slot})
		msg("Le Dresseur dévie la Ball !")
		msg("Voler les Pokémon des autres, c'est mal !")
		return
	if t.invuln != "":
		events.append({"t": "ball", "shakes": -1, "caught": false, "ball": item, "slot": t.slot})
		msg("Raté ! La Ball n'a rien touché !")
		return
	var shakes := 0
	var ok := false
	if item == "master-ball":
		ok = true
		shakes = 3
	else:
		var p := catch_chance(item, t)
		var per_shake := pow(p, 0.25)
		for i in 4:
			if randf() < per_shake:
				shakes += 1
			else:
				break
		ok = shakes == 4
		shakes = mini(shakes, 3)
	events.append({"t": "ball", "shakes": shakes, "caught": ok, "ball": item, "slot": t.slot})
	if ok:
		msg("Et hop ! %s est attrapé !" % t.mon.name())
		t.mon.ball = item
		t.mon.boss = false
		t.mon.held_item = t.item
		t.mon.recalc_stats()
		t.mon.hp = mini(t.mon.hp, t.mon.max_hp())
		if item == "heal-ball":
			t.mon.heal_full()
		if item == "friend-ball":
			t.mon.happiness = 200
		caught = t.mon
		var thrower := actions.keys().filter(func(k): return k.side == 0 and actions[k].get("type", "") == "ball")
		caught_owner = thrower[0].owner if thrower.size() > 0 else 0
		over = true
		result = "caught"
		_finish_items()
		events.append({"t": "end", "result": "caught"})
	else:
		msg(["Oh non ! Le Pokémon s'est libéré !", "Raaah ! Ça y était presque !",
			"Aaaah ! C'était si près !", "Mince ! Il y était presque !"][shakes])


func _use_item(b: Battler, item: String, target: int, move_index: int) -> void:
	msg("%s utilise %s !" % [owner_name(0, b.owner), Data.item_name(item)])
	var stat_items := {"x-attack": "atk", "x-defense": "def", "x-sp-atk": "spa", "x-sp-def": "spd", "x-speed": "spe", "x-accuracy": "acc"}
	if stat_items.has(item):
		_stage(b, stat_items[item], 2, b)
		return
	if item == "dire-hit":
		b.crit_bonus += 2
		msg("%s est gonflé à bloc !" % nm(b))
		return
	if item == "guard-spec":
		sides[0].mist = 5
		msg("L'équipe est entourée de brume !")
		return
	var mon: Pokemon = sides[0].party[target]
	var text := ItemUse.apply(mon, item, move_index)
	if text == "":
		msg("Ça n'a aucun effet.")
		return
	for p: Battler in actives(0):
		if p.party_index == target:
			hp_event(p)
	refresh()
	for line in text.split("\n"):
		msg(line)


# ---------------------------------------------------------------------------
# IA adverse
# ---------------------------------------------------------------------------

## Dégâts estimés (en % des PV restants de la cible), sans hasard ni effet de bord.
func estimate(u: Battler, t: Battler, m: Dictionary) -> float:
	if m["cat"] == "status" or t == null:
		return 0.0
	var typ := _move_type(u, m)
	var eff := _type_eff(u, t, typ, m["ident"])
	var ta := dab(u, t)
	if eff == 0.0:
		return 0.0
	if (ta in ["volt-absorb", "lightning-rod", "motor-drive"] and typ == "electric") or (ta in ["water-absorb", "storm-drain", "dry-skin"] and typ == "water") \
			or (ta == "flash-fire" and typ == "fire") or (ta == "sap-sipper" and typ == "grass") or (ta == "levitate" and typ == "ground") \
			or (ta == "earth-eater" and typ == "ground") or (ta == "wonder-guard" and eff <= 1.0) or (ta == "well-baked-body" and typ == "fire"):
		return 0.0
	if m["ident"] in OHKO:
		return 100.0 * (0.3 if t.mon.level <= u.mon.level else 0.0)
	var dmg := 0.0
	match m["ident"]:
		"seismic-toss", "night-shade":
			dmg = u.mon.level
		"super-fang", "natures-madness", "ruination":
			dmg = t.mon.hp / 2.0
		"endeavor":
			dmg = maxf(0.0, t.mon.hp - u.mon.hp)
		"final-gambit":
			dmg = u.mon.hp
		_:
			var bp := _base_power(u, t, m)
			var save_cur := _cur_move
			_cur_move = m
			dmg = float(_calc_damage(u, t, m, _power_mods(u, t, m, typ, bp, true), eff, false, false))
			_cur_move = save_cur
	var hits := 1.0
	if m.get("min_hits", 0) > 0:
		hits = float(m["max_hits"]) if ab(u) == "skill-link" else (m["min_hits"] + m["max_hits"]) / 2.0 + (0.5 if m["max_hits"] == 5 else 0.0)
	dmg *= hits
	var acc: float = m["acc"] / 100.0 if m["acc"] > 0 else 1.0
	return dmg / maxf(1.0, t.mon.hp) * 100.0 * acc


## Plus gros dégâts qu'un adversaire peut infliger à `b` ce tour (en % de ses PV).
func threat(b: Battler) -> float:
	var worst := 0.0
	for f: Battler in foes(b):
		for mv in f.moves():
			worst = maxf(worst, estimate(f, b, move_data(mv["id"])))
	return worst


func _ai_action(b: Battler) -> Dictionary:
	if locked_move(1, b.slot) != 0:
		return {"type": "move", "slot": -1}
	var slots := usable_slots(1, b.slot)
	if slots.is_empty():
		return {"type": "move", "id": STRUGGLE}
	var targets := foes(b)
	if targets.is_empty():
		return {"type": "move", "slot": slots[0]}
	if wild and ai_level == 0:
		var t0: Battler = targets[randi() % targets.size()]
		return {"type": "move", "slot": slots[randi() % slots.size()], "target_side": 0, "target_slot": t0.slot}
	if ai_potions > 0 and b.mon.hp * 4 < b.mon.max_hp() and randi() % 2 == 0 and ai_level < 3:
		return {"type": "item"}
	# Changement stratégique (Champions et fin de jeu) : mauvais duel et meilleur remplaçant.
	if ai_level >= 2 and not wild and not trapped(b) and b.turns > 0:
		var sw := _ai_switch(b)
		if sw >= 0:
			return {"type": "switch", "index": sw}
	var best := -1
	var best_t: Battler = targets[0]
	var best_score := -1.0
	var scores := []
	for s in slots:
		var m := move_data(b.moves()[s]["id"])
		for t: Battler in targets:
			var sc := _ai_score(b, t, m)
			scores.append([s, t, sc])
			if sc > best_score:
				best_score = sc
				best = s
				best_t = t
	var precision: int = [0, 75, 92, 100][clampi(ai_level, 0, 3)]
	var out := {}
	if randi() % 100 < precision and best >= 0:
		out = {"type": "move", "slot": best, "target_side": 0, "target_slot": best_t.slot}
	else:
		var good := scores.filter(func(x): return x[2] > 0)
		if good.is_empty():
			good = scores
		var pick: Array = good[randi() % good.size()]
		out = {"type": "move", "slot": pick[0], "target_side": 0, "target_slot": pick[1].slot}
	if can_mega_evolve(b):
		out["mega"] = true
	var chosen := move_data(b.moves()[out["slot"]]["id"])
	if can_z_move(b, chosen["id"]) and chosen["cat"] != "status" and (ai_level >= 3 or b.hp_frac() < 0.5 or randi() % 3 == 0):
		out["z"] = true
	return out


## Faut-il changer de Pokémon ? Renvoie l'indice du remplaçant ou -1.
func _ai_switch(b: Battler) -> int:
	var my_best := 0.0
	for mv in b.moves():
		for f: Battler in foes(b):
			my_best = maxf(my_best, estimate(b, f, move_data(mv["id"])))
	var danger := threat(b)
	var faster := true
	for f: Battler in foes(b):
		if speed(f) > speed(b):
			faster = false
	# On reste si on peut mettre K.O. en premier, ou si le duel est correct.
	if (my_best >= 100.0 and faster) or (danger < 70.0 and my_best >= 35.0):
		return -1
	if danger < 100.0 and my_best >= 60.0:
		return -1
	var best := -1
	var best_val := -9999.0
	for i in bench(1, b.owner):
		var mon: Pokemon = sides[1].party[i]
		var val := 0.0
		for f: Battler in foes(b):
			for mv in f.moves():
				var md := move_data(mv["id"])
				if md["cat"] != "status":
					val -= Data.effectiveness(_move_type(f, md), mon.types()) * md["power"] / 40.0
			for mv2 in mon.moves:
				var md2 := move_data(mv2["id"])
				if md2["cat"] != "status":
					val += Data.effectiveness(md2["type"], all_types(f)) * md2["power"] / 60.0
		val += mon.hp * 4.0 / maxf(1.0, mon.max_hp())
		if val > best_val:
			best_val = val
			best = i
	if best < 0:
		return -1
	# Le remplaçant doit être nettement meilleur (sinon on attaque quand même).
	var cur_val := 0.0
	for f: Battler in foes(b):
		for mv in f.moves():
			var md3 := move_data(mv["id"])
			if md3["cat"] != "status":
				cur_val -= Data.effectiveness(_move_type(f, md3), all_types(b)) * md3["power"] / 40.0
	cur_val += my_best / 25.0 + b.hp_frac() * 4.0
	if best_val > cur_val + 3.0 and randi() % 100 < (60 if ai_level == 2 else 85):
		return best
	return -1


func _ai_score(b: Battler, t: Battler, m: Dictionary) -> float:
	var ident: String = m["ident"]
	var danger := threat(b) if ai_level >= 2 else 0.0
	if m["cat"] != "status":
		var pct := estimate(b, t, m)
		if pct <= 0.0:
			return 0.0
		if ident in ["self-destruct", "explosion", "misty-explosion", "final-gambit"] and b.mon.hp * 2 > b.mon.max_hp():
			pct *= 0.2
		if ident == "dream-eater" and t.mon.status != "slp":
			return 0.0
		if _attack_fails(b, t, m) and ident not in ["sucker-punch", "thunderclap", "upper-hand"]:
			return 0.0
		if (TWO_TURN.has(ident) and not (ident in ["solar-beam", "solar-blade"] and is_sun(b)) and it(b) != "power-herb") or ident in RECHARGE:
			pct *= 0.6
		var score := minf(pct, 150.0) + (60.0 if pct >= 100.0 else 0.0)
		# Achever avec une attaque prioritaire.
		if ai_level >= 2 and m["prio"] > 0 and pct >= 100.0:
			score += 40.0
		if ai_level >= 2 and pct >= 100.0 and speed(b) < speed(t) and danger >= 100.0 and m["prio"] <= 0:
			score -= 20.0
		if m.get("drain", 0) < 0 and b.hp_frac() < 0.3:
			score *= 0.7
		if ident in ["u-turn", "volt-switch", "flip-turn"] and ai_level >= 3 and danger >= 80.0:
			score += 25.0
		return score
	# Capacités de statut.
	var hp := b.hp_frac()
	match m.get("mcat", 0):
		1:
			var ail: String = m["ail"]
			if ail in ["poison", "paralysis", "burn", "sleep"]:
				if t.mon.status != "" or t.substitute > 0 or (terrain == "misty" and grounded(t)):
					return 0.0
				if ail == "paralysis" and (has_type(t, "electric") or (ident == "thunder-wave" and Data.effectiveness("electric", all_types(t)) == 0.0)):
					return 0.0
				if ail == "poison" and (has_type(t, "poison") or has_type(t, "steel")):
					return 0.0
				if ail == "burn" and has_type(t, "fire"):
					return 0.0
				if ail == "sleep" and ab(t) in ["insomnia", "vital-spirit", "sweet-veil"]:
					return 0.0
				var v := 55.0 if ail == "sleep" else 40.0
				if ail == "burn" and stat_value(t, 1) > stat_value(t, 3):
					v += 20.0
				if ail == "paralysis" and speed(t) > speed(b):
					v += 15.0
				if ident == "toxic" and t.mon.max_hp() > 200:
					v += 10.0
				return v
			if ail == "confusion":
				return 0.0 if t.confusion > 0 else 25.0
			if ident == "leech-seed":
				return 0.0 if (t.seeded or has_type(t, "grass")) else 35.0
			return 15.0
		2:
			var total := 0
			var target := t if _targets_foe(m) else b
			for sc in m["stats"]:
				var cur: int = target.stages[STAGE_KEYS[sc[0] - 1]]
				if (sc[1] > 0 and cur >= 4) or (sc[1] < 0 and cur <= -4):
					continue
				total += 1
			if total == 0:
				return 0.0
			if ai_level >= 2 and not _targets_foe(m):
				# On se renforce seulement si on n'est pas en danger immédiat.
				if danger >= 60.0 or hp < 0.6:
					return 5.0
				return 55.0 if b.turns < 3 else 25.0
			return 25.0 if b.turns < 2 else 12.0
		3:
			if hp < 0.5:
				return 75.0 if danger < 50.0 or ai_level < 2 else 45.0
			return 0.0
		11:
			match ident:
				"stealth-rock", "spikes", "toxic-spikes", "sticky-web":
					var os: BSide = sides[0]
					var already: bool = (ident == "stealth-rock" and os.stealth_rock) or (ident == "spikes" and os.spikes >= 3) \
						or (ident == "toxic-spikes" and os.toxic_spikes >= 2) or (ident == "sticky-web" and os.sticky_web)
					if already or alive_count(0) <= 1:
						return 0.0
					return 50.0 if b.turns < 2 else 20.0
				"reflect", "light-screen", "aurora-veil", "tailwind", "safeguard", "mist", "lucky-chant":
					var key := ident.replace("-", "_")
					var cur_v = sides[1].get(key) if key in ["reflect", "light_screen", "aurora_veil", "tailwind", "safeguard", "mist", "lucky_chant"] else 0
					return 0.0 if cur_v > 0 else 30.0
			return 15.0
		10:
			if ident == "trick-room":
				return 45.0 if trick_room == 0 and speed(b) < speed(t) else 0.0
			if ident.ends_with("-terrain"):
				return 0.0 if terrain == ident.split("-")[0] else 25.0
			if ident in ["rain-dance", "sunny-day", "sandstorm", "hail", "snowscape"]:
				return 0.0 if weather != "" else 25.0
	match ident:
		"rest":
			return 65.0 if hp < 0.35 else 0.0
		"protect", "detect", "kings-shield", "spiky-shield", "baneful-bunker", "obstruct", "silk-trap", "burning-bulwark":
			if b.protect_chain > 0:
				return 0.0
			if ai_level >= 3 and (t.mon.status in ["psn", "tox", "brn"] or t.seeded or t.perish > 0):
				return 40.0
			return 10.0
		"substitute":
			return 25.0 if b.substitute == 0 and hp > 0.5 else 0.0
		"taunt":
			return 30.0 if t.taunt == 0 and ai_level >= 2 else 10.0
		"encore":
			return 35.0 if t.last_move != 0 and move_data(t.last_move)["cat"] == "status" else 0.0
		"splash", "celebrate":
			return 1.0
		"memento", "healing-wish", "lunar-dance":
			return 30.0 if hp < 0.25 else 0.0
		"destiny-bond":
			return 40.0 if hp < 0.25 and speed(b) > speed(t) else 0.0
		"perish-song":
			return 10.0
		"defog", "rapid-spin", "tidy-up":
			var s0: BSide = sides[1]
			return 35.0 if s0.stealth_rock or s0.spikes > 0 or s0.toxic_spikes > 0 or s0.sticky_web else 0.0
		"haze":
			var boosts := 0
			for k in t.stages:
				boosts += maxi(0, t.stages[k])
			return 15.0 * boosts
		"belly-drum", "shell-smash", "fillet-away", "clangorous-soul", "no-retreat":
			if ai_level >= 2 and danger < 50.0 and hp > 0.6:
				return 60.0
			return 10.0
		"trick", "switcheroo":
			return 30.0 if it(b).begins_with("choice-") or it(b) in ["toxic-orb", "flame-orb", "sticky-barb", "iron-ball", "lagging-tail"] else 0.0
		"pain-split":
			return 40.0 if hp < 0.4 and t.hp_frac() > 0.6 else 0.0
		"wish":
			return 40.0 if hp < 0.6 and sides[1].wish_turns == 0 else 0.0
		"roar", "whirlwind":
			var boosted := false
			for k in t.stages:
				if t.stages[k] >= 2:
					boosted = true
			return 45.0 if boosted else 5.0
	return 15.0


func _ai_use_potion(b: Battler) -> void:
	ai_potions -= 1
	var amount := 60 if b.mon.level < 30 else 120 if b.mon.level < 60 else 200
	msg("%s utilise une %s !" % [owner_name(1, b.owner), "Super Potion" if amount == 60 else "Hyper Potion" if amount == 120 else "Potion Max"])
	_heal(b, amount)
	msg("%s récupère des PV !" % nm(b))


func _ai_next(owner: int) -> int:
	var t := _first_active(0)
	var best := -1
	var best_score := -999.0
	for i in bench(1, owner):
		var mon: Pokemon = sides[1].party[i]
		var sc := 0.0
		for mv in mon.moves:
			var md := move_data(mv["id"])
			if md["cat"] != "status" and t != null:
				sc = maxf(sc, Data.effectiveness(md["type"], all_types(t)) * (1.5 if mon.types().has(md["type"]) else 1.0))
		if t != null:
			for ty in all_types(t):
				sc -= Data.effectiveness(ty, mon.types()) * 0.5
		sc += float(mon.hp) / maxf(1.0, mon.max_hp()) * 0.5
		if sc > best_score:
			best_score = sc
			best = i
	return best


# ---------------------------------------------------------------------------
# Copie de l'état (combat coop : l'hôte calcule, l'invité affiche)
# ---------------------------------------------------------------------------

const SYNC_FIELDS := ["party_index", "owner", "fainted", "empty", "types", "stages", "transformed", "t_moves", "t_stats",
	"substitute", "invuln", "recharge", "charging", "rampage", "rampage_move", "rollout", "uproar", "disable_move",
	"disable_turns", "encore_move", "encore_turns", "taunt", "torment", "confusion", "last_move", "imprison", "item",
	"form_id", "f_stats", "mega", "choice_move", "heal_block", "throat_chop", "ability"]
const SIDE_SYNC := ["reflect", "light_screen", "aurora_veil", "mist", "safeguard", "tailwind", "lucky_chant",
	"spikes", "toxic_spikes", "stealth_rock", "sticky_web"]


func snapshot() -> Dictionary:
	var out := []
	for side: BSide in sides:
		var slots := []
		for b in side.slots:
			if b == null:
				slots.append(null)
				continue
			var d := {}
			for f in SYNC_FIELDS:
				d[f] = b.get(f)
			slots.append(d)
		out.append({"party": side.party.map(func(m): return m.to_dict()), "owners": side.owners, "slot_owner": side.slot_owner,
			"names": side.names, "slots": slots, "mega_used": side.mega_used, "z_used": side.z_used,
			"field": SIDE_SYNC.map(func(f): return side.get(f))})
	return {"sides": out, "need_switch": need_switch, "over": over, "result": result, "wild": wild, "turn": turn,
		"weather": weather, "terrain": terrain, "trick_room": trick_room, "trainers": trainers,
		"can_mega": can_mega, "can_z": can_z, "mega_owners": mega_owners, "z_owners": z_owners,
		"weather_turns": weather_turns, "terrain_turns": terrain_turns, "gravity": gravity,
		"magic_room": magic_room, "wonder_room": wonder_room, "aura": aura}


func apply_snapshot(d: Dictionary) -> void:
	wild = d["wild"]
	over = d["over"]
	result = d["result"]
	turn = d["turn"]
	weather = d["weather"]
	terrain = d.get("terrain", "")
	trick_room = d.get("trick_room", 0)
	need_switch = d["need_switch"]
	trainers = d.get("trainers", trainers)
	trainer = trainers[0] if trainers.size() > 0 else {}
	can_mega = d.get("can_mega", can_mega)
	can_z = d.get("can_z", can_z)
	mega_owners = d.get("mega_owners", mega_owners)
	z_owners = d.get("z_owners", z_owners)
	weather_turns = d.get("weather_turns", weather_turns)
	terrain_turns = d.get("terrain_turns", terrain_turns)
	gravity = d.get("gravity", gravity)
	magic_room = d.get("magic_room", magic_room)
	wonder_room = d.get("wonder_room", wonder_room)
	aura = d.get("aura", aura)
	for k in 2:
		var sd: Dictionary = d["sides"][k]
		var side: BSide = sides[k]
		side.party = sd["party"].map(func(x): return Pokemon.from_dict(x))
		side.owners = sd["owners"]
		side.slot_owner = sd["slot_owner"]
		side.names = sd["names"]
		side.mega_used = sd.get("mega_used", {})
		side.z_used = sd.get("z_used", {})
		var fv: Array = sd.get("field", [])
		for i in mini(fv.size(), SIDE_SYNC.size()):
			side.set(SIDE_SYNC[i], fv[i])
		side.slots = []
		for bd in sd["slots"]:
			if bd == null:
				side.slots.append(null)
				continue
			var b := Battler.new()
			for f in SYNC_FIELDS:
				if bd.has(f):
					b.set(f, bd[f])
			b.side = k
			b.slot = side.slots.size()
			b.mon = side.party[b.party_index]
			if not bd.has("ability"):
				b.ability = b.mon.ability
			side.slots.append(b)


# ---------------------------------------------------------------------------
# PvP : point de vue de l'autre joueur (camps inversés)
# ---------------------------------------------------------------------------

static func flip_text(t: String) -> String:
	return t.replace("\u00010|", "\u0003").replace("\u00011|", "\u00010|").replace("\u0003", "\u00011|")


## Remplace les jetons de nom par le nom (et « adverse » pour le camp d'en face).
static func resolve_text(t: String) -> String:
	if not t.contains("\u0001"):
		return t
	var out := ""
	var i := 0
	while i < t.length():
		var c := t[i]
		if c == "\u0001":
			var j := t.find("\u0002", i)
			if j < 0:
				break
			var tok := t.substr(i + 1, j - i - 1)
			var side := int(tok.get_slice("|", 0))
			out += tok.get_slice("|", 1) + (" adverse" if side == 1 else "")
			i = j + 1
		else:
			out += c
			i += 1
	return out


static func flip_events(evs: Array) -> Array:
	var out := []
	for e in evs:
		var c: Dictionary = e.duplicate(true)
		c.erase("mon")
		for k in ["side", "tside"]:
			if c.has(k):
				c[k] = 1 - int(c[k])
		if c.get("t", "") == "field" and c.has("sides"):
			c["sides"] = [c["sides"][1], c["sides"][0]]
		if c.get("t", "") == "end":
			c["result"] = {"win": "lose", "lose": "win"}.get(c["result"], c["result"])
		if c.has("text"):
			c["text"] = flip_text(c["text"])
		out.append(c)
	return out


static func flip_snapshot(d: Dictionary, host_name: String) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	c["sides"] = [d["sides"][1], d["sides"][0]]
	c["can_mega"] = [d["can_mega"][1], d["can_mega"][0]]
	c["can_z"] = [d["can_z"][1], d["can_z"][0]]
	c["mega_owners"] = []
	c["z_owners"] = []
	c["need_switch"] = []
	c["trainers"] = [{"name": host_name}]
	c["result"] = {"win": "lose", "lose": "win"}.get(d["result"], d["result"])
	return c
