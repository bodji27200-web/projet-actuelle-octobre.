class_name OnlineScreen
extends Screen
## Multijoueur : héberger, rejoindre, inviter dans le groupe, discuter.

var _busy := false
var _info: Label
var _list: Label


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("283058")
	bg.size = size
	add_child(bg)
	Kit.label(self, "MULTIJOUEUR", Vector2(14, 6), 20, Color("f8d030"), false)
	var p := Kit.panel(self, Rect2(8, 36, 464, 120))
	_info = Kit.label(p, "", Vector2(10, 4), 14)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size = Vector2(444, 110)
	var p2 := Kit.panel(self, Rect2(8, 160, 464, 80))
	_list = Kit.label(p2, "", Vector2(10, 4), 14)
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.size = Vector2(444, 70)
	_refresh()
	_menu.call_deferred()


func _refresh() -> void:
	if Net.online():
		_info.text = "En ligne (%s). Port : %d.\n" % ["tu héberges la partie" if Net.is_host() else "connecté", Net.PORT]
		if Net.is_host():
			_info.text += "Ton adresse à donner à ton ami : %s\n" % ", ".join(Net.local_ips())
		_info.text += "Groupe : %s" % (Net.players[Net.partner]["name"] if Net.in_group() else "aucun (invite un joueur ci-dessous)")
	else:
		_info.text = "Hors ligne.\nPour jouer à deux : l'un HÉBERGE, l'autre REJOINT avec l'adresse affichée chez l'hôte.\nMême Wi-Fi : ça marche directement. À distance : utilisez un VPN comme Radmin VPN ou ZeroTier (voir le README)."
	var names := []
	for pid in Net.players:
		var st: Dictionary = Net.players[pid]
		names.append("%s — %s (%d badges)%s" % [st.get("name", "?"), Game.maps.get(st.get("map", ""), {}).get("name", "?"), st.get("badges", 0), " ★ groupe" if pid == Net.partner else ""])
	_list.text = "Joueurs connectés :\n" + ("\n".join(names) if names.size() > 0 else "personne pour l'instant")


func _menu() -> void:
	while true:
		_refresh()
		var opts := []
		if not Net.online():
			opts = ["HÉBERGER", "REJOINDRE", "RETOUR"]
		else:
			opts = ["INVITER DANS LE GROUPE", "QUITTER LE GROUPE", "PROFIL D'UN JOUEUR", "ENVOYER UN MESSAGE", "SE DÉCONNECTER", "RETOUR"]
		var i: int = await Game.ui.choose(opts, Vector2(250, 244 - opts.size() * 22), true)
		var choice: String = opts[i] if i >= 0 else "RETOUR"
		match choice:
			"HÉBERGER":
				var err := Net.host()
				if err != OK:
					await Game.ui.say("Impossible d'ouvrir la partie (port %d déjà utilisé ?)." % Net.PORT)
				else:
					Net.send_state()
					await Game.ui.say("Partie ouverte ! Donne à ton ami l'adresse : %s" % ", ".join(Net.local_ips()))
			"REJOINDRE":
				var ip: String = await Game.ui.enter_name("Adresse de l'hôte (ex : 192.168.1.20) :", "127.0.0.1", 40)
				if Net.join(ip.strip_edges()) != OK:
					await Game.ui.say("Adresse invalide.")
				else:
					await Game.ui.say("Connexion en cours...")
					for k in 30:
						await get_tree().create_timer(0.2).timeout
						if Net.online():
							break
					await Game.ui.say("Connecté !" if Net.online() else "Connexion impossible. Vérifie l'adresse et que ton ami héberge bien la partie.")
			"INVITER DANS LE GROUPE":
				var pids := Net.players.keys()
				if pids.is_empty():
					await Game.ui.say("Personne n'est connecté.")
					continue
				var j: int = await Game.ui.ask("Inviter qui ?", pids.map(func(p): return Net.players[p]["name"]))
				if j >= 0:
					Net.invite(pids[j])
					await Game.ui.say("Invitation envoyée !")
			"PROFIL D'UN JOUEUR":
				var pids2 := Net.players.keys()
				if pids2.is_empty():
					await Game.ui.say("Personne n'est connecté.")
					continue
				var j2: int = await Game.ui.ask("Voir le profil de qui ?", pids2.map(func(p): return Net.players[p]["name"]))
				if j2 >= 0:
					await Events.show_profile(pids2[j2])
			"QUITTER LE GROUPE":
				Net.leave_group()
				await Game.ui.say("Tu n'es plus dans un groupe.")
			"ENVOYER UN MESSAGE":
				await Events.chat()
			"SE DÉCONNECTER":
				Net.stop()
				await Game.ui.say("Déconnecté.")
			_:
				finish()
				return
