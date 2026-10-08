"""Données des régions de la campagne d'après-Ligue (voir regions.py pour le format)."""


def _helpers(W):
    return W.say, W.iff, W.setf, W.give, W.F, W.special, W.battle, W.quest, W.hide


def legend(nid, sid, lvl, text, require=None, flag=None):
    n = {"id": nid, "look": "legend", "kind": "legend", "species": sid, "level": lvl, "flag": flag or f"leg_{sid}", "text": [text]}
    if require:
        n["require"] = require
    return n


def miniboss(W, nid, sid, lvl, aura, intro, after):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    flag = f"boss_{nid}"
    return {"id": nid, "look": "legend", "species": sid, "kind": "script", "ghost": True, "hide_if": F(flag),
            "script": [say(*intro), ["boss", sid, lvl, flag, aura], say(*after), give("rare-candy", 2)]}


def villain_npc(W, realm, nid, look, tid, intro, defeat, next_hint):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    return {"id": nid, "look": look, "kind": "script", "hide_if": F(f"chap_{realm}_villain"), "dir": "down",
            "script": [say(*intro), battle(tid), say(*defeat), setf(f"chap_{realm}_villain"), quest(f"chap_{realm}", 3),
                       say(next_hint), hide(nid)]}


def champion_npc(W, realm, nid, look, tid, name, intro, after, wait):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    return {"id": nid, "look": look, "kind": "script", "dir": "down", "trainer": tid,
            "script": [iff(F(f"champion_{realm}"), [say(f"{name} : Tu es le Maître de cette région désormais, {{player}}. Reviens m'affronter quand tu veux !")],
                           [iff(F(f"chap_{realm}_villain"), [say(*intro), battle(tid), say(*after), special("chapter_done", realm)],
                                [say(wait)])])]}


def chapter(realm, name, explore, villain_done):
    return {"title": f"Chapitre {name}", "main": False, "stages": ["", explore, explore, villain_done, villain_done, villain_done,
                                                                    villain_done, villain_done, villain_done,
                                                                    f"Terminé ! Tu as battu le Maître de {name} et obtenu un Fragment Arc-en-Ciel."]}


def strong_trainer(W, tid, cls, name, team, intro, defeat, look, kind, aura="", money=None, ai=3):
    """Dresseur important : équipe au build compétitif automatique, IA maximale, aura éventuelle."""
    W.tr(tid, cls, name, team, intro, defeat, money=money or max(l for _, l in team) * 200, potions=2, look=look, kind=kind,
         music="gym")
    t = W.trainers[tid]
    t["team"] = [[s, l, {"exact": True}] for s, l in team]
    t["build"] = "auto"
    t["ai"] = ai
    if aura:
        t["aura"] = aura
    return tid


# =============================================================================
# JOHTO
# =============================================================================

def johto(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "johto"
    villain = strong_trainer(W, "rr_johto", "Admin Rainbow", "Amos", [(229, 56), (110, 56), (169, 57), (248, 58)],
                             "La Team Rainbow Rocket ne laissera personne gâcher le retour de Giovanni !",
                             "Impossible... La Team Rocket, vaincue deux fois par le même gamin...", "rocket", "villain", aura="dark")
    champ = strong_trainer(W, "maitre_johto", "Maître", "Peter", [(130, 60), (149, 60), (142, 60), (6, 61), (149, 62), (149, 64)],
                           "Je suis Peter, le Maître des Dragons. Tu as chassé la Team Rainbow Rocket... Montre-moi la force de ton lien avec tes Pokémon !",
                           "Ce combat restera gravé dans ma mémoire.", "elite4", "champion")
    grunt_pool = [19, 20, 41, 42, 88, 89, 109, 110, 198, 228, 229]
    grunts = []
    for k in range(4):
        tid = W.tr(f"rr_johto_sbire_{k}", "Sbire Rainbow", W.NAMES[k * 3], [(grunt_pool[(k * 3 + j) % len(grunt_pool)], 50 + k) for j in range(3)],
                   "La Team Rainbow Rocket règne sur Johto !", "Grr... Le chef va me tuer...", look="rocket")
        grunts.append(tid)
    W.quests["chap_johto"] = chapter(R, "Johto", "Explore Johto en partant d'Oliville. La Team Rainbow Rocket aurait installé un repaire à Acajou...",
                                     "La Team Rainbow Rocket de Johto est vaincue ! Défie le Maître Peter au fond de l'Antre du Dragon, à Ébènelle.")
    W.quests["q_johto_puits"] = {"title": "Les queues de Ramoloss", "stages": ["", "Fargas d'Écorcia est furieux : des sbires coupent les queues des Ramoloss au Puits Ramoloss.",
                                                                             "Terminé ! Fargas t'a offert une Pierre Stase et sa reconnaissance."]}
    W.quests["q_johto_ailes"] = {"title": "Les plumes légendaires", "stages": ["", "Le Sage de Rosalia et le marin d'Oliville parlent de plumes mystérieuses...",
                                                                             "Tu as l'Arc-en-Ci'Aile et l'Argent'Aile : Ho-Oh t'attend au sommet de la Tour Carillon, Lugia au fond des Tourb'Îles."]}
    beasts = [[243, 55, 700, "leg_243", {"flag": "beasts_free"}], [244, 55, 700, "leg_244", {"flag": "beasts_free"}],
              [245, 55, 700, "leg_245", {"flag": "beasts_free"}]]
    return {
        "realm": R, "name": "Johto", "prefix": "jo", "gen": 2, "max_species": 251, "versions": ["15", "16"], "band": (42, 58),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur", "Karatéka", "Médium", "Canon", "Ornithologue"],
        "lore": ["Johto est la région voisine de Kanto. Ici, on vit au rythme des traditions et des vieilles tours d'Écorcia.",
                 "Il y a longtemps, la Tour Cendrée brûla. Trois Pokémon y périrent... et Ho-Oh les ramena à la vie.",
                 "Au fond des Tourb'Îles, au large d'Oliville, dormirait un gardien des mers : Lugia.",
                 "Fargas, à Écorcia, fabrique des Poké Balls avec des Noigrumes. Elles ont toutes un petit secret !",
                 "Les Pokémon du Parc Naturel sont plus nombreux le matin... et les Insectes adorent le Concours !"],
        "mart_extra": ["dusk-ball", "quick-ball", "heal-ball", "moon-ball", "friend-ball", "love-ball", "fast-ball", "level-ball", "lure-ball", "heavy-ball"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-l", "sun-stone", "moon-stone",
                 "dragon-scale", "kings-rock", "metal-coat", "up-grade", "tmsv071", "tmsv081", "tmsv117"],
        "progress": ["oliville", "r38", "rosalia", "r37", "parc", "doublonville", "r34", "bois_chenes", "ecorcia", "r33", "r32", "mauville",
                     "r31", "griotte", "r29", "bourg_geon", "chenal40", "irisia", "r42", "acajou", "lac_colere", "r44", "ebenelle", "r45"],
        "zones": {
            "oliville": {"kind": "town", "at": (0, 1), "loc": "olivine-city", "enc": ["olivine-city"], "port": True,
                         "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                         "assault-vest", "eviolite", "expert-belt", "muscle-band", "wise-glasses", "scope-lens", "quick-claw",
                                         "shell-bell", "black-sludge", "light-clay", "weakness-policy", "white-herb", "power-herb"],
                         "npcs": [{"id": "marin_oliville", "look": "fisher", "kind": "script", "script": [
                             iff(F("champion_johto"), [iff(F("got_silver_wing"), [say("Marin : Lugia dort au fond des Tourb'Îles. Bonne chance !")],
                                                           [say("Marin : Le Maître de Johto ! Tiens, une plume que j'ai trouvée en mer..."), give("silver-wing"),
                                                            setf("got_silver_wing"), quest("q_johto_ailes", 2)])],
                                 [say("Marin : On raconte qu'un gardien des mers dort sous les Tourb'Îles. Il ne se montre qu'aux plus grands dresseurs..."),
                                  quest("q_johto_ailes", 1)])]}]},
            "r38": {"kind": "route", "at": (1, 1), "loc": "johto-route-38", "name": "Routes 38 et 39", "enc": ["johto-route-38", "johto-route-39"]},
            "rosalia": {"kind": "town", "at": (2, 1), "loc": "ecruteak-city", "enc": ["ecruteak-city"],
                        "npcs": [{"id": "sage_rosalia", "look": "oldman", "kind": "script", "script": [
                            iff(F("champion_johto"), [iff(F("got_rainbow_wing"), [say("Sage : Ho-Oh t'attend au sommet de la Tour Carillon.")],
                                                          [say("Sage : Le Maître de Johto... Tu es digne de cette plume aux sept couleurs."), give("rainbow-wing"),
                                                           setf("got_rainbow_wing")])],
                                [say("Sage : Il y a longtemps, la Tour Cendrée brûla. Trois Pokémon y périrent et Ho-Oh les ressuscita...",
                                     "Ils se cachent encore sous la tour. Si tu les réveilles, ils parcourront Johto... mais on ne les croise que très rarement.")])]}]},
            "r37": {"kind": "route", "at": (2, 2), "loc": "johto-route-37", "name": "Routes 36 et 37", "enc": ["johto-route-37", "johto-route-36"], "rare": beasts,
                    "extra": {"grass": [(198, 12)]}},
            "parc": {"kind": "forest", "at": (1, 2), "loc": "national-park", "name": "Parc Naturel", "enc": ["national-park", "johto-route-35"], "rare": beasts},
            "doublonville": {"kind": "town", "at": (2, 3), "loc": "goldenrod-city",
                             "special_shop": ["Grand Magasin", ["tmsv008", "tmsv012", "tmsv019", "tmsv029", "tmsv034", "tmsv047", "tmsv066", "tmsv076",
                                                                 "hp-up", "protein", "iron", "calcium", "zinc", "carbos", "pp-up", "exp-candy-m",
                                                                 "fire-stone", "water-stone", "thunder-stone", "leaf-stone", "sun-stone", "moon-stone"],
                                              ["Vendeuse : Le Grand Magasin de Doublonville a de tout : CT, vitamines, pierres..."]],
                             "houses": [[("conteur", "oldman", 5, 3, "down", {"text": ["Doublonville est la plus grande ville de Johto !", "Sa Tour Radio émet dans toute la région."]})],
                                        [("aide_orme", "scientist", 5, 3, "down", {"kind": "script", "script": [
                                            iff(F("got_togepi"), [say("Assistant : Ton Œuf a éclos ? Les Togepi sont pleins de bonheur !")],
                                                [say("Assistant : Le Prof. Orme a trouvé cet Œuf mystérieux. Il éclora en marchant beaucoup. Prends-le !"),
                                                 ["egg", 175], setf("got_togepi")])]})]]},
            "r34": {"kind": "route", "at": (2, 4), "loc": "johto-route-34", "enc": ["johto-route-34"], "rare": beasts},
            "bois_chenes": {"kind": "forest", "at": (2, 5), "loc": "ilex-forest", "enc": ["ilex-forest"],
                            "npcs": [legend("celebi", 251, 60, "Un vieux sanctuaire de bois... La GS Ball se met à trembler ! Celebi, le Pokémon qui voyage dans le temps, apparaît !",
                                            {"item": "gs-ball"})]},
            "ecorcia": {"kind": "town", "at": (3, 5), "loc": "azalea-town",
                        "npcs": [{"id": "fargas", "look": "oldman", "kind": "script", "script": [
                            iff(F("champion_johto"), [iff(F("got_gs_ball"), [say("Fargas : Le sanctuaire du Bois aux Chênes... Va y poser la GS Ball.")],
                                                          [say("Fargas : Tiens, Maître. Cette GS Ball m'intrigue depuis des années. Elle réagit au Bois aux Chênes..."),
                                                           give("gs-ball"), setf("got_gs_ball")])],
                                [iff(F("tr_rr_johto_sbire_0"), [iff(F("puits_done"), [say("Fargas : Merci encore pour les Ramoloss !")],
                                                                       [say("Fargas : Tu as chassé ces bandits du puits ! Prends ça."), give("everstone"),
                                                                        give("kings-rock"), setf("puits_done"), quest("q_johto_puits", 2)])],
                                     [say("Fargas : Des sbires de la Team Rainbow Rocket coupent les queues des Ramoloss au puits ! Chasse-les !"),
                                      quest("q_johto_puits", 1)])])]}]},
            "r33": {"kind": "route", "at": (4, 5), "loc": "johto-route-33", "enc": ["johto-route-33"]},
            "r32": {"kind": "route", "at": (4, 4), "loc": "johto-route-32", "enc": ["johto-route-32"], "rare": beasts},
            "mauville": {"kind": "town", "at": (4, 3), "loc": "violet-city", "enc": ["violet-city"], "fossil": True},
            "r31": {"kind": "route", "at": (5, 3), "loc": "johto-route-31", "name": "Routes 30 et 31", "enc": ["johto-route-31", "johto-route-30"], "rare": beasts},
            "griotte": {"kind": "town", "at": (6, 3), "loc": "cherrygrove-city", "enc": ["cherrygrove-city"]},
            "r29": {"kind": "route", "at": (7, 3), "loc": "johto-route-29", "enc": ["johto-route-29"], "rare": beasts},
            "bourg_geon": {"kind": "town", "at": (8, 3), "loc": "new-bark-town", "enc": ["new-bark-town"],
                           "lab": {"prof": "Prof. Orme", "starters": [152, 155, 158],
                                   "intro": ["Prof. Orme : Ah, le Maître de Kanto ! Chen m'a parlé de toi.", "Je confie un Pokémon de Johto aux dresseurs prometteurs. Choisis !"]}},
            "chenal40": {"kind": "sea", "at": (0, 2), "loc": "johto-sea-route-40", "name": "Chenaux 40 et 41", "enc": ["johto-sea-route-40", "johto-sea-route-41"]},
            "irisia": {"kind": "town", "at": (0, 3), "loc": "cianwood-city", "enc": ["cianwood-city"]},
            "r42": {"kind": "route", "at": (3, 1), "loc": "johto-route-42", "enc": ["johto-route-42"], "rare": beasts},
            "acajou": {"kind": "town", "at": (4, 1), "loc": "mahogany-town"},
            "lac_colere": {"kind": "lake", "at": (4, 0), "loc": "lake-of-rage", "name": "Lac Colère", "enc": ["lake-of-rage", "johto-route-43"],
                           "npcs": [miniboss(W, "leviator_rouge", 130, 62, "water", ["Un Léviator rouge écarlate surgit du lac, fou de rage !"],
                                              ["Le Léviator rouge replonge... Il a laissé une écaille brillante."])]},
            "r44": {"kind": "route", "at": (5, 1), "loc": "johto-route-44", "enc": ["johto-route-44"], "rare": beasts, "extra": {"grass": [(228, 14)]}},
            "ebenelle": {"kind": "town", "at": (6, 1), "loc": "blackthorn-city", "enc": ["blackthorn-city"]},
            "r45": {"kind": "route", "at": (6, 2), "loc": "johto-route-45", "name": "Routes 45 et 46", "enc": ["johto-route-45", "johto-route-46"], "rare": beasts},
        },
        "links": [("oliville", "r38"), ("r38", "rosalia"), ("rosalia", "r42"), ("r42", "acajou"), ("acajou", "r44"), ("r44", "ebenelle"),
                  ("acajou", "lac_colere"), ("ebenelle", "r45"), ("rosalia", "r37"), ("r37", "parc"), ("r37", "doublonville"),
                  ("doublonville", "r34"), ("r34", "bois_chenes"), ("bois_chenes", "ecorcia"), ("ecorcia", "r33"), ("r33", "r32"),
                  ("r32", "mauville"), ("mauville", "r31"), ("r31", "griotte"), ("griotte", "r29"), ("r29", "bourg_geon"),
                  ("oliville", "chenal40"), ("chenal40", "irisia")],
        "dungeons": [
            {"key": "chetiflor", "name": "Tour Chétiflor", "attach": "mauville", "floors": 2, "theme": "tower", "door": "tower",
             "enc": ["sprout-tower/2f", "sprout-tower/3f"], "trainer_class": "Médium"},
            {"key": "alpha", "name": "Ruines d'Alpha", "attach": "r32", "floors": 2, "theme": "rock",
             "enc": ["ruins-of-alph/interior-a", "ruins-of-alph/interior-b", "ruins-of-alph/interior-c", "ruins-of-alph/interior-d", "ruins-of-alph/outside"],
             "extra": {"grass": [(201, 120)]}, "trainers": 1},
            {"key": "caves_jumelles", "name": "Caves Jumelles", "attach": "r33", "floors": 2, "enc": ["union-cave/1f", "union-cave/b1f", "union-cave/b2f"]},
            {"key": "puits", "name": "Puits Ramoloss", "attach": "ecorcia", "floors": 1, "enc": ["slowpoke-well/1f", "slowpoke-well/b1f"], "trainers": 0,
             "content": [{"id": "sbire_puits", "look": "rocket", "kind": "trainer", "trainer": grunts[0], "sight": 3}]},
            {"key": "tour_cendree", "name": "Tour Cendrée", "attach": "rosalia", "floors": 2, "theme": "mansion", "door": "tower",
             "enc": ["burned-tower/1f", "burned-tower/b1f"],
             "content": [{"id": "betes", "look": "legend", "species": 245, "kind": "script", "ghost": True, "hide_if": F("beasts_free"), "script": [
                 say("Trois Pokémon dorment ici depuis l'incendie... Raikou, Entei et Suicune !", "Ils se réveillent et s'enfuient dans toute la région de Johto !",
                     "Tu pourras peut-être les croiser dans les hautes herbes... mais très rarement."), setf("beasts_free"), hide("betes")]}]},
            {"key": "carillon", "name": "Tour Carillon", "attach": "rosalia", "floors": 3, "theme": "tower", "door": "tower", "bonus": 10,
             "enc": ["bell-tower/2f", "bell-tower/5f", "bell-tower/9f"], "require": F("champion_johto"),
             "locked": "Un moine : La Tour Carillon n'est ouverte qu'au Maître de Johto.",
             "content": [legend("hooh", 250, 70, "Une lumière aux sept couleurs... Ho-Oh, le gardien des cieux, descend du sommet de la tour !",
                                {"item": "rainbow-wing"})]},
            {"key": "tourbiles", "name": "Tourb'Îles", "attach": "chenal40", "floors": 3, "bonus": 10,
             "enc": ["whirl-islands/1f", "whirl-islands/b1f", "whirl-islands/b2f", "whirl-islands/b3f"],
             "content": [legend("lugia", 249, 70, "Au plus profond des Tourb'Îles, un chant immense résonne... Lugia, le gardien des mers !",
                                {"item": "silver-wing"})]},
            {"key": "creuset", "name": "Mont Creuset", "attach": "r42", "floors": 2, "bonus": 6,
             "enc": ["mt-mortar/1f", "mt-mortar/lower-cave", "mt-mortar/upper-cave", "mt-mortar/b1f"], "extra": {"grass": [(218, 18)]},
             "content": [miniboss(W, "kicklee_maitre", 237, 64, "fighting", ["Un Kapoera s'entraîne seul au fond de la grotte. Il te défie !"],
                                  ["Kapoera s'incline et disparaît dans l'ombre."])]},
            {"key": "repaire", "name": "Repaire Rainbow Rocket", "attach": "acajou", "floors": 2, "theme": "rocket", "door": "silph", "music": "rocket",
             "enc": ["team-rocket-hq"], "extra": {"grass": [(100, 40), (109, 40), (41, 30)]}, "trainers": 0,
             "content": [villain_npc(W, R, "amos", "rocket", villain,
                                     ["Amos : Le Maître de Kanto ? Giovanni avait prévu ta venue.", "La Team Rainbow Rocket rassemble les chefs de toutes les équipes du monde... Tu ne l'arrêteras pas !"],
                                     ["Amos : Hmpf. Tu as gagné... cette fois. Mais Giovanni t'attend dans un monde que tu n'imagines pas."],
                                     "Le repaire est libéré ! Le Maître Peter t'attend à l'Antre du Dragon, à Ébènelle."),
                         {"id": "sbire_r1", "look": "rocket", "kind": "trainer", "trainer": grunts[1], "sight": 3},
                         {"id": "sbire_r2", "look": "rocket", "kind": "trainer", "trainer": grunts[2], "sight": 3},
                         {"id": "sbire_r3", "look": "rocket", "kind": "trainer", "trainer": grunts[3], "sight": 3}]},
            {"key": "glace", "name": "Route de Glace", "attach": "r44", "floors": 2, "theme": "ice", "bonus": 6,
             "enc": ["ice-path/1f", "ice-path/b1f", "ice-path/b2f", "ice-path/b3f"],
             "content": [miniboss(W, "mammochon_glace", 473, 66, "ice", ["Un énorme Mammochon bloque le passage gelé !"], ["Mammochon s'éloigne dans la glace."])]},
            {"key": "antre_dragon", "name": "Antre du Dragon", "attach": "ebenelle", "floors": 1, "bonus": 6, "enc": ["dragons-den"],
             "content": [champion_npc(W, R, "peter", "elite4", champ, "Peter",
                                      ["Peter : Je t'attendais, {player}.", "Je suis Peter, Maître de la Ligue de Johto. Mes dragons sont invincibles. Prouve-moi le contraire !"],
                                      ["Peter : ... Incroyable. Tu as le cœur d'un vrai Maître.", "La Team Rainbow Rocket a pris pied à Hoenn. Ils ont recruté Max et Arthur, les chefs des Teams Magma et Aqua !"],
                                      "Peter : La Team Rainbow Rocket se cache encore à Acajou. Chasse-la avant de venir me défier !")]},
            {"key": "grotte_sombre", "name": "Antre Noir", "attach": "r45", "floors": 2, "enc": ["dark-cave/violet-city-entrance", "dark-cave/blackthorn-city-entrance"]},
            {"key": "argente", "name": "Mont Argenté", "attach": "r45", "floors": 3, "theme": "rock", "bonus": 16, "require": F("champion_johto"),
             "locked": "Un garde : Le Mont Argenté est réservé aux Maîtres. Les Pokémon y sont très dangereux !",
             "enc": ["mt-silver/1f-top", "mt-silver/2f", "mt-silver/4f"],
             "content": [miniboss(W, "tyranocif_argente", 248, 78, "dark", ["Le sol tremble... Un Tyranocif gigantesque, entouré d'une aura ténébreuse !"],
                                  ["Tyranocif s'effondre. Le sommet du Mont Argenté est silencieux..."])]},
        ],
    }



# =============================================================================
# ÎLES SEVII (premier chapitre après la Ligue)
# =============================================================================

def ariane_npc(W, R, tid, intro, defeat, hint):
    """Chef de l'entrepôt de Sevii : la battre termine le chapitre (pas de Maître aux Îles Sevii)."""
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    n = villain_npc(W, R, "ariane", "rocket", tid, intro, defeat, hint)
    n["script"] = n["script"][:-2] + [setf("chap_sevii_done"), setf("sevii_done"), quest("chap_sevii", 9)] + n["script"][-2:]
    return n

def ev_species(W, stat, n=4, max_sid=386):
    """Espèces de base qui rapportent des EV dans une seule statistique (les plus rentables d'abord).
    Seulement des Pokémon ordinaires des trois premières générations : pas d'Ultra-Chimère ni de Paradoxe."""
    out = []
    for sid, p in W.POKE.items():
        if sid > max_sid or p["legendary"] or p["mythical"] or p["evolves_from"] or p["egg_groups"] == ["no-eggs"]:
            continue
        if sum(p["base"]) >= 500:
            continue
        ev = p["ev"]
        if ev[stat] > 0 and sum(ev) == ev[stat]:
            out.append((ev[stat], -sum(p["base"]), sid))
    out.sort(reverse=True)
    return [sid for _, _, sid in out[:n]]


def sevii(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "sevii"
    villain = strong_trainer(W, "rr_sevii", "Admin Rainbow", "Ariane", [(24, 46), (110, 47), (45, 47), (229, 48)],
                             "Le Maître de Kanto ? Giovanni avait raison de te craindre... La Team Rainbow Rocket rassemble les chefs du monde entier !",
                             "Tss... Peu importe. Les autres régions sont déjà entre nos mains.", "rocket", "villain", aura="dark")
    grunts = [W.tr(f"rr_sevii_sbire_{k}", "Sbire Rainbow", W.NAMES[k + 5], [(p, 42 + k) for p in ([19, 41, 88], [20, 42, 109], [52, 96, 23])[k]],
                   "Ce entrepôt appartient à la Team Rainbow Rocket !", "Aïe ! Le chef va être furieux...", look="rocket") for k in range(3)]
    W.quests["chap_sevii"] = {"title": "Chapitre Îles Sevii", "main": False, "stages": [
        "", "Des sbires de la Team Rainbow Rocket ont été vus dans un entrepôt de l'Île 5. Enquête !", "",
        "Tu as vaincu Ariane ! Le capitaine peut désormais t'emmener à Johto.", "", "", "", "", "", "Terminé !"]}
    rooms = ["PV", "Attaque", "Défense", "Attaque Spéciale", "Défense Spéciale", "Vitesse"]
    ev_rooms = [{"key": f"ev_{k}", "name": f"Salle des EV {rooms[k]}", "attach": "ile_six", "floors": 1, "theme": "building", "door": "dojo", "door_size": (4, 3),
                 "trainers": 0, "rate": 0.25, "extra": {"grass": [(sid, 20) for sid in ev_species(W, k)]}, "bonus": 0} for k in range(6)]
    return {
        "realm": R, "name": "Îles Sevii", "prefix": "se", "gen": 3, "max_species": 386, "versions": ["10", "11"], "band": (38, 50),
        "classes": ["Topdresseur", "Montagnard", "Pêcheur", "Nageuse", "Ornithologue", "Canon", "Gentleman"],
        "lore": ["Les Îles Sevii sont un archipel au sud de Kanto. On y vient en vacances... d'habitude.",
                 "La nuit, des lumières étranges brillent sur l'Île 5. Des gens en noir y entrent et en sortent.",
                 "Le Centre d'Entraînement EV de l'Île 6 attire les dresseurs qui veulent des Pokémon parfaits.",
                 "Une légende parle d'une Île Aurore où tomberait un Pokémon venu de l'espace..."],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-m", "fire-stone", "water-stone",
                 "thunder-stone", "leaf-stone", "moon-stone", "dusk-stone", "shiny-stone", "dawn-stone", "ice-stone"],
        "progress": ["ile_un", "route_tison", "ile_deux", "ile_trois", "bois_baies", "ile_quatre", "ile_cinq", "ile_six", "ile_sept", "canyon"],
        "zones": {
            "ile_un": {"kind": "port", "at": (0, 1), "loc": "one-island", "name": "Île 1", "enc": ["one-island"], "port": True,
                       "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                       "assault-vest", "eviolite", "heavy-duty-boots", "weakness-policy", "expert-belt", "black-sludge",
                                       "light-clay", "toxic-orb", "flame-orb", "air-balloon", "sitrus-berry", "lum-berry", "white-herb"]},
            "route_tison": {"kind": "route", "at": (1, 1), "loc": "kindle-road", "name": "Route Tison", "enc": ["kindle-road", "treasure-beach"]},
            "ile_deux": {"kind": "town", "at": (0, 2), "loc": "two-island", "name": "Île 2", "enc": ["cape-brink"]},
            "ile_trois": {"kind": "town", "at": (1, 2), "loc": "three-island", "name": "Île 3", "enc": ["bond-bridge"]},
            "bois_baies": {"kind": "forest", "at": (2, 2), "loc": "berry-forest", "enc": ["berry-forest"]},
            "ile_quatre": {"kind": "town", "at": (0, 3), "loc": "four-island", "name": "Île 4", "enc": ["four-island"]},
            "ile_cinq": {"kind": "town", "at": (1, 3), "loc": "five-island", "name": "Île 5", "enc": ["five-island", "five-isle-meadow", "memorial-pillar"]},
            "ile_six": {"kind": "town", "at": (2, 3), "loc": "six-island", "name": "Île 6", "enc": ["water-path", "ruin-valley", "green-path"],
                        "special_shop": ["Boutique EV", ["macho-brace", "power-weight", "power-bracer", "power-belt", "power-lens", "power-band",
                                                         "power-anklet", "pomeg-berry", "kelpsy-berry", "qualot-berry", "hondew-berry", "grepa-berry",
                                                         "tamato-berry", "hp-up", "protein", "iron", "calcium", "zinc", "carbos"],
                                         ["Vendeuse : Bracelet Macho et objets Pouvoir pour gagner plus d'EV, Baies pour en retirer.",
                                          "Les six Salles des EV sont juste à côté : une salle par statistique !"]],
                        "npcs": [{"id": "coach_ev", "look": "ace", "kind": "script", "script": [special("ev_info")]}]},
            "ile_sept": {"kind": "town", "at": (3, 3), "loc": "seven-island", "name": "Île 7", "enc": ["canyon-entrance"]},
            "canyon": {"kind": "route", "at": (3, 2), "loc": "sevault-canyon", "enc": ["sevault-canyon", "tanoby-ruins"]},
        },
        "links": [("ile_un", "route_tison"), ("ile_un", "ile_deux"), ("ile_deux", "ile_trois"), ("ile_trois", "bois_baies"),
                  ("ile_deux", "ile_quatre"), ("ile_quatre", "ile_cinq"), ("ile_cinq", "ile_six"), ("ile_six", "ile_sept"), ("ile_sept", "canyon")],
        "dungeons": [
            {"key": "mont_braise", "name": "Mont Braise", "attach": "route_tison", "floors": 2, "theme": "volcano",
             "enc": ["mt-ember", "mt-ember/b1f", "mt-ember/b2f", "mt-ember/summit"],
             "content": [miniboss(W, "maganon_braise", 467, 52, "fire", ["Un Maganon entouré de flammes surgit du cratère !"], ["Maganon disparaît dans la lave."])]},
            {"key": "grotte_glace", "name": "Grotte de Glace", "attach": "ile_quatre", "floors": 2, "theme": "ice",
             "enc": ["icefall-cave/entrance", "icefall-cave/1f", "icefall-cave/b1f", "icefall-cave/waterfall"]},
            {"key": "entrepot", "name": "Entrepôt Rainbow Rocket", "attach": "ile_cinq", "floors": 2, "theme": "rocket", "door": "silph", "music": "rocket",
             "trainers": 0, "extra": {"grass": [(19, 30), (41, 30), (88, 20), (109, 20)]},
             "content": [ariane_npc(W, R, villain,
                                     ["Ariane : Tiens donc. Le célèbre Maître de Kanto.", "Giovanni a ouvert des portes vers d'autres mondes. Il en a ramené les chefs de toutes les équipes criminelles !"],
                                     ["Ariane : Max, Arthur, Hélio, Ghetis, Lysandre, Elsa-Mina, Shehroz... Ils sont tous dans la Team Rainbow Rocket.",
                                      "Chaque région a son repaire. Bonne chance pour tous les vaincre, gamin !"],
                                     "Le capitaine peut maintenant t'emmener à Johto. La Team Rainbow Rocket y a un repaire à Acajou !"),
                         {"id": "sbire_e1", "look": "rocket", "kind": "trainer", "trainer": grunts[0], "sight": 3},
                         {"id": "sbire_e2", "look": "rocket", "kind": "trainer", "trainer": grunts[1], "sight": 3},
                         {"id": "sbire_e3", "look": "rocket", "kind": "trainer", "trainer": grunts[2], "sight": 3}]},
            {"key": "grotte_perdue", "name": "Grotte Perdue", "attach": "ile_cinq", "floors": 2, "theme": "tower", "door": "tower",
             "enc": ["lost-cave/room-1", "lost-cave/room-5", "lost-cave/room-10"]},
            {"key": "tanoby", "name": "Ruines Tanoby", "attach": "canyon", "floors": 1, "theme": "rock", "trainers": 0,
             "enc": ["tanoby-ruins"], "extra": {"grass": [(201, 100)]}},
            {"key": "ile_aurore", "name": "Île Aurore", "attach": "ile_sept", "floors": 1, "theme": "rock", "bonus": 25, "trainers": 0,
             "require": F("champion_johto"), "locked": "Un marin : L'Île Aurore ? Seuls les Maîtres de Johto osent y aller...",
             "content": [legend("deoxys", 386, 75, "Un éclat venu de l'espace... Deoxys, le Pokémon ADN, se dresse au sommet de l'Île Aurore !")]},
        ] + ev_rooms,
    }


# =============================================================================
# HOENN
# =============================================================================

def hoenn(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "hoenn"
    max_ = strong_trainer(W, "rr_hoenn_max", "Chef Magma", "Max", [(262, 58), (169, 59), (323, 61)],
                          "Max : L'humanité a besoin de plus de terres ! Giovanni m'a promis un monde où Groudon règne !",
                          "Max : ... Le magma s'est refroidi. Tu es plus brûlant que lui.", "magma", "villain", aura="fire")
    arthur = strong_trainer(W, "rr_hoenn_arthur", "Chef Aqua", "Arthur", [(262, 59), (169, 60), (319, 62)],
                            "Arthur : Les mers recouvriront tout ! La Team Rainbow Rocket me donnera Kyogre !",
                            "Arthur : Bwahaha... Bon, d'accord. Tu as gagné, mon gars.", "aqua", "villain", aura="water")
    champ = strong_trainer(W, "maitre_hoenn", "Maître", "Pierre Rochard", [(227, 64), (344, 64), (306, 65), (346, 65), (348, 66), (376, 68)],
                           "Pierre Rochard : Je suis Pierre Rochard, Maître de Hoenn. Montre-moi ce qui fait ta force !",
                           "Pierre Rochard : Magnifique. Tu as la dureté d'une vraie pierre précieuse.", "champion_m", "champion")
    W.quests["chap_hoenn"] = chapter(R, "Hoenn", "La Team Rainbow Rocket a recruté Max (Team Magma) au Mont Chimnée et Arthur (Team Aqua) à Nénucrique. Arrête-les !",
                                     "Max et Arthur sont vaincus ! Pierre Rochard t'attend au bout de la Route Victoire, à Éternara.")
    W.quests["q_hoenn_regis"] = {"title": "Le Sanctuaire", "stages": ["", "Un texte en braille du Sanctuaire de Pacifiville parle de trois géants scellés...",
                                                                   "Les trois géants (Ruines Désert, Grotte de l'Îlot, Tombeau Antique) sont réveillés."]}
    W.quests["q_hoenn_orbes"] = {"title": "Les Gemmes du Mont Mémoria", "stages": ["", "Un vieux couple garde deux Gemmes au sommet du Mont Mémoria.",
                                                                              "Tu as la Gemme Rouge et la Gemme Bleue : Groudon et Kyogre t'attendent."]}
    arthur_npc = villain_npc(W, R, "arthur", "aqua", arthur,
                             ["Arthur : Max est tombé ? Peu importe ! La mer, elle, ne perd jamais !"],
                             ["Arthur : Bon... Max et moi, on rentre dans notre monde. Enfin, si Giovanni nous laisse faire."],
                             "Max et Arthur sont vaincus ! Pierre Rochard, Maître de Hoenn, t'attend à Éternara.")
    arthur_npc["script"] = [iff(F("rr_hoenn_max_done"), arthur_npc["script"], [say("Arthur : Bwahaha ! Va d'abord voir Max au Mont Chimnée, gamin. Moi, je t'attends !")])]
    max_npc = {"id": "max", "look": "magma", "kind": "script", "hide_if": F("rr_hoenn_max_done"), "script": [
        say("Max : Le Maître de Kanto... Giovanni m'a parlé de toi.", "Groudon dormira sous mes ordres, et la terre s'étendra !"), battle(max_),
        say("Max : Hmpf. Arthur est à Nénucrique, dans la planque Aqua. Lui ne perdra pas si facilement."), setf("rr_hoenn_max_done"), hide("max")]}
    eon = [[380, 70, 900, "leg_380", {"flag": "champion_hoenn"}], [381, 70, 900, "leg_381", {"flag": "champion_hoenn"}]]
    return {
        "realm": R, "name": "Hoenn", "prefix": "ho", "gen": 3, "max_species": 386, "versions": ["25", "26", "9"], "band": (46, 62),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur", "Nageuse", "Karatéka", "Médium", "Ornithologue"],
        "lore": ["Hoenn est une région chaude, entourée d'une mer immense.", "Le Mont Chimnée crache de la fumée depuis que des gens en rouge y sont montés...",
                 "Des marins en bleu et blanc rôdent autour de Nénucrique.", "On dit que deux Pokémon éon volent au-dessus des mers du sud."],
        "mart_extra": ["dive-ball", "nest-ball", "repeat-ball", "timer-ball", "luxury-ball", "premier-ball"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-l", "fire-stone", "water-stone",
                 "thunder-stone", "leaf-stone", "moon-stone", "sun-stone", "deep-sea-tooth", "deep-sea-scale", "prism-scale", "dragon-scale",
                 "root-fossil", "claw-fossil", "tmsv024", "tmsv046", "tmsv099"],
        "progress": ["poivressel", "r110", "lavandia", "r117", "vergazon", "r111", "r112", "vermilava", "r113", "autequia", "r114", "r115",
                     "merouville", "r104", "bois_clementi", "clementi", "r102", "rosyeres", "r101", "bourg_en_vol", "chenal105", "myokara",
                     "r118", "r119", "cimetronelle", "r120", "r121", "nenucrique", "chenal124", "algatia", "chenal126", "atalanopolis",
                     "chenal128", "pacifiville", "eternara"],
        "zones": {
            "poivressel": {"kind": "port", "at": (4, 4), "loc": "slateport-city", "enc": ["slateport-city"], "port": True,
                           "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                           "assault-vest", "eviolite", "heavy-duty-boots", "shell-bell", "mystic-water", "charcoal", "miracle-seed",
                                           "magnet", "soft-sand", "sharp-beak", "hard-stone", "never-melt-ice", "dragon-fang", "spell-tag"]},
            "r110": {"kind": "route", "at": (4, 3), "loc": "hoenn-route-110", "enc": ["hoenn-route-110"], "rare": eon},
            "lavandia": {"kind": "town", "at": (4, 2), "loc": "mauville-city"},
            "r117": {"kind": "route", "at": (3, 2), "loc": "hoenn-route-117", "enc": ["hoenn-route-117"], "extra": {"marsh": [(283, 12)]}},
            "vergazon": {"kind": "town", "at": (2, 2), "loc": "verdanturf-town"},
            "r111": {"kind": "desert", "at": (4, 1), "loc": "hoenn-route-111", "enc": ["hoenn-route-111"]},
            "r112": {"kind": "route", "at": (3, 1), "loc": "hoenn-route-112", "enc": ["hoenn-route-112", "jagged-pass"]},
            "vermilava": {"kind": "town", "at": (2, 1), "loc": "lavaridge-town", "enc": ["lavaridge-town"]},
            "r113": {"kind": "route", "at": (4, 0), "loc": "hoenn-route-113", "enc": ["hoenn-route-113"]},
            "autequia": {"kind": "town", "at": (3, 0), "loc": "fallarbor-town"},
            "r114": {"kind": "route", "at": (2, 0), "loc": "hoenn-route-114", "enc": ["hoenn-route-114"], "extra": {"grass": [(335, 8), (336, 8)]},
                     "rare": [[385, 70, 1500, "leg_385", {"flag": "champion_hoenn"}]]},
            "r115": {"kind": "route", "at": (1, 0), "loc": "hoenn-route-115", "name": "Routes 115 et 116", "enc": ["hoenn-route-115", "hoenn-route-116"]},
            "merouville": {"kind": "town", "at": (1, 1), "loc": "rustboro-city", "enc": ["rustboro-city"], "fossil": True},
            "r104": {"kind": "route", "at": (1, 2), "loc": "hoenn-route-104", "enc": ["hoenn-route-104", "hoenn-route-104/north-oras", "hoenn-route-104/south-oras"]},
            "bois_clementi": {"kind": "forest", "at": (1, 3), "loc": "petalburg-woods", "enc": ["petalburg-woods"]},
            "clementi": {"kind": "town", "at": (2, 3), "loc": "petalburg-city", "enc": ["petalburg-city"]},
            "r102": {"kind": "route", "at": (3, 3), "loc": "hoenn-route-102", "enc": ["hoenn-route-102"]},
            "rosyeres": {"kind": "town", "at": (3, 4), "loc": "oldale-town"},
            "r101": {"kind": "route", "at": (3, 5), "loc": "hoenn-route-101", "name": "Routes 101 et 103", "enc": ["hoenn-route-101", "hoenn-route-103"]},
            "bourg_en_vol": {"kind": "town", "at": (3, 6), "loc": "littleroot-town",
                             "lab": {"prof": "Prof. Seko", "starters": [252, 255, 258],
                                     "intro": ["Prof. Seko : Oh ! Un Maître de Kanto à Hoenn ? Fantastique !", "Choisis l'un de mes Pokémon. Ils t'aideront contre la Team Rainbow Rocket !"]}},
            "chenal105": {"kind": "sea", "at": (2, 4), "loc": "hoenn-route-105", "name": "Chenaux 105 à 109",
                          "enc": ["hoenn-route-105", "hoenn-route-106", "hoenn-route-107", "hoenn-route-108", "hoenn-route-109"]},
            "myokara": {"kind": "town", "at": (2, 5), "loc": "dewford-town", "enc": ["dewford-town"]},
            "r118": {"kind": "route", "at": (5, 2), "loc": "hoenn-route-118", "enc": ["hoenn-route-118"], "rare": eon},
            "r119": {"kind": "forest", "at": (5, 1), "loc": "hoenn-route-119", "enc": ["hoenn-route-119"], "rare": eon,
                     "npcs": [{"id": "institut_meteo", "look": "scientist", "kind": "script", "script": [
                         iff(F("got_castform"), [say("Chercheur : Morphéo change de forme selon le temps. Fascinant, non ?")],
                             [say("Chercheur de l'Institut Météo : La Team Rainbow Rocket voulait voler nos recherches ! Tiens, prends ce Pokémon en remerciement."),
                              ["mon", 351, 50], W.setf("got_castform")])]}]},
            "cimetronelle": {"kind": "town", "at": (5, 0), "loc": "fortree-city", "enc": ["fortree-city"]},
            "r120": {"kind": "route", "at": (6, 0), "loc": "hoenn-route-120", "enc": ["hoenn-route-120"], "rare": eon},
            "r121": {"kind": "route", "at": (7, 0), "loc": "hoenn-route-121", "name": "Routes 121 et 122", "enc": ["hoenn-route-121", "hoenn-route-122", "hoenn-route-123"]},
            "nenucrique": {"kind": "town", "at": (8, 0), "loc": "lilycove-city", "enc": ["lilycove-city"],
                           "special_shop": ["Grand Magasin de Nénucrique", ["tmsv009", "tmsv023", "tmsv035", "tmsv052", "tmsv065", "tmsv082", "tmsv089",
                                                                          "hp-up", "protein", "iron", "calcium", "zinc", "carbos", "pp-up", "exp-candy-m",
                                                                          "fire-stone", "water-stone", "thunder-stone", "leaf-stone", "moon-stone", "sun-stone"],
                                            ["Vendeuse : Le plus grand magasin de Hoenn ! Des CT à tous les étages."]]},
            "chenal124": {"kind": "sea", "at": (9, 0), "loc": "hoenn-route-124", "name": "Chenaux 124 et 125", "enc": ["hoenn-route-124", "hoenn-route-125"],
                          "extra": {"marsh": [(366, 10), (369, 4), (222, 8)]}},
            "algatia": {"kind": "town", "at": (10, 0), "loc": "mossdeep-city", "enc": ["mossdeep-city"],
                        "npcs": [{"id": "maison_rochard", "look": "champion_m", "kind": "script", "script": [
                            iff(F("champion_hoenn"), [iff(F("got_beldum"), [say("Pierre Rochard : Terhal deviendra un Métalosse redoutable.")],
                                                          [say("Pierre Rochard : Tu m'as battu à la loyale. Prends ce Terhal, il te sera fidèle."), ["mon", 374, 45], W.setf("got_beldum")])],
                                [say("Un mot sur la porte : « Parti à Éternara. Pierre Rochard »")])]}]},
            "chenal126": {"kind": "sea", "at": (10, 1), "loc": "hoenn-route-126", "name": "Chenaux 126 et 127", "enc": ["hoenn-route-126", "hoenn-route-127"]},
            "atalanopolis": {"kind": "town", "at": (9, 1), "loc": "sootopolis-city", "enc": ["sootopolis-city"]},
            "chenal128": {"kind": "sea", "at": (10, 2), "loc": "hoenn-route-128", "name": "Chenaux 128 à 134",
                          "enc": ["hoenn-route-128", "hoenn-route-129", "hoenn-route-130", "hoenn-route-131", "hoenn-route-132", "hoenn-route-133", "hoenn-route-134"]},
            "pacifiville": {"kind": "town", "at": (9, 2), "loc": "pacifidlog-town", "enc": ["pacifidlog-town"],
                            "npcs": [{"id": "braille", "look": "oldman", "kind": "script", "script": [
                                iff(F("regis_awake"), [say("Vieil homme : Les trois géants sont réveillés. Ils attendent dans leurs ruines...")],
                                    [say("Vieil homme : J'ai déchiffré le braille du Sanctuaire :", "« Trois géants dorment dans le sable, la glace et l'acier. Que le Maître les réveille. »"),
                                     iff(F("champion_hoenn"), [say("Les géants se sont réveillés ! Cherche-les aux Ruines Désert, à la Grotte de l'Îlot et au Tombeau Antique."),
                                                               setf("regis_awake"), quest("q_hoenn_regis", 2)],
                                         [say("Mais seul un Maître de Hoenn pourra les réveiller..."), quest("q_hoenn_regis", 1)])])]}]},
            "eternara": {"kind": "town", "at": (10, 3), "loc": "ever-grande-city", "enc": ["ever-grande-city"]},
        },
        "links": [("poivressel", "r110"), ("r110", "lavandia"), ("lavandia", "r117"), ("r117", "vergazon"), ("lavandia", "r111"), ("r111", "r112"),
                  ("r112", "vermilava"), ("r111", "r113"), ("r113", "autequia"), ("autequia", "r114"), ("r114", "r115"), ("r115", "merouville"),
                  ("merouville", "r104"), ("r104", "bois_clementi"), ("bois_clementi", "clementi"), ("clementi", "r102"), ("r102", "rosyeres"),
                  ("rosyeres", "r101"), ("r101", "bourg_en_vol"), ("clementi", "chenal105"), ("chenal105", "myokara"), ("lavandia", "r118"),
                  ("r118", "r119"), ("r119", "cimetronelle"), ("cimetronelle", "r120"), ("r120", "r121"), ("r121", "nenucrique"),
                  ("nenucrique", "chenal124"), ("chenal124", "algatia"), ("algatia", "chenal126"), ("chenal126", "atalanopolis"),
                  ("chenal126", "chenal128"), ("chenal128", "eternara"), ("chenal128", "pacifiville")],
        "dungeons": [
            {"key": "granite", "name": "Grotte Granite", "attach": "myokara", "floors": 2, "enc": ["granite-cave/1f", "granite-cave/b1f", "granite-cave/b2f"]},
            {"key": "merazon", "name": "Tunnel Mérazon", "attach": "vergazon", "floors": 1, "enc": ["rusturf-tunnel"]},
            {"key": "new_lavandia", "name": "New Lavandia", "attach": "r110", "floors": 2, "theme": "building", "door": "silph",
             "enc": ["new-mauville", "new-mauville/entrance"],
             "content": [miniboss(W, "elecsprint_new", 310, 64, "electric", ["Un Élecsprint surchargé d'électricité bloque les générateurs !"], ["Élecsprint se calme et s'en va."])]},
            {"key": "meteore", "name": "Site Météore", "attach": "r114", "floors": 2, "bonus": 6,
             "enc": ["meteor-falls", "meteor-falls/b1f", "meteor-falls/back", "meteor-falls/backsmall-room"], "extra": {"grass": [(337, 12), (338, 12)]},
             "content": [miniboss(W, "drattak_meteore", 373, 68, "dragon", ["Un Drattak furieux fond sur toi du haut de la cascade !"], ["Drattak s'envole au loin."])]},
            {"key": "ardent", "name": "Chemin Ardent", "attach": "r112", "floors": 1, "theme": "volcano", "enc": ["fiery-path"]},
            {"key": "chimnee", "name": "Mont Chimnée", "attach": "vermilava", "floors": 2, "theme": "volcano", "trainers": 1,
             "enc": ["jagged-pass", "fiery-path"], "trainer_class": "Sbire Rainbow", "content": [max_npc]},
            {"key": "planque_aqua", "name": "Planque Aqua", "attach": "nenucrique", "floors": 2, "theme": "rocket", "door": "silph", "music": "rocket",
             "trainers": 2, "trainer_class": "Sbire Rainbow", "extra": {"grass": [(41, 30), (72, 30), (318, 20)]}, "content": [arthur_npc]},
            {"key": "memoria", "name": "Mont Mémoria", "attach": "r121", "floors": 3, "theme": "tower", "door": "tower",
             "enc": ["mt-pyre/1f", "mt-pyre/2f", "mt-pyre/3f", "mt-pyre/4f", "mt-pyre/summit"],
             "content": [{"id": "vieux_couple", "look": "oldman", "kind": "script", "script": [
                 iff(F("champion_hoenn"), [iff(F("got_orbs"), [say("Vieillard : Les Gemmes réveilleront Groudon et Kyogre. Sois prudent.")],
                                               [say("Vieillard : Tu es le Maître de Hoenn. Ces Gemmes sont à toi."), give("red-orb"), give("blue-orb"),
                                                setf("got_orbs"), quest("q_hoenn_orbes", 2)])],
                     [say("Vieillard : Nous gardons deux Gemmes. Seul le Maître de Hoenn pourra les recevoir."), quest("q_hoenn_orbes", 1)])]},
                         miniboss(W, "branette_memoria", 354, 66, "ghost", ["Une Branette géante flotte au-dessus des tombes..."], ["Branette se dissipe dans la brume."])]},
            {"key": "trefonds", "name": "Grotte Tréfonds", "attach": "algatia", "floors": 2, "theme": "ice", "extra": {"grass": [(361, 15), (363, 10)]},
             "enc": ["shoal-cave/low-tide", "shoal-cave/high-tide", "shoal-cave/b1f", "shoal-cave/b2f"]},
            {"key": "origine", "name": "Grotte Origine", "attach": "atalanopolis", "floors": 3, "bonus": 12,
             "enc": ["cave-of-origin/entrance", "cave-of-origin/1f", "cave-of-origin/b1f"],
             "content": [legend("groudon", 383, 75, "La chaleur devient insupportable... Groudon, le Pokémon continent, se réveille !", {"item": "red-orb"})]},
            {"key": "fondmer", "name": "Caverne Fondmer", "attach": "chenal128", "floors": 3, "bonus": 12, "enc": ["seafloor-cavern"],
             "content": [legend("kyogre", 382, 75, "Une pluie diluvienne s'abat dans la caverne... Kyogre, le Pokémon océan, ouvre les yeux !", {"item": "blue-orb"})]},
            {"key": "pilier", "name": "Pilier Céleste", "attach": "chenal126", "floors": 3, "theme": "tower", "door": "tower", "bonus": 16,
             "enc": ["sky-pillar/1f", "sky-pillar/3f", "sky-pillar/5f"], "require": F("champion_hoenn"),
             "locked": "Une force mystérieuse bloque l'entrée du Pilier Céleste...",
             "content": [legend("rayquaza", 384, 80, "Au sommet du Pilier Céleste, Rayquaza, le Pokémon du ciel, te toise...",
                                {"all_flags": ["leg_382", "leg_383"]})]},
            {"key": "ruines_desert", "name": "Ruines Désert", "attach": "r111", "floors": 1, "theme": "rock", "bonus": 14, "trainers": 0,
             "enc": ["desert-ruins/area"], "content": [legend("regirock", 377, 70, "Un géant de pierre se met en mouvement... Regirock !", {"flag": "regis_awake"})]},
            {"key": "grotte_ilot", "name": "Grotte de l'Îlot", "attach": "chenal105", "floors": 1, "theme": "ice", "bonus": 14, "trainers": 0,
             "enc": ["island-cave/area"], "content": [legend("regice", 378, 70, "Un géant de glace se met en mouvement... Regice !", {"flag": "regis_awake"})]},
            {"key": "tombeau", "name": "Tombeau Antique", "attach": "r120", "floors": 1, "theme": "building", "door": "tower", "bonus": 14, "trainers": 0,
             "enc": ["ancient-tomb/area"], "content": [legend("registeel", 379, 70, "Un géant d'acier se met en mouvement... Registeel !", {"flag": "regis_awake"})]},
            {"key": "victoire", "name": "Route Victoire de Hoenn", "attach": "eternara", "floors": 2, "bonus": 6,
             "enc": ["hoenn-victory-road/1f", "hoenn-victory-road/b1f", "hoenn-victory-road/b2f"],
             "content": [champion_npc(W, R, "pierre_rochard", "champion_m", champ, "Pierre Rochard",
                                      ["Pierre Rochard : Tu as chassé Max et Arthur de Hoenn. Merci, {player}.", "Maintenant, en tant que Maître de Hoenn, je dois tester ta force !"],
                                      ["Pierre Rochard : Quelle bataille ! Le titre te revient.", "La Team Rainbow Rocket a aussi recruté Hélio, le chef de la Team Galaxie, à Sinnoh..."],
                                      "Pierre Rochard : Max et Arthur menacent encore Hoenn. Arrête-les d'abord !")]},
        ],
    }


# =============================================================================
# SINNOH
# =============================================================================

def sinnoh(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "sinnoh"
    saturne = strong_trainer(W, "rr_sinnoh_saturne", "Admin Galaxie", "Saturne", [(42, 62), (436, 62), (454, 63)],
                             "Saturne : Le QG Galaxie est à nous. Hélio prépare un nouveau monde au sommet du Mont Couronné !",
                             "Saturne : ... Va au Mont Couronné, si tu l'oses.", "galaxie", "villain")
    helio = strong_trainer(W, "rr_sinnoh_helio", "Chef Galaxie", "Hélio", [(430, 66), (169, 66), (130, 67), (461, 67), (229, 68)],
                           "Hélio : Ce monde est imparfait. Avec Dialga et Palkia, Giovanni et moi créerons un monde sans esprit !",
                           "Hélio : ... Je ne comprends pas. Comment un simple dresseur... peut-il me vaincre ?", "galaxie", "villain", aura="psychic")
    champ = strong_trainer(W, "maitre_sinnoh", "Maître", "Cynthia", [(442, 68), (407, 68), (468, 69), (448, 69), (350, 70), (445, 72)],
                           "Cynthia : Je suis Cynthia, Maître de Sinnoh. Mes Pokémon et moi te ferons face de toutes nos forces !",
                           "Cynthia : Je n'avais pas perdu depuis bien longtemps... Merci pour ce combat.", "champion_f", "champion")
    W.quests["chap_sinnoh"] = chapter(R, "Sinnoh", "La Team Galaxie s'est alliée à la Team Rainbow Rocket. Infiltre le QG Galaxie de Voilaroc, puis arrête Hélio au Mont Couronné.",
                                      "Hélio est vaincu ! Cynthia, Maître de Sinnoh, t'attend à la Ligue (Chenal 223, à l'est de Rivamar).")
    W.quests["q_sinnoh_lacs"] = {"title": "Les gardiens des lacs", "stages": ["", "Trois Pokémon des lacs veillent sur Sinnoh : Créhelf (Lac Savoir), Créfadet (Lac Courage)... et Créfollet, qui erre partout.",
                                                                           "Terminé."]}
    helio_npc = villain_npc(W, R, "helio", "galaxie", helio,
                            ["Hélio : Tu as passé le QG... Peu importe. Au sommet des Colonnes Lances, le temps et l'espace vont m'obéir !"],
                            ["Hélio : Dialga et Palkia... sont libres. Prends-les si tu peux. Moi, je disparais."],
                            "Hélio est vaincu ! Dialga et Palkia apparaissent au sommet... et Cynthia t'attend à la Ligue.")
    helio_npc["script"] = [iff(F("tr_rr_sinnoh_saturne"), helio_npc["script"], [say("Hélio : Viens d'abord à Voilaroc, au QG Galaxie. Saturne t'y attend.")])]
    mesprit = [[481, 70, 900, "leg_481", {"flag": "champion_sinnoh"}]]
    return {
        "realm": R, "name": "Sinnoh", "prefix": "si", "gen": 4, "max_species": 493, "versions": ["14", "12", "13"], "band": (50, 66),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur", "Nageuse", "Karatéka", "Médium", "Canon", "Gentleman"],
        "lore": ["Sinnoh est coupée en deux par le Mont Couronné, la plus haute montagne de la région.", "Trois lacs abritent des Pokémon qui donnent le savoir, l'émotion et la volonté.",
                 "La Team Galaxie s'est installée à Voilaroc. Leur chef parle de créer un nouveau monde...", "À Frimapic, un temple renferme un colosse endormi."],
        "mart_extra": ["dusk-ball", "quick-ball", "timer-ball", "repeat-ball", "heal-ball", "net-ball", "nest-ball", "luxury-ball"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-l", "dusk-stone", "shiny-stone", "dawn-stone",
                 "oval-stone", "razor-claw", "razor-fang", "protector", "electirizer", "magmarizer", "reaper-cloth", "dubious-disc", "tmsv088", "tmsv105"],
        "progress": ["joliberges", "r218", "feli_cite", "r202", "littorella", "r201", "bonaugure", "lac_verite", "r203", "charbourg", "r204", "floraville",
                     "r205", "foret_vestigion", "vestigion", "r206", "unionpolis", "r209", "bonville", "r210", "celestia", "r211", "r215", "voilaroc",
                     "r214", "rivamar", "r222", "rive_courage", "r213", "verchamps", "r212", "r216", "frimapic", "lac_savoir", "chenal223", "ligue"],
        "zones": {
            "joliberges": {"kind": "port", "at": (0, 2), "loc": "canalave-city", "enc": ["canalave-city"], "port": True,
                           "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                           "assault-vest", "eviolite", "heavy-duty-boots", "black-sludge", "light-clay", "toxic-orb", "flame-orb",
                                           "flame-plate", "splash-plate", "zap-plate", "meadow-plate", "icicle-plate", "fist-plate", "toxic-plate",
                                           "earth-plate", "sky-plate", "mind-plate", "insect-plate", "stone-plate", "spooky-plate", "draco-plate",
                                           "dread-plate", "iron-plate", "pixie-plate", "griseous-orb", "adamant-orb", "lustrous-orb"]},
            "r218": {"kind": "lake", "at": (1, 2), "loc": "sinnoh-route-218", "enc": ["sinnoh-route-218"]},
            "feli_cite": {"kind": "town", "at": (2, 2), "loc": "jubilife-city"},
            "r202": {"kind": "route", "at": (2, 3), "loc": "sinnoh-route-202", "enc": ["sinnoh-route-202"]},
            "littorella": {"kind": "town", "at": (2, 4), "loc": "sandgem-town"},
            "r201": {"kind": "route", "at": (1, 4), "loc": "sinnoh-route-201", "enc": ["sinnoh-route-201"]},
            "bonaugure": {"kind": "town", "at": (0, 4), "loc": "twinleaf-town", "enc": ["twinleaf-town"],
                          "lab": {"prof": "Prof. Sorbier", "starters": [387, 390, 393],
                                  "intro": ["Prof. Sorbier : Hm. Le Maître de Kanto. Chen m'a prévenu.", "Choisis un de ces Pokémon. Prends-en soin."]}},
            "lac_verite": {"kind": "lake", "at": (0, 3), "loc": "lake-verity", "name": "Lac Vérité",
                           "enc": ["lake-verity/before-galactic-intervention", "lake-verity/after-galactic-intervention"], "rare": mesprit},
            "r203": {"kind": "route", "at": (3, 2), "loc": "sinnoh-route-203", "enc": ["sinnoh-route-203"]},
            "charbourg": {"kind": "town", "at": (4, 2), "loc": "oreburgh-city", "fossil": True},
            "r204": {"kind": "route", "at": (2, 1), "loc": "sinnoh-route-204", "enc": ["sinnoh-route-204/south-towards-jubilife-city", "sinnoh-route-204/north-towards-floaroma-town"]},
            "floraville": {"kind": "town", "at": (2, 0), "loc": "floaroma-town", "enc": ["floaroma-meadow"]},
            "r205": {"kind": "route", "at": (3, 0), "loc": "sinnoh-route-205", "enc": ["sinnoh-route-205/south-towards-floaroma-town", "sinnoh-route-205/east-towards-eterna-city", "valley-windworks"]},
            "foret_vestigion": {"kind": "forest", "at": (4, 0), "loc": "eterna-forest", "enc": ["eterna-forest"]},
            "vestigion": {"kind": "town", "at": (5, 0), "loc": "eterna-city", "enc": ["eterna-city"]},
            "r206": {"kind": "route", "at": (5, 1), "loc": "sinnoh-route-206", "name": "Routes 206 à 208", "enc": ["sinnoh-route-206", "sinnoh-route-207", "sinnoh-route-208"]},
            "unionpolis": {"kind": "town", "at": (5, 2), "loc": "hearthome-city"},
            "r209": {"kind": "route", "at": (6, 2), "loc": "sinnoh-route-209", "enc": ["sinnoh-route-209"], "rare": mesprit},
            "bonville": {"kind": "town", "at": (7, 2), "loc": "solaceon-town"},
            "r210": {"kind": "route", "at": (7, 1), "loc": "sinnoh-route-210", "enc": ["sinnoh-route-210/south-towards-solaceon-town", "sinnoh-route-210/west-towards-celestic-town"], "rare": mesprit},
            "celestia": {"kind": "town", "at": (7, 0), "loc": "celestic-town", "enc": ["celestic-town"],
                         "npcs": [{"id": "ancienne_celestia", "look": "oldman", "kind": "script", "script": [
                             iff(F("champion_sinnoh"), [say("Ancienne : La faille du temple s'est ouverte... Elle mène à Hisui, l'ancien Sinnoh. Veux-tu y aller ?"),
                                                        W.choice("Traverser la faille temporelle ?", ["OUI", "NON"], [[special("goto", "hi_campement")], []])],
                                 [say("Ancienne : Ce temple garde un secret du temps jadis. Un jour, quand tu seras Maître de Sinnoh, il s'ouvrira peut-être...")])]}]},
            "r211": {"kind": "route", "at": (6, 0), "loc": "sinnoh-route-211", "enc": ["sinnoh-route-211/west-towards-eterna-city", "sinnoh-route-211/east-towards-celestic-town"]},
            "r215": {"kind": "route", "at": (8, 2), "loc": "sinnoh-route-215", "enc": ["sinnoh-route-215"], "rare": mesprit},
            "voilaroc": {"kind": "town", "at": (9, 2), "loc": "veilstone-city"},
            "r214": {"kind": "route", "at": (9, 3), "loc": "sinnoh-route-214", "enc": ["sinnoh-route-214"], "rare": mesprit},
            "rivamar": {"kind": "town", "at": (9, 4), "loc": "sunyshore-city", "enc": ["sunyshore-city"]},
            "r222": {"kind": "route", "at": (8, 4), "loc": "sinnoh-route-222", "enc": ["sinnoh-route-222"], "rare": mesprit},
            "rive_courage": {"kind": "lake", "at": (7, 4), "loc": "valor-lakefront", "name": "Rive Lac Courage", "enc": ["valor-lakefront", "lake-valor"]},
            "r213": {"kind": "route", "at": (6, 4), "loc": "sinnoh-route-213", "enc": ["sinnoh-route-213"], "rare": mesprit},
            "verchamps": {"kind": "town", "at": (5, 4), "loc": "pastoria-city", "enc": ["pastoria-city"]},
            "r212": {"kind": "route", "at": (5, 3), "loc": "sinnoh-route-212", "enc": ["sinnoh-route-212/north-towards-hearthome-city", "sinnoh-route-212/east-towards-pastoria-city"]},
            "r216": {"kind": "snow", "at": (7, -1), "loc": "sinnoh-route-216", "name": "Routes 216 et 217", "enc": ["sinnoh-route-216", "sinnoh-route-217"]},
            "frimapic": {"kind": "town", "at": (7, -2), "loc": "snowpoint-city", "music": "town"},
            "lac_savoir": {"kind": "lake", "at": (8, -2), "loc": "acuity-lakefront", "name": "Rive Lac Savoir", "enc": ["acuity-lakefront", "lake-acuity"]},
            "chenal223": {"kind": "sea", "at": (10, 4), "loc": "sinnoh-sea-route-223", "enc": ["sinnoh-sea-route-223"],
                          "rare": [[489, 60, 500, "leg_489", {"flag": "champion_sinnoh"}]]},
            "ligue": {"kind": "town", "at": (11, 4), "loc": "sinnoh-pokemon-league", "name": "Ligue Pokémon de Sinnoh", "enc": ["sinnoh-pokemon-league"], "extra_houses": 0},
        },
        "links": [("joliberges", "r218"), ("r218", "feli_cite"), ("feli_cite", "r202"), ("r202", "littorella"), ("littorella", "r201"), ("r201", "bonaugure"),
                  ("bonaugure", "lac_verite"), ("feli_cite", "r203"), ("r203", "charbourg"), ("feli_cite", "r204"), ("r204", "floraville"),
                  ("floraville", "r205"), ("r205", "foret_vestigion"), ("foret_vestigion", "vestigion"), ("vestigion", "r206"), ("r206", "unionpolis"),
                  ("unionpolis", "r209"), ("r209", "bonville"), ("bonville", "r210"), ("r210", "celestia"), ("vestigion", "r211"), ("r211", "celestia"),
                  ("bonville", "r215"), ("r215", "voilaroc"), ("voilaroc", "r214"), ("r214", "rivamar"), ("rivamar", "r222"), ("r222", "rive_courage"),
                  ("rive_courage", "r213"), ("r213", "verchamps"), ("verchamps", "r212"), ("r212", "unionpolis"), ("celestia", "r216"),
                  ("r216", "frimapic"), ("frimapic", "lac_savoir"), ("rivamar", "chenal223"), ("chenal223", "ligue")],
        "dungeons": [
            {"key": "mine", "name": "Mine Charbourg", "attach": "charbourg", "floors": 2, "enc": ["oreburgh-mine/1f", "oreburgh-mine/b1f"],
             "items": ["skull-fossil", "armor-fossil"]},
            {"key": "reveche", "name": "Grotte Revèche", "attach": "r206", "floors": 2, "bonus": 6, "enc": ["wayward-cave/1f", "wayward-cave/b1f"],
             "content": [miniboss(W, "carchacrok_reveche", 445, 72, "dragon", ["Un Carchacrok surgit du sable à une vitesse folle !"], ["Carchacrok s'enfonce dans le sol."])]},
            {"key": "chateau", "name": "Vieux Château", "attach": "foret_vestigion", "floors": 2, "theme": "mansion", "door": "mansion",
             "enc": ["old-chateau/entrance", "old-chateau/dining-room", "old-chateau/2f"],
             "content": [legend("motisma", 479, 55, "La vieille télévision s'allume toute seule... C'est un Motisma !")]},
            {"key": "qg", "name": "QG Galaxie", "attach": "voilaroc", "floors": 2, "theme": "rocket", "door": "silph", "music": "rocket",
             "trainers": 2, "trainer_class": "Sbire Rainbow", "extra": {"grass": [(41, 30), (100, 20), (436, 20)]},
             "content": [{"id": "saturne", "look": "galaxie", "kind": "trainer", "trainer": saturne, "sight": 3}]},
            {"key": "couronne", "name": "Mont Couronné", "attach": "r211", "floors": 3, "bonus": 8,
             "enc": ["mt-coronet/1f-route-211", "mt-coronet/2f", "mt-coronet/4f", "mt-coronet/6f", "spear-pillar/area"],
             "content": [helio_npc,
                         legend("dialga", 483, 75, "Le temps se fige... Dialga, le maître du temps, rugit au sommet des Colonnes Lances !", {"flag": "chap_sinnoh_villain"}),
                         legend("palkia", 484, 75, "L'espace se déforme... Palkia, le maître de l'espace, apparaît !", {"flag": "chap_sinnoh_villain"})]},
            {"key": "grand_marais", "name": "Grand Marais", "attach": "verchamps", "floors": 1, "theme": "forest",
             "enc": ["great-marsh/area-1", "great-marsh/area-2", "great-marsh/area-3", "great-marsh/area-4", "great-marsh/area-5", "great-marsh/area-6"]},
            {"key": "tour_perdue", "name": "Tour Perdue", "attach": "r209", "floors": 2, "theme": "tower", "door": "tower",
             "enc": ["lost-tower/1f", "lost-tower/3f", "lost-tower/5f"]},
            {"key": "ile_fer", "name": "Île de Fer", "attach": "joliberges", "floors": 2,
             "enc": ["iron-island/1f", "iron-island/b1f-left", "iron-island/b2f-left", "iron-island/b3f"],
             "content": [{"id": "riolu_oeuf", "look": "ace", "kind": "script", "script": [
                 iff(F("got_riolu"), [say("Dresseur : Ce Riolu deviendra un grand Lucario !")],
                     [say("Dresseur : Merci de m'avoir aidé à chasser les sbires. Prends cet Œuf, il contient un Riolu."), ["egg", 447], setf("got_riolu")])]}]},
            {"key": "ruines_bonville", "name": "Ruines Bonville", "attach": "bonville", "floors": 2, "theme": "rock", "trainers": 0,
             "enc": ["solaceon-ruins/1f", "solaceon-ruins/b1f-a", "solaceon-ruins/b3f-a"], "extra": {"grass": [(201, 100)]}},
            {"key": "savoir", "name": "Caverne Savoir", "attach": "lac_savoir", "floors": 1, "bonus": 12, "trainers": 0,
             "content": [legend("crehelf", 480, 70, "Un Pokémon aux yeux clos médite au fond de la caverne... Créhelf !", {"flag": "champion_sinnoh"})]},
            {"key": "courage", "name": "Caverne Courage", "attach": "rive_courage", "floors": 1, "bonus": 12, "trainers": 0,
             "content": [legend("crefadet", 482, 70, "Un Pokémon bondit devant toi, plein de volonté... Créfadet !", {"flag": "champion_sinnoh"})]},
            {"key": "temple", "name": "Temple Frimapic", "attach": "frimapic", "floors": 3, "theme": "ice", "bonus": 16,
             "enc": ["snowpoint-temple/1f", "snowpoint-temple/b1f", "snowpoint-temple/b3f", "snowpoint-temple/b5f"],
             "require": F("champion_sinnoh"), "locked": "Une prêtresse : Le temple est interdit, sauf au Maître de Sinnoh.",
             "content": [legend("regigigas", 486, 75, "Un colosse immense s'éveille au fond du temple... Regigigas !", {"all_flags": ["leg_377", "leg_378", "leg_379"]})]},
            {"key": "retour", "name": "Grotte Retour", "attach": "r210", "floors": 3, "bonus": 16,
             "enc": ["turnback-cave/pillar-1", "turnback-cave/pillar-2", "turnback-cave/pillar-3"],
             "require": F("champion_sinnoh"), "locked": "Un vent glacé souffle de la grotte... Seul le Maître de Sinnoh peut y entrer.",
             "content": [legend("giratina", 487, 75, "Le monde se renverse... Giratina surgit du Monde Distorsion !")]},
            {"key": "abrupt", "name": "Mont Abrupt", "attach": "ligue", "floors": 3, "theme": "volcano", "bonus": 14,
             "enc": ["stark-mountain/entrance", "stark-mountain", "stark-mountain/inside"], "require": F("champion_sinnoh"),
             "locked": "Le Mont Abrupt est réservé aux Maîtres.",
             "content": [legend("heatran", 485, 75, "Le magma bouillonne... Heatran, le Pokémon du dôme de lave, sort de la roche !")]},
            {"key": "pleine_lune", "name": "Île Pleine Lune", "attach": "joliberges", "floors": 1, "theme": "forest", "bonus": 14, "trainers": 0,
             "require": F("champion_sinnoh"), "locked": "Un marin : L'Île Pleine Lune ? Seul le Maître de Sinnoh peut y aller.",
             "content": [legend("cresselia", 488, 72, "Une lueur argentée danse au clair de lune... Cresselia ! Elle laisse tomber une plume."),
                         {"id": "lunaile", "look": "ball", "kind": "item", "item": "lunar-wing", "count": 1, "flag": "got_lunar_wing"}]},
            {"key": "nouvelle_lune", "name": "Île Nouvellelune", "attach": "joliberges", "floors": 1, "theme": "rocket", "bonus": 16, "trainers": 0,
             "require": {"item": "lunar-wing"}, "locked": "Des cauchemars bloquent l'accès à l'île... Il faudrait la Lun'Aile de Cresselia.",
             "content": [legend("darkrai", 491, 75, "Les ténèbres s'épaississent... Darkrai, le Pokémon des cauchemars !")]},
            {"key": "paradis", "name": "Paradis Fleuri", "attach": "floraville", "floors": 1, "theme": "grass", "bonus": 14, "trainers": 0,
             "require": F("champion_sinnoh"), "locked": "Un champ de fleurs inaccessible... Seul le Maître de Sinnoh y est admis.",
             "content": [legend("shaymin", 492, 70, "Un petit Pokémon fleuri te regarde... Shaymin !")]},
            {"key": "passage", "name": "Passage Marin", "attach": "r222", "floors": 1, "theme": "water", "bonus": 14, "trainers": 0,
             "require": F("champion_sinnoh"), "locked": "Les vagues sont trop fortes...",
             "content": [legend("manaphy", 490, 60, "Un chant marin résonne... Manaphy, le prince des mers !")]},
            {"key": "victoire", "name": "Route Victoire de Sinnoh", "attach": "ligue", "floors": 2, "bonus": 6,
             "enc": ["sinnoh-victory-road/1f", "sinnoh-victory-road/2f", "sinnoh-victory-road/b1f"],
             "content": [champion_npc(W, R, "cynthia", "champion_f", champ, "Cynthia",
                                      ["Cynthia : Tu as vaincu Hélio et libéré Dialga et Palkia. Impressionnant.", "Mais je suis Cynthia, Maître de Sinnoh. Je ne reculerai pas !"],
                                      ["Cynthia : Tu es un dresseur exceptionnel.", "La Team Rainbow Rocket a recruté Ghetis, de la Team Plasma, à Unys. Sois prudent..."],
                                      "Cynthia : Hélio menace encore Sinnoh depuis le Mont Couronné. Arrête-le d'abord !")]},
        ],
    }


# =============================================================================
# HISUI (le Sinnoh d'autrefois, par la faille du temple de Célestia)
# =============================================================================

def hisui(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "hisui"
    return {
        "realm": R, "name": "Hisui", "prefix": "hi", "gen": 8, "max_species": 905, "versions": [], "band": (64, 72),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Karatéka"],
        "lore": ["Hisui... C'est ainsi que l'on appelait Sinnoh il y a très longtemps.", "Ici, les Pokémon sont plus sauvages et plus forts qu'à notre époque.",
                 "Les Pokémon de Hisui évoluent parfois d'une façon jamais vue ailleurs !"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "black-augurite", "peat-block", "razor-claw", "sun-stone", "ice-stone"],
        "progress": ["campement", "plaine_obsidienne", "marais_carmin"],
        "zones": {
            "campement": {"kind": "town", "at": (0, 0), "name": "Campement de Hisui", "extra_houses": 1,
                          "lab": {"prof": "Chercheur du campement", "starters": [722, 155, 501], "level": 55,
                                  "intro": ["Chercheur : Un voyageur venu du futur ? Fascinant !", "Les Pokémon de Hisui ont besoin d'un dresseur comme toi. Choisis-en un !"]},
                          "npcs": [{"id": "retour_present", "look": "oldman", "kind": "script", "script": [
                              W.choice("Retourner à ton époque (Célestia) ?", ["OUI", "NON"], [[special("goto", "si_celestia")], []])]}]},
            "plaine_obsidienne": {"kind": "route", "at": (1, 0), "name": "Plaine Obsidienne", "items": ["black-augurite", "peat-block"],
                                  "extra": {"grass": [(399, 14), (396, 14), (403, 12), (234, 10), (123, 6), (216, 10), (217, 4), (77, 8), (133, 6), (41, 8),
                                                      (10231, 8), (10229, 8), (10247, 6), (406, 8), (415, 8), (412, 6)],
                                            "marsh": [(54, 20), (418, 20), (10247, 15), (129, 20)]}},
            "marais_carmin": {"kind": "lake", "at": (2, 0), "name": "Marais Carmin",
                              "extra": {"grass": [(453, 12), (449, 10), (431, 10), (548, 8), (627, 8), (704, 8), (10235, 8), (10238, 6), (712, 8),
                                                  (207, 8), (201, 4), (114, 8), (280, 8), (339, 10), (10234, 6)],
                                        "marsh": [(10234, 15), (339, 20), (211, 10), (194, 20), (10247, 15)]},
                              "rare": [[905, 72, 600, "leg_905", None]]},
        },
        "links": [("campement", "plaine_obsidienne"), ("plaine_obsidienne", "marais_carmin")],
        "dungeons": [
            {"key": "temple", "name": "Temple de Sinnoh", "attach": "marais_carmin", "floors": 2, "theme": "rock", "bonus": 8,
             "extra": {"grass": [(10235, 20), (10238, 20), (442, 10), (425, 15), (200, 15)]},
             "content": [miniboss(W, "noble_hisui", 10230, 76, "fire", ["Un Arcanin de Hisui, le Seigneur des lieux, entouré d'une aura brûlante, te barre la route !"],
                                  ["Le Seigneur de Hisui s'apaise et retourne dans les ruines."])]},
        ],
    }



# =============================================================================
# UNYS
# =============================================================================

def unys(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "unys"
    ghetis = strong_trainer(W, "rr_unys_ghetis", "Chef Plasma", "Ghetis", [(563, 70), (626, 70), (537, 71), (625, 71), (604, 72), (635, 74)],
                            "Ghetis : Je suis Ghetis, le véritable chef de la Team Plasma ! Avec la Team Rainbow Rocket, Unys m'appartiendra !",
                            "Ghetis : Impossible ! Moi, Ghetis, vaincu par un enfant ?!", "plasma", "villain", aura="dark")
    champ = strong_trainer(W, "maitre_unys", "Maître", "Iris", [(635, 72), (621, 72), (306, 73), (567, 73), (131, 74), (612, 76)],
                           "Iris : Je suis Iris, Maître d'Unys ! Mes dragons et moi, on va te montrer ce qu'est la vraie force !",
                           "Iris : Waouh... T'es vraiment super fort ! Bravo !", "champion_f", "champion")
    W.quests["chap_unys"] = chapter(R, "Unys", "La Team Plasma de Ghetis a rejoint la Team Rainbow Rocket. Leur Frégate Plasma mouille au port de Port Yoneuve !",
                                    "Ghetis est vaincu ! Iris, Maître d'Unys, t'attend au bout de la Route Victoire, au nord de Janusia.")
    W.quests["q_unys_epees"] = {"title": "Les Épées de la Justice", "stages": ["", "Trois Pokémon légendaires protègent les Pokémon d'Unys : Cobaltium, Terrakium et Viridium.",
                                                                            "Les trois Épées de la Justice t'ont jugé digne : Keldeo t'attend au Bois du Serment."]}
    forces = [[641, 74, 900, "leg_641", {"flag": "champion_unys"}], [642, 74, 900, "leg_642", {"flag": "champion_unys"}]]
    return {
        "realm": R, "name": "Unys", "prefix": "un", "gen": 5, "max_species": 649, "versions": ["21", "22", "17", "18"], "band": (54, 70),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur", "Nageuse", "Karatéka", "Médium", "Canon", "Gentleman", "Scientifique"],
        "lore": ["Unys est une région lointaine, aux villes immenses comme Volucité.", "La Team Plasma voulait « libérer » les Pokémon. Mais Ghetis voulait surtout le pouvoir...",
                 "Deux dragons, l'un de vérité et l'autre d'idéaux, dorment dans la Tour Dragospire.", "Des nuages d'orage traversent Unys : on dit que ce sont deux Pokémon qui se battent."],
        "mart_extra": ["dusk-ball", "quick-ball", "timer-ball", "repeat-ball", "heal-ball", "net-ball", "nest-ball", "dive-ball", "luxury-ball"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-l", "dusk-stone", "shiny-stone", "dawn-stone",
                 "fire-stone", "water-stone", "thunder-stone", "leaf-stone", "moon-stone", "sun-stone", "cover-fossil", "plume-fossil", "tmsv033", "tmsv092"],
        "progress": ["renouet", "r1", "arabelle", "r2", "ogoesse", "r3", "maillard", "foret", "volucite", "r4", "meanville", "r16", "r5",
                     "port_yoneuve", "r6", "parsemille", "r7", "flocombe", "r8", "janusia", "r11", "entrelasque", "r13", "vaguelone", "r14", "r10", "ligue"],
        "zones": {
            "port_yoneuve": {"kind": "port", "at": (0, 4), "loc": "driftveil-city", "enc": ["driftveil-city", "driftveil-drawbridge"], "port": True,
                             "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                             "assault-vest", "eviolite", "heavy-duty-boots", "air-balloon", "red-card", "eject-button", "ring-target",
                                             "binding-band", "absorb-bulb", "cell-battery", "fire-gem", "water-gem", "electric-gem", "normal-gem"]},
            "r6": {"kind": "route", "at": (0, 3), "loc": "unova-route-6", "enc": ["unova-route-6"], "rare": forces},
            "parsemille": {"kind": "town", "at": (0, 2), "loc": "mistralton-city"},
            "r7": {"kind": "route", "at": (0, 1), "loc": "unova-route-7", "enc": ["unova-route-7"], "rare": forces},
            "flocombe": {"kind": "town", "at": (0, 0), "loc": "icirrus-city", "enc": ["icirrus-city"]},
            "r8": {"kind": "lake", "at": (1, 0), "loc": "unova-route-8", "name": "Route 8 et Tourbière", "enc": ["unova-route-8", "moor-of-icirrus"], "rare": forces},
            "janusia": {"kind": "town", "at": (2, 0), "loc": "opelucid-city"},
            "r10": {"kind": "route", "at": (2, -1), "loc": "unova-route-10", "enc": ["unova-route-10", "unova-route-9"]},
            "ligue": {"kind": "town", "at": (2, -2), "loc": "unova-pokemon-league", "name": "Ligue Pokémon d'Unys", "extra_houses": 0},
            "r11": {"kind": "route", "at": (3, 0), "loc": "unova-route-11", "name": "Routes 11 et 12", "enc": ["unova-route-11", "village-bridge", "unova-route-12"], "rare": forces},
            "entrelasque": {"kind": "town", "at": (4, 0), "loc": "lacunosa-town"},
            "r13": {"kind": "route", "at": (5, 0), "loc": "unova-route-13", "enc": ["unova-route-13"], "rare": forces},
            "vaguelone": {"kind": "town", "at": (6, 0), "loc": "undella-town", "enc": ["undella-town", "undella-bay"]},
            "r14": {"kind": "route", "at": (6, 1), "loc": "unova-route-14", "name": "Routes 14 et 15", "enc": ["unova-route-14", "unova-route-15"], "rare": forces},
            "r5": {"kind": "route", "at": (1, 4), "loc": "unova-route-5", "enc": ["unova-route-5"], "rare": forces},
            "meanville": {"kind": "town", "at": (2, 4), "loc": "nimbasa-city"},
            "r16": {"kind": "forest", "at": (3, 4), "loc": "unova-route-16", "name": "Route 16 et Bois des Illusions", "enc": ["unova-route-16", "lostlorn-forest"]},
            "r4": {"kind": "desert", "at": (2, 5), "loc": "unova-route-4", "enc": ["unova-route-4", "desert-resort", "desert-resort/entrance"]},
            "volucite": {"kind": "town", "at": (2, 6), "loc": "castelia-city", "enc": ["castelia-city"],
                         "special_shop": ["Grand Magasin de Volucité", ["tmsv015", "tmsv032", "tmsv057", "tmsv073", "tmsv086", "tmsv100", "tmsv127",
                                                                        "hp-up", "protein", "iron", "calcium", "zinc", "carbos", "pp-up", "exp-candy-l",
                                                                        "dusk-stone", "shiny-stone", "dawn-stone", "oval-stone"],
                                          ["Vendeur : Volucité, la ville qui ne dort jamais ! Tout est en vente ici."]]},
            "foret": {"kind": "forest", "at": (1, 6), "loc": "pinwheel-forest", "enc": ["pinwheel-forest/outside", "pinwheel-forest/inside"],
                      "npcs": [legend("viridium", 640, 72, "Un Pokémon vert et gracieux surgit des arbres... Viridium, l'une des Épées de la Justice !", {"flag": "champion_unys"})]},
            "maillard": {"kind": "town", "at": (0, 6), "loc": "nacrene-city", "fossil": True},
            "r3": {"kind": "route", "at": (0, 7), "loc": "unova-route-3", "enc": ["unova-route-3"]},
            "ogoesse": {"kind": "town", "at": (0, 8), "loc": "striaton-city", "enc": ["striaton-city"]},
            "r2": {"kind": "route", "at": (1, 8), "loc": "unova-route-2", "enc": ["unova-route-2"]},
            "arabelle": {"kind": "town", "at": (2, 8), "loc": "accumula-town", "enc": ["accumula-town"]},
            "r1": {"kind": "route", "at": (3, 8), "loc": "unova-route-1", "enc": ["unova-route-1"]},
            "renouet": {"kind": "town", "at": (4, 8), "loc": "nuvema-town",
                        "lab": {"prof": "Prof. Keteleeria", "starters": [495, 498, 501],
                                "intro": ["Prof. Keteleeria : Bienvenue à Unys ! Chen m'a tout raconté.", "Prends l'un de ces Pokémon. Ensemble, vous arrêterez la Team Plasma !"]}},
        },
        "links": [("port_yoneuve", "r6"), ("r6", "parsemille"), ("parsemille", "r7"), ("r7", "flocombe"), ("flocombe", "r8"), ("r8", "janusia"),
                  ("janusia", "r10"), ("r10", "ligue"), ("janusia", "r11"), ("r11", "entrelasque"), ("entrelasque", "r13"), ("r13", "vaguelone"),
                  ("vaguelone", "r14"), ("port_yoneuve", "r5"), ("r5", "meanville"), ("meanville", "r16"), ("meanville", "r4"), ("r4", "volucite"),
                  ("volucite", "foret"), ("foret", "maillard"), ("maillard", "r3"), ("r3", "ogoesse"), ("ogoesse", "r2"), ("r2", "arabelle"),
                  ("arabelle", "r1"), ("r1", "renouet")],
        "dungeons": [
            {"key": "vestiges", "name": "Vestiges du Rêve", "attach": "ogoesse", "floors": 1, "theme": "rock", "enc": ["dreamyard", "dreamyard/b1f"]},
            {"key": "chateau_enfoui", "name": "Château Enfoui", "attach": "r4", "floors": 3, "theme": "ground", "bonus": 6,
             "enc": ["relic-castle/a", "relic-castle/b", "relic-castle/c", "relic-castle/d"],
             "content": [miniboss(W, "pyrax_enfoui", 637, 74, "fire", ["Un Pyrax, soleil vivant du château, déploie ses ailes de feu !"], ["Pyrax s'envole vers le plafond."])]},
            {"key": "electrolithe", "name": "Grotte Électrolithe", "attach": "r6", "floors": 2, "theme": "electric",
             "enc": ["chargestone-cave/1f", "chargestone-cave/b1f", "chargestone-cave/b2f"],
             "content": [legend("cobaltium", 638, 72, "Un Pokémon d'acier au regard noble... Cobaltium, l'une des Épées de la Justice !", {"flag": "champion_unys"})]},
            {"key": "fore", "name": "Mont Foré", "attach": "r7", "floors": 2, "theme": "ice", "enc": ["twist-mountain/b1f-3f", "twist-mountain/b4f"]},
            {"key": "cieux", "name": "Tour des Cieux", "attach": "r7", "floors": 2, "theme": "tower", "door": "tower",
             "enc": ["celestial-tower/2f", "celestial-tower/3f", "celestial-tower/4f", "celestial-tower/5f"],
             "content": [legend("meloetta", 648, 70, "Une mélodie ancienne résonne au sommet de la tour... Meloetta danse !", {"flag": "champion_unys"})]},
            {"key": "dragospire", "name": "Tour Dragospire", "attach": "flocombe", "floors": 3, "theme": "tower", "door": "tower", "bonus": 10,
             "enc": ["dragonspiral-tower/entrance", "dragonspiral-tower/1f", "dragonspiral-tower/2f", "dragonspiral-tower/7f"],
             "require": F("champion_unys"), "locked": "Un garde : La Tour Dragospire est sacrée. Seul le Maître d'Unys peut y monter.",
             "content": [legend("reshiram", 643, 78, "Des flammes blanches embrasent le sommet... Reshiram, le dragon de la vérité !"),
                         legend("zekrom", 644, 78, "Des éclairs noirs fendent le ciel... Zekrom, le dragon des idéaux !")]},
            {"key": "cyclopeenne", "name": "Grotte Cyclopéenne", "attach": "r13", "floors": 3, "theme": "ice", "bonus": 12,
             "enc": ["giant-chasm/outside", "giant-chasm", "giant-chasm/forest", "giant-chasm/forest-cave"],
             "require": F("champion_unys"), "locked": "Un froid mortel sort de la grotte...",
             "content": [legend("kyurem", 646, 78, "Un souffle glacé fige tout... Kyurem, le dragon de glace, sort de la brume !")]},
            {"key": "autel", "name": "Autel Abondance", "attach": "r14", "floors": 1, "theme": "grass", "bonus": 10, "enc": ["abundant-shrine"],
             "content": [legend("demeteros", 645, 76, "La terre se met à trembler... Démétéros, le Pokémon de la fertilité, descend des nuages !",
                                {"all_flags": ["leg_641", "leg_642"]})]},
            {"key": "liberte", "name": "Île Liberté", "attach": "volucite", "floors": 1, "theme": "building", "door": "tower", "bonus": 10, "trainers": 0,
             "require": F("champion_unys"), "locked": "Un marin : L'Île Liberté ? On y va seulement avec le Maître d'Unys...",
             "content": [legend("victini", 494, 70, "Au sous-sol du phare, un petit Pokémon t'observe... Victini, le Pokémon de la victoire !")]},
            {"key": "p2", "name": "Labo P2", "attach": "r16", "floors": 2, "theme": "building", "door": "silph", "bonus": 10, "enc": ["p2-laboratory"],
             "require": F("champion_unys"), "locked": "Un laboratoire abandonné... La porte ne s'ouvre que pour le Maître d'Unys.",
             "content": [legend("genesect", 649, 75, "Une machine se réveille dans un bruit métallique... Genesect !")]},
            {"key": "serment", "name": "Bois du Serment", "attach": "r8", "floors": 1, "theme": "forest", "bonus": 10, "trainers": 0,
             "require": {"all_flags": ["leg_638", "leg_639", "leg_640"]}, "locked": "Un bois secret... Seuls ceux qui ont rencontré les trois Épées de la Justice peuvent y entrer.",
             "content": [legend("keldeo", 647, 72, "Un jeune Pokémon déterminé t'attend au milieu du bois... Keldeo !")]},
            {"key": "fregate", "name": "Frégate Plasma", "attach": "port_yoneuve", "floors": 2, "theme": "rocket", "door": "silph", "music": "rocket",
             "trainers": 2, "trainer_class": "Sbire Rainbow", "extra": {"grass": [(509, 25), (551, 25), (559, 25), (624, 25)]},
             "content": [villain_npc(W, R, "ghetis", "plasma", ghetis,
                                     ["Ghetis : Le Maître de Kanto ! Giovanni m'avait prévenu.", "La Team Plasma ne s'arrêtera jamais ! Unys sera à nous, et ses Pokémon nos esclaves !"],
                                     ["Ghetis : ... La Team Plasma est finie. Encore une fois."],
                                     "Ghetis est vaincu ! Iris t'attend à la Ligue d'Unys, au nord de Janusia.")]},
            {"key": "victoire", "name": "Route Victoire d'Unys", "attach": "r10", "floors": 3, "bonus": 6,
             "enc": ["unova-victory-road/outside", "unova-victory-road/unknown-area-53", "unova-victory-road/unknown-area-59", "unova-victory-road/7f"],
             "content": [legend("terrakium", 639, 72, "Un Pokémon massif garde la Route Victoire... Terrakium, l'une des Épées de la Justice !", {"flag": "champion_unys"})]},
            {"key": "salle_iris", "name": "Salle du Maître d'Unys", "attach": "ligue", "floors": 1, "theme": "building", "door": "league", "trainers": 0,
             "content": [champion_npc(W, R, "iris", "champion_f", champ, "Iris",
                                      ["Iris : Te voilà enfin ! Tu as chassé Ghetis d'Unys, hein ? Trop fort !", "Mais maintenant c'est moi, Iris, la Maîtresse d'Unys ! En garde !"],
                                      ["Iris : T'es vraiment incroyable ! Le titre est à toi !", "Au fait... la Team Rainbow Rocket a recruté Lysandre, de la Team Flare. Il est à Kalos !"],
                                      "Iris : Ghetis et sa Frégate Plasma sont encore à Port Yoneuve ! Va les arrêter d'abord !")]},
        ],
    }


# =============================================================================
# KALOS
# =============================================================================

def kalos(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "kalos"
    lysandre = strong_trainer(W, "rr_kalos_lysandre", "Chef Flare", "Lysandre", [(620, 74), (430, 74), (668, 75), (130, 77)],
                              "Lysandre : Le monde est trop laid. Avec l'arme ultime et la Team Rainbow Rocket, je le rendrai beau... en le vidant !",
                              "Lysandre : ... Ma vision était si belle. Pourquoi ne la vois-tu pas ?", "flare", "villain", aura="fire")
    cornelia = strong_trainer(W, "cornelia", "Championne", "Cornélia", [(619, 64), (67, 64), (701, 65), (448, 66)],
                              "Cornélia : Je suis Cornélia de la Tour Maîtrise ! La Méga-Évolution se mérite. Montre-moi ton lien avec tes Pokémon !",
                              "Cornélia : Waouh ! Tu mérites le Méga-Anneau !", "girl", "leader", ai=2)
    champ = strong_trainer(W, "maitre_kalos", "Maître", "Dianthéa", [(701, 76), (697, 76), (699, 77), (711, 77), (706, 78), (282, 80)],
                           "Dianthéa : Je suis Dianthéa, Maître de Kalos. Que notre combat soit aussi beau qu'une pièce de théâtre !",
                           "Dianthéa : Quelle performance... Tu as volé la vedette !", "champion_f", "champion")
    W.quests["chap_kalos"] = chapter(R, "Kalos", "Lysandre et la Team Flare ont rejoint la Team Rainbow Rocket. Leur repaire est sous Cromlac'h !",
                                     "Lysandre est vaincu ! Dianthéa, Maître de Kalos, t'attend à la Ligue (au nord d'Auffrac-les-Congères).")
    W.quests["q_kalos_mega"] = {"title": "La Méga-Évolution", "stages": ["", "Cornélia, à la Tour Maîtrise de Yantreizh, confie le Méga-Anneau aux dresseurs qui la battent.",
                                                                        "Tu as le Méga-Anneau ! La Boutique Méga d'Illumis vend toutes les Méga-Gemmes."]}
    mega_stones = sorted(k for k, v in W.ITEMS_JSON.items() if v.get("cat") == "mega-stones")
    cornelia_npc = {"id": "cornelia", "look": "girl", "kind": "script", "script": [
        iff(F("got_mega_ring"), [say("Cornélia : Fais bon usage du Méga-Anneau ! La Boutique Méga d'Illumis a toutes les Méga-Gemmes.")],
            [say("Cornélia : Salut ! Tu veux la Méga-Évolution ? Il faudra me battre d'abord !"), quest("q_kalos_mega", 1), battle(cornelia),
             say("Cornélia : Bravo ! Voici le Méga-Anneau et une Lucarite."), give("mega-ring"), give("lucarionite"), setf("got_mega_ring"),
             quest("q_kalos_mega", 2)])]}
    return {
        "realm": R, "name": "Kalos", "prefix": "ka", "gen": 6, "max_species": 721, "versions": ["23", "24"], "band": (58, 74),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur", "Nageuse", "Karatéka", "Médium", "Canon", "Gentleman"],
        "lore": ["Kalos est la région de la beauté. Illumis, sa capitale, brille de mille feux.", "La Méga-Évolution a été découverte ici. Cornélia, à Yantreizh, en est la gardienne.",
                 "La Team Flare porte des costumes rouges et parle de « beauté »... Inquiétant.", "Une arme ancienne serait cachée sous Cromlac'h, la ville des menhirs."],
        "mart_extra": ["dusk-ball", "quick-ball", "timer-ball", "repeat-ball", "heal-ball", "net-ball", "nest-ball", "dive-ball", "luxury-ball"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-l", "dusk-stone", "shiny-stone", "dawn-stone",
                 "ice-stone", "sachet", "whipped-dream", "jaw-fossil", "sail-fossil", "tmsv039", "tmsv079", "tmsv119"],
        "progress": ["bourg_croquis", "quarellis", "r2", "foret", "r3", "neuvartault", "r4", "illumis", "r5", "fort_vanitas", "r7", "relifac", "r8",
                     "roche_gliffe", "r9", "cromlach", "r10", "yantreizh", "r12", "port_tempere", "r16", "romant", "r14", "r15", "la_frescale", "r17",
                     "flusselles", "r18", "mozheim", "r19", "auffrac", "r20", "ligue"],
        "zones": {
            "bourg_croquis": {"kind": "town", "at": (0, 6), "loc": "vaniville-town",
                              "lab": {"prof": "Prof. Platane", "starters": [650, 653, 656],
                                      "intro": ["Prof. Platane : Bienvenue à Kalos ! J'étudie la Méga-Évolution.", "Choisis l'un de ces Pokémon pour ton voyage !"]}},
            "quarellis": {"kind": "town", "at": (0, 5), "loc": "aquacorde-town"},
            "r2": {"kind": "route", "at": (0, 4), "loc": "kalos-route-2", "enc": ["kalos-route-2"]},
            "foret": {"kind": "forest", "at": (1, 4), "loc": "santalune-forest", "enc": ["santalune-forest"]},
            "r3": {"kind": "route", "at": (2, 4), "loc": "kalos-route-3", "enc": ["kalos-route-3"]},
            "neuvartault": {"kind": "town", "at": (3, 4), "loc": "santalune-city"},
            "r4": {"kind": "route", "at": (3, 3), "loc": "kalos-route-4", "enc": ["kalos-route-4"]},
            "illumis": {"kind": "town", "at": (3, 2), "loc": "lumiose-city",
                        "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                        "assault-vest", "eviolite", "heavy-duty-boots", "weakness-policy", "safety-goggles", "luminous-moss",
                                        "snowball", "pixie-plate", "roseli-berry", "kee-berry", "maranga-berry"],
                        "special_shop": ["Boutique Méga", mega_stones, ["Vendeuse : Toutes les Méga-Gemmes connues ! Il te faut un Méga-Anneau pour t'en servir.",
                                                                        "Cornélia, à Yantreizh, en donne aux dresseurs qui la battent."]]},
            "r5": {"kind": "route", "at": (2, 2), "loc": "kalos-route-5", "enc": ["kalos-route-5"]},
            "fort_vanitas": {"kind": "town", "at": (1, 2), "loc": "camphrier-town"},
            "r7": {"kind": "route", "at": (1, 1), "loc": "kalos-route-7", "name": "Routes 6 et 7", "enc": ["kalos-route-6", "kalos-route-7", "parfum-palace"]},
            "relifac": {"kind": "town", "at": (1, 0), "loc": "cyllage-city", "enc": ["cyllage-city"]},
            "r8": {"kind": "route", "at": (2, 0), "loc": "kalos-route-8", "enc": ["kalos-route-8"]},
            "roche_gliffe": {"kind": "town", "at": (3, 0), "loc": "ambrette-town", "enc": ["ambrette-town"], "fossil": True},
            "r9": {"kind": "desert", "at": (4, 0), "loc": "kalos-route-9", "enc": ["kalos-route-9"]},
            "cromlach": {"kind": "town", "at": (5, 0), "loc": "geosenge-town"},
            "r10": {"kind": "route", "at": (6, 0), "loc": "kalos-route-10", "name": "Routes 10 et 11", "enc": ["kalos-route-10", "kalos-route-11"],
                    "extra": {"grass": [(702, 10)]}},
            "yantreizh": {"kind": "town", "at": (7, 0), "loc": "shalour-city", "enc": ["shalour-city"], "npcs": [cornelia_npc]},
            "r12": {"kind": "route", "at": (7, 1), "loc": "kalos-route-12", "enc": ["kalos-route-12", "azure-bay"]},
            "port_tempere": {"kind": "port", "at": (7, 2), "loc": "coumarine-city", "port": True},
            "r16": {"kind": "route", "at": (6, 2), "loc": "kalos-route-16", "enc": ["kalos-route-16"]},
            "romant": {"kind": "town", "at": (5, 2), "loc": "laverre-city", "enc": ["laverre-city"]},
            "r14": {"kind": "lake", "at": (4, 2), "loc": "kalos-route-14", "enc": ["kalos-route-14", "kalos-route-13"]},
            "r15": {"kind": "route", "at": (5, 3), "loc": "kalos-route-15", "enc": ["kalos-route-15"]},
            "la_frescale": {"kind": "town", "at": (5, 4), "loc": "dendemille-town"},
            "r17": {"kind": "snow", "at": (6, 4), "loc": "kalos-route-17", "enc": ["kalos-route-17"]},
            "flusselles": {"kind": "town", "at": (7, 4), "loc": "anistar-city"},
            "r18": {"kind": "route", "at": (7, 5), "loc": "kalos-route-18", "enc": ["kalos-route-18"]},
            "mozheim": {"kind": "town", "at": (8, 5), "loc": "couriway-town", "enc": ["couriway-town"]},
            "r19": {"kind": "route", "at": (8, 6), "loc": "kalos-route-19", "enc": ["kalos-route-19"]},
            "auffrac": {"kind": "town", "at": (8, 7), "loc": "snowbelle-city"},
            "r20": {"kind": "forest", "at": (9, 7), "loc": "kalos-route-20", "enc": ["kalos-route-20", "pokemon-village"]},
            "ligue": {"kind": "town", "at": (10, 7), "loc": "kalos-pokemon-league", "name": "Ligue Pokémon de Kalos", "enc": ["kalos-route-21", "kalos-route-22"], "extra_houses": 0},
        },
        "links": [("bourg_croquis", "quarellis"), ("quarellis", "r2"), ("r2", "foret"), ("foret", "r3"), ("r3", "neuvartault"), ("neuvartault", "r4"),
                  ("r4", "illumis"), ("illumis", "r5"), ("r5", "fort_vanitas"), ("fort_vanitas", "r7"), ("r7", "relifac"), ("relifac", "r8"),
                  ("r8", "roche_gliffe"), ("roche_gliffe", "r9"), ("r9", "cromlach"), ("cromlach", "r10"), ("r10", "yantreizh"), ("yantreizh", "r12"),
                  ("r12", "port_tempere"), ("port_tempere", "r16"), ("r16", "romant"), ("romant", "r14"), ("r14", "illumis"), ("romant", "r15"),
                  ("r15", "la_frescale"), ("la_frescale", "r17"), ("r17", "flusselles"), ("flusselles", "r18"), ("r18", "mozheim"), ("mozheim", "r19"),
                  ("r19", "auffrac"), ("auffrac", "r20"), ("r20", "ligue")],
        "dungeons": [
            {"key": "miroitante", "name": "Grotte Miroitante", "attach": "r10", "floors": 2, "theme": "ice",
             "enc": ["reflection-cave/unknown-area-305", "reflection-cave/unknown-area-306", "reflection-cave/unknown-area-307", "reflection-cave/unknown-area-308"]},
            {"key": "etincelante", "name": "Grotte Étincelante", "attach": "r9", "floors": 2, "enc": ["glittering-cave/unknown-area-303", "glittering-cave/unknown-area-304"],
             "rare": [[719, 72, 600, "leg_719", {"flag": "champion_kalos"}]]},
            {"key": "connecterre", "name": "Cave Connecterre", "attach": "r8", "floors": 1, "enc": ["connecting-cave"]},
            {"key": "gelee", "name": "Caverne Gelée", "attach": "r17", "floors": 2, "theme": "ice", "bonus": 6,
             "enc": ["frost-cavern/unknown-area-313", "frost-cavern/unknown-area-315", "frost-cavern/unknown-area-317"],
             "content": [miniboss(W, "seracrawl_gelee", 713, 76, "ice", ["Un Séracrawl gigantesque bloque la caverne gelée !"], ["Séracrawl se fige et laisse passer."])]},
            {"key": "flare", "name": "Repaire Team Flare", "attach": "cromlach", "floors": 3, "theme": "rocket", "door": "silph", "music": "rocket",
             "trainers": 2, "trainer_class": "Sbire Rainbow", "enc": ["team-flare-secret-hq"],
             "content": [villain_npc(W, R, "lysandre", "flare", lysandre,
                                     ["Lysandre : Te voilà enfin. Giovanni et moi avons le même rêve : un monde nouveau.", "Et toi, tu es une tache dans ce tableau parfait !"],
                                     ["Lysandre : ... Xerneas et Yveltal sont libres. Le monde... continuera."],
                                     "Lysandre est vaincu ! Dianthéa, Maître de Kalos, t'attend à la Ligue."),
                         legend("xerneas", 716, 78, "Un arbre de lumière s'illumine... Xerneas, le Pokémon de la vie !", {"flag": "chap_kalos_villain"}),
                         legend("yveltal", 717, 78, "Un cocon sombre s'ouvre... Yveltal, le Pokémon de la destruction !", {"flag": "chap_kalos_villain"})]},
            {"key": "coda", "name": "Grotte Coda", "attach": "r18", "floors": 3, "bonus": 10,
             "enc": ["terminus-cave/1f", "terminus-cave/b1f-left", "terminus-cave/b2f"], "require": F("champion_kalos"),
             "locked": "Des bruits étranges montent de la grotte... Seul le Maître de Kalos peut y descendre.",
             "content": [legend("zygarde", 718, 78, "Des cellules vertes s'assemblent... Zygarde, le gardien de l'écosystème !")]},
            {"key": "desolation", "name": "Hôtel Désolation", "attach": "r15", "floors": 2, "theme": "mansion", "door": "mansion", "enc": ["lost-hotel"],
             "content": [legend("hoopa", 720, 72, "Un anneau flotte dans le hall... Hoopa en sort en riant !", {"flag": "champion_kalos"})]},
            {"key": "nereen", "name": "Antre Néréen", "attach": "port_tempere", "floors": 1, "theme": "water", "bonus": 12, "trainers": 0,
             "enc": ["sea-spirits-den"], "require": F("champion_kalos"), "locked": "La marée bloque l'accès à l'antre...",
             "content": [legend("volcanion", 721, 74, "Une vapeur brûlante remplit l'antre... Volcanion !")]},
            {"key": "victoire", "name": "Route Victoire de Kalos", "attach": "ligue", "floors": 2, "bonus": 6,
             "enc": ["kalos-victory-road/outside", "kalos-victory-road/unknown-area-322", "kalos-victory-road/unknown-area-326"],
             "content": [champion_npc(W, R, "diantha", "champion_f", champ, "Dianthéa",
                                      ["Dianthéa : Bienvenue, {player}. Tu as sauvé Kalos de Lysandre...", "Maintenant, offrons au public le plus beau des combats !"],
                                      ["Dianthéa : Bravo ! Tu es le nouveau Maître de Kalos.", "On dit qu'à Alola, Elsa-Mina de la Fondation Æther a rejoint la Team Rainbow Rocket..."],
                                      "Dianthéa : Lysandre et la Team Flare menacent encore Kalos. Arrête-les d'abord !")]},
        ],
    }



# =============================================================================
# ALOLA
# =============================================================================

def totem(W, nid, sid, lvl, aura, crystal, intro):
    """Pokémon Dominant (boss à aura) : il garde un Cristal Z."""
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    flag = f"boss_{nid}"
    return {"id": nid, "look": "legend", "species": sid, "kind": "script", "ghost": True, "hide_if": F(flag),
            "script": [say(intro, "C'est un Pokémon Dominant ! Il appelle une aura à son secours !"), ["boss", sid, lvl, flag, aura],
                       say("Le Pokémon Dominant s'éloigne. Il a laissé un Cristal Z !"), give(crystal)]}


def alola(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "alola"
    elsa = strong_trainer(W, "rr_alola_elsamina", "Présidente Æther", "Elsa-Mina", [(36, 76), (549, 76), (350, 77), (760, 77), (429, 78)],
                          "Elsa-Mina : Mes chers Pokémon... Avec Giovanni, je les protégerai pour toujours, loin de ce monde sale !",
                          "Elsa-Mina : Non... Mes précieux... Pourquoi personne ne comprend mon amour ?", "aether", "villain", aura="fairy")
    pectorius = strong_trainer(W, "pectorius", "Doyen", "Pectorius", [(57, 66), (297, 66), (740, 68)],
                               "Pectorius : Je suis Pectorius, doyen de Mele-Mele ! Les capacités Z se méritent : montre-moi ta force !",
                               "Pectorius : Ho ho ! Le Bracelet Z est à toi !", "hiker", "leader", ai=2)
    champ = strong_trainer(W, "maitre_alola", "Maître", "Prof. Euphorbe", [(745, 78), (10104, 78), (628, 79), (462, 79), (143, 80), (727, 82)],
                           "Prof. Euphorbe : Woooh ! Je suis le Prof. Euphorbe, et je défends le titre de Maître d'Alola ! Allez, on y va !",
                           "Prof. Euphorbe : Woooh ! Quel combat ! Tu es le Maître d'Alola, cousin !", "prof", "champion")
    W.quests["chap_alola"] = chapter(R, "Alola", "Elsa-Mina, la présidente de la Fondation Æther, s'est alliée à la Team Rainbow Rocket. Va au Paradis Æther, au large de Ho'ohale !",
                                     "Elsa-Mina est vaincue ! Le Prof. Euphorbe défend le titre de Maître à la Ligue d'Alola, au sommet du Mont Lanakila.")
    W.quests["q_alola_z"] = {"title": "Les capacités Z", "stages": ["", "Le doyen Pectorius, à Lili'i, donne le Bracelet Z aux dresseurs qui le battent.",
                                                                "Tu as le Bracelet Z ! Les Pokémon Dominants des grottes gardent des Cristaux Z, et la Boutique Z d'Ekaeka en vend."]}
    z_crystals = sorted(k for k, v in W.ITEMS_JSON.items() if v.get("cat") == "z-crystals" and not k.endswith("--bag"))
    pectorius_npc = {"id": "pectorius", "look": "hiker", "kind": "script", "script": [
        iff(F("got_z_ring"), [say("Pectorius : Les capacités Z unissent le dresseur et son Pokémon. Utilise-les bien !")],
            [say("Pectorius : Bienvenue à Lili'i ! Tu veux le pouvoir des capacités Z ?"), quest("q_alola_z", 1), battle(pectorius),
             say("Pectorius : Ho ho ! Voici le Bracelet Z et un Normalium Z."), give("z-ring"), give("normalium-z--held"), setf("got_z_ring"), quest("q_alola_z", 2)])]}
    lillie = {"id": "lilie", "look": "lass", "kind": "script", "script": [
        iff(F("champion_alola"), [iff(F("got_cosmog"), [say("Lilie : Prends soin de Cosmog... Il deviendra très fort !")],
                                      [say("Lilie : Tu as sauvé ma mère... Merci. Je te confie Cosmog. Il sera heureux avec toi."), ["mon", 789, 50], setf("got_cosmog")])],
            [say("Lilie : Ma mère, Elsa-Mina... Elle a rejoint ces gens horribles. Je t'en prie, arrête-la !")])]}
    gladio = {"id": "gladio", "look": "rival", "kind": "script", "script": [
        iff(F("got_type_null"), [say("Gladio : Type:0 a besoin d'un dresseur qui lui fait confiance. Ne me déçois pas.")],
            [iff(F("chap_alola_villain"),
                 [say("Gladio : ... Tu as arrêté ma mère. Je n'ai pas réussi, moi.", "Ce Pokémon a été créé ici, au Paradis Æther, pour combattre les Ultra-Chimères.",
                      "Son casque l'empêche d'utiliser sa vraie force. Avec toi, il pourra peut-être s'en libérer."),
                  ["mon", 772, 60], setf("got_type_null"),
                  say("Gladio : Quand il te fera vraiment confiance, il deviendra Silvallié.")],
                 [say("Gladio : Ma mère est en haut. Je n'ai pas la force de l'affronter... Toi, peut-être.")])])]}
    ub = [legend("zeroid", 793, 76, "Une créature translucide flotte dans l'Ultra-Dimension... Zéroïd, une Ultra-Chimère !"),
          legend("mouscoto", 794, 76, "Des muscles gigantesques... Mouscoto, une Ultra-Chimère !"),
          legend("cancrelove", 795, 76, "Une silhouette d'une élégance troublante... Cancrelove, une Ultra-Chimère !"),
          legend("cablifere", 796, 76, "Des câbles crépitants... Câblifère, une Ultra-Chimère !"),
          legend("bamboiselle", 797, 76, "Une tour de bambou vivante... Bamboiselle, une Ultra-Chimère !"),
          legend("katagami", 798, 76, "Une feuille de papier tranchante... Katagami, une Ultra-Chimère !"),
          legend("engloutyran", 799, 76, "Une gueule immense... Engloutyran, une Ultra-Chimère !"),
          legend("ama_ama", 803, 70, "Un petit Pokémon venimeux t'observe avec curiosité... Vémini !"),
          legend("ama_ama2", 805, 76, "Un mur de pierres vivantes... Ama-Ama, une Ultra-Chimère !"),
          legend("pierroteknik", 806, 76, "Un clown explosif ricane... Pierroteknik, une Ultra-Chimère !")]
    return {
        "realm": R, "name": "Alola", "prefix": "al", "gen": 7, "max_species": 809, "versions": ["29", "30", "27", "28"], "band": (62, 78),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur", "Nageuse", "Karatéka", "Médium", "Canon"],
        "lore": ["Alola, c'est quatre îles, du soleil et des Pokémon sous des formes que tu n'as jamais vues !", "À Alola, chaque île a son Pokémon gardien : les Tokos.",
                 "La Fondation Æther protège les Pokémon... du moins c'est ce qu'elle dit.", "Des failles dans le ciel mènent à l'Ultra-Dimension, peuplée d'Ultra-Chimères."],
        "mart_extra": ["dusk-ball", "quick-ball", "timer-ball", "repeat-ball", "heal-ball", "net-ball", "nest-ball", "dive-ball", "luxury-ball"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-xl", "ice-stone", "dawn-stone",
                 "fire-stone", "water-stone", "thunder-stone", "leaf-stone", "moon-stone", "sun-stone", "tmsv054", "tmsv113", "tmsv140"],
        "progress": ["lili_i", "r1", "ekaeka", "r2", "r3", "mer_mele", "ho_ohale", "r4", "ohana", "r6", "r7", "konikoni", "r9", "mer_ula", "malie",
                     "r10", "r11", "r12", "r13", "village_toko", "r15", "kokohio", "r17", "ligue", "flottant", "poni", "defi"],
        "zones": {
            "lili_i": {"kind": "town", "at": (0, 1), "loc": "iki-town", "enc": ["alola-route-1/east"],
                       "lab": {"prof": "Prof. Euphorbe", "starters": [722, 725, 728],
                               "intro": ["Prof. Euphorbe : Alola ! Woooh, un Maître de Kanto chez nous !", "Choisis l'un de ces Pokémon. Ils sont trop cool, cousin !"]},
                       "npcs": [pectorius_npc]},
            "r1": {"kind": "route", "at": (1, 1), "loc": "alola-route-1", "enc": ["alola-route-1/hauoli-outskirts", "alola-route-1/south", "alola-route-1/west"]},
            "ekaeka": {"kind": "port", "at": (2, 1), "loc": "hauoli-city", "enc": ["hauoli-city/beachfront", "hauoli-city/main"], "port": True,
                       "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                       "assault-vest", "eviolite", "heavy-duty-boots", "terrain-extender", "electric-seed", "psychic-seed",
                                       "grassy-seed", "misty-seed", "protective-pads", "adrenaline-orb"],
                       "special_shop": ["Boutique Z", z_crystals, ["Vendeur : Tous les Cristaux Z d'Alola ! Il te faut le Bracelet Z du doyen Pectorius."]],
                       "npcs": [lillie]},
            "r2": {"kind": "route", "at": (2, 0), "loc": "alola-route-2", "enc": ["alola-route-2/main", "alola-route-2/north", "hauoli-cemetery"]},
            "r3": {"kind": "route", "at": (3, 0), "loc": "alola-route-3", "enc": ["alola-route-3/main", "alola-route-3/north", "melemele-meadow"]},
            "mer_mele": {"kind": "sea", "at": (3, 1), "loc": "melemele-sea", "enc": ["melemele-sea", "kalae-bay"]},
            "ho_ohale": {"kind": "town", "at": (4, 1), "loc": "heahea-city", "enc": ["hano-beach"]},
            "r4": {"kind": "route", "at": (5, 1), "loc": "alola-route-4", "name": "Routes 4 et 5", "enc": ["alola-route-4", "alola-route-5"]},
            "ohana": {"kind": "town", "at": (6, 1), "loc": "paniola-town", "enc": ["paniola-ranch"]},
            "r6": {"kind": "route", "at": (7, 1), "loc": "alola-route-6", "enc": ["alola-route-6/north", "alola-route-6/south"]},
            "r7": {"kind": "route", "at": (7, 2), "loc": "alola-route-7", "name": "Routes 7 et 8", "enc": ["alola-route-7", "alola-route-8/main", "akala-outskirts"]},
            "konikoni": {"kind": "town", "at": (7, 3), "loc": "konikoni-city", "enc": ["konikoni-city"]},
            "r9": {"kind": "route", "at": (6, 3), "loc": "alola-route-9", "enc": ["alola-route-9/main", "memorial-hill"]},
            "mer_ula": {"kind": "sea", "at": (8, 3), "name": "Mer d'Ula-Ula", "enc": ["ulaula-beach"]},
            "malie": {"kind": "town", "at": (9, 3), "loc": "malie-city", "enc": ["malie-garden", "malie-city/outer-cape"]},
            "r10": {"kind": "route", "at": (9, 2), "loc": "alola-route-10", "enc": ["alola-route-10"]},
            "r11": {"kind": "route", "at": (10, 3), "loc": "alola-route-11", "enc": ["alola-route-11"]},
            "r12": {"kind": "route", "at": (11, 3), "loc": "alola-route-12", "enc": ["alola-route-12", "blush-mountain"],
                    "rare": [[807, 76, 800, "leg_807", {"flag": "champion_alola"}]]},
            "r13": {"kind": "desert", "at": (11, 4), "loc": "alola-route-13", "name": "Route 13 et Désert Haina", "enc": ["alola-route-13", "haina-desert"]},
            "village_toko": {"kind": "town", "at": (11, 5), "loc": "tapu-village", "enc": ["tapu-village"]},
            "r15": {"kind": "route", "at": (10, 5), "loc": "alola-route-15", "name": "Routes 14 à 16", "enc": ["alola-route-14", "alola-route-15/main", "alola-route-16/main"]},
            "kokohio": {"kind": "town", "at": (9, 5), "loc": "po-town", "music": "rocket"},
            "r17": {"kind": "route", "at": (11, 6), "loc": "alola-route-17", "enc": ["alola-route-17/west", "alola-route-17/northeast", "ulaula-meadow"]},
            "ligue": {"kind": "town", "at": (12, 6), "loc": "alola-pokemon-league", "name": "Ligue Pokémon d'Alola", "enc": ["mount-lanakila/outside"], "extra_houses": 0},
            "flottant": {"kind": "town", "at": (11, 7), "loc": "seafolk-village", "enc": ["seafolk-village/main"]},
            "poni": {"kind": "route", "at": (10, 7), "loc": "poni-wilds", "name": "Terres de Poni",
                     "enc": ["poni-wilds", "poni-grove", "poni-meadow", "poni-plains/center", "poni-breaker-coast", "ancient-poni-path"]},
            "defi": {"kind": "route", "at": (9, 7), "loc": "poni-gauntlet", "enc": ["poni-gauntlet", "exeggutor-island"]},
        },
        "links": [("lili_i", "r1"), ("r1", "ekaeka"), ("ekaeka", "r2"), ("r2", "r3"), ("ekaeka", "mer_mele"), ("mer_mele", "ho_ohale"), ("ho_ohale", "r4"),
                  ("r4", "ohana"), ("ohana", "r6"), ("r6", "r7"), ("r7", "konikoni"), ("konikoni", "r9"), ("konikoni", "mer_ula"), ("mer_ula", "malie"),
                  ("malie", "r10"), ("malie", "r11"), ("r11", "r12"), ("r12", "r13"), ("r13", "village_toko"), ("village_toko", "r15"),
                  ("r15", "kokohio"), ("village_toko", "r17"), ("r17", "ligue"), ("r17", "flottant"), ("flottant", "poni"), ("poni", "defi")],
        "dungeons": [
            {"key": "verdoyante", "name": "Grotte Verdoyante", "attach": "r2", "floors": 1, "enc": ["verdant-cavern/trial-site"],
             "content": [totem(W, "totem_rattatac", 10092, 70, "dark", "darkinium-z--held", "Un Rattatac d'Alola énorme surgit du fond de la grotte !")]},
            {"key": "clapotis", "name": "Colline Clapotis", "attach": "r4", "floors": 1, "theme": "water",
             "enc": ["brooklet-hill/main", "brooklet-hill/north", "brooklet-hill/south"],
             "content": [totem(W, "totem_tarenbulle", 752, 72, "water", "waterium-z--held", "Une bulle géante éclate... Un Tarenbulle Dominant !")]},
            {"key": "jungle", "name": "Jungle Sombrefeuille", "attach": "ohana", "floors": 2, "theme": "forest",
             "enc": ["lush-jungle/north", "lush-jungle/south", "lush-jungle/west", "lush-jungle/east-cave"],
             "content": [totem(W, "totem_floramantis", 754, 72, "grass", "grassium-z--held", "Des pétales tourbillonnent... Un Floramantis Dominant !")]},
            {"key": "volcan", "name": "Parc Volcanique", "attach": "r6", "floors": 1, "theme": "volcano", "enc": ["wela-volcano-park"],
             "content": [totem(W, "totem_malamandre", 758, 72, "fire", "firium-z--held", "Une odeur toxique... Un Malamandre Dominant sort des flammes !")]},
            {"key": "hokulani", "name": "Mont Hokulani", "attach": "r10", "floors": 2, "theme": "rock",
             "enc": ["mount-hokulani/main", "mount-hokulani/east", "mount-hokulani/west"], "extra": {"grass": [(774, 20)]},
             "content": [totem(W, "totem_togedemaru", 777, 74, "electric", "electrium-z--held", "Des étincelles partout... Un Togedemaru Dominant !")]},
            {"key": "manoir", "name": "Manoir Chelou", "attach": "r15", "floors": 1, "theme": "mansion", "door": "mansion", "enc": ["thrifty-megamart/abandoned-site"],
             "content": [totem(W, "totem_mimiqui", 778, 74, "ghost", "ghostium-z--held", "Un Mimiqui Dominant te fixe derrière son déguisement..."),
                         legend("marshadow", 802, 74, "Une ombre bouge toute seule dans le manoir... Marshadow !", {"flag": "champion_alola"})]},
            {"key": "aether", "name": "Paradis Æther", "attach": "ho_ohale", "floors": 2, "theme": "building", "door": "silph", "music": "rocket",
             "trainers": 2, "trainer_class": "Sbire Rainbow", "extra": {"grass": [(132, 30), (35, 20), (173, 20)]},
             "content": [villain_npc(W, R, "elsa_mina", "aether", elsa,
                                     ["Elsa-Mina : Bienvenue au Paradis Æther. Ici, mes Pokémon sont protégés de tout...", "Giovanni comprend ma vision. Toi, tu vas tout gâcher !"],
                                     ["Elsa-Mina : ... Lilie... Je suis désolée."],
                                     "Elsa-Mina est vaincue ! Le Prof. Euphorbe t'attend à la Ligue d'Alola, au sommet du Mont Lanakila."), gladio]},
            {"key": "conflit", "name": "Ruines du Conflit", "attach": "r3", "floors": 1, "theme": "rock", "bonus": 12, "trainers": 0, "enc": ["ruins-of-conflict"],
             "require": F("champion_alola"), "locked": "Les ruines sont scellées... Seul le Maître d'Alola peut entrer.",
             "content": [legend("tokorico", 785, 76, "La foudre s'abat dans les ruines... Tokorico, le gardien de Mele-Mele !")]},
            {"key": "eveil", "name": "Ruines de l'Éveil", "attach": "konikoni", "floors": 1, "theme": "rock", "bonus": 12, "trainers": 0, "enc": ["ruins-of-life"],
             "require": F("champion_alola"), "locked": "Les ruines sont scellées... Seul le Maître d'Alola peut entrer.",
             "content": [legend("tokopiyon", 786, 76, "Des papillons de lumière dansent... Tokopiyon, la gardienne d'Akala !")]},
            {"key": "essor", "name": "Ruines de l'Essor", "attach": "r13", "floors": 1, "theme": "rock", "bonus": 12, "trainers": 0, "enc": ["ruins-of-abundance"],
             "require": F("champion_alola"), "locked": "Les ruines sont scellées... Seul le Maître d'Alola peut entrer.",
             "content": [legend("tokotoro", 787, 76, "Des lianes envahissent les ruines... Tokotoro, le gardien d'Ula-Ula !")]},
            {"key": "au_dela", "name": "Ruines de l'Au-Delà", "attach": "poni", "floors": 1, "theme": "rock", "bonus": 12, "trainers": 0, "enc": ["ruins-of-hope"],
             "require": F("champion_alola"), "locked": "Les ruines sont scellées... Seul le Maître d'Alola peut entrer.",
             "content": [legend("tokopisco", 788, 76, "Une brume épaisse se lève... Tokopisco, la gardienne de Poni !")]},
            {"key": "canyon", "name": "Grand Canyon de Poni", "attach": "defi", "floors": 3, "theme": "rock", "bonus": 10,
             "enc": ["vast-poni-canyon/outside", "vast-poni-canyon/inside", "vast-poni-canyon/northwest"],
             "require": F("champion_alola"), "locked": "Le canyon est trop dangereux... Seul le Maître d'Alola s'y aventure.",
             "content": [legend("solgaleo", 791, 80, "À l'Autel du Soleil, une lumière aveuglante... Solgaleo, la bête qui dévore le soleil !"),
                         legend("lunala", 792, 80, "À l'Autel de la Lune, un voile de nuit... Lunala, la bête qui avale la lune !"),
                         legend("necrozma", 800, 82, "Un prisme noir aspire la lumière... Necrozma !", {"all_flags": ["leg_791", "leg_792"]})]},
            {"key": "ultra", "name": "Ultra-Dimension", "attach": "defi", "floors": 3, "theme": "psychic", "bonus": 14,
             "enc": ["ultra-space-wilds/cave", "ultra-space-wilds/cliff", "ultra-space-wilds/crag"],
             "require": F("champion_alola"), "locked": "Une faille dans le ciel... Elle ne s'ouvre que pour le Maître d'Alola.", "content": ub},
            {"key": "magearna", "name": "Château de Kokohio", "attach": "kokohio", "floors": 2, "theme": "mansion", "door": "mansion", "bonus": 10,
             "content": [legend("magearna", 801, 74, "Une poupée mécanique s'anime... Magearna, le Pokémon artificiel !", {"flag": "champion_alola"})]},
            {"key": "lanakila", "name": "Mont Lanakila", "attach": "ligue", "floors": 2, "theme": "ice", "bonus": 6,
             "enc": ["mount-lanakila/base", "mount-lanakila/cave", "mount-lanakila/crater"],
             "content": [champion_npc(W, R, "euphorbe", "prof", champ, "Prof. Euphorbe",
                                      ["Prof. Euphorbe : Woooh ! Tu as libéré Alola d'Elsa-Mina ! Trop fort, cousin !", "Mais le titre de Maître, il faudra me le prendre !"],
                                      ["Prof. Euphorbe : Woooh ! Tu es le Maître d'Alola !", "On dit que Shehroz, le président de Macro Cosmos à Galar, travaille avec Giovanni..."],
                                      "Prof. Euphorbe : Elsa-Mina est encore au Paradis Æther, au large de Ho'ohale. Arrête-la d'abord !")]},
        ],
    }


# =============================================================================
# GALAR
# =============================================================================

def galar(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "galar"
    rose = strong_trainer(W, "rr_galar_shehroz", "Président", "Shehroz", [(879, 80), (598, 80), (589, 81), (863, 81), (601, 82)],
                          "Shehroz : L'énergie de Galar s'épuisera dans mille ans ! Avec Éthernatos et Giovanni, je règle ce problème... maintenant !",
                          "Shehroz : ... Je voulais seulement sauver Galar.", "macro", "villain", aura="steel")
    champ = strong_trainer(W, "maitre_galar", "Maître", "Tarak", [(681, 82), (887, 82), (612, 83), (537, 83), (866, 83), (6, 85)],
                           "Tarak : Je suis Tarak, Maître invaincu de Galar ! Prépare-toi pour un combat de champion !",
                           "Tarak : ... Mon invincibilité s'arrête ici. Quel combat incroyable !", "champion_m", "champion")
    W.quests["chap_galar"] = chapter(R, "Galar", "Shehroz, président de Macro Cosmos, veut réveiller Éthernatos avec la Team Rainbow Rocket. Monte à la Tour Rose de Winscor !",
                                     "Shehroz est vaincu ! Tarak, le Maître invaincu de Galar, t'attend au Stade de Winscor.")
    W.quests["q_galar_dojo"] = {"title": "Le Dojo de la Maîtrise", "stages": ["", "Le maître du Dojo de l'Île d'Armure confie Wushours aux dresseurs qu'il juge dignes.",
                                                                          "Tu as Wushours ! Ses deux Tours (Ténèbres et Eau) le feront évoluer en Shifours."]}
    birds = [[10169, 78, 900, "leg_10169", {"flag": "champion_galar"}], [10170, 78, 900, "leg_10170", {"flag": "champion_galar"}],
             [10171, 78, 900, "leg_10171", {"flag": "champion_galar"}]]
    dojo = {"id": "maitre_dojo", "look": "oldman", "kind": "script", "script": [
        iff(F("got_kubfu"), [say("Maître du Dojo : Emmène Wushours à la Tour des Ténèbres ou à la Tour de l'Eau. Il y trouvera sa voie !")],
            [say("Maître du Dojo : Ho ho ! Un Maître de Kanto au Dojo ? Prends ce petit Wushours, il a besoin d'un vrai dresseur."), ["mon", 891, 70],
             setf("got_kubfu"), quest("q_galar_dojo", 2)])]}
    return {
        "realm": R, "name": "Galar", "prefix": "ga", "gen": 8, "max_species": 898, "versions": ["33", "34", "35", "50", "36", "51"], "band": (66, 82),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur", "Nageuse", "Karatéka", "Médium", "Canon", "Gentleman"],
        "lore": ["Galar adore les combats Pokémon : les matchs se jouent dans d'immenses stades !", "La Tour Rose de Winscor appartient à Macro Cosmos, l'entreprise du président Shehroz.",
                 "Dans la Forêt de Sleepwood, deux héros légendaires dorment depuis des siècles.", "Les oiseaux légendaires de Galar ne ressemblent pas du tout à ceux de Kanto !"],
        "mart_extra": ["dusk-ball", "quick-ball", "timer-ball", "repeat-ball", "heal-ball", "net-ball", "nest-ball", "dive-ball", "luxury-ball", "dream-ball"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-xl", "sweet-apple", "tart-apple", "cracked-pot",
                 "galarica-cuff", "galarica-wreath", "fossilized-bird", "fossilized-fish", "fossilized-drake", "fossilized-dino", "tmsv121", "tmsv147"],
        "progress": ["paddoxton", "r1", "brasswick", "r2", "plaine", "lac", "rocheuse", "motorby", "r3", "r4", "greenbury", "r5", "skifford", "old_chister",
                     "lumirinth", "corrifey", "r6", "kickenham", "r7", "r8", "ludester", "r9", "smashings", "r10", "winscor", "dojo", "salutation",
                     "efforts", "hameau", "plateau", "pente"],
        "zones": {
            "paddoxton": {"kind": "town", "at": (0, 6), "loc": "postwick",
                          "lab": {"prof": "Prof. Magnolia", "starters": [810, 813, 816],
                                  "intro": ["Prof. Magnolia : Un Maître de Kanto à Galar ! Tarak sera ravi de te rencontrer.", "Choisis l'un de ces Pokémon, ils viennent de Galar."]}},
            "r1": {"kind": "route", "at": (0, 5), "loc": "galar-route-1", "enc": ["galar-route-1"]},
            "brasswick": {"kind": "town", "at": (0, 4), "loc": "wedgehurst"},
            "r2": {"kind": "route", "at": (0, 3), "loc": "galar-route-2", "enc": ["galar-route-2/main", "galar-route-2/lakeside", "galar-route-2/lake"], "rare": birds},
            "plaine": {"kind": "route", "at": (1, 3), "loc": "rolling-fields", "name": "Plaine Verdoyante",
                       "enc": ["rolling-fields/main", "dappled-grove", "watchtower-ruins", "west-lake-axewell", "east-lake-axewell", "axews-eye"], "rare": birds,
                       "extra": {"grass": [(83, 12)]}},
            "lac": {"kind": "lake", "at": (1, 2), "loc": "north-lake-miloch", "name": "Lac Milobellus",
                    "enc": ["south-lake-miloch/main", "north-lake-miloch", "giants-seat", "motostoke-riverbank", "bridge-field"], "rare": birds},
            "rocheuse": {"kind": "route", "at": (1, 1), "loc": "stony-wilderness", "name": "Plaine Rocheuse",
                         "enc": ["stony-wilderness/main", "dusty-bowl", "giants-mirror/main", "hammerlocke-hills", "giants-cap/main", "lake-of-outrage"], "rare": birds},
            "motorby": {"kind": "town", "at": (2, 3), "loc": "motostoke", "enc": ["motostoke/main"]},
            "r3": {"kind": "route", "at": (2, 2), "loc": "galar-route-3", "enc": ["galar-route-3/east", "galar-route-3/west"]},
            "r4": {"kind": "route", "at": (2, 1), "loc": "galar-route-4", "enc": ["galar-route-4"]},
            "greenbury": {"kind": "town", "at": (2, 0), "loc": "turffield", "enc": ["turffield"]},
            "r5": {"kind": "route", "at": (3, 0), "loc": "galar-route-5", "enc": ["galar-route-5"]},
            "skifford": {"kind": "port", "at": (4, 0), "loc": "hulbury", "enc": ["hulbury"], "port": True,
                         "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                         "assault-vest", "eviolite", "heavy-duty-boots", "throat-spray", "eject-pack", "blunder-policy",
                                         "room-service", "utility-umbrella", "weakness-policy", "booster-energy"]},
            "old_chister": {"kind": "town", "at": (5, 0), "loc": "stow-on-side", "enc": ["stow-on-side"]},
            "lumirinth": {"kind": "forest", "at": (5, 1), "loc": "glimwood-tangle", "enc": ["glimwood-tangle"],
                          "rare": [[893, 78, 900, "leg_893", {"flag": "champion_galar"}]]},
            "corrifey": {"kind": "town", "at": (5, 2), "loc": "ballonlea"},
            "r6": {"kind": "desert", "at": (6, 0), "loc": "galar-route-6", "enc": ["galar-route-6"], "extra": {"grass": [(562, 15)]}},
            "kickenham": {"kind": "town", "at": (7, 0), "loc": "hammerlocke", "enc": ["hammerlocke"], "fossil": True,
                          "special_shop": ["Boutique des Fouilles", ["fossilized-bird", "fossilized-fish", "fossilized-drake", "fossilized-dino", "cracked-pot",
                                                                     "chipped-pot", "sweet-apple", "tart-apple", "galarica-cuff", "galarica-wreath",
                                                                     "strawberry-sweet", "love-sweet", "berry-sweet", "clover-sweet", "flower-sweet", "star-sweet",
                                                                     "ribbon-sweet"],
                                           ["Vendeuse : Fossiles de Galar, Théières, Pommes, Sucreries... Le chercheur d'à côté sait réveiller les fossiles !"]]},
            "r7": {"kind": "route", "at": (7, 1), "loc": "galar-route-7", "enc": ["galar-route-7"]},
            "r8": {"kind": "route", "at": (7, 2), "loc": "galar-route-8", "enc": ["galar-route-8/main", "galar-route-8/steamdrift-way"]},
            "ludester": {"kind": "town", "at": (7, 3), "loc": "circhester", "enc": ["circhester"]},
            "r9": {"kind": "lake", "at": (6, 3), "loc": "galar-route-9", "enc": ["galar-route-9/main", "galar-route-9/circhester-bay", "galar-route-9/outer-spikemuth"],
                   "extra": {"grass": [(871, 15), (222, 12)], "marsh": [(222, 10)]}},
            "smashings": {"kind": "town", "at": (5, 3), "loc": "spikemuth", "music": "rocket"},
            "r10": {"kind": "snow", "at": (8, 0), "loc": "galar-route-10", "enc": ["galar-route-10/main", "galar-route-10/near-station"], "extra": {"grass": [(122, 12)]}},
            "winscor": {"kind": "town", "at": (9, 0), "loc": "wyndon", "enc": ["wyndon"]},
            "dojo": {"kind": "town", "at": (9, 1), "loc": "master-dojo", "name": "Dojo de la Maîtrise", "npcs": [dojo], "extra_houses": 1},
            "salutation": {"kind": "route", "at": (10, 1), "loc": "fields-of-honor", "name": "Plaine Salutation",
                           "enc": ["fields-of-honor", "soothing-wetlands", "forest-of-focus", "challenge-road", "honeycalm-island"]},
            "efforts": {"kind": "route", "at": (10, 2), "loc": "training-lowlands", "name": "Plaine des Efforts",
                        "enc": ["training-lowlands", "potbottom-desert", "loop-lagoon", "workout-sea", "challenge-beach"]},
            "hameau": {"kind": "town", "at": (9, -1), "loc": "freezington", "music": "town"},
            "plateau": {"kind": "snow", "at": (10, -1), "loc": "slippery-slope", "name": "Plateau Beau-Gant",
                        "enc": ["slippery-slope", "frostpoint-field", "giants-bed", "old-cemetery"],
                        "npcs": [legend("blizzeval", 896, 80, "Un destrier de glace hennit dans la tempête... Blizzeval !", {"flag": "champion_galar"}),
                                 legend("spectreval", 897, 80, "Un destrier spectral surgit du brouillard... Spectreval !", {"flag": "champion_galar"})]},
            "pente": {"kind": "snow", "at": (11, -1), "loc": "snowslide-slope", "name": "Pente Enneigée",
                      "enc": ["snowslide-slope", "path-to-the-peak", "ballimere-lake", "three-point-pass", "dyna-tree-hill"]},
        },
        "links": [("paddoxton", "r1"), ("r1", "brasswick"), ("brasswick", "r2"), ("r2", "plaine"), ("plaine", "motorby"), ("plaine", "lac"),
                  ("lac", "rocheuse"), ("motorby", "r3"), ("r3", "r4"), ("r4", "greenbury"), ("greenbury", "r5"), ("r5", "skifford"),
                  ("skifford", "old_chister"), ("old_chister", "lumirinth"), ("lumirinth", "corrifey"), ("old_chister", "r6"), ("r6", "kickenham"),
                  ("kickenham", "r7"), ("r7", "r8"), ("r8", "ludester"), ("ludester", "r9"), ("r9", "smashings"), ("kickenham", "r10"),
                  ("r10", "winscor"), ("winscor", "dojo"), ("dojo", "salutation"), ("salutation", "efforts"), ("winscor", "hameau"),
                  ("hameau", "plateau"), ("plateau", "pente")],
        "dungeons": [
            {"key": "mine", "name": "Mine de Galar", "attach": "r3", "floors": 2, "enc": ["galar-mine"]},
            {"key": "mine2", "name": "Mine de Galar n° 2", "attach": "skifford", "floors": 2, "enc": ["galar-mine-no-2"], "extra": {"grass": [(878, 15)]}},
            {"key": "sleepwood", "name": "Forêt de Sleepwood", "attach": "r2", "floors": 2, "theme": "forest", "bonus": 10,
             "enc": ["slumbering-weald/main", "slumbering-weald/deep"],
             "content": [legend("zacian", 888, 82, "Une épée de lumière fend la brume... Zacian, le héros aguerri !", {"flag": "champion_galar"}),
                         legend("zamazenta", 889, 82, "Un bouclier se dresse dans la brume... Zamazenta, le héros aguerri !", {"flag": "champion_galar"})]},
            {"key": "tour_rose", "name": "Tour Rose", "attach": "winscor", "floors": 3, "theme": "building", "door": "silph", "music": "rocket",
             "trainers": 2, "trainer_class": "Sbire Rainbow", "enc": ["energy-plant/tower-summit"],
             "content": [villain_npc(W, R, "shehroz", "macro", rose,
                                     ["Shehroz : Bienvenue au sommet de la Tour Rose. D'ici, je vois l'avenir de Galar.", "Giovanni m'a offert le pouvoir d'Éthernatos. Tu ne m'en priveras pas !"],
                                     ["Shehroz : ... Éthernatos s'éveille quand même ! Je ne le contrôle plus !"],
                                     "Shehroz est vaincu ! Tarak t'attend au Stade de Winscor... mais Éthernatos s'est réveillé au sommet !"),
                         legend("ethernatos", 890, 84, "Un immense dragon de poison déploie ses ailes... Éthernatos !", {"flag": "chap_galar_villain"})]},
            {"key": "tenebres", "name": "Tour des Ténèbres", "attach": "efforts", "floors": 2, "theme": "tower", "door": "tower", "bonus": 8,
             "items": ["scroll-of-darkness"], "extra": {"grass": [(570, 20), (215, 20), (302, 15)]}},
            {"key": "eau", "name": "Tour de l'Eau", "attach": "efforts", "floors": 2, "theme": "water", "door": "tower", "bonus": 8,
             "items": ["scroll-of-waters"], "extra": {"grass": [(7, 20), (60, 20), (418, 15)]}},
            {"key": "choix", "name": "Ruines du Choix", "attach": "plateau", "floors": 1, "theme": "rock", "bonus": 12, "trainers": 0,
             "enc": ["split-decision-ruins"], "require": F("champion_galar"), "locked": "Les ruines sont scellées...",
             "content": [legend("regieleki", 894, 80, "Un éclair vivant jaillit des ruines... Regieleki !"),
                         legend("regidrago", 895, 80, "Une tête de dragon de pierre s'anime... Regidrago !")]},
            {"key": "couronne", "name": "Temple Couronne", "attach": "pente", "floors": 2, "theme": "ice", "bonus": 12, "enc": ["crown-shrine"],
             "require": F("champion_galar"), "locked": "Le Temple Couronne ne s'ouvre qu'au Maître de Galar.",
             "content": [legend("sylveroy", 898, 82, "Un roi couronné de fleurs t'attend sur l'autel... Sylveroy, le Roi des Bienfaits !",
                                {"all_flags": ["leg_896", "leg_897"]})]},
            {"key": "stade", "name": "Stade de Winscor", "attach": "winscor", "floors": 1, "theme": "building", "door": "league", "trainers": 0,
             "content": [champion_npc(W, R, "tarak", "champion_m", champ, "Tarak",
                                      ["Tarak : Te voilà ! Tu as stoppé Shehroz et la Team Rainbow Rocket. Galar te doit beaucoup.", "Mais sur ce terrain, je suis le Maître invaincu. Montre-moi un combat de champion !"],
                                      ["Tarak : Tu es le nouveau Maître de Galar !", "La dernière région où la Team Rainbow Rocket se cache... c'est Paldea. Ils veulent la Zone Zéro."],
                                      "Tarak : Shehroz est encore en haut de la Tour Rose. Arrête-le d'abord !")]},
        ],
    }


# =============================================================================
# PALDEA
# =============================================================================
# Pas de tables officielles d'Écarlate et Violet dans les données : les rencontres sont écrites à la main,
# zone par zone, d'après les jeux (Pokémon de Paldea + anciens Pokémon présents dans le Pokédex de Paldea).

PARADOX_ANCIENT = [984, 985, 986, 987, 988, 989, 1005, 1009, 1020, 1021]
PARADOX_FUTURE = [990, 991, 992, 993, 994, 995, 1006, 1010, 1022, 1023]


def paldea(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "paldea"
    turum = strong_trainer(W, "rr_paldea_turum", "Prof. IA", "Turum", [(994, 84), (991, 84), (992, 85), (993, 85), (995, 85), (990, 86)],
                           "IA Turum : Je suis l'intelligence artificielle du Prof. Turum. Giovanni m'a ouvert une nouvelle voie : "
                           "les Pokémon du futur, en nombre infini, pour la Team Rainbow Rocket.",
                           "IA Turum : ... Programme interrompu. Le Prof. Turum aurait voulu que quelqu'un m'arrête.", "scientist", "villain",
                           aura="electric")
    champ = strong_trainer(W, "maitre_paldea", "Présidente de la Ligue", "Alisma", [(956, 84), (673, 84), (976, 85), (713, 85), (983, 86), (970, 88)],
                           "Alisma : Je suis Alisma, présidente de la Ligue de Paldea. Je dois vérifier par moi-même ta valeur. En garde !",
                           "Alisma : ... Admirable. Paldea a un nouveau Maître.", "champion_f", "champion")
    W.quests["chap_paldea"] = chapter(R, "Paldea", "Une IA, copie du Prof. Turum, aide la Team Rainbow Rocket à tirer des Pokémon du futur de la Zone Zéro. Descends dans le Grand Cratère !",
                                      "L'IA Turum est arrêtée ! Alisma, présidente de la Ligue, t'attend à la Ligue Pokémon de Paldea.")
    W.quests["q_paldea_titans"] = {"title": "Les Pokémon Titans", "stages": ["", "Cinq Pokémon Titans, géants et entourés d'une aura, rôdent à Paldea. Trouve-les tous !",
                                                                         "Terminé ! Tu as vaincu les cinq Pokémon Titans de Paldea."]}
    titan_flags = [f"boss_titan_{k}" for k in ("lestombaile", "craparoi", "fort_ivoire", "ferdeter", "oyacata")]
    W.quests["q_septentria"] = {"title": "La légende de Septentria", "stages": ["",
        "À Septentria, on raconte que trois « Loyaux » ont volé les masques d'un ogre. Cherche-les dans les Terres Vierges, la Forêt Ternelle et le Mont Strueux.",
        "Les trois Loyaux sont capturés. L'ogre, Ogerpon, t'attend dans la Gueule du Monstre... avec ses masques."]}

    def titan(nid, sid, lvl, aura, desc):
        n = miniboss(W, nid, sid, lvl, aura, [f"Le sol tremble... {desc}", "C'est un Pokémon Titan ! Une aura immense l'entoure !"],
                     ["Le Pokémon Titan s'enfuit en laissant derrière lui une herbe mystérieuse..."])
        n["script"].insert(0, quest("q_paldea_titans", 1))
        n["script"].append(give("exp-candy-xl", 2))
        n["script"].append(iff({"all_flags": titan_flags}, [quest("q_paldea_titans", 2), say("Tu as vaincu les cinq Pokémon Titans de Paldea !")]))
        return n

    clavel_intro = ["Directeur Clavel : Bienvenue à l'Académie Orange ! Un Maître de Kanto venu à Paldea ? Quel honneur !",
                    "Ici, chaque élève reçoit un Pokémon pour sa Chasse au Trésor. Choisis le tien !"]
    sage = {"id": "sage_sanctuaires", "look": "oldman", "kind": "script", "script": [
        say("Vieil homme : Quatre sanctuaires scellés retiennent les Quatre Fléaux : le Bois Mourant, le Froid Cruel, le Sol Corrompu et le Feu Ravageur.",
            "Leurs sceaux ne cèdent que devant le Maître de Paldea. Leurs gardiens sont terrifiants... Sois prudent.")]}
    shop = ["gimmighoul-coin", "auspicious-armor", "malicious-armor", "unremarkable-teacup", "masterpiece-teacup", "syrupy-apple", "metal-alloy",
            "leaders-crest", "booster-energy", "ability-patch", "covert-cloak", "loaded-dice", "mirror-herb", "punching-glove", "clear-amulet",
            "ability-shield", "fairy-feather", "tmsv226"]
    paradox_rate = [(sid, 6) for sid in PARADOX_ANCIENT + PARADOX_FUTURE]
    return {
        "realm": R, "name": "Paldea", "prefix": "pa", "gen": 9, "max_species": 1025, "versions": [], "band": (70, 86),
        "classes": ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur", "Nageuse", "Karatéka", "Médium", "Canon", "Gentleman"],
        "lore": ["Paldea est une immense région : on peut l'explorer dans l'ordre que l'on veut !", "Au centre de Paldea s'ouvre le Grand Cratère. Personne n'en connaît le fond...",
                 "Les élèves de l'Académie Orange partent chaque année pour la Chasse au Trésor.", "Des Pokémon jamais vus ailleurs sortiraient de la Zone Zéro, tout au fond du cratère.",
                 "Septentria, au nord-est, est un village paisible où l'on fête les trois héros Loyaux."],
        "mart_extra": ["dusk-ball", "quick-ball", "timer-ball", "repeat-ball", "heal-ball", "net-ball", "nest-ball", "dive-ball", "luxury-ball", "dream-ball"],
        "loot": ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-xl", "ability-capsule", "bottle-cap",
                 "tmsv001", "tmsv171", "tmsv167", "tmsv169", "sweet-apple", "tart-apple", "syrupy-apple", "unremarkable-teacup", "gimmighoul-coin"],
        "progress": ["porto", "ouest1", "jarramanca", "mesaledo", "sud1", "plato_real", "route_cuchalaga", "cuchalaga", "sud2", "cuencia", "sud3", "sevaro",
                     "desert", "mezclamora", "ouest2", "alforneira", "est1", "levalendura", "est3", "pinchoria", "est2", "ligue", "mont_nappe", "frigao",
                     "nord3", "lac_asrol", "cratere", "septentria", "jaderaude", "terres", "foret_ternelle", "mont_strueux", "parc_adorami"],
        "zones": {
            "porto": {"kind": "port", "at": (0, 3), "loc": "porto-marinada", "port": True,
                      "battle_shop": ["leftovers", "choice-band", "choice-specs", "choice-scarf", "life-orb", "focus-sash", "rocky-helmet",
                                      "assault-vest", "eviolite", "heavy-duty-boots", "throat-spray", "eject-pack", "blunder-policy",
                                      "room-service", "utility-umbrella", "weakness-policy", "booster-energy", "covert-cloak", "loaded-dice"],
                      "special_shop": ["Marché de Porto Marinada", shop, ["Marchand : Objets rares de Paldea ! Armures, bols, pommes, et même des Pièces de Mordudor."]]},
            "ouest1": {"kind": "route", "at": (1, 3), "loc": "paldea-west-province-area-one",
                       "extra": {"grass": [(915, 15), (917, 12), (919, 10), (921, 10), (924, 12), (928, 10), (931, 10), (938, 8), (940, 8), (962, 6),
                                           (187, 8), (661, 8), (734, 8)]},
                       "npcs": [titan("titan_lestombaile", 962, 76, "flying", "Un Lestombaile gigantesque fond du ciel !")]},
            "jarramanca": {"kind": "town", "at": (2, 3), "loc": "cascarrafa"},
            "mesaledo": {"kind": "town", "at": (3, 3), "loc": "mesagoza", "extra_houses": 3,
                         "lab": {"prof": "Directeur Clavel", "starters": [906, 909, 912], "intro": clavel_intro}},
            "sud1": {"kind": "route", "at": (3, 4), "loc": "paldea-south-province-area-one",
                     "extra": {"grass": [(915, 18), (917, 12), (919, 12), (921, 12), (926, 10), (924, 10), (187, 8), (661, 8), (819, 8), (734, 6), (194, 8)]}},
            "plato_real": {"kind": "town", "at": (3, 5), "loc": "los-platos"},
            "route_cuchalaga": {"kind": "route", "at": (2, 5), "loc": "poco-path",
                                "extra": {"grass": [(915, 18), (921, 14), (917, 12), (919, 10), (926, 10), (819, 10), (661, 8), (187, 8)]}},
            "cuchalaga": {"kind": "town", "at": (1, 5), "loc": "cabo-poco", "extra_houses": 1},
            "sud2": {"kind": "route", "at": (4, 5), "loc": "paldea-south-province-area-two",
                     "extra": {"grass": [(928, 12), (944, 10), (948, 10), (951, 10), (953, 8), (938, 8), (926, 8), (285, 8), (546, 8), (406, 8), (316, 6), (128, 6)]}},
            "cuencia": {"kind": "town", "at": (5, 5), "loc": "artazon"},
            "sud3": {"kind": "route", "at": (6, 5), "loc": "paldea-south-province-area-three",
                     "extra": {"grass": [(932, 12), (950, 6), (942, 10), (944, 8), (957, 10), (953, 8), (74, 8), (299, 6), (524, 8), (27, 8)]},
                     "npcs": [titan("titan_craparoi", 950, 77, "rock", "Un Craparoi énorme surgit d'une falaise !")]},
            "sevaro": {"kind": "town", "at": (5, 6), "loc": "cortondo", "extra_houses": 1},
            "desert": {"kind": "desert", "at": (2, 2), "loc": "asado-desert",
                       "extra": {"grass": [(932, 10), (948, 10), (969, 8), (328, 10), (551, 10), (27, 8), (449, 10), (843, 8), (50, 6), (999, 4)]},
                       "npcs": [titan("titan_fort_ivoire", 984, 79, "ground", "Une silhouette massive charge à travers le sable... Fort-Ivoire !")]},
            "mezclamora": {"kind": "town", "at": (2, 1), "loc": "medali", "npcs": [sage]},
            "ouest2": {"kind": "route", "at": (1, 1), "loc": "paldea-west-province-area-two",
                       "extra": {"grass": [(940, 10), (942, 10), (946, 10), (951, 8), (955, 10), (965, 8), (967, 4), (203, 8), (856, 8), (280, 8), (206, 8)]}},
            "alforneira": {"kind": "town", "at": (0, 1), "loc": "alfornada", "extra_houses": 1},
            "est1": {"kind": "route", "at": (4, 3), "loc": "paldea-east-province-area-one",
                     "extra": {"grass": [(921, 12), (938, 10), (940, 10), (942, 10), (944, 8), (957, 8), (965, 8), (403, 10), (179, 8), (587, 6)]}},
            "levalendura": {"kind": "town", "at": (5, 3), "loc": "levincia"},
            "est3": {"kind": "route", "at": (6, 3), "loc": "paldea-east-province-area-three",
                     "extra": {"grass": [(965, 10), (968, 6), (969, 8), (971, 10), (973, 8), (957, 8), (624, 8), (442, 4), (613, 8), (57, 6)]},
                     "npcs": [titan("titan_ferdeter", 968, 80, "steel", "Un Ferdeter géant creuse la montagne de ses anneaux d'acier !")]},
            "pinchoria": {"kind": "town", "at": (7, 3), "loc": "zapapico"},
            "est2": {"kind": "lake", "at": (7, 4), "loc": "paldea-east-province-area-two",
                     "extra": {"grass": [(960, 12), (946, 10), (955, 10), (973, 8), (931, 10), (278, 10), (692, 8), (690, 8)],
                               "marsh": [(963, 15), (960, 10), (129, 15), (976, 8), (194, 10)], "super-rod": [(963, 12), (976, 10), (130, 8), (846, 10)]}},
            "ligue": {"kind": "town", "at": (4, 2), "loc": "pokemon-league", "name": "Ligue Pokémon de Paldea", "extra_houses": 0},
            "mont_nappe": {"kind": "snow", "at": (4, 1), "loc": "glaseado-mountain",
                           "extra": {"grass": [(974, 12), (996, 10), (971, 8), (225, 8), (215, 8), (459, 8), (361, 8), (712, 8), (872, 8), (613, 8)]}},
            "frigao": {"kind": "town", "at": (4, 0), "loc": "montenevera"},
            "nord3": {"kind": "route", "at": (5, 0), "loc": "paldea-north-province-area-three",
                      "extra": {"grass": [(942, 8), (944, 8), (967, 6), (969, 8), (971, 8), (371, 6), (443, 6), (633, 6), (885, 6), (996, 6), (999, 4), (935, 6)]}},
            "lac_asrol": {"kind": "lake", "at": (5, 1), "loc": "casseroya-lake",
                          "extra": {"grass": [(976, 6), (963, 10), (147, 6), (54, 10), (194, 10), (60, 10), (283, 8)],
                                    "marsh": [(977, 10), (978, 12), (976, 10), (963, 15), (129, 15), (349, 4), (194, 10)],
                                    "super-rod": [(977, 10), (978, 10), (976, 10), (130, 8), (349, 6)]},
                          "npcs": [titan("titan_oyacata", 977, 81, "water", "La surface du lac se soulève... Un Oyacata titanesque, avec un Nigirigon sur la tête !")]},
            "cratere": {"kind": "route", "at": (5, 2), "name": "Bord du Grand Cratère", "rate": 0.1,
                        "extra": {"grass": [(967, 8), (973, 8), (969, 8), (942, 8), (921, 8), (996, 6), (999, 6), (147, 6), (246, 6), (704, 6), (935, 6)]}},
            "septentria": {"kind": "route", "at": (8, 3), "loc": "kitakami-road",
                           "extra": {"grass": [(1012, 10), (840, 10), (946, 8), (924, 8), (43, 8), (102, 8), (163, 8), (570, 6), (231, 8)]}},
            "jaderaude": {"kind": "town", "at": (9, 3), "loc": "mossui-town", "extra_houses": 2,
                          "npcs": [{"id": "conteur_septentria", "look": "oldman", "kind": "script", "script": [
                              say("Conteur : Il y a longtemps, un ogre terrorisait Septentria. Trois héros, les Loyaux, l'auraient chassé...",
                                  "Mais certains disent que ce sont les Loyaux qui avaient volé les masques de l'ogre !"), quest("q_septentria", 1)]}]},
            "terres": {"kind": "route", "at": (9, 2), "loc": "kitakami-wilds",
                       "extra": {"grass": [(1012, 10), (840, 10), (167, 8), (335, 6), (336, 6), (447, 6), (436, 6), (220, 8)]},
                       "npcs": [legend("felicanis", 1014, 82, "Un Pokémon au collier de chaînes toxiques te barre la route... Félicanis, l'un des Loyaux !",
                                       {"flag": "champion_paldea"})]},
            "foret_ternelle": {"kind": "forest", "at": (9, 4), "loc": "timeless-woods",
                               "extra": {"grass": [(1012, 12), (840, 10), (285, 8), (43, 8), (92, 8), (198, 8), (708, 8), (946, 8)]},
                               "npcs": [legend("fortusimia", 1015, 82, "Un singe au regard hypnotique te fixe depuis une branche... Fortusimia, l'un des Loyaux !",
                                               {"flag": "champion_paldea"})]},
            "mont_strueux": {"kind": "route", "at": (9, 1), "loc": "oni-mountain",
                             "extra": {"grass": [(1012, 8), (840, 8), (624, 8), (74, 8), (66, 8), (631, 6), (632, 6)]},
                             "npcs": [legend("favianos", 1016, 82, "Un oiseau aux plumes empoisonnées se pose devant toi... Favianos, l'un des Loyaux !",
                                             {"flag": "champion_paldea"})]},
            "parc_adorami": {"kind": "town", "at": (10, 3), "loc": "loyalty-plaza", "extra_houses": 0,
                             "npcs": [legend("pechaminus", 1025, 84, "Une étrange odeur de pêche... Un petit Pokémon ricane derrière les statues : Pêchaminus !",
                                             {"flag": "leg_1017"})]},
        },
        "links": [("porto", "ouest1"), ("ouest1", "jarramanca"), ("jarramanca", "mesaledo"), ("jarramanca", "desert"), ("desert", "mezclamora"),
                  ("mezclamora", "ouest2"), ("ouest2", "alforneira"), ("mesaledo", "sud1"), ("sud1", "plato_real"), ("plato_real", "route_cuchalaga"),
                  ("route_cuchalaga", "cuchalaga"), ("plato_real", "sud2"), ("sud2", "cuencia"), ("cuencia", "sud3"), ("cuencia", "sevaro"),
                  ("mesaledo", "est1"), ("est1", "levalendura"), ("levalendura", "est3"), ("est3", "pinchoria"), ("pinchoria", "est2"),
                  ("est1", "ligue"), ("ligue", "cratere"), ("ligue", "mont_nappe"), ("mont_nappe", "frigao"), ("mont_nappe", "lac_asrol"),
                  ("frigao", "nord3"), ("pinchoria", "septentria"), ("septentria", "jaderaude"), ("jaderaude", "terres"), ("terres", "mont_strueux"),
                  ("jaderaude", "foret_ternelle"), ("jaderaude", "parc_adorami")],
        "dungeons": [
            {"key": "alforneira_grotte", "name": "Grotte d'Alforneira", "attach": "alforneira", "floors": 2, "theme": "rock", "bonus": 6,
             "extra": {"grass": [(957, 12), (999, 10), (969, 10), (74, 10), (41, 10), (304, 8), (610, 6), (529, 8)]}},
            {"key": "tunnel", "name": "Tunnel Mezcla-Pincho", "attach": "mezclamora", "floors": 1, "bonus": 4,
             "extra": {"grass": [(932, 12), (942, 10), (957, 10), (41, 10), (74, 10), (95, 8), (524, 8)]}},
            {"key": "zone_zero", "name": "Zone Zéro", "attach": "cratere", "floors": 3, "theme": "psychic", "bonus": 6, "music": "rocket",
             "trainers": 2, "trainer_class": "Sbire Rainbow",
             "extra": {"grass": [(996, 10), (969, 10), (973, 8), (967, 8), (921, 8), (447, 8), (282, 6), (373, 4), (635, 4)]},
             "content": [villain_npc(W, R, "ia_turum", "scientist", turum,
                                     ["IA Turum : Te voici à la Station Zéro. Le Prof. Turum a passé sa vie ici, à chercher l'avenir.",
                                      "Avec la machine temporelle et la Team Rainbow Rocket, l'avenir viendra à nous. Je ne peux pas te laisser l'arrêter."],
                                     ["IA Turum : ... Arrêt de la machine temporelle. Merci. Vraiment."],
                                     "L'IA Turum est arrêtée ! Alisma t'attend à la Ligue Pokémon de Paldea. Plus bas, la Zone Zéro reste à explorer...")]},
            {"key": "profondeurs", "name": "Zone Zéro - Profondeurs", "attach": "cratere", "floors": 3, "theme": "psychic", "bonus": 10, "trainers": 0,
             "rate": 0.12, "cap": 24, "require": F("chap_paldea_villain"), "locked": "Un champ de force bloque le passage... Il faut d'abord arrêter l'IA de la Station Zéro.",
             "extra": {"grass": paradox_rate + [(996, 6), (969, 6), (447, 6), (373, 3)]},
             "content": [legend("koraidon", 1007, 86, "Une silhouette rouge dort au fond de la Zone Zéro... Koraidon, le Pokémon du passé !", {"flag": "champion_paldea"}),
                         legend("miraidon", 1008, 86, "Des circuits violets s'illuminent dans l'obscurité... Miraidon, le Pokémon du futur !", {"flag": "champion_paldea"}),
                         legend("terapagos", 1024, 88, "Un cristal géant vibre... Le Pokémon de la Téracristallisation se réveille : Terapagos !",
                                {"all_flags": ["leg_1007", "leg_1008"]})]},
            {"key": "bois_mourant", "name": "Sanctuaire du Bois Mourant", "attach": "ouest2", "floors": 1, "theme": "forest", "bonus": 12, "trainers": 0,
             "require": F("champion_paldea"), "locked": "Un sceau ancien bloque l'entrée... Seul le Maître de Paldea peut le briser.",
             "content": [legend("chongjian", 1001, 82, "Des feuilles se fanent tout autour... Chongjian, le Fléau du Bois Mourant !")]},
            {"key": "froid_cruel", "name": "Sanctuaire du Froid Cruel", "attach": "mont_nappe", "floors": 1, "theme": "ice", "bonus": 12, "trainers": 0,
             "require": F("champion_paldea"), "locked": "Un sceau ancien bloque l'entrée... Seul le Maître de Paldea peut le briser.",
             "content": [legend("baojian", 1002, 82, "Le froid te mord les os... Baojian, le Fléau du Froid Cruel !")]},
            {"key": "sol_corrompu", "name": "Sanctuaire du Sol Corrompu", "attach": "desert", "floors": 1, "theme": "ground", "bonus": 12, "trainers": 0,
             "require": F("champion_paldea"), "locked": "Un sceau ancien bloque l'entrée... Seul le Maître de Paldea peut le briser.",
             "content": [legend("dinglu", 1003, 82, "La terre se fend sous tes pieds... Dinglu, le Fléau du Sol Corrompu !")]},
            {"key": "feu_ravageur", "name": "Sanctuaire du Feu Ravageur", "attach": "nord3", "floors": 1, "theme": "volcano", "bonus": 12, "trainers": 0,
             "require": F("champion_paldea"), "locked": "Un sceau ancien bloque l'entrée... Seul le Maître de Paldea peut le briser.",
             "content": [legend("yuyu", 1004, 82, "Des flammes dansent dans le noir... Yuyu, le Fléau du Feu Ravageur !")]},
            {"key": "gueule", "name": "Gueule du Monstre", "attach": "mont_strueux", "floors": 2, "theme": "rock", "bonus": 10, "trainers": 0,
             "extra": {"grass": [(1012, 10), (624, 10), (66, 10), (74, 10), (631, 8)]},
             "items": ["wellspring-mask", "hearthflame-mask", "cornerstone-mask"],
             "content": [legend("ogerpon", 1017, 84, "Un petit ogre masqué danse au fond de la grotte... Ogerpon !",
                                {"all_flags": ["leg_1014", "leg_1015", "leg_1016"]})]},
            {"key": "salle_ligue", "name": "Salle de la Ligue", "attach": "ligue", "floors": 1, "theme": "building", "door": "league", "trainers": 0,
             "content": [champion_npc(W, R, "alisma", "champion_f", champ, "Alisma",
                                      ["Alisma : Tu as arrêté l'IA de la Station Zéro. Paldea te remercie.", "Mais la Ligue ne donne pas son titre par gratitude. Prouve ta force !"],
                                      ["Alisma : Tu es le Maître de Paldea.", "Huit régions libérées... Giovanni ne peut plus se cacher. Son Château t'attend."],
                                      "Alisma : L'IA de la Station Zéro est encore active, au fond du Grand Cratère. Arrête-la d'abord !")]},
        ],
    }


# =============================================================================
# CHÂTEAU ROCKET ET ABÎME (fin de la campagne)
# =============================================================================

def rainbow(W):
    say, iff, setf, give, F, special, battle, quest, hide = _helpers(W)
    R = "rainbow"
    gio = strong_trainer(W, "rr_giovanni_final", "Boss Rainbow", "Giovanni", [(34, 90), (464, 90), (445, 91), (115, 91), (53, 91), (150, 92)],
                         "Giovanni : Huit régions... Tu as démantelé chacun de mes alliés. Mais ici, c'est MON château, et Mewtwo m'obéit enfin.",
                         "Giovanni : ... Encore toi. Toujours toi. Très bien. La Team Rainbow Rocket n'existe plus.", "giovanni", "villain",
                         aura="ground", money=50000)
    gardien = strong_trainer(W, "gardien_abime", "Gardien de l'Abîme", "", [(150, 100), (384, 100), (383, 100), (382, 100), (483, 100), (484, 100)],
                             "Gardien de l'Abîme : ...", "Gardien de l'Abîme : ...", "abyss", "abyss", aura="dragon", money=100000)
    W.trainers[gardien]["name"] = "Gardien de l'Abîme"
    W.quests["chap_rainbow"] = {"title": "Le Château Rocket", "main": False, "stages": ["",
        "Les huit Fragments Arc-en-Ciel t'ont mené au Château Rocket. Monte jusqu'au trône et bats Giovanni !",
        "Giovanni est vaincu ! Sous le Château, l'Abîme s'est ouvert : dix étages de dresseurs au niveau 100...",
        "Terminé ! Tu as vaincu le Gardien de l'Abîme. Le Pokémon Alpha t'attendait tout au fond."]}
    giovanni = {"id": "giovanni_final", "look": "giovanni", "kind": "script", "dir": "down", "hide_if": F("rainbow_done"), "script": [
        say("Giovanni : Bienvenue dans la salle du trône, Maître de neuf régions.", "Tu as repris mes huit fragments. Il ne reste que moi... et Mewtwo."),
        battle(gio),
        say("Giovanni : Mon château... Mes alliés... Tout s'effondre.", "Écoute bien : sous ce château dort l'Abîme. Même moi, je n'ai jamais osé y descendre."),
        special("finale"), give("master-ball"), hide("giovanni_final")]}
    gardien_npc = {"id": "gardien", "look": "abyss", "kind": "script", "dir": "down", "hide_if": F("abyss_done"), "script": [
        say("Une silhouette immobile se tient au fond de l'Abîme...", "Gardien de l'Abîme : Nul ne descend ici sans payer le prix. Montre-moi ce que valent tes Pokémon au sommet de leur force."),
        battle(gardien),
        say("Gardien de l'Abîme : ... Tu es digne. Le Pokémon Alpha t'attend derrière moi."),
        special("abyss_done"), hide("gardien")]}
    elite_pool = sorted(sid for sid, p in W.POKE.items() if sid <= 1025 and not p["legendary"] and not p["mythical"] and not p["evos"]
                        and sum(p["base"]) >= 520)
    rocket_pool = [24, 110, 89, 229, 262, 169, 461, 430, 452, 454, 625, 560, 635, 248, 53, 112, 31, 34, 130, 142, 197, 359, 571, 553, 435, 59]
    shop = ["bottle-cap", "gold-bottle-cap", "ability-patch", "ability-capsule", "exp-candy-xl", "rare-candy", "pp-max", "macho-brace",
            "power-weight", "power-bracer", "power-belt", "power-lens", "power-band", "power-anklet"] + \
        sorted(k for k in W.ITEMS_JSON if k.endswith("-mint"))
    return {
        "realm": R, "name": "Château Rocket", "prefix": "cr", "gen": 9, "max_species": 1025, "versions": [], "band": (88, 95),
        "classes": ["Sbire Rainbow", "Admin Rainbow"],
        "lore": ["Ce château est apparu d'un coup, sur une île sans nom. Les gens d'ici l'appellent le Château Rocket.",
                 "On dit qu'un gouffre sans fond s'ouvre sous le château. Ceux qui y descendent en reviennent changés... quand ils en reviennent.",
                 "La boutique du quai vend tout ce qu'il faut pour entraîner des Pokémon parfaits."],
        "mart_extra": ["dusk-ball", "quick-ball", "timer-ball", "repeat-ball", "heal-ball", "net-ball", "nest-ball", "luxury-ball", "dream-ball"],
        "loot": ["full-restore", "max-revive", "rare-candy", "pp-max", "max-elixir", "exp-candy-xl", "bottle-cap", "ability-capsule"],
        "progress": ["quai", "jardins", "parvis"],
        "zones": {
            "quai": {"kind": "port", "at": (0, 0), "name": "Quai du Château", "port": True, "extra_houses": 0,
                     "battle_shop": sorted(k for k, v in W.ITEMS_JSON.items() if v.get("cat") == "held-items" and v.get("price", 0) > 0),
                     "special_shop": ["Boutique de l'Élite", shop, ["Vendeur : Capsules d'Argent, Aromates, objets Pouvoir... Tout pour des Pokémon parfaits !"]]},
            "jardins": {"kind": "route", "at": (1, 0), "name": "Jardins du Château", "trainers": 4,
                        "extra": {"grass": [(130, 10), (59, 8), (229, 10), (262, 10), (24, 8), (110, 8), (89, 8), (53, 8), (197, 6), (359, 6), (571, 6), (553, 6)]}},
            "parvis": {"kind": "town", "at": (2, 0), "name": "Parvis du Château", "music": "rocket", "extra_houses": 0},
        },
        "links": [("quai", "jardins"), ("jardins", "parvis")],
        "dungeons": [
            {"key": "chateau", "name": "Château Rocket", "attach": "parvis", "floors": 4, "theme": "rocket", "door": "mansion", "music": "rocket",
             "trainers": 3, "elite": {"level": 86, "step": 1, "size": 5, "pool": rocket_pool, "classes": ["Sbire Rainbow", "Admin Rainbow"],
                                      "look": "rainbow", "kind": "villain", "music": "rocket",
                                      "intros": ["Personne ne monte jusqu'au Boss !", "Le Château Rocket est imprenable !", "Tu vas regretter d'être venu ici !"],
                                      "defeats": ["Le Boss va me tuer...", "Impossible... Tu es trop fort !", "Monte, si tu l'oses..."]},
             "items": ["max-revive", "full-restore"], "content": [giovanni]},
            {"key": "abime", "name": "Abîme", "attach": "parvis", "floors": 10, "theme": "abyss", "bonus": 4, "rate": 0.1, "trainers": 2, "cap": 20,
             "require": F("rainbow_done"), "locked": "Un gouffre sans fond... Des forces obscures le scellent tant que Giovanni règne sur le château.",
             "extra": {"grass": [(149, 6), (248, 6), (373, 6), (376, 6), (445, 6), (635, 6), (706, 6), (784, 6), (887, 6), (998, 6),
                                 (113, 8), (242, 6), (531, 8), (143, 6), (131, 6), (289, 4), (230, 6), (472, 6)]},
             "elite": {"level": 91, "step": 1, "size": 6, "pool": elite_pool, "classes": ["Topdresseur", "Dresseur de l'Abîme"],
                       "intros": ["Ici, seuls les plus forts survivent.", "Au niveau 100, la moindre erreur ne pardonne pas.", "Combien d'étages tiendras-tu ?"],
                       "defeats": ["... Descends. Si tu l'oses.", "Tes Pokémon sont parfaits...", "L'Abîme te jugera plus bas."]},
             "items": ["gold-bottle-cap", "ability-patch"],
             "content": [gardien_npc, legend("arceus", 493, 100, "Une lumière divine emplit l'Abîme... Arceus, le Pokémon Alpha, celui qui a créé l'univers !",
                                              {"flag": "abyss_done"})]},
        ],
    }

ALL = [sevii, johto, hoenn, sinnoh, hisui, unys, kalos, alola, galar, paldea, rainbow]
