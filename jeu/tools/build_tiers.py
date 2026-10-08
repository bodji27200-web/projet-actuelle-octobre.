"""Génère jeu/data/tiers.json : le tier Smogon (National Dex) de chaque Pokémon et forme du jeu.

Sources (Pokémon Showdown, github.com/smogon/pokemon-showdown, dossier data/) :
  formats-data.ts  (tiers)   et   pokedex.ts  (numéros et formes)
Usage : python3 build_tiers.py <dossier_showdown> <dossier_csv_pokeapi> <dossier_data_du_jeu>

On prend le tier « National Dex » (natDexTier) quand il existe, sinon le tier de la génération actuelle.
Les formes de PokeAPI (identifiant « charizard-mega-x ») correspondent aux identifiants Showdown sans tirets.
"""
import csv
import json
import re
import sys

SD, CSV, DATA = sys.argv[1], sys.argv[2], sys.argv[3]

# Ordre du plus fort au plus faible ; « (OU) » = non classé mais autorisé en OU.
ORDER = ["AG", "Uber", "OU", "UUBL", "UU", "RUBL", "RU", "NUBL", "NU", "PUBL", "PU", "ZUBL", "ZU", "NFE", "LC"]


def blocks(text):
    """Entrées « id: { ... }, » de premier niveau d'un fichier de données Showdown."""
    for m in re.finditer(r"^\t([a-z0-9]+): \{(.*?)^\t\},?$", text, re.S | re.M):
        yield m.group(1), m.group(2)


def field(body, key):
    m = re.search(r"\b" + key + r': "([^"]*)"', body)
    return m.group(1) if m else None


fmt = {}
for sid, body in blocks(open(f"{SD}/formats-data.ts", encoding="utf-8").read()):
    t = field(body, "natDexTier") or field(body, "tier")
    if t:
        fmt[sid] = t.strip("()")

num_of = {}
base_of = {}
for sid, body in blocks(open(f"{SD}/pokedex.ts", encoding="utf-8").read()):
    m = re.search(r"\bnum: (-?\d+)", body)
    if not m:
        continue
    num_of[sid] = int(m.group(1))
    base_of[sid] = field(body, "baseSpecies")

# Espèce de base (pas de baseSpecies) par numéro national.
species_sd = {num: sid for sid, num in num_of.items() if base_of[sid] is None and num > 0}

ident = {}
with open(f"{CSV}/pokemon.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        ident[int(r["id"])] = (r["identifier"], int(r["species_id"]))

game = json.load(open(f"{DATA}/pokemon.json", encoding="utf-8"))


def norm(t):
    if t in ORDER:
        return t
    if t in ("Illegal", "Unreleased", "CAP", "CAP LC", "CAP NFE"):
        return None
    if t.startswith("DUber") or t.startswith("D"):
        return None
    return None


out = {}
missing = []
for pid_s in game:
    pid = int(pid_s)
    sp = game[pid_s]["species"] if pid > 10000 else pid
    tier = None
    if pid > 10000 and pid in ident:
        sd = ident[pid][0].replace("-", "")
        tier = norm(fmt.get(sd, ""))
    if tier is None and sp in species_sd:
        tier = norm(fmt.get(species_sd[sp], ""))
    if tier is None:
        missing.append(pid)
        # Défaut prudent : légendaire = Uber, sinon le tier le plus permissif hors LC.
        g = game[str(sp)] if str(sp) in game else game[pid_s]
        tier = "Uber" if g.get("legendary") or g.get("mythical") else "PU"
    out[pid_s] = tier

json.dump({"order": ORDER, "tiers": out}, open(f"{DATA}/tiers.json", "w", encoding="utf-8"), separators=(",", ":"))
print(len(out), "tiers ;", len(missing), "sans tier Smogon (valeur par défaut) :", missing[:40])
