extends Node
## Test de charge du moteur : des milliers de combats aléatoires (tous les Pokémon et formes, objets tenus,
## talents cachés, capacités au hasard parmi toutes, Méga-Évolution, capacités Z, simple et double).
## godot --headless res://tests/stress_test.tscn [-- <nombre de combats>]

var held: Array = []
var pids: Array = []
var move_ids: Array = []


func _ready() -> void:
	seed(7)
	for id in Data.items:
		var it: Dictionary = Data.items[id]
		if it.get("held", false) and it.get("cat", "") not in ["standard-balls", "special-balls", "apricorn-balls", "healing", "vitamins", "status-cures", "revival", "pp-recovery", "stat-boosts", "spelunking", "loot", "collectibles", "dex-completion"]:
			held.append(id)
	for pid in Data.pokemon:
		if not Data.pokemon[pid].get("battle_only", false):
			pids.append(pid)
	move_ids = Data.moves.keys()
	var n := 1500
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var results := {"win": 0, "lose": 0, "run": 0, "caught": 0, "timeout": 0}
	var turns_total := 0
	var megas := 0
	var zs := 0
	var t0 := Time.get_ticks_msec()
	for i in n:
		var r := _battle(i)
		results[r[0]] = results.get(r[0], 0) + 1
		turns_total += r[1]
		megas += r[2]
		zs += r[3]
		if i % 250 == 0:
			print("  combat %d / %d" % [i, n])
	print("=== %d combats en %.1f s : %s, %.1f tours en moyenne, %d Méga-Évolutions, %d capacités Z ===" % [n, (Time.get_ticks_msec() - t0) / 1000.0, results, float(turns_total) / n, megas, zs])
	get_tree().quit()


func _mon(lvl: int) -> Pokemon:
	var pid: int = pids[randi() % pids.size()]
	var m := Pokemon.create(pid, lvl, randi() % 4 == 0)
	m.moves.clear()
	for k in 4:
		var mid: int = move_ids[randi() % move_ids.size()]
		if randi() % 2 == 0 and m.data()["learn"].size() > 0:
			mid = m.data()["learn"][randi() % m.data()["learn"].size()][1]
		if not m.knows(mid):
			m.moves.append(Pokemon.make_move(mid))
	if randi() % 3 > 0:
		m.held_item = held[randi() % held.size()]
	# Méga-Gemme assortie de temps en temps.
	if randi() % 6 == 0:
		for stone in Data.mega_stones:
			if Data.pokemon[Data.mega_stones[stone]]["species"] == m.species:
				m.held_item = stone
	for k in 6:
		m.evs[k] = randi_range(0, 85)
	m.recalc_stats()
	m.hp = m.max_hp()
	return m


func _battle(i: int) -> Array:
	var lvl := randi_range(5, 100)
	var double := randi() % 3 == 0
	var a := []
	var e := []
	for k in randi_range(1, 4):
		a.append(_mon(lvl))
		e.append(_mon(clampi(lvl + randi_range(-10, 10), 1, 100)))
	var wild := randi() % 4 == 0 and not double
	var trainer := {} if wild else {"name": "Test", "ai": randi_range(1, 3)}
	var b := Battle.new([a], [e], wild, trainer, {"double": double, "mega": true, "zmove": true, "boss": wild and randi() % 5 == 0,
		"aura": ["", "", "fire", "dragon", "ghost", "grass", "dark", "steel", "electric", "water", "ice", "psychic", "fairy", "fighting", "rock", "ground", "flying"][randi() % 17]})
	b.start()
	var turns := 0
	var megas := 0
	var zs := 0
	while not b.over and turns < 150:
		turns += 1
		while b.need_switch.size() > 0 and not b.over:
			var ns: Dictionary = b.need_switch[0]
			var opts := b.bench(0, ns["owner"])
			if opts.is_empty():
				b.need_switch.pop_front()
				continue
			b.player_switch(ns["slot"], opts[randi() % opts.size()])
		if b.over:
			break
		var acts := {}
		for s in b.sides[0].slots.size():
			var bt := b.battler(0, s)
			if bt == null or not bt.alive():
				continue
			var r := randi() % 20
			if r == 0 and b.bench(0, bt.owner).size() > 0 and not b.trapped(bt):
				var opts2 := b.bench(0, bt.owner)
				acts[s] = {"type": "switch", "index": opts2[randi() % opts2.size()]}
				continue
			if r == 1 and wild:
				acts[s] = {"type": "ball", "item": ["poke-ball", "ultra-ball", "dusk-ball", "quick-ball"][randi() % 4]}
				continue
			var usable := b.usable_slots(0, s)
			var act := {"type": "move"}
			if b.locked_move(0, s) != 0:
				act["slot"] = -1
			elif usable.is_empty():
				act["id"] = Battle.STRUGGLE
			else:
				act["slot"] = usable[randi() % usable.size()]
				var f := b.foes(bt)
				if f.size() > 0:
					var t: Battle.Battler = f[randi() % f.size()]
					act["target_side"] = 1
					act["target_slot"] = t.slot
				if b.can_mega_evolve(bt) and randi() % 2 == 0:
					act["mega"] = true
					megas += 1
				if b.can_z_move(bt, bt.moves()[act["slot"]]["id"]) and randi() % 2 == 0:
					act["z"] = true
					zs += 1
			acts[s] = act
		b.play_turn(acts)
	return [b.result if b.over else "timeout", turns, megas, zs]
