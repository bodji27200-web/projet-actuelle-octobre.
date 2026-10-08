"""Régions officielles de la campagne d'après-Ligue (appelé par build_world.py).

Chaque région est décrite par :
  - une grille de zones extérieures (villes, routes, forêts, chenaux) reliées entre elles, avec leurs noms
    français officiels et les vraies tables de rencontre des jeux (versions listées) ;
  - des donjons (grottes, tours, repaires) accrochés à une zone, sur plusieurs étages ;
  - le contenu : professeur et starters, port, boutiques, repaire de la Team Rainbow Rocket, Maître de la région,
    légendaires cachés (souvent derrière un objet ou un drapeau), mini-boss à aura, quêtes annexes.

Les tables officielles sont filtrées : seules les espèces de la génération de la région (ou d'une génération
antérieure, avec leurs évolutions) sont gardées, les formes régionales remplacent les formes de Kanto (Alola,
Galar), et les niveaux sont remis à l'échelle de la progression de la campagne.
"""
import json
import random

from world_lib import (WALK, connect_door, decorate_town, free_area, interior, make_bridge_route, make_cave,
                       make_route, make_town, reachable, sprinkle)

CELL_W, CELL_H = 42, 30
SIZES = {"town": (40, 28), "port": (40, 28), "route": (32, 20), "forest": (32, 22), "sea": (34, 20), "snow": (32, 20),
         "desert": (32, 20), "lake": (32, 20)}
THEMES = {"forest": "forest", "snow": "ice", "desert": "ground", "lake": "water", "sea": "water"}


class Region:
    def __init__(self, W, rid, realm_index, spec):
        self.W = W
        self.id = rid
        self.spec = spec
        self.ox = 4000 * (realm_index + 1)
        self.oy = 0
        self.zones = {}      # clé -> carte
        self.cells = {}      # clé -> (gx, gy)
        self.rng = random.Random(sum(map(ord, rid)) * 31)
        self.gen = spec["gen"]
        self.band = spec["band"]

    # -- outils -------------------------------------------------------------------
    def mid(self, key):
        return f"{self.spec['prefix']}_{key}"

    def level_at(self, key):
        """Niveau des Pokémon sauvages d'une zone : selon son rang dans la progression."""
        order = self.spec["progress"]
        i = order.index(key) if key in order else len(order) // 2
        lo, hi = self.band
        return int(round(lo + (hi - lo) * i / max(1, len(order) - 1)))


def family_gen(P, sid):
    """Génération de la famille (celle de l'espèce de base)."""
    s = sid
    while P[s]["evolves_from"]:
        s = P[s]["evolves_from"]
    return P[s]["gen"]


def regional_form(P, sid, realm):
    tag = {"alola": "alola", "galar": "galar", "hisui": "hisui", "paldea": "paldea"}.get(realm)
    if not tag:
        return sid
    # Pikachu, Noeunoeuf, Osselait restent normaux : ce sont leurs évolutions qui changent à Alola.
    if realm == "alola" and sid in (25, 102, 104):
        return sid
    for f in P[sid].get("forms", []):
        if P[f].get("regional") == tag:
            return f
    return sid


def merge_tables(R, ENC_ALL, keys, gen, realm, level, P, extra=None, cap=18):
    """Fusionne les tables officielles de plusieurs lieux, filtre par génération, met les niveaux à l'échelle."""
    for k in keys:
        if not any(k in ENC_ALL["versions"].get(v, {}) for v in R.spec["versions"]):
            print(f"ATTENTION {R.id} : pas de table de rencontre « {k} » dans les versions {R.spec['versions']}")
    out = {}
    methods = {"grass": "grass", "water": "marsh", "old-rod": "old-rod", "good-rod": "good-rod", "super-rod": "super-rod",
               "tree": "grass", "rock": "grass"}
    for v in R.spec["versions"]:
        tables = ENC_ALL["versions"].get(v, {})
        for k in keys:
            t = tables.get(k)
            if not t:
                continue
            for meth, lst in t.items():
                dest = methods.get(meth)
                if dest is None:
                    continue
                d = out.setdefault(dest, {})
                for e in lst:
                    sid = e[0]
                    if sid not in P or sid > 1025:
                        continue
                    if family_gen(P, sid) > gen and P[sid]["gen"] > gen:
                        continue
                    d[sid] = d.get(sid, 0) + int(e[3])
    for meth, lst in (extra or {}).items():
        d = out.setdefault(meth, {})
        for sid, rate in lst:
            d[sid] = d.get(sid, 0) + rate
    res = {}
    forced = {meth: {sid for sid, _ in lst} for meth, lst in (extra or {}).items()}
    for meth, d in out.items():
        if not d:
            continue
        total = sum(d.values())
        tab = []
        # Les espèces ajoutées à la main passent en premier : elles ne doivent pas être coupées par la limite.
        for sid, rate in sorted(d.items(), key=lambda x: (x[0] not in forced.get(meth, ()), -x[1])):
            pid = regional_form(P, sid, realm)
            lvl = level + (2 if meth in ("good-rod",) else 5 if meth == "super-rod" else -6 if meth == "old-rod" else 0)
            lvl = max(2, min(100, lvl))
            tab.append([pid, max(2, lvl - 2), min(100, lvl + 2), max(1, round(100 * rate / total))])
        res[meth] = tab[:cap]
    return res


def find_spot(m, w, h, rng, avoid_doors=True, allowed="."):
    """Emplacement libre pour un bâtiment (porte en dessous comprise), qui ne coupe aucun passage."""
    spots = [(x, y) for y in range(2, m.h - h - 3) for x in range(2, m.w - w - 2)]
    rng.shuffle(spots)
    for (x, y) in spots:
        if not free_area(m, x, y, w, h + 1, allowed, margin=1):
            continue
        return x, y
    return None


def place_building(W, m, kind, w, h, to, tx, ty, label, rng, **extra):
    """Pose un bâtiment sur un emplacement libre et vérifie que toutes les sorties restent reliées."""
    start = None
    for wp in m.warps:
        start = (wp["x"], wp["y"])
        break
    path_cells = [(x, y) for y in range(m.h) for x in range(m.w) if m.g[y][x] == ","]
    if start is None and path_cells:
        start = path_cells[0]
    spots = [(x, y) for y in range(2, m.h - h - 3) for x in range(2, m.w - w - 2)]
    rng.shuffle(spots)
    base = reachable(m, start) if start is not None else set()
    stats = [0, 0]
    sea = not path_cells
    for (x, y) in spots:
        if not free_area(m, x, y, w, h + 1, ".\"fT~w:" if sea else ".\"fT:", margin=1):
            continue
        stats[0] += 1
        snapshot = [row[:] for row in m.g]
        prot = set(m.protected)
        nb = len(m.buildings)
        door = W.put_building(m, kind, x, y, w, h, to, tx, ty, label, **extra)
        if sea:
            # Îlot : la porte est reliée au ponton le plus proche par des planches.
            bridge = [(bx, by) for by in range(m.h) for bx in range(m.w) if m.g[by][bx] == "H"]
            if bridge:
                bx, by = min(bridge, key=lambda c: abs(c[0] - door[0]) + abs(c[1] - door[1]))
                m.path(door[0], door[1], bx, door[1], "H", 1)
                m.path(bx, door[1], bx, by, "H", 1)
        ok = True
        if start is not None:
            reach = reachable(m, start)
            if door not in reach:
                ok = False
            for (px, py) in path_cells:
                if (px, py) in base and (px, py) not in reach and m.g[py][px] == ",":
                    ok = False
                    break
        if ok:
            return door
        stats[1] += 1
        m.g = snapshot
        m.protected = prot
        del m.buildings[nb:]
    prot = "\n".join("".join("P" if (x, y) in m.protected else m.g[y][x] for x in range(m.w)) for y in range(m.h))
    raise RuntimeError(f"pas de place pour {kind} dans {m.id} (libres {stats[0]}, coupent un passage {stats[1]}, départ {start})\n" + prot)


def build(W, specs, ENC_ALL, NAMES_FR):
    """W : le module build_world (ses fonctions et ses dictionnaires maps, trainers, quests...)."""
    P = W.POKE
    regions = []
    for i, spec in enumerate(specs):
        R = Region(W, spec["realm"], i, spec)
        regions.append(R)
        _build_region(W, R, ENC_ALL, NAMES_FR, P)
    return regions


def zone_name(R, key, z, NAMES_FR):
    if z.get("name"):
        return z["name"]
    loc = z.get("loc")
    if loc and loc in NAMES_FR:
        return NAMES_FR[loc]["fr"]
    return key


def _build_region(W, R, ENC_ALL, NAMES_FR, P):
    spec = R.spec
    zones = spec["zones"]
    # Rectangles et liaisons.
    rects = {}
    for key, z in zones.items():
        gx, gy = z["at"]
        w, h = SIZES[z["kind"]]
        rects[key] = (R.ox + gx * CELL_W, R.oy + gy * CELL_H, w, h)
    links = []
    for a, b in spec["links"]:
        ax, ay = zones[a]["at"]
        bx, by = zones[b]["at"]
        if ay == by and abs(ax - bx) == 1:
            left, right = (a, b) if ax < bx else (b, a)
            links.append((R.mid(left), R.mid(right), rects[left][1] + 5, False))
        elif ax == bx and abs(ay - by) == 1:
            top, bot = (a, b) if ay < by else (b, a)
            links.append((R.mid(top), R.mid(bot), rects[top][0] + 5, True))
        else:
            raise ValueError(f"{R.id} : {a} et {b} ne sont pas voisins")
    for key, r in rects.items():
        W.RECT[R.mid(key)] = r
    W.LINKS.extend(links)
    # Cartes extérieures.
    for key, z in zones.items():
        mid = R.mid(key)
        name = zone_name(R, key, z, NAMES_FR)
        kind = z["kind"]
        seed = sum(map(ord, mid)) + 11
        level = R.level_at(key)
        if kind in ("town", "port"):
            m = W.town(mid, name, seed, (18, 12), z.get("music", "town"))
            m.extra["town"] = True
            m.extra["arrive"] = [18, 12]
        elif kind == "sea":
            wx, wy, w, h = W.RECT[mid]
            m = make_bridge_route(mid, name, w, h, W.exits_for(mid), seed)
            W.place(m)
            m.music = "sea"
            m.battle_bg = "water"
            W.add(m)
        else:
            m = W.route(mid, name, seed, None, grass={"forest": 0.32, "lake": 0.15}.get(kind, 0.22),
                        water=kind in ("lake",), trees={"forest": 0.26}.get(kind, 0.08), theme=THEMES.get(kind, ""))
            if kind == "desert":
                for y in range(m.h):
                    for x in range(m.w):
                        if m.g[y][x] == "." and (x, y) not in m.protected:
                            m.g[y][x] = ":"
            if kind in ("snow", "desert", "forest", "lake"):
                m.theme = THEMES[kind]
        m.realm = R.id
        R.zones[key] = m
        # Rencontres.
        tables = merge_tables(R, ENC_ALL, z.get("enc", []), R.gen, R.id, level, P, z.get("extra"))
        for meth, tab in tables.items():
            if meth == "marsh" and kind not in ("sea", "lake") and not any(c in row for row in m.g for c in "~w"):
                # Pas d'eau sur cette carte : on creuse un étang pour ces Pokémon.
                if not W.add_pond(m, seed + 3):
                    continue
            m.wild[meth] = tab
        if "rare" in z:
            m.extra["rare"] = z["rare"]
        if z.get("rate"):
            m.rate = z["rate"]
    _enrich_fishing(R, P)
    return R


ROD_LEVEL = {"old-rod": -8, "good-rod": 0, "super-rod": 6}


def _enrich_fishing(R, P):
    """Les tables de pêche officielles sont pauvres : chaque point d'eau reçoit au moins 5 espèces par canne,
    prises parmi les Pokémon aquatiques de la même région (ceux qu'on pêche ou qu'on croise sur l'eau ailleurs)."""
    pool = {}
    for m in R.zones.values():
        for meth in ("old-rod", "good-rod", "super-rod", "marsh"):
            for e in m.wild.get(meth, []):
                pool[e[0]] = pool.get(e[0], 0) + e[3]
    fish = [sid for sid, _ in sorted(pool.items(), key=lambda x: -x[1])]
    if not fish:
        return
    for key, m in R.zones.items():
        water = any(c in row for row in m.g for c in "~w")
        if not water:
            continue
        level = R.level_at(key)
        rng = random.Random(sum(map(ord, m.id)) + 99)
        for rod, dl in ROD_LEVEL.items():
            tab = m.wild.setdefault(rod, [])
            have = {e[0] for e in tab}
            cands = [f for f in fish if f not in have]
            rng.shuffle(cands)
            while len(tab) < 5 and cands:
                sid = cands.pop()
                lvl = max(2, min(100, level + dl))
                tab.append([sid, max(2, lvl - 2), min(100, lvl + 2), 8])
                have.add(sid)


def finish_region(W, R, P):
    """Contenu des zones (après apply_links : les chemins vers les sorties existent)."""
    spec = R.spec
    for key, z in spec["zones"].items():
        m = R.zones[key]
        rng = random.Random(sum(map(ord, m.id)) * 7)
        level = R.level_at(key)
        if z["kind"] in ("town", "port"):
            _town_content(W, R, key, z, m, rng, level, P)
        else:
            _route_content(W, R, key, z, m, rng, level, P)
    for d in spec.get("dungeons", []):
        _dungeon(W, R, d, P)
    # Maisons d'habitants (s'il reste de la place) : les villes paraissent habitées.
    lore = spec.get("lore", [])
    for key, z in spec["zones"].items():
        if z["kind"] not in ("town", "port"):
            continue
        m = R.zones[key]
        rng = random.Random(sum(map(ord, m.id)) * 17)
        for k in range(z.get("extra_houses", 2)):
            hid = f"maison_{m.id}_{10 + k}"
            try:
                d = place_building(W, m, "house", 4, 3, hid, 4, 6, "", rng)
            except RuntimeError:
                break
            line = lore[(sum(map(ord, m.id)) + k) % len(lore)] if lore else f"Bienvenue à {m.name} !"
            W.house_for(m, 10 + k, d, [(f"habitant_{k}", ["oldman", "girl", "lass", "youngster"][k % 4], 5, 3, "down", {"text": [line]})])
            W.maps[hid].realm = R.id
    # Décor des villes en dernier (fleurs, arbres, barrières), une fois tous les bâtiments posés.
    for key, z in spec["zones"].items():
        if z["kind"] in ("town", "port"):
            decorate_town(R.zones[key], 14, 6, 2)
            m = R.zones[key]
            if "grass" in m.wild and not _grass_patches(m, random.Random(sum(map(ord, m.id)) * 23)):
                print(f"ATTENTION {m.id} : pas de place pour les herbes hautes, rencontres d'herbe retirées")
                del m.wild["grass"]


def _grass_patches(m, rng, n=2):
    """Herbes hautes dans une ville qui a des Pokémon sauvages (jardins, prés en bordure de ville)."""
    done = 0
    for pw, ph in ((6, 3), (5, 3), (4, 3), (4, 2), (3, 2)):
        spots = [(x, y) for y in range(2, m.h - ph - 1) for x in range(2, m.w - pw - 1)]
        rng.shuffle(spots)
        for x, y in spots:
            if done >= n:
                return done
            if not free_area(m, x, y, pw, ph, ".", 0):
                continue
            if any(x - 1 <= nn["x"] <= x + pw and y - 1 <= nn["y"] <= y + ph for nn in m.npcs):
                continue
            m.rect(x, y, pw, ph, '"')
            done += 1
    return done


def _pool_of(m, P):
    pool = []
    for meth in ("grass", "marsh"):
        for e in m.wild.get(meth, []):
            sid = P[e[0]]["species"] if e[0] > 10000 else e[0]
            if not P[sid]["legendary"] and not P[sid]["mythical"]:
                pool.append(e[0])
    return pool


def _route_content(W, R, key, z, m, rng, level, P):
    pool = _pool_of(m, P)
    if pool:
        tids = []
        for j in range(z.get("trainers", 3 if z["kind"] != "sea" else 2)):
            cls = rng.choice(R.spec.get("classes", ["Topdresseur", "Montagnard", "Fillette", "Gamin", "Scout", "Pêcheur"]))
            n = rng.randint(2, 4)
            team = []
            for _ in range(n):
                lvl = level + rng.randint(0, 3)
                sid = rng.choice(pool)
                team.append((W.evolve_to(sid, lvl, max_sid=R.spec["max_species"]) if sid < 10000 else sid, lvl))
            tid = W.tr(f"{m.id}_{j}", cls, rng.choice(W.NAMES), team, rng.choice(W.INTROS), rng.choice(W.DEFEATS))
            tids.append(tid)
        W.place_route_trainers(m, tids, sum(map(ord, m.id)))
    loot = R.spec.get("loot", ["ultra-ball", "full-restore", "max-revive", "rare-candy", "pp-up", "max-elixir", "exp-candy-l"])
    # Sur les chenaux, les îlots ne sont pas tous reliés au ponton : objets seulement sur la terre ferme.
    if z["kind"] != "sea":
        W.place_items(m, [(rng.choice(loot), 1), (rng.choice(loot), 1)] + [(it, 1) for it in z.get("items", [])], sum(map(ord, m.id)) + 1)
    for n in z.get("npcs", []):
        _npc(W, m, n, rng)
    m.signs.setdefault(f"2,{m.h // 2}", m.name.upper())
    if m.get(2, m.h // 2) in ".,":
        m.g[m.h // 2][2] = "S"
    else:
        m.signs.pop(f"2,{m.h // 2}")


def _npc(W, m, n, rng):
    """PNJ libre sur une case accessible."""
    cells = [(x, y) for y in range(2, m.h - 2) for x in range(2, m.w - 2) if m.g[y][x] in ".,:" and (x, y) not in m.doors]
    rng.shuffle(cells)
    start = next(((wp["x"], wp["y"]) for wp in m.warps), None)
    for (x, y) in cells:
        if any(abs(x - o["x"]) + abs(y - o["y"]) < 3 for o in m.npcs):
            continue
        if any(b["x"] - 1 <= x <= b["x"] + b["w"] and b["y"] - 1 <= y <= b["y"] + b["h"] + 1 for b in m.buildings):
            continue
        before = reachable(m, start) if start else set()
        args = dict(n)
        nid = args.pop("id")
        look = args.pop("look", "youngster")
        d = args.pop("dir", "down")
        node = m.npc(nid, look, x, y, d, **args)
        if start:
            after = reachable(m, start)
            if not (before - {(x, y)} <= after):
                m.npcs.remove(node)
                m.protected.discard((x, y))
                continue
        return node
    raise RuntimeError(f"pas de place pour le PNJ {n['id']} dans {m.id}")


def _town_content(W, R, key, z, m, rng, level, P):
    label = m.name
    spec = R.spec
    d = place_building(W, m, "center", 5, 4, f"centre_{m.id}", 6, 6, "", rng)
    W.center_for(m, d, label)
    W.maps[f"centre_{m.id}"].realm = R.id
    stock = W.MARTS["top"] + spec.get("mart_extra", [])
    d = place_building(W, m, "mart", 4, 3, f"boutique_{m.id}", 5, 6, "", rng)
    W.mart_for(m, d, label, stock)
    W.maps[f"boutique_{m.id}"].realm = R.id
    if z.get("lab"):
        _lab(W, R, m, z["lab"], rng)
    if z.get("battle_shop"):
        _shop_building(W, R, m, "boutique_combat", "Boutique de Combat", z["battle_shop"], rng,
                       ["Vendeur : Objets tenus pour les combats sérieux ! Ils ne servent qu'en combat... mais quelle différence !"])
    if z.get("special_shop"):
        name, stock, lines = z["special_shop"]
        _shop_building(W, R, m, "boutique_speciale", name, stock, rng, lines)
    if z.get("fossil"):
        hid = f"labo_fossiles_{m.id}"
        d = place_building(W, m, "lab", 6, 4, hid, 6, 9, "", rng)
        lf = W.add(interior(hid, f"Labo Fossiles de {label}", ["WWWWWWWWWWWWW", "WBBMMqqqMMBBW", "WqqqqqqqqqqqW", "WqqqqqqqXXXqW", "WqqqqqqqqqqqW",
                                                               "WqqqqqqqqqqqW", "WBBBqqqqqBBBW", "WqqqqqqqqqqqW", "WqqqqqqqqqqqW", "WpqqqqqqqqqpW", "WWWWWWmWWWWWW"], "lab"))
        lf.region = m.id
        lf.realm = R.id
        lf.warp(6, 10, m.id, d[0], d[1], "down")
        lf.npc("chercheur_fossiles", "scientist", 9, 2, kind="fossil")
    for k, house in enumerate(z.get("houses", [])):
        hid = f"maison_{m.id}_{k}"
        d = place_building(W, m, "house", 4, 3, hid, 4, 6, "", rng)
        W.house_for(m, k, d, house)
        W.maps[hid].realm = R.id
    if z.get("port"):
        # Arrivée des bateaux : sur le chemin, près du bord bas ; le capitaine attend à côté.
        cells = [(x, y) for y in range(m.h - 3, 2, -1) for x in range(2, m.w - 2) if m.g[y][x] == "," and m.g[y][x + 1] in ".,f"]
        px, py = cells[0]
        m.extra["port"] = [px, py]
        m.npc("capitaine", "oldman", px + 1, py, "left", kind="script", script=[W.special("travel")])
        m.signs.setdefault(f"{px},{py - 1}", "PORT") if m.get(px, py - 1) == "." else None
    for n in z.get("npcs", []):
        _npc(W, m, n, rng)
    if m.g[3][2] == ".":
        m.signs["2,3"] = f"{label.upper()}"
        m.g[3][2] = "S"


def _shop_building(W, R, m, base, name, stock, rng, lines):
    sid = f"{base}_{m.id}"
    d = place_building(W, m, "mart", 4, 3, sid, 5, 6, name, rng)
    s = W.add(interior(sid, f"{name} de {m.name}", W.MART_ROWS, "mart"))
    s.region = m.id
    s.realm = R.id
    s.warp(5, 7, m.id, d[0], d[1], "down")
    s.npc("vendeur", "clerk", 2, 2, kind="shop", stock=stock)
    s.npc("conseil", "ace", 7, 5, "left", text=lines)


def _lab(W, R, m, lab, rng):
    lid = f"labo_{R.id}"
    d = place_building(W, m, "lab", 6, 4, lid, 6, 9, "", rng)
    lm = W.add(interior(lid, f"Labo du {lab['prof']}", ["WWWWWWWWWWWWW", "WBBMMqqqMMBBW", "WqqqqqqqqqqqW", "WqqqqqqqXXXqW", "WqqqqqqqqqqqW",
                                                      "WqqqqqqqqqqqW", "WBBBqqqqqBBBW", "WqqqqqqqqqqqW", "WqqqqqqqqqqqW", "WpqqqqqqqqqpW", "WWWWWWmWWWWWW"], "lab"))
    lm.region = m.id
    lm.realm = R.id
    lm.warp(6, 10, m.id, d[0], d[1], "down")
    flag = f"starter_{R.id}"
    sts = lab["starters"]
    lvl = lab.get("level", R.band[0] - 10)
    lm.npc("professeur", "scientist", 6, 2, "down", kind="script", script=[
        W.iff(W.F(f"champion_{R.id}"), [W.iff(W.F(flag + "_rest"), [W.say(f"{lab['prof']} : Tu as fait honneur à {R.spec['name']}. Merci, Maître {{player}} !")],
                                             [W.say(f"{lab['prof']} : Tu as battu le Maître de {R.spec['name']} ! Prends les deux autres, ils t'attendaient."),
                                              W.special("starter_rest", sts, lvl, flag)])],
              [W.iff(W.F(flag), [W.say(f"{lab['prof']} : Prends soin de ton Pokémon ! Reviens me voir quand tu auras battu le Maître de {R.spec['name']}.")],
                     [W.say(*lab["intro"]), W.special("starter_pick", sts, lvl, flag)])])])


def _dungeon(W, R, d, P):
    """Donjon sur plusieurs étages, accroché à une zone extérieure (entrée = grotte ou bâtiment)."""
    key = d["key"]
    attach = R.zones[d["attach"]]
    floors = d.get("floors", 2)
    theme = d.get("theme", "cave")
    building = theme in ("tower", "building", "rocket", "mansion")
    level = R.level_at(d["attach"]) + d.get("bonus", 4)
    rng = random.Random(sum(map(ord, key)) * 13)
    names = [d["name"]] if floors == 1 else [f"{d['name']} - {k + 1}" for k in range(floors)]
    fl = []
    for k in range(floors):
        fid = f"{R.mid(key)}_{k + 1}"
        fm, fc = make_cave(fid, names[k], d.get("w", 26), d.get("h", 20), sum(map(ord, fid)), theme=theme,
                           rooms=d.get("rooms", 6), building=building)
        fm.region = attach.id
        fm.realm = R.id
        fm.music = d.get("music", "dungeon" if building else "cave")
        if not building:
            fm.cave = True
        tables = merge_tables(R, W.ENC_ALL, d.get("enc", []), R.gen, R.id, level + k, P, d.get("extra"), d.get("cap", 18))
        if "grass" in tables:
            fm.wild["grass"] = tables["grass"]
        elif d.get("enc") or d.get("extra"):
            for meth in tables:
                fm.wild["grass"] = tables[meth]
                break
        fm.rate = d.get("rate", 0.09)
        floor_c0 = "q" if building else ("u" if theme == "tower" else "_")
        for (cx, cy) in fc:
            for dx in (0, 1):
                if fm.g[cy][cx + dx] == "R":
                    fm.g[cy][cx + dx] = floor_c0
        if "rare" in d and k == floors - 1:
            fm.extra["rare"] = d["rare"]
        fl.append((W.add(fm), fc))
    # Entrée.
    kind = "cave" if not building else d.get("door", "silph")
    bw, bh = d.get("door_size", (3, 2) if kind == "cave" else (5, 4))
    door = place_building(W, attach, kind, bw, bh, fl[0][0].id, 0, 0, d["name"], random.Random(sum(map(ord, key))),
                          **({"require": d["require"]} if d.get("require") else {}))
    f0, c0 = fl[0]
    ex, ey = c0[0]
    f0.g[ey + 1][ex] = "m"
    f0.warp(ex, ey + 1, attach.id, door[0], door[1], "down")
    for b in attach.buildings:
        if b["to"] == f0.id:
            b["tx"], b["ty"] = ex, ey
            if d.get("locked"):
                b["locked"] = d["locked"]
    for k in range(floors - 1):
        a, ac = fl[k]
        b, bc = fl[k + 1]
        ux, uy = ac[-1]
        a.g[uy][ux] = ">"
        dx, dy = bc[0]
        b.g[dy][dx] = "<"
        a.warp(ux, uy, b.id, dx + 1, dy, "right")
        b.warp(dx, dy, a.id, ux + 1, uy, "right")
        # Cases d'arrivée des escaliers : jamais d'objet ni de dresseur dessus.
        b.protected.add((dx + 1, dy))
        a.protected.add((ux + 1, uy))
    f0.protected.add((ex, ey))
    floor_c = "q" if building else "_"
    # Dresseurs, objets.
    pool = _pool_of(fl[0][0], P) or [P[e[0]]["species"] if e[0] > 10000 else e[0] for e in fl[0][0].wild.get("grass", [])]
    for k, (fm, fc) in enumerate(fl):
        for j in range(min(d.get("trainers", 2), len(fc) - 2)):
            if d.get("elite"):
                # Dresseurs d'élite (Abîme) : six Pokémon au build compétitif, IA maximale, niveau qui monte à chaque étage.
                el = d["elite"]
                lvl0 = min(100, el["level"] + int(k * el.get("step", 1)))
                team = [(sid, min(100, lvl0 + rng.randint(0, 2))) for sid in rng.sample(el["pool"], el.get("size", 6))]
                cls = rng.choice(el.get("classes", ["Topdresseur"]))
                tid = W.tr(f"{fm.id}_{j}", cls, rng.choice(W.NAMES), team, rng.choice(el.get("intros", W.INTROS)),
                           rng.choice(el.get("defeats", W.DEFEATS)), money=lvl0 * 300, potions=2, kind=el.get("kind", "abyss"), look=el.get("look", "abyss"))
                t = W.trainers[tid]
                t["team"] = [[s_, l_, {"exact": True}] for s_, l_ in team]
                t["build"] = "auto"
                t["ai"] = 3
                t["music"] = el.get("music", "gym")
                W.trainer_npc(fm, tid, fc[j + 1][0], fc[j + 1][1], "down", 3)
                continue
            if not pool:
                break
            team = []
            for _ in range(rng.randint(2, 4)):
                lvl = level + k + rng.randint(0, 3)
                sid = rng.choice(pool)
                team.append((W.evolve_to(sid, lvl, max_sid=R.spec["max_species"]) if sid < 10000 else sid, lvl))
            cls = d.get("trainer_class") or rng.choice(R.spec.get("classes", ["Topdresseur"]))
            tid = W.tr(f"{fm.id}_{j}", cls, rng.choice(W.NAMES), team, rng.choice(W.INTROS), rng.choice(W.DEFEATS))
            W.trainer_npc(fm, tid, fc[j + 1][0], fc[j + 1][1], "down", 3)
        loot = R.spec.get("loot", ["ultra-ball", "full-restore", "max-revive", "rare-candy"])
        W.place_items(fm, [(rng.choice(loot), 1)] + [(it, 1) for it in (d.get("items", []) if k == floors - 1 else [])],
                      sum(map(ord, fm.id)) + 5, "q_u" if building else "_")
    # Contenu du fond : légendaire, boss, chef de la Team, Maître...
    lm, lc = fl[-1]
    gx, gy = lc[-1]
    for n, c in enumerate(d.get("content", [])):
        x, y = (gx, gy) if n == 0 else lc[-2 - ((n - 1) % max(1, len(lc) - 2))]
        taken = {(o["x"], o["y"]) for o in lm.npcs} | {(w["x"], w["y"]) for w in lm.warps}
        arrivals = {(fc_[0][0] + 1, fc_[0][1]) for _, fc_ in fl} | {(ex, ey)}
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (2, 0), (-2, 0), (0, 1)):
            if (x + dx, y + dy) not in taken and (x + dx, y + dy) not in arrivals and lm.get(x + dx, y + dy) not in "#W ":
                x, y = x + dx, y + dy
                break
        if lm.g[y][x] not in WALK:
            lm.g[y][x] = "_" if not building else "q"
        c = dict(c)
        nid = c.pop("id")
        look = c.pop("look", "legend")
        dd = c.pop("dir", "down")
        lm.npc(nid, look, x, y, dd, **c)
    # Rien ne doit couper un couloir : on retire les rochers décoratifs, puis les objets au sol gênants.
    for k, (fm, fc) in enumerate(fl):
        arrive = (ex, ey) if k == 0 else (fc[0][0] + 1, fc[0][1])
        _unblock(fm, arrive, floor_c)
    return fl


def _floor_ok(fm, arrive):
    reach = reachable(fm, arrive)
    near = ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))
    for n in fm.npcs:
        if not any((n["x"] + dx, n["y"] + dy) in reach for dx, dy in near[1:]):
            return False
    for wp in fm.warps:
        if not any((wp["x"] + dx, wp["y"] + dy) in reach for dx, dy in near):
            return False
    return True


def _unblock(fm, arrive, floor_c):
    if _floor_ok(fm, arrive):
        return
    for y in range(fm.h):
        for x in range(fm.w):
            if fm.g[y][x] == "R":
                fm.g[y][x] = floor_c
    for n in [n for n in fm.npcs if n.get("kind") == "item"]:
        if _floor_ok(fm, arrive):
            return
        fm.npcs.remove(n)
        fm.protected.discard((n["x"], n["y"]))
