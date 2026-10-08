extends Node
## Équilibre de la fin de jeu : godot --headless res://tests/balance_test.tscn [-- <combats>]
## Une IA joue le joueur (la meilleure attaque à chaque tour, comme l'IA adverse) avec une équipe de fin de jeu
## (niveau 100, builds compétitifs) contre Giovanni, un dresseur du fond de l'Abîme et le Gardien de l'Abîme.
## Un boss de fin de jeu doit être dur, mais pas impossible.

const TEAMS := {
	"légendaires": [150, 384, 383, 382, 445, 248],
	"sans légendaire": [445, 248, 376, 149, 373, 635],
}


func _ready() -> void:
	seed(99)
	var n := 20
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var abyss_trainer := ""
	for npc in Game.maps["cr_abime_10"]["npcs"]:
		if npc.get("kind", "") == "trainer":
			abyss_trainer = npc["trainer"]
	for tid in ["rr_giovanni_final", abyss_trainer, "gardien_abime"]:
		for team_name in TEAMS:
			var wins := 0
			var turns := 0
			for k in n:
				var r: Array = _fight(Game.trainers[tid], TEAMS[team_name])
				wins += 1 if r[0] == "win" else 0
				turns += r[1]
			print("%-22s contre équipe %-16s : %2d victoires sur %d (%.0f %%), %.1f tours en moyenne" % [
				Game.trainers[tid]["name"], team_name, wins, n, 100.0 * wins / n, float(turns) / n])
	get_tree().quit()


func _player_team(ids: Array) -> Array:
	var out := []
	for sid in ids:
		var m := Pokemon.create(sid, 100)
		Builds.auto(m, true)
		out.append(m)
	return out


func _fight(t: Dictionary, ids: Array) -> Array:
	var foe: Array = Events.make_team(t["team"], t)
	var b := Battle.new([_player_team(ids)], [foe], false, t, {"mega": true, "zmove": false, "aura": t.get("aura", "")})
	b.start()
	var turns := 0
	while not b.over and turns < 200:
		turns += 1
		while b.need_switch.size() > 0 and not b.over:
			var ns: Dictionary = b.need_switch[0]
			var opts := b.bench(0, ns["owner"])
			if opts.is_empty():
				b.need_switch.pop_front()
				continue
			b.player_switch(ns["slot"], _best_switch(b, opts))
		if b.over:
			break
		var acts := {}
		for s in b.sides[0].slots.size():
			var bt := b.battler(0, s)
			if bt == null or not bt.alive():
				continue
			acts[s] = _best_move(b, bt, s)
		b.play_turn(acts)
	return [b.result if b.over else "timeout", turns]


## La meilleure attaque selon le même calcul que l'IA adverse (dégâts estimés, K.O., priorité...).
func _best_move(b: Battle, bt: Battle.Battler, s: int) -> Dictionary:
	if b.locked_move(0, s) != 0:
		return {"type": "move", "slot": -1}
	var usable := b.usable_slots(0, s)
	if usable.is_empty():
		return {"type": "move", "id": Battle.STRUGGLE}
	var best := usable[0]
	var best_t: Battle.Battler = null
	var best_score := -1.0
	for i in usable:
		var m := b.move_data(bt.moves()[i]["id"])
		for f: Battle.Battler in b.foes(bt):
			var sc := b._ai_score(bt, f, m)
			if sc > best_score:
				best_score = sc
				best = i
				best_t = f
	var act := {"type": "move", "slot": best}
	if best_t != null:
		act["target_side"] = 1
		act["target_slot"] = best_t.slot
	if b.can_mega_evolve(bt):
		act["mega"] = true
	return act


## Remplaçant : celui qui fait le plus de dégâts au Pokémon adverse en face.
func _best_switch(b: Battle, opts: Array) -> int:
	var foe: Battle.Battler = null
	for f: Battle.Battler in b.actives(1):
		foe = f
	if foe == null:
		return opts[0]
	var best: int = opts[0]
	var best_v := -1.0
	for i in opts:
		var mon: Pokemon = b.sides[0].party[i]
		var v := 0.0
		for mv in mon.moves:
			var md := b.move_data(mv["id"])
			if md["cat"] != "status":
				v = maxf(v, Data.effectiveness(md["type"], foe.types) * md["power"] * (1.5 if mon.types().has(md["type"]) else 1.0))
		if v > best_v:
			best_v = v
			best = i
	return best
