"""Graphismes du monde, dessinés par programme dans le style de Pokémon Revolution Online :
arbres ronds et sapins en grappes ombrées, hautes herbes en étoile, champignons, souche, tronc, buisson à baies,
fleurs, panneau, personnages (joueur, autre joueur) et Reptincel qui suit le joueur.
Usage : python3 make_art.py   (écrit dans ../assets)"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixel import (disc, get, inner_edge, line, mix, new, outline, paste, poly, put, rect, rgb, rng, shadow)

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

# --- Palette (jour ; la nuit est une teinte appliquée par le jeu) -------------------------------------------
LEAF_O = (22, 62, 44)
LEAF_D = (38, 98, 62)
LEAF_M = (54, 128, 74)
LEAF_L = (84, 162, 88)
LEAF_H = (124, 192, 104)
PINE_O = (20, 58, 52)
PINE_D = (34, 92, 72)
PINE_M = (50, 122, 86)
PINE_L = (82, 156, 100)
TRUNK = (118, 84, 58)
TRUNK_D = (84, 58, 42)
TRUNK_L = (152, 114, 76)
TRUNK_O = (52, 36, 30)
GRASS_O = (26, 80, 52)
GRASS_D = (42, 118, 70)
GRASS_M = (58, 144, 80)
GRASS_L = (98, 182, 94)


def save(im, *path):
    p = os.path.join(OUT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)


# =============================================================================================================
# Végétation
# =============================================================================================================

def blob(im, cx, cy, r, dark, mid, light, high):
    """Grappe de feuillage : cercle sombre, puis plus clair vers le haut-gauche (lumière du soleil)."""
    disc(im, cx, cy, r, dark)
    disc(im, cx - 1, cy - 1.5, r - 1.5, mid)
    disc(im, cx - 2.5, cy - 3.5, r * 0.55, light)
    if r >= 9:
        disc(im, cx - 4, cy - 5, r * 0.25, high)


def round_tree(seed, w=96, h=108, sleepy=False):
    r = rng(seed)
    im = new(w, h)
    # Tronc et racines (dessinés d'abord : le feuillage les recouvre en haut).
    tx = w // 2
    rect(im, tx - 7, 70, 14, 28, TRUNK)
    rect(im, tx - 7, 70, 4, 28, TRUNK_L)
    rect(im, tx + 3, 70, 4, 28, TRUNK_D)
    poly(im, [(tx - 12, 99), (tx - 7, 88), (tx - 5, 99)], TRUNK)
    poly(im, [(tx + 12, 99), (tx + 7, 88), (tx + 5, 99)], TRUNK_D)
    rect(im, tx - 12, 97, 25, 3, TRUNK_D)
    # Feuillage : grappes de l'arrière (haut) vers l'avant (bas).
    cx, cy = w / 2, 44
    bumps = []
    for k in range(9):
        a = -math.pi / 2 + k * 2 * math.pi / 9 + r.uniform(-0.15, 0.15)
        bumps.append((cx + math.cos(a) * 28 + r.uniform(-2, 2), cy + math.sin(a) * 25 + r.uniform(-2, 2), r.uniform(12.5, 15.5)))
    bumps.append((cx, cy, 24))
    for k in range(4):
        bumps.append((cx + r.uniform(-14, 14), cy + r.uniform(-8, 14), r.uniform(10, 13)))
    bumps.sort(key=lambda b: b[1])
    for bx, by, br in bumps:
        blob(im, bx, by, br, LEAF_D, LEAF_M, LEAF_L, LEAF_H)
    # Ombre du bas du feuillage.
    for y in range(h):
        for x in range(w):
            p = get(im, x, y)
            if p[3] and y > cy + 18 and p[:3] in (LEAF_M, LEAF_L):
                put(im, x, y, LEAF_D if (x + y) % 2 == 0 or y > cy + 24 else LEAF_M)
    # Petites feuilles claires éparses.
    for _ in range(26):
        x, y = r.randint(10, w - 10), r.randint(16, 64)
        if get(im, x, y)[3] and get(im, x, y)[:3] != TRUNK:
            put(im, x, y, LEAF_H if y < cy else LEAF_L)
    if sleepy:
        _sleepy_face(im, int(cx - 14 + r.randint(-6, 6)), int(cy + 2))
    outline(im, LEAF_O)
    return im


def _sleepy_face(im, x, y):
    """Petit Pokémon endormi caché dans le feuillage (comme dans la Forêt de Jade de PRO)."""
    body = (96, 128, 200)
    disc(im, x + 10, y + 6, 10, body, 7)
    disc(im, x + 9, y + 4, 8, (122, 154, 220), 5)
    line(im, x + 4, y + 6, x + 7, y + 6, (40, 50, 96))
    line(im, x + 12, y + 6, x + 15, y + 6, (40, 50, 96))
    line(im, x + 8, y + 9, x + 11, y + 9, (40, 50, 96))
    for k, (zx, zy) in enumerate([(x + 19, y - 4), (x + 23, y - 9)]):
        s = 3 + k
        line(im, zx, zy, zx + s, zy, (190, 210, 255))
        line(im, zx + s, zy, zx, zy + s, (190, 210, 255))
        line(im, zx, zy + s, zx + s, zy + s, (190, 210, 255))


def pine_tree(seed, w=72, h=118):
    r = rng(seed)
    im = new(w, h)
    tx = w // 2
    rect(im, tx - 5, 92, 10, 22, TRUNK)
    rect(im, tx - 5, 92, 3, 22, TRUNK_L)
    rect(im, tx + 2, 92, 3, 22, TRUNK_D)
    tiers = 5
    for i in range(tiers):
        top = 4 + i * 16
        bot = top + 30
        half = 10 + i * 6.5
        teeth = 3 + i
        pts = [(tx, top)]
        for k in range(teeth + 1):
            x = tx + half - k * 2 * half / teeth
            pts.append((x, bot - (0 if k % 1 == 0 else 3)))
            if k < teeth:
                pts.append((x - half / teeth, bot - 5 + r.randint(-1, 1)))
        poly(im, [(tx, top), (tx + half, bot), (tx - half, bot)], PINE_D)
        # Bord inférieur en dents de scie.
        for k in range(teeth):
            x0 = tx - half + k * 2 * half / teeth
            poly(im, [(x0, bot - 1), (x0 + half / teeth, bot + 4), (x0 + 2 * half / teeth, bot - 1)], PINE_D)
        poly(im, [(tx - 1, top + 3), (tx - half + 3, bot - 2), (tx + half * 0.25, bot - 2)], PINE_M)
        poly(im, [(tx - 2, top + 6), (tx - half + 6, bot - 4), (tx - half * 0.3, bot - 4)], PINE_L)
    outline(im, PINE_O)
    return im


def tall_grass(seed, w=34, h=32):
    """Haute herbe de PRO : une rosette de grandes feuilles pointues, vue de dessus (le joueur s'y enfonce)."""
    r = rng(seed)
    im = new(w, h)
    cx, cy = w / 2, h / 2 + 1
    n = 9
    base_a = r.uniform(0, 40)
    leaves = []
    for k in range(n):
        a = math.radians(base_a + k * 360 / n + r.uniform(-8, 8))
        leaves.append((a, r.uniform(12.5, 15.5)))
    # Feuilles du haut d'abord (derrière), celles du bas devant.
    leaves.sort(key=lambda l: math.sin(l[0]))
    for i, (a, ln) in enumerate(leaves):
        sy = 0.8
        tip = (cx + math.cos(a) * ln, cy + math.sin(a) * ln * sy)
        pa = a + math.pi / 2
        bw = 4.2
        b1 = (cx + math.cos(pa) * 1.5, cy + math.sin(pa) * 1.5 * sy)
        b2 = (cx - math.cos(pa) * 1.5, cy - math.sin(pa) * 1.5 * sy)
        m1 = (cx + math.cos(a) * ln * 0.45 + math.cos(pa) * bw, cy + (math.sin(a) * ln * 0.45 + math.sin(pa) * bw) * sy)
        m2 = (cx + math.cos(a) * ln * 0.45 - math.cos(pa) * bw, cy + (math.sin(a) * ln * 0.45 - math.sin(pa) * bw) * sy)
        front = math.sin(a) > 0.2
        poly(im, [b1, m1, tip, m2, b2], GRASS_M if front else GRASS_D)
        # moitié éclairée de la feuille
        poly(im, [b1, m1, tip], GRASS_L if front else GRASS_M)
        line(im, cx, cy, cx + math.cos(a) * ln * 0.85, cy + math.sin(a) * ln * 0.85 * sy, GRASS_D)
    disc(im, cx, cy, 2.5, GRASS_D, 2)
    outline(im, GRASS_O)
    return im


def mushrooms(seed):
    im = new(34, 44)
    cap, cap_d, cap_l, cap_o = (206, 178, 214), (164, 134, 182), (232, 214, 238), (92, 70, 112)
    stem, stem_d = (236, 228, 214), (194, 182, 168)
    for (x, y, s) in [(10, 18, 1.0), (22, 26, 0.8), (14, 32, 0.6)]:
        rect(im, int(x - 2 * s), int(y), max(3, int(4 * s)), int(14 * s), stem)
        rect(im, int(x + 1 * s), int(y), max(1, int(1.5 * s)), int(14 * s), stem_d)
        disc(im, x, y, 9 * s, cap_d, 5 * s)
        disc(im, x - 1, y - 1.5 * s, 8 * s, cap, 4 * s)
        disc(im, x - 3 * s, y - 2.5 * s, 3.5 * s, cap_l, 1.8 * s)
    outline(im, cap_o)
    return im


def stump():
    im = new(34, 30)
    bark, bark_d, bark_l = (150, 112, 82), (108, 80, 60), (182, 144, 104)
    rect(im, 4, 10, 26, 14, bark)
    rect(im, 4, 10, 6, 14, bark_l)
    rect(im, 22, 10, 8, 14, bark_d)
    poly(im, [(1, 25), (6, 18), (8, 25)], bark)
    poly(im, [(33, 25), (28, 18), (26, 25)], bark_d)
    disc(im, 17, 10, 13, (214, 182, 138), 5)
    disc(im, 17, 10, 9, (190, 154, 112), 3.4)
    disc(im, 17, 10, 5, (214, 182, 138), 1.8)
    for x in range(8, 28, 4):
        line(im, x, 15, x, 23, bark_d)
    outline(im, (64, 44, 36))
    return im


def log():
    im = new(68, 34)
    bark, bark_d, bark_l = (150, 112, 82), (108, 80, 60), (182, 144, 104)
    rect(im, 8, 6, 52, 22, bark)
    rect(im, 8, 6, 52, 5, bark_l)
    rect(im, 8, 23, 52, 5, bark_d)
    for x in range(14, 58, 7):
        line(im, x, 12, x + 4, 12, bark_d)
        line(im, x + 2, 18, x + 6, 18, bark_d)
    disc(im, 60, 17, 7, (214, 182, 138), 11)
    disc(im, 60, 17, 4.5, (190, 154, 112), 7)
    disc(im, 60, 17, 2, (214, 182, 138), 3)
    disc(im, 8, 17, 6, bark_d, 11)
    outline(im, (64, 44, 36))
    return im


def berry_bush(seed):
    r = rng(seed)
    im = new(46, 42)
    for bx, by, br in [(16, 20, 12), (30, 20, 12), (23, 13, 12), (23, 25, 14)]:
        blob(im, bx, by, br, (30, 82, 58), (44, 108, 70), (68, 138, 82), (98, 168, 96))
    for _ in range(14):
        x, y = r.randint(8, 38), r.randint(6, 34)
        if get(im, x, y)[3]:
            put(im, x, y, (226, 74, 124))
            put(im, x + 1, y, (248, 156, 188))
    outline(im, (18, 50, 40))
    return im


def flowers(seed):
    """Deux fleurs orange (posées au sol)."""
    im = new(32, 30)
    pet, pet_d, pet_l, ctr, o = (248, 150, 44), (214, 102, 30), (255, 202, 92), (250, 232, 96), (122, 62, 24)
    for (x, y) in [(10, 10), (22, 20)]:
        for dx, dy in [(-4, 0), (4, 0), (0, -4), (0, 4)]:
            disc(im, x + dx, y + dy, 3.4, pet_d)
            disc(im, x + dx - 0.5, y + dy - 0.5, 2.6, pet)
            put(im, x + dx - 1, y + dy - 1, pet_l)
        disc(im, x, y, 2.2, ctr)
    outline(im, o)
    return im


def sign():
    im = new(32, 38)
    wood, wood_d, wood_l = (172, 128, 82), (128, 90, 58), (204, 160, 108)
    rect(im, 14, 18, 4, 18, wood_d)
    rect(im, 2, 4, 28, 16, wood)
    rect(im, 2, 4, 28, 3, wood_l)
    rect(im, 2, 17, 28, 3, wood_d)
    for y in (9, 13):
        line(im, 6, y, 25, y, (96, 66, 44))
    outline(im, (64, 44, 36))
    return im


def leaf_particle():
    im = new(12, 8)
    poly(im, [(1, 4), (6, 0), (11, 3), (6, 7)], (120, 168, 58))
    line(im, 2, 4, 10, 3, (86, 128, 40))
    outline(im, (60, 92, 34))
    return im


# =============================================================================================================
# Personnages (24 x 32 par image ; lignes : bas, gauche, droite, haut ; colonnes : arrêt, pas 1, arrêt, pas 2)
# =============================================================================================================

def character(skin, hair, shirt, shirt_d, pants, shoes, cap=None, accent=(196, 58, 58)):
    W, H = 24, 32
    sheet = new(W * 4, H * 4)
    o = (34, 26, 32)
    for row, d in enumerate(["down", "left", "right", "up"]):
        for col in range(4):
            step = [0, 1, 0, -1][col]
            im = new(W, H)
            bob = 0 if step == 0 else 1
            _legs(im, d, step, pants, shoes, bob)
            _body(im, d, step, skin, shirt, shirt_d, accent, bob)
            _head(im, d, skin, hair, cap, bob)
            outline(im, o)
            if d == "right":
                pass
            paste(sheet, im, col * W, row * H)
    return sheet


def _legs(im, d, step, pants, shoes, bob):
    pd = mix(pants, (0, 0, 0), 0.3)
    y0 = 24
    if d in ("down", "up"):
        lx, rx = 8, 13
        ly = y0 + (1 if step == 1 else 0)
        ry = y0 + (1 if step == -1 else 0)
        rect(im, lx, ly - bob, 3, 5, pants)
        rect(im, rx, ry - bob, 3, 5, pd)
        rect(im, lx, ly + 4 - bob, 3, 2, shoes)
        rect(im, rx, ry + 4 - bob, 3, 2, mix(shoes, (0, 0, 0), 0.25))
    else:
        f = 1 if d == "right" else -1
        cx = 11
        a = step * 2
        rect(im, cx - 1 - a * f, y0 - bob, 3, 5, pd)
        rect(im, cx + 1 + a * f, y0 - bob, 3, 5, pants)
        rect(im, cx - 1 - a * f, y0 + 4 - bob, 3 + (1 if f > 0 else 0), 2, mix(shoes, (0, 0, 0), 0.25))
        rect(im, cx + 1 + a * f - (1 if f < 0 else 0), y0 + 4 - bob, 4, 2, shoes)


def _body(im, d, step, skin, shirt, shirt_d, accent, bob):
    y = 16 - bob
    rect(im, 7, y, 10, 9, shirt)
    rect(im, 13, y, 4, 9, shirt_d)
    if d == "down":
        rect(im, 11, y, 2, 6, accent)          # cravate / bande
        rect(im, 7, y + 7, 10, 2, mix(shirt_d, (0, 0, 0), 0.15))
        # bras
        sw = 1 if step else 0
        rect(im, 5, y + 1 + sw, 2, 6, shirt_d)
        rect(im, 17, y + 1 - sw + 1, 2, 6, shirt_d)
        rect(im, 5, y + 7 + sw, 2, 2, skin)
        rect(im, 17, y + 8 - sw, 2, 2, skin)
    elif d == "up":
        rect(im, 7, y + 7, 10, 2, mix(shirt_d, (0, 0, 0), 0.15))
        rect(im, 5, y + 1, 2, 6, shirt_d)
        rect(im, 17, y + 1, 2, 6, shirt_d)
        rect(im, 5, y + 7, 2, 2, skin)
        rect(im, 17, y + 7, 2, 2, skin)
    else:
        f = 1 if d == "right" else -1
        ax = 11 + step * 2 * f
        rect(im, ax, y + 1, 3, 6, shirt_d)
        rect(im, ax, y + 7, 3, 2, skin)
        if f > 0:
            rect(im, 15, y, 2, 4, accent)
        else:
            rect(im, 7, y, 2, 4, accent)


def _head(im, d, skin, hair, cap, bob):
    y = 1 - bob
    skin_d = mix(skin, (0, 0, 0), 0.18)
    hair_l = mix(hair, (255, 255, 255), 0.25)
    eye = (40, 30, 60)
    # Crâne
    disc(im, 12, y + 8, 9.5, hair, 8.5)
    if d == "down":
        rect(im, 5, y + 9, 14, 7, skin)
        rect(im, 5, y + 14, 14, 2, skin_d)
        disc(im, 12, y + 6, 9.5, hair, 6)          # frange
        poly(im, [(5, y + 8), (9, y + 8), (6, y + 13)], hair)
        poly(im, [(19, y + 8), (15, y + 8), (18, y + 13)], hair)
        rect(im, 8, y + 10, 2, 3, eye)
        rect(im, 14, y + 10, 2, 3, eye)
        put(im, 8, y + 10, (255, 255, 255))
        put(im, 14, y + 10, (255, 255, 255))
    elif d == "up":
        disc(im, 12, y + 8, 9.5, hair, 8.5)
        rect(im, 6, y + 14, 12, 2, mix(hair, (0, 0, 0), 0.2))
    else:
        f = 1 if d == "right" else -1
        fx = 12 + 3 * f
        rect(im, fx - 4, y + 9, 8, 7, skin)
        rect(im, fx - 4, y + 14, 8, 2, skin_d)
        disc(im, 12 - f, y + 6, 9.5, hair, 6)
        poly(im, [(12 - 7 * f, y + 6), (12 - 3 * f, y + 15), (12 - 9 * f, y + 13)], hair)
        rect(im, fx + (1 if f > 0 else -2), y + 10, 2, 3, eye)
        put(im, fx + (1 if f > 0 else -2), y + 10, (255, 255, 255))
    # Reflet et mèche dressée
    if cap is None:
        line(im, 8, y + 2, 11, y + 1, hair_l)
        line(im, 12, y - 0, 13, y - 3 + 3, hair)
        put(im, 12, y - 1, hair)
        put(im, 13, y - 2, hair)
        put(im, 14, y - 2, hair)
    else:
        cap_d = mix(cap, (0, 0, 0), 0.25)
        disc(im, 12, y + 5, 10, cap, 6)
        rect(im, 3, y + 6, 18, 3, cap_d)
        if d == "down":
            rect(im, 6, y + 8, 12, 2, cap_d)
        elif d in ("left", "right"):
            f = 1 if d == "right" else -1
            rect(im, 12 + 3 * f + (0 if f > 0 else -6), y + 7, 7, 2, cap_d)
        disc(im, 10, y + 2, 3, mix(cap, (255, 255, 255), 0.3), 1.5)


# =============================================================================================================
# Reptincel qui suit le joueur (32 x 32 ; lignes : bas, gauche, droite, haut ; 2 images de marche)
# =============================================================================================================

RED = (214, 66, 50)
RED_D = (164, 40, 40)
RED_L = (244, 118, 80)
CREAM = (248, 214, 150)
CREAM_D = (220, 178, 112)
FL_Y = (252, 222, 80)
FL_O = (248, 140, 36)
FL_R = (226, 64, 34)
CO = (70, 22, 26)


def _flame(im, x, y, frame):
    s = 1 if frame else 0
    poly(im, [(x, y + 6), (x - 3, y - 1 - s), (x + 1, y + 1), (x + 2, y - 4 + s), (x + 4, y + 1), (x + 6, y - 1), (x + 5, y + 6)], FL_R)
    poly(im, [(x + 1, y + 5), (x, y + 1), (x + 2, y), (x + 3, y - 2 + s), (x + 4, y + 2), (x + 4, y + 5)], FL_O)
    disc(im, x + 2.5, y + 4, 1.6, FL_Y)


def charmeleon_frame(d, frame):
    im = new(32, 32)
    bob = frame
    if d in ("left", "right"):
        # Dessiné tourné vers la droite, puis retourné pour la gauche.
        # Queue (derrière)
        for i in range(9):
            tx = 11 - i
            ty = 22 - int(i * i * 0.12) - bob
            rect(im, tx, ty, 2, 3, RED if i < 6 else RED_D)
        _flame(im, 1, 9 - bob, frame)
        # Jambes
        fl = 2 if frame else 0
        rect(im, 12 - fl // 2, 23 - bob, 4, 6 + bob, RED_D)
        rect(im, 17 + fl // 2, 23 - bob, 4, 6 + bob, RED)
        rect(im, 11 - fl // 2, 28, 5, 2, RED_D)
        rect(im, 17 + fl // 2, 28, 5, 2, RED)
        # Corps
        disc(im, 16, 19 - bob, 6, RED, 7)
        disc(im, 18.5, 20 - bob, 3, CREAM, 5)
        put(im, 19, 23 - bob, CREAM_D)
        # Bras
        rect(im, 19, 17 - bob, 4, 2, RED_D)
        put(im, 23, 17 - bob, (250, 250, 240))
        # Tête
        disc(im, 19, 9 - bob, 6.5, RED, 5.5)
        poly(im, [(21, 7 - bob), (28, 9 - bob), (28, 12 - bob), (21, 13 - bob)], RED)       # museau
        line(im, 22, 13 - bob, 27, 12 - bob, RED_D)
        disc(im, 17.5, 7 - bob, 3, RED_L, 2)
        # Corne vers l'arrière
        poly(im, [(14, 6 - bob), (8, 2 - bob), (13, 9 - bob)], RED)
        # Oeil
        rect(im, 22, 8 - bob, 2, 3, (40, 70, 140))
        put(im, 22, 8 - bob, (255, 255, 255))
        outline(im, CO)
        if d == "left":
            im = im.transpose(0)  # FLIP_LEFT_RIGHT
        return im
    if d == "down":
        # Queue derrière, flamme visible à droite
        rect(im, 22, 20 - bob, 3, 4, RED_D)
        _flame(im, 23, 12 - bob, frame)
        fl = 1 if frame else 0
        rect(im, 10, 23 - bob + fl, 5, 6, RED_D)
        rect(im, 17, 23 - bob - fl + 1, 5, 6, RED)
        disc(im, 16, 19 - bob, 7, RED, 7)
        disc(im, 16, 21 - bob, 4, CREAM, 5)
        rect(im, 7, 16 - bob, 3, 5, RED_D)
        rect(im, 22, 16 - bob, 3, 5, RED_D)
        disc(im, 16, 9 - bob, 7.5, RED, 6.5)
        poly(im, [(12, 4 - bob), (14, -1 + 2 - bob), (16, 4 - bob)], RED)           # corne
        disc(im, 14, 6 - bob, 3, RED_L, 2)
        rect(im, 11, 9 - bob, 2, 3, (40, 70, 140))
        rect(im, 19, 9 - bob, 2, 3, (40, 70, 140))
        put(im, 11, 9 - bob, (255, 255, 255))
        put(im, 19, 9 - bob, (255, 255, 255))
        line(im, 14, 13 - bob, 18, 13 - bob, RED_D)
        outline(im, CO)
        return im
    # haut (de dos)
    fl = 1 if frame else 0
    rect(im, 10, 23 - bob + fl, 5, 6, RED)
    rect(im, 17, 23 - bob - fl + 1, 5, 6, RED_D)
    disc(im, 16, 19 - bob, 7, RED, 7)
    disc(im, 16, 9 - bob, 7.5, RED, 6.5)
    disc(im, 15, 7 - bob, 3, RED_L, 2)
    poly(im, [(14, 4 - bob), (16, -1 + 2 - bob), (18, 4 - bob)], RED_D)
    rect(im, 15, 22 - bob, 3, 6, RED_D)
    _flame(im, 14, 25 - bob, frame)
    outline(im, CO)
    return im


def charmeleon_sheet():
    sheet = new(32 * 2, 32 * 4)
    for row, d in enumerate(["down", "left", "right", "up"]):
        for f in range(2):
            paste(sheet, charmeleon_frame(d, f), f * 32, row * 32)
    return sheet


def main():
    for k in range(6):
        save(round_tree(100 + k), "world", f"tree_{k}.png")
    save(round_tree(321, sleepy=True), "world", "tree_sleepy.png")
    for k in range(3):
        save(pine_tree(200 + k), "world", f"pine_{k}.png")
    for k in range(4):
        save(tall_grass(300 + k), "world", f"grass_{k}.png")
    save(mushrooms(1), "world", "mushrooms.png")
    save(stump(), "world", "stump.png")
    save(log(), "world", "log.png")
    save(berry_bush(5), "world", "bush.png")
    save(flowers(3), "world", "flowers.png")
    save(sign(), "world", "sign.png")
    save(leaf_particle(), "world", "leaf.png")
    save(shadow(22, 8, 110), "world", "shadow.png")
    save(character(skin=(250, 214, 188), hair=(30, 28, 36), shirt=(238, 236, 240), shirt_d=(196, 194, 206),
                   pants=(70, 66, 82), shoes=(180, 50, 56)), "chars", "player.png")
    save(character(skin=(244, 206, 170), hair=(96, 62, 40), shirt=(84, 150, 66), shirt_d=(58, 116, 50),
                   pants=(84, 70, 52), shoes=(70, 50, 40), cap=(70, 128, 58), accent=(230, 210, 120)), "chars", "jeremy.png")
    save(charmeleon_sheet(), "chars", "charmeleon.png")
    print("graphismes écrits dans", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
