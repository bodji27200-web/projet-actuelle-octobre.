"""Ajoute à Jersey 10 les symboles qui lui manquent (♂ ♀ ★ ▶ ₽ ...).

Sans ça, Godot va chercher ces caractères dans une police du système :
taille, épaisseur et ligne de base différentes, donc symboles mal placés.
Les glyphes sont dessinés sur la même grille de pixels que la police
(1 pixel = 75 unités, hauteur des capitales = 10 pixels).

Entrée : assets/fonts/Jersey10.ttf (originale, OFL)
Sortie : assets/fonts/Jersey10Jeu.ttf
"""
import os

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

PX = 75
ROOT = os.path.join(os.path.dirname(__file__), "..")

# Chaque glyphe : (caractère, ligne du bas en pixels au-dessus de la ligne de base, lignes de haut en bas)
GLYPHS = {
	"♂": (0, [
		"......xxxx",
		"........xx",
		".......xxx",
		"......xx.x",
		"..xxxxx...",
		".xx..xx...",
		"xx....xx..",
		"xx....xx..",
		".xx..xx...",
		"..xxxx....",
	]),
	"♀": (0, [
		"..xxxx..",
		".xx..xx.",
		"xx....xx",
		"xx....xx",
		".xx..xx.",
		"..xxxx..",
		"...xx...",
		".xxxxxx.",
		"...xx...",
		"...xx...",
	]),
	"★": (0, [
		"....x....",
		"....x....",
		"...xxx...",
		"xxxxxxxxx",
		".xxxxxxx.",
		"..xxxxx..",
		"..xx.xx..",
		".xx...xx.",
		".x.....x.",
	]),
	"▶": (0, [
		"x....",
		"xx...",
		"xxx..",
		"xxxx.",
		"xxxxx",
		"xxxx.",
		"xxx..",
		"xx...",
		"x....",
	]),
	"◀": (0, [
		"....x",
		"...xx",
		"..xxx",
		".xxxx",
		"xxxxx",
		".xxxx",
		"..xxx",
		"...xx",
		"....x",
	]),
	"▼": (1, [
		"xxxxxxxxx",
		".xxxxxxx.",
		"..xxxxx..",
		"...xxx...",
		"....x....",
	]),
	"▲": (1, [
		"....x....",
		"...xxx...",
		"..xxxxx..",
		".xxxxxxx.",
		"xxxxxxxxx",
	]),
	"₽": (0, [
		".xxxxx..",
		".xx..xx.",
		".xx..xx.",
		".xx..xx.",
		"xxxxxx..",
		".xx.....",
		"xxxxx...",
		".xx.....",
		".xx.....",
		".xx.....",
	]),
	"✓": (0, [
		"........xx",
		".......xx.",
		"......xx..",
		"xx...xx...",
		".xx.xx....",
		"..xxx.....",
		"...x......",
	]),
	"■": (0, ["xxxxxxxx"] * 8),
	"□": (0, ["xxxxxxxx", "xx....xx", "xx....xx", "xx....xx", "xx....xx", "xx....xx", "xx....xx", "xxxxxxxx"]),
	"●": (0, [
		"..xxxx..",
		".xxxxxx.",
		"xxxxxxxx",
		"xxxxxxxx",
		"xxxxxxxx",
		"xxxxxxxx",
		".xxxxxx.",
		"..xxxx..",
	]),
}


def draw(rows, bottom):
	pen = TTGlyphPen(None)
	h = len(rows)
	for r, row in enumerate(rows):
		y0 = (bottom + h - 1 - r) * PX
		x = 0
		while x < len(row):
			if row[x] != "x":
				x += 1
				continue
			start = x
			while x < len(row) and row[x] == "x":
				x += 1
			# Contour dans le sens horaire (contour extérieur TrueType).
			pen.moveTo((start * PX, y0))
			pen.lineTo((start * PX, y0 + PX))
			pen.lineTo((x * PX, y0 + PX))
			pen.lineTo((x * PX, y0))
			pen.closePath()
	return pen.glyph()


def main():
	font = TTFont(os.path.join(ROOT, "assets/fonts/Jersey10.ttf"))
	order = font.getGlyphOrder()
	glyf = font["glyf"]
	hmtx = font["hmtx"]
	for ch, (bottom, rows) in GLYPHS.items():
		name = "uni%04X" % ord(ch)
		if name not in order:
			order.append(name)
		g = draw(rows, bottom)
		glyf[name] = g
		g.recalcBounds(glyf)
		width = max(len(r) for r in rows)
		hmtx[name] = ((width + 1) * PX, 0)
		for table in font["cmap"].tables:
			if table.isUnicode():
				table.cmap[ord(ch)] = name
	font.setGlyphOrder(order)
	font["maxp"].numGlyphs = len(order)
	font.save(os.path.join(ROOT, "assets/fonts/Jersey10Jeu.ttf"))
	print("%d glyphes ajoutés" % len(GLYPHS))


if __name__ == "__main__":
	main()
