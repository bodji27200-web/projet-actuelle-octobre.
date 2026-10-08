"""Génère jeu/data/world.json : toute la région de Kanto (cartes, PNJ, dresseurs, histoire, quêtes).

Usage : python3 build_world.py <dossier_data>
"""
import json
import random
import sys

from world_lib import (Map, WALK, connect_door, decorate_town, interior, make_bridge_route, make_cave,
                       make_route, make_town, reachable, scatter, sprinkle)

DATA = sys.argv[1]
POKE = {int(k): v for k, v in json.load(open(f"{DATA}/pokemon.json", encoding="utf-8")).items()}
ENC = json.load(open(f"{DATA}/encounters.json", encoding="utf-8"))
maps = {}
trainers = {}
quests = {}
rng = random.Random(151)


def add(m):
    maps[m.id] = m
    return m


# ---------------------------------------------------------------------------
# Script (mini-langage interprété par le jeu)
# ---------------------------------------------------------------------------

def say(*t): return ["say", list(t)]
def iff(cond, then, els=None): return ["if", cond, then, els or []]
def setf(f): return ["set", f]
def give(item, n=1): return ["give", item, n]
def take(item, n=1): return ["take", item, n]
def mon(sid, lvl): return ["mon", sid, lvl]
def egg(sid): return ["egg", sid]
def outfit(o): return ["outfit", o]
def badge(n): return ["badge", n]
def battle(tid): return ["battle", tid]
def heal(): return ["heal"]
def hide(nid): return ["hide", nid]
def quest(q, stage): return ["quest", q, stage]
def money(n): return ["money", n]
def legend(sid, lvl, flag): return ["legend", sid, lvl, flag]
def boss(sid, lvl, flag): return ["boss", sid, lvl, flag]
def special(name, *args): return ["special", name] + list(args)
def choice(q, opts, branches): return ["choice", q, opts, branches]
def warpc(mid, x, y, d="down"): return ["warp", mid, x, y, d]
def F(f): return {"flag": f}
def NF(f): return {"not": f}
def BADGES(n): return {"badges": n}


# ---------------------------------------------------------------------------
# Dresseurs
# ---------------------------------------------------------------------------

CLASSES = {
    "Gamin": {"look": "youngster", "money": 16, "pool": [19, 16, 21, 29, 32, 23, 27, 56]},
    "Fillette": {"look": "lass", "money": 16, "pool": [35, 39, 29, 43, 16, 25, 52]},
    "Scout": {"look": "bugcatcher", "money": 10, "pool": [10, 11, 13, 14, 46, 48, 123, 127]},
    "Montagnard": {"look": "hiker", "money": 36, "pool": [74, 75, 95, 66, 67, 104, 111, 27]},
    "Pêcheur": {"look": "fisher", "money": 35, "pool": [129, 118, 119, 72, 60, 61, 98, 116]},
    "Nageuse": {"look": "girl", "money": 5, "pool": [72, 120, 116, 118, 86, 90, 54]},
    "Topdresseur": {"look": "ace", "money": 60, "pool": [17, 20, 22, 24, 26, 28, 33, 30, 36, 59, 62, 65, 68, 76, 78, 80, 82, 85, 91, 97, 99, 101, 103, 105, 110, 112, 115, 119, 121, 124, 125, 126, 127, 128, 130, 131, 134, 135, 136, 143]},
    "Sbire Rocket": {"look": "rocket", "money": 30, "pool": [19, 20, 23, 24, 41, 42, 109, 110, 88, 89, 52, 53, 96]},
    "Admin Rocket": {"look": "rocket", "money": 60, "pool": [24, 42, 110, 89, 53, 97, 20]},
    "Karatéka": {"look": "hiker", "money": 24, "pool": [56, 57, 66, 67, 68, 106, 107]},
    "Médium": {"look": "oldman", "money": 28, "pool": [92, 93, 94, 64, 79, 96]},
    "Scientifique": {"look": "scientist", "money": 48, "pool": [81, 82, 100, 101, 109, 88, 137]},
    "Canon": {"look": "lass", "money": 48, "pool": [63, 64, 79, 96, 97, 102, 122, 124]},
    "Motard": {"look": "rocket", "money": 20, "pool": [109, 110, 88, 89, 19, 20, 52, 53]},
    "Dompteur": {"look": "hiker", "money": 40, "pool": [58, 59, 77, 78, 37, 38, 111, 128]},
    "Ornithologue": {"look": "youngster", "money": 25, "pool": [16, 17, 18, 21, 22, 83, 84, 85]},
    "Jongleur": {"look": "clerk", "money": 35, "pool": [63, 64, 96, 97, 100, 101, 122]},
    "Gentleman": {"look": "oldman", "money": 70, "pool": [58, 25, 26, 128, 52, 53]},
    "Disciple": {"look": "ace", "money": 50, "pool": []},
    "Dresseur": {"look": "ace", "money": 40, "pool": [17, 20, 22, 24, 26, 28, 33, 30]},
}
TYPE_POOL = {}
for sid, p in POKE.items():
    if not p["legendary"]:
        for t in p["types"]:
            TYPE_POOL.setdefault(t, []).append(sid)


def evolve_to(sid, lvl):
    """Forme évoluée qu'un dresseur aurait à ce niveau (évolutions par niveau ; pierres vers 32+)."""
    s = sid
    for _ in range(3):
        nxt = None
        for e in POKE[s]["evos"]:
            if "level" in e and lvl >= e["level"]:
                nxt = e["to"]
            elif "item" in e and lvl >= 32 and e["item"] != "linking-cord" and nxt is None and s not in (133,):
                nxt = e["to"]
            elif e.get("item") == "linking-cord" and lvl >= 38:
                nxt = e["to"]
        if nxt is None:
            break
        s = nxt
    return s


def tr(tid, cls, name, team, intro, defeat, money=None, potions=0, pool_type=None, look=None, kind="normal", music=None):
    lvl = max(l for _, l in team)
    c = CLASSES.get(cls, CLASSES["Dresseur"])
    trainers[tid] = {"id": tid, "class": cls, "name": f"{cls} {name}".strip(), "team": [[s, l] for s, l in team],
                     "intro": intro, "defeat": defeat, "money": money or c["money"] * lvl, "potions": potions,
                     "look": look or c["look"], "pool_type": pool_type, "kind": kind, "music": music or ("gym" if kind in ("leader", "elite") else "trainer")}
    return tid


INTROS = ["Hé ! On s'est regardés dans les yeux ! Combat !", "Tu as l'air fort. Prouve-le !", "Mes Pokémon s'ennuient. Viens jouer !",
          "Je m'entraîne ici depuis des jours. À toi !", "Pas si vite ! Un combat d'abord !", "Ton équipe a l'air sympa. Voyons ça !"]
DEFEATS = ["Quoi ? J'ai perdu ?", "Tu es vraiment fort...", "Bon, je retourne m'entraîner.", "Pfff, la prochaine fois !",
           "Je n'ai rien vu venir !", "Bien joué. Tu mérites ta victoire."]
NAMES = ["Léo", "Max", "Tom", "Hugo", "Lina", "Emma", "Jade", "Noé", "Zoé", "Iris", "Paul", "Nina", "Théo", "Lou", "Sam", "Rose",
         "Enzo", "Lola", "Nathan", "Maëlle", "Axel", "Inès", "Bruno", "Clara", "Dylan", "Elsa", "Félix", "Gaby", "Ilan", "Julie"]


def random_trainer(tid, cls, lvl_lo, lvl_hi, n=None, pool=None):
    c = CLASSES[cls]
    pool = pool or c["pool"]
    n = n or rng.randint(1, 3)
    team = []
    for _ in range(n):
        lvl = rng.randint(lvl_lo, lvl_hi)
        team.append((evolve_to(rng.choice(pool), lvl), lvl))
    return tr(tid, cls, rng.choice(NAMES), team, rng.choice(INTROS), rng.choice(DEFEATS))


def trainer_npc(m, tid, x, y, d, sight=4):
    t = trainers[tid]
    return m.npc(tid, t["look"], x, y, d, kind="trainer", trainer=tid, sight=sight)


def place_route_trainers(m, specs, seed):
    """Place des dresseurs à côté du chemin, tournés vers lui."""
    r = random.Random(seed)
    spots = []
    for y in range(2, m.h - 2):
        for x in range(2, m.w - 2):
            if m.g[y][x] in '."' and (x, y) not in m.protected:
                for d, (dx, dy) in (("right", (1, 0)), ("left", (-1, 0)), ("down", (0, 1)), ("up", (0, -1))):
                    if m.get(x + dx, y + dy) == "," and m.get(x + 2 * dx, y + 2 * dy) == ",":
                        spots.append((x, y, d))
    r.shuffle(spots)
    used = []
    for tid in specs:
        for (x, y, d) in spots:
            if all(abs(x - ux) + abs(y - uy) > 5 for ux, uy in used):
                trainer_npc(m, tid, x, y, d, sight=3)
                used.append((x, y))
                break


def place_items(m, items, seed, allowed='."_'):
    r = random.Random(seed)
    cells = [(x, y) for y in range(1, m.h - 1) for x in range(1, m.w - 1) if m.g[y][x] in allowed and (x, y) not in m.protected]
    r.shuffle(cells)
    for i, (item, n) in enumerate(items):
        for (x, y) in cells:
            if all(abs(x - nn["x"]) + abs(y - nn["y"]) > 2 for nn in m.npcs) and m.get(x, y + 1) in WALK:
                m.npc(f"item_{m.id}_{i}", "ball", x, y, kind="item", item=item, count=n, flag=f"item_{m.id}_{i}")
                break


RODS = ("old-rod", "good-rod", "super-rod")


def wild(m, key, kinds=("grass", "water"), rate=None):
    src = ENC.get(key, {})
    for k in kinds:
        if k in src:
            m.wild["grass" if k == "grass" else "marsh"] = src[k]
    for k in RODS:
        if k in src:
            m.wild[k] = src[k]
    if rate:
        m.rate = rate


# ---------------------------------------------------------------------------
# Disposition de la région (coordonnées monde en cases)
# ---------------------------------------------------------------------------
RECT = {
    "bourg": (40, 190, 22, 18), "r1": (44, 160, 14, 30), "jadielle": (36, 136, 30, 24), "r22": (6, 140, 30, 12),
    "r23": (6, 90, 14, 50), "plateau": (2, 62, 22, 26), "r2": (44, 106, 14, 30), "foret": (36, 72, 30, 34),
    "argenta": (34, 46, 32, 26), "r3": (66, 52, 40, 14), "r4": (110, 40, 30, 12), "azuria": (140, 34, 30, 24),
    "r24": (150, 4, 12, 30), "r25": (162, 4, 36, 12), "r5": (150, 58, 12, 22), "safrania": (138, 80, 36, 28),
    "r6": (150, 108, 12, 20), "carmin": (138, 128, 32, 24), "r11": (170, 136, 36, 12), "r12": (206, 96, 14, 56),
    "lavanville": (200, 72, 26, 24), "r9": (170, 40, 56, 12), "r10": (226, 36, 14, 50), "r8": (174, 84, 26, 12),
    "r7": (114, 88, 24, 12), "celadopole": (78, 82, 36, 26), "r16": (66, 86, 12, 12), "r17": (66, 98, 14, 70),
    "r18": (66, 168, 44, 12), "parmanie": (110, 150, 34, 30), "r13": (180, 152, 40, 12), "r15": (144, 152, 36, 12),
    "r19": (118, 180, 12, 40), "r21": (46, 208, 12, 24), "cramois": (36, 232, 26, 22), "r20": (62, 236, 50, 12),
}
# Connexions : (carte du haut / gauche, carte du bas / droite, coordonnée monde de la 1re case, vertical ?)
LINKS = [
    ("r1", "bourg", 50, True), ("jadielle", "r1", 50, True), ("r22", "jadielle", 145, False),
    ("r23", "r22", 10, True), ("r2", "jadielle", 50, True), ("foret", "r2", 50, True), ("argenta", "foret", 50, True),
    ("argenta", "r3", 57, False), ("r4", "azuria", 45, False), ("r24", "azuria", 154, True),
    ("r24", "r25", 8, False), ("azuria", "r5", 154, True), ("r5", "safrania", 154, True), ("safrania", "r6", 154, True),
    ("r6", "carmin", 154, True), ("carmin", "r11", 141, False), ("r11", "r12", 141, False),
    ("lavanville", "r12", 212, True), ("azuria", "r9", 45, False), ("r9", "r10", 45, False),
    ("lavanville", "r10", 80, False), ("r8", "lavanville", 88, False), ("safrania", "r8", 88, False),
    ("r7", "safrania", 92, False), ("celadopole", "r7", 92, False), ("r16", "celadopole", 92, False),
    ("r16", "r17", 70, True), ("r17", "r18", 72, True), ("r18", "parmanie", 172, False),
    ("r12", "r13", 212, True), ("r15", "r13", 156, False), ("parmanie", "r15", 156, False),
    ("parmanie", "r19", 122, True), ("bourg", "r21", 50, True), ("r21", "cramois", 50, True),
    ("cramois", "r20", 240, False),
]


def exits_for(mid):
    wx, wy, w, h = RECT[mid]
    out = []
    for a, b, c, vertical in LINKS:
        if vertical:
            if a == mid:
                out.append((c - wx, h - 2))
            if b == mid:
                out.append((c - wx, 0))
        else:
            if a == mid:
                out.append((w - 2, c - wy))
            if b == mid:
                out.append((0, c - wy))
    return out


def apply_links():
    for a, b, c, vertical in LINKS:
        A, B = maps[a], maps[b]
        for k in range(2):
            if vertical:
                ax, bx = c + k - A.wx, c + k - B.wx
                for yy in (A.h - 1, A.h - 2):
                    if A.g[yy][ax] in "T#=v~":
                        A.g[yy][ax] = "H" if A.g[yy][ax] == "~" else ","
                for yy in (0, 1):
                    if B.g[yy][bx] in "T#=v~":
                        B.g[yy][bx] = "H" if B.g[yy][bx] == "~" else ","
                A.warp(ax, A.h - 1, b, bx, 1, "down")
                B.warp(bx, 0, a, ax, A.h - 2, "up")
            else:
                ay, by = c + k - A.wy, c + k - B.wy
                for xx in (A.w - 1, A.w - 2):
                    if A.g[ay][xx] in "T#=v~":
                        A.g[ay][xx] = "H" if A.g[ay][xx] == "~" else ","
                for xx in (0, 1):
                    if B.g[by][xx] in "T#=v~":
                        B.g[by][xx] = "H" if B.g[by][xx] == "~" else ","
                A.warp(A.w - 1, ay, b, 1, by, "right")
                B.warp(0, by, a, A.w - 2, ay, "left")


def place(m):
    m.wx, m.wy = RECT[m.id][0], RECT[m.id][1]
    return m


def route(mid, name, seed, enc_key=None, **kw):
    wx, wy, w, h = RECT[mid]
    m = make_route(mid, name, w, h, exits_for(mid), seed, **kw)
    place(m)
    if enc_key:
        wild(m, enc_key)
    return add(m)


def sea_route(mid, name, seed, enc_key):
    wx, wy, w, h = RECT[mid]
    m = make_bridge_route(mid, name, w, h, exits_for(mid), seed)
    place(m)
    wild(m, enc_key)
    m.music = "sea"
    m.battle_bg = "water"
    return add(m)


def town(mid, name, seed, center, music="town"):
    wx, wy, w, h = RECT[mid]
    m = make_town(mid, name, w, h, exits_for(mid), seed, center, music)
    return add(place(m))


# ---------------------------------------------------------------------------
# Intérieurs génériques
# ---------------------------------------------------------------------------
CENTER_ROWS = ["WWWWWWWWWWWWW", "WWWWWMMMWWWWW", "WqqqqqqqqqqPW", "WqqqCCCCCqqqW", "WqqqqqqqqqqqW",
               "WpqqqqqqqqqpW", "WqqqqqqqqqqqW", "WWWWWWmWWWWWW"]
MART_ROWS = ["WWWWWWWWWWW", "WBBBBBBBBBW", "WqqqqqqqqqW", "WKKKqqqqqqW", "WqqqqqqqqqW", "WqqqqqBBqqW",
             "WpqqqqqqqqW", "WWWWWmWWWWW"]
HOUSE_ROWS = [["WWWWWWWWWW", "WBBootoobW", "WoooooooBW", "WooooooooW", "WoXXoooooW", "WoXXoooooW", "WooooooooW", "WWWWmWWWWW"],
              ["WWWWWWWWWW", "WBBoooooBW", "WooooooooW", "WooooXXooW", "WooooXXooW", "WpoooooopW", "WooooooooW", "WWWWmWWWWW"],
              ["WWWWWWWWWW", "WtoooBBBBW", "WooooooooW", "WoXXooooooW"[:10], "WoXXoooooW", "WpooooooobW", "WooooooooW", "WWWWmWWWWW"]]
MARTS = {
    "base": ["poke-ball", "potion", "antidote", "paralyze-heal", "awakening", "escape-rope", "repel"],
    "mid": ["poke-ball", "great-ball", "potion", "super-potion", "antidote", "paralyze-heal", "awakening", "burn-heal",
            "ice-heal", "repel", "super-repel", "escape-rope", "net-ball", "nest-ball", "quick-ball"],
    "high": ["poke-ball", "great-ball", "ultra-ball", "super-potion", "hyper-potion", "full-heal", "revive", "ether",
             "max-repel", "escape-rope", "net-ball", "nest-ball", "repeat-ball", "timer-ball", "dusk-ball", "quick-ball",
             "luxury-ball", "heal-ball", "level-ball", "moon-ball", "heavy-ball", "fast-ball", "friend-ball", "love-ball", "dive-ball"],
    "top": ["ultra-ball", "great-ball", "max-potion", "full-restore", "full-heal", "revive", "max-revive", "max-ether",
            "max-elixir", "max-repel", "timer-ball", "dusk-ball", "quick-ball", "repeat-ball"],
}


def fit_rows(rows):
    w = max(len(r) for r in rows)
    return [(r[:-1] + "o" * (w - len(r)) + r[-1]) if len(r) < w else r for r in rows]


def center_for(t, door, label):
    cid = f"centre_{t.id}"
    m = add(interior(cid, f"Centre Pokémon de {label}", CENTER_ROWS, "center"))
    m.region = t.id
    m.heal = True
    m.warp(6, 7, t.id, door[0], door[1], "down")
    m.npc("infirmiere", "nurse", 6, 2, kind="nurse")
    m.signs["11,2"] = "@pc"
    return cid


def mart_for(t, door, label, stock):
    mid = f"boutique_{t.id}"
    m = add(interior(mid, f"Boutique de {label}", MART_ROWS, "mart"))
    m.region = t.id
    m.warp(5, 7, t.id, door[0], door[1], "down")
    m.npc("vendeur", "clerk", 2, 2, kind="shop", stock=stock)
    return mid


def house_for(t, k, door, npcs, rows=None):
    hid = f"maison_{t.id}_{k}"
    m = add(interior(hid, f"Maison", fit_rows(rows or HOUSE_ROWS[k % len(HOUSE_ROWS)])))
    m.region = t.id
    m.warp(4, 7, t.id, door[0], door[1], "down")
    for n in npcs:
        nid, look, x, y, d, extra = n
        m.npc(nid, look, x, y, d, **extra)
    return hid


def set_entry(m, to, x, y):
    for b in m.buildings:
        if b["to"] == to:
            b["tx"], b["ty"] = x, y


def put_building(t, kind, x, y, w, h, to, tx, ty, label="", **extra):
    door = t.building(kind, x, y, w, h, to, tx, ty, label)
    t.buildings[-1].update(extra)
    connect_door(t, door)
    return door


def gym(t, n, typ, leader, label, team, tm, badge_name, quote, post, trainer_specs, theme):
    """Arène : 2-3 dresseurs puis le Champion tout en haut."""
    gid = f"arene_{t.id}"
    rows = ["WWWWWWWWWWWWW"] + ["W" + "q" * 11 + "W" for _ in range(13)] + ["WWWWWWmWWWWWW"]
    m = add(interior(gid, f"Arène de {label}", rows, "gym"))
    m.region = t.id
    m.theme = theme
    for x in (1, 2, 10, 11):
        for y in range(3, 12, 3):
            m.g[y][x] = "O"
    m.g[13][4] = "O"
    m.g[13][8] = "O"
    lid = tr(f"leader_{n}", "Champion", leader, team,
             quote, "Bravo... Tu as gagné le Badge %s !" % badge_name, money=team[-1][1] * 100, potions=2,
             pool_type=typ, look=f"leader{n}", kind="leader")
    leader_npc = m.npc(lid, f"leader{n}", 6, 2, "down", kind="script", script=[
        iff(F(f"badge_{n}"), [say(*post)], [
            say(quote),
            battle(lid),
            badge(n),
            say(f"Voici le Badge {badge_name} ! Il prouve ta valeur.", f"Prends aussi cette CT !"),
            give(tm),
            say(*post),
        ])])
    leader_npc["trainer"] = lid
    for i, (cls, mons) in enumerate(trainer_specs):
        tid = tr(f"gym{n}_{i}", cls, rng.choice(NAMES), mons, rng.choice(INTROS), rng.choice(DEFEATS), pool_type=typ)
        x = [4, 8, 6][i % 3]
        y = [10, 7, 5][i % 3]
        trainer_npc(m, tid, x, y, ["left", "right", "down"][i % 3], sight=3)
    m.npc("guide", "clerk", 4, 12, "up", text=[f"Yo, futur Champion ! L'Arène de {label} utilise des Pokémon de type {typ_fr(typ)}.",
                                              "Prépare des Pokémon efficaces contre eux. Tu peux le faire !"])
    return gid


TYPE_FR = {"rock": "Roche", "water": "Eau", "electric": "Électrik", "grass": "Plante", "poison": "Poison",
           "psychic": "Psy", "fire": "Feu", "ground": "Sol", "ice": "Glace", "fighting": "Combat", "ghost": "Spectre", "dragon": "Dragon"}


def typ_fr(t):
    return TYPE_FR.get(t, t)


# ===========================================================================
# BOURG PALETTE
# ===========================================================================
t = town("bourg", "Bourg Palette", 1, (10, 8))
t.rect(1, 14, 20, 3, "~", True)
t.path(10, 8, 10, 17, "H")
t.signs["3,8"] = "BOURG PALETTE\nUne ville d'un blanc pur où commence chaque aventure."
d_home = put_building(t, "house", 3, 2, 4, 3, "maison", 4, 6)
d_rival = put_building(t, "house", 14, 2, 4, 3, "maison_rival", 4, 6)
d_lab = put_building(t, "lab", 12, 9, 6, 4, "labo", 6, 9)
t.signs["11,12"] = "LABO POKéMON DU PROF. CHEN"
t.npc("fille_bp", "girl", 6, 10, text=["La technologie, c'est incroyable !", "On peut stocker des Pokémon dans un PC et les retirer ailleurs !"])
t.npc("marin_bp", "hiker", 13, 13, "left", kind="script", script=[
    iff(BADGES(7), [say("Le ponton de la Route 21 mène à Cramois'Île, au sud. Bon vent !")],
        [say("Au sud, le ponton de la Route 21 mène à Cramois'Île.", "Mais la mer est agitée... Reviens quand tu seras plus expérimenté !")])])
t.npc("blocage_r21", "hiker", 10, 15, "down", kind="script", ghost=True, hide_if=BADGES(6),
      script=[say("Désolé, le ponton est en travaux. Reviens quand tu auras au moins 6 Badges !")])
t.npc("blocage_r21b", "hiker", 11, 15, "down", kind="script", ghost=True, hide_if=BADGES(6),
      script=[say("Désolé, le ponton est en travaux. Reviens quand tu auras au moins 6 Badges !")])
decorate_town(t, 8, 2, 1)
t.music = "pallet"

m = add(interior("maison", "Maison", fit_rows(["WWWWWWWWWW", "WBBootoPbW", "WoooooooBW", "WooooooooW", "WoXXoooooW", "WoXXoooooW", "WooooooooW", "WWWWmWWWWW"])))
m.region = "bourg"
m.warp(4, 7, "bourg", d_home[0], d_home[1], "down")
m.npc("maman", "mom", 6, 4, "left", kind="mom")
m.signs = {"7,1": "@pc", "8,1": "@wardrobe", "5,1": "Une émission sur les Pokémon passe à la télé. Quatre garçons marchent sur une voie ferrée..."}

m = add(interior("maison_rival", "Maison de Régis", fit_rows(HOUSE_ROWS[1])))
m.region = "bourg"
m.warp(4, 7, "bourg", d_rival[0], d_rival[1], "down")
m.npc("soeur", "lass", 4, 3, "down", kind="sister")

m = add(interior("labo", "Labo du Prof. Chen", ["WWWWWWWWWWWWW", "WBBMMqqqMMBBW", "WqqqqqqqqqqqW", "WqqqqqqqXXXqW", "WqqqqqqqqqqqW",
                                                 "WqqqqqqqqqqqW", "WBBBqqqqqBBBW", "WqqqqqqqqqqqW", "WqqqqqqqqqqqW", "WpqqqqqqqqqpW", "WWWWWWmWWWWWW"], "lab"))
m.region = "bourg"
m.warp(6, 10, "bourg", d_lab[0], d_lab[1], "down")
m.npc("chen", "chen", 9, 2, kind="chen")
m.npc("rival", "rival", 6, 4, "up", kind="rival_lab")
for i, sid in enumerate((1, 4, 7)):
    m.npc(f"ball{sid}", "ball", 8 + i, 3, kind="starter", species=sid)
m.npc("assistant_multi", "scientist", 10, 8, "left", kind="script", script=[
    iff(F("exp_share_got"), [say("Le Multi Exp partage l'expérience avec toute l'équipe. Active-le ou coupe-le depuis le Sac !")],
        [iff(F("has_starter"), [say("Tiens, prends ce Multi Exp ! Tous tes Pokémon gagneront de l'expérience, même ceux qui ne combattent pas.",
                                    "Tu peux l'activer ou le désactiver depuis le Sac, dans les OBJETS RARES."),
                                give("exp-share"), setf("exp_share_got"), setf("exp_share_on")],
             [say("Choisis d'abord ton Pokémon !")])])])
m.npc("assistant", "scientist", 2, 8, "right", kind="script", script=[
    iff({"caught": 10}, [iff(F("dex_10"), [say("Continue à remplir le Pokédex ! À 30 Pokémon capturés, j'aurai une autre récompense.")],
                             [say("10 Pokémon capturés ! Excellent ! Tiens, pour ta collection."), give("great-ball", 10), setf("dex_10")])],
        [say("Le Pokédex enregistre automatiquement chaque Pokémon que tu rencontres !", "Capture 10 Pokémon et reviens me voir !")]),
    iff({"caught": 30}, [iff(NF("dex_30"), [say("30 Pokémon ! Voici une tenue spéciale « Chercheur » !"), outfit("chercheur"), setf("dex_30")])]),
    iff({"caught": 60}, [iff(NF("dex_60"), [say("60 Pokémon ! Prends ces Super Bonbons !"), give("rare-candy", 5), setf("dex_60")])]),
    iff({"caught": 100}, [iff(NF("dex_100"), [say("100 Pokémon ! Incroyable ! Prends cette Master Ball."), give("master-ball"), setf("dex_100")])]),
])

# ===========================================================================
# ROUTES DU DÉBUT
# ===========================================================================
r = route("r1", "Route 1", 11, "kanto-route-1", grass=0.25, ledges=2)
r.signs[f"3,{r.h - 5}"] = "ROUTE 1\nBOURG PALETTE - JADIELLE"
r.npc("vendeur_r1", "clerk", 3, 14, "right", kind="gift", item="potion", count=2, flag="gift_route1",
      text=["Bonjour ! Je travaille à la Boutique Pokémon de Jadielle.", "Tiens, prends ces échantillons gratuits !"])

t = town("jadielle", "Jadielle", 2, (15, 11))
d = put_building(t, "center", 5, 2, 5, 4, "centre_jadielle", 6, 6)
center_for(t, d, "Jadielle")
d = put_building(t, "mart", 19, 2, 4, 3, "boutique_jadielle", 5, 6)
mart_for(t, d, "Jadielle", MARTS["base"])
maps["boutique_jadielle"].npcs[0]["kind"] = "script"
maps["boutique_jadielle"].npcs[0]["script"] = [
    iff(NF("parcel_got"), [say("Hé ! Tu viens de Bourg Palette ? Le Prof. Chen a commandé un colis.", "Tu peux le lui apporter ?"),
                           give("oaks-parcel"), setf("parcel_got"), quest("main", 2)],
        [special("shop", MARTS["base"])])]
d = put_building(t, "gym", 3, 14, 6, 5, "arene_jadielle", 6, 13, "Arène", require=BADGES(7),
                 locked="L'Arène de Jadielle est fermée. Son Champion est absent...")
d = put_building(t, "house", 20, 13, 4, 3, "maison_jadielle_0", 4, 6)
house_for(t, 0, d, [("conseil", "scientist", 6, 3, "down", {"kind": "info"})])
t.signs["13,19"] = "JADIELLE\nLa ville éternellement verte."
t.npc("vieux", "oldman", 22, 9, "left", kind="oldman")
t.npc("gamin_j", "youngster", 25, 18, "down", text=["Les hautes herbes sont pleines de Pokémon sauvages.", "Plus tu vas au nord, plus ils sont forts !"])
t.npc("lila", "girl", 12, 20, "right", kind="script", script=[
    say("Je suis Lila. Ma sœur Lou et moi, on combat toujours à deux !",
        "Si tu joues en ligne avec un ami et que vous êtes dans le même GROUPE, tous vos combats deviennent des combats 2 contre 2 !",
        "Deux Pokémon sauvages apparaissent, et chaque Dresseur appelle un camarade. Pratique pour s'entraider !")])
decorate_town(t, 12, 3, 2)

r = route("r22", "Route 22", 22, "kanto-route-22", grass=0.22, water=True)
r.signs["4,3"] = "ROUTE 22\nPORTE DE LA LIGUE POKéMON (8 Badges requis)"
r.npc("rival22", "rival", 20, 6, "right", kind="rival22")
r.npc("rival22b", "rival", 18, 6, "right", kind="rival_final", hide_if=NF("badge_8"))

r = route("r2", "Route 2", 2, "kanto-route-2/south-towards-viridian-city", grass=0.25, ledges=1)
random_trainer("r2_a", "Gamin", 5, 7, 2)
random_trainer("r2_b", "Fillette", 6, 7, 2)
place_route_trainers(r, ["r2_a", "r2_b"], 2)
r.npc("fillette_r2", "girl", 3, 4, "right", kind="script", script=[
    iff(F("lost_rattata_done"), [say("Merci encore d'avoir retrouvé mon Rattata !")],
        [iff({"party_has": 19}, [say("Oh ! Tu as un Rattata ! Le mien s'est perdu dans les hautes herbes...", "Merci de me l'avoir montré, ça me rassure. Tiens !"),
                                 give("potion", 3), outfit("casquette_bleue"), setf("lost_rattata_done"), quest("rattata", 2)],
             [say("Mon Rattata s'est enfui... Si tu en captures un, montre-le-moi pour me rassurer !"), quest("rattata", 1)])])])
place_items(r, [("potion", 1), ("poke-ball", 2)], 21)

# Forêt de Jade (carte extérieure, sombre)
wx, wy, w, h = RECT["foret"]
f = Map("foret", "Forêt de Jade", w, h, fill="T")
f.theme = "forest"
f.music = "forest"
f.battle_bg = "forest"
fr = random.Random(5)
for (x0, y0, x1, y1) in [(14, 0, 15, 8), (14, 8, 26, 9), (25, 9, 26, 20), (5, 19, 26, 20), (5, 20, 6, 30), (5, 29, 15, 30), (14, 30, 15, 33)]:
    f.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, ",")
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            f.protected.add((xx, yy))
for (x, y, ww, hh) in [(3, 2, 11, 6), (16, 2, 10, 5), (10, 10, 15, 8), (7, 21, 15, 7), (22, 21, 6, 8)]:
    f.rect(x, y, ww, hh, '"')
sprinkle(f, fr, "f", 6, '"')
f.wx, f.wy = wx, wy
wild(f, "viridian-forest", rate=0.1)
add(f)
for tid, cls, n, lo, hi in [("foret_a", "Scout", 2, 6, 8), ("foret_b", "Scout", 3, 7, 9), ("foret_c", "Scout", 2, 8, 9), ("foret_d", "Fillette", 2, 8, 10)]:
    random_trainer(tid, cls, lo, hi, n)
trainer_npc(f, "foret_a", 13, 4, "right", 3)
trainer_npc(f, "foret_b", 24, 12, "left", 3)
trainer_npc(f, "foret_c", 18, 17, "down", 3)
trainer_npc(f, "foret_d", 7, 26, "right", 3)
place_items(f, [("antidote", 2), ("poke-ball", 3), ("potion", 2), ("leaf-stone", 1)], 9, '"')

# ===========================================================================
# ARGENTA (Pierre)
# ===========================================================================
t = town("argenta", "Argenta", 3, (16, 11))
d = put_building(t, "center", 4, 3, 5, 4, "centre_argenta", 6, 6)
center_for(t, d, "Argenta")
d = put_building(t, "mart", 22, 3, 4, 3, "boutique_argenta", 5, 6)
mart_for(t, d, "Argenta", MARTS["base"] + ["great-ball"])
d = put_building(t, "gym", 13, 14, 6, 5, "arene_argenta", 6, 13)
gym(t, 1, "rock", "Pierre", "Argenta", [(74, 12), (95, 14)], "tm39", "Roche",
    "Je suis Pierre, le Champion d'Argenta. Ma volonté est aussi dure que la roche ! Montre-moi la tienne !",
    ["Le Badge Roche prouve ta force. Continue vers l'est, par le Mont Sélénite.", "La Team Rocket y aurait été vue..."],
    [("Campeur", [(50, 10), (27, 11)])], "rock")
d = put_building(t, "house", 22, 15, 4, 3, "maison_argenta_0", 4, 6)
house_for(t, 0, d, [("musee", "scientist", 5, 3, "down", {"text": ["Le Musée d'Argenta expose des fossiles de Pokémon disparus.", "On raconte que le Mont Sélénite en cache encore..."]})])
t.npc("garde_argenta", "youngster", 30, 11, "left", kind="script", ghost=True, hide_if=F("badge_1"),
      script=[say("Tu veux aller à l'est ? Le Champion Pierre veut d'abord voir ce que tu vaux !", "Va à l'Arène, au sud de la ville.")])
t.npc("garde_argenta2", "youngster", 30, 12, "left", kind="script", ghost=True, hide_if=F("badge_1"),
      script=[say("Le Champion Pierre veut d'abord voir ce que tu vaux !")])
t.signs["14,9"] = "ARGENTA\nUne ville grise comme la pierre."
decorate_town(t, 6, 4, 1)
CLASSES["Campeur"] = {"look": "youngster", "money": 20, "pool": [74, 27, 50, 95, 104]}

# ===========================================================================
# ROUTE 3, MONT SÉLÉNITE, ROUTE 4
# ===========================================================================
r = route("r3", "Route 3", 3, "kanto-route-3", grass=0.18, trees=0.1)
for i, (cls, lo, hi, n) in enumerate([("Gamin", 9, 11, 2), ("Fillette", 9, 10, 3), ("Scout", 9, 11, 3), ("Gamin", 10, 12, 2), ("Fillette", 10, 12, 2)]):
    random_trainer(f"r3_{i}", cls, lo, hi, n)
place_route_trainers(r, [f"r3_{i}" for i in range(5)], 33)
door_mm_in = put_building(r, "cave", r.w - 7, 2, 3, 2, "mtmoon_1", 0, 0)
r.npc("pokecenter_r3", "nurse", r.w - 10, 5, "down", kind="nurse")

mm1, c1 = make_cave("mtmoon_1", "Mont Sélénite", 30, 22, 31, rooms=6)
mm2, c2 = make_cave("mtmoon_2", "Mont Sélénite - Sous-sol", 30, 22, 32, rooms=6)
for mm in (mm1, mm2):
    mm.region = "r3"
    add(mm)
wild(mm1, "mt-moon/1f", rate=0.08)
wild(mm2, "mt-moon/b2f", rate=0.08)
# entrée
ex, ey = c1[0]
mm1.g[ey + 1][ex] = "m"
mm1.warp(ex, ey + 1, "r3", door_mm_in[0], door_mm_in[1], "down")
set_entry(r, "mtmoon_1", ex, ey)
# vers le sous-sol
sx, sy = c1[-1]
mm1.g[sy][sx] = ">"
bx, by = c2[0]
mm2.g[by][bx] = "<"
mm1.warp(sx, sy, "mtmoon_2", bx + 1, by, "right")
mm2.warp(bx, by, "mtmoon_1", sx + 1, sy, "right")
for i, (cls, lo, hi, n) in enumerate([("Montagnard", 10, 12, 2), ("Sbire Rocket", 11, 13, 2), ("Scout", 11, 12, 3), ("Sbire Rocket", 12, 13, 2)]):
    random_trainer(f"mm_{i}", cls, lo, hi, n)
trainer_npc(mm1, "mm_0", c1[2][0], c1[2][1], "down", 3)
trainer_npc(mm1, "mm_1", c1[3][0], c1[3][1], "left", 3)
trainer_npc(mm2, "mm_2", c2[1][0], c2[1][1], "right", 3)
trainer_npc(mm2, "mm_3", c2[2][0], c2[2][1], "down", 3)
place_items(mm1, [("moon-stone", 1), ("rare-candy", 1), ("escape-rope", 1)], 1)
place_items(mm2, [("moon-stone", 1), ("ether", 1), ("tm09", 1)], 2)
tr("corbeau_1", "Admin Rocket", "Corbeau", [(41, 12), (23, 13), (19, 13), (109, 14)],
   "Ha ! Un gamin ! Je suis Corbeau, Admin de la Team Rocket. Ces fossiles valent une fortune, et tu ne les auras pas !",
   "Tch... Tu es plus coriace que prévu. On se reverra !", potions=1)
ox, oy = c2[-1]
mm2.npc("corbeau_mm", "rocket", ox, oy - 1, "down", kind="script", script=[
    iff(F("mtmoon_boss"), [say("...")], [
        say(trainers["corbeau_1"]["intro"]), battle("corbeau_1"), setf("mtmoon_boss"), quest("main", 5),
        say("Corbeau : Bah ! Prends un fossile si tu veux. Le Boss a d'autres projets..."), hide("corbeau_mm")])],
    hide_if=F("mtmoon_boss"))
mm2.npc("fossile_nautile", "ball", ox - 1, oy, kind="script", hide_if=F("fossil_chosen"), script=[
    iff(F("mtmoon_boss"), [choice("C'est le Nautile, un fossile de Pokémon. Le prendre ?", ["OUI", "NON"], [[give("helix-fossil"), setf("fossil_chosen"), say("Tu obtiens le Nautile !"), hide("fossile_nautile"), hide("fossile_dome")], []])],
        [say("Un fossile. L'Admin Rocket le surveille...")])])
mm2.npc("fossile_dome", "ball", ox + 1, oy, kind="script", hide_if=F("fossil_chosen"), script=[
    iff(F("mtmoon_boss"), [choice("C'est le Fossile Dôme. Le prendre ?", ["OUI", "NON"], [[give("dome-fossil"), setf("fossil_chosen"), say("Tu obtiens le Fossile Dôme !"), hide("fossile_nautile"), hide("fossile_dome")], []])],
        [say("Un fossile. L'Admin Rocket le surveille...")])])
# sortie vers la route 4
ex2, ey2 = c2[-1]
mm2.g[ey2 + 1][ex2] = "m"
r4 = route("r4", "Route 4", 4, "kanto-route-4", grass=0.2, ledges=1)
door_mm_out = put_building(r4, "cave", 3, 2, 3, 2, "mtmoon_2", ex2, ey2)
mm2.warp(ex2, ey2 + 1, "r4", door_mm_out[0], door_mm_out[1], "down")
random_trainer("r4_0", "Fillette", 13, 15, 2)
place_route_trainers(r4, ["r4_0"], 4)
# Antre (donjon coop optionnel) sur la route 4
door_antre1 = put_building(r4, "cave", r4.w - 8, r4.h - 5, 3, 2, "antre_1", 0, 0)

# ===========================================================================
# AZURIA (Ondine), PONT PÉPITE, LÉO
# ===========================================================================
t = town("azuria", "Azuria", 4, (14, 11))
d = put_building(t, "center", 4, 3, 5, 4, "centre_azuria", 6, 6)
center_for(t, d, "Azuria")
d = put_building(t, "mart", 21, 3, 4, 3, "boutique_azuria", 5, 6)
mart_for(t, d, "Azuria", MARTS["mid"])
d = put_building(t, "gym", 19, 14, 6, 5, "arene_azuria", 6, 13)
gym(t, 2, "water", "Ondine", "Azuria", [(120, 18), (121, 21)], "tm03", "Cascade",
    "Je suis Ondine ! Ma politique ? Attaquer à fond avec des Pokémon Eau !",
    ["Le Badge Cascade est à toi. Va voir Léo, au nord, par le Pont Pépite.", "Ensuite, le Major Bob t'attend à Carmin-sur-Mer, au sud."],
    [("Nageuse", [(118, 16), (118, 16)]), ("Nageuse", [(120, 17)])], "water")
d = put_building(t, "house", 4, 15, 4, 3, "maison_azuria_0", 4, 6)
house_for(t, 0, d, [("velo", "clerk", 5, 3, "down", {"text": ["Une Bicyclette ? Le président du Club des Fans de Carmin en offre une à ceux qui l'écoutent parler de ses Pokémon !"]})])
t.npc("garde_grotte", "hiker", 2, 9, "right", kind="script", ghost=True, hide_if=F("champion"),
      script=[say("La Grotte Azurée, au nord-ouest, abrite des Pokémon d'une puissance incroyable.", "Seul le Maître de la Ligue a le droit d'y entrer.")])
decorate_town(t, 8, 3, 1)

r = route("r24", "Route 24 - Pont Pépite", 24, "kanto-route-24", grass=0.15, water=True)
for i in range(5):
    tr(f"pont_{i}", ["Gamin", "Fillette", "Scout", "Fillette", "Topdresseur"][i], NAMES[i + 5],
       [(evolve_to(s, 14 + i), 14 + i) for s in rng.sample(CLASSES[["Gamin", "Fillette", "Scout", "Fillette", "Topdresseur"][i]]["pool"], 2)],
       f"Défi du Pont Pépite ! Je suis le dresseur n°{i + 1} !", "Aïe ! Passe au suivant !")
for i in range(5):
    trainer_npc(r, f"pont_{i}", 7 if i % 2 else 4, r.h - 6 - i * 4, "right" if i % 2 == 0 else "left", 2)
r.npc("recruteur", "rocket", 6, 5, "down", kind="script", script=[
    iff(F("pont_done"), [say("Tch... Va-t'en.")], [
        iff({"all_flags": ["tr_pont_0", "tr_pont_1", "tr_pont_2", "tr_pont_3", "tr_pont_4"]}, [
            say("Bravo ! Tu as relevé le Défi du Pont Pépite ! Voici ta récompense : une Pépite !"), give("nugget"),
            say("Et... entre nous, ça te dirait de rejoindre la Team Rocket ? Non ? Alors je vais te convaincre !"),
            battle(tr("recruteur_r", "Sbire Rocket", "Recruteur", [(23, 15), (41, 16)], "Rejoins-nous ou disparais !", "D'accord, d'accord ! Pas de Team Rocket pour toi !")),
            outfit("pont_dore"), setf("pont_done"), say("Tu obtiens la tenue « Pont Doré » en souvenir !")],
            [say("Bats les 5 Dresseurs du Pont Pépite et je t'offrirai un prix !")])])])
r.npc("garde_grotte_az", "hiker", 2, r.h - 3, "right", text=["La Grotte Azurée est au bout de ce chemin... Réservée au Maître de la Ligue."])
door_cave_az = put_building(r, "cave", 2, r.h - 8, 3, 2, "grotte_az_1", 0, 0, require=F("champion"),
                            locked="Un garde bloque l'entrée : « Seul le Maître de la Ligue peut entrer. »")

r = route("r25", "Route 25", 25, "kanto-route-25", grass=0.18, water=True)
for i in range(3):
    random_trainer(f"r25_{i}", ["Montagnard", "Gamin", "Fillette"][i], 13, 16, 2)
place_route_trainers(r, [f"r25_{i}" for i in range(3)], 25)
d = put_building(r, "house", r.w - 7, 3, 4, 3, "chalet_leo", 4, 6)
m = add(interior("chalet_leo", "Chalet de Léo", fit_rows(["WWWWWWWWWW", "WMMMooMMMW", "WooooooooW", "WooooooooW", "WoXXoooooW", "WoXXoooooW", "WpoooooopW", "WWWWmWWWWW"])))
m.region = "r25"
m.warp(4, 7, "r25", d[0], d[1], "down")
m.npc("leo", "ball", 6, 3, kind="script", script=[
    iff(F("leo_done"), [say("Léo : Merci encore ! Comment va l'Œuf que je t'ai donné ? Il faut marcher beaucoup pour qu'il éclose !")], [
        say("??? : Hé ! Par ici ! C'est moi, Léo ! Je ressemble à un Pokémon, hein ?",
            "J'ai raté une expérience de téléporteur et j'ai fusionné avec un Pokémon !",
            "Active la machine de droite pendant que j'entre dans celle de gauche, s'il te plaît !"),
        ["flash"],
        say("Léo : Ouf ! Me revoilà humain ! Merci, tu m'as sauvé !",
            "Tiens, prends cet Œuf que j'ai trouvé. Je me demande ce qui en sortira !"),
        special("gift_egg", [133, 147, 113, 131, 123, 127]),
        setf("leo_done"), quest("main", 7),
        say("Léo : Et file à Carmin-sur-Mer ! Le Souterrain de la Route 5 te permet de contourner Safrania.")])])

# ===========================================================================
# ROUTE 5 (Pension, Souterrain), SAFRANIA (fermée au début), ROUTE 6
# ===========================================================================
r = route("r5", "Route 5", 5, "kanto-route-5", grass=0.2)
d = put_building(r, "house", 1, 4, 4, 3, "pension", 4, 6, "Pension")
m = add(interior("pension", "Pension Pokémon", fit_rows(["WWWWWWWWWW", "WBBoooooBW", "WooooooooW", "WooooooooW", "WoXXoooooW", "WoXXoooooW", "WpoooooopW", "WWWWmWWWWW"])))
m.region = "r5"
m.warp(4, 7, "r5", d[0], d[1], "down")
m.npc("mamie_rosa", "oldman", 4, 3, kind="daycare")
m.npc("papi_rosa", "oldman", 7, 4, "left", text=["Mamie Rosa garde les Pokémon et les entraîne pendant que tu marches.",
                                                 "Si deux Pokémon s'entendent bien, on trouve parfois un Œuf ! Reviens souvent voir."])
d = put_building(r, "gate", r.w - 6, 8, 4, 3, "souterrain_ns", 1, 1, "Souterrain")
gr = add(interior("souterrain_ns", "Souterrain", ["WWWWWWWWWWWWWWWWWWWWWW", "Wm" + "q" * 18 + "mW", "WWWWWWWWWWWWWWWWWWWWWW"], "indoor"))
gr.region = "r5"
r.npc("garde_safrania_n", "youngster", 6, r.h - 3, "down", kind="script", ghost=True, hide_if=F("safrania_open"),
      script=[say("Safrania est fermée ! La Team Rocket a pris la ville en otage...", "Passe par le Souterrain, à l'est de la route.")])
r.npc("garde_safrania_n2", "youngster", 7, r.h - 3, "down", kind="script", ghost=True, hide_if=F("safrania_open"),
      script=[say("Personne n'entre à Safrania pour l'instant.")])
d5 = d
r6 = route("r6", "Route 6", 6, "kanto-route-6", grass=0.2, water=True)
d6 = put_building(r6, "gate", r6.w - 6, 6, 4, 3, "souterrain_ns", 19, 1, "Souterrain")
gr.warp(1, 1, "r5", d5[0], d5[1], "down")
gr.warp(20, 1, "r6", d6[0], d6[1], "down")
set_entry(r, "souterrain_ns", 2, 1)
set_entry(r6, "souterrain_ns", 19, 1)
r6.npc("garde_safrania_s", "youngster", 6, 2, "up", kind="script", ghost=True, hide_if=F("safrania_open"),
       script=[say("Safrania est fermée ! Désolé.")])
r6.npc("garde_safrania_s2", "youngster", 7, 2, "up", kind="script", ghost=True, hide_if=F("safrania_open"),
       script=[say("Safrania est fermée ! Désolé.")])
for i in range(3):
    random_trainer(f"r6_{i}", ["Scout", "Fillette", "Gamin"][i], 16, 20, 2)
place_route_trainers(r6, [f"r6_{i}" for i in range(3)], 6)

# ===========================================================================
# CARMIN-SUR-MER (Major Bob)
# ===========================================================================
t = town("carmin", "Carmin-sur-Mer", 6, (16, 11))
t.rect(1, t.h - 5, t.w - 2, 4, "~", True)
d = put_building(t, "center", 4, 3, 5, 4, "centre_carmin", 6, 6)
center_for(t, d, "Carmin-sur-Mer")
d = put_building(t, "mart", 22, 3, 4, 3, "boutique_carmin", 5, 6)
mart_for(t, d, "Carmin-sur-Mer", MARTS["mid"])
d = put_building(t, "gym", 20, 12, 6, 5, "arene_carmin", 6, 13)
gym(t, 3, "electric", "Bob", "Carmin-sur-Mer", [(100, 21), (25, 18), (26, 24)], "tm34", "Foudre",
    "Hé, gamin ! Moi, c'est le Major Bob ! Mes Pokémon Électrik m'ont sauvé à la guerre. Ils vont te griller !",
    ["Le Badge Foudre ! Tu as du cran, gamin.", "Va à l'est, par la Route 11 puis la Route 12 jusqu'à Lavanville."],
    [("Gentleman", [(25, 21), (25, 21)]), ("Scientifique", [(81, 20), (100, 21)])], "electric")
trainers["leader_3"]["name"] = "Major Bob"
d = put_building(t, "house", 4, 13, 4, 3, "maison_carmin_0", 4, 6)
house_for(t, 0, d, [("club", "oldman", 5, 3, "down", {"kind": "script", "script": [
    iff(F("bike"), [say("Président : Ma Ponyta est la plus belle du monde, tu ne trouves pas ?")], [
        say("Président : Bienvenue au Club des Fans de Pokémon ! Écoute-moi parler de ma Ponyta...",
            "Elle galope si vite ! Sa crinière de feu est si belle ! ... Et patati et patata...",
            "Tu m'as écouté jusqu'au bout ! Tiens, prends cette Bicyclette !"),
        give("bicycle"), setf("bike"), say("Appuie sur la touche VÉLO (V par défaut) pour l'enfourcher !")])]})])
t.npc("pecheur_carmin", "fisher", 6, 18, "down", kind="script", script=[
    iff(F("canne_got"), [say("Maître Pêcheur : Face à l'eau, appuie sur A pour pêcher !",
                             "Mes frères pêchent à Parmanie et sur la Route 12. Ils ont de meilleures cannes que moi !")],
        [say("Maître Pêcheur : Salut ! Je suis le Maître Pêcheur de Carmin ! La pêche, c'est toute ma vie !",
             "Tu as l'air de t'ennuyer... Tiens, prends cette Canne et essaie !"),
         give("old-rod"), setf("canne_got"), quest("peche", 1),
         say("Mets-toi face à l'eau et appuie sur A. Tu peux aussi l'utiliser depuis le Sac, dans les OBJETS RARES.",
             "Avec cette vieille Canne, ça mord souvent... mais surtout des Magicarpe !")])])
decorate_town(t, 6, 2, 1)

r = route("r11", "Route 11", 11, "kanto-route-11", grass=0.22)
for i in range(4):
    random_trainer(f"r11_{i}", ["Gamin", "Jongleur", "Ornithologue", "Scientifique"][i], 18, 22, 2)
place_route_trainers(r, [f"r11_{i}" for i in range(4)], 11)
d_dig = put_building(r, "cave", 3, 2, 3, 2, "cave_taupiqueur", 0, 0)

r = route("r12", "Route 12", 12, "kanto-route-12", grass=0.15, water=True)
for i in range(4):
    random_trainer(f"r12_{i}", ["Pêcheur", "Pêcheur", "Montagnard", "Ornithologue"][i], 22, 27, 2)
place_route_trainers(r, [f"r12_{i}" for i in range(4)], 12)
r.npc("ronflex_r12", "legend", 6, 30, "down", kind="script", species=143, ghost=True, hide_if=F("ronflex_12"), script=[
    iff({"item": "poke-flute"}, [say("Un Pokémon énorme dort sur la route. Tu joues de la Poké Flûte..."), say("Ronflex se réveille ! Il est furieux !"),
                                 legend(143, 30, "ronflex_12"), quest("main", 13)],
        [say("Un Pokémon énorme dort sur la route et bloque le passage. Rien ne le réveille...")])])
r.npc("ronflex_r12b", "legend", 7, 30, "down", kind="script", species=0, ghost=True, hide_if=F("ronflex_12"), script=[say("Ronflex ronfle bruyamment...")])
r.rect(9, 37, 3, 3, "~", True)
r.npc("pecheur_r12", "fisher", 10, 36, "down", kind="script", script=[
    iff(F("mega_canne_got"), [say("Pêcheur : Avec la Méga Canne, même les Pokémon les plus rares mordent. Bonne pêche !")],
        [iff(F("super_canne_got"), [say("Pêcheur : Mes deux frères t'ont donné leurs cannes ? Alors tu es digne de la mienne !",
                                         "Voici la Méga Canne, la meilleure de toutes !"),
                                     give("super-rod"), setf("mega_canne_got"), quest("peche", 3),
                                     say("Avec elle, tu pêcheras des Pokémon bien plus forts. On dit même qu'un dragon vit dans le Parc Safari...")],
             [say("Pêcheur : Chut... tu vas faire fuir les poissons.", "Reviens quand mon frère de Parmanie t'aura donné sa Super Canne.")])])])

# ===========================================================================
# LAVANVILLE, TOUR POKÉMON
# ===========================================================================
t = town("lavanville", "Lavanville", 7, (12, 9), music="lavender")
d = put_building(t, "center", 3, 2, 5, 4, "centre_lavanville", 6, 6)
center_for(t, d, "Lavanville")
d = put_building(t, "mart", 18, 2, 4, 3, "boutique_lavanville", 5, 6)
mart_for(t, d, "Lavanville", MARTS["mid"])
d_tower = put_building(t, "tower", 16, 13, 6, 6, "tour_1", 0, 0, "Tour Pokémon")
d = put_building(t, "house", 3, 14, 4, 3, "maison_lavanville_0", 4, 6)
house_for(t, 0, d, [("fuji", "oldman", 5, 3, "down", {"kind": "script", "hide_if": NF("fuji_saved"), "script": [
    say("M. Fuji : Merci de m'avoir sauvé. Les Pokémon de la tour reposent enfin en paix.",
        "Prends cette Poké Flûte. Sa mélodie réveille n'importe quel Pokémon endormi.") if False else ["noop"],
    iff(F("flute_got"), [say("M. Fuji : Prends soin de tes Pokémon. Ils te le rendront.")],
        [say("M. Fuji : Merci de m'avoir sauvé. Les Pokémon de la tour reposent enfin en paix.",
             "Prends cette Poké Flûte. Sa mélodie réveille n'importe quel Pokémon endormi, comme le Ronflex de la Route 12 !"),
         give("poke-flute"), setf("flute_got"), quest("main", 12)])]}),
                     ("enfant_fuji", "girl", 2, 5, "right", {"text": ["M. Fuji s'occupe des Pokémon orphelins.", "Il est monté à la Tour Pokémon et il n'est jamais revenu..."]})])
t.npc("medium_lav", "oldman", 20, 11, "down", text=["La Tour Pokémon est hantée...", "On dit qu'un fantôme bloque l'accès au sommet. Impossible de l'identifier sans un Scope Sylphe."])
decorate_town(t, 4, 2, 0)

tower = []
for k in range(4):
    tm, tc = make_cave(f"tour_{k + 1}", f"Tour Pokémon - {k + 1}e étage" if k else "Tour Pokémon - RdC", 22, 18, 70 + k, theme="tower", rooms=5, building=False)
    tm.theme = "tower"
    tm.music = "tower"
    tm.cave = True
    tm.region = "lavanville"
    # le sol de la tour est violet et les murs sont des tombes
    for y in range(tm.h):
        for x in range(tm.w):
            if tm.g[y][x] == "_":
                tm.g[y][x] = "u"
            elif tm.g[y][x] == "R":
                tm.g[y][x] = "O"
    if k > 0:
        wild(tm, f"pokemon-tower/{k + 2}f", rate=0.1)
    tower.append((add(tm), tc))
tm0, tc0 = tower[0]
ex, ey = tc0[0]
tm0.g[ey + 1][ex] = "m"
tm0.warp(ex, ey + 1, "lavanville", d_tower[0], d_tower[1], "down")
set_entry(maps["lavanville"], "tour_1", ex, ey)
for k in range(3):
    a, ac = tower[k]
    b2, bc = tower[k + 1]
    ux, uy = ac[-1]
    a.g[uy][ux] = "<"
    dx, dy = bc[0]
    b2.g[dy][dx] = ">"
    a.warp(ux, uy, b2.id, dx + 1, dy, "right")
    b2.warp(dx, dy, a.id, ux + 1, uy, "right")
tm0.npc("rival_tour", "rival", tc0[1][0], tc0[1][1], "down", kind="script", hide_if=F("rival_tour"), script=[
    say("{rival} : Hé, {player} ! Qu'est-ce que tu fais ici ? Tes Pokémon sont morts ?", "Moi, je viens juste voir... Bon, montre-moi si tu as progressé !"),
    special("rival_battle", 4), setf("rival_tour"), say("{rival} : Pfff. Je file à Céladopole. Salut, minable !"), hide("rival_tour")])
for k in range(1, 4):
    tmk, tck = tower[k]
    for j in range(2):
        tid = random_trainer(f"tour_{k}_{j}", "Médium" if j == 0 else "Sbire Rocket", 21 + k * 2, 24 + k * 2, 2)
        trainer_npc(tmk, tid, tck[j + 1][0], tck[j + 1][1], "down", 3)
    place_items(tmk, [(["super-potion", "great-ball", "rare-candy"][k - 1], 1)], 70 + k, "u")
tm3, tc3 = tower[3]
gx, gy = tc3[-2]
tm3.npc("fantome", "legend", gx, gy, "down", kind="script", species=105, ghost=True, hide_if=F("tower_ghost"), script=[
    iff({"item": "silph-scope"}, [
        say("Le Scope Sylphe révèle le fantôme... C'est l'esprit d'une Ossatueur !", "Elle protège encore son petit... Calme-la !"),
        boss(105, 30, "tower_ghost"),
        say("L'esprit d'Ossatueur s'apaise et disparaît... Il repose enfin en paix."), quest("main", 11)],
        [say("Un fantôme bloque le passage ! « Va-t'en... Va-t'en... »", "Impossible de l'identifier. Il te faut un Scope Sylphe.")])])
tm3.npc("fantome_b", "legend", gx + 1, gy, "down", kind="script", species=0, ghost=True, hide_if=F("tower_ghost"), script=[say("« Va-t'en... »")])
fx, fy = tc3[-1]
tm3.npc("fuji_tour", "oldman", fx, fy, "down", kind="script", hide_if=F("fuji_saved"), script=[
    iff(F("tower_ghost"), [say("Sbire Rocket : Tu ne libéreras pas le vieux !"),
                           battle(tr("tour_rocket_boss", "Admin Rocket", "Corbeau", [(42, 26), (110, 27), (24, 28)], "Encore toi ?! Cette fois, je ne te laisserai pas passer !", "Grr... La Team Rocket n'a pas dit son dernier mot !", potions=1)),
                           say("M. Fuji : Merci, mon enfant... Rentrons à la maison. Viens me voir chez moi."),
                           setf("fuji_saved"), hide("fuji_tour"), outfit("spectre")],
        [say("Un vieil homme est retenu par la Team Rocket, mais un fantôme bloque le chemin...")])])

r = route("r10", "Route 10", 10, "kanto-route-10", grass=0.18, water=True)
for i in range(3):
    random_trainer(f"r10_{i}", ["Montagnard", "Ornithologue", "Fillette"][i], 22, 26, 2)
place_route_trainers(r, [f"r10_{i}" for i in range(3)], 10)
d_cent = put_building(r, "silph", 3, 8, 6, 5, "centrale", 0, 0, "Centrale", require=BADGES(6),
                      locked="La Centrale est fermée. Un écriteau indique : « Accès réservé aux Dresseurs ayant 6 Badges. »")
r9 = route("r9", "Route 9", 9, "kanto-route-9", grass=0.2, trees=0.12)
for i in range(5):
    random_trainer(f"r9_{i}", ["Gamin", "Montagnard", "Fillette", "Scout", "Topdresseur"][i], 20, 25, 2)
place_route_trainers(r9, [f"r9_{i}" for i in range(5)], 9)
d_antre2 = put_building(r9, "cave", r9.w // 2, 2, 3, 2, "antre_2", 0, 0)

# ===========================================================================
# ROUTE 8, ROUTE 7, CÉLADOPOLE (Érika), REPAIRE ROCKET
# ===========================================================================
r8 = route("r8", "Route 8", 8, "kanto-route-8", grass=0.22)
for i in range(4):
    random_trainer(f"r8_{i}", ["Motard", "Jongleur", "Fillette", "Gentleman"][i], 22, 26, 2)
place_route_trainers(r8, [f"r8_{i}" for i in range(4)], 8)
r8.npc("garde_saf_e", "youngster", 2, 4, "left", kind="script", ghost=True, hide_if=F("safrania_open"), script=[say("Safrania est fermée. Passe par le Souterrain !")])
r8.npc("garde_saf_e2", "youngster", 2, 5, "left", kind="script", ghost=True, hide_if=F("safrania_open"), script=[say("Safrania est fermée.")])
d8 = put_building(r8, "gate", 8, 6, 4, 3, "souterrain_eo", 20, 1, "Souterrain")
r7 = route("r7", "Route 7", 7, "kanto-route-7", grass=0.25)
r7.npc("garde_saf_o", "youngster", r7.w - 3, 4, "right", kind="script", ghost=True, hide_if=F("safrania_open"), script=[say("Safrania est fermée. Passe par le Souterrain !")])
r7.npc("garde_saf_o2", "youngster", r7.w - 3, 5, "right", kind="script", ghost=True, hide_if=F("safrania_open"), script=[say("Safrania est fermée.")])
d7 = put_building(r7, "gate", 8, 6, 4, 3, "souterrain_eo", 1, 1, "Souterrain")
ge = add(interior("souterrain_eo", "Souterrain", ["WWWWWWWWWWWWWWWWWWWWWW", "Wm" + "q" * 18 + "mW", "WWWWWWWWWWWWWWWWWWWWWW"], "indoor"))
ge.region = "r7"
ge.warp(1, 1, "r7", d7[0], d7[1], "down")
ge.warp(20, 1, "r8", d8[0], d8[1], "down")
set_entry(r7, "souterrain_eo", 2, 1)
set_entry(r8, "souterrain_eo", 19, 1)

t = town("celadopole", "Céladopole", 8, (18, 11), music="celadon")
d = put_building(t, "center", 3, 2, 5, 4, "centre_celadopole", 6, 6)
center_for(t, d, "Céladopole")
d_store = put_building(t, "store", 11, 2, 8, 5, "magasin", 7, 8, "Magasin")
d = put_building(t, "gym", 26, 15, 6, 5, "arene_celadopole", 6, 13)
gym(t, 4, "grass", "Érika", "Céladopole", [(71, 29), (114, 24), (45, 29)], "tm19", "Prisme",
    "Bonjour... Je suis Érika. J'adore les fleurs et les Pokémon Plante. Mais je ne perds jamais !",
    ["Le Badge Prisme est à toi. Tu es vraiment doué.", "On dit que la Team Rocket se cache sous le Casino, à l'est..."],
    [("Fillette", [(43, 24), (69, 24)]), ("Fillette", [(102, 26)]), ("Canon", [(70, 25), (44, 25)])], "grass")
d_casino = put_building(t, "casino", 24, 3, 6, 4, "casino", 6, 7, "Casino")
d = put_building(t, "house", 3, 15, 4, 3, "maison_celadopole_0", 4, 6)
house_for(t, 0, d, [("evoli_don", "girl", 5, 3, "down", {"kind": "script", "script": [
    iff(F("eevee_got"), [say("Prends bien soin de mon Évoli ! Avec une pierre, il évolue de trois façons différentes.")],
        [say("J'ai trop de Pokémon chez moi... Tu veux bien adopter mon Évoli ?"), mon(133, 25), setf("eevee_got")])]})])
t.npc("lou", "girl", 18, 18, "down", kind="script", script=[
    iff(F("twins_done"), [say("Lou : Lila et moi, on s'entraîne encore. Reviens nous affronter quand tu veux !")],
        [say("Lou : Je suis Lou, la sœur de Lila ! On t'attendait. Un combat en duo, ça te dit ?", "Deux contre deux ! Tu envoies deux Pokémon à la fois !"),
         ["double_battle", tr("jumelles", "Jumelles", "Lila & Lou", [(36, 30), (40, 30), (31, 30), (34, 30)],
                              "En duo !", "Waouh ! Tu gères le combat double !", look="girl")],
         setf("twins_done"), give("rare-candy", 2), outfit("rose_bonbon"), say("Lou : Tiens, notre tenue fétiche, et deux Super Bonbons !")])])
decorate_town(t, 10, 4, 1)

ms = add(interior("magasin", "Magasin de Céladopole", fit_rows(["WWWWWWWWWWWWWWW", "WBBBBBMMMBBBBBW", "WqqqqqqqqqqqqqW", "WKKKqqqqqqqKKKW", "WqqqqqqqqqqqqqW",
                                                                  "WqqqBBqqqBBqqqW", "WqqqqqqqqqqqqqW", "WpqqqqqqqqqqqpW", "WqqqqqqqqqqqqqW", "WWWWWWWmWWWWWWW"]), "mart"))
ms.region = "celadopole"
ms.warp(7, 9, "celadopole", d_store[0], d_store[1], "down")
ms.npc("vendeur_objets", "clerk", 2, 2, kind="shop", stock=MARTS["high"] + ["fire-stone", "water-stone", "thunder-stone", "leaf-stone", "moon-stone",
                                                                            "x-attack", "x-defense", "x-speed", "x-sp-atk", "x-sp-def", "x-accuracy", "dire-hit", "guard-spec",
                                                                            "hp-up", "protein", "iron", "calcium", "zinc", "carbos", "fresh-water", "soda-pop", "lemonade"])
ms.npc("vendeur_ct", "clerk", 12, 2, kind="shop", stock=[f"tm{n:02d}" for n in range(1, 51)])
MINTS = ["lonely", "adamant", "naughty", "brave", "bold", "impish", "lax", "relaxed", "modest", "mild", "rash", "quiet",
         "calm", "gentle", "careful", "sassy", "timid", "hasty", "jolly", "naive", "serious"]
ms.npc("herboriste", "lass", 2, 6, "right", kind="shop",
       stock=["pomeg-berry", "kelpsy-berry", "qualot-berry", "hondew-berry", "grepa-berry", "tamato-berry"] + [f"{n}-mint" for n in MINTS])
ms.npc("conseil_build", "youngster", 9, 8, "up", text=[
    "L'herboriste vend des Aromates : ils changent la nature d'un Pokémon. Pratique pour un build !",
    "Ses Baies baissent les EV d'une stat de 10. Les vitamines, elles, en ajoutent 10.",
    "Les IV, eux, ne changent jamais. Il faut capturer ou faire éclore le bon Pokémon !"])
ms.npc("vendeur_tenues", "lass", 7, 2, kind="outfit_shop", stock=["bleu_marine", "vert_foret", "noir_minuit", "blanc_neige", "rose_bonbon", "orange_soleil"])
ms.npc("porygon_vendeur", "scientist", 12, 6, "left", kind="script", script=[
    iff(F("porygon_got"), [say("Porygon est un Pokémon artificiel. Il aime les ordinateurs !")],
        [choice("Je vends un Porygon pour 9 800 ₽. Intéressé ?", ["OUI", "NON"], [[["pay", 9800, [mon(137, 26), setf("porygon_got")], [say("Tu n'as pas assez d'argent !")]]], []])])])

cs = add(interior("casino", "Casino de Céladopole", fit_rows(["WWWWWWWWWWWWW", "WMMMMqqqMMMMW", "WqqqqqqqqqqqW", "WMMqMMqMMqMMW", "WqqqqqqqqqqqW", "WMMqMMqMMqMMW", "WqqqqqqqqqqqW", "WWWWWWmWWWWWW"]), "celadon"))
cs.region = "celadopole"
cs.warp(6, 7, "celadopole", d_casino[0], d_casino[1], "down")
cs.npc("sbire_affiche", "rocket", 10, 2, "down", kind="script", hide_if=F("rocket_hideout"), script=[
    say("Sbire Rocket : Hé ! Ne touche pas à cette affiche ! Elle ne cache RIEN du tout !"),
    battle(random_trainer("casino_sbire", "Sbire Rocket", 21, 24, 2)),
    say("Sbire Rocket : Argh ! Bon, oui, il y a un escalier secret derrière l'affiche..."), hide("sbire_affiche")])
cs.g[1][11] = ">"
rh = []
for k in range(3):
    hm, hc = make_cave(f"repaire_{k + 1}", f"Repaire Rocket - Sous-sol {k + 1}", 24, 18, 90 + k, theme="rocket", rooms=5, building=True)
    hm.region = "celadopole"
    hm.music = "rocket"
    rh.append((add(hm), hc))
h1, hc1 = rh[0]
cs.warp(11, 1, "repaire_1", hc1[0][0] + 1, hc1[0][1], "right")
h1.g[hc1[0][1]][hc1[0][0]] = "<"
h1.warp(hc1[0][0], hc1[0][1], "casino", 10, 2, "down")
for k in range(2):
    a, ac = rh[k]
    b2, bc = rh[k + 1]
    ux, uy = ac[-1]
    a.g[uy][ux] = ">"
    dx, dy = bc[0]
    b2.g[dy][dx] = "<"
    a.warp(ux, uy, b2.id, dx + 1, dy, "right")
    b2.warp(dx, dy, a.id, ux + 1, uy, "right")
for k in range(3):
    hm, hc = rh[k]
    for j in range(2):
        tid = random_trainer(f"repaire_{k}_{j}", "Sbire Rocket", 21 + k * 2, 25 + k * 2, 2)
        trainer_npc(hm, tid, hc[j + 1][0], hc[j + 1][1], "left", 3)
    place_items(hm, [(["hyper-potion", "ultra-ball", "tm24"][k], 1)], 90 + k, "q")
h3, hc3 = rh[2]
gx, gy = hc3[-1]
h3.npc("giovanni_1", "giovanni", gx, gy - 1, "down", kind="script", hide_if=F("rocket_hideout"), script=[
    say("??? : Alors c'est toi qui sèmes le trouble dans mon repaire...", "Je suis Giovanni, le chef de la Team Rocket ! Tu vas regretter d'être venu."),
    battle(tr("giovanni_1b", "Boss Rocket", "Giovanni", [(95, 25), (111, 24), (115, 29)], "...", "Hmph. Tu as gagné cette fois. Prends ce Scope Sylphe et disparais.", potions=1, look="giovanni", kind="leader", music="rocket")),
    give("silph-scope"), setf("rocket_hideout"), quest("main", 11), outfit("rocket"),
    say("Giovanni : Je reviendrai. La Team Rocket ne meurt jamais !", "Tu trouves aussi un uniforme Rocket abandonné : la tenue « Rocket » !"), hide("giovanni_1")])
CLASSES["Boss Rocket"] = {"look": "giovanni", "money": 100, "pool": [111, 112, 51, 31, 34, 115, 95]}
CLASSES["Champion"] = {"look": "ace", "money": 100, "pool": []}
CLASSES["Jumelles"] = {"look": "girl", "money": 60, "pool": [35, 36, 39, 40]}

r16 = route("r16", "Route 16", 16, "kanto-route-16", grass=0.22)
r17 = route("r17", "Route 17 - Piste Cyclable", 17, "kanto-route-17", grass=0.12, trees=0.04)
r17.music = "cycling"
for i in range(6):
    random_trainer(f"r17_{i}", "Motard", 26, 30, 2)
place_route_trainers(r17, [f"r17_{i}" for i in range(6)], 17)
r18 = route("r18", "Route 18", 18, "kanto-route-18", grass=0.2)
for i in range(3):
    random_trainer(f"r18_{i}", "Ornithologue", 27, 30, 2)
place_route_trainers(r18, [f"r18_{i}" for i in range(3)], 18)

# ===========================================================================
# ROUTES 13 / 15, PARMANIE (Koga), PARC SAFARI
# ===========================================================================
r13 = route("r13", "Route 13", 13, "kanto-route-13", grass=0.24, ledges=1)
for i in range(5):
    random_trainer(f"r13_{i}", ["Ornithologue", "Fillette", "Gentleman", "Topdresseur", "Gamin"][i], 25, 30, 2)
place_route_trainers(r13, [f"r13_{i}" for i in range(5)], 13)
r15 = route("r15", "Route 15", 15, "kanto-route-15", grass=0.24)
for i in range(4):
    random_trainer(f"r15_{i}", ["Ornithologue", "Fillette", "Topdresseur", "Motard"][i], 27, 31, 2)
place_route_trainers(r15, [f"r15_{i}" for i in range(4)], 15)

t = town("parmanie", "Parmanie", 9, (16, 15))
d = put_building(t, "center", 3, 3, 5, 4, "centre_parmanie", 6, 6)
center_for(t, d, "Parmanie")
d = put_building(t, "mart", 24, 3, 4, 3, "boutique_parmanie", 5, 6)
mart_for(t, d, "Parmanie", MARTS["high"])
d = put_building(t, "gym", 4, 19, 6, 5, "arene_parmanie", 6, 13)
gym(t, 5, "poison", "Koga", "Parmanie", [(109, 37), (89, 39), (109, 37), (110, 43)], "tm06", "Âme",
    "Fwahaha ! Je suis Koga, maître ninja des poisons ! Tu vas goûter à l'art du ninja !",
    ["Le Badge Âme... Tu le mérites, jeune ninja.", "La Team Rocket a envahi Safrania. Les gardes laissent passer ceux qui ont 5 Badges."],
    [("Jongleur", [(96, 34), (64, 35)]), ("Jongleur", [(97, 36)]), ("Ninja", [(109, 34), (88, 34), (42, 36)])], "poison")
CLASSES["Ninja"] = {"look": "rocket", "money": 40, "pool": [109, 88, 41, 23, 48]}
d_safari = put_building(t, "gate", 14, 3, 4, 3, "safari", 20, 34, "Parc Safari")
d = put_building(t, "house", 24, 19, 4, 3, "maison_parmanie_0", 4, 6)
house_for(t, 0, d, [("gardien", "oldman", 5, 3, "down", {"kind": "script", "script": [
    iff(F("dentier_done"), [say("Gardien : Grâce à toi, je mâche à nouveau ! Hé hé !")],
        [iff({"item": "gold-teeth"}, [say("Gardien : Mon dentier en or ! Merci ! Tiens, ma vieille tenue de gardien du Safari !"),
                                      take("gold-teeth"), outfit("safari"), give("tm24"), setf("dentier_done"), quest("dentier", 2)],
             [say("Gardien : J'ai perdu mon dentier en or dans le Parc Safari... Tu pourrais le chercher ?"), quest("dentier", 1)])])]})])
decorate_town(t, 10, 4, 2)
t.npc("garde_saf_info", "youngster", 18, 12, "down", text=["Le Parc Safari regorge de Pokémon rares !", "Certains ne vivent que là-bas."])
t.rect(26, 15, 4, 3, "~", True)
wild(t, "fuchsia-city", kinds=())
t.npc("pecheur_parmanie", "fisher", 25, 16, "right", kind="script", script=[
    iff(F("super_canne_got"), [say("Pêcheur : Avec la Super Canne, tu pêcheras des Poissirène, des Ptitard, des Hypotrempe...",
                                   "Mon grand frère de la Route 12 a une canne encore meilleure !")],
        [iff(F("canne_got"), [say("Pêcheur : Tiens, la Canne de mon frère de Carmin ! Elle n'attrape que des Magicarpe...",
                                  "Prends plutôt ma Super Canne !"),
                              give("good-rod"), setf("super_canne_got"), quest("peche", 2)],
             [say("Pêcheur : Mon frère, le Maître Pêcheur de Carmin, distribue des cannes à pêche. Va le voir !")])])])

# Parc Safari : grande zone sauvage
sf = make_route("safari", "Parc Safari", 42, 36, [(20, 34)], 77, grass=0.35, water=True, trees=0.1)
sf.outdoor = False
sf.region = "parmanie"
sf.music = "safari"
sf.g[35][20] = "m"
sf.g[35][21] = "m"
sf.warp(20, 35, "parmanie", d_safari[0], d_safari[1], "down")
sf.warp(21, 35, "parmanie", d_safari[0], d_safari[1], "down")
merged = {}
for key in ["kanto-safari-zone/middle", "kanto-safari-zone/area-1-east", "kanto-safari-zone/area-2-north", "kanto-safari-zone/area-3-west"]:
    for kind, lst in ENC.get(key, {}).items():
        for e in lst:
            k2 = (kind, e[0])
            if k2 in merged:
                merged[k2][3] += e[3]
            else:
                merged[k2] = list(e)
sf.wild = {"grass": [v for (k, _), v in merged.items() if k == "grass"], "marsh": [v for (k, _), v in merged.items() if k == "water"]}
for rk in RODS:
    sf.wild[rk] = [v for (k, _), v in merged.items() if k == rk]
sf.rate = 0.16
place_items(sf, [("gold-teeth", 1), ("ultra-ball", 3), ("max-revive", 1), ("tm32", 1)], 78, '."')
add(sf)

# ===========================================================================
# SAFRANIA (Morgane), SYLPHE SARL, DOJO
# ===========================================================================
t = town("safrania", "Safrania", 10, (16, 12), music="saffron")
d = put_building(t, "center", 3, 2, 5, 4, "centre_safrania", 6, 6)
center_for(t, d, "Safrania")
d = put_building(t, "mart", 27, 2, 4, 3, "boutique_safrania", 5, 6)
mart_for(t, d, "Safrania", MARTS["high"])
d_silph = put_building(t, "silph", 12, 2, 8, 6, "sylphe_1", 0, 0, "Sylphe SARL")
d = put_building(t, "gym", 25, 18, 6, 5, "arene_safrania", 6, 13, require=F("silph_done"),
                 locked="« L'Arène est fermée tant que la Team Rocket occupe la ville ! »")
gym(t, 6, "psychic", "Morgane", "Safrania", [(64, 38), (122, 37), (49, 38), (65, 43)], "tm04", "Marais",
    "Je savais que tu viendrais. Je suis Morgane. Mes pouvoirs psychiques me l'ont dit...",
    ["Le Badge Marais est à toi. Tu iras loin, je l'ai vu.", "Cramois'Île t'attend, au sud de Parmanie, par le ponton de la Route 19."],
    [("Canon", [(79, 34), (64, 34)]), ("Médium", [(96, 36)]), ("Canon", [(97, 36), (122, 36)])], "psychic")
d = put_building(t, "dojo", 3, 18, 6, 4, "dojo", 6, 7, "Dojo")
dj = add(interior("dojo", "Dojo de Safrania", fit_rows(["WWWWWWWWWWWWW", "WooooooooooooW"[:13], "WoooooXooooooW"[:13], "WooooooooooooW"[:13], "WooooooooooooW"[:13],
                                                     "WooooooooooooW"[:13], "WpoooooooooopW"[:13], "WooooooooooooW"[:13], "WWWWWWmWWWWWW"]), "gym"))
dj.region = "safrania"
dj.warp(6, 8, "safrania", d[0], d[1], "down")
dj.npc("maitre_karate", "hiker", 6, 2, kind="script", script=[
    iff(F("dojo_done"), [say("Maître Karaté : Prends soin du Pokémon que je t'ai confié !")], [
        say("Maître Karaté : Je suis le Maître du Dojo ! Tu oses me défier ?"),
        battle(tr("maitre_dojo", "Karatéka", "Maître", [(57, 37), (68, 37)], "Hyaaa !", "Ton style est imparable !")),
        say("Maître Karaté : Tu as gagné ! Choisis un de mes Pokémon !"),
        choice("Lequel veux-tu ?", ["KICKLEE", "TYGNON"], [[mon(106, 30)], [mon(107, 30)]]), setf("dojo_done")])])
dj.npc("karateka1", "hiker", 3, 4, "right", kind="trainer", trainer=random_trainer("dojo_1", "Karatéka", 31, 34, 2), sight=3)
dj.npc("karateka2", "hiker", 9, 5, "left", kind="trainer", trainer=random_trainer("dojo_2", "Karatéka", 31, 34, 2), sight=3)
t.npc("sbire_saf", "rocket", 17, 9, "down", kind="script", hide_if=F("silph_done"), text=["La Team Rocket contrôle Safrania ! Le Boss est à Sylphe SARL !"],
      script=[say("La Team Rocket contrôle Safrania ! Le Boss est à Sylphe SARL !")])
decorate_town(t, 8, 2, 1)
silph = []
for k in range(4):
    sm, sc = make_cave(f"sylphe_{k + 1}", f"Sylphe SARL - {k + 1}{'er' if k == 0 else 'e'} étage", 24, 18, 110 + k, theme="building", rooms=5, building=True)
    sm.region = "safrania"
    sm.music = "rocket"
    silph.append((add(sm), sc))
s1, sc1 = silph[0]
ex, ey = sc1[0]
s1.g[ey + 1][ex] = "m"
s1.warp(ex, ey + 1, "safrania", d_silph[0], d_silph[1], "down")
t.buildings[[b["to"] for b in t.buildings].index("sylphe_1")]["tx"] = ex
t.buildings[[b["to"] for b in t.buildings].index("sylphe_1")]["ty"] = ey
for k in range(3):
    a, ac = silph[k]
    b2, bc = silph[k + 1]
    ux, uy = ac[-1]
    a.g[uy][ux] = "<"
    dx, dy = bc[0]
    b2.g[dy][dx] = ">"
    a.warp(ux, uy, b2.id, dx + 1, dy, "right")
    b2.warp(dx, dy, a.id, ux + 1, uy, "right")
for k in range(4):
    sm, sc = silph[k]
    for j in range(2):
        tid = random_trainer(f"sylphe_{k}_{j}", "Sbire Rocket" if j == 0 else "Scientifique", 30 + k * 2, 34 + k * 2, 2 + (k > 1))
        trainer_npc(sm, tid, sc[j + 1][0], sc[j + 1][1], "left", 3)
    place_items(sm, [(["hyper-potion", "max-revive", "rare-candy", "tm26"][k], 1)], 110 + k, "q")
s2, sc2 = silph[1]
s2.npc("lokhlass_don", "scientist", sc2[-2][0], sc2[-2][1] + 1, "down", kind="script", script=[
    iff(F("lapras_got"), [say("Prends soin de Lokhlass. C'est un Pokémon très doux.")],
        [say("Employé : Merci d'être venu nous aider ! Prends ce Lokhlass, la Team Rocket voulait le voler."), mon(131, 25), setf("lapras_got")])])
s3, sc3 = silph[2]
s3.npc("rival_sylphe", "rival", sc3[-2][0], sc3[-2][1], "down", kind="script", hide_if=F("rival_sylphe"), script=[
    say("{rival} : Te voilà enfin, {player} ! Moi aussi je suis venu affronter la Team Rocket.", "Mais d'abord, voyons qui est le plus fort !"),
    special("rival_battle", 5), setf("rival_sylphe"), say("{rival} : Tch... Le Boss est au dernier étage. Vas-y, je te laisse cet honneur."), hide("rival_sylphe")])
s4, sc4 = silph[3]
gx, gy = sc4[-1]
s4.npc("giovanni_2", "giovanni", gx, gy - 1, "down", kind="script", hide_if=F("silph_done"), script=[
    say("Giovanni : Encore toi ! Sylphe SARL et sa Master Ball appartiennent à la Team Rocket !", "Je vais te montrer ce qu'est le vrai pouvoir !"),
    battle(tr("giovanni_2b", "Boss Rocket", "Giovanni", [(33, 37), (115, 35), (111, 37), (31, 41)], "...", "Arrgh ! Encore battu... Très bien. Nous quittons Safrania.", potions=2, look="giovanni", kind="leader", music="rocket")),
    setf("silph_done"), setf("safrania_open"), quest("main", 15),
    say("Président de Sylphe : Merci, jeune héros ! Prends cette Master Ball, elle capture n'importe quel Pokémon !"),
    give("master-ball"), hide("giovanni_2")])

# ===========================================================================
# ROUTE 19, ÎLES ÉCUME, ROUTE 20, CRAMOIS'ÎLE (Auguste), MANOIR
# ===========================================================================
r19 = sea_route("r19", "Route 19", 19, "kanto-sea-route-19")
for i in range(3):
    random_trainer(f"r19_{i}", "Nageuse", 30, 34, 2)
r19.npc("r19_t0", "girl", 7, 10, "left", kind="trainer", trainer="r19_0", sight=3)
r19.npc("r19_t1", "girl", 4, 20, "right", kind="trainer", trainer="r19_1", sight=3)
r19.npc("r19_t2", "girl", 7, 30, "left", kind="trainer", trainer="r19_2", sight=3)
for nn in r19.npcs:
    r19.g[nn["y"]][nn["x"]] = "H"
r19.path(4, 19, 4, 36, "H", 2)
d_ecume_in = r19.building("cave", 7, 30, 3, 2, "ecume_1", 0, 0)
r19.set(d_ecume_in[0], d_ecume_in[1], "H", True)
r19.path(d_ecume_in[0], d_ecume_in[1], 4, d_ecume_in[1], "H", 2)

ecume = []
for k in range(2):
    em, ec = make_cave(f"ecume_{k + 1}", f"Îles Écume - {'Entrée' if k == 0 else 'Profondeurs'}", 28, 20, 130 + k, theme="ice", rooms=6)
    em.region = "r19"
    em.music = "cave"
    wild(em, ["seafoam-islands/1f", "seafoam-islands/b3f"][k], rate=0.09)
    ecume.append((add(em), ec))
e1, ec1 = ecume[0]
e2, ec2 = ecume[1]
ex, ey = ec1[0]
e1.g[ey + 1][ex] = "m"
e1.warp(ex, ey + 1, "r19", d_ecume_in[0], d_ecume_in[1], "down")
set_entry(r19, "ecume_1", ex, ey)
ux, uy = ec1[-1]
e1.g[uy][ux] = ">"
dx, dy = ec2[0]
e2.g[dy][dx] = "<"
e1.warp(ux, uy, "ecume_2", dx + 1, dy, "right")
e2.warp(dx, dy, "ecume_1", ux + 1, uy, "right")
ax, ay = ec2[-1]
e2.npc("artikodin", "legend", ax, ay, kind="legend", species=144, level=50, flag="leg_144",
       text=["Un Pokémon de glace majestueux vous fixe... C'est Artikodin, l'oiseau légendaire !"], require=BADGES(6))
e2.npc("blanc_neige_box", "ball", ec2[2][0], ec2[2][1], kind="script", hide_if=F("outfit_neige"), script=[
    say("Une boîte gelée... Il y a une tenue blanche à l'intérieur !"), outfit("blanc_neige"), setf("outfit_neige"), hide("blanc_neige_box")])
for j in range(2):
    tid = random_trainer(f"ecume_{j}", "Nageuse" if j else "Pêcheur", 32, 36, 3)
    trainer_npc(e1, tid, ec1[j + 1][0], ec1[j + 1][1], "down", 3)
r20 = sea_route("r20", "Route 20", 20, "kanto-sea-route-20")
ox, oy = ec2[-2]
e2.g[oy + 1][ox] = "m"
d_ecume_out = r20.building("cave", r20.w - 8, 2, 3, 2, "ecume_2", ox, oy)
r20.set(d_ecume_out[0], d_ecume_out[1], "H", True)
r20.path(d_ecume_out[0], d_ecume_out[1], 24, d_ecume_out[1], "H", 2)
e2.warp(ox, oy + 1, "r20", d_ecume_out[0], d_ecume_out[1], "down")
r21 = sea_route("r21", "Route 21", 21, "kanto-sea-route-21")
for i in range(2):
    random_trainer(f"r21_{i}", ["Pêcheur", "Nageuse"][i], 30, 34, 2)
r21.npc("r21_t0", "hiker", 4, 8, "right", kind="trainer", trainer="r21_0", sight=3)
r21.npc("r21_t1", "girl", 7, 16, "left", kind="trainer", trainer="r21_1", sight=3)
for nn in r21.npcs:
    r21.g[nn["y"]][nn["x"]] = "H"

t = town("cramois", "Cramois'Île", 11, (12, 10), music="cinnabar")
d = put_building(t, "center", 3, 2, 5, 4, "centre_cramois", 6, 6)
center_for(t, d, "Cramois'Île")
d = put_building(t, "mart", 18, 2, 4, 3, "boutique_cramois", 5, 6)
mart_for(t, d, "Cramois'Île", MARTS["top"])
d = put_building(t, "gym", 17, 14, 6, 5, "arene_cramois", 6, 13, require={"item": "secret-key"},
                 locked="La porte de l'Arène est verrouillée. Il faudrait une Clé Secrète...")
gym(t, 7, "fire", "Auguste", "Cramois'Île", [(58, 42), (77, 40), (78, 42), (59, 47)], "tm38", "Volcan",
    "Hah ! Je suis Auguste, le Champion brûlant de Cramois'Île ! Mes Pokémon vont te réduire en cendres !",
    ["Le Badge Volcan ! Tu as le feu sacré, gamin !", "Il ne reste qu'un Badge : celui de Jadielle. Son Champion est enfin revenu..."],
    [("Scientifique", [(126 if False else 77, 36), (37, 36)]), ("Dompteur", [(58, 37), (38, 38)]), ("Scientifique", [(126 if False else 136, 38)])], "fire")
d_lab_fossil = put_building(t, "lab", 3, 13, 6, 4, "labo_fossiles", 6, 9)
lf = add(interior("labo_fossiles", "Labo Pokémon de Cramois'Île", ["WWWWWWWWWWWWW", "WBBMMqqqMMBBW", "WqqqqqqqqqqqW", "WqqqqqqqXXXqW", "WqqqqqqqqqqqW",
                                                                     "WqqqqqqqqqqqW", "WBBBqqqqqBBBW", "WqqqqqqqqqqqW", "WqqqqqqqqqqqW", "WpqqqqqqqqqpW", "WWWWWWmWWWWWW"], "lab"))
lf.region = "cramois"
lf.warp(6, 10, "cramois", d_lab_fossil[0], d_lab_fossil[1], "down")
lf.npc("chercheur_fossiles", "scientist", 9, 2, kind="fossil")
d_mansion = put_building(t, "mansion", 10, 14, 6, 5, "manoir_1", 0, 0, "Manoir Pokémon")
decorate_town(t, 4, 2, 0)
manoir = []
for k in range(2):
    mm, mc = make_cave(f"manoir_{k + 1}", f"Manoir Pokémon - {'RdC' if k == 0 else 'Sous-sol'}", 24, 18, 140 + k, theme="mansion", rooms=6, building=True)
    mm.region = "cramois"
    mm.music = "mansion"
    mm.cave = True
    wild(mm, ["pokemon-mansion/1f", "pokemon-mansion/b1f"][k], rate=0.08)
    manoir.append((add(mm), mc))
m1, mc1 = manoir[0]
m2, mc2 = manoir[1]
ex, ey = mc1[0]
m1.g[ey + 1][ex] = "m"
m1.warp(ex, ey + 1, "cramois", d_mansion[0], d_mansion[1], "down")
t.buildings[[b["to"] for b in t.buildings].index("manoir_1")]["tx"] = ex
t.buildings[[b["to"] for b in t.buildings].index("manoir_1")]["ty"] = ey
ux, uy = mc1[-1]
m1.g[uy][ux] = ">"
dx, dy = mc2[0]
m2.g[dy][dx] = "<"
m1.warp(ux, uy, "manoir_2", dx + 1, dy, "right")
m2.warp(dx, dy, "manoir_1", ux + 1, uy, "right")
for k, (mm, mc) in enumerate(manoir):
    for j in range(2):
        tid = random_trainer(f"manoir_{k}_{j}", "Scientifique" if j else "Dompteur", 34 + k * 2, 38 + k * 2, 2)
        trainer_npc(mm, tid, mc[j + 1][0], mc[j + 1][1], "down", 3)
kx, ky = mc2[-1]
m2.npc("boss_manoir", "legend", kx, ky - 1, "down", kind="script", species=59, ghost=True, hide_if=F("manoir_boss"), script=[
    say("Un Arcanin sauvage gigantesque garde quelque chose... C'est un Pokémon BOSS !"), boss(59, 40, "manoir_boss"),
    say("Arcanin s'enfuit ! Derrière lui, il y a une clé...")])
m2.npc("cle_secrete", "ball", kx, ky, kind="script", hide_if=F("key_got"), script=[
    iff(F("manoir_boss"), [give("secret-key"), setf("key_got"), say("Tu trouves la Clé Secrète ! Elle ouvre l'Arène de Cramois'Île."), hide("cle_secrete"), quest("main", 18)],
        [say("Arcanin garde cet objet...")])])
place_items(m1, [("full-restore", 1), ("fire-stone", 1)], 141, "q")
place_items(m2, [("rare-candy", 2), ("tm35", 1)], 142, "q")

# ===========================================================================
# ARÈNE DE JADIELLE (Giovanni), ROUTE 23, ROUTE VICTOIRE, PLATEAU INDIGO
# ===========================================================================
gym(maps["jadielle"], 8, "ground", "Giovanni", "Jadielle", [(111, 45), (51, 42), (31, 44), (34, 45), (112, 50)], "tm26", "Terre",
    "Giovanni : Bienvenue dans mon Arène. Oui, le Champion de Jadielle et le chef de la Team Rocket ne font qu'un !",
    ["Giovanni : ... Tu m'as battu trois fois. La Team Rocket est dissoute.", "Je vais disparaître et m'entraîner seul. Va à la Ligue Pokémon, tu le mérites."],
    [("Karatéka", [(66, 40), (67, 42)]), ("Dompteur", [(111, 41), (28, 41)]), ("Topdresseur", [(31, 42), (34, 42)])], "ground")
trainers["leader_8"]["look"] = "giovanni"
maps["arene_jadielle"].npcs[0]["look"] = "giovanni"
maps["arene_jadielle"].npcs[0]["script"][0][3].insert(3, setf("rocket_disbanded"))
maps["arene_jadielle"].npcs[0]["script"][0][3].insert(4, quest("main", 19))

r23 = route("r23", "Route 23", 23, "kanto-route-23", grass=0.2, water=True)
for n in range(1, 8):
    r23.npc(f"garde_badge_{n}", "youngster", 2 if n % 2 else r23.w - 3, r23.h - 4 - n * 5, "right" if n % 2 else "left",
            text=[f"Garde : Seuls les Dresseurs avec le Badge {['Roche', 'Cascade', 'Foudre', 'Prisme', 'Âme', 'Marais', 'Volcan'][n - 1]} peuvent passer. Tu l'as ! Vas-y !"])
r23.npc("garde_final", "youngster", 6, r23.h - 4, "down", kind="script", ghost=True, hide_if=BADGES(8),
        script=[say("Garde : Il faut les 8 Badges de Kanto pour emprunter la Route 23 !")])
r23.npc("garde_final2", "youngster", 7, r23.h - 4, "down", kind="script", ghost=True, hide_if=BADGES(8),
        script=[say("Garde : Il faut les 8 Badges de Kanto !")])
d_vr = put_building(r23, "cave", 5, 2, 3, 2, "victoire_1", 0, 0)
d_antre3 = put_building(r23, "cave", r23.w - 5, 12, 3, 2, "antre_3", 0, 0)
vr = []
for k in range(2):
    vm, vc = make_cave(f"victoire_{k + 1}", f"Route Victoire - {k + 1}", 30, 22, 150 + k, rooms=7)
    vm.region = "r23"
    wild(vm, f"kanto-victory-road-2/{k + 1}f", rate=0.08)
    vr.append((add(vm), vc))
v1, vc1 = vr[0]
v2, vc2 = vr[1]
ex, ey = vc1[0]
v1.g[ey + 1][ex] = "m"
v1.warp(ex, ey + 1, "r23", d_vr[0], d_vr[1], "down")
set_entry(r23, "victoire_1", ex, ey)
ux, uy = vc1[-1]
v1.g[uy][ux] = "<"
dx, dy = vc2[0]
v2.g[dy][dx] = ">"
v1.warp(ux, uy, "victoire_2", dx + 1, dy, "right")
v2.warp(dx, dy, "victoire_1", ux + 1, uy, "right")
for k, (vm, vc) in enumerate(vr):
    for j in range(3):
        tid = random_trainer(f"victoire_{k}_{j}", ["Topdresseur", "Karatéka", "Canon"][j], 42 + k * 2, 46 + k * 2, 3)
        trainer_npc(vm, tid, vc[j + 1][0], vc[j + 1][1], "down", 3)
sx2, sy2 = vc2[-2]
v2.npc("sulfura", "legend", sx2, sy2, kind="legend", species=146, level=50, flag="leg_146",
       text=["Une chaleur intense... Sulfura, l'oiseau de feu légendaire, se dresse devant toi !"])
place_items(v1, [("full-restore", 1), ("max-revive", 1)], 151, "_")
place_items(v2, [("rare-candy", 1), ("tm02", 1)], 152, "_")

t = add(place(make_town("plateau", "Plateau Indigo", 22, 26, [], 12, (10, 20), "league")))
for y in range(t.h - 2, 4, -1):
    t.set(10, y, ",", True)
    t.set(11, y, ",", True)
ox, oy = vc2[-1]
v2.g[oy + 1][ox] = "m"
d_vr_out = put_building(t, "cave", 9, t.h - 4, 3, 2, "victoire_2", ox, oy)
v2.warp(ox, oy + 1, "plateau", d_vr_out[0], d_vr_out[1], "down")
d = put_building(t, "league", 7, 2, 8, 6, "ligue_1", 6, 9, "Ligue Pokémon")
d_center_pl = put_building(t, "center", 2, 11, 5, 4, "centre_plateau", 6, 6)
center_for(t, d_center_pl, "Plateau Indigo")
maps["centre_plateau"].npcs.append({"id": "vendeur_ligue", "look": "clerk", "x": 2, "y": 4, "dir": "right", "kind": "shop", "stock": MARTS["top"]})
ELITE = [("Olga", "ice", [(87, 54), (91, 53), (80, 54), (124, 56), (131, 56)], "Je suis Olga du Conseil 4. Mes Pokémon Glace vont te frigorifier !"),
         ("Aldo", "fighting", [(95, 53), (107, 55), (106, 55), (95, 56), (68, 58)], "Je suis Aldo ! Les Pokémon et moi, on s'entraîne jusqu'à l'épuisement. Hoo-hah !"),
         ("Agatha", "ghost", [(94, 54), (42, 54), (93, 53), (24, 56), (94, 58)], "Je suis Agatha. Ce vieux Chen... Tu es son protégé ? Je vais te montrer le vrai combat !"),
         ("Peter", "dragon", [(130, 56), (148, 54), (148, 54), (142, 58), (149, 60)], "Je suis Peter, le maître des dragons. Les dragons sont des Pokémon mystiques. Prépare-toi !")]
for k, (name, typ, team, intro) in enumerate(ELITE):
    lid = f"ligue_{k + 1}"
    lm = add(interior(lid, f"Ligue Pokémon - {name}", ["WWWWWWWWWWW"] + ["W" + "q" * 9 + "W" for _ in range(9)] + ["WWWWWmWWWWW"], "league"))
    lm.theme = {"ice": "ice", "fighting": "", "ghost": "tower", "dragon": "volcano"}[typ]
    lm.region = "plateau"
    eid = tr(f"elite_{k + 1}", "Conseil 4", name, team, intro, "Tu es digne de continuer...", money=team[-1][1] * 100, potions=2, pool_type=typ, look=f"elite{k + 1}", kind="elite")
    lm.npc(eid, f"elite{k + 1}", 5, 3, "down", kind="script", trainer=eid, script=[
        iff(F(f"elite_{k + 1}_done"), [say("Avance ! Le prochain t'attend.")],
            [say(intro), ["league_battle", eid], setf(f"elite_{k + 1}_done"), say("Tu peux passer. La porte du fond est ouverte.")])])
    lm.g[1][5] = "<"
    lm.warp(5, 10, "plateau" if k == 0 else f"ligue_{k}", d[0] if k == 0 else 5, d[1] if k == 0 else 2, "down")
    nxt = f"ligue_{k + 2}" if k < 3 else "ligue_champion"
    lm.npc(f"porte_{k}", "clerk", 5, 2, "down", kind="script", ghost=True, hide_if=F(f"elite_{k + 1}_done"), script=[say("La porte est fermée. Bats d'abord ce membre du Conseil 4 !")])
    lm.warp(5, 1, nxt, 5, 8, "up")
cm = add(interior("ligue_champion", "Ligue Pokémon - Salle du Maître", ["WWWWWWWWWWW"] + ["W" + "q" * 9 + "W" for _ in range(9)] + ["WWWWWmWWWWW"], "league"))
cm.region = "plateau"
cm.warp(5, 10, "ligue_4", 5, 2, "down")
cm.npc("rival_champion", "rival", 5, 3, "down", kind="script", script=[
    iff(F("champion"), [say("{rival} : Tu es le Maître, {player}. Je l'accepte... Mais je reviendrai plus fort !")],
        [say("{rival} : Hé, {player} ! Tu es enfin là. Pendant que tu traînais, je suis devenu le Maître de la Ligue !",
             "Mes Pokémon sont les plus forts du monde ! Et je vais te le prouver !"),
         special("rival_battle", 7),
         say("{rival} : Non... C'est impossible ! J'ai tout donné..."),
         say("Prof. Chen : {player} ! {rival} ! Bravo à vous deux !", "{player}, tu es le nouveau Maître de la Ligue Pokémon de Kanto !",
             "{rival}, tu as oublié une chose : l'amour de tes Pokémon. C'est ce qui a fait la différence."),
         setf("champion"), quest("main", 20), outfit("champion"), ["hall_of_fame"]])])
quests_main = [
    "Va voir le Prof. Chen dans son labo, au sud de Bourg Palette.",
    "Va à Jadielle, au nord de Bourg Palette, par la Route 1.",
    "Rapporte le colis du vendeur de Jadielle au Prof. Chen.",
    "Traverse la Route 2 et la Forêt de Jade jusqu'à Argenta, puis bats Pierre.",
    "Franchis le Mont Sélénite, à l'est d'Argenta. La Team Rocket y a été aperçue.",
    "Va à Azuria par la Route 4 et bats Ondine.",
    "Rends visite à Léo, au bout du Pont Pépite et de la Route 25, au nord d'Azuria.",
    "Passe par le Souterrain de la Route 5 jusqu'à Carmin-sur-Mer et bats le Major Bob.",
    "Rejoins Lavanville par la Route 11 puis la Route 12.",
    "La Tour Pokémon est hantée. Va à Céladopole (Souterrain de la Route 8) et bats Érika.",
    "Infiltre le Repaire Rocket sous le Casino de Céladopole et récupère le Scope Sylphe.",
    "Retourne à la Tour Pokémon de Lavanville et libère M. Fuji.",
    "Retrouve M. Fuji chez lui à Lavanville.",
    "Réveille le Ronflex de la Route 12 avec la Poké Flûte et va à Parmanie par les Routes 13 et 15.",
    "Bats Koga à Parmanie. Ensuite, libère Safrania : entre dans Sylphe SARL.",
    "Bats Morgane, la Championne de Safrania.",
    "Prends le ponton de la Route 19 (sud de Parmanie) vers les Îles Écume et Cramois'Île.",
    "Trouve la Clé Secrète dans le Manoir Pokémon de Cramois'Île.",
    "Bats Auguste à Cramois'Île. Le ponton de la Route 21 te ramène à Bourg Palette.",
    "Le Champion de Jadielle est revenu. Va l'affronter, puis prends la Route 22 vers la Ligue.",
    "Tu es le Maître de la Ligue ! Complète le Pokédex et explore la Grotte Azurée.",
]
quests = {
    "main": {"title": "L'aventure de Kanto", "stages": quests_main, "main": True},
    "rattata": {"title": "Le Rattata perdu", "stages": ["", "Montre un Rattata à la fillette de la Route 2.", "Terminé ! Tu as rassuré la fillette."]},
    "dentier": {"title": "Le dentier du Gardien", "stages": ["", "Trouve le dentier en or du Gardien dans le Parc Safari.", "Terminé ! Le Gardien t'a offert sa tenue."]},
    "pension": {"title": "La Pension", "stages": ["", "Laisse deux Pokémon compatibles à la Pension de la Route 5 pour obtenir un Œuf.", "Tu as obtenu un Œuf de la Pension !"]},
    "fossile": {"title": "Le fossile", "stages": ["", "Apporte ton fossile au Labo de Cramois'Île.", "Ton fossile a été ressuscité !"]},
    "peche": {"title": "Les frères pêcheurs", "stages": ["", "Va voir le frère du Maître Pêcheur à Parmanie, près de l'étang.",
                                                          "Le dernier frère pêche au bord d'un étang sur la Route 12.",
                                                          "Terminé ! Tu as la Méga Canne, la meilleure canne à pêche."]},
}

# ===========================================================================
# DONJONS COOP OPTIONNELS (« Antres ») avec boss
# ===========================================================================
ANTRES = [("antre_1", "Antre des Rocs", "r4", door_antre1, 34, (95, 22), [74, 41, 27, 50]),
          ("antre_2", "Antre Spectral", "r9", d_antre2, 52, (94, 32), [92, 93, 41, 42]),
          ("antre_3", "Antre du Dragon", "r23", d_antre3, 79, (149, 55), [147, 148, 42, 75])]
for (aid, name, parent, door, seed, (bsid, blvl), pool) in ANTRES:
    am, ac = make_cave(aid, name, 26, 20, seed, theme={"antre_1": "cave", "antre_2": "tower", "antre_3": "volcano"}[aid], rooms=6)
    am.region = parent
    am.music = "dungeon"
    am.rate = 0.1
    am.wild = {"grass": [[s, blvl - 12, blvl - 6, 10] for s in pool]}
    ex, ey = ac[0]
    am.g[ey + 1][ex] = "m"
    am.warp(ex, ey + 1, parent, door[0], door[1], "down")
    pm = maps[parent]
    for b in pm.buildings:
        if b["to"] == aid:
            b["tx"], b["ty"] = ex, ey
            b["label"] = name
    for j in range(3):
        tid = random_trainer(f"{aid}_{j}", "Topdresseur", blvl - 8, blvl - 4, 3)
        trainer_npc(am, tid, ac[j + 1][0], ac[j + 1][1], "down", 3)
    bx, by = ac[-1]
    am.npc(f"{aid}_boss", "legend", bx, by, "down", kind="script", species=bsid, ghost=True, hide_if=F(f"{aid}_boss"), script=[
        say(f"Un {POKE[bsid]['name']} gigantesque se dresse devant toi ! C'est le BOSS de l'antre !",
            "Conseil : à deux en coop, c'est bien plus facile !"),
        boss(bsid, blvl, f"{aid}_boss"),
        say("Le boss est vaincu ! Tu trouves son trésor !"), give("rare-candy", 3), give("ultra-ball", 5), outfit({"antre_1": "orange_soleil", "antre_2": "noir_minuit", "antre_3": "dragon"}[aid])])
    add(am)

# Grotte Azurée (après la Ligue) : Mewtwo
ga = []
for k in range(2):
    gm, gc = make_cave(f"grotte_az_{k + 1}", f"Grotte Azurée - {k + 1}", 30, 22, 160 + k, rooms=7)
    gm.region = "r24"
    gm.music = "dungeon"
    wild(gm, ["cerulean-cave/1f", "cerulean-cave/b1f"][k], rate=0.09)
    ga.append((add(gm), gc))
g1, gc1 = ga[0]
g2, gc2 = ga[1]
ex, ey = gc1[0]
g1.g[ey + 1][ex] = "m"
g1.warp(ex, ey + 1, "r24", door_cave_az[0], door_cave_az[1], "down")
for b in maps["r24"].buildings:
    if b["to"] == "grotte_az_1":
        b["tx"], b["ty"] = ex, ey
ux, uy = gc1[-1]
g1.g[uy][ux] = ">"
dx, dy = gc2[0]
g2.g[dy][dx] = "<"
g1.warp(ux, uy, "grotte_az_2", dx + 1, dy, "right")
g2.warp(dx, dy, "grotte_az_1", ux + 1, uy, "right")
mx, my = gc2[-1]
g2.npc("mewtwo", "legend", mx, my, kind="legend", species=150, level=70, flag="leg_150",
       text=["Une présence terrifiante... Mewtwo, le Pokémon créé par l'homme, vous observe en silence."])
place_items(g1, [("max-revive", 2), ("ultra-ball", 5)], 161, "_")
place_items(g2, [("rare-candy", 3), ("full-restore", 2)], 162, "_")

# Centrale : Électhor
cm2, cc = make_cave("centrale", "Centrale", 26, 20, 170, theme="building", rooms=6, building=True)
cm2.region = "r10"
cm2.music = "dungeon"
cm2.cave = True
wild(cm2, "kanto-power-plant", rate=0.1)
ex, ey = cc[0]
cm2.g[ey + 1][ex] = "m"
cm2.warp(ex, ey + 1, "r10", d_cent[0], d_cent[1], "down")
for b in maps["r10"].buildings:
    if b["to"] == "centrale":
        b["tx"], b["ty"] = ex, ey
ex2, ey2 = cc[-1]
cm2.npc("electhor", "legend", ex2, ey2, kind="legend", species=145, level=50, flag="leg_145",
        text=["L'air crépite d'électricité... Électhor, l'oiseau de foudre légendaire !"])
place_items(cm2, [("thunder-stone", 1), ("max-elixir", 1), ("tm25", 1)], 171, "q")
add(cm2)

# Cave Taupiqueur
dc, dcc = make_cave("cave_taupiqueur", "Cave Taupiqueur", 24, 16, 180, rooms=5)
dc.region = "r11"
wild(dc, "digletts-cave", rate=0.12)
ex, ey = dcc[0]
dc.g[ey + 1][ex] = "m"
dc.warp(ex, ey + 1, "r11", d_dig[0], d_dig[1], "down")
for b in maps["r11"].buildings:
    if b["to"] == "cave_taupiqueur":
        b["tx"], b["ty"] = ex, ey
add(dc)

# ---------------------------------------------------------------------------
# Rencontres manquantes : on ajoute aux bons endroits les Pokémon des autres versions.
# ---------------------------------------------------------------------------
EXTRA = {"r3": [[27, 6, 8, 15]], "r4": [[27, 8, 12, 15]], "r24": [[69, 12, 14, 20], [37, 12, 14, 8]],
         "r25": [[69, 12, 14, 20]], "r5": [[37, 13, 16, 10], [69, 13, 16, 20]], "r6": [[37, 13, 16, 10], [69, 13, 16, 20]],
         "r7": [[37, 18, 20, 10], [69, 19, 22, 20]], "r8": [[37, 18, 20, 10], [38, 30, 30, 2]], "r12": [[69, 22, 26, 15], [70, 28, 30, 5]],
         "r13": [[69, 22, 26, 15], [70, 28, 30, 5]], "r15": [[70, 28, 30, 5]], "safari": [[127, 23, 25, 4], [83, 24, 26, 4], [122, 24, 26, 3], [124, 24, 26, 3], [108, 24, 26, 3], [128, 26, 28, 4]],
         "r23": [[83, 30, 32, 6]], "r17": [[77, 26, 30, 12]], "r18": [[77, 26, 30, 10]], "r10": [[125, 30, 33, 6]], "manoir_2": [[126, 32, 36, 6]], "r20": [], "r21": [[114, 30, 33, 10]]}
MARSH_EXTRA = {"r24": [[121, 25, 30, 5]], "r19": [[120, 25, 30, 10], [90, 25, 30, 10], [116, 25, 30, 10]],
               "r20": [[120, 25, 30, 10], [90, 25, 30, 10], [116, 25, 30, 10], [79, 25, 30, 10]], "r12": [[79, 22, 26, 10], [54, 22, 26, 10]]}
for mid, extra in EXTRA.items():
    maps[mid].wild.setdefault("grass", []).extend(extra)
for mid, extra in MARSH_EXTRA.items():
    maps[mid].wild.setdefault("marsh", []).extend(extra)

# Mares : certaines routes de Rouge Feu ont de l'eau (et des tables de pêche) mais le générateur
# n'a pas pu y placer d'étang (route trop étroite). On en creuse un sur une zone d'herbe libre,
# seulement si ça ne coupe aucun passage.
def has_water(m):
    return any(c in row for row in m.g for c in "~w")


def add_pond(m, seed):
    rng = random.Random(seed)
    start = next(((x, y) for y in range(m.h) for x in range(m.w) if m.g[y][x] == ","), None)
    if start is None:
        return False
    before = reachable(m, start)
    for pw, ph in ((6, 4), (5, 4), (5, 3), (4, 3), (3, 4), (3, 3), (2, 4), (2, 3)):
        spots = []
        for y in range(1, m.h - ph):
            for x in range(1, m.w - pw):
                cells = [(xx, yy) for yy in range(y, y + ph) for xx in range(x, x + pw)]
                if any(m.g[yy][xx] not in '."' or (xx, yy) in m.protected for xx, yy in cells):
                    continue
                ring = [(xx, yy) for yy in range(y - 1, y + ph + 1) for xx in range(x - 1, x + pw + 1) if (xx, yy) not in cells]
                if any(m.get(xx, yy) in ",S" for xx, yy in ring):
                    continue
                if any(abs(n["x"] - cx) + abs(n["y"] - cy) <= 2 for n in m.npcs for cx, cy in cells):
                    continue
                if any(b["x"] - 1 <= cx <= b["x"] + b["w"] and b["y"] - 1 <= cy <= b["y"] + b["h"] for b in m.buildings for cx, cy in cells):
                    continue
                spots.append((x, y, cells))
        rng.shuffle(spots)
        for x, y, cells in spots:
            old = {c: m.g[c[1]][c[0]] for c in cells}
            m.rect(x, y, pw, ph, "w", True)
            if pw >= 3 and ph >= 3:
                m.rect(x + 1, y + 1, pw - 2, ph - 2, "~", True)
            after = reachable(m, start)
            # Rien d'autre que l'étang ne doit devenir inaccessible.
            if before - set(cells) <= after:
                return True
            for (cx, cy), c in old.items():
                m.g[cy][cx] = c
                m.protected.discard((cx, cy))
    return False


for mid, mm in maps.items():
    if mm.outdoor and mid in RECT and not has_water(mm) and any(rk in mm.wild for rk in RODS):
        if not add_pond(mm, sum(map(ord, mid)) + 7):
            print("pas de place pour un étang :", mid)

# Pêche : chaque point d'eau a ses tables Canne / Super Canne / Méga Canne.
wild(maps["bourg"], "pallet-town", kinds=())
wild(maps["carmin"], "vermilion-city", kinds=())
for mid, mm in maps.items():
    if has_water(mm):
        for rk in RODS:
            mm.wild.setdefault(rk, list(ENC["pallet-town"][rk]))

# Les vraies tables sont pauvres : on ajoute quelques Pokémon Eau selon le type de point d'eau.
# Pourcentages approximatifs, ajoutés par-dessus les tables officielles.
FISH_EXTRA = {
    "pond": {"old-rod": [(60, 5, 10, 10)], "good-rod": [(54, 15, 25, 12), (79, 15, 25, 10), (60, 15, 20, 10)],
             "super-rod": [(61, 25, 35, 15), (55, 30, 40, 6), (80, 35, 40, 3), (119, 30, 35, 8)]},
    "coast": {"old-rod": [(72, 5, 10, 10), (98, 5, 10, 8)], "good-rod": [(120, 15, 25, 15), (98, 15, 25, 10)],
              "super-rod": [(99, 30, 40, 12), (86, 30, 35, 10), (121, 35, 40, 3), (117, 30, 35, 8)]},
    "sea": {"old-rod": [(72, 5, 10, 12)], "good-rod": [(120, 15, 25, 15), (90, 15, 25, 10)],
            "super-rod": [(86, 30, 35, 12), (91, 35, 40, 3), (121, 35, 40, 4), (131, 35, 40, 2), (73, 30, 40, 10)]},
    "cave": {"good-rod": [(86, 20, 30, 12)], "super-rod": [(86, 30, 40, 15), (87, 40, 45, 3), (55, 35, 40, 8)]},
}
for mid, mm in maps.items():
    if not has_water(mm):
        continue
    kind = "sea" if mid in ("r19", "r20", "r21") else "coast" if mid in ("bourg", "carmin") else "cave" if mm.cave else "pond"
    for rk, extra in FISH_EXTRA[kind].items():
        table = mm.wild[rk] = [list(e) for e in mm.wild[rk]]
        total = sum(e[3] for e in table) or 100
        have = {e[0] for e in table}
        for sid, lo, hi, pct in extra:
            if sid not in have:
                table.append([sid, lo, hi, max(1, round(total * pct / 100))])

# ---------------------------------------------------------------------------
# Finitions : connexions, panneaux, vérifications
# ---------------------------------------------------------------------------
apply_links()
for mid in RECT:
    mm = maps[mid]
    if mid.startswith("r") and mid[1:].isdigit():
        mm.signs.setdefault(f"2,{mm.h // 2}", f"{mm.name.upper()}")
        if mm.get(2, mm.h // 2) not in ".,":
            mm.signs.pop(f"2,{mm.h // 2}")
        else:
            mm.g[mm.h // 2][2] = "S"
# Les routes avec de l'eau : tout marais doit être accessible ; sinon on le remplace par de l'herbe.
for mid, mm in maps.items():
    if not mm.outdoor:
        continue
    ent = [(w["tx"], w["ty"]) for x in maps.values() for w in x.warps if w["to"] == mid]
    if not ent:
        continue
    reach = reachable(mm, ent[0], ())
    for y in range(mm.h):
        for x in range(mm.w):
            if mm.g[y][x] in 'w"' and (x, y) not in reach:
                if any((x + dx, y + dy) in reach for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    continue
                mm.g[y][x] = "~" if mm.g[y][x] == "w" else "T"

problems = []
for mid, mm in maps.items():
    ent = [(w["tx"], w["ty"]) for x in maps.values() for w in x.warps if w["to"] == mid]
    ent += [(b["tx"], b["ty"]) for x in maps.values() for b in x.buildings if b["to"] == mid]
    if not ent:
        problems.append(f"{mid} : aucune entrée")
        continue
    reach = reachable(mm, ent[0])
    for e in ent:
        if e not in reach:
            problems.append(f"{mid} : entrée inaccessible {e} (case {mm.get(*e)!r})")
    for wp in mm.warps:
        near = [(wp["x"] + dx, wp["y"] + dy) for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))]
        if not any(n in reach for n in near):
            problems.append(f"{mid} : sortie inaccessible {wp}")
        t2 = maps.get(wp["to"])
        if t2 is None:
            problems.append(f"{mid} : sortie vers carte inconnue {wp['to']}")
        elif t2.get(wp["tx"], wp["ty"]) not in WALK:
            problems.append(f"{mid} -> {wp['to']} : arrivée sur une case bloquante {(wp['tx'], wp['ty'])} {t2.get(wp['tx'], wp['ty'])!r}")
    for b in mm.buildings:
        door = (b["x"] + b["w"] // 2, b["y"] + b["h"])
        if door not in reach:
            problems.append(f"{mid} : porte inaccessible {b['to']} {door}")
        t2 = maps.get(b["to"])
        if t2 is not None and t2.get(b["tx"], b["ty"]) not in WALK:
            problems.append(f"{mid} -> {b['to']} : arrivée bloquante {(b['tx'], b['ty'])}")
    for n in mm.npcs:
        near = [(n["x"] + dx, n["y"] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (0, 2), (2, 0), (-2, 0))]
        if not any(p in reach for p in near):
            problems.append(f"{mid} : PNJ inaccessible {n['id']}")
for p in problems:
    print("PROBLÈME", p)

# Couverture du Pokédex
obtainable = set()
for mm in maps.values():
    for lst in mm.wild.values():
        obtainable |= {e[0] for e in lst}
    for n in mm.npcs:
        if n.get("kind") in ("legend", "starter") and n.get("species"):
            obtainable.add(n["species"])
obtainable |= {133, 131, 106, 107, 137, 138, 140, 142, 143, 105, 151, 1, 4, 7}
for t2 in trainers.values():
    pass
changed = True
while changed:
    changed = False
    for sid in list(obtainable):
        for e in POKE[sid]["evos"]:
            if e["to"] not in obtainable:
                obtainable.add(e["to"])
                changed = True
for sid in list(obtainable):
    pre = POKE[sid]["evolves_from"]
    if pre and pre in POKE and pre not in obtainable and POKE[pre]["egg_groups"] != ["no-eggs"]:
        obtainable.add(pre)
missing = [f"{s} {POKE[s]['name']}" for s in range(1, 152) if s not in obtainable]
print("Pokémon introuvables :", missing)

out = {"maps": {k: v.to_json() for k, v in maps.items()}, "trainers": trainers, "quests": quests,
       "classes": CLASSES, "type_pool": TYPE_POOL, "world": {k: list(v) for k, v in RECT.items()}}
json.dump(out, open(f"{DATA}/world.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(maps), "cartes,", len(trainers), "dresseurs,", len(problems), "problèmes")
