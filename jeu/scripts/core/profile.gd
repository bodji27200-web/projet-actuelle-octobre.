class_name Profile
extends RefCounted
## Statistiques du dresseur, titres déblocables et carte de profil (consultable par les autres joueurs).

## Titres : id -> [nom, condition affichée, statistique, seuil].
## La statistique peut être une clé de Game.stats ou une valeur calculée (voir value()).
const TITLES := {
	"debutant": ["Dresseur Débutant", "Titre de départ", "", 0],
	"collectionneur_shiny": ["Le Collectionneur Shiny", "Capturer 5 Pokémon chromatiques", "shinies", 5],
	"chasseur_shiny": ["Chasseur d'Étoiles", "Capturer 1 Pokémon chromatique", "shinies", 1],
	"maitre_pecheur": ["Maître Pêcheur", "Pêcher 50 Pokémon", "fish", 50],
	"pecheur": ["Pêcheur du Dimanche", "Pêcher 10 Pokémon", "fish", 10],
	"terreur_arenes": ["La Terreur des Arènes", "Battre 30 Champions d'Arène (revanches)", "leaders", 30],
	"badge_8": ["Détenteur des 8 Badges", "Obtenir les 8 Badges de Kanto", "badges", 8],
	"maitre_ligue": ["Maître de la Ligue", "Devenir Maître de la Ligue Pokémon", "champion", 1],
	"chasseur_legendes": ["Chasseur de Légendes", "Capturer 5 légendaires ou fabuleux", "legends", 5],
	"tueur_boss": ["Fléau des Boss", "Vaincre 10 Pokémon Boss", "bosses", 10],
	"eleveur": ["Éleveur Émérite", "Faire éclore 20 Œufs", "eggs", 20],
	"pokedex_100": ["Encyclopédie Vivante", "Capturer 100 espèces", "dex", 100],
	"pokedex_500": ["Grand Naturaliste", "Capturer 500 espèces", "dex", 500],
	"pokedex_1025": ["Maître du Pokédex", "Capturer les 1025 espèces", "dex", 1025],
	"marcheur": ["Marcheur Infatigable", "Faire 100 000 pas", "steps", 100000],
	"millionnaire": ["Millionnaire", "Avoir 1 000 000 ₽", "money", 1000000],
	"frappeur": ["Frappe Atomique", "Infliger 1 000 dégâts en un coup", "best_damage", 1000],
	"veteran": ["Vétéran", "Gagner 500 combats", "wins", 500],
	"evolutions": ["Professeur en Herbe", "Faire évoluer 50 Pokémon", "evolutions", 50],
	"pvp_1500": ["Duelliste Classé", "Atteindre 1500 Elo en combat classé", "elo", 1500],
	"pvp_1800": ["Légende de l'Arène", "Atteindre 1800 Elo en combat classé", "elo", 1800],
	"marchand": ["Négociant", "Vendre 10 fois à l'Hôtel des Ventes", "gts_sold", 10],
	"guilde": ["Chef de Guilde", "Fonder une guilde", "guild_leader", 1],
	"heros_sevii": ["Héros des Îles Sevii", "Terminer la campagne des Îles Sevii", "sevii", 1],
	"survivant_abime": ["Survivant de l'Abîme", "Vaincre le Gardien de l'Abîme", "abyss", 1],
	"conquerant": ["Conquérant des Régions", "Battre les Maîtres des 8 autres régions", "region_champions", 8],
}

## Statistiques suivies (clé -> libellé sur la carte de profil).
const STAT_LABELS := {
	"wins": "Combats gagnés", "trainers": "Dresseurs battus", "leaders": "Champions d'Arène battus",
	"shinies": "Chromatiques capturés", "legends": "Légendaires capturés", "bosses": "Boss vaincus",
	"fish": "Pokémon pêchés", "eggs": "Œufs éclos", "evolutions": "Évolutions", "caught_total": "Captures au total",
	"pvp_wins": "Victoires en classé", "pvp_losses": "Défaites en classé", "gts_sold": "Ventes à l'Hôtel des Ventes",
}


static func add(key: String, n := 1) -> void:
	Game.stats[key] = int(Game.stats.get(key, 0)) + n


static func record_hit(hit: Dictionary) -> void:
	if hit.is_empty():
		return
	if int(hit.get("dmg", 0)) > int(Game.stats.get("best_damage", 0)):
		Game.stats["best_damage"] = int(hit["dmg"])
		Game.stats["best_hit"] = "%s (%s sur %s)" % [str(hit["dmg"]), hit.get("move", "?"), hit.get("target", "?")]


## Valeur d'une statistique (y compris les valeurs calculées).
static func value(key: String) -> int:
	match key:
		"":
			return 1
		"badges":
			return Game.badge_count()
		"champion":
			return 1 if Game.flag("champion") else 0
		"dex":
			return Game.caught.size()
		"steps":
			return Game.steps
		"money":
			return Game.money
		"elo":
			return int(Game.stats.get("elo_best", 0))
		"sevii":
			return 1 if Game.flag("sevii_done") else 0
		"abyss":
			return 1 if Game.flag("abyss_done") else 0
		"region_champions":
			var n := 0
			for r in ["johto", "hoenn", "sinnoh", "unys", "kalos", "alola", "galar", "paldea"]:
				if Game.flag("champion_" + r):
					n += 1
			return n
	return int(Game.stats.get(key, 0))


static func unlocked(id: String) -> bool:
	return Game.titles.has(id)


## Débloque les titres dont la condition est remplie ; renvoie les nouveaux.
static func check_titles() -> Array:
	var fresh := []
	for id in TITLES:
		if Game.titles.has(id):
			continue
		var t: Array = TITLES[id]
		if value(t[2]) >= int(t[3]):
			Game.titles.append(id)
			fresh.append(id)
	return fresh


## Annonce les nouveaux titres (à appeler après un combat, une éclosion, une évolution...).
static func announce() -> void:
	for id in check_titles():
		Audio.jingle("badge")
		await Game.ui.say(["Nouveau titre débloqué : « %s » !" % TITLES[id][0], "Tu peux l'afficher depuis ta Carte de Dresseur."])
		if Game.title == "debutant":
			Game.title = id
			if Game.world != null:
				Game.world.refresh_player_look()
				Net.send_state()


static func title_name(id: String) -> String:
	return TITLES.get(id, TITLES["debutant"])[0]


## Profil complet, envoyé aux autres joueurs qui consultent la carte.
static func card() -> Dictionary:
	var stats := {}
	for k in STAT_LABELS:
		stats[k] = int(Game.stats.get(k, 0))
	return {"name": Game.player_name, "look": Game.look(), "title": Game.title, "time": int(Game.play_time),
		"seen": Game.seen.size(), "caught": Game.caught.size(), "badges": Game.badges.duplicate(), "money": Game.money,
		"best_hit": Game.stats.get("best_hit", "aucun"), "best_damage": int(Game.stats.get("best_damage", 0)),
		"elo": int(Game.stats.get("elo", 1000)), "guild": Game.stats.get("guild", ""), "stats": stats,
		"titles": Game.titles.size(), "champion": Game.flag("champion"),
		"party": Game.party.filter(func(m): return not m.is_egg).map(func(m): return [m.sprite_id(), m.level, m.shiny])}
