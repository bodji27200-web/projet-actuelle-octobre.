class_name Battle
extends RefCounted
## Moteur de combat (simple, 1 contre 1). Ne dessine rien : chaque action renvoie une liste
## d'événements ({"t": "msg"/"hp"/"send"/"faint"/...}) que l'écran de combat joue ensuite.

const STAGE_KEYS := ["hp", "atk", "def", "spa", "spd", "spe", "acc", "eva"]
const STAT_LABEL := {"atk": "L'Attaque", "def": "La Défense", "spa": "L'Attaque Spéciale",
	"spd": "La Défense Spéciale", "spe": "La Vitesse", "acc": "La Précision", "eva": "L'Esquive"}
const STRUGGLE := 165
const SELF_TARGETS := ["user", "users-field", "user-and-allies", "all-allies", "user-or-ally"]
const SOUND := ["growl", "roar", "sing", "supersonic", "screech", "snore", "uproar", "hyper-voice",
	"perish-song", "heal-bell", "metal-sound", "grass-whistle"]
const PUNCH := ["mega-punch", "fire-punch", "ice-punch", "thunder-punch", "comet-punch", "dizzy-punch",
	"dynamic-punch", "focus-punch", "mach-punch", "meteor-mash", "shadow-punch", "sky-uppercut"]
const NON_CONTACT := ["earthquake", "magnitude", "rock-throw", "rock-tomb", "bone-club", "bonemerang",
	"bone-rush", "egg-bomb", "barrage", "pin-missile", "spike-cannon", "twineedle", "fissure",
	"self-destruct", "explosion", "sand-tomb", "rock-blast", "bullet-seed", "icicle-spear",
	"poison-sting", "razor-leaf", "present", "secret-power", "pay-day", "sky-attack", "spit-up"]
const TWO_TURN := {"fly": "%s s'envole !", "dig": "%s s'enterre !", "dive": "%s plonge !",
	"bounce": "%s bondit très haut !", "solar-beam": "%s absorbe la lumière !",
	"skull-bash": "%s baisse la tête !", "sky-attack": "%s est entouré d'une lumière intense !",
	"razor-wind": "%s crée un tourbillon !"}
const SEMI_INVULN := ["fly", "dig", "dive", "bounce"]
const OHKO := ["fissure", "guillotine", "horn-drill", "sheer-cold"]
const RAMPAGE := ["thrash", "petal-dance", "outrage"]
const STATUS_TEXT := {"psn": "%s est empoisonné !", "tox": "%s est gravement empoisonné !",
	"par": "%s est paralysé ! Il aura du mal à attaquer !", "slp": "%s s'endort !",
	"brn": "%s est brûlé !", "frz": "%s est gelé !"}
const AILMENT_STATUS := {"paralysis": "par", "sleep": "slp", "freeze": "frz", "burn": "brn", "poison": "psn"}
const TRAP_TEXT := {"bind": "%s est ligoté !", "wrap": "%s est ligoté !", "fire-spin": "%s est piégé dans un tourbillon de feu !",
	"clamp": "%s est pris dans la Claquoir !", "sand-tomb": "%s est piégé par le Tourbi-Sable !"}


const SPREAD_TARGETS := ["all-opponents", "all-other-pokemon"]


class Battler:
	var mon: Pokemon
	var side := 0
	var slot := 0
	var owner := 0
	var party_index := 0
	var stages := {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0, "acc": 0, "eva": 0}
	var types: Array = []
	var ability := 0
	var confusion := 0
	var flinch := false
	var seeded := false
	var seeded_by: Battler = null
	var substitute := 0
	var trap_turns := 0
	var trap_move := ""
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
	var endure := false
	var focus_energy := false
	var rage := false
	var last_move := 0
	var transformed := false
	var t_moves: Array = []
	var t_stats: Array = []
	var cursed := false
	var nightmare := false
	var perish := 0
	var destiny_bond := false
	var grudge := false
	var ingrain := false
	var yawn := 0
	var charged := false
	var stockpile := 0
	var curled := false
	var minimized := false
	var foresight := false
	var mean_look := false
	var attract := false
	var torment := false
	var uproar := 0
	var lock_on := false
	var rollout := 0
	var fury_cutter := 0
	var turns := 0
	var toxic_n := 0
	var flash_fire := false
	var imprison := false
	var moved := false
	var hit_phys := 0
	var hit_spec := 0
	var hit_by_foe := false
	var fainted := false
	var empty := false

	func moves() -> Array:
		return t_moves if transformed else mon.moves

	func raw(i: int) -> int:
		return t_stats[i] if transformed else mon.stats[i]

	func alive() -> bool:
		return not empty and not fainted and mon.hp > 0


class BSide:
	var party: Array = []      # tous les Pokémon du camp (plusieurs dresseurs possibles)
	var owners: Array = []     # propriétaire de chaque Pokémon (indice de dresseur)
	var slots: Array = []      # Battler sur le terrain, un par emplacement
	var slot_owner: Array = [] # dresseur qui contrôle chaque emplacement
	var names: Array = []      # nom de chaque dresseur du camp
	var reflect := 0
	var light_screen := 0
	var mist := 0
	var safeguard := 0
	var spikes := 0
	var future_turns := 0
	var future_damage := 0

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
var ai_potions := 0
var pay_day := 0
var caught: Pokemon = null
var caught_owner := 0
var caught_species := []
var mud_sport := false
var water_sport := false
var actions := {}
var _spread := false
## Tests : force la réussite des jets de précision.
var always_hit := false
## Multi Exp activé, par dresseur du camp du joueur.
var exp_share: Array = [false, false]


## p_parties / e_parties : une équipe par dresseur du camp.
## opts : double (2 emplacements même avec un seul dresseur), boss (le Pokémon adverse est un boss).
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
		out.sort_custom(func(a, c): return speed(a) > speed(c))
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
	if b.side == 0:
		return b.mon.name()
	return b.mon.name() + (" sauvage" if wild else " ennemi")


func ab(b: Battler) -> String:
	if b == null:
		return ""
	for o: Battler in _on_field():
		if o != b and Data.ability_ident(o.ability) == "neutralizing-gas":
			return ""
	return Data.ability_ident(b.ability)


func weather_on() -> String:
	for b: Battler in _on_field():
		if Data.ability_ident(b.ability) == "cloud-nine":
			return ""
	return weather


func move_data(id: int) -> Dictionary:
	return Data.moves[id]


func hp_event(b: Battler) -> void:
	events.append({"t": "hp", "side": b.side, "slot": b.slot, "hp": b.mon.hp, "max": b.mon.max_hp()})


func anim(b: Battler, kind: String) -> void:
	events.append({"t": "anim", "side": b.side, "slot": b.slot, "kind": kind})


func refresh() -> void:
	events.append({"t": "refresh"})


func stage_mult(s: int) -> float:
	return (2.0 + s) / 2.0 if s >= 0 else 2.0 / (2.0 - s)


func acc_mult(s: int) -> float:
	return (3.0 + s) / 3.0 if s >= 0 else 3.0 / (3.0 - s)


func speed(b: Battler) -> float:
	var v: float = b.raw(5) * stage_mult(b.stages["spe"])
	if b.mon.status == "par":
		v *= 0.5
	var w := weather_on()
	if (w == "rain" and ab(b) == "swift-swim") or (w == "sun" and ab(b) == "chlorophyll"):
		v *= 2.0
	return v


func is_grounded_immune(b: Battler) -> bool:
	return b.types.has("flying") or ab(b) == "levitate"


func trapped(b: Battler) -> bool:
	if b.types.has("ghost"):
		return false
	for o: Battler in foes(b):
		if ab(o) == "arena-trap" and not is_grounded_immune(b):
			return true
	return b.trap_turns > 0 or b.mean_look or b.ingrain


func battler(side_i: int, slot: int) -> Battler:
	var s: BSide = sides[side_i]
	return s.slots[slot] if slot < s.slots.size() else null


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
	if m["pp"] <= 0:
		return false
	if b.disable_move == id:
		return false
	if b.encore_turns > 0 and b.encore_move != id:
		return false
	if b.taunt > 0 and move_data(id)["cat"] == "status":
		return false
	if b.torment and b.last_move == id:
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
		return 205
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
		else:
			msg("Un %s sauvage apparaît !" % names[0])
		if e.party[0].boss:
			msg("%s dégage une aura terrifiante ! C'est un Pokémon BOSS !" % names[0])
	else:
		if trainers.size() >= 2:
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
	_entry_abilities()
	return flush()


func _next_for_slot(side_i: int, slot: int) -> int:
	var s: BSide = sides[side_i]
	var owner: int = s.slot_owner[slot]
	var b := bench(side_i, owner)
	return b[0] if b.size() > 0 else -1


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
	if keep_stages and old != null:
		b.stages = old.stages.duplicate()
		b.confusion = old.confusion
		b.substitute = old.substitute
		b.seeded = old.seeded
		b.seeded_by = old.seeded_by
		b.focus_energy = old.focus_energy
		b.cursed = old.cursed
		b.perish = old.perish
		b.ingrain = old.ingrain
	side.slots[slot] = b
	if side_i == 0:
		for e: Battler in actives(1):
			_add_participant(e.party_index, idx)
	else:
		participants[idx] = []
		for p: Battler in actives(0):
			_add_participant(idx, p.party_index)
	if announce:
		if side_i == 0:
			msg("Go ! %s !" % b.mon.name() if b.owner == 0 or sides[0].names.size() < 2 else "%s envoie %s !" % [owner_name(0, b.owner), b.mon.name()])
		else:
			msg("%s envoie %s !" % [owner_name(1, b.owner), b.mon.name()])
	events.append({"t": "send", "side": side_i, "slot": slot, "mon": b.mon, "index": idx, "owner": b.owner})
	if side.spikes > 0 and not is_grounded_immune(b):
		var frac: int = [8, 6, 4][side.spikes - 1]
		msg("%s est blessé par les picots !" % nm(b))
		_hurt(b, maxi(1, b.mon.max_hp() / frac))


func _add_participant(enemy_idx: int, player_idx: int) -> void:
	if not participants.has(enemy_idx):
		participants[enemy_idx] = []
	if not participants[enemy_idx].has(player_idx):
		participants[enemy_idx].append(player_idx)


func _entry_abilities() -> void:
	for b: Battler in actives():
		_entry_ability(b)


func _entry_ability(b: Battler) -> void:
	if b == null or not b.alive():
		return
	var o := foe(b)
	match ab(b):
		"intimidate":
			msg("Intimidation de %s !" % nm(b))
			for f: Battler in foes(b):
				_stage(f, "atk", -1, b)
		"trace":
			if o != null and o.ability != 0 and Data.ability_ident(o.ability) != "trace":
				b.ability = o.ability
				msg("%s copie le talent %s !" % [nm(b), Data.ability_name(o.ability)])
		"download":
			if o != null:
				var stat := "atk" if o.raw(2) * stage_mult(o.stages["def"]) < o.raw(4) * stage_mult(o.stages["spd"]) else "spa"
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
		"pressure":
			msg("%s exerce sa Pression !" % nm(b))
		"mold-breaker":
			msg("%s brise le moule !" % nm(b))
		"neutralizing-gas":
			msg("Un gaz inhibiteur se répand !")


func _switch_out(b: Battler) -> void:
	if ab(b) == "natural-cure" and b.mon.status != "":
		b.mon.status = ""
	for o: Battler in foes(b):
		o.mean_look = false
		o.attract = false


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
	_entry_ability(sides[0].slots[slot])
	for n in need_switch.duplicate():
		if bench(0, n["owner"]).is_empty():
			need_switch.erase(n)
			var eb: Battler = sides[0].slots[n["slot"]]
			if eb != null and not eb.alive():
				eb.empty = true
	_check_end()
	return flush()


# ---------------------------------------------------------------------------
# Tour de combat
# ---------------------------------------------------------------------------

## actions : {emplacement_joueur: action}. Une action seule est acceptée pour le combat simple.
func play_turn(player_actions: Dictionary) -> Array:
	if player_actions.has("type"):
		player_actions = {0: player_actions}
	turn += 1
	for b: Battler in actives():
		b.flinch = false
		b.protected = false
		b.endure = false
		b.moved = false
		b.hit_phys = 0
		b.hit_spec = 0
		b.hit_by_foe = false
	actions = {}
	for k in player_actions:
		var b := battler(0, int(k))
		if b != null and b.alive():
			actions[b] = player_actions[k]
	for b: Battler in actives(1):
		actions[b] = _ai_action(b)

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
				msg("%s, reviens !" % b.mon.name())
				events.append({"t": "recall", "side": 0, "slot": b.slot})
				_switch_out(b)
				_send(0, b.slot, a["index"])
				_entry_ability(sides[0].slots[b.slot])
		if over:
			return flush()
	for b: Battler in actives(1):
		var a2: Dictionary = actions.get(b, {})
		if a2.get("type", "") == "item":
			_ai_use_potion(b)
		elif a2.get("type", "") == "switch":
			msg("%s rappelle %s !" % [owner_name(1, b.owner), b.mon.name()])
			events.append({"t": "recall", "side": 1, "slot": b.slot})
			_switch_out(b)
			_send(1, b.slot, a2["index"])
			_entry_ability(sides[1].slots[b.slot])

	# Capacités : priorité, puis vitesse.
	var movers := []
	for b: Battler in actions:
		if actions[b].get("type", "") == "move" and is_instance_valid(b) and sides[b.side].slots[b.slot] == b:
			movers.append(b)
	movers.shuffle()
	movers.sort_custom(func(a, c):
		var pa := _priority(a)
		var pc := _priority(c)
		if pa != pc:
			return pa > pc
		return speed(a) > speed(c))
	for b: Battler in movers:
		if over:
			break
		if not b.alive() or sides[b.side].slots[b.slot] != b:
			continue
		_do_move(b, actions[b])
		b.moved = true
		_check_end()
	if not over:
		_end_of_turn()
		_check_end()
	return flush()


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
	return move_data(_action_move_id(b))["prio"]


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
	if a.has("target_slot") and not a.has("target_side"):
		for o in f:
			if o.slot == a["target_slot"]:
				return o
	return f[randi() % f.size()] if f.size() > 1 and not a.has("target_slot") else f[0]


func _do_move(u: Battler, action: Dictionary) -> void:
	if u.recharge:
		u.recharge = false
		msg("%s doit se reposer !" % nm(u))
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
		u.invuln = ""
		u.rampage = 0
		u.rollout = 0
		u.uproar = 0
		u.fury_cutter = 0
		return
	if not continuing and id != STRUGGLE:
		if not can_use(u, slot):
			msg("%s ne peut pas utiliser %s !" % [nm(u), Data.move_name(id)])
			return
		var cost := 1
		for f: Battler in foes(u):
			if ab(f) == "pressure":
				cost = 2
		u.moves()[slot]["pp"] = maxi(0, u.moves()[slot]["pp"] - cost)
		u.charge_target = action.duplicate()
	if id == STRUGGLE and not continuing:
		msg("%s n'a plus de capacité utilisable !" % nm(u))
	msg("%s utilise %s !" % [nm(u), Data.move_name(id)])
	var m := move_data(id)
	if id != 118 and id != 119:
		u.last_move = id
	if m["ident"] != "rage":
		u.rage = false
	if m["ident"] != "fury-cutter":
		u.fury_cutter = 0
	if m["ident"] not in ["protect", "detect", "endure"]:
		u.protect_chain = 0
	# Capacités qui touchent plusieurs Pokémon.
	if m["target"] in SPREAD_TARGETS and not TWO_TURN.has(m["ident"]):
		var targets := foes(u) if m["target"] == "all-opponents" else actives().filter(func(x): return x != u)
		if targets.is_empty():
			_fail()
		else:
			_spread = targets.size() > 1
			for t2: Battler in targets:
				if t2.alive() and u.alive():
					_execute(u, t2, m)
			_spread = false
	else:
		if t == null and _targets_foe(m):
			_fail()
		else:
			_execute(u, t if t != null else foe(u), m)
	if u.alive() and u.rampage > 0 and m["ident"] in RAMPAGE:
		u.rampage -= 1
		if u.rampage == 0:
			msg("%s est épuisé par sa colère !" % nm(u))
			_confuse(u, u, true)


func _can_act(u: Battler, id: int) -> bool:
	var mon := u.mon
	var ident: String = move_data(id)["ident"]
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
	if mon.status == "frz":
		if randi() % 5 == 0 or ident in ["flame-wheel", "sacred-fire"]:
			mon.status = ""
			msg("%s n'est plus gelé !" % nm(u))
			refresh()
		else:
			msg("%s est gelé ! Il ne peut pas bouger !" % nm(u))
			return false
	if u.flinch:
		msg("%s a peur et ne peut pas attaquer !" % nm(u))
		return false
	if u.confusion > 0:
		u.confusion -= 1
		if u.confusion == 0:
			msg("%s n'est plus confus !" % nm(u))
		else:
			msg("%s est confus..." % nm(u))
			if randi() % 3 == 0:
				msg("Il se blesse dans sa confusion !")
				var a: float = u.raw(1) * stage_mult(u.stages["atk"])
				var d: float = u.raw(2) * stage_mult(u.stages["def"])
				var dmg := int(int(int(2 * u.mon.level / 5 + 2) * 40 * a / d) / 50) + 2
				anim(u, "hit")
				_hurt(u, dmg)
				return false
	if mon.status == "par" and randi() % 4 == 0:
		msg("%s est paralysé ! Il ne peut pas attaquer !" % nm(u))
		return false
	if u.attract:
		msg("%s est amoureux !" % nm(u))
		if randi() % 2 == 0:
			msg("L'amour empêche %s d'attaquer !" % nm(u))
			return false
	return true


func _execute(u: Battler, t: Battler, m: Dictionary) -> void:
	var ident: String = m["ident"]
	# Capacités en deux tours.
	if TWO_TURN.has(ident):
		if u.charging != m["id"]:
			if not (ident == "solar-beam" and weather_on() == "sun"):
				u.charging = m["id"]
				msg(TWO_TURN[ident] % nm(u))
				if SEMI_INVULN.has(ident):
					u.invuln = ident
					events.append({"t": "hide", "side": u.side, "slot": u.slot, "on": true})
				if ident == "skull-bash":
					_stage(u, "def", 1, u)
				return
		u.charging = 0
		if u.invuln != "":
			u.invuln = ""
			events.append({"t": "hide", "side": u.side, "slot": u.slot, "on": false})
	if _special_move(u, t, m):
		return
	if m["cat"] == "status":
		_status_move(u, t, m)
	else:
		_damage_move(u, t, m)


func _targets_foe(m: Dictionary) -> bool:
	return not SELF_TARGETS.has(m["target"]) and m["target"] not in ["entire-field", "opponents-field"]


func _fail() -> void:
	msg("Mais cela échoue !")


func _hits(u: Battler, t: Battler, m: Dictionary) -> bool:
	if always_hit and t.invuln == "":
		return true
	var ident: String = m["ident"]
	if t.invuln != "":
		var ok := false
		match t.invuln:
			"fly", "bounce":
				ok = ident in ["gust", "twister", "thunder", "sky-uppercut"]
			"dig":
				ok = ident in ["earthquake", "magnitude", "fissure"]
			"dive":
				ok = ident in ["surf", "whirlpool"]
		if not ok and ab(u) != "no-guard" and ab(t) != "no-guard":
			return false
	var acc: int = m["acc"]
	var w := weather_on()
	if ident == "thunder":
		if w == "rain":
			return true
		if w == "sun":
			acc = 50
	if ident == "blizzard" and w == "hail":
		return true
	if acc == 0 or ab(u) == "no-guard" or ab(t) == "no-guard":
		return true
	if u.lock_on:
		u.lock_on = false
		return true
	var eva: int = 0 if t.foresight else t.stages["eva"]
	var s := clampi(u.stages["acc"] - eva, -6, 6)
	if ab(u) == "keen-eye" and s < 0 and u.stages["acc"] >= 0:
		s = maxi(s, 0)
	var p := acc * acc_mult(s)
	if ab(u) == "compound-eyes":
		p *= 1.3
	if ab(t) == "sand-veil" and w == "sandstorm":
		p *= 0.8
	if ab(t) == "tangled-feet" and t.confusion > 0:
		p *= 0.5
	return randf() * 100.0 < p


func _move_type(u: Battler, m: Dictionary) -> String:
	if m["ident"] == "hidden-power":
		return u.mon.hidden_power_type()
	return m["type"]


func _type_eff(u: Battler, t: Battler, typ: String, ident: String) -> float:
	var tt := t.types.duplicate()
	if (t.foresight or ab(u) == "scrappy") and typ in ["normal", "fighting"]:
		tt.erase("ghost")
	var e := Data.effectiveness(typ, tt)
	if typ == "ground" and ab(t) == "levitate":
		e = 0.0
	return e


## Talents qui absorbent ou annulent une attaque. Renvoie true si l'attaque est stoppée.
func _absorb(u: Battler, t: Battler, typ: String, ident: String) -> bool:
	match ab(t):
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
		"lightning-rod":
			if typ == "electric":
				msg("Paratonnerre de %s attire l'attaque !" % nm(t))
				_stage(t, "spa", 1, t)
				return true
		"flash-fire":
			if typ == "fire":
				t.flash_fire = true
				msg("Torche de %s renforce ses attaques Feu !" % nm(t))
				return true
		"soundproof":
			if SOUND.has(ident):
				msg("Anti-Bruit de %s le protège !" % nm(t))
				return true
		"damp":
			if ident in ["self-destruct", "explosion"]:
				msg("Moiteur de %s empêche l'explosion !" % nm(t))
				return true
	return false


func _power(u: Battler, t: Battler, m: Dictionary) -> int:
	var ident: String = m["ident"]
	var p: int = m["power"]
	match ident:
		"flail", "reversal":
			var r := int(48 * u.mon.hp / u.mon.max_hp())
			p = 200 if r < 2 else 150 if r < 5 else 100 if r < 10 else 80 if r < 17 else 40 if r < 33 else 20
		"return":
			p = maxi(1, int(u.mon.happiness * 10 / 25))
		"frustration":
			p = maxi(1, int((255 - u.mon.happiness) * 10 / 25))
		"low-kick":
			var w: int = t.mon.data()["weight"]
			p = 20 if w < 100 else 40 if w < 250 else 60 if w < 500 else 80 if w < 1000 else 100 if w < 2000 else 120
		"rollout":
			p = 30 * int(pow(2, 5 - maxi(1, u.rollout))) * (2 if u.curled else 1)
		"fury-cutter":
			p = mini(160, 40 * int(pow(2, u.fury_cutter)))
		"spit-up":
			p = 100 * u.stockpile
		"facade":
			if u.mon.status != "":
				p *= 2
		"revenge":
			if u.hit_by_foe:
				p *= 2
		"hidden-power":
			p = 60
		"earthquake", "magnitude":
			if t.invuln == "dig":
				p *= 2
		"surf":
			if t.invuln == "dive":
				p *= 2
		"gust", "twister":
			if t.invuln in ["fly", "bounce"]:
				p *= 2
		"stomp":
			if t.minimized:
				p *= 2
		"solar-beam":
			if weather_on() in ["rain", "sandstorm", "hail"]:
				p /= 2
	var typ := _move_type(u, m)
	var f := 1.0
	if u.charged and typ == "electric":
		f *= 2.0
	if mud_sport and typ == "electric":
		f *= 0.5
	if water_sport and typ == "fire":
		f *= 0.5
	match ab(u):
		"technician":
			if p <= 60:
				f *= 1.5
		"iron-fist":
			if PUNCH.has(ident):
				f *= 1.2
		"reckless":
			if m["drain"] < 0 or ident in ["jump-kick", "high-jump-kick"]:
				f *= 1.2
		"overgrow", "blaze", "torrent", "swarm":
			var boosted: String = {"overgrow": "grass", "blaze": "fire", "torrent": "water", "swarm": "bug"}[ab(u)]
			if typ == boosted and u.mon.hp * 3 <= u.mon.max_hp():
				f *= 1.5
		"rivalry":
			if u.mon.gender < 2 and t.mon.gender < 2:
				f *= 1.25 if u.mon.gender == t.mon.gender else 0.75
	if u.flash_fire and typ == "fire":
		f *= 1.5
	match ab(t):
		"thick-fat":
			if typ in ["fire", "ice"]:
				f *= 0.5
		"dry-skin":
			if typ == "fire":
				f *= 1.25
	return maxi(1, int(p * f))


func _calc_damage(u: Battler, t: Battler, m: Dictionary, power: int, eff: float, crit: bool) -> int:
	var phys: bool = m["cat"] == "physical"
	var ak := "atk" if phys else "spa"
	var dk := "def" if phys else "spd"
	var sa: int = u.stages[ak]
	var sd: int = t.stages[dk]
	if crit:
		sa = maxi(sa, 0)
		sd = mini(sd, 0)
	var a: float = u.raw(1 if phys else 3) * stage_mult(sa)
	var d: float = t.raw(2 if phys else 4) * stage_mult(sd)
	if phys and ab(u) == "guts" and u.mon.status != "":
		a *= 1.5
	var dmg := int(int(int(2 * u.mon.level / 5 + 2) * power * a / maxf(1.0, d)) / 50) + 2
	var typ := _move_type(u, m)
	var w := weather_on()
	if (w == "sun" and typ == "fire") or (w == "rain" and typ == "water"):
		dmg = int(dmg * 1.5)
	elif (w == "sun" and typ == "water") or (w == "rain" and typ == "fire"):
		dmg = int(dmg * 0.5)
	if crit:
		dmg = int(dmg * (2.25 if ab(u) == "sniper" else 1.5))
	if _spread:
		dmg = int(dmg * 0.75)
	dmg = int(dmg * randi_range(85, 100) / 100.0)
	if u.types.has(typ):
		dmg = int(dmg * (2.0 if ab(u) == "adaptability" else 1.5))
	dmg = int(dmg * eff)
	if eff < 1.0 and ab(u) == "tinted-lens":
		dmg *= 2
	if eff > 1.0 and ab(t) == "filter":
		dmg = int(dmg * 0.75)
	if phys and u.mon.status == "brn" and ab(u) != "guts":
		dmg = int(dmg * 0.5)
	if not crit:
		var ts: BSide = sides[t.side]
		if (phys and ts.reflect > 0) or (not phys and ts.light_screen > 0):
			dmg = int(dmg * 0.5)
	return maxi(1, dmg)


func _crit(u: Battler, t: Battler, m: Dictionary) -> bool:
	if ab(t) in ["battle-armor", "shell-armor"]:
		return false
	var stage: int = m["crit"] + (2 if u.focus_energy else 0)
	var odds: int = [24, 8, 2, 1][mini(stage, 3)]
	return randi() % odds == 0


func _damage_move(u: Battler, t: Battler, m: Dictionary) -> void:
	var ident: String = m["ident"]
	if t == null or t.mon.hp <= 0:
		_fail()
		return
	var typ := _move_type(u, m)
	if t.protected:
		msg("%s se protège !" % nm(t))
		_end_rollout(u)
		return
	if OHKO.has(ident):
		_ohko(u, t, m)
		return
	if not _hits(u, t, m):
		msg("%s évite l'attaque !" % nm(t))
		_end_rollout(u)
		if ident in ["jump-kick", "high-jump-kick"]:
			msg("%s s'écrase au sol !" % nm(u))
			_hurt(u, u.mon.max_hp() / 2)
		return
	var eff := _type_eff(u, t, typ, ident)
	if _absorb(u, t, typ, ident):
		return
	if eff == 0.0:
		msg("Ça n'affecte pas %s..." % nm(t))
		_end_rollout(u)
		if ident in ["jump-kick", "high-jump-kick"]:
			msg("%s s'écrase au sol !" % nm(u))
			_hurt(u, u.mon.max_hp() / 2)
		return

	# Dégâts fixes.
	var fixed := -1
	match ident:
		"seismic-toss", "night-shade":
			fixed = u.mon.level
		"dragon-rage":
			fixed = 40
		"sonic-boom":
			fixed = 20
		"super-fang":
			fixed = maxi(1, t.mon.hp / 2)
		"psywave":
			fixed = maxi(1, int(u.mon.level * randi_range(50, 150) / 100))
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
		"spit-up":
			if u.stockpile == 0:
				_fail()
				return
		"present":
			var r := randi() % 10
			if r < 2:
				msg("%s récupère des PV !" % nm(t))
				_heal(t, t.mon.max_hp() / 4)
				return
	if ident == "magnitude":
		var r := randi() % 100
		var lv := 4 if r < 5 else 5 if r < 15 else 6 if r < 35 else 7 if r < 65 else 8 if r < 85 else 9 if r < 95 else 10
		m = m.duplicate()
		m["power"] = [10, 30, 50, 70, 90, 110, 150][lv - 4]
		msg("Ampleur %d !" % lv)
	if ident == "present":
		m = m.duplicate()
		var r2 := randi() % 8
		m["power"] = 40 if r2 < 4 else 80 if r2 < 7 else 120
	if ident == "rollout" and u.rollout == 0:
		u.rollout = 5
	if ident == "fury-cutter":
		u.fury_cutter = mini(u.fury_cutter + 1, 4)

	var hits := 1
	if m["min_hits"] > 0:
		if m["min_hits"] == m["max_hits"]:
			hits = m["min_hits"]
		elif ab(u) == "skill-link":
			hits = m["max_hits"]
		else:
			var r := randi() % 100
			hits = 2 if r < 35 else 3 if r < 70 else 4 if r < 85 else 5
	var total := 0
	var landed := 0
	var crit_any := false
	var subst_hit := false
	for h in hits:
		if t.mon.hp <= 0 or u.mon.hp <= 0:
			break
		var crit := false
		var dmg := fixed
		if fixed < 0:
			crit = _crit(u, t, m)
			dmg = _calc_damage(u, t, m, _power(u, t, m), eff, crit)
		if ident == "spit-up":
			pass
		landed += 1
		if t.substitute > 0 and not SOUND.has(ident):
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
		if ident == "false-swipe":
			dmg = mini(dmg, t.mon.hp - 1)
		var survive := t.endure or (ab(t) == "sturdy" and t.mon.hp == t.mon.max_hp())
		if survive and dmg >= t.mon.hp:
			dmg = t.mon.hp - 1
			msg("%s tient bon !" % nm(t))
		anim(t, "hit")
		dmg = mini(dmg, t.mon.hp)
		t.mon.hp -= dmg
		hp_event(t)
		total += dmg
		if crit:
			crit_any = true
			msg("Coup critique !")
			if ab(t) == "anger-point" and t.mon.hp > 0:
				t.stages["atk"] = 6
				msg("Colérique : l'Attaque de %s est au maximum !" % nm(t))
		if m["cat"] == "physical":
			t.hit_phys = dmg
		else:
			t.hit_spec = dmg
		t.hit_by_foe = true
		if t.rage and t.mon.hp > 0:
			msg("La rage de %s augmente !" % nm(t))
			_stage(t, "atk", 1, t)
		if not NON_CONTACT.has(ident) and m["cat"] == "physical" and t.mon.hp >= 0:
			_contact_abilities(u, t)
	if fixed < 0 and landed > 0:
		if eff > 1.0:
			msg("C'est super efficace !")
		elif eff < 1.0:
			msg("Ce n'est pas très efficace...")
	if hits > 1:
		msg("Touché %d fois !" % landed)
	if ident == "spit-up":
		u.stockpile = 0
	if ident == "hyper-beam" and t.mon.hp >= 0:
		u.recharge = true
	if ident == "pay-day":
		pay_day += 5 * u.mon.level
		msg("Des pièces tombent partout !")
	if ident == "rapid-spin":
		if u.seeded or u.trap_turns > 0 or sides[u.side].spikes > 0:
			msg("%s se libère !" % nm(u))
		u.seeded = false
		u.trap_turns = 0
		sides[u.side].spikes = 0
	if ident == "brick-break":
		var ts: BSide = sides[t.side]
		if ts.reflect > 0 or ts.light_screen > 0:
			ts.reflect = 0
			ts.light_screen = 0
			msg("Les protections adverses volent en éclats !")
	if ident == "knock-off" or ident == "thief" or ident == "covet":
		pass
	if ident in RAMPAGE and u.rampage == 0:
		u.rampage = randi_range(2, 3)
		u.rampage_move = m["id"]
	if ident == "uproar" and u.uproar == 0:
		u.uproar = 3
		msg("%s fait un BROUHAHA !" % nm(u))
		for ob: Battler in actives():
			if ob.mon.status == "slp":
				ob.mon.status = ""
				msg("%s se réveille !" % nm(ob))
	if ident == "rollout":
		u.rollout -= 1

	# Vol de vie, contrecoup.
	if total > 0 and m["drain"] > 0:
		var amount := maxi(1, int(total * m["drain"] / 100))
		if ab(t) == "liquid-ooze":
			msg("%s aspire le Suintement !" % nm(u))
			_hurt(u, amount)
		elif u.mon.hp > 0 and u.mon.hp < u.mon.max_hp():
			msg("L'énergie de %s est drainée !" % nm(t))
			_heal(u, amount)
	elif total > 0 and (m["drain"] < 0 or m["id"] == STRUGGLE):
		if m["id"] == STRUGGLE:
			msg("%s est blessé par le contrecoup !" % nm(u))
			_hurt(u, maxi(1, u.mon.max_hp() / 4))
		elif ab(u) != "rock-head" and ab(u) != "magic-guard":
			msg("%s est blessé par le contrecoup !" % nm(u))
			_hurt(u, maxi(1, int(total * -m["drain"] / 100)))

	if ident in ["self-destruct", "explosion"] and u.mon.hp > 0:
		u.mon.hp = 0
		hp_event(u)
		_faint(u)

	# Effets secondaires.
	if landed > 0 and not subst_hit and t.mon.hp > 0:
		_secondary(u, t, m)
	if landed > 0 and m["mcat"] == 7 and u.mon.hp > 0:
		var ch: int = m["stat_ch"] if m["stat_ch"] > 0 else 100
		if randi() % 100 < _chance(u, ch):
			for sc in m["stats"]:
				_stage(u, STAGE_KEYS[sc[0] - 1], sc[1], u)
	if ident == "flame-wheel" and u.mon.status == "frz":
		u.mon.status = ""

	if t.mon.hp <= 0:
		_faint(t)
		if t.destiny_bond and u.mon.hp > 0:
			msg("%s entraîne %s avec lui !" % [nm(t), nm(u)])
			u.mon.hp = 0
			hp_event(u)
			_faint(u)
		if t.grudge:
			for mv in u.moves():
				if mv["id"] == m["id"]:
					mv["pp"] = 0
					msg("%s perd tous les PP de %s à cause de la Rancune !" % [nm(u), m["name"]])
	if ab(t) == "cursed-body" and t.mon.hp > 0 and u.disable_turns == 0 and randi() % 10 < 3:
		u.disable_move = m["id"]
		u.disable_turns = 4
		msg("Corps Maudit : %s de %s est bloqué !" % [m["name"], nm(u)])


func _end_rollout(u: Battler) -> void:
	u.rollout = 0
	u.rampage = 0
	u.fury_cutter = 0


func _chance(u: Battler, c: int) -> int:
	return c * 2 if ab(u) == "serene-grace" else c


func _secondary(u: Battler, t: Battler, m: Dictionary) -> void:
	if ab(t) == "shield-dust":
		return
	var ident: String = m["ident"]
	if ident == "tri-attack":
		if randi() % 100 < _chance(u, 20):
			_set_status(t, ["par", "brn", "frz"][randi() % 3], u, false)
		return
	if ident == "secret-power":
		if randi() % 100 < _chance(u, 30):
			_set_status(t, "par", u, false)
		return
	if m["ail"] != "none" and m["ail_ch"] > 0 and randi() % 100 < _chance(u, m["ail_ch"]):
		_ailment(u, t, m["ail"], false, ident)
	if m["flinch"] > 0 and not t.moved and ab(t) != "inner-focus" and randi() % 100 < _chance(u, m["flinch"]):
		t.flinch = true
	elif ab(u) == "stench" and not t.moved and randi() % 10 == 0:
		t.flinch = true
	if m["mcat"] == 6:
		var ch: int = m["stat_ch"] if m["stat_ch"] > 0 else 100
		if randi() % 100 < _chance(u, ch):
			for sc in m["stats"]:
				_stage(t, STAGE_KEYS[sc[0] - 1], sc[1], u)


func _contact_abilities(u: Battler, t: Battler) -> void:
	if u.mon.hp <= 0 or randi() % 10 >= 3:
		return
	match ab(t):
		"static":
			_set_status(u, "par", t, false)
		"poison-point":
			_set_status(u, "psn", t, false)
		"flame-body":
			_set_status(u, "brn", t, false)
		"effect-spore":
			_set_status(u, ["psn", "par", "slp"][randi() % 3], t, false)
		"cute-charm":
			_attract(u, t, false)


func _ohko(u: Battler, t: Battler, m: Dictionary) -> void:
	if t.mon.level > u.mon.level or (m["ident"] == "sheer-cold" and t.types.has("ice")):
		_fail()
		return
	if Data.effectiveness(m["type"], t.types) == 0.0 or (m["type"] == "ground" and ab(t) == "levitate"):
		msg("Ça n'affecte pas %s..." % nm(t))
		return
	if ab(t) == "sturdy":
		msg("Fermeté de %s le protège !" % nm(t))
		return
	if ab(u) != "no-guard" and randi() % 100 >= 30 + u.mon.level - t.mon.level:
		msg("%s évite l'attaque !" % nm(t))
		return
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
	if on_foe:
		if t == null or t.mon.hp <= 0:
			_fail()
			return
		if t.protected:
			msg("%s se protège !" % nm(t))
			return
		if _absorb(u, t, m["type"], ident):
			return
		if not _hits(u, t, m):
			msg("%s évite l'attaque !" % nm(t))
			return
		if t.substitute > 0 and not SOUND.has(ident) and ident not in ["roar", "whirlwind", "haze", "perish-song"]:
			_fail()
			return
	match m["mcat"]:
		1:
			var target := u if not on_foe else t
			if m["ail"] in ["poison", "paralysis", "burn", "sleep"] and ident == "thunder-wave" and Data.effectiveness("electric", t.types) == 0.0:
				msg("Ça n'affecte pas %s..." % nm(t))
				return
			if not _ailment(u, target, m["ail"], true, ident):
				return
		2:
			var target2 := t if on_foe else u
			var any := false
			for sc in m["stats"]:
				if _stage(target2, STAGE_KEYS[sc[0] - 1], sc[1], u):
					any = true
			if ident == "minimize":
				u.minimized = true
			if ident == "defense-curl":
				u.curled = true
			if ident == "charge":
				u.charged = true
				msg("%s se charge en électricité !" % nm(u))
			if not any and m["stats"].size() > 0:
				pass
		3:
			_heal_move(u, m)
		5:
			for sc in m["stats"]:
				_stage(t, STAGE_KEYS[sc[0] - 1], sc[1], u)
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


func _heal_move(u: Battler, m: Dictionary) -> void:
	if u.mon.hp >= u.mon.max_hp():
		msg("Les PV de %s sont au maximum !" % nm(u))
		return
	var frac := 0.5
	var ident: String = m["ident"]
	if ident in ["synthesis", "moonlight", "morning-sun"]:
		var w := weather_on()
		frac = 2.0 / 3.0 if w == "sun" else 0.25 if w != "" else 0.5
	if ident == "swallow":
		if u.stockpile == 0:
			_fail()
			return
		frac = [0.25, 0.5, 1.0][u.stockpile - 1]
		u.stockpile = 0
	_heal(u, maxi(1, int(u.mon.max_hp() * frac)))
	msg("%s récupère des PV !" % nm(u))


func _field_move(u: Battler, m: Dictionary) -> void:
	var ident: String = m["ident"]
	match ident:
		"haze":
			for ob: Battler in actives():
				for k in ob.stages:
					ob.stages[k] = 0
			msg("Les changements de stats sont annulés !")
		"rain-dance", "sunny-day", "sandstorm", "hail":
			var w: String = {"rain-dance": "rain", "sunny-day": "sun", "sandstorm": "sandstorm", "hail": "hail"}[ident]
			if weather == w:
				_fail()
				return
			weather = w
			weather_turns = 5
			msg({"rain": "Il commence à pleuvoir !", "sun": "Le soleil brille fort !",
				"sandstorm": "Une tempête de sable se lève !", "hail": "Il commence à grêler !"}[w])
			events.append({"t": "weather", "w": w})
		"mud-sport":
			mud_sport = true
			msg("Les attaques Électrik sont affaiblies !")
		"water-sport":
			water_sport = true
			msg("Les attaques Feu sont affaiblies !")
		_:
			_fail()


func _side_move(u: Battler, m: Dictionary) -> void:
	var s: BSide = sides[u.side]
	match m["ident"]:
		"reflect":
			if s.reflect > 0:
				_fail()
				return
			s.reflect = 5
			msg("Protection augmente la Défense de l'équipe !")
		"light-screen":
			if s.light_screen > 0:
				_fail()
				return
			s.light_screen = 5
			msg("Mur Lumière augmente la Défense Spéciale de l'équipe !")
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
		"spikes":
			var o: BSide = sides[1 - u.side]
			if o.spikes >= 3:
				_fail()
				return
			o.spikes += 1
			msg("Des picots sont dispersés autour de l'équipe adverse !")


func _force_switch(u: Battler, t: Battler) -> void:
	if ab(t) == "suction-cups" or t.ingrain:
		_fail()
		return
	if wild:
		if is_double() or t.mon.boss:
			_fail()
			return
		msg("%s est emporté au loin !" % nm(t))
		over = true
		result = "run"
		events.append({"t": "end", "result": "run"})
		return
	var options := bench(t.side, t.owner)
	if options.is_empty():
		_fail()
		return
	var idx: int = options[randi() % options.size()]
	events.append({"t": "recall", "side": t.side, "slot": t.slot})
	_switch_out(t)
	_send(t.side, t.slot, idx, false)
	msg("%s est envoyé au combat !" % sides[t.side].party[idx].name())


## Capacités au fonctionnement unique. Renvoie true si l'effet a été entièrement géré ici.
func _special_move(u: Battler, t: Battler, m: Dictionary) -> bool:
	var ident: String = m["ident"]
	match ident:
		"splash":
			msg("Mais rien ne se passe !")
		"teleport":
			if wild and not trapped(u):
				msg("%s se téléporte !" % nm(u))
				over = true
				result = "run"
				events.append({"t": "end", "result": "run"})
			else:
				_fail()
		"protect", "detect", "endure":
			if t != null and t.moved:
				_fail()
				u.protect_chain = 0
				return true
			if randi() % int(pow(3, mini(u.protect_chain, 6))) != 0:
				_fail()
				u.protect_chain = 0
				return true
			u.protect_chain += 1
			if ident == "endure":
				u.endure = true
				msg("%s se prépare à encaisser !" % nm(u))
			else:
				u.protected = true
				msg("%s se protège !" % nm(u))
		"rest":
			if u.mon.hp >= u.mon.max_hp() or ab(u) in ["insomnia", "vital-spirit"]:
				_fail()
				return true
			u.mon.status = "slp"
			u.mon.sleep_turns = 3
			u.mon.hp = u.mon.max_hp()
			hp_event(u)
			refresh()
			msg("%s dort et récupère tous ses PV !" % nm(u))
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
		"focus-energy":
			if u.focus_energy:
				_fail()
				return true
			u.focus_energy = true
			msg("%s se concentre !" % nm(u))
		"disable":
			if t.last_move == 0 or t.disable_turns > 0 or not _hits(u, t, m):
				_fail()
				return true
			t.disable_move = t.last_move
			t.disable_turns = 4
			msg("%s de %s est bloqué !" % [Data.move_name(t.last_move), nm(t)])
		"mimic":
			if t.last_move == 0 or t.last_move in [STRUGGLE, 102, 118] or u.moves().any(func(x): return x["id"] == t.last_move):
				_fail()
				return true
			for mv in u.moves():
				if mv["id"] == 102:
					mv["id"] = t.last_move
					mv["pp"] = 5
					mv["max"] = 5
			msg("%s apprend %s !" % [nm(u), Data.move_name(t.last_move)])
		"metronome":
			var pool := []
			for id in Data.moves:
				if Data.moves[id]["ident"] not in ["metronome", "struggle", "mimic", "mirror-move", "sleep-talk", "counter", "protect", "detect", "endure", "destiny-bond", "transform"]:
					pool.append(id)
			var picked: Dictionary = move_data(pool[randi() % pool.size()])
			msg("%s utilise %s !" % [nm(u), picked["name"]])
			_execute(u, t, picked)
		"mirror-move":
			if t.last_move == 0 or t.last_move == 119:
				_fail()
				return true
			var mm := move_data(t.last_move)
			msg("%s utilise %s !" % [nm(u), mm["name"]])
			_execute(u, t, mm)
		"sleep-talk":
			if u.mon.status != "slp":
				_fail()
				return true
			var opts := []
			for mv in u.moves():
				if move_data(mv["id"])["ident"] not in ["sleep-talk", "focus-punch", "uproar", "bide"] and not TWO_TURN.has(move_data(mv["id"])["ident"]):
					opts.append(mv["id"])
			if opts.is_empty():
				_fail()
				return true
			var st := move_data(opts[randi() % opts.size()])
			msg("%s utilise %s !" % [nm(u), st["name"]])
			_execute(u, t, st)
		"snore":
			if u.mon.status != "slp":
				_fail()
				return true
			return false
		"dream-eater":
			if t.mon.status != "slp" or t.substitute > 0:
				msg("Ça n'affecte pas %s..." % nm(t))
				return true
			return false
		"transform":
			if t.transformed or t.substitute > 0:
				_fail()
				return true
			u.transformed = true
			u.types = t.types.duplicate()
			u.t_stats = t.mon.stats.duplicate()
			u.t_stats[0] = u.mon.stats[0]
			u.stages = t.stages.duplicate()
			u.ability = t.ability
			u.t_moves = []
			for mv in t.moves():
				u.t_moves.append({"id": mv["id"], "pp": 5, "max": 5, "ups": 0})
			events.append({"t": "transform", "side": u.side, "slot": u.slot, "species": t.mon.species, "shiny": t.mon.shiny})
			msg("%s se transforme en %s !" % [nm(u), t.mon.data()["name"]])
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
			u.types = ["normal"]
			msg("%s devient du type Normal !" % nm(u))
		"mind-reader", "lock-on":
			u.lock_on = true
			msg("%s vise %s !" % [nm(u), nm(t)])
		"curse":
			if u.types.has("ghost"):
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
		"belly-drum":
			if u.mon.hp <= u.mon.max_hp() / 2 or u.stages["atk"] >= 6:
				_fail()
				return true
			_hurt(u, u.mon.max_hp() / 2)
			u.stages["atk"] = 6
			msg("%s sacrifie des PV et monte son Attaque au maximum !" % nm(u))
		"destiny-bond":
			u.destiny_bond = true
			msg("%s veut emmener son ennemi avec lui !" % nm(u))
		"grudge":
			u.grudge = true
			msg("%s veut se venger !" % nm(u))
		"mean-look", "block":
			if t.mean_look:
				_fail()
				return true
			t.mean_look = true
			msg("%s ne peut plus s'enfuir !" % nm(t))
		"baton-pass":
			var bench_list := bench(u.side, u.owner)
			if bench_list.is_empty() or (u.side == 1 and wild):
				_fail()
				return true
			msg("%s passe le relais !" % nm(u))
			if u.side == 0:
				need_switch.append({"slot": u.slot, "owner": u.owner, "baton": true})
			else:
				events.append({"t": "recall", "side": 1, "slot": u.slot})
				_send(1, u.slot, bench_list[0], true, true)
		"encore":
			if t.last_move == 0 or t.encore_turns > 0 or t.last_move in [STRUGGLE, 227, 102, 118, 119]:
				_fail()
				return true
			t.encore_move = t.last_move
			t.encore_turns = 3
			msg("%s doit refaire %s !" % [nm(t), Data.move_name(t.last_move)])
		"psych-up":
			u.stages = t.stages.duplicate()
			msg("%s copie les changements de stats de %s !" % [nm(u), nm(t)])
		"future-sight":
			var fs: BSide = sides[t.side]
			if fs.future_turns > 0:
				_fail()
				return true
			fs.future_turns = 3
			var fm := m.duplicate()
			fm["cat"] = "special"
			fs.future_damage = _calc_damage(u, t, fm, m["power"], Data.effectiveness("psychic", t.types), false)
			msg("%s prévoit une attaque !" % nm(u))
		"stockpile":
			if u.stockpile >= 3:
				_fail()
				return true
			u.stockpile += 1
			msg("%s stocke %d !" % [nm(u), u.stockpile])
			_stage(u, "def", 1, u)
			_stage(u, "spd", 1, u)
		"memento":
			u.mon.hp = 0
			hp_event(u)
			_stage(t, "atk", -2, u)
			_stage(t, "spa", -2, u)
			_faint(u)
		"follow-me", "helping-hand", "snatch", "trick", "recycle":
			msg("Mais rien ne se passe !")
		"taunt":
			if t.taunt > 0:
				_fail()
				return true
			t.taunt = 3
			msg("%s se laisse provoquer !" % nm(t))
		"torment":
			if t.torment:
				_fail()
				return true
			t.torment = true
			msg("%s est tourmenté !" % nm(t))
		"role-play":
			if t.ability == u.ability:
				_fail()
				return true
			u.ability = t.ability
			msg("%s copie le talent %s !" % [nm(u), Data.ability_name(t.ability)])
		"skill-swap":
			var a := u.ability
			u.ability = t.ability
			t.ability = a
			msg("%s échange son talent avec %s !" % [nm(u), nm(t)])
		"imprison":
			u.imprison = true
			msg("%s scelle les capacités communes !" % nm(u))
		"refresh":
			if not u.mon.status in ["psn", "tox", "par", "brn"]:
				_fail()
				return true
			u.mon.status = ""
			refresh()
			msg("%s est soigné !" % nm(u))
		"aromatherapy", "heal-bell":
			for i in sides[u.side].party.size():
				if sides[u.side].owners[i] == u.owner:
					sides[u.side].party[i].status = ""
			refresh()
			msg("Un parfum apaisant soigne toute l'équipe !")
		"perish-song":
			for ob: Battler in actives():
				if ob.perish == 0 and ab(ob) != "soundproof":
					ob.perish = 4
			msg("Tous les Pokémon entendant ce chant seront K.O. dans 3 tours !")
		"nightmare":
			if t.mon.status != "slp" or t.nightmare:
				_fail()
				return true
			t.nightmare = true
			msg("%s fait un cauchemar !" % nm(t))
		"leech-seed":
			if t.protected:
				msg("%s se protège !" % nm(t))
				return true
			if t.types.has("grass") or t.seeded or t.substitute > 0:
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
		"yawn":
			if t.yawn > 0 or t.mon.status != "" or t.substitute > 0:
				_fail()
				return true
			t.yawn = 2
			msg("%s rend %s somnolent !" % [nm(u), nm(t)])
		"attract":
			if t.protected:
				msg("%s se protège !" % nm(t))
				return true
			_attract(t, u, true)
		"foresight", "odor-sleuth":
			t.foresight = true
			t.stages["eva"] = mini(t.stages["eva"], 0)
			msg("%s est identifié !" % nm(t))
		"rage":
			u.rage = true
			return false
		"bide":
			_fail()
		"focus-punch":
			if u.hit_by_foe:
				msg("%s perd sa concentration et ne peut pas attaquer !" % nm(u))
				return true
			return false
		"fake-out":
			if u.turns > 1:
				_fail()
				return true
			return false
		"swallow":
			_heal_move(u, m)
		"whirlwind", "roar":
			if t.protected and ident == "whirlwind":
				pass
			_force_switch(u, t)
		_:
			return false
	return true


# ---------------------------------------------------------------------------
# Statuts, stats, PV
# ---------------------------------------------------------------------------

func _ailment(u: Battler, t: Battler, ail: String, from_status_move: bool, ident: String) -> bool:
	if AILMENT_STATUS.has(ail):
		var st: String = AILMENT_STATUS[ail]
		if ident == "toxic" or (ident == "poison-fang"):
			st = "tox"
		return _set_status(t, st, u, from_status_move)
	match ail:
		"confusion":
			return _confuse(t, u, from_status_move)
		"infatuation":
			return _attract(t, u, from_status_move)
		"trap":
			if t.trap_turns == 0 and t.mon.hp > 0:
				t.trap_turns = randi_range(4, 5)
				t.trap_move = ident
				msg(TRAP_TEXT.get(ident, "%s est piégé !") % nm(t))
			return true
		"nightmare", "torment", "disable", "yawn", "leech-seed", "perish-song", "ingrain":
			return true
	if from_status_move:
		_fail()
	return false


func _set_status(t: Battler, st: String, src: Battler, loud: bool) -> bool:
	var mon := t.mon
	if mon.hp <= 0:
		return false
	var fail := ""
	if mon.status != "":
		fail = "%s est déjà touché par un statut !" % nm(t)
	elif src != t and sides[t.side].safeguard > 0:
		fail = "%s est protégé par Rune Protect !" % nm(t)
	elif st == "brn" and (t.types.has("fire") or ab(t) == "water-veil"):
		fail = "Ça n'affecte pas %s..." % nm(t)
	elif st == "par" and (t.types.has("electric") or ab(t) == "limber"):
		fail = "Ça n'affecte pas %s..." % nm(t)
	elif st in ["psn", "tox"] and (t.types.has("poison") or t.types.has("steel") or ab(t) == "immunity"):
		fail = "Ça n'affecte pas %s..." % nm(t)
	elif st == "frz" and (t.types.has("ice") or weather_on() == "sun"):
		fail = "Ça n'affecte pas %s..." % nm(t)
	elif st == "slp" and (ab(t) in ["insomnia", "vital-spirit"] or actives().any(func(x): return x.uproar > 0)):
		fail = "%s ne peut pas s'endormir !" % nm(t)
	elif ab(t) == "leaf-guard" and weather_on() == "sun":
		fail = "Feuille Garde protège %s !" % nm(t)
	if t.substitute > 0 and src != t and loud:
		fail = "Mais cela échoue !"
	if fail != "":
		if loud:
			msg(fail)
		return false
	mon.status = st
	if st == "slp":
		mon.sleep_turns = randi_range(2, 4)
	if st == "tox":
		t.toxic_n = 0
	anim(t, "status_" + st)
	refresh()
	msg(STATUS_TEXT[st] % nm(t))
	if ab(t) == "synchronize" and src != null and src != t and st in ["psn", "tox", "par", "brn"]:
		msg("Synchro de %s !" % nm(t))
		_set_status(src, "psn" if st == "tox" else st, null, false)
	return true


func _confuse(t: Battler, src: Battler, loud: bool) -> bool:
	if t.mon.hp <= 0:
		return false
	if t.confusion > 0:
		if loud:
			msg("%s est déjà confus !" % nm(t))
		return false
	if ab(t) == "own-tempo" or (src != t and sides[t.side].safeguard > 0):
		if loud:
			_fail()
		return false
	t.confusion = randi_range(2, 5)
	anim(t, "status_conf")
	msg("%s est confus !" % nm(t))
	return true


func _attract(t: Battler, src: Battler, loud: bool) -> bool:
	if t.attract or t.mon.gender == 2 or src.mon.gender == 2 or t.mon.gender == src.mon.gender or ab(t) == "oblivious":
		if loud:
			_fail()
		return false
	t.attract = true
	msg("%s tombe amoureux !" % nm(t))
	return true


## Modifie un niveau de stat. Renvoie true si quelque chose a changé.
func _stage(t: Battler, key: String, delta: int, src: Battler) -> bool:
	if t == null or t.mon.hp <= 0 or delta == 0:
		return false
	var label: String = STAT_LABEL[key] + " de " + nm(t)
	if delta < 0 and src != t:
		if sides[t.side].mist > 0:
			msg("%s est protégé par la brume !" % nm(t))
			return false
		if ab(t) in ["clear-body"] or (ab(t) == "keen-eye" and key == "acc") or (ab(t) == "hyper-cutter" and key == "atk"):
			msg("%s de %s empêche la baisse !" % [Data.ability_name(t.ability), nm(t)])
			return false
		if t.substitute > 0:
			return false
	var cur: int = t.stages[key]
	var nv := clampi(cur + delta, -6, 6)
	if nv == cur:
		msg(label + (" ne peut plus augmenter !" if delta > 0 else " ne peut plus baisser !"))
		return false
	t.stages[key] = nv
	var n := absi(nv - cur)
	if delta > 0:
		anim(t, "stat_up")
		msg(label + [" augmente !", " augmente beaucoup !", " augmente énormément !"][mini(n, 3) - 1])
	else:
		anim(t, "stat_down")
		msg(label + [" baisse !", " baisse beaucoup !", " baisse énormément !"][mini(n, 3) - 1])
		if ab(t) == "competitive" and src != t:
			msg("Battant de %s s'active !" % nm(t))
			_stage(t, "spa", 2, t)
	return true


func _hurt(b: Battler, amount: int) -> void:
	if b.mon.hp <= 0:
		return
	b.mon.hp = maxi(0, b.mon.hp - maxi(1, amount))
	hp_event(b)
	if b.mon.hp <= 0:
		_faint(b)


func _heal(b: Battler, amount: int) -> void:
	if b.mon.hp <= 0:
		return
	b.mon.hp = mini(b.mon.max_hp(), b.mon.hp + maxi(1, amount))
	hp_event(b)


func _faint(b: Battler) -> void:
	if b.fainted:
		return
	b.fainted = true
	b.mon.hp = 0
	b.mon.status = ""
	b.charging = 0
	b.invuln = ""
	events.append({"t": "faint", "side": b.side, "slot": b.slot})
	msg("%s est K.O. !" % nm(b))
	if b.side == 1:
		_give_exp(b)


## Expérience (formule des jeux récents) : elle baisse quand ton Pokémon est plus fort que l'adversaire.
static func exp_gain(base: int, foe_level: int, my_level: int, trainer_battle: bool, shared: int) -> int:
	var a := 1.5 if trainer_battle else 1.0
	var scale := pow((2.0 * foe_level + 10.0) / (foe_level + my_level + 10.0), 2.5)
	return maxi(1, int(a * base * foe_level / 5.0 / maxi(1, shared) * scale) + 1)


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
		mon.add_evs(enemy.mon.data()["ev"])
		if mon.level >= 100:
			continue
		var gained := exp_gain(base, enemy.mon.level, mon.level, not wild, idxs.size() if not shared.has(i) else 2)
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
			hp_event(on_field)


func _end_of_turn() -> void:
	var w := weather_on()
	if weather != "":
		weather_turns -= 1
		if weather_turns <= 0:
			msg({"rain": "La pluie s'arrête.", "sun": "Le soleil s'affaiblit.",
				"sandstorm": "La tempête de sable se calme.", "hail": "La grêle s'arrête."}[weather])
			weather = ""
			events.append({"t": "weather", "w": ""})
		else:
			msg({"rain": "La pluie continue de tomber.", "sun": "Le soleil brille.",
				"sandstorm": "La tempête de sable fait rage.", "hail": "La grêle continue de tomber."}[weather])
	for b: Battler in actives():
		var side: BSide = sides[b.side]
		if not b.alive():
			continue
		b.turns += 1
		var mx := b.mon.max_hp()
		if w == "sandstorm" and not (b.types.has("rock") or b.types.has("ground") or b.types.has("steel")) and ab(b) not in ["sand-veil", "magic-guard"] and b.invuln == "":
			msg("La tempête de sable blesse %s !" % nm(b))
			_hurt(b, mx / 16)
		if w == "hail" and not b.types.has("ice") and ab(b) != "magic-guard" and b.invuln == "":
			msg("La grêle blesse %s !" % nm(b))
			_hurt(b, mx / 16)
		if ab(b) == "dry-skin":
			if w == "rain":
				_heal(b, mx / 8)
			elif w == "sun":
				_hurt(b, mx / 8)
		if ab(b) == "hydration" and w == "rain" and b.mon.status != "":
			b.mon.status = ""
			msg("Hydratation soigne %s !" % nm(b))
			refresh()
		if side.future_turns > 0 and b == _first_active(b.side):
			side.future_turns -= 1
			if side.future_turns == 0 and b.mon.hp > 0:
				msg("%s subit l'attaque prévue !" % nm(b))
				anim(b, "hit")
				_hurt(b, side.future_damage)
		if b.mon.hp <= 0:
			continue
		if b.ingrain and b.mon.hp < mx:
			msg("%s absorbe des nutriments avec ses racines !" % nm(b))
			_heal(b, mx / 16)
		if b.seeded and ab(b) != "magic-guard":
			var o: Battler = b.seeded_by
			var drained := mini(b.mon.hp, maxi(1, mx / 8))
			msg("Vampigraine draine l'énergie de %s !" % nm(b))
			_hurt(b, drained)
			if o != null and o.alive():
				_heal(o, drained)
		if b.mon.hp <= 0:
			continue
		if ab(b) != "magic-guard":
			match b.mon.status:
				"psn":
					msg("%s souffre du poison !" % nm(b))
					_hurt(b, mx / 8)
				"tox":
					b.toxic_n += 1
					msg("%s souffre du poison !" % nm(b))
					_hurt(b, mx * b.toxic_n / 16)
				"brn":
					msg("%s souffre de sa brûlure !" % nm(b))
					_hurt(b, mx / 16)
			if b.nightmare and b.mon.status == "slp" and b.mon.hp > 0:
				msg("%s est pris dans un cauchemar !" % nm(b))
				_hurt(b, mx / 4)
			if b.cursed and b.mon.hp > 0:
				msg("%s est touché par la malédiction !" % nm(b))
				_hurt(b, mx / 4)
			if b.trap_turns > 0 and b.mon.hp > 0:
				b.trap_turns -= 1
				if b.trap_turns == 0:
					msg("%s est libéré !" % nm(b))
				else:
					msg("%s est blessé par %s !" % [nm(b), Data.move_name(_trap_id(b.trap_move))])
					_hurt(b, mx / 8)
		if b.mon.status != "slp":
			b.nightmare = false
		if b.mon.hp <= 0:
			continue
		if ab(b) == "shed-skin" and b.mon.status != "" and randi() % 3 == 0:
			b.mon.status = ""
			msg("Mue soigne %s !" % nm(b))
			refresh()
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
		if b.taunt > 0:
			b.taunt -= 1
		if b.yawn > 0:
			b.yawn -= 1
			if b.yawn == 0:
				_set_status(b, "slp", null, false)
		if b.perish > 0:
			b.perish -= 1
			msg("Le compte à rebours de %s passe à %d !" % [nm(b), b.perish])
			if b.perish == 0:
				_hurt(b, b.mon.hp)
		b.charged = b.charged and b.last_move == 268
	for s in sides:
		for key in ["reflect", "light_screen", "mist", "safeguard"]:
			if s.get(key) > 0:
				s.set(key, s.get(key) - 1)


func _trap_id(ident: String) -> int:
	for id in Data.moves:
		if Data.moves[id]["ident"] == ident:
			return id
	return 0


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
	# Remplacements adverses (automatiques).
	for k in sides[1].slots.size():
		var b: Battler = sides[1].slots[k]
		if b != null and not b.alive() and not b.empty:
			var nxt := _ai_next(sides[1].slot_owner[k])
			if nxt >= 0 and not wild:
				_send(1, k, nxt)
				_entry_ability(sides[1].slots[k])
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
	if not wild:
		var total := 0
		for t in trainers:
			total += int(t.get("money", 100))
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
	if ab(p) == "run-away" or p.types.has("ghost"):
		msg("Vous prenez la fuite !")
		over = true
		result = "run"
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
			return 3.5 if cave else 1.0
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
		b.focus_energy = true
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

func _ai_action(b: Battler) -> Dictionary:
	if locked_move(1, b.slot) != 0:
		return {"type": "move", "slot": -1}
	var slots := usable_slots(1, b.slot)
	if slots.is_empty():
		return {"type": "move", "id": STRUGGLE}
	var targets := foes(b)
	if targets.is_empty():
		return {"type": "move", "slot": slots[0]}
	if wild:
		var t0: Battler = targets[randi() % targets.size()]
		return {"type": "move", "slot": slots[randi() % slots.size()], "target_side": 0, "target_slot": t0.slot}
	if ai_potions > 0 and b.mon.hp * 4 < b.mon.max_hp() and randi() % 2 == 0:
		return {"type": "item"}
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
	if randi() % 100 < 80 and best >= 0:
		return {"type": "move", "slot": best, "target_side": 0, "target_slot": best_t.slot}
	var good := scores.filter(func(x): return x[2] > 0)
	if good.is_empty():
		good = scores
	var pick: Array = good[randi() % good.size()]
	return {"type": "move", "slot": pick[0], "target_side": 0, "target_slot": pick[1].slot}


func _ai_score(b: Battler, t: Battler, m: Dictionary) -> float:
	var ident: String = m["ident"]
	if m["cat"] != "status":
		var typ := _move_type(b, m)
		var eff := _type_eff(b, t, typ, ident)
		if eff == 0.0 or (typ == "ground" and is_grounded_immune(t)):
			return 0.0
		if OHKO.has(ident):
			return 30.0 if t.mon.level <= b.mon.level else 0.0
		var p := float(maxi(m["power"], 40))
		if ident in ["seismic-toss", "night-shade"]:
			p = 60.0
		var phys: bool = m["cat"] == "physical"
		var ratio: float = (b.raw(1 if phys else 3) * stage_mult(b.stages["atk" if phys else "spa"])) / maxf(1.0, t.raw(2 if phys else 4) * stage_mult(t.stages["def" if phys else "spd"]))
		var est := (int(2 * b.mon.level / 5 + 2) * p * ratio / 50.0 + 2.0) * eff * (1.5 if b.types.has(typ) else 1.0)
		est *= m["acc"] / 100.0 if m["acc"] > 0 else 1.0
		var pct := est / maxf(1.0, t.mon.hp) * 100.0
		if ident in ["self-destruct", "explosion"] and b.mon.hp * 2 > b.mon.max_hp():
			pct *= 0.2
		if ident == "dream-eater" and t.mon.status != "slp":
			return 0.0
		if TWO_TURN.has(ident) or ident == "hyper-beam":
			pct *= 0.7
		return minf(pct, 150.0) + (50.0 if pct >= 100.0 else 0.0)
	match m["mcat"]:
		1:
			if m["ail"] in ["poison", "paralysis", "burn", "sleep"]:
				if t.mon.status != "" or t.substitute > 0:
					return 0.0
				if m["ail"] == "paralysis" and t.types.has("electric"):
					return 0.0
				if m["ail"] == "poison" and (t.types.has("poison") or t.types.has("steel")):
					return 0.0
				return 55.0 if m["ail"] == "sleep" else 40.0
			if m["ail"] == "confusion":
				return 0.0 if t.confusion > 0 else 30.0
			if m["ail"] == "leech-seed" or ident == "leech-seed":
				return 0.0 if (t.seeded or t.types.has("grass")) else 35.0
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
			return 25.0 if b.turns < 2 else 12.0
		3:
			return 70.0 if b.mon.hp * 2 < b.mon.max_hp() else 0.0
	match ident:
		"rest":
			return 60.0 if b.mon.hp * 3 < b.mon.max_hp() else 0.0
		"protect", "detect":
			return 10.0 if b.protect_chain == 0 else 0.0
		"substitute":
			return 25.0 if b.substitute == 0 and b.mon.hp * 2 > b.mon.max_hp() else 0.0
		"reflect", "light-screen", "mist", "safeguard":
			return 20.0 if sides[1].get(ident.replace("-", "_")) == 0 else 0.0
		"splash", "teleport":
			return 1.0
	return 15.0


func _ai_use_potion(b: Battler) -> void:
	ai_potions -= 1
	var amount := 60 if b.mon.level < 30 else 120
	msg("%s utilise une %s !" % [owner_name(1, b.owner), "Super Potion" if amount == 60 else "Hyper Potion"])
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
				sc = maxf(sc, Data.effectiveness(md["type"], t.types))
		if t != null:
			for ty in t.types:
				sc -= Data.effectiveness(ty, mon.types()) * 0.5
		if sc > best_score:
			best_score = sc
			best = i
	return best


# ---------------------------------------------------------------------------
# Copie de l'état (combat coop : l'hôte calcule, l'invité affiche)
# ---------------------------------------------------------------------------

const SYNC_FIELDS := ["party_index", "owner", "fainted", "empty", "types", "stages", "transformed", "t_moves", "t_stats",
	"substitute", "invuln", "recharge", "charging", "rampage", "rampage_move", "rollout", "uproar", "disable_move",
	"disable_turns", "encore_move", "encore_turns", "taunt", "torment", "confusion", "last_move", "imprison"]


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
			"names": side.names, "slots": slots})
	return {"sides": out, "need_switch": need_switch, "over": over, "result": result, "wild": wild, "turn": turn,
		"weather": weather, "trainers": trainers}


func apply_snapshot(d: Dictionary) -> void:
	wild = d["wild"]
	over = d["over"]
	result = d["result"]
	turn = d["turn"]
	weather = d["weather"]
	need_switch = d["need_switch"]
	trainers = d.get("trainers", trainers)
	trainer = trainers[0] if trainers.size() > 0 else {}
	for k in 2:
		var sd: Dictionary = d["sides"][k]
		var side: BSide = sides[k]
		side.party = sd["party"].map(func(x): return Pokemon.from_dict(x))
		side.owners = sd["owners"]
		side.slot_owner = sd["slot_owner"]
		side.names = sd["names"]
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
			b.ability = b.mon.ability
			side.slots.append(b)
