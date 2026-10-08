class_name SocialMenus
extends RefCounted
## Menus des fonctions sociales : Hôtel des Ventes, guildes, combats classés, échanges, bases secrètes.
## Accessibles depuis les guichets des Centres Pokémon et depuis le menu MULTIJOUEUR.


static func ui() -> Node:
	return Game.ui


static func _need_online() -> bool:
	if Net.online():
		return true
	await ui().say(["Cette fonction relie les joueurs entre eux.", "Connecte-toi d'abord : menu MULTIJOUEUR, puis HÉBERGER ou REJOINDRE."])
	return false


static func _price_text(p: int) -> String:
	var s := str(p)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out + " ₽"


static func _mon_desc(m: Pokemon) -> String:
	var iv := 0
	for v in m.ivs:
		iv += v
	var ab := Data.ability_name(m.ability)
	return "N.%d, %s, talent %s, IV %d/186%s%s" % [m.level, Data.natures[m.nature].get("name", ""), ab, iv,
		", tient %s" % Data.item_name(m.held_item) if m.held_item != "" else "", ", chromatique !" if m.shiny else ""]


# ---------------------------------------------------------------------------
# Hôtel des Ventes
# ---------------------------------------------------------------------------

static func gts() -> void:
	if not await _need_online():
		return
	while true:
		var i: int = await ui().ask("Hôtel des Ventes : vends et achète des Pokémon et des objets contre des ₽. (taxe de %d %% sur les ventes)" % int(Social.GTS_FEE * 100),
			["ACHETER", "VENDRE", "MES ANNONCES", "QUITTER"])
		match i:
			0:
				await _gts_buy()
			1:
				await _gts_sell()
			2:
				await _gts_mine()
			_:
				return


static func _gts_buy() -> void:
	var tab := 0
	var search := ""
	while true:
		var all := Social.gts_listings().filter(func(r): return r["seller"] != Game.uid and r["kind"] == ["pokemon", "item"][tab])
		if search != "":
			all = all.filter(func(r): return str(r["label"]).to_lower().contains(search.to_lower()))
		var rows := ["◆ CHERCHER UN NOM" if search == "" else "◆ RECHERCHE : %s (effacer)" % search]
		var rights := [""]
		var descs := ["Filtrer les annonces par nom."]
		var icons := [null]
		for r in all:
			rows.append(r["label"])
			rights.append(_price_text(int(r["price"])))
			if r["kind"] == "pokemon":
				var m := Pokemon.from_dict(r["data"])
				descs.append("Vendu par %s. %s" % [r["seller_name"], _mon_desc(m)])
				icons.append(["icon", m.sprite_id()])
			else:
				descs.append("Vendu par %s. %s" % [r["seller_name"], Data.items.get(r["data"]["item"], {}).get("desc", "")])
				icons.append(["item", r["data"]["item"]])
		var title := "ACHETER — %s (◀ ▶)   Argent : %s" % [["POKéMON", "OBJETS"][tab], _price_text(Game.money)]
		var pick = await ListPick.pick(title, rows, rights, descs, icons, true)
		if pick is Dictionary:
			tab = 1 - tab
			continue
		if pick < 0:
			return
		if pick == 0:
			if search != "":
				search = ""
			else:
				search = (await ui().enter_name("Nom à chercher :", "", 16)).strip_edges()
			continue
		var r: Dictionary = all[pick - 1]
		var price := int(r["price"])
		if Game.money < price:
			await ui().say("Tu n'as pas assez d'argent (%s)." % _price_text(price))
			continue
		if r["kind"] == "pokemon" and Game.party.size() >= Game.PARTY_MAX and Game.pc.size() >= 999:
			await ui().say("Tu n'as plus de place pour un Pokémon.")
			continue
		if not await ui().confirm("Acheter %s pour %s ?" % [r["label"], _price_text(price)]):
			continue
		var res: Dictionary = await Social.request("gts_buy", {"id": r["id"], "money": Game.money})
		if not res.get("ok", false):
			await ui().say(res.get("msg", "Achat impossible."))
			continue
		Game.money -= price
		if res["kind"] == "pokemon":
			var mon := Pokemon.from_dict(res["data"])
			var where := Game.give_pokemon(mon)
			Audio.jingle("catch")
			await ui().say("%s est à toi !%s" % [mon.name(), " Il est envoyé dans le PC." if where == "pc" else ""])
		else:
			Game.add_item(res["data"]["item"], int(res["data"]["count"]))
			Audio.jingle("item")
			await ui().say("Tu reçois %s x%d !" % [Data.item_name(res["data"]["item"]), res["data"]["count"]])
		Game.save_game()


static func _gts_sell() -> void:
	var k: int = await ui().ask("Que veux-tu vendre ?", ["UN POKéMON", "UN OBJET", "ANNULER"])
	var payload := {}
	var give_back := Callable()
	if k == 0:
		var w: int = await ui().ask("D'où vient le Pokémon ?", ["ÉQUIPE", "PC"])
		var lst: Array = Game.party if w == 0 else Game.pc if w == 1 else []
		if lst.is_empty():
			return
		var idx := -1
		if w == 0:
			if Game.party.size() <= 1:
				await ui().say("Il doit te rester au moins un Pokémon dans l'équipe !")
				return
			var ps := PartyScreen.new()
			ps.mode = "select"
			ps.title = "Quel Pokémon vendre ?"
			var r = await ui().open(ps)
			idx = r if r is int else -1
		else:
			var r2 = await ListPick.pick("Quel Pokémon du PC vendre ?", Game.pc.map(func(m): return m.name()),
				Game.pc.map(func(m): return "N.%d" % m.level), Game.pc.map(func(m): return _mon_desc(m)), Game.pc.map(func(m): return ["icon", m.sprite_id()]))
			idx = r2 if r2 is int else -1
		if idx < 0:
			return
		var mon: Pokemon = lst[idx]
		payload = {"kind": "pokemon", "data": mon.to_dict(), "label": "%s N.%d%s" % [mon.name(), mon.level, " ★" if mon.shiny else ""]}
		lst.remove_at(idx)
		give_back = func(): Game.give_pokemon(mon)
	elif k == 1:
		var bag := BagScreen.new()
		bag.mode = "trade"
		var item = await ui().open(bag)
		if item == null:
			return
		if Data.items.get(item, {}).get("key", false):
			await ui().say("On ne peut pas vendre un objet rare.")
			return
		var have := Game.item_count(item)
		var n := clampi(int(await ui().enter_name("Combien ? (tu en as %d)" % have, "1", 3)), 1, have)
		payload = {"kind": "item", "data": {"item": item, "count": n}, "label": "%s x%d" % [Data.item_name(item), n]}
		Game.remove_item(item, n)
		give_back = func(): Game.add_item(item, n)
	else:
		return
	var suggested := 5000
	if payload["kind"] == "item":
		suggested = maxi(100, int(Data.items[payload["data"]["item"]].get("price", 1000)) * int(payload["data"]["count"]))
	var price := int(await ui().enter_name("Prix de vente en ₽ :", str(suggested), 7))
	if price < 1 or not await ui().confirm("Mettre en vente %s pour %s ? (tu toucheras %s)" % [payload["label"], _price_text(price), _price_text(price - int(round(price * Social.GTS_FEE)))]):
		give_back.call()
		return
	payload["price"] = price
	var res: Dictionary = await Social.request("gts_list", payload)
	if not res.get("ok", false):
		give_back.call()
		await ui().say(res.get("msg", "Impossible de mettre en vente."))
		return
	Game.save_game()
	await ui().say(["%s est en vente !" % payload["label"], "Tu recevras l'argent dès qu'un joueur l'achètera (même si tu n'es pas là)."])


static func _gts_mine() -> void:
	while true:
		var mine := Social.gts_listings().filter(func(r): return r["seller"] == Game.uid)
		if mine.is_empty():
			await ui().say("Tu n'as aucune annonce en ligne.")
			return
		var pick = await ListPick.pick("MES ANNONCES (A : retirer de la vente)", mine.map(func(r): return r["label"]),
			mine.map(func(r): return _price_text(int(r["price"]))), [], mine.map(func(r): return ["icon", Pokemon.from_dict(r["data"]).sprite_id()] if r["kind"] == "pokemon" else ["item", r["data"]["item"]]))
		if not pick is int or pick < 0:
			return
		var r: Dictionary = mine[pick]
		if not await ui().confirm("Retirer %s de la vente ?" % r["label"]):
			continue
		var res: Dictionary = await Social.request("gts_cancel", {"id": r["id"]})
		if not res.get("ok", false):
			await ui().say(res.get("msg", "Impossible."))
			continue
		if res["kind"] == "pokemon":
			Game.give_pokemon(Pokemon.from_dict(res["data"]))
		else:
			Game.add_item(res["data"]["item"], int(res["data"]["count"]))
		Game.save_game()
		await ui().say("%s t'est rendu." % r["label"])


# ---------------------------------------------------------------------------
# Guildes
# ---------------------------------------------------------------------------

static func guilds() -> void:
	if not await _need_online():
		return
	while true:
		var g := Social.guild_of(Game.uid)
		if g == "":
			var i: int = await ui().ask("Guichet des Guildes : unis-toi à d'autres dresseurs, gagnez des points ensemble !",
				["CRÉER (%s)" % _price_text(Social.GUILD_COST), "REJOINDRE", "CLASSEMENT", "QUITTER"])
			match i:
				0:
					if Game.money < Social.GUILD_COST:
						await ui().say("Il faut %s pour fonder une guilde." % _price_text(Social.GUILD_COST))
						continue
					var nm: String = (await ui().enter_name("Nom de la guilde (3 à 16 lettres) :", "", 16)).strip_edges()
					if nm == "":
						continue
					var r: Dictionary = await Social.request("guild_create", {"guild": nm})
					if r.get("ok", false):
						Game.money -= Social.GUILD_COST
						Game.stats["guild_leader"] = 1
						Audio.jingle("badge")
						await ui().say("La guilde « %s » est fondée ! Tu en es le chef." % nm)
						await Profile.announce()
					else:
						await ui().say(r.get("msg", "Impossible."))
				1:
					var lst := Social.guild_ranking().filter(func(x): return x.get("open", true))
					if lst.is_empty():
						await ui().say("Aucune guilde n'accepte de membres pour l'instant. Fonde la tienne !")
						continue
					var pick = await ListPick.pick("REJOINDRE UNE GUILDE", lst.map(func(x): return x["name"]),
						lst.map(func(x): return "%d pts" % x["points"]), lst.map(func(x): return "%d membre(s). Chef : %s." % [x["members"].size(), x["members"].get(x["leader"], {}).get("name", "?")]))
					if pick is int and pick >= 0:
						var r2: Dictionary = await Social.request("guild_join", {"guild": lst[pick]["name"]})
						await ui().say("Bienvenue dans la guilde « %s » !" % lst[pick]["name"] if r2.get("ok", false) else r2.get("msg", "Impossible."))
				2:
					await guild_ranking()
				_:
					return
		else:
			var info := Social.guild(g)
			var leader: bool = info.get("leader", "") == Game.uid
			var opts := ["MEMBRES", "CLASSEMENT", "CANAL DE GUILDE"]
			if leader:
				opts.append("FERMER LES ADHÉSIONS" if info.get("open", true) else "OUVRIR LES ADHÉSIONS")
			opts += ["QUITTER LA GUILDE", "RETOUR"]
			var i2: int = await ui().ask("Guilde « %s » : %d points, %d membre(s)." % [g, info.get("points", 0), info.get("members", {}).size()], opts)
			var c: String = opts[i2] if i2 >= 0 else "RETOUR"
			match c:
				"MEMBRES":
					await _guild_members(g, leader)
				"CLASSEMENT":
					await guild_ranking()
				"CANAL DE GUILDE":
					var cs := ChatScreen.new()
					cs.channel = Social.CHANNELS.find("Guilde")
					await ui().open(cs)
				"FERMER LES ADHÉSIONS", "OUVRIR LES ADHÉSIONS":
					var r3: Dictionary = await Social.request("guild_open")
					await ui().say(("La guilde accepte de nouveaux membres." if r3.get("open", false) else "La guilde n'accepte plus de nouveaux membres.") if r3.get("ok", false) else r3.get("msg", ""))
				"QUITTER LA GUILDE":
					if await ui().confirm("Quitter la guilde « %s » ?" % g):
						var r4: Dictionary = await Social.request("guild_leave")
						await ui().say("Tu as quitté la guilde." if r4.get("ok", false) else r4.get("msg", ""))
				_:
					return


static func _guild_members(g: String, leader: bool) -> void:
	var info := Social.guild(g)
	var uids: Array = info["members"].keys()
	uids.sort_custom(func(a, b): return int(info["members"][a].get("points", 0)) > int(info["members"][b].get("points", 0)))
	var rows := uids.map(func(u): return ("★ " if u == info["leader"] else "") + str(info["members"][u]["name"]))
	var pick = await ListPick.pick("MEMBRES DE « %s »%s" % [g, " (A : exclure)" if leader else ""], rows,
		uids.map(func(u): return "%d pts" % int(info["members"][u].get("points", 0))))
	if leader and pick is int and pick >= 0 and uids[pick] != Game.uid:
		if await ui().confirm("Exclure %s de la guilde ?" % info["members"][uids[pick]]["name"]):
			var r: Dictionary = await Social.request("guild_kick", {"target": uids[pick]})
			await ui().say("Membre exclu." if r.get("ok", false) else r.get("msg", ""))


static func guild_ranking() -> void:
	var lst := Social.guild_ranking()
	if lst.is_empty():
		await ui().say("Aucune guilde pour l'instant.")
		return
	var rows := []
	for k in lst.size():
		rows.append("%d. %s" % [k + 1, lst[k]["name"]])
	await ListPick.pick("CLASSEMENT DES GUILDES", rows, lst.map(func(x): return "%d pts" % x["points"]),
		lst.map(func(x): return "%d membre(s). Points : combats gagnés, Champions, boss, victoires classées, chromatiques, légendaires, ventes." % x["members"].size()))


# ---------------------------------------------------------------------------
# Combats classés
# ---------------------------------------------------------------------------

static func _pick_format(title: String) -> String:
	var keys := Ranked.FORMATS.keys()
	var pick = await ListPick.pick(title, keys.map(func(k): return Ranked.FORMATS[k]["name"]),
		keys.map(func(k): return "%d Elo" % Social.elo_of(Game.uid, k)), keys.map(func(k): return Ranked.FORMATS[k]["desc"]))
	return keys[pick] if pick is int and pick >= 0 else ""


static func ranked() -> void:
	if not await _need_online():
		return
	while true:
		var opts := ["FILE D'ATTENTE CLASSÉE" if Social.in_queue == "" else "QUITTER LA FILE (%s)" % Ranked.FORMATS[Social.in_queue]["name"],
			"DÉFIER UN JOUEUR", "CLASSEMENT", "VÉRIFIER MON ÉQUIPE", "RÈGLES", "QUITTER"]
		var i: int = await ui().ask("Arène Classée : affronte les autres dresseurs. Ton Elo monte quand tu gagnes !", opts)
		match i:
			0:
				if Social.in_queue != "":
					await Social.leave_queue()
					await ui().say("Tu as quitté la file d'attente.")
					continue
				var fmt := await _pick_format("FORMAT DE LA FILE D'ATTENTE")
				if fmt == "":
					continue
				var r: Dictionary = await Social.join_queue(fmt)
				if r.get("ok", false):
					await ui().say(["Tu es dans la file %s." % Ranked.FORMATS[fmt]["name"], "Continue à jouer : le combat commencera dès qu'un adversaire de ton niveau sera trouvé."])
				else:
					await ui().say(r.get("msg", "Impossible."))
			1:
				await challenge_pick()
			2:
				var fmt2 := await _pick_format("CLASSEMENT : QUEL FORMAT ?")
				if fmt2 == "":
					continue
				var lad := Social.ladder(fmt2)
				if lad.is_empty():
					await ui().say("Personne n'a encore joué dans ce format.")
					continue
				var rows := []
				for k in lad.size():
					rows.append("%d. %s" % [k + 1, lad[k]["name"]])
				await ListPick.pick("CLASSEMENT %s" % Ranked.FORMATS[fmt2]["name"], rows, lad.map(func(x): return "%d Elo" % x["elo"]),
					lad.map(func(x): return "%d victoire(s), %d défaite(s)." % [x["w"], x["l"]]))
			3:
				var fmt3 := await _pick_format("VÉRIFIER MON ÉQUIPE POUR QUEL FORMAT ?")
				if fmt3 == "":
					continue
				var errs := Ranked.validate(Game.party, fmt3)
				var tiers := Game.party.filter(func(m): return not m.is_egg).map(func(m): return "%s : %s" % [m.name(), Ranked.effective_tier(m)])
				await ui().say(["Tiers Smogon de ton équipe : " + ", ".join(tiers) + "."] + (["Ton équipe est valide en %s !" % Ranked.FORMATS[fmt3]["name"]] if errs.is_empty() else errs.slice(0, 4)))
			4:
				await ui().say(["Les combats classés suivent les règles de Smogon (tiers National Dex).", "Ton équipe est mise au niveau du format (5, 50 ou 100). Tes Pokémon ne gagnent pas d'expérience et ne perdent rien."] + Ranked.CLAUSES)
			_:
				return


## Défier un joueur connecté (combat amical, sans Elo).
static func challenge_pick() -> void:
	var pids := Net.players.keys()
	if pids.is_empty():
		await ui().say("Personne n'est connecté.")
		return
	var j: int = await ui().ask("Défier qui ?", pids.map(func(p): return Net.players[p]["name"]))
	if j < 0:
		return
	await challenge(pids[j])


static func challenge(pid: int) -> void:
	var fmt := await _pick_format("FORMAT DU DÉFI")
	if fmt == "":
		return
	await Social.challenge(pid, fmt, false)


static func trade_pick() -> void:
	if not await _need_online():
		return
	var pids := Net.players.keys()
	if pids.is_empty():
		await ui().say("Personne n'est connecté.")
		return
	var j: int = await ui().ask("Échanger avec qui ?", pids.map(func(p): return Net.players[p]["name"]))
	if j >= 0:
		await Social.trade_with(pids[j])
		Game.save_game()


# ---------------------------------------------------------------------------
# Bases secrètes
# ---------------------------------------------------------------------------

## Hôtesse des bases (Centres Pokémon) : visiter sa base ou celle d'un ami.
static func base_desk(ow: Node) -> void:
	var lst := Social.visitable_bases()
	var opts: Array = lst.map(func(b): return b["name"].to_upper())
	opts.append("INVITER MON GROUPE À DÉCORER" if Net.in_group() else "ANNULER")
	if Net.in_group():
		opts.append("ANNULER")
	var i: int = await ui().ask("Bases Secrètes : un lieu rien qu'à vous, à décorer ensemble avec des peluches, des plantes et vos trophées de boss !", opts)
	if i < 0 or i >= opts.size():
		return
	if i < lst.size():
		await enter_base(ow, lst[i]["owner"])
	elif Net.in_group() and i == lst.size():
		var partner_uid: String = Net.players.get(Net.partner, {}).get("uid", "")
		if partner_uid == "":
			return
		var r: Dictionary = await Social.request("base_member", {"member": partner_uid, "add": true})
		await ui().say("%s peut maintenant décorer ta base avec toi !" % Net.players[Net.partner]["name"] if r.get("ok", false) else r.get("msg", ""))


static func base_map_id(owner: String) -> String:
	return "base:" + owner


static func enter_base(ow: Node, owner: String) -> void:
	var id := base_map_id(owner)
	var m: Dictionary = Game.maps["base_secrete"].duplicate(true)
	m["id"] = id
	m["base_owner"] = owner
	var b := Social.base(owner)
	m["name"] = "Base Secrète de %s" % (Game.player_name if owner == Game.uid else b.get("name", "?"))
	m["region"] = Game.maps.get(ow.map_id, {}).get("region", Game.last_outdoor)
	Game.maps[id] = m
	Game.return_point = {"map": ow.map_id, "x": ow.player.tile.x, "y": ow.player.tile.y}
	Audio.sfx("door")
	await ow.warp_to(id, Vector2i(m["entry"][0], m["entry"][1]), "up")


static func can_decorate(owner: String) -> bool:
	return owner == Game.uid or Social.base(owner).get("members", []).has(Game.uid)


## PC de la base : placer, ranger, acheter des décorations.
static func decorate(ow: Node) -> void:
	var owner: String = ow.map.get("base_owner", "")
	if not can_decorate(owner):
		await ui().say("Seul le propriétaire et ses invités peuvent décorer cette base.")
		return
	while true:
		var i: int = await ui().ask("PC de la base : que veux-tu faire ?", ["PLACER UNE DÉCO", "RANGER UNE DÉCO", "CATALOGUE (ACHETER)", "QUITTER"])
		match i:
			0:
				await _place(ow, owner)
			1:
				await _remove(ow, owner)
			2:
				await decor_shop()
			_:
				return


static func _owned() -> Array:
	var out := []
	for id in Game.decor:
		if int(Game.decor[id]) > 0:
			out.append(id)
	out.sort()
	return out


static func _place(ow: Node, owner: String) -> void:
	var owned := _owned()
	if owned.is_empty():
		await ui().say("Tu n'as aucune décoration. Achète-en au catalogue, ou bats des boss pour gagner leurs trophées !")
		return
	var pick = await ListPick.pick("PLACER QUELLE DÉCORATION ?", owned.map(func(d): return Decor.info(d)["name"]),
		owned.map(func(d): return "x%d" % int(Game.decor[d])), [], owned.map(func(d): return ["icon", Decor.info(d)["sid"]] if Decor.info(d).has("sid") else null))
	if not pick is int or pick < 0:
		return
	var id: String = owned[pick]
	var at: Vector2i = ow.front_tile()
	if not ow.base_free(at):
		await ui().say("Place-toi devant une case libre pour poser la décoration.")
		return
	var items: Array = Social.base(owner).get("items", []).duplicate(true)
	items.append({"id": id, "x": at.x, "y": at.y})
	var r: Dictionary = await Social.save_base(owner, items)
	if not r.get("ok", false):
		await ui().say(r.get("msg", "Impossible."))
		return
	Game.decor[id] = int(Game.decor[id]) - 1
	if int(Game.decor[id]) <= 0:
		Game.decor.erase(id)
	ow.refresh_decor()
	Audio.sfx("select")


static func _remove(ow: Node, owner: String) -> void:
	var at: Vector2i = ow.front_tile()
	var items: Array = Social.base(owner).get("items", []).duplicate(true)
	for k in range(items.size() - 1, -1, -1):
		if int(items[k]["x"]) == at.x and int(items[k]["y"]) == at.y:
			var id: String = items[k]["id"]
			items.remove_at(k)
			var r: Dictionary = await Social.save_base(owner, items)
			if not r.get("ok", false):
				await ui().say(r.get("msg", "Impossible."))
				return
			Game.decor[id] = int(Game.decor.get(id, 0)) + 1
			ow.refresh_decor()
			await ui().say("%s est rangé dans ton sac à décorations." % Decor.info(id)["name"])
			return
	await ui().say("Place-toi devant la décoration à ranger.")


static func decor_shop() -> void:
	var keys := Decor.CATALOG.keys()
	while true:
		var pick = await ListPick.pick("CATALOGUE — Argent : %s" % _price_text(Game.money), keys.map(func(k): return Decor.CATALOG[k]["name"]),
			keys.map(func(k): return _price_text(int(Decor.CATALOG[k]["price"]))),
			keys.map(func(k): return "Tu en as %d." % int(Game.decor.get(k, 0))),
			keys.map(func(k): return ["icon", Decor.CATALOG[k]["sid"]] if Decor.CATALOG[k].has("sid") else null))
		if not pick is int or pick < 0:
			return
		var id: String = keys[pick]
		var price := int(Decor.CATALOG[id]["price"])
		if Game.money < price:
			await ui().say("Tu n'as pas assez d'argent.")
			continue
		if await ui().confirm("Acheter %s pour %s ?" % [Decor.CATALOG[id]["name"], _price_text(price)]):
			Game.money -= price
			Game.decor[id] = int(Game.decor.get(id, 0)) + 1
			Audio.jingle("item")
