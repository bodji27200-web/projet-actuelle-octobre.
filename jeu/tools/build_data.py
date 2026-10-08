"""Génère jeu/data/*.json à partir des CSV de PokeAPI (github.com/PokeAPI/pokeapi, data/v2/csv).

Usage : python3 build_data.py <dossier_csv> <dossier_sortie>
Kanto (151 Pokémon), capacités apprises par niveau + CT, noms et textes en français.
"""
import csv
import json
import sys
from collections import defaultdict

SRC, OUT = sys.argv[1], sys.argv[2]
FR = "5"
VG = "7"  # rouge-feu / vert-feuille : apprentissages et CT
MAX_ID = 151


def rows(name):
    with open(f"{SRC}/{name}.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def clean(text):
    return " ".join(text.replace("­", "").replace("\f", " ").split())


def fr_names(name, key):
    return {r[key]: r["name"] for r in rows(name) if r["local_language_id"] == FR}


def last_fr_flavor(name, key, vg_key):
    best = {}
    for r in rows(name):
        if r["language_id"] != FR:
            continue
        k = r[key]
        v = int(r[vg_key])
        if k not in best or v > best[k][0]:
            best[k] = (v, clean(r["flavor_text"]))
    return {k: v[1] for k, v in best.items()}


types = {r["id"]: r["identifier"] for r in rows("types")}
items = {r["id"]: r for r in rows("items")}
item_by_ident = {r["identifier"]: r for r in rows("items")}
item_names = fr_names("item_names", "item_id")
item_desc = last_fr_flavor("item_flavor_text", "item_id", "version_group_id")

# --- Pokémon -----------------------------------------------------------------
species = {r["id"]: r for r in rows("pokemon_species") if int(r["id"]) <= MAX_ID}
pokemon = {r["id"]: r for r in rows("pokemon") if int(r["id"]) <= MAX_ID}
names = {}
genus = {}
for r in rows("pokemon_species_names"):
    if r["local_language_id"] == FR and r["pokemon_species_id"] in species:
        names[r["pokemon_species_id"]] = r["name"]
        genus[r["pokemon_species_id"]] = r["genus"]
dex_text = last_fr_flavor("pokemon_species_flavor_text", "species_id", "version_id")

stats = defaultdict(lambda: [0] * 6)
evs = defaultdict(lambda: [0] * 6)
for r in rows("pokemon_stats"):
    if r["pokemon_id"] in pokemon and int(r["stat_id"]) <= 6:
        stats[r["pokemon_id"]][int(r["stat_id"]) - 1] = int(r["base_stat"])
        evs[r["pokemon_id"]][int(r["stat_id"]) - 1] = int(r["effort"])

ptypes = defaultdict(list)
for r in sorted(rows("pokemon_types"), key=lambda r: int(r["slot"])):
    if r["pokemon_id"] in pokemon:
        ptypes[r["pokemon_id"]].append(types[r["type_id"]])

pabil = defaultdict(list)
for r in sorted(rows("pokemon_abilities"), key=lambda r: int(r["slot"])):
    if r["pokemon_id"] in pokemon and r["is_hidden"] == "0":
        pabil[r["pokemon_id"]].append(int(r["ability_id"]))

evos = defaultdict(list)
seen_evo = set()
for r in rows("pokemon_evolution"):
    to = r["evolved_species_id"]
    if to not in species:
        continue
    frm = species[to]["evolves_from_species_id"]
    if not frm or frm not in species:
        continue
    trig = r["evolution_trigger_id"]
    if trig == "1" and r["minimum_level"]:
        e = {"to": int(to), "level": int(r["minimum_level"])}
    elif trig == "2":
        e = {"to": int(to), "item": "linking-cord"}  # échange -> Fil de Liaison
    elif trig == "3" and r["trigger_item_id"]:
        e = {"to": int(to), "item": items[r["trigger_item_id"]]["identifier"]}
    else:
        continue
    key = (frm, json.dumps(e, sort_keys=True))
    if key in seen_evo:
        continue
    # Évolutions par pierre ajoutées dans des générations récentes : on garde la première par cible.
    if any(x["to"] == e["to"] for x in evos[frm]):
        continue
    seen_evo.add(key)
    evos[frm].append(e)

learn = defaultdict(list)
tm = defaultdict(set)
for r in rows("pokemon_moves"):
    if r["version_group_id"] != VG or r["pokemon_id"] not in pokemon:
        continue
    if r["pokemon_move_method_id"] == "1":
        learn[r["pokemon_id"]].append([int(r["level"]), int(r["move_id"])])
    elif r["pokemon_move_method_id"] == "4":
        tm[r["pokemon_id"]].add(int(r["move_id"]))

out_pkmn = {}
for sid, s in species.items():
    p = pokemon[sid]
    out_pkmn[sid] = {
        "id": int(sid),
        "name": names[sid],
        "genus": genus.get(sid, ""),
        "dex": dex_text.get(sid, ""),
        "types": ptypes[sid],
        "base": stats[sid],
        "ev": evs[sid],
        "catch": int(s["capture_rate"]),
        "exp": int(p["base_experience"]),
        "growth": int(s["growth_rate_id"]),
        "gender": int(s["gender_rate"]),
        "happiness": int(s["base_happiness"] or 70),
        "legendary": s["is_legendary"] == "1" or s["is_mythical"] == "1",
        "evolves_from": int(s["evolves_from_species_id"] or 0),
        "abilities": pabil[sid],
        "evos": evos.get(sid, []),
        "learn": sorted(learn[sid]),
        "tm": sorted(tm[sid]),
        "height": int(p["height"]),
        "weight": int(p["weight"]),
    }

# --- Capacités ---------------------------------------------------------------
machines = [r for r in rows("machines") if r["version_group_id"] == VG]
move_ids = {m for p in out_pkmn.values() for _, m in p["learn"]}
move_ids |= {m for p in out_pkmn.values() for m in p["tm"]}
move_ids |= {int(r["move_id"]) for r in machines}
move_ids |= {165}  # Lutte

moves = {r["id"]: r for r in rows("moves")}
meta = {r["move_id"]: r for r in rows("move_meta")}
ailments = {r["id"]: r["identifier"] for r in rows("move_meta_ailments")}
targets = {r["id"]: r["identifier"] for r in rows("move_targets")}
mnames = fr_names("move_names", "move_id")
mdesc = last_fr_flavor("move_flavor_text", "move_id", "version_group_id")
mstat = defaultdict(list)
for r in rows("move_meta_stat_changes"):
    mstat[r["move_id"]].append([int(r["stat_id"]), int(r["change"])])
CAT = {"1": "status", "2": "physical", "3": "special"}

out_moves = {}
for mid in sorted(move_ids):
    m = moves[str(mid)]
    mt = meta.get(str(mid), {})
    i = lambda k: int(mt.get(k) or 0)
    out_moves[str(mid)] = {
        "id": mid,
        "ident": m["identifier"],
        "name": mnames.get(str(mid), m["identifier"]),
        "desc": mdesc.get(str(mid), ""),
        "type": types[m["type_id"]],
        "power": int(m["power"] or 0),
        "acc": int(m["accuracy"] or 0),
        "pp": int(m["pp"] or 1),
        "prio": int(m["priority"]),
        "cat": CAT[m["damage_class_id"]],
        "target": targets[m["target_id"]],
        "effect": int(m["effect_id"] or 0),
        "chance": int(m["effect_chance"] or 0),
        "mcat": i("meta_category_id"),
        "ail": ailments.get(mt.get("meta_ailment_id", "0"), "none"),
        "ail_ch": i("ailment_chance"),
        "min_hits": i("min_hits"),
        "max_hits": i("max_hits"),
        "min_turns": i("min_turns"),
        "max_turns": i("max_turns"),
        "drain": i("drain"),
        "heal": i("healing"),
        "crit": i("crit_rate"),
        "flinch": i("flinch_chance"),
        "stat_ch": i("stat_chance"),
        "stats": mstat.get(str(mid), []),
    }

# --- Talents -----------------------------------------------------------------
abil_ids = {a for p in out_pkmn.values() for a in p["abilities"]}
anames = fr_names("ability_names", "ability_id")
adesc = last_fr_flavor("ability_flavor_text", "ability_id", "version_group_id")
aident = {r["id"]: r["identifier"] for r in rows("abilities")}
out_abil = {
    str(a): {"ident": aident[str(a)], "name": anames.get(str(a), aident[str(a)]), "desc": adesc.get(str(a), "")}
    for a in sorted(abil_ids)
}

# --- Objets ------------------------------------------------------------------
ITEMS = """poke-ball great-ball ultra-ball master-ball premier-ball net-ball nest-ball repeat-ball
timer-ball luxury-ball dusk-ball heal-ball quick-ball level-ball moon-ball heavy-ball fast-ball
friend-ball love-ball dive-ball
potion super-potion hyper-potion max-potion full-restore revive max-revive antidote paralyze-heal
awakening burn-heal ice-heal full-heal ether max-ether elixir max-elixir fresh-water soda-pop
lemonade moomoo-milk rare-candy hp-up protein iron calcium zinc carbos pp-up pp-max
fire-stone water-stone thunder-stone leaf-stone moon-stone linking-cord
x-attack x-defense x-sp-atk x-sp-def x-speed x-accuracy dire-hit guard-spec
repel super-repel max-repel escape-rope""".split()
out_items = {}
for ident in ITEMS:
    r = item_by_ident.get(ident)
    if r is None:
        print("objet introuvable :", ident)
        continue
    out_items[ident] = {"name": item_names.get(r["id"], ident), "desc": item_desc.get(r["id"], ""), "price": int(r["cost"])}
for r in sorted(machines, key=lambda r: int(r["machine_number"])):
    n = int(r["machine_number"])
    kind = "CT" if n <= 50 else "CS"
    num = n if n <= 50 else n - 50
    mid = r["move_id"]
    out_items[f"tm{n:02d}"] = {
        "name": f"{kind}{num:02d} {mnames.get(mid, '')}",
        "desc": mdesc.get(mid, ""),
        "price": 3000 if kind == "CT" else 0,
        "move": int(mid),
    }

# --- Natures, courbes d'expérience ------------------------------------------
nat_names = fr_names("nature_names", "nature_id")
out_nat = []
for r in sorted(rows("natures"), key=lambda r: int(r["game_index"])):
    up, down = int(r["increased_stat_id"]), int(r["decreased_stat_id"])
    out_nat.append({"name": nat_names[r["id"]], "up": up - 1 if up != down else -1, "down": down - 1 if up != down else -1})

exp = defaultdict(lambda: [0] * 101)
for r in rows("experience"):
    if int(r["level"]) <= 100:
        exp[int(r["growth_rate_id"])][int(r["level"])] = int(r["experience"])

type_fr = {types[r["type_id"]]: r["name"] for r in rows("type_names") if r["local_language_id"] == FR and r["type_id"] in types}


def dump(name, obj):
    with open(f"{OUT}/{name}.json", "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))


dump("pokemon", out_pkmn)
dump("moves", out_moves)
dump("abilities", out_abil)
dump("items", out_items)
dump("misc", {"natures": out_nat, "exp": {str(k): v for k, v in exp.items()}, "types": type_fr})
print(len(out_pkmn), "pokémon,", len(out_moves), "capacités,", len(out_abil), "talents,", len(out_items), "objets")
