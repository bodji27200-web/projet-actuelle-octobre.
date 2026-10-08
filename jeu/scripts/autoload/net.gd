extends Node
## Multijoueur : connexion (ENet), positions des joueurs, groupes, discussion et combats coop.
##
## Chaque joueur garde sa propre sauvegarde. Le joueur qui déclenche un combat coop le calcule (« hôte du combat »),
## son partenaire envoie ses choix et reçoit les événements + l'état du combat après chaque tour.

signal players_changed
signal message(text: String)
signal _coop_msg

const PORT := 24680
const MAX_PLAYERS := 8

var players := {}          # id réseau -> état {name, look, map, x, y, dir, battle, group}
var partner := 0           # id du partenaire de groupe (0 = pas de groupe)
var in_battle := false
var chat_log: Array = []
var _invite_from := 0
var _coop_inbox: Array = []   # messages coop reçus (invité) : {bid, kind, data}
var _actions := {}            # actions reçues (hôte) : "bid:slot" -> action
var _accept := {}             # bid -> réponse de l'invité
var _peer: ENetMultiplayerPeer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_lost)
	multiplayer.connected_to_server.connect(func(): message.emit("Connecté au serveur !"); send_state())
	multiplayer.connection_failed.connect(func(): message.emit("Connexion impossible."); stop())


func online() -> bool:
	return _peer != null and multiplayer.multiplayer_peer == _peer and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return online() and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if online() else 1


func host(port := PORT) -> Error:
	stop()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	message.emit("Partie ouverte ! Les autres joueurs peuvent te rejoindre.")
	return OK


func join(ip: String, port := PORT) -> Error:
	stop()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, port)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	return OK


func stop() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	for pid in players.keys():
		if Game.world != null:
			Game.world.remote_leave(pid)
	players.clear()
	partner = 0
	players_changed.emit()


func local_ips() -> Array:
	return Array(IP.get_local_addresses()).filter(func(a): return a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"))


# ---------------------------------------------------------------------------
# Positions et apparence
# ---------------------------------------------------------------------------

func my_state() -> Dictionary:
	var w = Game.world
	var st := {"name": Game.player_name, "look": Game.look(), "map": Game.map_id, "x": Game.pos.x, "y": Game.pos.y,
		"dir": Game.facing, "battle": in_battle, "group": partner != 0, "badges": Game.badge_count(), "title": Game.title, "uid": Game.uid,
		"guild": Game.stats.get("guild", ""), "elo": int(Game.stats.get("elo", 1000)), "follow": []}
	if w != null and w.follower != null:
		st["follow"] = [w.follower.sid, w.follower.shiny]
	if w != null and w.player != null:
		st["x"] = w.player.tile.x
		st["y"] = w.player.tile.y
		st["dir"] = w.player.dir
	return st


func send_state() -> void:
	if online():
		_state.rpc(my_state())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(st: Dictionary) -> void:
	var pid := multiplayer.get_remote_sender_id()
	var first := not players.has(pid)
	players[pid] = st
	if Game.world != null:
		Game.world.remote_update(pid, st)
	if first:
		players_changed.emit()
		message.emit("%s a rejoint la partie." % st.get("name", "?"))


func _on_peer_connected(pid: int) -> void:
	_state.rpc_id(pid, my_state())


func _on_peer_disconnected(pid: int) -> void:
	var name: String = players.get(pid, {}).get("name", "Un joueur")
	players.erase(pid)
	if Game.world != null:
		Game.world.remote_leave(pid)
	if partner == pid:
		partner = 0
		message.emit("%s a quitté le groupe." % name)
	message.emit("%s s'est déconnecté." % name)
	_coop_inbox.append({"bid": -1, "kind": "lost", "data": {}})
	_coop_msg.emit()
	players_changed.emit()


func _on_server_lost() -> void:
	message.emit("Connexion perdue avec l'hôte.")
	_coop_inbox.append({"bid": -1, "kind": "lost", "data": {}})
	_coop_msg.emit()
	stop()


# ---------------------------------------------------------------------------
# Discussion
# ---------------------------------------------------------------------------

func send_chat(text: String) -> void:
	_chat.rpc(Game.player_name, text)
	_add_chat(Game.player_name, text)


@rpc("any_peer", "call_remote", "reliable")
func _chat(name: String, text: String) -> void:
	_add_chat(name, text)


func _add_chat(name: String, text: String) -> void:
	chat_log.append("%s : %s" % [name, text])
	if chat_log.size() > 30:
		chat_log.pop_front()
	message.emit("%s : %s" % [name, text])


# ---------------------------------------------------------------------------
# Profils (carte de dresseur des autres joueurs)
# ---------------------------------------------------------------------------

signal _profile_in
var _profiles := {}


## Demande la carte d'un joueur ; renvoie {} s'il ne répond pas.
func request_profile(pid: int) -> Dictionary:
	if not players.has(pid):
		return {}
	_profiles.erase(pid)
	_req_profile.rpc_id(pid)
	var waited := 0.0
	while not _profiles.has(pid) and waited < 5.0 and players.has(pid):
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return _profiles.get(pid, {})


@rpc("any_peer", "call_remote", "reliable")
func _req_profile() -> void:
	_send_profile.rpc_id(multiplayer.get_remote_sender_id(), Profile.card())


@rpc("any_peer", "call_remote", "reliable")
func _send_profile(card: Dictionary) -> void:
	_profiles[multiplayer.get_remote_sender_id()] = card
	_profile_in.emit()


# ---------------------------------------------------------------------------
# Groupe
# ---------------------------------------------------------------------------

func in_group() -> bool:
	return partner != 0 and players.has(partner)


func invite(pid: int) -> void:
	_invite.rpc_id(pid, Game.player_name)


@rpc("any_peer", "call_remote", "reliable")
func _invite(from_name: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if partner != 0:
		_invite_reply.rpc_id(pid, false)
		return
	_invite_from = pid
	_ask_invite.call_deferred(pid, from_name)


func _ask_invite(pid: int, from_name: String) -> void:
	while Game.ui == null or Game.ui_busy() or (Game.world != null and (Game.world.busy or Game.world.moving)):
		await get_tree().create_timer(0.3).timeout
	if Game.world != null:
		Game.world.busy = true
	var ok: bool = await Game.ui.confirm("%s t'invite dans son groupe. En groupe, vos combats deviennent des combats 2 contre 2. Accepter ?" % from_name)
	if Game.world != null:
		Game.world.busy = false
	if ok:
		partner = pid
		message.emit("Tu es maintenant en groupe avec %s !" % from_name)
	_invite_reply.rpc_id(pid, ok)
	send_state()


@rpc("any_peer", "call_remote", "reliable")
func _invite_reply(ok: bool) -> void:
	var pid := multiplayer.get_remote_sender_id()
	var name: String = players.get(pid, {}).get("name", "?")
	if ok:
		partner = pid
		message.emit("%s a rejoint ton groupe !" % name)
	else:
		message.emit("%s a refusé l'invitation." % name)
	send_state()


func leave_group() -> void:
	if partner != 0 and players.has(partner):
		_left_group.rpc_id(partner)
	partner = 0
	send_state()


@rpc("any_peer", "call_remote", "reliable")
func _left_group() -> void:
	partner = 0
	message.emit("Ton partenaire a quitté le groupe.")
	send_state()


## Le partenaire est-il prêt pour un combat 2 contre 2 (même carte, libre) ?
func coop_ready() -> bool:
	if not in_group():
		return false
	var st: Dictionary = players[partner]
	return st.get("map", "") == Game.map_id and not st.get("battle", false)


func share_badge(_n: int) -> void:
	pass


# ---------------------------------------------------------------------------
# Combat coop : côté hôte du combat
# ---------------------------------------------------------------------------

func host_coop_battle(enemy_parties: Array, wild: bool, trainers: Array, opts: Dictionary) -> String:
	var bid := randi()
	var setup := {"wild": wild, "trainers": trainers, "opts": opts, "host_name": Game.player_name}
	_accept.erase(bid)
	_coop_request.rpc_id(partner, bid, setup)
	var waited := 0.0
	while not _accept.has(bid) and waited < 6.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var reply: Dictionary = _accept.get(bid, {})
	if reply.is_empty() or not reply.get("ok", false):
		# Partenaire indisponible : combat normal (un seul adversaire).
		var o2 := opts.duplicate()
		o2["no_coop"] = true
		return await Events.run_battle([enemy_parties[0]], wild, trainers.slice(0, 1), o2)
	var guest_party: Array = reply["party"].map(func(x): return Pokemon.from_dict(x))
	var guest_name: String = reply["name"]
	in_battle = true
	send_state()
	Audio.play_music(Events._battle_music(wild, trainers, opts))
	await Game.ui.battle_intro()
	var bopts := Events.battle_opts(opts, wild, enemy_parties, trainers)
	bopts["double"] = false
	bopts["player_names"] = [Game.player_name, guest_name]
	bopts["mega_owners"] = [Game.item_count("mega-ring") > 0, reply.get("mega", false)]
	bopts["z_owners"] = [Game.item_count("z-ring") > 0, reply.get("zmove", false)]
	bopts["mega"] = bopts["mega_owners"].has(true)
	bopts["zmove"] = bopts["z_owners"].has(true)
	var battle := Battle.new([Game.party, guest_party], enemy_parties, wild, trainers, bopts)
	battle.player_name = Game.player_name
	battle.cave = opts.get("cave", false)
	battle.fishing = opts.get("fishing", false)
	battle.caught_species = Game.caught.keys()
	battle.exp_share = [Game.flag("exp_share_on"), reply.get("exp_share", false)]
	var screen := BattleScreen.new()
	screen.battle = battle
	screen.bg = opts.get("bg", "cave" if opts.get("cave", false) else "grass")
	screen.coop = {"role": "host", "bid": bid, "local_owner": 0, "offset": 0, "peer": partner}
	var result: String = await Game.ui.open(screen)
	# Fin : on renvoie au partenaire son équipe à jour et ce qui le concerne.
	var n_host := Game.party.size()
	var guest_after := []
	for i in battle.sides[0].party.size():
		if battle.sides[0].owners[i] == 1:
			guest_after.append(battle.sides[0].party[i].to_dict())
	var leveled := []
	for i in battle.leveled:
		if battle.sides[0].owners[i] == 1:
			leveled.append(i - n_host)
	var end := {"result": result, "party": guest_after, "leveled": leveled, "pay_day": battle.pay_day,
		"caught": battle.caught.to_dict() if battle.caught != null and battle.caught_owner == 1 else {},
		"trainers": trainers, "wild": wild, "best_hit": battle.best_hit[1], "boss": opts.get("boss", false), "fishing": battle.fishing}
	if players.has(partner):
		_coop_to_guest.rpc_id(partner, bid, "end", end)
	in_battle = false
	send_state()
	return await Events.after_battle(battle, result, wild, trainers, opts, 0)


@rpc("any_peer", "call_remote", "reliable")
func _coop_accept(bid: int, reply: Dictionary) -> void:
	_accept[bid] = reply


@rpc("any_peer", "call_remote", "reliable")
func _coop_action(bid: int, slot: int, action: Dictionary) -> void:
	_actions["%d:%d" % [bid, slot]] = action
	_coop_msg.emit()


## État du combat tel que le voit l'autre joueur (en PvP, son camp est en bas : camps inversés).
func _snap_for(battle: Battle, flip: bool) -> Dictionary:
	return Battle.flip_snapshot(battle.snapshot(), battle.owner_name(0, 0)) if flip else battle.snapshot()


## Envoie les événements d'un tour + l'état complet au partenaire (ou à l'adversaire en PvP : flip).
func send_events(bid: int, peer: int, events: Array, battle: Battle, flip := false) -> void:
	if not players.has(peer):
		return
	var ser := []
	for e in events:
		var c: Dictionary = e.duplicate()
		c.erase("mon")
		ser.append(c)
	if flip:
		ser = Battle.flip_events(ser)
	_coop_to_guest.rpc_id(peer, bid, "events", {"events": ser, "snap": _snap_for(battle, flip)})


func ask_actions(bid: int, peer: int, slots: Array, battle: Battle, flip := false) -> void:
	if players.has(peer):
		_coop_to_guest.rpc_id(peer, bid, "ask", {"slots": slots, "snap": _snap_for(battle, flip)})


func ask_switch(bid: int, peer: int, slot: int, battle: Battle, flip := false) -> void:
	if players.has(peer):
		_coop_to_guest.rpc_id(peer, bid, "switch", {"slot": slot, "snap": _snap_for(battle, flip)})


## Attend l'action du partenaire pour un emplacement. S'il est parti : action automatique (abandon en PvP).
func wait_action(bid: int, slot: int, peer: int, pvp := false) -> Dictionary:
	var key := "%d:%d" % [bid, slot]
	while not _actions.has(key):
		if not players.has(peer):
			return {"type": "run"} if pvp else {"type": "move", "slot": 0}
		await _coop_msg
	var a: Dictionary = _actions[key]
	_actions.erase(key)
	return a


# ---------------------------------------------------------------------------
# Combat coop : côté invité
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _coop_request(bid: int, setup: Dictionary) -> void:
	var pid := multiplayer.get_remote_sender_id()
	var busy: bool = in_battle or Game.world == null or Game.world.busy or Game.world.moving or Game.ui_busy() or pid != partner
	if busy or Game.alive_count() == 0:
		_coop_accept.rpc_id(pid, bid, {"ok": false})
		return
	_coop_accept.rpc_id(pid, bid, {"ok": true, "party": Game.party.map(func(m): return m.to_dict()), "name": Game.player_name, "exp_share": Game.flag("exp_share_on"),
		"mega": Game.item_count("mega-ring") > 0, "zmove": Game.item_count("z-ring") > 0})
	_join_coop.call_deferred(bid, pid, setup)


@rpc("any_peer", "call_remote", "reliable")
func _coop_to_guest(bid: int, kind: String, data: Dictionary) -> void:
	_coop_inbox.append({"bid": bid, "kind": kind, "data": data})
	_coop_msg.emit()


func _join_coop(bid: int, pid: int, setup: Dictionary) -> void:
	in_battle = true
	Game.world.busy = true
	send_state()
	message.emit("%s lance un combat : tu le rejoins !" % setup["host_name"])
	Audio.play_music(Events._battle_music(setup["wild"], setup["trainers"], setup["opts"]))
	await Game.ui.battle_intro()
	var mirror := Battle.new([], [], setup["wild"], setup["trainers"])
	mirror.player_name = Game.player_name
	var own_party := Game.party
	var screen := BattleScreen.new()
	screen.battle = mirror
	screen.bg = setup["opts"].get("bg", "grass")
	screen.coop = {"role": "guest", "bid": bid, "local_owner": 1, "peer": pid}
	var result: String = await Game.ui.open(screen)
	var end: Dictionary = screen.coop.get("end", {})
	Game.party = own_party
	if not end.is_empty():
		# L'hôte nous rend notre équipe à jour (PV, expérience, niveaux, PP...).
		var fresh: Array = end["party"].map(func(x): return Pokemon.from_dict(x))
		for i in mini(fresh.size(), Game.party.size()):
			Game.party[i] = fresh[i]
		var pending: Array = screen.coop.get("learn", [])
		for l in pending:
			var idx: int = l["index"]
			if idx < Game.party.size():
				await Events.learn_move(Game.party[idx], l["move"])
		if result == "win" and not end["wild"]:
			for t in end["trainers"]:
				Game.money += int(t.get("money", 0))
				if t.has("id"):
					Game.set_flag("tr_%s" % t["id"])
					if str(t["id"]).begins_with("leader_"):
						var n := int(str(t["id"]).split("_")[1])
						if not Game.badges.has(n):
							Game.give_badge(n)
							Audio.jingle("badge")
							await Game.ui.say("Grâce au combat en duo, %s obtient aussi le Badge !" % Game.player_name)
		Game.money += int(end.get("pay_day", 0))
		Profile.record_hit(end.get("best_hit", {}))
		if result == "win":
			Profile.add("wins")
			if not end["wild"]:
				Profile.add("trainers", end["trainers"].size())
				for t in end["trainers"]:
					if str(t.get("id", "")).begins_with("leader_"):
						Profile.add("leaders")
			if end.get("boss", false):
				Profile.add("bosses")
		if not end["caught"].is_empty():
			var mon := Pokemon.from_dict(end["caught"])
			Profile.add("caught_total")
			if mon.shiny:
				Profile.add("shinies")
			if Data.pokemon.get(mon.species, {}).get("legendary", false) or Data.pokemon.get(mon.species, {}).get("mythical", false):
				Profile.add("legends")
			if end.get("fishing", false):
				Profile.add("fish")
			Game.give_pokemon(mon)
			Audio.jingle("catch")
			await Game.ui.say("%s est ajouté à ta collection !" % mon.name())
		if result == "lose":
			Game.heal_party()
			var hp: Dictionary = Game.heal_point
			await Game.world.warp_to(hp["map"], Vector2i(hp["x"], hp["y"]), "down")
		else:
			for i in end["leveled"]:
				if i < Game.party.size():
					var m2: Pokemon = Game.party[i]
					var to := m2.level_evolution()
					if to != 0 and not m2.is_fainted():
						await Events.evolve(m2, to)
	await Profile.announce()
	Audio.play_music(Game.world.map.get("music", "route"))
	in_battle = false
	Game.world.busy = false
	send_state()


## Prochain message coop pour ce combat (invité).
func next_coop(bid: int) -> Dictionary:
	while true:
		for i in _coop_inbox.size():
			var m: Dictionary = _coop_inbox[i]
			if m["bid"] == bid or m["kind"] == "lost":
				_coop_inbox.remove_at(i)
				return m
		await _coop_msg
	return {}


func send_action(bid: int, peer: int, slot: int, action: Dictionary) -> void:
	if players.has(peer):
		_coop_action.rpc_id(peer, bid, slot, action)
