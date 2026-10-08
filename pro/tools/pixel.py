"""Petits outils de pixel art (PIL) : formes pleines sans anticrénelage, contour automatique, ombrage."""
import math
import random

from PIL import Image


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rgb(c, a=255):
    return (c[0], c[1], c[2], a)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def put(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((int(x), int(y)), rgb(c) if len(c) == 3 else c)


def get(im, x, y):
    if 0 <= x < im.width and 0 <= y < im.height:
        return im.getpixel((int(x), int(y)))
    return (0, 0, 0, 0)


def disc(im, cx, cy, r, c, ry=None):
    ry = r if ry is None else ry
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if ((x + 0.5 - cx) / max(r, 0.01)) ** 2 + ((y + 0.5 - cy) / max(ry, 0.01)) ** 2 <= 1.0:
                put(im, x, y, c)


def rect(im, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(im, xx, yy, c)


def poly(im, pts, c):
    """Polygone plein (règle pair-impair), au pixel près."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        yc = y + 0.5
        inter = []
        n = len(pts)
        for i in range(n):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % n]
            if (y1 <= yc < y2) or (y2 <= yc < y1):
                inter.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
        inter.sort()
        for k in range(0, len(inter) - 1, 2):
            for x in range(int(math.ceil(inter[k] - 0.5)), int(math.floor(inter[k + 1] - 0.5)) + 1):
                put(im, x, y, c)


def line(im, x0, y0, x1, y1, c):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        put(im, round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)


def outline(im, c, diag=False):
    """Contour d'1 pixel autour de tout ce qui est opaque."""
    src = im.copy()
    w, h = im.size
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (-1, -1), (1, -1), (-1, 1)] if diag else [])
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] > 0:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src.getpixel((x + dx, y + dy))[3] > 0 for dx, dy in nb):
                im.putpixel((x, y), rgb(c))
    return im


def inner_edge(im, c, side="br"):
    """Assombrit (ou éclaire) les pixels opaques au bord du côté donné : relief simple."""
    src = im.copy()
    w, h = im.size
    d = {"br": [(1, 0), (0, 1)], "tl": [(-1, 0), (0, -1)], "b": [(0, 1)], "t": [(0, -1)]}[side]
    for y in range(h):
        for x in range(w):
            p = src.getpixel((x, y))
            if p[3] == 0:
                continue
            if any(src.getpixel((x + dx, y + dy))[3] == 0 if 0 <= x + dx < w and 0 <= y + dy < h else True for dx, dy in d):
                im.putpixel((x, y), rgb(c))
    return im


def paste(dst, src, x, y):
    dst.alpha_composite(src, (int(x), int(y)))


def shadow(w, h, a=90):
    """Ombre ovale douce (portée au sol)."""
    im = new(w, h)
    for y in range(h):
        for x in range(w):
            d = ((x + 0.5 - w / 2) / (w / 2)) ** 2 + ((y + 0.5 - h / 2) / (h / 2)) ** 2
            if d < 1:
                im.putpixel((x, y), (8, 12, 24, int(a * (1 - d) ** 0.7)))
    return im


def rng(seed):
    return random.Random(seed)
