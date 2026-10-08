class_name TradeScreen
extends Screen
## Échange direct entre deux joueurs : chacun propose un Pokémon, un objet et/ou de l'argent,
## voit l'offre de l'autre, puis les deux valident. Les évolutions par échange se déclenchent.

var _offer := {}           # {"pokemon": dict, "where": "party"/"pc", "index": int, "item": id, "count": n, "money": n}
var _mine: Panel
var _theirs: Panel
var _status: Label
var _busy := false
var _done := false
var _last_seen := {}


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("406880")
	bg.size = size
	add_child(bg)
	Kit.label(self, "ÉCHANGE", Vector2(14, 4), 18, Color("f8d030"), false)
	_mine = Kit.panel(self, Rect2(6, 34, 230, 150))
	_theirs = Kit.panel(self, Rect2(244, 34, 230, 150))
	var sp := Kit.panel(self, Rect2(6, 188, 468, 30), Color("f8f8f8"))
	_status = Kit.label(sp, "", Vector2(10, 0), 13)
	_refresh()
	_menu.call_deferred()


func _peer_name() -> String:
	return Net.players.get(Social.trade_state().get("peer", 0), {}).get("name", "?")


func _draw_offer(p: Panel, title: String, o: Dictionary, ok: bool) -> void:
	Kit.clear(p)
	Kit.label(p, title, Vector2(8, 2), 14, Color("4870a0"))
	var y := 28
	if o.get("pokemon") is Dictionary and not o["pokemon"].is_empty():
		var m := Pokemon.from_dict(o["pokemon"])
		var ic := TextureRect.new()
		ic.position = Vector2(6, y)
		ic.size = Vector2(40, 30)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		Sprites.apply(ic, "icon", m.sprite_id())
		p.add_child(ic)
		Kit.name_line(p, m, Vector2(50, y), 13)
		Kit.label(p, "N.%d  %s" % [m.level, Data.natures[m.nature].get("name", "")], Vector2(50, y + 18), 11)
		var iv := 0
		for v in m.ivs:
			iv += v
		Kit.label(p, "IV : %d/186%s" % [iv, "  ★" if m.shiny else ""], Vector2(50, y + 34), 11)
		if m.held_item != "":
			Kit.label(p, "Tient : %s" % Data.item_name(m.held_item), Vector2(50, y + 50), 11)
		y += 70
	if o.get("item", "") != "":
		Kit.label(p, "%s x%d" % [Data.item_name(o["item"]), o.get("count", 1)], Vector2(8, y), 13)
		y += 22
	if int(o.get("money", 0)) > 0:
		Kit.label(p, "%d ₽" % o["money"], Vector2(8, y), 13)
		y += 22
	if y == 28:
		Kit.label(p, "(rien pour l'instant)", Vector2(8, y), 12, Color("909090"))
	if ok:
		Kit.label(p, "✓ VALIDÉ", Vector2(140, 124), 13, Color("30a040"))


func _refresh() -> void:
	var st := Social.trade_state()
	_draw_offer(_mine, "TON OFFRE", _offer, st.get("my_ok", false))
	_draw_offer(_theirs, "OFFRE DE %s" % _peer_name().to_upper(), st.get("theirs", {}), st.get("their_ok", false))
	if st.get("my_ok", false) and not st.get("their_ok", false):
		_status.text = "En attente de la validation de %s..." % _peer_name()
	elif st.get("their_ok", false) and not st.get("my_ok", false):
		_status.text = "%s a validé ! À toi de valider." % _peer_name()
	else:
		_status.text = "Composez vos offres, puis validez tous les deux."
	_last_seen = st.duplicate(true)


func _process(_d: float) -> void:
	var st := Social.trade_state()
	if not _done and not st.is_empty() and st.hash() != _last_seen.hash():
		_refresh()


func _cancelled() -> bool:
	var st := Social.trade_state()
	return st.is_empty() or st.get("state", "") == "cancelled" or not Net.players.has(st.get("peer", -1))


func _menu() -> void:
	while true:
		if _cancelled():
			_done = true
			await Game.ui.say("L'échange a été annulé.")
			Social.trade_cancel()
			finish()
			return
		var st := Social.trade_state()
		if st.get("my_ok", false):
			# On attend la validation de l'autre (ou une nouvelle offre, qui annule les validations).
			if st.get("their_ok", false):
				_done = true
				await _execute()
				return
			await get_tree().create_timer(0.1).timeout
			continue
		var opts := ["UN POKéMON", "UN OBJET", "DE L'ARGENT", "RETIRER MON OFFRE", "VALIDER", "ANNULER"]
		var i: int = await Game.ui.choose(opts, Vector2(300, 316 - opts.size() * 22 - 10), false)
		if _cancelled():
			continue
		match i:
			0:
				await _pick_pokemon()
			1:
				await _pick_item()
			2:
				var t: String = await Game.ui.enter_name("Combien de ₽ ? (tu as %d ₽)" % Game.money, "0", 9)
				_offer["money"] = clampi(int(t), 0, Game.money)
				Social.trade_offer(_public_offer())
			3:
				_offer = {}
				Social.trade_offer({})
			4:
				if _public_offer().is_empty() and Social.trade_state().get("theirs", {}).is_empty():
					await Game.ui.say("Les deux offres sont vides !")
					continue
				Social.trade_confirm(true)
			5:
				if await Game.ui.confirm("Annuler l'échange ?"):
					Social.trade_cancel()
					_done = true
					finish()
					return
		_refresh()


func _public_offer() -> Dictionary:
	var o := {}
	for k in ["pokemon", "item", "count", "money"]:
		if _offer.has(k):
			o[k] = _offer[k]
	return o


func _pick_pokemon() -> void:
	var w: int = await Game.ui.ask("D'où vient le Pokémon ?", ["ÉQUIPE", "PC"])
	if w == 0:
		if Game.party.size() <= 1:
			await Game.ui.say("Il doit te rester au moins un Pokémon dans l'équipe !")
			return
		var ps := PartyScreen.new()
		ps.mode = "select"
		ps.title = "Quel Pokémon proposer ?"
		var idx = await Game.ui.open(ps)
		if idx == null or idx < 0:
			return
		_offer["pokemon"] = Game.party[idx].to_dict()
		_offer["where"] = "party"
		_offer["index"] = idx
	elif w == 1:
		if Game.pc.is_empty():
			await Game.ui.say("Ton PC est vide.")
			return
		var idx2 = await ListPick.pick("Quel Pokémon du PC proposer ?", Game.pc.map(func(m): return m.name()),
			Game.pc.map(func(m): return "N.%d" % m.level), [], Game.pc.map(func(m): return ["icon", m.sprite_id()]))
		if idx2 is int and idx2 >= 0:
			_offer["pokemon"] = Game.pc[idx2].to_dict()
			_offer["where"] = "pc"
			_offer["index"] = idx2
	else:
		return
	Social.trade_offer(_public_offer())


func _pick_item() -> void:
	var bag := BagScreen.new()
	bag.mode = "trade"
	var item = await Game.ui.open(bag)
	if item == null:
		return
	if Data.items.get(item, {}).get("key", false):
		await Game.ui.say("On ne peut pas échanger un objet rare.")
		return
	var have := Game.item_count(item)
	var t: String = await Game.ui.enter_name("Combien ? (tu en as %d)" % have, "1", 3)
	_offer["item"] = item
	_offer["count"] = clampi(int(t), 1, have)
	Social.trade_offer(_public_offer())


## Les deux ont validé : on donne son offre et on reçoit celle de l'autre.
func _execute() -> void:
	var r := Social.trade_execute(_offer)
	Audio.jingle("item")
	await Game.ui.say("Échange réussi avec %s !" % _peer_name())
	var got: Pokemon = r["got"]
	if got != null:
		var to := got.trade_evolution(int(r["given"]))
		if to != 0:
			await Events.evolve(got, to)
	Social.trade_close()
	Game.save_game()
	finish()
