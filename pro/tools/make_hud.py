"""Icônes de l'interface (lissées, comme dans PRO) : dessinées 4 fois plus grandes puis réduites.
Usage : python3 make_hud.py"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "hud")
S = 4


def canvas(n):
    return Image.new("RGBA", (n * S, n * S), (0, 0, 0, 0))


def done(im, n, name):
    os.makedirs(OUT, exist_ok=True)
    im.resize((n, n), Image.LANCZOS).save(os.path.join(OUT, name))


def P(*pts):
    return [(x * S, y * S) for x, y in pts]


def B(x0, y0, x1, y1):
    return [x0 * S, y0 * S, x1 * S, y1 * S]


def pvp():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    cx, cy = 20, 20
    pts = []
    for k in range(32):
        a = k * math.pi / 16
        r = 18 if k % 2 == 0 else 10.5
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(P(*pts), fill=(236, 140, 24), outline=(170, 84, 20))
    pts2 = [(cx + math.cos(k * math.pi / 16) * (14 if k % 2 == 0 else 9), cy + math.sin(k * math.pi / 16) * (14 if k % 2 == 0 else 9)) for k in range(32)]
    d.polygon(P(*pts2), fill=(252, 204, 52))
    d.ellipse(B(cx - 7, cy - 7, cx + 7, cy + 7), fill=(255, 240, 150))
    done(im, 40, "pvp.png")


def backpack():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    o = (150, 92, 20)
    d.rounded_rectangle(B(7, 9, 33, 34), radius=6 * S, fill=(242, 176, 44), outline=o, width=2 * S)
    d.rounded_rectangle(B(13, 4, 27, 12), radius=4 * S, outline=o, width=2 * S)
    d.rounded_rectangle(B(10, 18, 30, 30), radius=3 * S, fill=(250, 202, 80), outline=o, width=2 * S)
    d.rectangle(B(18, 16, 22, 22), fill=(196, 120, 30))
    d.line(P((10, 12), (30, 12)), fill=(255, 220, 120), width=2 * S)
    done(im, 40, "backpack.png")


def pokedex():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    d.ellipse(B(4, 4, 36, 36), fill=(250, 250, 250), outline=(40, 40, 46), width=2 * S)
    d.pieslice(B(4, 4, 36, 36), 180, 360, fill=(224, 44, 44), outline=(40, 40, 46), width=2 * S)
    d.ellipse(B(7, 7, 22, 14), fill=(250, 120, 110))
    d.rectangle(B(4, 18.5, 36, 21.5), fill=(40, 40, 46))
    d.ellipse(B(14, 14, 26, 26), fill=(250, 250, 250), outline=(40, 40, 46), width=2 * S)
    d.ellipse(B(17, 17, 23, 23), fill=(230, 230, 236))
    done(im, 40, "pokedex.png")


def trainer():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(B(3, 8, 37, 32), radius=3 * S, fill=(96, 214, 120), outline=(30, 110, 56), width=2 * S)
    d.rectangle(B(7, 12, 18, 23), fill=(44, 150, 76))
    for y in (13, 17, 21):
        d.line(P((21, y), (33, y)), fill=(30, 110, 56), width=2 * S)
    d.line(P((7, 27), (33, 27)), fill=(30, 110, 56), width=2 * S)
    done(im, 40, "trainer.png")


def social():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    d.ellipse(B(13, 12, 37, 30), fill=(176, 178, 186), outline=(90, 92, 100), width=2 * S)
    d.polygon(P((30, 28), (36, 35), (25, 29)), fill=(176, 178, 186))
    d.ellipse(B(3, 5, 29, 24), fill=(252, 252, 252), outline=(110, 112, 120), width=2 * S)
    d.polygon(P((8, 21), (4, 30), (15, 23)), fill=(252, 252, 252))
    d.line(P((8, 21), (4, 30), (15, 23)), fill=(110, 112, 120), width=2 * S)
    done(im, 40, "social.png")


def map_icon():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    d.polygon(P((6, 9), (34, 7), (35, 31), (5, 33)), fill=(170, 214, 222), outline=(120, 96, 64))
    for (x, y, r, c) in [(12, 15, 4, (90, 170, 90)), (24, 22, 5, (90, 170, 90)), (17, 26, 3, (220, 190, 110)), (27, 13, 3, (230, 120, 90))]:
        d.ellipse(B(x - r, y - r, x + r, y + r), fill=c)
    d.rounded_rectangle(B(2, 5, 8, 35), radius=3 * S, fill=(236, 214, 170), outline=(120, 96, 64), width=S)
    d.rounded_rectangle(B(32, 4, 38, 33), radius=3 * S, fill=(236, 214, 170), outline=(120, 96, 64), width=S)
    done(im, 40, "map.png")


def bag():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    o = (120, 52, 14)
    d.rounded_rectangle(B(13, 4, 27, 18), radius=6 * S, outline=o, width=3 * S)
    d.rounded_rectangle(B(6, 13, 34, 36), radius=5 * S, fill=(244, 120, 36), outline=o, width=2 * S)
    d.rounded_rectangle(B(9, 15, 31, 20), radius=2 * S, fill=(252, 160, 74))
    d.ellipse(B(11, 17, 15, 21), fill=(80, 36, 10))
    d.ellipse(B(25, 17, 29, 21), fill=(80, 36, 10))
    done(im, 40, "bag.png")


def moon():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    d.ellipse(B(6, 5, 34, 33), fill=(252, 240, 170))
    d.ellipse(B(12, 2, 40, 30), fill=(0, 0, 0, 0))
    m = Image.new("L", im.size, 0)
    dm = ImageDraw.Draw(m)
    dm.ellipse(B(6, 5, 34, 33), fill=255)
    dm.ellipse(B(13, 2, 41, 29), fill=0)
    moon_im = Image.new("RGBA", im.size, (250, 236, 160, 255))
    glow = m.filter(ImageFilter.GaussianBlur(2 * S))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", im.size, (255, 230, 140, 90)), (0, 0), glow)
    out.paste(moon_im, (0, 0), m)
    done(out, 40, "moon.png")


def sun():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    for k in range(12):
        a = k * math.pi / 6
        d.line(P((20 + math.cos(a) * 11, 20 + math.sin(a) * 11), (20 + math.cos(a) * 17, 20 + math.sin(a) * 17)), fill=(255, 200, 60), width=3 * S)
    d.ellipse(B(10, 10, 30, 30), fill=(255, 214, 72), outline=(240, 160, 30), width=2 * S)
    done(im, 40, "sun.png")


def lock():
    im = canvas(40)
    d = ImageDraw.Draw(im)
    d.arc(B(12, 5, 30, 23), 180, 330, fill=(180, 184, 192), width=3 * S)
    d.rounded_rectangle(B(9, 17, 31, 35), radius=3 * S, fill=(200, 204, 212), outline=(110, 114, 124), width=2 * S)
    d.ellipse(B(18, 22, 22, 26), fill=(70, 74, 84))
    d.rectangle(B(19.2, 25, 20.8, 30), fill=(70, 74, 84))
    done(im, 40, "lock.png")


def wrench():
    im = canvas(32)
    d = ImageDraw.Draw(im)
    d.line(P((8, 25), (21, 12)), fill=(220, 222, 228), width=5 * S)
    d.ellipse(B(17, 3, 30, 16), fill=(220, 222, 228))
    d.polygon(P((22, 4), (28, 4), (24, 11)), fill=(0, 0, 0, 0))
    d.ellipse(B(21, 2, 29, 9), fill=(0, 0, 0, 0))
    d.ellipse(B(5, 22, 11, 28), fill=(220, 222, 228))
    done(im, 32, "wrench.png")


def menu_icon():
    im = canvas(32)
    d = ImageDraw.Draw(im)
    for y in (9, 16, 23):
        d.ellipse(B(4, y - 2, 8, y + 2), fill=(232, 234, 240))
        d.rounded_rectangle(B(11, y - 2, 28, y + 2), radius=2 * S, fill=(232, 234, 240))
    done(im, 32, "menu.png")


def glow():
    n = 96
    im = Image.new("RGBA", (n * S, n * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = n / 2
    for k in range(14):
        a = k * math.pi / 7 + 0.1
        w = 0.09
        d.polygon(P((c, c), (c + math.cos(a - w) * 46, c + math.sin(a - w) * 46), (c + math.cos(a + w) * 46, c + math.sin(a + w) * 46)),
                  fill=(60, 220, 255, 110))
    im = im.filter(ImageFilter.GaussianBlur(3 * S))
    d = ImageDraw.Draw(im)
    done(im, n, "glow.png")


def tri(name, pts, n=16):
    im = canvas(n)
    d = ImageDraw.Draw(im)
    d.polygon(P(*pts), fill=(232, 234, 240))
    done(im, n, name)


def main():
    pvp(); backpack(); pokedex(); trainer(); social(); map_icon(); bag(); moon(); sun(); lock(); wrench(); menu_icon(); glow()
    tri("arrow_down.png", [(2, 4), (14, 4), (8, 12)])
    tri("arrow_left.png", [(11, 2), (11, 14), (4, 8)])
    print("icônes écrites dans", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
