"""Vérification indépendante du Pokédex : lit data/*.json comme le jeu et dit si chaque espèce est vraiment obtenable.
Usage : python3 check_dex.py ../data
- rencontres déclenchables (mêmes règles que overworld.gd), légendaires, dons, starters, rares ;
- évolutions seulement si le moteur sait les faire ET si l'objet nécessaire est obtenable (boutique, sol, don) ;
- reproduction (pré-évolutions) seulement pour les Pokémon qui pondent."""
import json, sys
D = sys.argv[1]
P = {int(k): v for k, v in json.load(open(f"{D}/pokemon.json")).items()}
I = json.load(open(f"{D}/items.json"))
W = json.load(open(f"{D}/world.json"))
maps = W["maps"]
realms = {m.get("realm", "kanto") for m in maps.values()}

def flat(cmds):
    for c in cmds or []:
        if isinstance(c, list):
            yield c
            yield from flat(c)

items = set()
got = set()
for mid, m in maps.items():
    tiles = set("".join(m["rows"]))
    floor = (m.get("cave") or not m.get("outdoor", True)) and bool(tiles & set("_uq"))
    for meth, lst in m.get("wild", {}).items():
        ok = ('"' in tiles or floor) if meth == "grass" else ("w" in tiles) if meth == "marsh" else bool(tiles & set("~w")) if meth.endswith("rod") else floor
        if not ok:
            print("table morte", mid, meth)
            continue
        got |= {e[0] for e in lst}
    if m.get("rare") and m.get("wild"):
        got |= {r[0] for r in m["rare"]}
    for n in m["npcs"]:
        if n.get("kind") == "legend":
            got.add(n["species"])
        if n.get("kind") in ("item", "gift"):
            items.add(n["item"])
        if n.get("kind") == "shop":
            items |= set(n.get("stock", []))
        for c in flat(n.get("script", [])):
            if c and c[0] == "give":
                items.add(c[1])
            if c and c[0] in ("mon", "egg", "legend") and isinstance(c[1], int):
                got.add(c[1])
            if c and c[0] == "special" and len(c) > 2 and c[1] in ("starter_pick", "starter_rest"):
                got |= set(c[2])
# Mew : le Prof. Chen le fait apparaître (150 Pokémon capturés, Maître de la Ligue) — events.gd chen_talk.
got.add(151)
# Fossiles (labos) : tous les fossiles ramassables ou vendus.
FOSSIL = {"helix-fossil": 138, "dome-fossil": 140, "old-amber": 142, "root-fossil": 345, "claw-fossil": 347, "skull-fossil": 408,
          "armor-fossil": 410, "cover-fossil": 564, "plume-fossil": 566, "jaw-fossil": 696, "sail-fossil": 698}
for it, sid in FOSSIL.items():
    if it in items:
        got.add(sid)
GALAR = {("fossilized-bird", "fossilized-drake"): 880, ("fossilized-bird", "fossilized-dino"): 881, ("fossilized-fish", "fossilized-drake"): 882,
         ("fossilized-fish", "fossilized-dino"): 883}
for (a, b), sid in GALAR.items():
    if a in items and b in items:
        got.add(sid)
SPECIAL_OK = {"spin", "shed", "use-move", "agile-style-move", "strong-style-move", "three-defeated-bisharp", "three-critical-hits",
              "take-damage", "recoil-damage"}
bad = set()
changed = True
while changed:
    changed = False
    for pid in list(got):
        for e in P[pid]["evos"]:
            t = e.get("to_form", e["to"])
            if t in got:
                continue
            why = None
            if "item" in e and e["item"] not in items:
                why = f"objet {e['item']} introuvable"
            if "held" in e and e["held"] not in items:
                why = f"objet tenu {e['held']} introuvable"
            if e.get("trade") and "linking-cord" not in items:
                why = "pas de Fil de Liaison (échange possible à deux seulement)"
            if "special" in e and e["special"] not in SPECIAL_OK:
                why = f"condition spéciale {e['special']} non gérée"
            mv = e.get("move") or e.get("used_move")
            if mv:
                fam, x = set(), P[pid]["species"]
                while x:
                    fam |= set(P[x].get("egg", []))
                    x = P[x]["evolves_from"]
                tms = [k for k, v in I.items() if v.get("move") == mv and k in items]
                if mv not in [m for _, m in P[pid]["learn"]] and mv not in fam and not tms:
                    why = f"capacité {mv} impossible à apprendre"
            if "region" in e and e["region"] not in realms:
                why = f"région {e['region']} absente"
            if why:
                bad.add((pid, t, why))
                continue
            got.add(t)
            changed = True
        pre = P[pid]["evolves_from"]
        if pre and pre not in got and P[pid]["egg_groups"] != ["no-eggs"]:
            got.add(pre)
            changed = True
species = {P[p]["species"] for p in got}
missing = [s for s in range(1, 1026) if s not in species]
print("espèces obtenables :", 1025 - len(missing), "/ 1025")
print("manquantes :", [f"{s} {P[s]['name']}" for s in missing])
for pid, t, why in sorted(bad):
    if P[t]["species"] not in species or t not in got:
        print("évolution bloquée :", P[pid]["name"], pid, "->", P[t]["name"], t, ":", why)
