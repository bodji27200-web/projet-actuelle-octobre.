"""Outils de génération de cartes (villes, routes, donjons, intérieurs) pour build_world.py.

Légende des tuiles :
  . herbe   , chemin   " hautes herbes   T arbre   ~ eau   f fleurs   = barrière   S panneau
  v rebord (saut vers le bas)   : sable   R rocher   w marais (Pokémon Eau)   H pont (planches)
  _ sol de grotte / donjon   # paroi   < escalier montant   > escalier descendant
  o parquet   q carrelage   u sol violet (tour)   W mur   m tapis de sortie   X table   B étagère
  P PC   C comptoir Centre   K comptoir Boutique   b lit   t télé   p plante   M machine   O statue
  (espace) vide
"""
import random

WALK = set('.,"f v:w_oqmuH<>')
BLOCK_NPC_OK = WALK


class Map:
    def __init__(self, mid, name, w, h, fill=".", outdoor=True, theme="", music="route"):
        self.id = mid
        self.name = name
        self.w = w
        self.h = h
        self.g = [[fill] * w for _ in range(h)]
        self.outdoor = outdoor
        self.theme = theme
        self.music = music
        self.cave = False
        self.wx = None
        self.wy = None
        self.region = mid
        self.buildings = []
        self.warps = []
        self.npcs = []
        self.signs = {}
        self.wild = {}
        self.rate = 0.12
        self.battle_bg = "grass"
        self.heal = False
        self.protected = set()  # cases à ne pas recouvrir (chemins, portes...)
        self.doors = set()
        self.realm = "kanto"
        self.extra = {}

    # -- dessin ---------------------------------------------------------------
    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def set(self, x, y, c, force=False):
        if self.inside(x, y) and (force or (x, y) not in self.protected):
            self.g[y][x] = c

    def get(self, x, y):
        return self.g[y][x] if self.inside(x, y) else "T"

    def rect(self, x, y, w, h, c, force=False):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c, force)

    def border(self, c="T", t=1):
        for y in range(self.h):
            for x in range(self.w):
                if x < t or y < t or x >= self.w - t or y >= self.h - t:
                    self.g[y][x] = c

    def path(self, x0, y0, x1, y1, c=",", width=2, protect=True):
        """Chemin en L (horizontal puis vertical), largeur 2."""
        def put(x, y):
            for dx in range(width):
                for dy in range(width):
                    if self.inside(x + dx, y + dy):
                        self.g[y + dy][x + dx] = c
                        if protect:
                            self.protected.add((x + dx, y + dy))
        x, y = x0, y0
        put(x, y)
        while x != x1:
            x += 1 if x1 > x else -1
            put(x, y)
        while y != y1:
            y += 1 if y1 > y else -1
            put(x, y)

    def rows(self):
        return ["".join(r) for r in self.g]

    def building(self, kind, x, y, w, h, to, tx, ty, label=""):
        self.buildings.append({"kind": kind, "x": x, "y": y, "w": w, "h": h, "to": to, "tx": tx, "ty": ty, "label": label})
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.protected.add((xx, yy))
                if self.inside(xx, yy) and self.g[yy][xx] in "T~\"wR":
                    self.g[yy][xx] = "."
        door = (x + w // 2, y + h)
        self.protected.add(door)
        self.doors.add(door)
        if self.get(*door) not in WALK or self.get(*door) in '"w':
            self.set(door[0], door[1], ",", True)
        return door

    def warp(self, x, y, to, tx, ty, d="down"):
        self.warps.append({"x": x, "y": y, "to": to, "tx": tx, "ty": ty, "dir": d})

    def npc(self, nid, look, x, y, d="down", **kw):
        n = {"id": nid, "look": look, "x": x, "y": y, "dir": d}
        n.update(kw)
        self.npcs.append(n)
        self.protected.add((x, y))
        if self.g[y][x] not in WALK:
            self.g[y][x] = "."
        return n

    def to_json(self):
        return {"name": self.name, "w": self.w, "h": self.h, "rows": self.rows(), "buildings": self.buildings,
                "warps": self.warps, "npcs": self.npcs, "signs": self.signs, "wild": self.wild, "rate": self.rate,
                "outdoor": self.outdoor, "cave": self.cave, "theme": self.theme, "music": self.music,
                "wx": self.wx, "wy": self.wy, "region": self.region, "battle_bg": self.battle_bg, "heal": self.heal,
                "realm": self.realm, **self.extra}


# ---------------------------------------------------------------------------
# Remplissage décoratif
# ---------------------------------------------------------------------------

def free_area(m, x, y, w, h, allowed=".", margin=0):
    for yy in range(y - margin, y + h + margin):
        for xx in range(x - margin, x + w + margin):
            if not m.inside(xx, yy) or m.g[yy][xx] not in allowed or (xx, yy) in m.protected:
                return False
    return True


def scatter(m, rng, c, count, wmin, wmax, hmin, hmax, allowed=".", margin=1):
    placed = []
    for _ in range(count * 30):
        if len(placed) >= count:
            break
        w = rng.randint(wmin, wmax)
        h = rng.randint(hmin, hmax)
        x = rng.randint(1, max(1, m.w - w - 1))
        y = rng.randint(1, max(1, m.h - h - 1))
        if free_area(m, x, y, w, h, allowed, margin):
            m.rect(x, y, w, h, c)
            placed.append((x, y, w, h))
    return placed


def sprinkle(m, rng, c, count, allowed="."):
    n = 0
    for _ in range(count * 20):
        if n >= count:
            break
        x, y = rng.randint(1, m.w - 2), rng.randint(1, m.h - 2)
        if m.g[y][x] in allowed and (x, y) not in m.protected:
            m.g[y][x] = c
            n += 1


def reachable(m, start, extra_blocked=()):
    blocked = set(extra_blocked)
    for b in m.buildings:
        for yy in range(b["y"], b["y"] + b["h"]):
            for xx in range(b["x"], b["x"] + b["w"]):
                blocked.add((xx, yy))
    for n in m.npcs:
        if not n.get("ghost"):
            blocked.add((n["x"], n["y"]))
    seen = {start}
    todo = [start]
    while todo:
        x, y = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in seen or (nx, ny) in blocked or not m.inside(nx, ny):
                continue
            c = m.g[ny][nx]
            if c == "v" and dy != 1:
                continue
            if c in WALK:
                seen.add((nx, ny))
                todo.append((nx, ny))
    return seen


# ---------------------------------------------------------------------------
# Générateurs
# ---------------------------------------------------------------------------

def make_route(mid, name, w, h, exits, seed, grass=0.22, water=False, trees=0.08, ledges=0, flowers=6, theme=""):
    """exits : liste de (x, y) d'entrée de chemin (sur les bords). Le chemin relie toutes les sorties."""
    rng = random.Random(seed)
    m = Map(mid, name, w, h, theme=theme)
    m.border("T", 1)
    cx, cy = w // 2 - 1, h // 2 - 1
    # point de passage aléatoire pour un chemin sinueux
    wpx = max(2, min(w - 4, cx + rng.randint(-w // 5, w // 5)))
    wpy = max(2, min(h - 4, cy + rng.randint(-h // 5, h // 5)))
    for (ex, ey) in exits:
        sx = min(max(ex, 0), w - 2)
        sy = min(max(ey, 0), h - 2)
        if ex == 0 or ex >= w - 2:
            m.path(sx, sy, wpx, sy)
            m.path(wpx, sy, wpx, wpy)
        else:
            m.path(sx, sy, sx, wpy)
            m.path(sx, wpy, wpx, wpy)
    if water:
        for _ in range(2):
            pw, ph = rng.randint(5, 9), rng.randint(4, 6)
            spots = scatter(m, rng, "w", 1, pw, pw, ph, ph, ".", 1)
            for (x, y, ww, hh) in spots:
                m.rect(x + 1, y + 1, ww - 2, hh - 2, "~")
    area = (w - 2) * (h - 2)
    target = int(area * grass)
    tries = 0
    while target > 0 and tries < 80:
        tries += 1
        pl = scatter(m, rng, '"', 1, 3, 8, 2, 5, ".", 1)
        for (_, _, ww, hh) in pl:
            target -= ww * hh
    scatter(m, rng, "T", int(area * trees / 6), 1, 3, 1, 2, ".", 1)
    for _ in range(ledges):
        ly = rng.randint(3, h - 4)
        for x in range(1, w - 1):
            if m.g[ly][x] == "." and (x, ly) not in m.protected:
                m.g[ly][x] = "v"
    sprinkle(m, rng, "f", flowers)
    sprinkle(m, rng, "R", rng.randint(0, 3))
    return m


def make_bridge_route(mid, name, w, h, exits, seed, theme=""):
    """Route maritime : eau, ponton en planches, îlots et marais (Pokémon Eau)."""
    rng = random.Random(seed)
    m = Map(mid, name, w, h, fill="~", theme=theme)
    cx, cy = w // 2 - 1, h // 2 - 1
    for (ex, ey) in exits:
        sx, sy = min(max(ex, 0), w - 2), min(max(ey, 0), h - 2)
        if ex == 0 or ex >= w - 2:
            m.path(sx, sy, cx, sy, "H")
            m.path(cx, sy, cx, cy, "H")
        else:
            m.path(sx, sy, sx, cy, "H")
            m.path(sx, cy, cx, cy, "H")
    for _ in range(4):
        iw, ih = rng.randint(4, 7), rng.randint(3, 5)
        for (x, y, ww, hh) in scatter(m, rng, ".", 1, iw, iw, ih, ih, "~", 1):
            m.rect(x + 1, y + 1, max(1, ww - 2), max(1, hh - 2), '"')
            m.set(x, y, "T")
    scatter(m, rng, "w", 6, 2, 4, 2, 3, "~", 0)
    # chaque îlot/marais doit toucher le ponton : on relie par des planches
    return m


def make_town(mid, name, w, h, exits, seed, center, music="town"):
    rng = random.Random(seed)
    m = Map(mid, name, w, h, music=music)
    m.border("T", 1)
    cx, cy = center
    for (ex, ey) in exits:
        sx, sy = min(max(ex, 0), w - 2), min(max(ey, 0), h - 2)
        if ex == 0 or ex >= w - 2:
            m.path(sx, sy, cx, sy)
            m.path(cx, sy, cx, cy)
        else:
            m.path(sx, sy, sx, cy)
            m.path(sx, cy, cx, cy)
    m._rng = rng
    return m


def connect_door(m, door):
    """Relie une porte au chemin le plus proche."""
    best = None
    for (x, y) in list(m.protected):
        if m.g[y][x] == "," and (x, y) != door and (x, y) not in m.doors:
            d = abs(x - door[0]) + abs(y - door[1])
            if best is None or d < best[0]:
                best = (d, x, y)
    if best:
        m.path(door[0], door[1], best[1], door[1], ",", 1)
        m.path(best[1], door[1], best[1], best[2], ",", 1)


def decorate_town(m, flowers=10, trees=4, fences=2):
    rng = m._rng
    sprinkle(m, rng, "f", flowers)
    scatter(m, rng, "T", trees, 1, 2, 1, 2, ".", 1)
    for (x, y, w, h) in scatter(m, rng, "=", fences, 4, 7, 1, 1, ".", 1):
        pass


def make_cave(mid, name, w, h, seed, theme="cave", rooms=7, building=False):
    """Donjon : salles reliées par des couloirs. Renvoie la carte et la liste des centres de salles."""
    rng = random.Random(seed)
    wall, floor = ("W", "q") if building else ("#", "_")
    if theme == "tower":
        floor = "u"
    m = Map(mid, name, w, h, fill=wall, outdoor=False, theme=theme, music="cave" if not building else "dungeon")
    m.cave = not building
    m.battle_bg = "cave" if not building else "indoor"
    centers = []
    for _ in range(rooms * 20):
        if len(centers) >= rooms:
            break
        rw, rh = rng.randint(5, 9), rng.randint(4, 7)
        x, y = rng.randint(1, w - rw - 2), rng.randint(1, h - rh - 2)
        if all(m.g[yy][xx] == wall for yy in range(y - 1, y + rh + 1) for xx in range(x - 1, x + rw + 1)):
            m.rect(x, y, rw, rh, floor)
            centers.append((x + rw // 2, y + rh // 2))
    centers.sort(key=lambda c: (c[1], c[0]))
    for a, b in zip(centers, centers[1:]):
        m.path(a[0], a[1], b[0], b[1], floor, 2, protect=False)
    if not building:
        for _ in range(int(w * h / 60)):
            x, y = rng.randint(1, w - 2), rng.randint(1, h - 2)
            if m.g[y][x] == floor and m.g[y - 1][x] == floor and m.g[y + 1][x] == floor:
                m.g[y][x] = "R"
    return m, centers


def interior(mid, name, rows, music="indoor"):
    m = Map(mid, name, len(rows[0]), len(rows), outdoor=False, music=music)
    m.g = [list(r) for r in rows]
    m.battle_bg = "indoor"
    return m
