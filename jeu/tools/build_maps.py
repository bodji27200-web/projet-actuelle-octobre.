"""Génère jeu/data/maps.json : cartes, bâtiments, PNJ, dresseurs et Pokémon sauvages.

Usage : python3 build_maps.py <dossier_data>
Légende des tuiles :
  . herbe   , chemin   " hautes herbes   T arbre   ~ eau   f fleurs   = barrière   S panneau
  v rebord (saut vers le bas)   : sable   R rocher   w marais (Pokémon Eau)   _ sol de grotte
  # paroi de grotte   o parquet   q carrelage   W mur   m tapis de sortie   X table   B étagère
  P PC   C comptoir Centre   K comptoir Boutique   b lit   t télé   p plante   M machine   (espace) vide
"""
import json
import random
import sys

DATA = sys.argv[1]
POKE = json.load(open(f"{DATA}/pokemon.json", encoding="utf-8"))
WALK = set('.,"f v:w_oqm')
maps = {}


def check(mid, rows):
    w = len(rows[0])
    for i, r in enumerate(rows):
        assert len(r) == w, f"{mid} ligne {i} : {len(r)} au lieu de {w} -> {r!r}"
    return w, len(rows)


def fit(r, w, fill):
    if len(r) < w:
        return r[:-1] + fill * (w - len(r)) + r[-1]
    if len(r) > w:
        return r[:w - 1] + r[-1]
    return r


def add(mid, name, rows, **kw):
    fill = "#" if kw.get("cave") else "." if kw.get("outdoor", True) else "W"
    rows = [fit(r, len(rows[0]), fill) for r in rows]
    w, h = check(mid, rows)
    m = {"name": name, "w": w, "h": h, "rows": rows, "buildings": [], "warps": [], "npcs": [], "signs": {},
         "wild": {}, "rate": 0.12, "outdoor": True, "cave": False}
    m.update(kw)
    maps[mid] = m
    return m


def tile(mid, x, y):
    return maps[mid]["rows"][y][x]


def warp(mid, x, y, to, tx, ty, d="down"):
    maps[mid]["warps"].append({"x": x, "y": y, "to": to, "tx": tx, "ty": ty, "dir": d})


def edge(a, xs_a, ya, b, xs_b, yb, d_ab, d_ba):
    """Relie deux cartes par une rangée de cases (bords de carte)."""
    for xa, xb in zip(xs_a, xs_b):
        warp(a, xa, ya, b, xb, yb + (-1 if d_ab == "up" else 1), d_ab)
        warp(b, xb, yb, a, xa, ya + (-1 if d_ba == "up" else 1), d_ba)


def edge_h(a, x_a, ys_a, b, x_b, ys_b, d_ab, d_ba):
    for ya, yb in zip(ys_a, ys_b):
        warp(a, x_a, ya, b, x_b + (-1 if d_ab == "left" else 1), yb, d_ab)
        warp(b, x_b, yb, a, x_a + (-1 if d_ba == "left" else 1), ya, d_ba)


def building(mid, kind, x, y, w, h, to, tx, ty):
    maps[mid]["buildings"].append({"kind": kind, "x": x, "y": y, "w": w, "h": h, "to": to, "tx": tx, "ty": ty})


def npc(mid, nid, look, x, y, d="down", **kw):
    n = {"id": nid, "look": look, "x": x, "y": y, "dir": d}
    n.update(kw)
    maps[mid]["npcs"].append(n)


def team(*pairs):
    return [[s, l] for s, l in pairs]


def trainer(mid, nid, look, x, y, d, cls, name, mons, intro, defeat, sight=4, money=None, potions=0):
    lvl = max(l for _, l in mons)
    base = {"Gamin": 16, "Scout": 10, "Fillette": 16, "Montagnard": 36, "Topdresseur": 60, "Expert": 70, "Scientifique": 48}.get(cls, 20)
    npc(mid, nid, look, x, y, d, kind="trainer", sight=sight, trainer={
        "name": f"{cls} {name}", "team": team(*mons), "intro": intro, "defeat": defeat,
        "money": money or base * lvl, "potions": potions})


# ---------------------------------------------------------------------------
# Intérieurs
# ---------------------------------------------------------------------------
add("maison", "Maison", [
    "WWWWWWWWWW",
    "WBBootoPbW",
    "WoooooooBW",
    "WooooooooW",
    "WooXXooooW",
    "WooXXooooW",
    "WooooooooW",
    "WWWWmWWWWW",
], outdoor=False)
warp("maison", 4, 7, "bourg", 5, 5, "down")
npc("maison", "maman", "mom", 6, 4, "left", kind="mom")
maps["maison"]["signs"] = {"7,1": "@pc", "5,1": "Une émission sur les Pokémon passe à la télé. Quatre garçons marchent sur une voie ferrée..."}
maps["maison"]["rows"][2] = "WoooooooBW"

add("maison_rival", "Maison du rival", [
    "WWWWWWWWWW",
    "WBBoooooBW",
    "WooooooooW",
    "WooooXXooW",
    "WooooXXooW",
    "WpoooooopW",
    "WooooooooW",
    "WWWWmWWWWW",
], outdoor=False)
warp("maison_rival", 4, 7, "bourg", 15, 5, "down")
npc("maison_rival", "soeur", "lass", 4, 3, "down", kind="sister")

add("labo", "Labo du Prof. Chen", [
    "WWWWWWWWWWWWW",
    "WBBMMqqqMMBBW",
    "WqqqqqqqqqqqW",
    "WqqqqqqqXXXqW",
    "WqqqqqqqqqqqW",
    "WqqqqqqqqqqqW",
    "WBBBqqqqqBBBW",
    "WqqqqqqqqqqqW",
    "WqqqqqqqqqqqW",
    "WpqqqqqqqqqpW",
    "WWWWWWmWWWWWW",
], outdoor=False)
warp("labo", 6, 10, "bourg", 12, 12, "down")
npc("labo", "chen", "chen", 9, 2, "down", kind="chen")
npc("labo", "rival", "rival", 6, 4, "up", kind="rival_lab")
npc("labo", "ball1", "ball", 8, 3, "down", kind="starter", species=1)
npc("labo", "ball4", "ball", 9, 3, "down", kind="starter", species=4)
npc("labo", "ball7", "ball", 10, 3, "down", kind="starter", species=7)
npc("labo", "assistant", "scientist", 2, 8, "right", text=["Le Prof. Chen étudie les Pokémon depuis des années.", "Le Pokédex enregistre automatiquement chaque Pokémon que tu rencontres !"])

CENTER = [
    "WWWWWWWWWWWWW",
    "WWWWWMMMWWWWW",
    "WqqqqqqqqqqPW",
    "WqqqCCCCCqqqW",
    "WqqqqqqqqqqqW",
    "WpqqqqqqqqqpW",
    "WqqqqqqqqqqqW",
    "WWWWWWmWWWWWW",
]
MART = [
    "WWWWWWWWWWW",
    "WBBBBBBBBBW",
    "WqqqqqqqqqW",
    "WKKKqqqqqqW",
    "WqqqqqqqqqW",
    "WqqqqqBBqqW",
    "WpqqqqqqqqW",
    "WWWWWmWWWWW",
]


def center(mid, back, bx, by):
    add(mid, "Centre Pokémon", CENTER, outdoor=False, heal=True)
    warp(mid, 6, 7, back, bx, by, "down")
    npc(mid, "infirmiere", "nurse", 6, 2, "down", kind="nurse")
    maps[mid]["signs"] = {"11,2": "@pc"}
    npc(mid, "visiteur", "girl", 2, 5, "right", text=["Les Centres Pokémon soignent gratuitement tes Pokémon.", "Le PC te permet de stocker les Pokémon que tu captures en trop."])


def mart(mid, back, bx, by, stock):
    add(mid, "Boutique Pokémon", MART, outdoor=False)
    warp(mid, 5, 7, back, bx, by, "down")
    npc(mid, "vendeur", "clerk", 2, 2, "down", kind="shop", stock=stock)


# ---------------------------------------------------------------------------
# Bourg Palette
# ---------------------------------------------------------------------------
add("bourg", "Bourg Palette", [
    "TTTTTTTTTT,,TTTTTTTT",
    "T.........,,.......T",
    "T.f.......,,.....f.T",
    "T.........,,.......T",
    "T.........,,.......T",
    "T....,,,,,,,,,,,...T",
    "T.f.......,........T",
    "T.S.......,......f.T",
    "T.........,........T",
    "T..f......,........T",
    "T.........,........T",
    "T.......,,,........T",
    "T.......,,,,,.S....T",
    "T..f..........f....T",
    "T..................T",
    "T~~~~~~~~~~~~~~~~~~T",
    "T~~~~~~~~~~~~~~~~~~T",
    "TTTTTTTTTTTTTTTTTTTT",
])
building("bourg", "house", 3, 2, 4, 3, "maison", 4, 6)
building("bourg", "house", 13, 2, 4, 3, "maison_rival", 4, 6)
building("bourg", "lab", 9, 8, 6, 4, "labo", 6, 9)
maps["bourg"]["signs"] = {"2,7": "BOURG PALETTE\nUne ville d'un blanc pur où commence chaque aventure.",
                          "14,12": "LABO POKéMON DU PROF. CHEN"}
npc("bourg", "fille", "girl", 6, 9, "down", text=["La technologie, c'est incroyable !", "On peut stocker des Pokémon dans un PC et les retirer ailleurs !"])
npc("bourg", "gros", "hiker", 16, 10, "left", text=["Il paraît que le Prof. Chen cherche quelqu'un pour l'aider.", "Va le voir dans son labo, au sud du village !"])

# ---------------------------------------------------------------------------
# Route 1
# ---------------------------------------------------------------------------
add("route1", "Route 1", [
    "TTTTTTTTTT,,TTTTTTTT",
    "T.........,,.......T",
    'T..""""...,,.."""".T',
    'T..""""...,,.."""".T',
    "T..vvvvvvv,,vvvvvv.T",
    "T.........,,.......T",
    'T.""""".....""""""..T'[:20],
    'T.""""".....""""""T',
    "T.........,,.......T",
    "T.f.......,,....f..T",
    "TTTTTT....,,..TTTTTT",
    'T""""T....,,..T""""T',
    'T""""T....,,..T""""T',
    'T""""".........""""T',
    "T..vvvvvvv,,vvvvvv.T",
    "T.........,,.......T",
    "T...S.....,,.......T",
    'T.....""""""""".....T'[:20],
    'T.....""""""""""...T',
    'T.....""""""""""...T',
    "T.........,,.......T",
    "T..f......,,...f...T",
    "T.vvvvvvvv,,vvvvvv.T",
    "T.........,,.......T",
    'T..""""...,,.."""".T',
    'T..""""...,,.."""".T',
    "T.........,,.......T",
    "TTTTTTTTTT,,TTTTTTTT",
])
edge("bourg", [10, 11], 0, "route1", [10, 11], 27, "up", "down")
maps["route1"]["signs"] = {"4,16": "ROUTE 1\nBOURG PALETTE - JADIELLE"}
npc("route1", "vendeur_r1", "clerk", 12, 20, "left", kind="gift", item="potion", count=1, flag="gift_route1",
    text=["Bonjour ! Je travaille à la Boutique Pokémon de Jadielle.", "Tiens, prends cet échantillon gratuit !"])
maps["route1"]["wild"] = {"grass": [[16, 2, 5, 55], [19, 2, 4, 45]]}

# ---------------------------------------------------------------------------
# Jadielle
# ---------------------------------------------------------------------------
add("jadielle", "Jadielle", [
    "TTTTTTTTTTTTTTT,,TTTTTTTTTTTTT",
    "T..............,,............T",
    "T..............,,............T",
    "T..f...........,,.......f....T",
    "T..............,,............T",
    "T..............,,............T",
    "T..............,,............T",
    "T.....,,,,,,,,,,,,,,,,,,,....T",
    "T.....,........,,.......,....T",
    "T..S..,........,,.......,..f.T",
    ",,,,,,,........,,.......,....T",
    ",,,,,,,........,,.......,....T",
    "T..............,,............T",
    "T..ff..........,,.......ff...T",
    "T..............,,............T",
    "T..............,,............T",
    "T......~~~~~...,,............T",
    "T......~~~~~...,,....f.......T",
    "T......~~~~~...,,............T",
    "T..............,,............T",
    "T...f..........,,......S.....T",
    "T..............,,............T",
    "TTTTTTTTTTTTTTT,,TTTTTTTTTTTTT",
])
building("jadielle", "center", 8, 3, 5, 4, "centre_jadielle", 6, 6)
building("jadielle", "mart", 20, 3, 4, 3, "boutique_jadielle", 5, 6)
building("jadielle", "house", 19, 11, 4, 3, "maison_jadielle", 4, 6)
building("jadielle", "gym", 3, 13, 6, 4, "arene_jadielle", 0, 0)
maps["jadielle"]["signs"] = {"3,9": "JADIELLE\nLa ville éternellement verte.", "23,20": "ASTUCE : affaiblis un Pokémon sauvage et endors-le ou paralyse-le avant de lancer une Ball !"}
edge("route1", [10, 11], 0, "jadielle", [15, 16], 22, "up", "down")
npc("jadielle", "vieux", "oldman", 17, 15, "left", kind="oldman")
npc("jadielle", "gamin_j", "youngster", 26, 8, "down", text=["Les Hautes herbes sont pleines de Pokémon sauvages.", "Plus tu vas au nord, plus ils sont forts !"])
npc("jadielle", "dame_j", "girl", 5, 20, "right", text=["L'Arène de Jadielle est fermée.", "Personne ne sait où est parti le Champion..."])
maps["jadielle"]["signs"]["5,16"] = "ARÈNE DE JADIELLE\nLa porte est verrouillée."

center("centre_jadielle", "jadielle", 10, 7)
mart("boutique_jadielle", "jadielle", 22, 6, [
    "poke-ball", "great-ball", "ultra-ball", "premier-ball", "net-ball", "nest-ball", "repeat-ball", "timer-ball",
    "luxury-ball", "dusk-ball", "heal-ball", "quick-ball", "level-ball", "moon-ball", "heavy-ball", "fast-ball",
    "friend-ball", "love-ball", "dive-ball",
    "potion", "super-potion", "hyper-potion", "max-potion", "full-restore", "revive", "antidote", "paralyze-heal",
    "awakening", "burn-heal", "ice-heal", "full-heal", "ether", "elixir", "fresh-water", "soda-pop", "lemonade",
    "repel", "super-repel", "max-repel", "escape-rope",
    "x-attack", "x-defense", "x-sp-atk", "x-sp-def", "x-speed", "x-accuracy", "dire-hit", "guard-spec",
    "fire-stone", "water-stone", "thunder-stone", "leaf-stone", "moon-stone", "linking-cord"])
add("maison_jadielle", "Maison", [
    "WWWWWWWWWW",
    "WBBootooBW",
    "WooooooooW",
    "WooXXooooW",
    "WooXXooooW",
    "WpoooooopW",
    "WooooooooW",
    "WWWWmWWWWW",
], outdoor=False)
warp("maison_jadielle", 4, 7, "jadielle", 21, 14, "down")
npc("maison_jadielle", "conseil", "scientist", 6, 3, "down", kind="info")

# ---------------------------------------------------------------------------
# Route 22 (ouest de Jadielle)
# ---------------------------------------------------------------------------
add("route22", "Route 22", [
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    'T""""".......TTT......."""""""',
    'T""""".......TTT......."""""""',
    "T........................,,,,,",
    "T...S....vvvvvvvv........,,,,,",
    'T......."""""""""........,,,,,',
    'T......."""""""""..""""".....T',
    "T~~~~~...........""\"\"\".....T",
    "T~~~~~......f..............T.T",
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
])
maps["route22"]["rows"][7] = 'T~~~~~...........""""".......T'
maps["route22"]["rows"][8] = "T~~~~~......f.................T"[:30]
check("route22", maps["route22"]["rows"])
edge_h("jadielle", 0, [10, 11], "route22", 29, [3, 4], "left", "right")
maps["route22"]["signs"] = {"4,4": "ROUTE 22\nPORTE DE LA LIGUE POKéMON\nAccès réservé aux Dresseurs ayant 8 Badges."}
maps["route22"]["wild"] = {"grass": [[19, 3, 5, 35], [21, 3, 5, 25], [29, 3, 5, 15], [32, 3, 5, 15], [56, 3, 5, 10]]}
npc("route22", "rival22", "rival", 20, 3, "right", kind="rival22")

# ---------------------------------------------------------------------------
# Route 2 (nord de Jadielle)
# ---------------------------------------------------------------------------
add("route2", "Route 2", [
    "TTTTTTTTTT,,TTTTTTTT",
    "T.........,,.......T",
    'T.""""""..,,.."""".T',
    'T.""""""..,,.."""".T',
    'T.""""""..,,.."""".T',
    "T.........,,.......T",
    "T...TTTTT.,,.TTTT..T",
    "T...TTTTT.,,.TTTT..T",
    'T.........,,.""""..T',
    'T..f......,,.""""..T',
    "T.........,,.......T",
    'T.""""""".,,.......T',
    'T.""""""".,,..S....T',
    'T.""""""".,,.......T',
    "T.........,,.......T",
    "T.vvvvvvvv,,vvvvvv.T",
    "T.........,,.......T",
    'T....""""",,""""...T',
    'T....""""",,""""...T',
    "T.........,,.......T",
    "T..f......,,.....f.T",
    "T.........,,.......T",
    "TTTTTTTTTT,,TTTTTTTT",
])
edge("jadielle", [15, 16], 0, "route2", [10, 11], 22, "up", "down")
maps["route2"]["signs"] = {"14,12": "ROUTE 2\nJADIELLE - FORÊT DE JADE"}
maps["route2"]["wild"] = {"grass": [[16, 3, 6, 30], [19, 3, 6, 25], [10, 3, 5, 15], [13, 3, 5, 15], [63, 4, 7, 5], [39, 4, 6, 10]]}
trainer("route2", "gamin_r2a", "youngster", 8, 10, "right", "Gamin", "Léo", [(19, 6), (16, 6)],
        "Hé ! On s'est croisés du regard ! On se bat !", "Quoi ?! J'ai perdu ?!")
trainer("route2", "fillette_r2", "lass", 15, 16, "left", "Fillette", "Iris", [(39, 7), (35, 7)],
        "Tu as l'air mignon, mais tes Pokémon le sont-ils ?", "Mes Pokémon tout mignons...")

# ---------------------------------------------------------------------------
# Forêt de Jade
# ---------------------------------------------------------------------------
F = [list("T" * 30) for _ in range(24)]


def carve(x0, y0, x1, y1, ch='"'):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            F[y][x] = ch


carve(2, 21, 27, 22)
carve(26, 19, 27, 23, ",")
carve(2, 14, 3, 22)
carve(2, 14, 24, 15)
carve(22, 8, 24, 15)
carve(5, 8, 24, 9)
carve(5, 3, 6, 9)
carve(5, 3, 15, 4)
carve(14, 0, 15, 4, ",")
carve(8, 17, 18, 19)
carve(12, 15, 13, 17, ",")
carve(16, 2, 27, 6)
carve(16, 3, 17, 4, ",")
carve(8, 11, 18, 12)
carve(10, 9, 11, 11, ",")
carve(26, 8, 27, 18)
carve(24, 11, 27, 12, ",")
for x, y in [(9, 18), (17, 5), (20, 21), (4, 15)]:
    F[y][x] = "f"
add("foret", "Forêt de Jade", ["".join(r) for r in F])
edge("route2", [10, 11], 0, "foret", [26, 27], 23, "up", "down")
maps["foret"]["wild"] = {"grass": [[10, 3, 6, 25], [11, 4, 6, 15], [13, 3, 6, 25], [14, 4, 6, 15], [25, 3, 5, 5], [16, 4, 6, 15]]}
maps["foret"]["rate"] = 0.10
trainer("foret", "scout_f1", "bugcatcher", 2, 17, "down", "Scout", "Rémi", [(13, 7), (10, 7), (14, 8)],
        "Hé ! Tu as des Pokémon ! Viens te battre !", "Non ! Mes Pokémon Insecte...", sight=4)
trainer("foret", "scout_f2", "bugcatcher", 20, 14, "left", "Scout", "Doug", [(10, 9), (11, 9), (12, 10)],
        "Les Insectes, c'est trop fort ! Regarde !", "Je dois encore m'entraîner...", sight=5)
trainer("foret", "scout_f3", "bugcatcher", 23, 10, "down", "Scout", "Sami", [(10, 10), (13, 10), (15, 12)],
        "Je viens de capturer un super Pokémon !", "Pfff... C'était pas assez...", sight=3)
trainer("foret", "fillette_f", "lass", 8, 8, "right", "Fillette", "Clara", [(25, 11), (35, 10)],
        "J'adore la forêt ! Et toi, tu aimes les combats ?", "Bon, tu es fort...", sight=5)
npc("foret", "item_f1", "ball", 27, 2, "down", kind="item", item="antidote", count=2, flag="item_foret1")
npc("foret", "item_f2", "ball", 8, 19, "down", kind="item", item="poke-ball", count=3, flag="item_foret2")
npc("foret", "item_f3", "ball", 18, 11, "down", kind="item", item="potion", count=2, flag="item_foret3")
npc("foret", "item_f4", "ball", 2, 22, "down", kind="item", item="leaf-stone", count=1, flag="item_foret4")
npc("foret", "item_f5", "ball", 27, 17, "down", kind="item", item="great-ball", count=3, flag="item_foret5")

# ---------------------------------------------------------------------------
# Plaine Sauvage
# ---------------------------------------------------------------------------
P = [
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    'T""""""""".....TTTTTTTTTT.....""""""""""T',
    'T"""""""""......TTRRRRTT......""""""""""T',
    'T""""""""".......T____T.......""""""""""T',
    'T"""""""""................f...""""""""""T',
    "T......................................T",
    "T..ff......,,,,,,,,,,,,,,,,,,,......ff.T",
    "T..........,..................,........T",
    'T..wwwwww..,..""""""""".......,..""""".T',
    'T.wwwwwwww.,..""""""""".......,..""""".T',
    'T.ww~~~~ww.,..""""""""".......,..""""".T',
    'T.ww~~~~ww.,..""""""""".......,..""""".T',
    "T.wwwwwwww.,..................,........T",
    "T..wwwwww..,..........S.......,........T",
    "T..........,,,,,,,,,,,,,,,,,,,,........T",
    'T"""""""..........,,...........""""""""T',
    'T"""""""..........,,...........""""""""T',
    'T"""""""...RR.....,,.....RR....""""""""T',
    "T...ff............,,.......f...........T",
    'T.....wwwwwwww....,,....""""""""""".....T',
    'T....ww~~~~~~ww...,,....""""""""""".....T',
    'T....ww~~~~~~ww...,,....""""""""""".....T',
    "T.....wwwwwwww....,,....................T",
    "T.................,,....................T",
    "TTTTTTTTTTTTTTTTTT,,TTTTTTTTTTTTTTTTTTTT",
]
P = [(r + "T" * 40)[:40] for r in P]
P = [r[:39] + "T" for r in P]
add("plaine", "Plaine Sauvage", P)
edge("foret", [14, 15], 0, "plaine", [18, 19], len(P) - 1, "up", "down")
building("plaine", "center", 31, 17, 5, 4, "centre_plaine", 6, 6)
warp("plaine", 19, 3, "grotte", 14, 22, "up")
warp("plaine", 20, 3, "grotte", 15, 22, "up")
maps["plaine"]["signs"] = {"22,13": "PLAINE SAUVAGE\nDe nombreux Pokémon rares vivent ici. Au nord : la Grotte Céleste."}
center("centre_plaine", "plaine", 33, 21)
maps["centre_plaine"]["npcs"].append({"id": "vendeur_p", "look": "clerk", "x": 2, "y": 4, "dir": "right", "kind": "shop",
    "stock": ["ultra-ball", "great-ball", "dusk-ball", "timer-ball", "quick-ball", "hyper-potion", "max-potion",
              "full-restore", "revive", "max-revive", "full-heal", "max-ether", "max-elixir", "rare-candy",
              "hp-up", "protein", "iron", "calcium", "zinc", "carbos", "pp-up", "pp-max", "max-repel",
              "fire-stone", "water-stone", "thunder-stone", "leaf-stone", "moon-stone", "linking-cord"]
             + [f"tm{n:02d}" for n in range(1, 51)]})

# Pokémon sauvages de la plaine : toutes les formes de base non légendaires.
CAVE_SPECIES = {41, 74, 50, 95, 35, 46, 66, 92, 104, 108, 27, 138, 140, 142}
grass, marsh = [], []
for sid, p in POKE.items():
    sid = int(sid)
    if p["evolves_from"] or p["legendary"] or sid in CAVE_SPECIES:
        continue
    bst = sum(p["base"])
    lvl = max(6, min(32, bst // 22))
    weight = max(2, p["catch"] // 3)
    entry = [sid, max(3, lvl - 3), lvl + 2, weight]
    (marsh if p["types"][0] == "water" else grass).append(entry)
maps["plaine"]["wild"] = {"grass": grass, "marsh": marsh}
maps["plaine"]["rate"] = 0.14

trainer("plaine", "expert_p1", "ace", 12, 7, "down", "Topdresseur", "Hugo",
        [(17, 22), (20, 22), (24, 23), (26, 24)], "Je suis venu ici pour m'entraîner. Montre-moi ce que tu vaux !",
        "Impressionnant... Tu iras loin.", sight=5, potions=1)
trainer("plaine", "expert_p2", "lass", 33, 13, "left", "Topdresseur", "Lou",
        [(36, 24), (40, 24), (121, 26), (45, 25)], "Mes Pokémon sont aussi élégants que puissants !",
        "Quelle défaite élégante...", sight=5, potions=1)
trainer("plaine", "montagnard_p", "hiker", 10, 18, "right", "Montagnard", "Roger",
        [(75, 25), (95, 26), (112, 27)], "Ho ho ! Les rochers, ça forge le caractère !",
        "Ça m'a secoué comme un éboulement !", sight=5, potions=1)
trainer("plaine", "scientifique_p", "scientist", 28, 23, "up", "Scientifique", "Taylor",
        [(82, 27), (101, 27), (137, 28), (110, 28)], "Mes recherches exigent des données de combat !",
        "Données... insuffisantes...", sight=4, potions=1)
trainer("plaine", "expert_p3", "ace", 30, 2, "down", "Expert", "Sacha",
        [(130, 33), (59, 33), (65, 34), (112, 33), (143, 34), (6, 35)],
        "Tu as réussi à venir jusqu'ici ? Alors affronte le meilleur Dresseur de la plaine !",
        "Incroyable... Tu es digne de la Grotte Céleste.", sight=4, potions=3)
npc("plaine", "item_p1", "ball", 1, 23, "down", kind="item", item="rare-candy", count=1, flag="item_plaine1")
npc("plaine", "item_p2", "ball", 38, 1, "down", kind="item", item="water-stone", count=1, flag="item_plaine2")
npc("plaine", "item_p3", "ball", 38, 23, "down", kind="item", item="thunder-stone", count=1, flag="item_plaine3")
npc("plaine", "item_p4", "ball", 1, 5, "down", kind="item", item="ultra-ball", count=5, flag="item_plaine4")
npc("plaine", "ranger", "girl", 20, 15, "down", text=["Les Pokémon Eau vivent dans les marais.", "Les plus rares se montrent très peu... Il faut de la patience !"])

# ---------------------------------------------------------------------------
# Grotte Céleste
# ---------------------------------------------------------------------------
G = [
    "##############################",
    "#____#######______#######____#",
    "#____#######______#######____#",
    "#___________________________##",
    "####____##########______######",
    "####____##########______######",
    "#________________#______#____#",
    "#__######________#______#____#",
    "#__######__R_____#_____________#",
    "#__######________#######_____#",
    "#________________________#___#",
    "#####_____#####____#####_#___#",
    "#####_____#####____#####_#___#",
    "#___________________________##",
    "#__#####____#######____######",
    "#__#####____#######_____#####",
    "#________________________####",
    "######____________________###",
    "######___#####_____#####___##",
    "#________#####_____#####___##",
    "#________#####_____________##",
    "#_____________________######",
    "#############__###############",
    "##############################",
]
G = [(r + "#" * 30)[:30] for r in G]
add("grotte", "Grotte Céleste", G, outdoor=False, cave=True)
maps["grotte"]["rows"][22] = "#############__###############"
warp("grotte", 13, 22, "plaine", 19, 4, "down")
warp("grotte", 14, 22, "plaine", 20, 4, "down")
maps["grotte"]["rows"][22] = "##############__##############"
maps["grotte"]["warps"] = []
warp("grotte", 14, 22, "plaine", 19, 4, "down")
warp("grotte", 15, 22, "plaine", 20, 4, "down")
maps["grotte"]["wild"] = {"cave": [[41, 18, 26, 30], [74, 18, 26, 25], [50, 18, 25, 15], [95, 20, 28, 8],
                                   [35, 18, 24, 8], [46, 18, 24, 10], [66, 18, 25, 10], [92, 20, 26, 8],
                                   [104, 20, 26, 8], [108, 22, 27, 4], [27, 18, 24, 10], [42, 26, 30, 6],
                                   [75, 26, 30, 6], [138, 25, 28, 2], [140, 25, 28, 2], [142, 26, 30, 2]]}
maps["grotte"]["rate"] = 0.08
npc("grotte", "artikodin", "legend", 2, 1, "down", kind="legend", species=144, level=50, flag="leg_144",
    text=["Une silhouette glaciale vous fixe..."])
npc("grotte", "electhor", "legend", 27, 1, "down", kind="legend", species=145, level=50, flag="leg_145",
    text=["L'air crépite d'électricité..."])
npc("grotte", "sulfura", "legend", 28, 7, "left", kind="legend", species=146, level=50, flag="leg_146",
    text=["Une chaleur écrasante envahit la grotte..."])
npc("grotte", "mewtwo", "legend", 1, 19, "right", kind="legend", species=150, level=70, flag="leg_150",
    text=["Une présence terrifiante... Un Pokémon créé par l'homme vous observe."])
npc("grotte", "mew", "legend", 27, 13, "left", kind="legend", species=151, level=30, flag="leg_151",
    text=["Un petit Pokémon rose flotte joyeusement..."])
npc("grotte", "montagnard_g", "hiker", 6, 10, "right", kind="trainer", sight=4, trainer={
    "name": "Montagnard Bernard", "team": team((74, 30), (75, 32), (95, 33), (76, 36)),
    "intro": "Cette grotte cache des Pokémon de légende ! Mais d'abord, moi !",
    "defeat": "Tu as la force d'affronter les légendes...", "money": 36 * 36, "potions": 2})
npc("grotte", "item_g1", "ball", 28, 1, "down", kind="item", item="master-ball", count=1, flag="item_grotte1")
npc("grotte", "item_g2", "ball", 1, 16, "down", kind="item", item="rare-candy", count=3, flag="item_grotte2")
npc("grotte", "item_g3", "ball", 21, 4, "down", kind="item", item="moon-stone", count=2, flag="item_grotte3")
npc("grotte", "item_g4", "ball", 1, 6, "down", kind="item", item="fire-stone", count=1, flag="item_grotte4")
npc("grotte", "item_g5", "ball", 28, 10, "down", kind="item", item="max-revive", count=2, flag="item_grotte5")

# ---------------------------------------------------------------------------
# Vérifications
# ---------------------------------------------------------------------------
for mid, m in maps.items():
    check(mid, m["rows"])
    m["w"], m["h"] = len(m["rows"][0]), len(m["rows"])
    for b in m["buildings"]:
        assert b["x"] + b["w"] <= m["w"] and b["y"] + b["h"] <= m["h"], (mid, b)
    for wp in m["warps"]:
        assert wp["to"] in maps, (mid, wp)
        t = maps[wp["to"]]
        assert 0 <= wp["tx"] < len(t["rows"][0]) and 0 <= wp["ty"] < len(t["rows"]), (mid, wp)
        assert t["rows"][wp["ty"]][wp["tx"]] in WALK, (mid, wp, repr(t["rows"][wp["ty"]][wp["tx"]]))
    for b in m["buildings"]:
        if b["to"] in maps:
            t = maps[b["to"]]
            assert t["rows"][b["ty"]][b["tx"]] in WALK, (mid, b)
    for n in m["npcs"]:
        assert 0 <= n["x"] < m["w"] and 0 <= n["y"] < m["h"], (mid, n["id"])
        c = m["rows"][n["y"]][n["x"]]
        if n.get("kind") != "starter":
            assert c in WALK, (mid, n["id"], repr(c))


BLOCKED_NPC = ("trainer", "legend", "item", "starter")


def reachable(mid, start):
    m = maps[mid]
    blocked = set()
    for b in m["buildings"]:
        for y in range(b["y"], b["y"] + b["h"]):
            for x in range(b["x"], b["x"] + b["w"]):
                blocked.add((x, y))
    for n in m["npcs"]:
        blocked.add((n["x"], n["y"]))
    seen = {start}
    todo = [start]
    while todo:
        x, y = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < m["w"] and 0 <= ny < m["h"] and (nx, ny) not in seen and (nx, ny) not in blocked:
                c = m["rows"][ny][nx]
                if c in WALK:
                    seen.add((nx, ny))
                    todo.append((nx, ny))
    return seen


for mid, m in maps.items():
    entries = [(w["tx"], w["ty"]) for mm in maps.values() for w in mm["warps"] if w["to"] == mid]
    entries += [(b["tx"], b["ty"]) for mm in maps.values() for b in mm["buildings"] if b["to"] == mid]
    if not entries:
        continue
    r = reachable(mid, entries[0])
    for e in entries:
        assert e in r, (mid, "entrée inaccessible", e)
    for w in m["warps"]:
        near = [(w["x"] + dx, w["y"] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        assert (w["x"], w["y"]) in r or any(n in r for n in near), (mid, "sortie inaccessible", w)
    for b in m["buildings"]:
        door = (b["x"] + b["w"] // 2, b["y"] + b["h"])
        assert door in r, (mid, "porte inaccessible", b)
    for n in m["npcs"]:
        near = [(n["x"] + dx, n["y"] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (0, 2))]
        assert any(p in r for p in near), (mid, "PNJ inaccessible", n["id"])

json.dump(maps, open(f"{DATA}/maps.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(maps), "cartes")
