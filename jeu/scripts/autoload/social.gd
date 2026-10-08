extends Node
## Fonctions sociales en ligne : chat à canaux, Hôtel des Ventes, guildes et classements, combats classés (Elo)
## avec file d'attente, défis, échanges directs, bases secrètes partagées.
##
## Les données communes (classement, guildes, annonces, paiements, bases) sont gardées chez chaque joueur
## (user://monde_partage.json) et fusionnées à chaque connexion : l'enregistrement le plus récent gagne.
## Peu importe qui héberge, tout le monde retrouve le même monde. Les modifications passent par l'hôte de la partie,
## qui les vérifie (annonce encore en vente, nom de guilde libre...) puis les diffuse.

signal changed(coll: String)
signal chat_in(channel: String, line: String)
signal _reply_in
signal _pvp_in

const STORE_PATH := "user://monde_partage.json"
const COLLS := ["ladder", "guilds", "gts", "payouts", "bases"]
const CHANNELS := ["Général", "Commerce", "Aide", "Guilde", "Langues"]
const LANGS := ["FR", "EN", "ES", "DE", "IT", "PT"]
const LOG_MAX := 60
## Taxe de l'Hôtel des Ventes (prélevée sur le vendeur).
const GTS_FEE := 0.05
const GTS_MAX_PER_PLAYER := 12
const GUILD_COST := 20000
## Points de guilde rapportés par les exploits des membres.
const GUILD_POINTS := {"trainer": 1, "leader": 5, "boss": 10, "ranked_win": 15, "shiny": 20, "legend": 25, "gts_sale": 2}

var store := {}
var store_path := STORE_PATH
var chat_logs := {}
var _replies := {}
var _queue: Array = []     # hôte : [{pid, uid, name, fmt, elo, t}]
var _queue_t := 0.0
var _pvp_msgs := {}         # bid -> réponse au défi
var _incoming: Array = []   # défis reçus en attente d'affichage
var in_queue := ""          # format de la file d'attente où l'on est inscrit


func _ready() -> void:
	for c in COLLS:
		store[c] = {}
	for ch in CHANNELS:
		chat_logs[ch] = []
	_load()
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.peer_disconnected.connect(_on_peer_gone)


func _process(delta: float) -> void:
	if not Net.is_host() or _queue.is_empty():
		return
	_queue_t += delta
	if _queue_t >= 1.0:
		_queue_t = 0.0
		_try_match()


## Tests : utiliser un autre fichier de monde partagé (vide au départ).
func use_store(path: String) -> void:
	store_path = path
	for c in COLLS:
		store[c] = {}
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


# ---------------------------------------------------------------------------
# Stockage partagé
# ---------------------------------------------------------------------------

func _load() -> void:
	if not FileAccess.file_exists(store_path):
		return
	var f := FileAccess.open(store_path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for c in COLLS:
			if d.get(c) is Dictionary:
				store[c] = d[c]


func _save() -> void:
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(store))


func _merge_all(other: Dictionary) -> Array:
	var touched := []
	for c in COLLS:
		var recs = other.get(c)
		if not recs is Dictionary:
			continue
		for id in recs:
			if _merge(c, str(id), recs[id]):
				if not touched.has(c):
					touched.append(c)
	return touched


func _merge(coll: String, id: String, rec: Variant) -> bool:
	if not rec is Dictionary:
		return false
	var cur = store[coll].get(id)
	if cur == null or int(rec.get("ts", 0)) > int(cur.get("ts", 0)):
		store[coll][id] = rec
		return true
	return false


## L'hôte enregistre puis diffuse un enregistrement.
func _publish(coll: String, id: String, rec: Dictionary) -> void:
	rec["ts"] = maxi(now_ms(), int(store[coll].get(id, {}).get("ts", 0)) + 1)
	store[coll][id] = rec
	_save()
	if Net.online():
		_records.rpc(coll, {id: rec})
	changed.emit(coll)
	_after_change(coll)


@rpc("any_peer", "call_remote", "reliable")
func _records(coll: String, recs: Dictionary) -> void:
	if not COLLS.has(coll):
		return
	var any := false
	for id in recs:
		any = _merge(coll, str(id), recs[id]) or any
	if any:
		_save()
		changed.emit(coll)
		_after_change(coll)


func _on_connected() -> void:
	_sync_up.rpc_id(1, store)


@rpc("any_peer", "call_remote", "reliable")
func _sync_up(their: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var touched := _merge_all(their)
	_save()
	_sync_down.rpc(store)
	for c in touched:
		changed.emit(c)
		_after_change(c)


@rpc("any_peer", "call_remote", "reliable")
func _sync_down(full: Dictionary) -> void:
	for c in _merge_all(full):
		changed.emit(c)
		_after_change(c)
	_save()
	_claim_payouts.call_deferred()


func _after_change(coll: String) -> void:
	if coll == "guilds":
		Game.stats["guild"] = guild_of(Game.uid)
	elif coll == "ladder":
		var r: Dictionary = store["ladder"].get(Game.uid, {})
		if not r.is_empty():
			Game.stats["elo"] = int(r.get("elo", {}).get("ou", Ranked.START_ELO))
			var best := 0
			for f in r.get("elo", {}):
				best = maxi(best, int(r["elo"][f]))
			Game.stats["elo_best"] = maxi(int(Game.stats.get("elo_best", 0)), best)
	elif coll == "payouts" and Net.online():
		_claim_payouts.call_deferred()


# ---------------------------------------------------------------------------
# Requêtes vers l'hôte (qui vérifie et applique)
# ---------------------------------------------------------------------------

func request(op: String, args := {}) -> Dictionary:
	if not Net.online():
		return {"ok": false, "msg": "Il faut être en ligne : menu MULTIJOUEUR, puis HÉBERGER ou REJOINDRE."}
	args["uid"] = Game.uid
	args["name"] = Game.player_name
	if Net.is_host():
		return _handle(1, op, args)
	var rid := randi()
	_replies.erase(rid)
	_req.rpc_id(1, rid, op, args)
	var waited := 0.0
	while not _replies.has(rid) and waited < 8.0 and Net.online():
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var r: Dictionary = _replies.get(rid, {"ok": false, "msg": "L'hôte de la partie ne répond pas."})
	_replies.erase(rid)
	return r


@rpc("any_peer", "call_remote", "reliable")
func _req(rid: int, op: String, args: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var pid := multiplayer.get_remote_sender_id()
	_rep.rpc_id(pid, rid, _handle(pid, op, args))


@rpc("any_peer", "call_remote", "reliable")
func _rep(rid: int, r: Dictionary) -> void:
	_replies[rid] = r
	_reply_in.emit()


static func fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}


func _handle(pid: int, op: String, a: Dictionary) -> Dictionary:
	var uid: String = str(a.get("uid", ""))
	var who: String = str(a.get("name", "?"))
	if uid == "":
		return fail("Joueur inconnu.")
	match op:
		# --- Hôtel des Ventes ---
		"gts_list":
			var price := int(a.get("price", 0))
			if price < 1 or price > 9999999:
				return fail("Prix invalide (de 1 à 9 999 999 ₽).")
			if gts_listings().filter(func(r): return r["seller"] == uid).size() >= GTS_MAX_PER_PLAYER:
				return fail("Tu as déjà %d annonces en ligne." % GTS_MAX_PER_PLAYER)
			if not a.get("kind", "") in ["pokemon", "item"]:
				return fail("Annonce invalide.")
			var id := "%s_%d" % [uid, now_ms()]
			_publish("gts", id, {"kind": a["kind"], "data": a["data"], "price": price, "seller": uid, "seller_name": who,
				"label": str(a.get("label", "?")), "open": true, "sold_to": "", "created": now_ms()})
			return {"ok": true, "id": id}
		"gts_buy":
			var rec: Dictionary = store["gts"].get(str(a.get("id", "")), {})
			if rec.is_empty() or not rec.get("open", false):
				return fail("Trop tard : cette annonce n'est plus en vente.")
			if rec["seller"] == uid:
				return fail("Tu ne peux pas acheter ta propre annonce.")
			if int(a.get("money", 0)) < int(rec["price"]):
				return fail("Tu n'as pas assez d'argent.")
			var sold := rec.duplicate(true)
			sold["open"] = false
			sold["sold_to"] = who
			_publish("gts", str(a["id"]), sold)
			var gain := int(rec["price"]) - int(round(int(rec["price"]) * GTS_FEE))
			_publish("payouts", "pay_%s_%d" % [rec["seller"], now_ms()], {"uid": rec["seller"], "amount": gain,
				"what": rec["label"], "buyer": who, "claimed": false})
			return {"ok": true, "kind": rec["kind"], "data": rec["data"], "price": rec["price"]}
		"gts_cancel":
			var rec2: Dictionary = store["gts"].get(str(a.get("id", "")), {})
			if rec2.is_empty() or not rec2.get("open", false) or rec2["seller"] != uid:
				return fail("Cette annonce n'est plus en ligne.")
			var c := rec2.duplicate(true)
			c["open"] = false
			c["sold_to"] = "(retirée)"
			_publish("gts", str(a["id"]), c)
			return {"ok": true, "kind": rec2["kind"], "data": rec2["data"]}
		"payout_claim":
			var total := 0
			var lines := []
			for id2 in store["payouts"].keys():
				var p: Dictionary = store["payouts"][id2]
				if p["uid"] == uid and not p.get("claimed", false):
					var c2 := p.duplicate()
					c2["claimed"] = true
					_publish("payouts", id2, c2)
					total += int(p["amount"])
					lines.append("%s vendu à %s : +%d ₽" % [p["what"], p["buyer"], p["amount"]])
			return {"ok": true, "total": total, "lines": lines}
		# --- Guildes ---
		"guild_create":
			var gname := str(a.get("guild", "")).strip_edges()
			if gname.length() < 3 or gname.length() > 16:
				return fail("Le nom de guilde doit faire de 3 à 16 caractères.")
			if guild_of(uid) != "":
				return fail("Tu es déjà dans une guilde.")
			var key := gname.to_lower()
			if store["guilds"].has(key) and not store["guilds"][key].get("gone", false):
				return fail("Ce nom de guilde est déjà pris.")
			_publish("guilds", key, {"name": gname, "leader": uid, "members": {uid: {"name": who, "points": 0}},
				"points": 0, "open": true, "gone": false, "created": now_ms()})
			return {"ok": true}
		"guild_join":
			var g: Dictionary = store["guilds"].get(str(a.get("guild", "")).to_lower(), {})
			if g.is_empty() or g.get("gone", false):
				return fail("Cette guilde n'existe pas.")
			if guild_of(uid) != "":
				return fail("Tu es déjà dans une guilde.")
			if not g.get("open", true):
				return fail("Cette guilde est fermée aux nouveaux membres.")
			var g2 := g.duplicate(true)
			g2["members"][uid] = {"name": who, "points": 0}
			_publish("guilds", g["name"].to_lower(), g2)
			return {"ok": true}
		"guild_leave":
			var key2 := guild_of(uid).to_lower()
			if key2 == "":
				return fail("Tu n'es dans aucune guilde.")
			var g3: Dictionary = store["guilds"][key2].duplicate(true)
			g3["members"].erase(uid)
			if g3["members"].is_empty():
				g3["gone"] = true
			elif g3["leader"] == uid:
				g3["leader"] = g3["members"].keys()[0]
			_publish("guilds", key2, g3)
			return {"ok": true}
		"guild_kick":
			var key3 := guild_of(uid).to_lower()
			var target := str(a.get("target", ""))
			if key3 == "" or store["guilds"][key3]["leader"] != uid:
				return fail("Seul le chef de guilde peut exclure un membre.")
			if target == uid or not store["guilds"][key3]["members"].has(target):
				return fail("Membre introuvable.")
			var g4: Dictionary = store["guilds"][key3].duplicate(true)
			g4["members"].erase(target)
			_publish("guilds", key3, g4)
			return {"ok": true}
		"guild_open":
			var key4 := guild_of(uid).to_lower()
			if key4 == "" or store["guilds"][key4]["leader"] != uid:
				return fail("Seul le chef de guilde peut changer ce réglage.")
			var g5: Dictionary = store["guilds"][key4].duplicate(true)
			g5["open"] = not g5.get("open", true)
			_publish("guilds", key4, g5)
			return {"ok": true, "open": g5["open"]}
		"guild_points":
			var key5 := guild_of(uid).to_lower()
			if key5 == "":
				return {"ok": true}
			var pts := clampi(int(a.get("points", 0)), 0, 100)
			var g6: Dictionary = store["guilds"][key5].duplicate(true)
			g6["points"] = int(g6["points"]) + pts
			g6["members"][uid]["points"] = int(g6["members"][uid].get("points", 0)) + pts
			_publish("guilds", key5, g6)
			return {"ok": true}
		# --- Classement ---
		"ladder_report":
			return _ladder_report(a)
		"queue_join":
			var fmt := str(a.get("fmt", ""))
			if not Ranked.FORMATS.has(fmt):
				return fail("Format inconnu.")
			_queue = _queue.filter(func(q): return q["uid"] != uid)
			_queue.append({"pid": pid, "uid": uid, "name": who, "fmt": fmt, "elo": elo_of(uid, fmt), "t": Time.get_ticks_msec()})
			_try_match()
			return {"ok": true}
		"queue_leave":
			_queue = _queue.filter(func(q): return q["uid"] != uid)
			return {"ok": true}
		# --- Bases secrètes ---
		"base_save":
			var owner := str(a.get("owner", ""))
			var b: Dictionary = store["bases"].get(owner, {"owner": owner, "name": who, "items": [], "members": []}).duplicate(true)
			if owner != uid and not b.get("members", []).has(uid):
				return fail("Seul le propriétaire et ses invités peuvent décorer cette base.")
			b["items"] = a.get("items", [])
			if owner == uid:
				b["name"] = who
			_publish("bases", owner, b)
			return {"ok": true}
		"base_member":
			var b2: Dictionary = store["bases"].get(uid, {"owner": uid, "name": who, "items": [], "members": []}).duplicate(true)
			var mem := str(a.get("member", ""))
			if a.get("add", true):
				if not b2["members"].has(mem):
					b2["members"].append(mem)
			else:
				b2["members"].erase(mem)
			_publish("bases", uid, b2)
			return {"ok": true}
	return fail("Opération inconnue.")


# ---------------------------------------------------------------------------
# Hôtel des Ventes
# ---------------------------------------------------------------------------

func gts_listings() -> Array:
	var out := []
	for id in store["gts"]:
		var r: Dictionary = store["gts"][id]
		if r.get("open", false):
			var c := r.duplicate()
			c["id"] = id
			out.append(c)
	out.sort_custom(func(x, y): return int(x.get("created", 0)) > int(y.get("created", 0)))
	return out


## Récupère l'argent des ventes faites pendant qu'on était absent.
func _claim_payouts() -> void:
	if not Net.online():
		return
	var pending: bool = store["payouts"].values().any(func(p): return p.get("uid", "") == Game.uid and not p.get("claimed", false))
	if not pending:
		return
	var r: Dictionary = await request("payout_claim")
	if r.get("ok", false) and int(r.get("total", 0)) > 0:
		Game.money += int(r["total"])
		Profile.add("gts_sold", r["lines"].size())
		contribute("gts_sale", r["lines"].size())
		for l in r["lines"]:
			Net.message.emit("Hôtel des Ventes : " + l)


# ---------------------------------------------------------------------------
# Guildes
# ---------------------------------------------------------------------------

func guild_of(uid: String) -> String:
	for k in store["guilds"]:
		var g: Dictionary = store["guilds"][k]
		if not g.get("gone", false) and g.get("members", {}).has(uid):
			return g["name"]
	return ""


func guild(name: String) -> Dictionary:
	return store["guilds"].get(name.to_lower(), {})


func guild_ranking() -> Array:
	var out: Array = store["guilds"].values().filter(func(g): return not g.get("gone", false))
	out.sort_custom(func(x, y): return int(x["points"]) > int(y["points"]))
	return out


## Rapporte des points à sa guilde (si on en a une et qu'on est en ligne).
func contribute(kind: String, times := 1) -> void:
	if not Net.online() or guild_of(Game.uid) == "":
		return
	var pts: int = GUILD_POINTS.get(kind, 0) * times
	if pts > 0:
		await request("guild_points", {"points": pts})


# ---------------------------------------------------------------------------
# Classement Elo et file d'attente
# ---------------------------------------------------------------------------

func elo_of(uid: String, fmt: String) -> int:
	return int(store["ladder"].get(uid, {}).get("elo", {}).get(fmt, Ranked.START_ELO))


func ladder(fmt: String) -> Array:
	var out := []
	for uid in store["ladder"]:
		var r: Dictionary = store["ladder"][uid]
		if r.get("elo", {}).has(fmt):
			out.append({"uid": uid, "name": r["name"], "elo": int(r["elo"][fmt]), "w": int(r.get("w", {}).get(fmt, 0)), "l": int(r.get("l", {}).get(fmt, 0))})
	out.sort_custom(func(x, y): return x["elo"] > y["elo"])
	return out


func _ladder_report(a: Dictionary) -> Dictionary:
	var fmt := str(a.get("fmt", "ou"))
	var w: Dictionary = a.get("winner", {})
	var l: Dictionary = a.get("loser", {})
	if w.is_empty() or l.is_empty() or w.get("uid", "") == l.get("uid", ""):
		return fail("Résultat invalide.")
	var draw: bool = a.get("draw", false)
	var ew := elo_of(w["uid"], fmt)
	var el := elo_of(l["uid"], fmt)
	var ne := Ranked.elo_after(ew, el, draw)
	for pair in [[w, ne[0], true], [l, ne[1], false]]:
		var p: Dictionary = pair[0]
		var r: Dictionary = store["ladder"].get(p["uid"], {"name": p["name"], "elo": {}, "w": {}, "l": {}}).duplicate(true)
		r["name"] = p["name"]
		r["elo"][fmt] = pair[1]
		if not draw:
			var key := "w" if pair[2] else "l"
			r[key][fmt] = int(r[key].get(fmt, 0)) + 1
		_publish("ladder", p["uid"], r)
	return {"ok": true, "winner": ne[0], "loser": ne[1], "before": [ew, el]}


func _try_match() -> void:
	var now := Time.get_ticks_msec()
	_queue = _queue.filter(func(q): return q["pid"] == 1 or Net.players.has(q["pid"]))
	for i in _queue.size():
		for j in range(i + 1, _queue.size()):
			var a: Dictionary = _queue[i]
			var b: Dictionary = _queue[j]
			if a["fmt"] != b["fmt"]:
				continue
			var waited := maxf(now - a["t"], now - b["t"]) / 1000.0
			if absi(a["elo"] - b["elo"]) <= 100 + int(waited * 20.0):
				_queue.erase(a)
				_queue.erase(b)
				# Le joueur au plus petit identifiant réseau calcule le combat.
				var host_q: Dictionary = a if a["pid"] < b["pid"] else b
				var guest_q: Dictionary = b if host_q == a else a
				_notify_match(host_q, guest_q, true)
				_notify_match(guest_q, host_q, false)
				return


func _notify_match(me: Dictionary, other: Dictionary, runs: bool) -> void:
	var info := {"fmt": me["fmt"], "opponent": other["name"], "opponent_pid": other["pid"], "opponent_elo": other["elo"], "runs": runs}
	if me["pid"] == multiplayer.get_unique_id():
		_matched(info)
	else:
		_matched.rpc_id(me["pid"], info)


@rpc("any_peer", "call_remote", "reliable")
func _matched(info: Dictionary) -> void:
	in_queue = ""
	_start_ranked.call_deferred(info)


func _start_ranked(info: Dictionary) -> void:
	await _wait_free()
	Net.message.emit("Adversaire trouvé : %s (%d Elo) !" % [info["opponent"], info["opponent_elo"]])
	if info["runs"]:
		await challenge(int(info["opponent_pid"]), info["fmt"], true)


func join_queue(fmt: String) -> Dictionary:
	var errs := Ranked.validate(Game.party, fmt)
	if errs.size() > 0:
		return fail(errs[0])
	var r: Dictionary = await request("queue_join", {"fmt": fmt})
	if r.get("ok", false):
		in_queue = fmt
	return r


func leave_queue() -> void:
	in_queue = ""
	await request("queue_leave")


func _on_peer_gone(pid: int) -> void:
	_queue = _queue.filter(func(q): return q["pid"] != pid)


# ---------------------------------------------------------------------------
# Défis et combats entre joueurs
# ---------------------------------------------------------------------------

func _wait_free() -> void:
	while Game.ui == null or Game.ui_busy() or (Game.world != null and (Game.world.busy or Game.world.moving)) or Net.in_battle:
		await get_tree().create_timer(0.3).timeout


func _pvp_payload(fmt: String) -> Dictionary:
	return {"name": Game.player_name, "uid": Game.uid, "team": Ranked.battle_team(Game.party, fmt).map(func(m): return m.to_dict()),
		"mega": Game.item_count("mega-ring") > 0, "zmove": Game.item_count("z-ring") > 0, "elo": elo_of(Game.uid, fmt)}


## Lance un combat contre un autre joueur (ce joueur calcule le combat). ranked : compte pour l'Elo.
func challenge(pid: int, fmt: String, ranked: bool) -> String:
	var errs := Ranked.validate(Game.party, fmt)
	if errs.size() > 0:
		await Game.ui.say(["Ton équipe ne respecte pas les règles du format %s :" % Ranked.FORMATS[fmt]["name"], errs[0]])
		return ""
	var bid := randi()
	_pvp_msgs.erase(bid)
	_pvp_request.rpc_id(pid, bid, {"fmt": fmt, "ranked": ranked, "from": _pvp_payload(fmt)})
	if not ranked:
		Net.message.emit("Défi envoyé à %s..." % Net.players.get(pid, {}).get("name", "?"))
	var waited := 0.0
	while not _pvp_msgs.has(bid) and waited < 60.0 and Net.players.has(pid):
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var rep: Dictionary = _pvp_msgs.get(bid, {})
	_pvp_msgs.erase(bid)
	if not rep.get("ok", false):
		await _wait_free()
		await Game.ui.say(rep.get("msg", "Pas de réponse de l'autre joueur."))
		return ""
	return await _host_pvp(bid, pid, fmt, ranked, rep)


@rpc("any_peer", "call_remote", "reliable")
func _pvp_request(bid: int, setup: Dictionary) -> void:
	var pid := multiplayer.get_remote_sender_id()
	_answer_pvp.call_deferred(bid, pid, setup)


func _answer_pvp(bid: int, pid: int, setup: Dictionary) -> void:
	await _wait_free()
	var fmt: String = setup["fmt"]
	var f: Dictionary = Ranked.FORMATS[fmt]
	var from: Dictionary = setup["from"]
	if not setup["ranked"]:
		if Game.world != null:
			Game.world.busy = true
		var ok: bool = await Game.ui.confirm("%s te défie en %s (%s) ! Accepter ?" % [from["name"], f["name"], f["desc"]])
		if Game.world != null:
			Game.world.busy = false
		if not ok:
			_pvp_reply.rpc_id(pid, bid, {"ok": false, "msg": "%s a refusé le défi." % Game.player_name})
			return
	var errs := Ranked.validate(Game.party, fmt)
	if errs.size() > 0:
		_pvp_reply.rpc_id(pid, bid, {"ok": false, "msg": "L'équipe de %s ne respecte pas les règles : %s" % [Game.player_name, errs[0]]})
		await Game.ui.say(["Ton équipe ne respecte pas les règles du format :", errs[0]])
		return
	var payload := _pvp_payload(fmt)
	payload["ok"] = true
	_pvp_reply.rpc_id(pid, bid, payload)
	await _join_pvp(bid, pid, fmt, setup["ranked"], from)


@rpc("any_peer", "call_remote", "reliable")
func _pvp_reply(bid: int, rep: Dictionary) -> void:
	_pvp_msgs[bid] = rep
	_pvp_in.emit()


## Côté joueur qui calcule le combat.
func _host_pvp(bid: int, pid: int, fmt: String, ranked: bool, rep: Dictionary) -> String:
	await _wait_free()
	var f: Dictionary = Ranked.FORMATS[fmt]
	var mine := Ranked.battle_team(Game.party, fmt)
	var theirs: Array = rep["team"].map(func(x): return Pokemon.from_dict(x))
	Net.in_battle = true
	if Game.world != null:
		Game.world.busy = true
	Net.send_state()
	Audio.play_music("battle_trainer")
	await Game.ui.battle_intro()
	var opts := {"pvp": true, "double": f["double"], "player_names": [Game.player_name], "mega": Game.item_count("mega-ring") > 0,
		"zmove": Game.item_count("z-ring") > 0, "foe_mega": rep.get("mega", false), "foe_zmove": rep.get("zmove", false),
		"turn_limit": Ranked.TURN_LIMIT}
	var battle := Battle.new([mine], [theirs], false, [{"name": rep["name"]}], opts)
	battle.player_name = Game.player_name
	var screen := BattleScreen.new()
	screen.battle = battle
	screen.bg = "grass"
	screen.coop = {"role": "pvp_host", "bid": bid, "local_owner": 0, "peer": pid}
	var result: String = await Game.ui.open(screen)
	var their_result: String = {"win": "lose", "lose": "win"}.get(result, result)
	if Net.players.has(pid):
		Net._coop_to_guest.rpc_id(pid, bid, "end", {"result": their_result})
	await _pvp_done(result, fmt, ranked, {"uid": rep["uid"], "name": rep["name"]})
	return result


## Côté joueur qui rejoint le combat (il voit son équipe en bas).
func _join_pvp(bid: int, pid: int, fmt: String, ranked: bool, from: Dictionary) -> void:
	Net.in_battle = true
	if Game.world != null:
		Game.world.busy = true
	Net.send_state()
	Audio.play_music("battle_trainer")
	await Game.ui.battle_intro()
	var mirror := Battle.new([], [], false, [{"name": from["name"]}], {"pvp": true})
	mirror.player_name = Game.player_name
	var screen := BattleScreen.new()
	screen.battle = mirror
	screen.bg = "grass"
	screen.coop = {"role": "pvp_guest", "bid": bid, "local_owner": 0, "peer": pid}
	var result: String = await Game.ui.open(screen)
	await _pvp_done(result, fmt, ranked, {})


func _pvp_done(result: String, fmt: String, ranked: bool, opponent: Dictionary) -> void:
	Net.in_battle = false
	if Game.world != null:
		Game.world.busy = false
		Audio.play_music(Game.world.map.get("music", "route"))
	Net.send_state()
	if result == "win":
		Profile.add("pvp_wins")
	elif result == "lose":
		Profile.add("pvp_losses")
	if not ranked:
		return
	if result == "win":
		contribute("ranked_win")
	# C'est le joueur qui a calculé le combat qui déclare le résultat.
	if opponent.is_empty():
		return
	var me := {"uid": Game.uid, "name": Game.player_name}
	var win: Dictionary = me if result != "lose" else opponent
	var lose: Dictionary = opponent if result != "lose" else me
	var r: Dictionary = await request("ladder_report", {"fmt": fmt, "winner": win, "loser": lose, "draw": result == "draw"})
	if r.get("ok", false):
		Net.message.emit("Classement %s mis à jour." % Ranked.FORMATS[fmt]["name"])


# ---------------------------------------------------------------------------
# Échanges directs
# ---------------------------------------------------------------------------

signal _trade_in
var _trade := {}   # état de l'échange en cours


func trade_with(pid: int) -> void:
	var tid := randi()
	_trade = {"id": tid, "peer": pid, "state": "asking"}
	_trade_req.rpc_id(pid, tid, Game.player_name)
	var waited := 0.0
	while _trade.get("state", "") == "asking" and waited < 60.0 and Net.players.has(pid):
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if _trade.get("state", "") != "open":
		var why: String = _trade.get("why", "Pas de réponse.")
		_trade = {}
		await Game.ui.say(why)
		return
	await _open_trade()


@rpc("any_peer", "call_remote", "reliable")
func _trade_req(tid: int, from_name: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	_answer_trade.call_deferred(tid, pid, from_name)


func _answer_trade(tid: int, pid: int, from_name: String) -> void:
	await _wait_free()
	if not _trade.is_empty():
		_trade_ans.rpc_id(pid, tid, false)
		return
	if Game.world != null:
		Game.world.busy = true
	var ok: bool = await Game.ui.confirm("%s veut faire un échange avec toi. Accepter ?" % from_name)
	if Game.world != null:
		Game.world.busy = false
	_trade_ans.rpc_id(pid, tid, ok)
	if ok:
		_trade = {"id": tid, "peer": pid, "state": "open"}
		await _open_trade()


@rpc("any_peer", "call_remote", "reliable")
func _trade_ans(tid: int, ok: bool) -> void:
	if _trade.get("id", -1) != tid:
		return
	_trade["state"] = "open" if ok else "refused"
	_trade["why"] = "L'autre joueur a refusé l'échange." if not ok else ""


func _open_trade() -> void:
	if Game.world != null:
		Game.world.busy = true
	var ts := TradeScreen.new()
	await Game.ui.open(ts)
	_trade = {}
	if Game.world != null:
		Game.world.busy = false


## Envoie mon offre à l'autre joueur : {pokemon: dict|null, item: id, count, money}.
func trade_offer(offer: Dictionary) -> void:
	if _trade.is_empty():
		return
	_trade["mine"] = offer
	_trade["my_ok"] = false
	_trade["their_ok"] = false
	_trade_msg.rpc_id(_trade["peer"], _trade["id"], "offer", offer)


func trade_confirm(ok: bool) -> void:
	if _trade.is_empty():
		return
	_trade["my_ok"] = ok
	_trade_msg.rpc_id(_trade["peer"], _trade["id"], "confirm", {"ok": ok})


func trade_cancel() -> void:
	if not _trade.is_empty() and Net.players.has(_trade["peer"]):
		_trade_msg.rpc_id(_trade["peer"], _trade["id"], "cancel", {})
	_trade = {}


## Applique l'échange validé : retire mon offre (offer : celle de l'écran, avec "where"/"index"),
## ajoute celle de l'autre. Renvoie {"got": Pokémon reçu ou null, "given": espèce donnée}.
func trade_execute(offer: Dictionary) -> Dictionary:
	var theirs: Dictionary = _trade.get("theirs", {})
	var given := 0
	if offer.get("pokemon") is Dictionary:
		var lst: Array = Game.party if offer.get("where", "party") == "party" else Game.pc
		var idx := int(offer.get("index", -1))
		if idx >= 0 and idx < lst.size():
			given = lst[idx].species
			lst.remove_at(idx)
	if offer.get("item", "") != "":
		Game.remove_item(offer["item"], int(offer.get("count", 1)))
	Game.money = maxi(0, Game.money - int(offer.get("money", 0)))
	Game.money += int(theirs.get("money", 0))
	if theirs.get("item", "") != "":
		Game.add_item(theirs["item"], int(theirs.get("count", 1)))
	var got: Pokemon = null
	if theirs.get("pokemon") is Dictionary and not theirs["pokemon"].is_empty():
		got = Pokemon.from_dict(theirs["pokemon"])
		Game.give_pokemon(got)
	return {"got": got, "given": given}


## Fin normale de l'échange (sans prévenir l'autre, qui termine de son côté).
func trade_close() -> void:
	_trade = {}


func trade_state() -> Dictionary:
	return _trade


@rpc("any_peer", "call_remote", "reliable")
func _trade_msg(tid: int, kind: String, data: Dictionary) -> void:
	if _trade.get("id", -1) != tid:
		return
	match kind:
		"offer":
			_trade["theirs"] = data
			_trade["my_ok"] = false
			_trade["their_ok"] = false
		"confirm":
			_trade["their_ok"] = data.get("ok", false)
		"cancel":
			_trade["state"] = "cancelled"
	_trade_in.emit()


# ---------------------------------------------------------------------------
# Discussion à canaux
# ---------------------------------------------------------------------------

func say(channel: String, text: String, lang := "FR") -> void:
	text = text.strip_edges().left(80)
	if text == "":
		return
	var g := guild_of(Game.uid)
	if channel == "Guilde" and g == "":
		Net.message.emit("Tu n'es dans aucune guilde : rejoins-en une pour utiliser ce canal.")
		return
	if Net.online():
		_chat.rpc(channel, Game.player_name, text, lang, g)
	_add_chat(channel, Game.player_name, text, lang)


@rpc("any_peer", "call_remote", "reliable")
func _chat(channel: String, who: String, text: String, lang: String, g: String) -> void:
	if not CHANNELS.has(channel):
		return
	if channel == "Guilde" and (g == "" or g != guild_of(Game.uid)):
		return
	if channel == "Langues" and not Game.settings.get("chat_langs", ["FR"]).has(lang):
		return
	_add_chat(channel, who, text, lang)


func _add_chat(channel: String, who: String, text: String, lang: String) -> void:
	var line := "%s%s : %s" % ["[%s] " % lang if channel == "Langues" else "", who, text]
	var log: Array = chat_logs[channel]
	log.append(line)
	if log.size() > LOG_MAX:
		log.pop_front()
	chat_in.emit(channel, line)
	var reading: bool = Game._stack.size() > 0 and Game._stack[-1] is ChatScreen
	if Game.settings.get("chat_toast", true) and not reading:
		Net.message.emit("[%s] %s" % [channel, line])


# ---------------------------------------------------------------------------
# Bases secrètes
# ---------------------------------------------------------------------------

func base(owner: String) -> Dictionary:
	return store["bases"].get(owner, {"owner": owner, "name": Game.player_name if owner == Game.uid else "?", "items": [], "members": []})


## Enregistre la décoration. Hors ligne : seulement sa propre base (fusionnée à la prochaine connexion).
func save_base(owner: String, items: Array) -> Dictionary:
	if Net.online():
		return await request("base_save", {"owner": owner, "items": items})
	if owner != Game.uid:
		return fail("Il faut être en ligne pour décorer la base d'un autre joueur.")
	var b := base(owner).duplicate(true)
	b["items"] = items
	b["name"] = Game.player_name
	_publish("bases", owner, b)
	return {"ok": true}


## Bases que je peux visiter : la mienne, celles des joueurs qui m'ont invité, et celles des joueurs connectés.
func visitable_bases() -> Array:
	var out := [{"owner": Game.uid, "name": "Ma base"}]
	var online_uids := {}
	for pid in Net.players:
		online_uids[Net.players[pid].get("uid", "")] = true
	for owner in store["bases"]:
		if owner == Game.uid:
			continue
		var b: Dictionary = store["bases"][owner]
		if b.get("members", []).has(Game.uid) or online_uids.has(owner):
			out.append({"owner": owner, "name": "Base de %s" % b.get("name", "?")})
	return out
