"""Route 1 : sol (une image), objets triés en profondeur et grille de collisions (JSON).
Usage : python3 make_map.py   (après make_art.py)"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from pixel import disc, mix, new, put, rect, rng

ROOT = os.path.join(os.path.dirname(__file__), "..")
T = 32
W, H = 32, 46

G_BASE = (122, 194, 90)
G_LIGHT = (140, 208, 104)
G_DARK = (106, 178, 80)
FOREST_FLOOR = (78, 146, 76)
DIRT = (206, 178, 130)
DIRT_L = (220, 194, 150)
DIRT_D = (184, 156, 110)
EDGE_L = (170, 222, 124)
LEDGE_TOP = (150, 214, 110)
LEDGE_FACE = (92, 156, 74)
LEDGE_DARK = (58, 110, 58)

PATH = [(15.5, -1), (15.5, 6), (11.5, 11), (11.5, 18), (19.5, 25), (19.5, 32), (15.5, 38), (15.5, 47)]
PATH_W = 1.6
GRASS_RECTS = [(4, 3, 6, 4), (21, 2, 7, 5), (4, 14, 5, 5), (22, 12, 6, 5), (5, 25, 8, 5), (24, 27, 4, 6), (4, 36, 7, 4), (22, 39, 5, 3)]
LEDGES = [(9, 4, 27), (21, 4, 28), (34, 4, 28)]
CLEARING = (19, 35, 9, 3)  # terre battue (x, y, l, h)


def open_bounds(y, r):
    """Limites gauche/droite de la zone praticable à la ligne y (bord de forêt irrégulier)."""
    if y <= 1 or y >= H - 2:
        return 14, 17
    left = 3 + (1 if math.sin(y * 0.7) > 0.6 else 0) + (1 if y in (2, H - 3) else 0)
    right = W - 4 - (1 if math.cos(y * 0.5) > 0.7 else 0) - (1 if y in (2, H - 3) else 0)
    return left, right


def dist_to_path(x, y):
    best = 99.0
    for (x1, y1), (x2, y2) in zip(PATH, PATH[1:]):
        dx, dy = x2 - x1, y2 - y1
        t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(x - (x1 + t * dx), y - (y1 + t * dy)))
    return best


def build_grid():
    r = rng(11)
    g = [["#"] * W for _ in range(H)]
    for y in range(H):
        lo, hi = open_bounds(y, r)
        for x in range(lo, hi + 1):
            g[y][x] = "."
    for y in range(H):
        for x in range(W):
            if g[y][x] == "." and dist_to_path(x + 0.5, y + 0.5) <= PATH_W:
                g[y][x] = ":"
    cx, cy, cw, ch = CLEARING
    for y in range(cy, cy + ch):
        for x in range(cx, cx + cw):
            if g[y][x] != "#":
                g[y][x] = ":"
    for (x0, y0, w, h) in GRASS_RECTS:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if g[y][x] == ".":
                    g[y][x] = '"'
    for (y, x0, x1) in LEDGES:
        for x in range(x0, x1 + 1):
            if g[y][x] in '."':
                g[y][x] = "="
    return g


def render_ground(g):
    r = rng(5)
    im = Image.new("RGBA", (W * T, H * T), G_BASE + (255,))
    px = im.load()
    # Herbe : petits carrés de 2 pixels plus clairs / plus foncés, comme dans PRO.
    for _ in range(W * H * 5):
        x, y = r.randrange(0, W * T - 2, 2), r.randrange(0, H * T - 2, 2)
        c = G_LIGHT if r.random() < 0.55 else G_DARK
        for dy in (0, 1):
            for dx in (0, 1):
                px[x + dx, y + dy] = c + (255,)
    for y in range(H):
        for x in range(W):
            if g[y][x] == "#":
                rect(im, x * T, y * T, T, T, FOREST_FLOOR)
    # Terre : masque des cases flouté puis seuillé = bords arrondis et courbes, comme dans PRO.
    from PIL import ImageFilter
    mask = Image.new("L", (W * T, H * T), 0)
    mp = mask.load()
    for y in range(H):
        for x in range(W):
            if g[y][x] == ":":
                for yy in range(y * T, y * T + T):
                    for xx in range(x * T, x * T + T):
                        mp[xx, yy] = 255
    mask = mask.filter(ImageFilter.GaussianBlur(9))
    mp = mask.load()
    for y in range(H * T):
        for x in range(W * T):
            if mp[x, y] >= 128:
                px[x, y] = DIRT + (255,)
    # Grain de la terre.
    for _ in range(W * H * 3):
        x, y = r.randrange(0, W * T - 2, 2), r.randrange(0, H * T - 2, 2)
        if px[x, y][:3] == DIRT:
            c = DIRT_L if r.random() < 0.5 else DIRT_D
            px[x, y] = c + (255,)
            px[x + 1, y] = c + (255,)
    # Bords de la terre : arrondis, liseré d'herbe claire à l'extérieur, ombre à l'intérieur.
    def is_dirt(x, y):
        return 0 <= x < W * T and 0 <= y < H * T and px[x, y][:3] in (DIRT, DIRT_L, DIRT_D)
    src = [[is_dirt(x, y) for x in range(W * T)] for y in range(H * T)]
    for y in range(H * T):
        for x in range(W * T):
            if src[y][x]:
                near = any(not src[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                           if 0 <= x + dx < W * T and 0 <= y + dy < H * T)
                if near:
                    px[x, y] = DIRT_D + (255,)
            else:
                near = any(src[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2))
                           if 0 <= x + dx < W * T and 0 <= y + dy < H * T)
                if near and px[x, y][:3] != FOREST_FLOOR:
                    px[x, y] = EDGE_L + (255,)
    # Rebords : on saute vers le bas.
    for y in range(H):
        for x in range(W):
            if g[y][x] != "=":
                continue
            bx, by = x * T, y * T
            left = x == 0 or g[y][x - 1] != "="
            right = x == W - 1 or g[y][x + 1] != "="
            x0 = bx + (6 if left else 0)
            x1 = bx + T - (6 if right else 0)
            # Petite falaise herbeuse : bord clair, face ombrée avec des touffes, ombre portée.
            rect(im, x0, by + 8, x1 - x0, 3, LEDGE_TOP)
            rect(im, x0, by + 11, x1 - x0, 11, LEDGE_FACE)
            for k in range(x0, x1, 4):
                h = 3 + ((k * 7) % 5)
                rect(im, k, by + 11, 2, h, mix(LEDGE_FACE, LEDGE_TOP, 0.5))
            rect(im, x0, by + 20, x1 - x0, 2, LEDGE_DARK)
            rect(im, x0 + 1, by + 22, x1 - x0 - 2, 3, mix(G_BASE, LEDGE_DARK, 0.45))
            if left:
                rect(im, x0 - 1, by + 9, 1, 13, LEDGE_DARK)
            if right:
                rect(im, x1, by + 9, 1, 13, LEDGE_DARK)
    # Fleurs.
    fl = Image.open(os.path.join(ROOT, "assets", "world", "flowers.png"))
    spots = [(7, 8), (25, 7), (8, 20), (27, 20), (13, 31), (26, 34), (9, 42), (21, 44), (5, 12), (17, 28)]
    for (x, y) in spots:
        if g[y][x] == ".":
            im.alpha_composite(fl, (x * T, y * T + 2))
    return im


def objects(g):
    """Arbres de la forêt (denses, qui se chevauchent), arbres isolés, décors. Chaque objet bloque des cases."""
    r = rng(21)
    out = []
    block = set()
    trees = [f"world/tree_{k}.png" for k in range(6)]
    pines = [f"world/pine_{k}.png" for k in range(3)]
    # Forêt : un arbre par bloc de 2 x 2 cases contenant de la forêt, posé sur les cases de forêt du bloc
    # (jamais sur une case praticable), en quinconce et un peu décalé pour un feuillage dense et naturel.
    for y in range(-1, H + 1, 2):
        for x in range(-1 + (y // 2) % 2, W + 1, 2):
            cells = [(cx, cy) for cx, cy in [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
                     if not (0 <= cx < W and 0 <= cy < H) or g[cy][cx] == "#"]
            if not cells:
                continue
            bx = sum(c[0] for c in cells) / len(cells) + 0.5
            by = max(c[1] for c in cells) + 1
            full = len(cells) == 4
            pine = r.random() < 0.28
            tex = r.choice(pines) if pine else r.choice(trees)
            if not pine and full and r.random() < 0.06:
                tex = "world/tree_sleepy.png"
            j = 6 if full else 2
            out.append({"tex": tex, "x": int(bx * T) + r.randint(-j, j), "y": int(by * T) - 4 + r.randint(-j, j // 2)})
    # Arbres isolés dans la route (2 x 2 cases).
    for (x, y, kind) in [(6, 23, "tree"), (26, 22, "pine"), (8, 32, "tree"), (25, 15, "tree")]:
        tex = r.choice(pines) if kind == "pine" else r.choice(trees)
        out.append({"tex": tex, "x": (x + 1) * T, "y": (y + 2) * T - 2})
        for cx, cy in [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]:
            block.add((cx, cy))
    deco = [("world/stump.png", 25, 9, 1), ("world/mushrooms.png", 5, 11, 1), ("world/mushrooms.png", 27, 26, 1),
            ("world/bush.png", 27, 37, 1), ("world/bush.png", 4, 30, 1), ("world/sign.png", 12, 39, 1),
            ("world/log.png", 21, 18, 2), ("world/stump.png", 9, 4, 1), ("world/mushrooms.png", 20, 41, 1)]
    for tex, x, y, w in deco:
        out.append({"tex": tex, "x": x * T + w * T // 2, "y": (y + 1) * T - 2})
        for k in range(w):
            block.add((x + k, y))
    return out, block


def main():
    g = build_grid()
    objs, block = objects(g)
    g_ground = [row[:] for row in g]  # le sol est dessiné d'après le terrain, sans les objets
    for (x, y) in block:
        if g[y][x] in '."':
            g[y][x] = "X"
        elif g[y][x] == ":":
            g[y][x] = "X"
    ground = render_ground(g_ground)
    ground.save(os.path.join(ROOT, "assets", "world", "route1_ground.png"))
    grass = []
    rr = rng(3)
    for y in range(H):
        for x in range(W):
            if g[y][x] == '"':
                grass.append({"tex": f"world/grass_{rr.randint(0, 3)}.png", "x": x * T + T // 2, "y": (y + 1) * T + 1})
    data = {"name": "Route 1", "tile": T, "w": W, "h": H, "rows": ["".join(r) for r in g],
            "objects": objs, "grass": grass, "start": [15, 40],
            "sign": {"x": 12, "y": 39, "text": "ROUTE 1\nBOURG PALETTE ↓   ↑ JADIELLE"},
            "jeremy": [23, 36]}
    with open(os.path.join(ROOT, "data", "route1.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    print("\n".join(data["rows"]))
    # Aperçu complet (sol + objets triés en profondeur) pour vérifier la carte.
    prev = ground.copy()
    cache = {}
    for o in sorted(objs + grass, key=lambda o: o["y"]):
        im = cache.setdefault(o["tex"], Image.open(os.path.join(ROOT, "assets", o["tex"])))
        prev.alpha_composite(im, (int(o["x"] - im.width // 2), int(o["y"] - im.height)))
    prev.save(os.path.join(os.path.dirname(__file__), "apercu_route1.png"))
    print(len(objs), "objets,", len(grass), "touffes d'herbe")


if __name__ == "__main__":
    main()
