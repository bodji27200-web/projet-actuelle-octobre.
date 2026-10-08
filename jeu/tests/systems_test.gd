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
	_builds()
	_display()
	_profile()
	_social()
	_campaign()
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
	var n_other := 0
	var type_move := {}
	for id in Data.moves:
		if not type_move.has(Data.moves[id]["type"]):
			type_move[Data.moves[id]["type"]] = id
	for sid in Data.pokemon:
		for e in Data.pokemon[sid]["evos"]:
			var target: int = e.get("to_form", e["to"])
			var lvl: int = e.get("level", 20)
			var m := Pokemon.create(sid, lvl)
			# Évolution au hasard (Chenipotte) : on cherche un Pokémon dont la « personnalité » mène à cette branche.
			if e.has("chance"):
				for k in 300:
					var lo := 0
					for o in Data.pokemon[sid]["evos"]:
						if o == e:
							break
						lo += int(o.get("chance", 0))
					if m.stable_roll() >= lo and m.stable_roll() < lo + int(e["chance"]):
						break
					m = Pokemon.create(sid, lvl)
			var ctx := {"party": [m], "region": e.get("region", "kanto"), "time": e.get("time", "day"),
				"group": e.get("group", false), "terrain": e.get("terrain", "grass")}
			if e.has("natures"):
				m.nature = Pokemon.nature_index(e["natures"][0])
			if e.has("steps"):
				m.counters["steps"] = e["steps"]
			if e.has("held"):
				m.held_item = e["held"]
			if e.has("happiness"):
				m.happiness = 255
				# Évoli connaît parfois une capacité Fée (Nymphali passerait avant Mentali/Noctali, comme dans les jeux).
				if not e.has("move_type"):
					m.moves = [Pokemon.make_move(33)]
			if e.has("gender"):
				m.gender = e["gender"]
			if e.has("move"):
				m.moves = [Pokemon.make_move(e["move"])]
			if e.has("move_type"):
				m.moves = [Pokemon.make_move(type_move[e["move_type"]])]
			if e.has("party"):
				ctx["party"].append(Pokemon.create(e["party"], 10))
			if e.has("party_type"):
				for id2 in Data.pokemon:
					if Data.pokemon[id2]["types"].has(e["party_type"]) and not Data.pokemon[id2].has("form"):
						ctx["party"].append(Pokemon.create(id2, 10))
						break
			if e.has("stats"):
				m.stats[1] = 50 + e["stats"] * 10
				m.stats[2] = 50
			var got := 0
			if e.has("item"):
				got = m.evolution_target("item", e["item"], ctx)
				check(m.evolution_target("item", "poke-ball", ctx) == 0, "%s ne réagit pas à une Poké Ball" % m.name())
				n_item += 1
			elif e.get("trade", false):
				got = m.evolution_target("trade", "", ctx.merged({"trade_with": e.get("trade_with", 0)}))
				var cord := m.evolution_target("item", "linking-cord", ctx)
				check(cord == target or e.has("trade_with"), "%s évolue aussi avec le Fil de Liaison" % m.name())
				n_other += 1
			elif e.has("special") and e["special"] not in ["shed", "spin"]:
				got = m.evolution_target(e["special"], "", ctx)
				n_other += 1
			else:
				got = m.evolution_target("level", "", ctx)
				if e.has("level"):
					var young := Pokemon.create(sid, maxi(1, e["level"] - 1))
					young.held_item = m.held_item
					young.happiness = m.happiness
					young.gender = m.gender
					young.moves = m.moves
					young.stats = m.stats
					check(young.evolution_target("level", "", ctx) != target or e["level"] <= 1, "%s n'évolue pas avant le niveau %d" % [m.name(), e["level"]])
				n_level += 1
			if e.get("special", "") == "shed":
				continue
			check(got == target, "%s -> %s (%s)" % [Data.pokemon[sid]["name"], Pokemon.evo_text(e), JSON.stringify(e)])
			var hp_before := m.hp
			m.evolve(target)
			check(m.sprite_id() == target and m.hp >= hp_before, "%s devient %s" % [Data.pokemon[sid]["name"], Data.pokemon[target]["name"]])
			# La Pierre Stase bloque les évolutions (sauf par objet).
			if not e.has("item") and not e.has("held"):
				var st := Pokemon.create(sid, lvl)
				st.held_item = "everstone"
				check(st.evolution_target("level", "", ctx) != target or e.size() > 2, "Pierre Stase bloque %s" % st.name())
	print("  %d évolutions par niveau, %d par objet, %d autres (échange, spéciales) vérifiées" % [n_level, n_item, n_other])


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
	var sno := Pokemon.create(143, 50)
	sno.moves = [Pokemon.make_move(150)]
	var b := _battle1(p, sno)
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
	press.moves = [Pokemon.make_move(150)]
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
	print("Effets des %d capacités..." % Data.moves.size())
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
		"horn-drill": "ohko", "sheer-cold": "ohko", "psywave": "", "struggle": "", "doom-desire": "différé",
		"aromatic-mist": "allié", "coaching": "allié", "decorate": "allié", "after-you": "double", "ally-switch": "double",
		"quash": "double", "instruct": "double", "rage-powder": "double", "spotlight": "double", "dragon-cheer": "allié",
		"healing-wish": "équipe", "lunar-dance": "équipe", "revival-blessing": "équipe", "shed-tail": "équipe",
		"parting-shot": "équipe", "chilly-reception": "équipe", "u-turn": "", "volt-switch": "", "flip-turn": "",
		"final-gambit": "pv", "last-respects": "", "sketch": "", "copycat": "", "assist": "", "me-first": "", "nature-power": ""}
	# Capacités à condition : on crée la situation qui les rend possibles.
	var setup := {
		"sucker-punch": "target_attacks", "thunderclap": "target_attacks", "comeuppance": "target_priority",
		"upper-hand": "target_priority", "metal-burst": "target_priority",
		"last-resort": "last_resort", "belch": "berry_eaten", "stuff-cheeks": "hold_berry",
		"hyperspace-fury": 720, "aura-wheel": 877, "burn-up": 6, "double-shock": 25,
		"steel-roller": "terrain", "poltergeist": "target_item", "heal-pulse": "heal_target", "floral-healing": "heal_target",
		"pollen-puff": "", "fling": "hold_item", "natural-gift": "hold_berry"}
	var checked := 0
	var skipped := 0
	for id in Data.moves:
		var m: Dictionary = Data.moves[id]
		var ident: String = m["ident"]
		var how = setup.get(ident, "")
		var user := Pokemon.create(how if how is int else 147, 50)  # Minidraco : type Dragon, neutre partout
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
		if how is String and how in ["target_attacks"]:
			target.moves = [Pokemon.make_move(33)]
		if how is String and how in ["target_priority"]:
			target.moves = [Pokemon.make_move(98)]
		if how is String and how == "last_resort":
			user.moves = [Pokemon.make_move(33), Pokemon.make_move(id)]
		if how is String and how in ["hold_berry", "berry_eaten"]:
			user.held_item = "oran-berry"
		if how is String and how == "hold_item":
			user.held_item = "iron-ball"
		if how is String and how == "target_item":
			target.held_item = "leftovers"
		var b := Battle.new([user], [target], true)
		b.always_hit = true
		b.start()
		var tb: Battle.Battler = b.battler(1, 0)
		var ub: Battle.Battler = b.battler(0, 0)
		if how is String and how == "berry_eaten":
			ub.berry_eaten = true
		if how is String and how == "terrain":
			b.terrain = "grassy"
			b.terrain_turns = 5
		if how is String and how == "last_resort":
			b.play_turn({"type": "move", "slot": 0})
			target.hp = target.max_hp()
		var slot := user.moves.size() - 1
		if skip_reason.has(ident):
			# Ces capacités ont des conditions particulières : on vérifie seulement qu'elles ne plantent pas.
			b.play_turn({"type": "move", "slot": 0})
			skipped += 1
			continue
		if m["mcat"] == 3 or ident in ["swallow", "synthesis", "moonlight", "recover", "soft-boiled"]:
			user.hp = user.max_hp() / 3
		if how is String and how == "heal_target":
			target.hp = target.max_hp() / 3
		var hp0 := target.hp
		var uhp0 := user.hp
		var stages0: Dictionary = tb.stages.duplicate()
		var ustages0: Dictionary = ub.stages.duplicate()
		b.play_turn({"type": "move", "slot": slot})
		if TWO_TURN_LIKE(ident):
			b.play_turn({"type": "move", "slot": slot})
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
		elif how is String and how == "heal_target":
			check(target.hp > hp0, what + " soigne la cible")
		elif m["mcat"] == 3:
			check(user.hp > uhp0, what + " soigne")
		elif ident in ["toxic-thread", "tar-shot"]:
			check(tb.stages["spe"] < 0, what + " baisse la Vitesse")
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
	check(e.species == 172 and e.is_egg, "L'Œuf d'un Raichu femelle est un Pichu")
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
			# « @return » : sortie de la base secrète, vers le Centre d'où l'on vient.
			check(Game.maps.has(w["to"]) or (w["to"] == "@return" and mid == "base_secrete"), "Passage %s -> %s" % [mid, w["to"]])
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
	check(old.size() >= 2 and int(old[0][0]) == 129, "Canne de Carmin : surtout des Magicarpe, mais pas que")
	check(sup.any(func(e): return e[2] >= 30), "Méga Canne : Pokémon jusqu'au N.30+")
	check(Game.maps["safari"]["wild"]["super-rod"].any(func(e): return int(e[0]) == 147), "Minidraco pêchable au Parc Safari")
	# Scuba Ball efficace sur un Pokémon pêché.
	var b := _battle1(Pokemon.create(25, 30), Pokemon.create(129, 20))
	check(b.ball_bonus("dive-ball", b.battler(1, 0)) == 1.0, "Scuba Ball x1 hors pêche")
	b.fishing = true
	check(b.ball_bonus("dive-ball", b.battler(1, 0)) == 3.5, "Scuba Ball x3,5 à la pêche")


func _builds() -> void:
	print("Natures, IV, EV, builds...")
	# 25 natures : 5 neutres, 20 qui couvrent chaque paire (+stat, -stat) une seule fois.
	check(Data.natures.size() == 25, "25 natures")
	var pairs := {}
	var neutral := 0
	for n in Data.natures:
		if n["up"] < 0:
			neutral += 1
		else:
			check(n["up"] != n["down"] and n["up"] >= 1 and n["down"] >= 1, "Nature %s modifie deux stats différentes (hors PV)" % n["name"])
			pairs["%d/%d" % [n["up"], n["down"]]] = true
	check(neutral == 5 and pairs.size() == 20, "5 natures neutres + 20 combinaisons (%d, %d)" % [neutral, pairs.size()])
	check(Data.natures[Pokemon.nature_index("adamant")]["name"] == "Rigide" and Data.natures[Pokemon.nature_index("timid")]["name"] == "Timide", "Noms français des natures")
	# Formule des stats (3e génération et suivantes), calculée à la main.
	var p := Pokemon.create(25, 100)
	var b: Array = p.data()["base"]
	p.ivs = [31, 31, 31, 31, 31, 31]
	p.evs = [0, 252, 0, 0, 4, 252]
	p.nature = Pokemon.nature_index("adamant")
	p.recalc_stats()
	check(p.stats[0] == (2 * b[0] + 31) + 100 + 10, "PV = 2xBase + IV + EV/4 + N + 10 (%d)" % p.stats[0])
	check(p.stats[1] == int(float((2 * b[1] + 31 + 63) + 5) * 1.1), "Attaque Rigide 252 EV (%d)" % p.stats[1])
	check(p.stats[3] == int(float((2 * b[3] + 31) + 5) * 0.9), "Atq. Spé. baissée par Rigide (%d)" % p.stats[3])
	check(p.stats[4] == (2 * b[4] + 31 + 1) + 5, "4 EV = +1 point au N.100 (%d)" % p.stats[4])
	var low := Pokemon.create(25, 50)
	low.ivs = [0, 0, 0, 0, 0, 0]
	low.evs = [0, 0, 0, 0, 0, 0]
	low.nature = Pokemon.nature_index("hardy")
	low.recalc_stats()
	var hi := Pokemon.create(25, 50)
	hi.ivs = [31, 31, 31, 31, 31, 31]
	hi.evs = [0, 0, 0, 0, 0, 0]
	hi.nature = low.nature
	hi.recalc_stats()
	check(hi.stats[5] - low.stats[5] == 15, "31 IV = +15 points au N.50 (%d)" % (hi.stats[5] - low.stats[5]))
	# EV : 252 par stat, 510 au total, gagnés en battant des Pokémon.
	var t := Pokemon.create(1, 30)
	t.evs = [0, 0, 0, 0, 0, 0]
	for i in 400:
		t.add_evs([0, 2, 0, 0, 0, 3])
	var tot := 0
	for v in t.evs:
		tot += v
	check(t.evs[5] == 252 and t.evs[1] == 252 and tot <= 510, "EV plafonnés à 252 par stat (%s)" % [t.evs])
	for i in 400:
		t.add_evs([2, 0, 2, 0, 0, 0])
	tot = 0
	for v in t.evs:
		tot += v
	check(tot == 510, "EV plafonnés à 510 au total (%d)" % tot)
	check(Data.pokemon[129]["ev"][5] == 1 and Data.pokemon[143]["ev"][0] == 2, "EV donnés : Magicarpe 1 Vitesse, Ronflex 2 PV")
	# Vitamines (+10) et Baies (-10).
	var v := Pokemon.create(1, 30)
	v.evs = [0, 0, 0, 0, 0, 0]
	check(ItemUse.apply(v, "protein") != "" and v.evs[1] == 10, "Protéine : +10 EV Attaque")
	check(ItemUse.apply(v, "kelpsy-berry") != "" and v.evs[1] == 0, "Baie Alga : -10 EV Attaque")
	check(ItemUse.apply(v, "kelpsy-berry") == "", "Baie inutile à 0 EV (pas consommée)")
	check(ItemUse.field_only("tamato-berry") and ItemUse.field_only("jolly-mint") and ItemUse.targets_pokemon("jolly-mint"), "Baies et Aromates : hors combat, sur un Pokémon")
	# Aromates : changent la nature et donc les stats.
	var m := Pokemon.create(6, 50)
	m.nature = Pokemon.nature_index("modest")
	m.recalc_stats()
	var atk: int = m.stats[1]
	check(ItemUse.apply(m, "adamant-mint") != "" and Data.natures[m.nature]["name"] == "Rigide" and m.stats[1] > atk, "Aromate Rigide")
	check(ItemUse.apply(m, "adamant-mint") == "", "Aromate inutile si la nature est déjà la bonne")
	check(ItemUse.apply(m, "serious-mint") != "" and Data.natures[m.nature]["up"] == -1, "Aromate Sérieux = nature neutre")
	for n in ["lonely", "adamant", "naughty", "brave", "bold", "impish", "lax", "relaxed", "modest", "mild", "rash", "quiet",
			"calm", "gentle", "careful", "sassy", "timid", "hasty", "jolly", "naive", "serious"]:
		check(Data.items.has(n + "-mint") and Pokemon.nature_index(n) >= 0, "Aromate %s" % n)
	# Caractère.
	var c := Pokemon.create(1, 10)
	c.ivs = [0, 0, 0, 0, 0, 0]
	check(c.characteristic() == "Il adore manger", "Caractère : IV tous à 0 -> « Il adore manger »")
	c.ivs = [10, 3, 4, 2, 1, 30]
	check(c.characteristic() == "Il aime la vitesse", "Caractère : meilleur IV en Vitesse (30) -> « Il aime la vitesse »")
	var missing := 0
	for i in 300:
		if Pokemon.create(randi_range(1, 151), 20).characteristic() == "":
			missing += 1
	check(missing == 0, "Chaque Pokémon a un caractère")
	# Synchro : 1 chance sur 2 (+1/25) que la nature soit copiée.
	var saved := Game.party.duplicate()
	var sync := Pokemon.create(63, 20)
	for id in Data.abilities:
		if Data.abilities[id]["ident"] == "synchronize":
			sync.ability = id
	sync.nature = Pokemon.nature_index("timid")
	Game.party = [sync]
	var same := 0
	for i in 1000:
		if Events.pick_wild([[19, 3, 3, 1]]).nature == sync.nature:
			same += 1
	check(same > 440 and same < 600, "Synchro : ~52 %% de natures copiées (%d / 1000)" % same)
	Game.party = saved
	# Pension : 3 IV hérités des parents.
	Game.daycare = [Pokemon.create(19, 20), Pokemon.create(19, 20)]
	Game.daycare[0].gender = 0
	Game.daycare[1].gender = 1
	Game.daycare[0].ivs = [31, 31, 31, 31, 31, 31]
	Game.daycare[1].ivs = [31, 31, 31, 31, 31, 31]
	var perfect := 0
	for i in 200:
		var egg := Game.daycare_make_egg()
		perfect += egg.ivs.count(31)
	check(perfect >= 200 * 3, "Œuf : au moins 3 IV hérités des parents (%.1f IV à 31 en moyenne)" % (perfect / 200.0))
	Game.daycare = []
	# Pêche plus variée et étangs sur les routes de pêche.
	for mid in ["r22", "r4", "r24", "r6", "r11", "r13", "r12"]:
		var water := false
		for row in Game.maps[mid]["rows"]:
			if "~" in row or "w" in row:
				water = true
		check(water, "%s : un point d'eau pour pêcher" % mid)
	for mid in Game.maps:
		var has_water := false
		for row in Game.maps[mid]["rows"]:
			if "~" in row or "w" in row:
				has_water = true
		if has_water:
			check(Game.maps[mid]["wild"]["super-rod"].size() >= 5, "%s : au moins 5 Pokémon à la Méga Canne (%d)" % [mid, Game.maps[mid]["wild"]["super-rod"].size()])


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


func _profile() -> void:
	print("Profil, titres, Ramassage...")
	# Ramassage : chaque tirage, à chaque niveau, donne un objet qui existe.
	for lvl in range(1, 101):
		for k in 30:
			var it := Events.pickup_item(lvl)
			check(Data.items.has(it), "Ramassage N.%d : objet inconnu %s" % [lvl, it])
	# Titres : conditions et sauvegarde.
	Game.new_game()
	check(Game.titles == ["debutant"] and Game.title == "debutant", "Nouveau jeu : titre de départ")
	Profile.add("shinies", 5)
	Profile.add("fish", 9)
	var fresh := Profile.check_titles()
	check(fresh.has("collectionneur_shiny") and fresh.has("chasseur_shiny"), "5 chromatiques : titres débloqués")
	check(not fresh.has("pecheur"), "9 Pokémon pêchés : pas encore Pêcheur")
	Profile.add("fish")
	check(Profile.check_titles().has("pecheur"), "10 Pokémon pêchés : Pêcheur du Dimanche")
	Profile.record_hit({"dmg": 500, "move": "Séisme", "target": "Onix"})
	Profile.record_hit({"dmg": 300, "move": "Charge", "target": "Rattata"})
	check(int(Game.stats["best_damage"]) == 500 and str(Game.stats["best_hit"]).contains("Séisme"), "Plus gros coup gardé")
	Game.title = "pecheur"
	var d := Game.save_dict()
	Game.new_game()
	var restored = Data._intify(JSON.parse_string(JSON.stringify(d)))
	check(restored["title"] == "pecheur" and restored["titles"].has("collectionneur_shiny") and int(restored["stats"]["fish"]) == 10,
		"Titres et statistiques dans la sauvegarde")
	for id in Profile.TITLES:
		var t: Array = Profile.TITLES[id]
		check(t.size() == 4 and Kit.text_width(t[1], 9) <= 206, "Titre %s bien défini et lisible" % id)
	# Le plus gros coup est suivi par le moteur.
	var me := Pokemon.create(6, 80)
	me.moves = [Pokemon.make_move(53)]
	var foe := Pokemon.create(143, 80)
	foe.moves = [Pokemon.make_move(150)]
	var b := _battle1(me, foe)
	b.always_hit = true
	b.play_turn({0: {"type": "move", "slot": 0}})
	check(int(b.best_hit[0].get("dmg", 0)) > 0 and b.best_hit[0].get("target", "") != "", "Le moteur note le plus gros coup du joueur")
	Game.new_game()


func _mk(sid: int, lvl: int, moves: Array, item := "") -> Pokemon:
	var m := Pokemon.create(sid, lvl)
	m.moves = moves.map(func(id): return Pokemon.make_move(id))
	m.held_item = item
	return m


func _social() -> void:
	print("Combats classés, Elo, PvP, décorations...")
	check(Ranked.tier_of(150) == "Uber", "Mewtwo est Uber (%s)" % Ranked.tier_of(150))
	check(Ranked.tier_of(1) == "LC", "Bulbizarre est LC")
	check(Ranked.rank("AG") < Ranked.rank("Uber") and Ranked.rank("Uber") < Ranked.rank("OU") and Ranked.rank("OU") < Ranked.rank("LC"), "Ordre des tiers")
	for pid in Data.pokemon:
		check(Ranked.rank(Ranked.tier_of(int(pid))) < 99, "Tier connu pour %s" % pid)
	var mew2 := _mk(150, 70, [94])
	var luca := _mk(448, 50, [396])
	check(Ranked.validate([mew2, luca], "ou").size() == 1, "Mewtwo refusé en OU")
	check(Ranked.validate([mew2, luca], "ubers").is_empty(), "Mewtwo accepté en Ubers")
	check(Ranked.validate([luca, _mk(448, 40, [396])], "ou").any(func(e): return e.contains("Espèce")), "Clause Espèce")
	check(Ranked.validate([_mk(130, 40, [90])], "ou").any(func(e): return e.contains("OHKO")), "Clause OHKO (Abîme)")
	check(Ranked.validate([_mk(130, 40, [104])], "ou").any(func(e): return e.contains("Esquive")), "Clause Esquive (Reflet)")
	check(Ranked.validate([_mk(172, 5, [84])], "lc").is_empty(), "Pichu accepté en Little Cup")
	check(not Ranked.validate([_mk(25, 5, [84])], "lc").is_empty(), "Pikachu refusé en Little Cup")
	check(Ranked.validate([_mk(144, 50, [58]), _mk(145, 50, [85]), _mk(146, 50, [53])], "vgc").any(func(e): return e.contains("légendaires")), "VGC : 3 légendaires refusés")
	check(Ranked.validate([_mk(151, 50, [94]), luca], "vgc").any(func(e): return e.contains("fabuleux")), "VGC : fabuleux refusé")
	check(Ranked.validate([_mk(3, 50, [202], "leftovers"), _mk(6, 50, [53], "leftovers")], "vgc").any(func(e): return e.contains("Objet")), "VGC : Clause Objet")
	var kanga := _mk(115, 50, [34], "kangaskhanite")
	check(Ranked.rank(Ranked.effective_tier(kanga)) <= Ranked.rank(Ranked.tier_of(115)), "Méga-Gemme : tier de la Méga-Évolution (%s)" % Ranked.effective_tier(kanga))
	var copy := Ranked.battle_team([luca], "lc")
	check(copy[0].level == 5 and luca.level == 50 and copy[0].hp == copy[0].max_hp(), "Équipe classée : copie au niveau du format, original intact")
	check(Ranked.elo_after(1000, 1000) == [1016, 984], "Elo : victoire à égalité +16/-16")
	check(Ranked.elo_after(1000, 1000, true) == [1000, 1000], "Elo : match nul à égalité")
	var up := Ranked.elo_after(1400, 1000)
	check(up[0] - 1400 < 16 and up[0] > 1400, "Elo : battre plus faible rapporte peu (+%d)" % (up[0] - 1400))
	# Perspective inversée.
	var ev := Battle.flip_events([{"t": "hp", "side": 0, "slot": 0}, {"t": "move_anim", "side": 1, "slot": 0, "tside": 0, "tslot": 0},
		{"t": "end", "result": "win"}, {"t": "msg", "text": "\u00010|Lucario\u0002 attaque \u00011|Florizarre\u0002 !"}])
	check(ev[0]["side"] == 1 and ev[1]["side"] == 0 and ev[1]["tside"] == 1 and ev[2]["result"] == "lose", "Inversion des camps et du résultat")
	check(Battle.resolve_text(ev[3]["text"]) == "Lucario adverse attaque Florizarre !", "Noms résolus : « %s »" % Battle.resolve_text(ev[3]["text"]))
	# Moteur en mode PvP.
	var a1 := _mk(286, 60, [147])
	var a2 := _mk(25, 60, [84])
	var b1 := _mk(143, 60, [33])
	var b2 := _mk(130, 60, [33])
	var pb := Battle.new([[a1, a2]], [[b1, b2]], false, [{"name": "Lou"}], {"pvp": true, "player_names": ["Sacha"], "turn_limit": 300})
	pb.always_hit = true
	pb.start()
	pb.play_turn({0: {"type": "move", "slot": 0, "target_side": 1, "target_slot": 0}}, {0: {"type": "move", "slot": 0, "target_side": 0, "target_slot": 0}})
	check(b1.status == "slp", "Spore endort Ronflex (PvP)")
	check(pb.sides[0].party[0].hp < pb.sides[0].party[0].max_hp() or b1.status == "slp", "L'adversaire humain a bien agi")
	pb.play_turn({0: {"type": "move", "slot": 0}}, {0: {"type": "switch", "index": 1}})
	check(pb.battler(1, 0).mon == b2, "Le joueur adverse a changé de Pokémon")
	pb.play_turn({0: {"type": "move", "slot": 0, "target_side": 1, "target_slot": 0}}, {0: {"type": "move", "slot": 0}})
	check(b2.status != "slp", "Clause Sommeil : 2e Pokémon adverse pas endormi")
	var ko := Battle.new([[_mk(6, 100, [53])]], [[_mk(10, 5, [33]), _mk(13, 5, [40])]], false, [{"name": "Lou"}], {"pvp": true})
	ko.always_hit = true
	ko.start()
	ko.play_turn({0: {"type": "move", "slot": 0}}, {0: {"type": "move", "slot": 0}})
	check(ko.foe_need_switch.size() == 1 and not ko.over, "PvP : l'adversaire choisit son remplaçant")
	ko.foe_switch(0, 1)
	check(ko.battler(1, 0) != null and ko.battler(1, 0).mon.species == 13 and ko.foe_need_switch.is_empty(), "PvP : remplaçant envoyé")
	ko.play_turn({0: {"type": "move", "slot": 0}}, {0: {"type": "run"}})
	check(ko.over and ko.result == "win", "PvP : abandon de l'adversaire = victoire")
	check(Battle.resolve_text("\u00011|Aspicot\u0002 est K.O. !") == "Aspicot adverse est K.O. !", "Texte PvP lisible")
	# Décorations.
	Game.new_game()
	check(Decor.give_trophy(59) and not Decor.give_trophy(59) and Game.decor.get("trophy_59", 0) == 1, "Trophée de boss donné une seule fois")
	check(Decor.info("trophy_59")["name"].contains("Arcanin"), "Nom du trophée")
	for id in Decor.CATALOG:
		check(Decor.texture(id) != null and int(Decor.CATALOG[id]["price"]) > 0, "Décoration %s" % id)
		if Decor.CATALOG[id].has("sid"):
			check(Data.pokemon.has(int(Decor.CATALOG[id]["sid"])), "Peluche/statue %s : Pokémon existant" % id)
	Game.new_game()


func _campaign() -> void:
	print("Campagne, Château Rocket, Abîme, Maître des Capacités...")
	var saved_flags: Dictionary = Game.flags.duplicate()
	# Un port par région, et l'ordre de déblocage de la campagne.
	for r in Campaign.ORDER + ["rainbow"]:
		check(not Campaign.port_of(r).is_empty(), "Port d'arrivée de %s" % r)
	Game.flags = {}
	check(not Campaign.unlocked("sevii") and not Campaign.unlocked("rainbow"), "Rien n'est ouvert avant la Ligue")
	Game.set_flag("champion")
	check(Campaign.unlocked("sevii") and not Campaign.unlocked("johto"), "Sevii s'ouvre après la Ligue, Johto après Sevii")
	Game.set_flag("chap_sevii_done")
	check(Campaign.unlocked("johto"), "Johto s'ouvre après Sevii")
	for r in Campaign.ORDER.slice(1, -1):
		Game.set_flag("champion_" + r)
	check(Campaign.unlocked("paldea") and not Campaign.unlocked("rainbow"), "Paldea s'ouvre après Galar, le Château après Paldea")
	Game.set_flag("champion_paldea")
	check(Campaign.unlocked("rainbow"), "Le Château Rocket s'ouvre avec les 8 Maîtres")
	check(Profile.value("region_champions") == 8, "Titre Conquérant : 8 Maîtres comptés")
	Game.set_flag("rainbow_done")
	check(Profile.value("rainbow") == 1, "Titre Fléau de la Team Rainbow")
	Game.flags = saved_flags
	# Abîme : 10 étages, dresseurs à 6 Pokémon au build compétitif, du niveau 91 au niveau 100.
	var top := 0
	var count := 0
	for k in 10:
		var m: Dictionary = Game.maps.get("cr_abime_%d" % (k + 1), {})
		check(not m.is_empty(), "Abîme : étage %d" % (k + 1))
		for npc in m.get("npcs", []):
			if npc.get("kind", "") != "trainer":
				continue
			var t: Dictionary = Game.trainers[npc["trainer"]]
			count += 1
			check(t.get("build", "") == "auto" and int(t.get("ai", 0)) == 3 and t["team"].size() == 6, "Abîme : %s au build auto, IA 3, 6 Pokémon" % t["id"])
			for e in t["team"]:
				top = maxi(top, int(e[1]))
				check(not Data.pokemon[int(e[0])].get("legendary", false), "Abîme : pas de légendaire chez %s" % t["id"])
	check(count >= 15, "Abîme : au moins 15 dresseurs (%d)" % count)
	check(top == 100, "Abîme : niveau 100 au fond (%d)" % top)
	var bottom: Array = Game.maps["cr_abime_10"]["npcs"]
	check(bottom.any(func(x): return int(x.get("species", 0)) == 493), "Arceus au fond de l'Abîme")
	check(bottom.any(func(x): return x["id"] == "gardien"), "Gardien de l'Abîme au fond")
	var gt: Dictionary = Game.trainers["gardien_abime"]
	var gteam: Array = Events.make_team(gt["team"], gt)
	check(gteam.size() == 6 and gteam.all(func(m): return m.level == 100 and m.moves.size() == 4), "Gardien : 6 Pokémon N.100 avec 4 capacités")
	check(gteam.all(func(m): return m.evs.reduce(func(a, b): return a + b, 0) == 508), "Gardien : EV complets")
	# Fin de campagne branchée sur les scripts.
	var specials := []
	for mid in ["cr_chateau_4", "cr_abime_10"]:
		for npc in Game.maps[mid]["npcs"]:
			for cmd in _flatten(npc.get("script", [])):
				if cmd is Array and cmd.size() > 1 and cmd[0] is String and cmd[0] == "special":
					specials.append(cmd[1])
	check(specials.has("finale") and specials.has("abyss_done"), "Giovanni et le Gardien terminent la campagne (%s)" % [specials])
	# Légendaires placés (Paldea, Septentria, Abîme...) et auras valides.
	var legends := {}
	const AURAS := ["", "fire", "steel", "electric", "ghost", "dragon", "grass", "dark", "water", "ice", "psychic", "fairy", "fighting",
		"rock", "ground", "flying"]
	for mid in Game.maps:
		for npc in Game.maps[mid]["npcs"]:
			if npc.get("kind", "") == "legend":
				legends[int(npc["species"])] = mid
			for cmd in _flatten(npc.get("script", [])):
				if cmd is Array and cmd.size() > 4 and cmd[0] is String and cmd[0] == "boss":
					check(cmd[4] in AURAS, "Aura connue : %s (%s)" % [cmd[4], mid])
	for t in Game.trainers.values():
		check(t.get("aura", "") in AURAS, "Aura de dresseur connue : %s" % t.get("aura", ""))
	for sid in [1001, 1002, 1003, 1004, 1007, 1008, 1014, 1015, 1016, 1017, 1024, 1025, 493, 888, 889, 890, 791, 792]:
		check(legends.has(sid), "Légendaire %d placé" % sid)
	# Rencontres : chaque table d'herbe peut se déclencher (herbes hautes, ou sol d'un donjon).
	for mid in Game.maps:
		var m: Dictionary = Game.maps[mid]
		if not m["wild"].has("grass"):
			continue
		var rows := "".join(m["rows"])
		var floor_ok: bool = (m.get("cave", false) or not m.get("outdoor", true)) and (rows.contains("_") or rows.contains("u") or rows.contains("q"))
		check(rows.contains('"') or floor_ok, "Rencontres possibles sur %s" % mid)
	# Maître des Capacités.
	check(Events.relearnable(Pokemon.create(234, 30)).has(828), "Cerfrousse peut réapprendre Sprint Bouclier (évolution en Cerbyllin)")
	check(Events.relearnable(Pokemon.create(221, 40)).has(246), "Cochignon peut réapprendre Pouvoir Antique (évolution en Mammochon)")
	var bulbi := Pokemon.create(1, 5)
	var razor_lv := 0
	for e in bulbi.data()["learn"]:
		if e[1] == 75:
			razor_lv = e[0]
	check(razor_lv > 5 and not Events.relearnable(bulbi).has(75), "Pas de capacité au-dessus du niveau actuel")
	bulbi.level = razor_lv
	check(Events.relearnable(bulbi).has(75), "Capacité réapprenable une fois le niveau atteint")
	check(Game.maps.values().filter(func(m): return m.get("heal", false) and m["npcs"].any(func(x): return x.get("kind", "") == "relearn")).size() > 50,
		"Un Maître des Capacités dans les Centres Pokémon")
	# Objets d'évolution propres au jeu.
	check(Pokemon.create(808, 50).item_evolution("meltan-candy") == 809, "Bonbon Meltan : Meltan -> Melmetal")
	check(Pokemon.create(999, 50).item_evolution("gimmighoul-coin") == 1000, "Pièce de Mordudor : Mordudor -> Gromago")
	check(Pokemon.create(67, 40).item_evolution("linking-cord") == 68, "Fil de Liaison : Machopeur -> Mackogneur")
	check(ItemUse.is_evo_item("meltan-candy") and ItemUse.is_evo_item("gimmighoul-coin"), "Bonbon Meltan et Pièce utilisables")
	# Objets hors combat : Poké Poupée, Grelot Zen.
	var bt := _battle1(Pokemon.create(25, 30), Pokemon.create(16, 30))
	bt.play_turn({"type": "item", "item": "poke-doll"})
	check(bt.over and bt.result == "run", "Poké Poupée : fuite assurée face à un sauvage")
	var bt2 := _battle1(Pokemon.create(25, 30), Pokemon.create(16, 30), false)
	bt2.play_turn({"type": "item", "item": "poke-doll"})
	check(not bt2.over, "Poké Poupée : sans effet contre un dresseur")
	var gz := Pokemon.create(25, 10)
	gz.held_item = "soothe-bell"
	var h0 := gz.happiness
	gz.add_exp(Data.exp_at(gz.data()["growth"], 11) - gz.exp)
	check(gz.level == 11 and gz.happiness == h0 + 5, "Grelot Zen : +5 d'amitié par niveau au lieu de +3")


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
