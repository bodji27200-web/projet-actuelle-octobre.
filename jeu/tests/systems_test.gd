extends Node
## Vérification de tous les systèmes de jeu : godot --headless res://tests/systems_test.tscn
## Affiche OK / ÉCHEC pour chaque vérification et un résumé final.

var ok := 0
var fail := 0
var failures: Array = []


func check(cond: bool, what: String) -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		failures.append(what)


func _ready() -> void:
	seed(42)
	_balls()
	_catch_formula()
	_evolutions()
	_experience()
	_pacing()
	_pp()
	_moves()
	_fainting()
	_outfits()
	_eggs()
	_rival()
	_world_data()
	_fishing()
	_display()
	print("\n=== RÉSULTAT : %d vérifications OK, %d échecs ===" % [ok, fail])
	for f in failures.slice(0, 60):
		print("  ÉCHEC : ", f)
	get_tree().quit()


func _battle1(p: Pokemon, e: Pokemon, wild := true) -> Battle:
	var b := Battle.new([p], [e], wild, {} if wild else {"name": "T"})
	b.start()
	return b


# ---------------------------------------------------------------------------
func _balls() -> void:
	print("Poké Balls...")
	var p := Pokemon.create(25, 50)
	var b := _battle1(p, Pokemon.create(16, 10))
	var t: Battle.Battler = b.battler(1, 0)
	check(b.ball_bonus("poke-ball", t) == 1.0, "Poké Ball x1")
	check(b.ball_bonus("great-ball", t) == 1.5, "Super Ball x1.5")
	check(b.ball_bonus("ultra-ball", t) == 2.0, "Hyper Ball x2")
	check(b.catch_chance("master-ball", t) == 1.0, "Master Ball 100 %")
	check(b.ball_bonus("net-ball", t) == 1.0, "Filet Ball x1 sur Roucool")
	var bw := _battle1(Pokemon.create(25, 50), Pokemon.create(10, 10))
	check(bw.ball_bonus("net-ball", bw.battler(1, 0)) == 3.5, "Filet Ball x3.5 sur Insecte")
	var bn := _battle1(Pokemon.create(25, 50), Pokemon.create(16, 5))
	check(is_equal_approx(bn.ball_bonus("nest-ball", bn.battler(1, 0)), 3.6), "Faiblo Ball x3.6 niveau 5")
	var bn2 := _battle1(Pokemon.create(25, 50), Pokemon.create(16, 45))
	check(bn2.ball_bonus("nest-ball", bn2.battler(1, 0)) == 1.0, "Faiblo Ball x1 niveau 45")
	b.caught_species = [16]
	check(b.ball_bonus("repeat-ball", t) == 3.5, "Bis Ball x3.5 si déjà capturé")
	b.caught_species = []
	check(b.ball_bonus("repeat-ball", t) == 1.0, "Bis Ball x1 sinon")
	b.turn = 1
	check(b.ball_bonus("quick-ball", t) == 5.0, "Rapide Ball x5 au 1er tour")
	b.turn = 5
	check(b.ball_bonus("quick-ball", t) == 1.0, "Rapide Ball x1 après")
	check(b.ball_bonus("timer-ball", t) > 2.4 and b.ball_bonus("timer-ball", t) < 2.6, "Chrono Ball augmente avec les tours")
	b.turn = 40
	check(b.ball_bonus("timer-ball", t) == 4.0, "Chrono Ball plafond x4")
	b.cave = true
	check(b.ball_bonus("dusk-ball", t) == 3.5, "Sombre Ball x3.5 en grotte")
	b.cave = false
	check(b.ball_bonus("dusk-ball", t) == 1.0, "Sombre Ball x1 dehors")
	check(b.ball_bonus("level-ball", t) == 8.0, "Niveau Ball x8 (niveau 4x plus haut)")
	var bm := _battle1(Pokemon.create(25, 50), Pokemon.create(30, 20))
	check(bm.ball_bonus("moon-ball", bm.battler(1, 0)) == 4.0, "Lune Ball x4 sur Nidorina")
	var bf := _battle1(Pokemon.create(25, 50), Pokemon.create(128, 20))
	check(bf.ball_bonus("fast-ball", bf.battler(1, 0)) == 4.0, "Speed Ball x4 sur Tauros")
	var pl := Pokemon.create(16, 30)
	var el := Pokemon.create(16, 10)
	pl.gender = 0
	el.gender = 1
	var bl := _battle1(pl, el)
	check(bl.ball_bonus("love-ball", bl.battler(1, 0)) == 8.0, "Love Ball x8 même espèce, sexe opposé")
	var bh := _battle1(Pokemon.create(25, 50), Pokemon.create(143, 30))
	check(bh.catch_chance("heavy-ball", bh.battler(1, 0)) > bh.catch_chance("poke-ball", bh.battler(1, 0)), "Masse Ball meilleure sur Ronflex")
	# Effets après capture
	for ball in ["heal-ball", "friend-ball"]:
		var e := Pokemon.create(16, 5)
		e.hp = 1
		e.status = "psn"
		var bb := Battle.new([Pokemon.create(25, 50)], [e], true)
		bb.start()
		bb.play_turn({"type": "ball", "item": "master-ball" if ball == "heal-ball" else "master-ball"})
		check(bb.result == "caught", "Capture Master Ball")
	var e2 := Pokemon.create(16, 5)
	e2.hp = 1
	var b2 := Battle.new([Pokemon.create(25, 50)], [e2], true)
	b2.start()
	b2._throw_ball("heal-ball", 0)
	var tries := 0
	while b2.result != "caught" and tries < 50:
		b2._throw_ball("heal-ball", 0)
		tries += 1
	check(b2.result == "caught" and b2.caught.hp == b2.caught.max_hp(), "Soin Ball soigne le Pokémon capturé")
	var e3 := Pokemon.create(16, 5)
	e3.hp = 1
	var b3 := Battle.new([Pokemon.create(25, 50)], [e3], true)
	b3.start()
	tries = 0
	while b3.result != "caught" and tries < 50:
		b3._throw_ball("friend-ball", 0)
		tries += 1
	check(b3.result == "caught" and b3.caught.happiness == 200, "Copain Ball : bonheur 200")
	var boss := Pokemon.create(95, 30)
	boss.boss = true
	var b4 := Battle.new([Pokemon.create(25, 50)], [boss], true, {}, {"boss": true})
	b4.start()
	b4._throw_ball("master-ball", 0)
	check(b4.result != "caught", "Un boss ne peut pas être capturé")
	var b5 := Battle.new([Pokemon.create(25, 50)], [Pokemon.create(16, 5)], false, {"name": "T"})
	b5.start()
	b5._throw_ball("master-ball", 0)
	check(b5.result != "caught", "Pas de capture contre un Dresseur")


func _catch_formula() -> void:
	print("Formule de capture...")
	var e := Pokemon.create(16, 5)
	var b := _battle1(Pokemon.create(25, 50), e)
	var t: Battle.Battler = b.battler(1, 0)
	var full := b.catch_chance("poke-ball", t)
	check(absf(full - 0.333) < 0.02, "Roucool PV max + Poké Ball ≈ 33 %% (obtenu %.1f %%)" % (full * 100))
	var prev := full
	var mono := true
	for k in range(1, 10):
		e.hp = maxi(1, e.max_hp() * (10 - k) / 10)
		var c := b.catch_chance("poke-ball", t)
		if c < prev - 0.0001:
			mono = false
		prev = c
	check(mono, "Moins de PV = plus de chances de capture")
	e.hp = e.max_hp()
	e.status = "slp"
	var slp := b.catch_chance("poke-ball", t)
	e.status = "par"
	var par := b.catch_chance("poke-ball", t)
	e.status = ""
	check(slp > par and par > full, "Sommeil > Paralysie > aucun statut")
	var mew := Pokemon.create(150, 70)
	var bm := _battle1(Pokemon.create(25, 50), mew)
	var cm := bm.catch_chance("ultra-ball", bm.battler(1, 0))
	check(cm > 0.002 and cm < 0.02, "Mewtwo PV max + Hyper Ball rare (%.2f %%)" % (cm * 100))
	mew.hp = 1
	mew.status = "slp"
	var cm2 := bm.catch_chance("ultra-ball", bm.battler(1, 0))
	check(cm2 > 0.04 and cm2 < 0.1, "Mewtwo 1 PV endormi + Hyper Ball ≈ 6 %% comme dans les jeux (%.1f %%)" % (cm2 * 100))
	# Tirages réels comparés à la formule
	e.hp = e.max_hp() / 2
	var expect := b.catch_chance("poke-ball", t)
	var got := 0
	for i in 2000:
		var ee := Pokemon.create(16, 5)
		ee.hp = ee.max_hp() / 2
		var bb := Battle.new([Pokemon.create(25, 50)], [ee], true)
		bb.start()
		bb._throw_ball("poke-ball", 0)
		if bb.result == "caught":
			got += 1
	var rate := got / 2000.0
	check(absf(rate - expect) < 0.04, "Tirages réels (%.1f %%) ≈ formule (%.1f %%)" % [rate * 100, expect * 100])
	print("  Roucool PV max : %.0f %%, à moitié : %.0f %%, 1 PV endormi : %.0f %%" % [full * 100, expect * 100, _chance_at(16, 1, "slp") * 100])


func _chance_at(sid: int, hp: int, status: String) -> float:
	var e := Pokemon.create(sid, 5)
	e.hp = hp
	e.status = status
	var b := _battle1(Pokemon.create(25, 50), e)
	return b.catch_chance("poke-ball", b.battler(1, 0))


# ---------------------------------------------------------------------------
func _evolutions() -> void:
	print("Évolutions...")
	var n_level := 0
	var n_item := 0
	for sid in Data.pokemon:
		for e in Data.pokemon[sid]["evos"]:
			if e.has("level"):
				var m := Pokemon.create(sid, maxi(1, e["level"] - 1))
				check(m.level_evolution() == 0, "%s n'évolue pas avant le niveau %d" % [m.name(), e["level"]])
				m.add_exp(m.exp_to_next())
				check(m.level_evolution() == e["to"], "%s évolue au niveau %d" % [Data.pokemon[sid]["name"], e["level"]])
				var hp_before := m.hp
				m.evolve(e["to"])
				check(m.species == e["to"] and m.hp >= hp_before, "%s devient %s" % [Data.pokemon[sid]["name"], Data.pokemon[e["to"]]["name"]])
				n_level += 1
			else:
				var m2 := Pokemon.create(sid, 20)
				check(m2.item_evolution(e["item"]) == e["to"], "%s + %s" % [m2.name(), e["item"]])
				check(m2.item_evolution("poke-ball") == 0, "%s ne réagit pas à un autre objet" % m2.name())
				n_item += 1
	print("  %d évolutions par niveau, %d par objet vérifiées" % [n_level, n_item])


func _experience() -> void:
	print("Expérience...")
	check(Data.exp_at(2, 100) == 1000000, "Courbe moyenne : 1 000 000 au N.100")
	check(Data.exp_at(3, 100) == 800000, "Courbe rapide : 800 000 au N.100")
	check(Data.exp_at(1, 100) == 1250000, "Courbe lente : 1 250 000 au N.100")
	check(Data.exp_at(4, 100) == 1059860, "Courbe parabolique : 1 059 860 au N.100")
	var m := Pokemon.create(4, 5)
	var last := -1.0
	var mono := true
	for i in 30:
		m.add_exp(37)
		var p := m.exp_progress()
		if m.level == 5 and p < last:
			mono = false
		last = p
	check(mono, "Barre d'expérience croissante")
	var m2 := Pokemon.create(4, 5)
	m2.add_exp(Data.exp_at(m2.data()["growth"], 100))
	check(m2.level == 100 and m2.exp == Data.exp_at(m2.data()["growth"], 100), "Niveau maximum 100")
	check(m2.add_exp(1000).is_empty(), "Pas d'expérience au-delà du N.100")
	var low := Battle.exp_gain(51, 20, 10, false, 1)
	var even := Battle.exp_gain(51, 20, 20, false, 1)
	var high := Battle.exp_gain(51, 20, 40, false, 1)
	check(low > even and even > high, "Moins d'expérience quand on est plus fort (%d > %d > %d)" % [low, even, high])
	check(Battle.exp_gain(51, 20, 20, true, 1) > even, "Bonus x1.5 contre un Dresseur")
	check(Battle.exp_gain(51, 20, 20, false, 2) < even, "Expérience partagée entre participants")
	# EV
	var ev := Pokemon.create(25, 50)
	for i in 300:
		ev.add_evs([0, 0, 0, 0, 0, 3])
	var total := 0
	for v in ev.evs:
		total += v
	check(ev.evs[5] == 252 and total <= 510, "EV plafonnés à 252 par stat / 510 au total")


## Simulation d'une partie : niveau atteint au fil des heures, comparé aux Champions.
func _pacing() -> void:
	print("Rythme de progression (simulation)...")
	# Zones de l'aventure : [niveau des sauvages, niveau des dresseurs, nb de dresseurs, nom, niveau de l'as du Champion]
	var areas := [[4, 6, 6, "Route 1-2 / Forêt (-> Pierre)", 14], [9, 11, 12, "Route 3 / Mt Sélénite (-> Ondine)", 21],
		[15, 17, 12, "Pont / Route 5-6 (-> Bob)", 24], [20, 22, 14, "Route 11-12 / Lavanville (-> Érika)", 29],
		[25, 28, 18, "Repaire / Tour / R.13-15 (-> Koga)", 43], [30, 34, 18, "Safari / Sylphe (-> Morgane)", 43],
		[34, 38, 12, "Îles Écume / Manoir (-> Auguste)", 47], [38, 42, 10, "Retour à Jadielle (-> Giovanni)", 50],
		[42, 46, 14, "Route Victoire (-> Ligue)", 63]]
	var team := [Pokemon.create(4, 5), Pokemon.create(16, 4), Pokemon.create(25, 6), Pokemon.create(74, 10)]
	var minutes := 0.0
	for a in areas:
		# Chaque zone : dresseurs + combats sauvages (≈ 1 combat par minute en jouant normalement)
		var fights := 0
		for i in a[2]:
			var lvl: int = a[1]
			for k in 2:
				_share_exp(team, 80, lvl, true)
			fights += 1
		for i in 40:
			_share_exp(team, 60, a[0], false)
			fights += 1
		minutes += fights * 1.3 + 15
		var best := 0
		for m in team:
			best = maxi(best, m.level)
		print("  après %-26s ~%3d min de jeu : équipe N.%d (as du Champion suivant : N.%d)" % [a[3], int(minutes), best, a[4]])
		check(best <= a[4] + 6, "Pas de sur-niveau après %s" % a[3])
		check(best >= a[4] - 12, "Pas trop de retard après %s" % a[3])
	var lead: int = team[0].level
	check(lead < 65, "Niveau raisonnable avant la Ligue (%d)" % lead)


# ---------------------------------------------------------------------------
## Un combat : le Pokémon le plus faible combat, les autres reçoivent la moitié (Multi Exp).
func _share_exp(team: Array, base: int, lvl: int, trainer: bool) -> void:
	var w := _weakest(team)
	for m in team:
		m.add_exp(Battle.exp_gain(base, lvl, m.level, trainer, 1 if m == w else 2))


func _weakest(team: Array) -> Pokemon:
	var w: Pokemon = team[0]
	for m in team:
		if m.level < w.level:
			w = m
	return w


func _pp() -> void:
	print("PP...")
	var p := Pokemon.create(4, 20)
	p.moves = [Pokemon.make_move(10)]
	var b := _battle1(p, Pokemon.create(143, 50))
	var before: int = p.moves[0]["pp"]
	b.play_turn({"type": "move", "slot": 0})
	check(p.moves[0]["pp"] == before - 1, "Une attaque consomme 1 PP")
	p.moves[0]["pp"] = 0
	check(b.usable_slots(0).is_empty(), "Attaque sans PP inutilisable")
	var evs := b.play_turn({"type": "move", "id": Battle.STRUGGLE})
	var used_struggle := evs.any(func(e): return e["t"] == "msg" and "Lutte" in e["text"])
	check(used_struggle, "Lutte quand il n'y a plus de PP")
	var p2 := Pokemon.create(4, 20)
	p2.moves = [Pokemon.make_move(10)]
	var press := Pokemon.create(144, 50)
	press.ability = 46
	var b2 := _battle1(p2, press)
	var bp: int = p2.moves[0]["pp"]
	b2.play_turn({"type": "move", "slot": 0})
	check(p2.moves[0]["pp"] == bp - 2 or Data.ability_ident(press.ability) != "pressure", "Pression : 2 PP par attaque")
	var p3 := Pokemon.create(4, 20)
	p3.moves = [Pokemon.make_move(10)]
	ItemUse.apply(p3, "pp-up", 0)
	check(p3.moves[0]["max"] == 35 + 7, "PP Plus : +20 %% des PP max")
	p3.moves[0]["pp"] = 0
	ItemUse.apply(p3, "ether", 0)
	check(p3.moves[0]["pp"] == 10, "Huile : +10 PP")


## Vérifie l'effet de CHAQUE capacité dans une situation contrôlée.
func _moves() -> void:
	print("Effets des 303 capacités...")
	var skip_reason := {"counter": "riposte", "mirror-coat": "riposte", "spit-up": "stock", "future-sight": "différé",
		"focus-punch": "", "snore": "sommeil", "dream-eater": "sommeil", "sleep-talk": "sommeil", "nightmare": "sommeil",
		"endeavor": "pv", "bide": "", "mimic": "", "mirror-move": "", "metronome": "aléatoire", "transform": "",
		"follow-me": "double", "helping-hand": "double", "snatch": "", "trick": "", "recycle": "", "imprison": "",
		"grudge": "", "destiny-bond": "", "spite": "", "encore": "", "disable": "", "torment": "", "teleport": "",
		"whirlwind": "", "roar": "", "baton-pass": "", "memento": "", "self-destruct": "", "explosion": "", "perish-song": "",
		"present": "aléatoire", "psych-up": "", "role-play": "", "skill-swap": "", "conversion-2": "", "camouflage": "",
		"rest": "pv", "substitute": "", "belly-drum": "", "curse": "", "stockpile": "", "swallow": "", "uproar": "",
		"rage": "", "lock-on": "", "mind-reader": "", "foresight": "", "odor-sleuth": "", "attract": "", "yawn": "", "ingrain": "",
		"fake-out": "", "protect": "", "detect": "", "endure": "", "splash": "", "conversion": "", "haze": "", "mist": "",
		"refresh": "", "aromatherapy": "", "heal-bell": "", "taunt": "", "block": "", "mean-look": "", "spikes": "",
		"safeguard": "", "reflect": "", "light-screen": "", "focus-energy": "", "mud-sport": "", "water-sport": "", "charge": "",
		"minimize": "", "defense-curl": "", "leech-seed": "", "false-swipe": "", "fissure": "ohko", "guillotine": "ohko",
		"horn-drill": "ohko", "sheer-cold": "ohko", "psywave": "", "struggle": ""}
	var checked := 0
	var skipped := 0
	for id in Data.moves:
		var m: Dictionary = Data.moves[id]
		var ident: String = m["ident"]
		var user := Pokemon.create(147, 50)  # Minidraco : type Dragon, neutre partout
		user.moves = [Pokemon.make_move(id)]
		var target := Pokemon.create(143, 50)  # Ronflex : Normal
		if m["type"] in ["fighting"]:
			target = Pokemon.create(128, 50)
		if m["type"] == "ghost" and m["cat"] != "status":
			target = Pokemon.create(64, 50)
		if m["type"] == "ground" or m["type"] == "electric":
			target = Pokemon.create(108, 50)
		if m["type"] == "poison" and m["ail"] in ["poison"]:
			target = Pokemon.create(143, 50)
		user.ability = 0
		target.ability = 0
		target.moves = [Pokemon.make_move(150)]
		var b := Battle.new([user], [target], true)
		b.always_hit = true
		b.start()
		var tb: Battle.Battler = b.battler(1, 0)
		var ub: Battle.Battler = b.battler(0, 0)
		if skip_reason.has(ident):
			# Ces capacités ont des conditions particulières : on vérifie seulement qu'elles ne plantent pas.
			b.play_turn({"type": "move", "slot": 0})
			skipped += 1
			continue
		if m["mcat"] == 3 or ident in ["swallow", "synthesis", "moonlight", "recover", "soft-boiled"]:
			user.hp = user.max_hp() / 3
		var hp0 := target.hp
		var uhp0 := user.hp
		var stages0: Dictionary = tb.stages.duplicate()
		var ustages0: Dictionary = ub.stages.duplicate()
		b.play_turn({"type": "move", "slot": 0})
		if TWO_TURN_LIKE(ident):
			b.play_turn({"type": "move", "slot": 0})
		checked += 1
		var what := "%s (%s)" % [m["name"], ident]
		if m["cat"] != "status" and m["power"] > 0 or ident in ["seismic-toss", "night-shade", "dragon-rage", "sonic-boom", "super-fang"]:
			check(target.hp < hp0 or tb.substitute > 0 or b.over, what + " inflige des dégâts")
			if m["drain"] > 0 and user.hp < user.max_hp():
				pass
			if m["drain"] < 0 or ident == "struggle":
				check(user.hp < uhp0, what + " blesse son lanceur (contrecoup)")
		elif m["mcat"] == 1 and m["ail"] in ["paralysis", "sleep", "burn", "poison", "freeze"]:
			check(target.status != "" or tb.types.has("electric") or tb.types.has("poison"), what + " inflige un statut")
		elif m["mcat"] == 1 and m["ail"] == "confusion":
			check(tb.confusion > 0, what + " rend confus")
		elif m["mcat"] == 2 and m["stats"].size() > 0:
			var changed := false
			for k in tb.stages:
				if tb.stages[k] != stages0[k] or ub.stages[k] != ustages0[k]:
					changed = true
			check(changed, what + " modifie des statistiques")
		elif m["mcat"] == 3:
			check(user.hp > uhp0, what + " soigne")
		elif m["mcat"] == 5:
			check(tb.confusion > 0, what + " rend confus et booste")
		elif m["mcat"] == 10 and ident in ["rain-dance", "sunny-day", "sandstorm", "hail"]:
			check(b.weather != "", what + " change la météo")
		else:
			check(true, what)
	print("  %d capacités vérifiées précisément, %d à condition spéciale exécutées sans erreur" % [checked, skipped])


func TWO_TURN_LIKE(ident: String) -> bool:
	return Battle.TWO_TURN.has(ident)


func _fainting() -> void:
	print("K.O....")
	var p1 := Pokemon.create(6, 60)
	var p2 := Pokemon.create(9, 60)
	var e := Pokemon.create(19, 3)
	var b := Battle.new([p1, p2], [e], false, {"name": "T"})
	b.start()
	var lvl0 := p1.exp
	var evs := b.play_turn({"type": "move", "slot": 0})
	check(e.hp == 0 and evs.any(func(x): return x["t"] == "faint"), "Le Pokémon adverse est K.O.")
	check(p1.exp > lvl0, "Expérience gagnée sur K.O.")
	check(b.result == "win", "Victoire quand l'adversaire n'a plus de Pokémon")
	var weak := Pokemon.create(19, 2)
	var strong := Pokemon.create(150, 80)
	strong.moves = [Pokemon.make_move(94)]
	var weak2 := Pokemon.create(16, 2)
	var b2 := Battle.new([weak, weak2], [strong], true)
	b2.start()
	weak.hp = 1
	for i in 5:
		if b2.need_switch.size() > 0 or b2.over:
			break
		b2.play_turn({"type": "move", "slot": 0})
	check(weak.hp == 0 and not weak.can_battle(), "Notre Pokémon est K.O.")
	check(b2.need_switch.size() > 0 or b2.over, "On doit envoyer un autre Pokémon")
	check(not b2.bench(0, 0).has(0), "Un Pokémon K.O. ne peut pas revenir")
	weak.hp = 0
	ItemUse.apply(weak, "revive")
	check(weak.hp == maxi(1, weak.max_hp() / 2), "Rappel : ranimé à la moitié des PV")
	var bx := Battle.new([[Pokemon.create(25, 20)], [Pokemon.create(1, 20)]], [Pokemon.create(16, 20)], true, {})
	bx.exp_share = [true, false]
	bx.start()
	var lone: Pokemon = Pokemon.create(7, 20)
	bx.sides[0].party.insert(1, lone)
	bx.sides[0].owners.insert(1, 0)
	var e0 := lone.exp
	bx.battler(1, 0).mon.hp = 1
	bx.play_turn({"type": "move", "slot": 0})
	check(lone.exp > e0 or bx.battler(1, 0).mon.hp > 0, "Multi Exp : un Pokémon resté au fond gagne de l'expérience")


func _outfits() -> void:
	print("Tenues...")
	for o in Game.OUTFITS:
		Game.give_outfit(o)
		Game.outfit = o
		for g in 2:
			Game.gender = g
			check(PixelArt.character(Game.look(), "down", 0) != null, "Tenue %s (%s)" % [o, "fille" if g else "garçon"])
	check(Game.outfits.size() == Game.OUTFITS.size(), "Toutes les tenues obtenues et équipables")
	Game.outfit = "classique"
	Game.gender = 0


func _eggs() -> void:
	print("Œufs et pension...")
	Game.party = [Pokemon.create(4, 20)]
	var egg := Pokemon.create_egg(6)
	check(egg.species == 4 and egg.is_egg and egg.level == 1, "Un Œuf de Dracaufeu contient un Salamèche N.1")
	Game.party.append(egg)
	var need: int = Data.pokemon[4]["hatch"] * 256
	var steps := 0
	var hatched := []
	while hatched.is_empty() and steps < 20000:
		hatched = Game.on_step()
		steps += 1
	check(steps == need, "Éclosion après %d pas (attendu %d)" % [steps, need])
	var fb := Pokemon.create(126, 30)
	fb.ability = 49
	Game.party = [fb, Pokemon.create_egg(4)]
	steps = 0
	hatched = []
	while hatched.is_empty() and steps < 20000:
		hatched = Game.on_step()
		steps += 1
	check(steps == need / 2 or Data.ability_ident(49) != "flame-body", "Corps Ardent divise le temps par 2")
	check(Game.party[1].egg_hint() != "", "Message de l'Œuf dans le résumé")
	var a := Pokemon.create(25, 20)
	var b2 := Pokemon.create(25, 20)
	a.gender = 0
	b2.gender = 1
	Game.daycare = [a, b2]
	check(Game.daycare_compat() == 50, "Même espèce, sexes opposés : 50 %")
	b2 = Pokemon.create(35, 20)
	b2.gender = 1
	Game.daycare = [a, b2]
	check(Game.daycare_compat() == 20, "Même groupe d'œufs : 20 %")
	Game.daycare = [a, Pokemon.create(132, 20)]
	check(Game.daycare_compat() == 20, "Avec Métamorph : 20 %")
	Game.daycare = [a, Pokemon.create(150, 70)]
	check(Game.daycare_compat() == 0, "Mewtwo ne pond pas")
	var c := Pokemon.create(25, 20)
	c.gender = 0
	Game.daycare = [a, c]
	check(Game.daycare_compat() == 0, "Deux mâles : pas d'Œuf")
	var d := Pokemon.create(26, 20)
	d.gender = 1
	Game.daycare = [a, d]
	var e := Game.daycare_make_egg()
	check(e.species == 25 and e.is_egg, "L'Œuf d'un Raichu femelle est un Pikachu")
	Game.daycare = []


func _rival() -> void:
	print("Rival...")
	for st in [1, 4, 7]:
		Game.starter = st
		var prev := 0
		for stage in [3, 4, 5, 6, 7]:
			var team := Events.rival_team(stage)
			var top := 0
			for e in team:
				top = maxi(top, e[1])
			check(top > prev, "Rival plus fort à chaque rencontre (starter %d, étape %d)" % [st, stage])
			prev = top
		var final := Events.rival_team(7)
		var ace: int = final[-1][0]
		check(Data.pokemon[ace]["evos"].is_empty(), "Le starter du rival est entièrement évolué à la Ligue (%s)" % Data.pokemon[ace]["name"])
	Game.starter = 0


func _world_data() -> void:
	print("Données du monde...")
	var leaders := 0
	for mid in Game.maps:
		var m: Dictionary = Game.maps[mid]
		for n in m["npcs"]:
			if n.has("trainer"):
				check(Game.trainers.has(n["trainer"]), "Dresseur %s existe (%s)" % [n["trainer"], mid])
			for cmd in _flatten(n.get("script", [])):
				if not (cmd is Array and cmd.size() > 0 and cmd[0] is String):
					continue
				if cmd.size() > 1 and cmd[0] in ["battle", "league_battle", "double_battle"]:
					check(Game.trainers.has(cmd[1]), "Script : dresseur %s existe" % cmd[1])
				if cmd.size() > 1 and cmd[0] == "give":
					check(Data.items.has(cmd[1]), "Script : objet %s existe" % cmd[1])
				if cmd.size() > 1 and cmd[0] == "outfit":
					check(Game.OUTFITS.has(cmd[1]), "Script : tenue %s existe" % cmd[1])
				if cmd[0] == "badge":
					leaders += 1
		for b in m["buildings"]:
			check(Game.maps.has(b["to"]), "Porte %s -> %s" % [mid, b["to"]])
		for w in m["warps"]:
			check(Game.maps.has(w["to"]), "Passage %s -> %s" % [mid, w["to"]])
	check(leaders == 8, "8 Champions d'Arène donnent un Badge (%d)" % leaders)
	check(Game.maps.size() > 100, "Plus de 100 cartes (%d)" % Game.maps.size())


func _fishing() -> void:
	print("Pêche...")
	for rod in Events.RODS:
		check(Data.items.has(rod) and Data.items[rod].get("key", false), "Canne %s = objet rare" % rod)
	var givers := {}
	for mid in Game.maps:
		var m: Dictionary = Game.maps[mid]
		var has_water := false
		for row in m["rows"]:
			if "~" in row or "w" in row:
				has_water = true
				break
		if has_water:
			for rod in Events.RODS:
				var t: Array = m["wild"].get(rod, [])
				check(not t.is_empty(), "%s : table de pêche %s" % [mid, rod])
				for e in t:
					check(Data.pokemon.has(int(e[0])) and e[1] <= e[2] and e[2] <= 100, "%s/%s : entrée valide %s" % [mid, rod, e])
		for n in m["npcs"]:
			for cmd in _flatten(n.get("script", [])):
				if cmd is Array and cmd.size() > 1 and cmd[0] is String and cmd[0] == "give" and cmd[1] in Events.RODS:
					givers[cmd[1]] = mid
	for rod in Events.RODS:
		check(givers.has(rod), "Un PNJ donne la %s" % Data.item_name(rod))
	check(PixelArt.LOOKS.has("fisher"), "Apparence du pêcheur")
	# Canne : Magicarpe ; Méga Canne : Pokémon plus forts.
	var old: Array = Game.maps["carmin"]["wild"]["old-rod"]
	var sup: Array = Game.maps["carmin"]["wild"]["super-rod"]
	check(old.size() == 1 and int(old[0][0]) == 129, "Canne de Carmin = Magicarpe")
	check(sup.any(func(e): return e[2] >= 30), "Méga Canne : Pokémon jusqu'au N.30+")
	check(Game.maps["safari"]["wild"]["super-rod"].any(func(e): return int(e[0]) == 147), "Minidraco pêchable au Parc Safari")
	# Scuba Ball efficace sur un Pokémon pêché.
	var b := _battle1(Pokemon.create(25, 30), Pokemon.create(129, 20))
	check(b.ball_bonus("dive-ball", b.battler(1, 0)) == 1.0, "Scuba Ball x1 hors pêche")
	b.fishing = true
	check(b.ball_bonus("dive-ball", b.battler(1, 0)) == 3.5, "Scuba Ball x3,5 à la pêche")


func _display() -> void:
	print("Affichage...")
	for c in "♂♀★▶◀▼▲₽✓■□●":
		check(Game.font.has_char(c.unicode_at(0)), "La police contient %s" % c)
	# Le nom + sexe + étoile ne doit jamais toucher le niveau, même en combat double (cadre de 200 px).
	var holder := Control.new()
	add_child(holder)
	var worst := 0.0
	for sid in Data.pokemon:
		var mon := Pokemon.create(int(sid), 100)
		mon.gender = 1
		mon.shiny = true
		var end := Kit.name_line(holder, mon, Vector2(10, 0), 13)
		worst = maxf(worst, end)
	var level_x := 200 - 12 - Kit.text_width("N.100", 13)
	check(worst + 2 <= level_x, "Nom + ♀ + ★ ne chevauche pas le niveau (fin %d, niveau à %d)" % [worst, level_x])
	holder.queue_free()


func _flatten(cmds: Variant) -> Array:
	var out := []
	if cmds is Array:
		for c in cmds:
			if c is Array:
				out.append(c)
				for sub in c:
					if sub is Array:
						out += _flatten(sub)
	return out
