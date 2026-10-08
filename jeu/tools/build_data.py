"""Génère jeu/data/*.json à partir des CSV de PokeAPI (github.com/PokeAPI/pokeapi, data/v2/csv).

Usage : python3 build_data.py <dossier_csv> <dossier_sortie>
Les 1025 Pokémon (et leurs formes régionales, Méga-Évolutions et Primo-Résurgences),
toutes leurs capacités (niveau, CT, œuf, tuteur), talents (y compris cachés), objets (dont
tous les objets tenus), évolutions avec leurs conditions. Noms et textes en français.
"""
import csv
import json
import os
import sys
from collections import defaultdict

SRC, OUT = sys.argv[1], sys.argv[2]
FR = "5"
MAX_ID = 1025
# Ordre de préférence des jeux pour les capacités apprises : le plus récent qui connaît le Pokémon.
VG_ORDER = ["25", "20", "23", "18", "17", "16", "15", "14", "11", "9", "10", "8", "6", "7", "5", "4", "3", "2", "1"]
FRLG = "7"


def rows(name):
    with open(f"{SRC}/{name}.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def clean(text):
    return " ".join(text.replace("\xad", "").replace("\f", " ").split())


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
item_cats = {r["id"]: r["identifier"] for r in rows("item_categories")}
item_flags = defaultdict(set)
for r in rows("item_flag_map"):
    item_flags[r["item_id"]].add(int(r["item_flag_id"]))

# --- Pokémon et formes ----------------------------------------------------------
species = {r["id"]: r for r in rows("pokemon_species") if int(r["id"]) <= MAX_ID}
all_pokemon = {r["id"]: r for r in rows("pokemon")}
forms_by_pokemon = {}
for r in rows("pokemon_forms"):
    if r["is_default"] == "1":
        forms_by_pokemon[r["pokemon_id"]] = r
form_fr = {r["pokemon_form_id"]: r["form_name"] for r in rows("pokemon_form_names") if r["local_language_id"] == FR}

SKIP_FORM = ("-gmax", "-totem", "-cap", "-starter", "-eternamax", "pikachu-", "-cosplay", "-power-construct",
             "-battle-bond", "-own-tempo", "-original", "koraidon-", "miraidon-", "-family-of-three",
             "-three-segment", "zygarde-10")
REGIONAL = ("-alola", "-galar", "-hisui", "-paldea")


def keep_form(p):
    ident = p["identifier"]
    if int(p["id"]) <= MAX_ID:
        return True
    if p["species_id"] not in species:
        return False
    if any(s in ident for s in SKIP_FORM) and not ident.endswith("-mega"):
        return False
    return True


pokemon = {pid: p for pid, p in all_pokemon.items() if keep_form(p)}
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
hidden = {}
for r in sorted(rows("pokemon_abilities"), key=lambda r: int(r["slot"])):
    if r["pokemon_id"] not in pokemon:
        continue
    if r["is_hidden"] == "1":
        hidden[r["pokemon_id"]] = int(r["ability_id"])
    elif int(r["ability_id"]) not in pabil[r["pokemon_id"]]:
        pabil[r["pokemon_id"]].append(int(r["ability_id"]))

# --- Évolutions (toutes les conditions) ----------------------------------------
TRIGGERS = {r["id"]: r["identifier"] for r in rows("evolution_triggers")}
loc_ident = {r["id"]: r["identifier"] for r in rows("locations")}
REGION_IDENT = {r["id"]: r["identifier"] for r in rows("regions")}
NATURE_ROWS = rows("natures")
form_pokemon = {r["id"]: r for r in rows("pokemon_forms")}


def form_to_pokemon(form_id):
    """Identifiant de forme PokeAPI -> identifiant Pokémon (10xxx pour une forme régionale), 0 si forme par défaut."""
    if not form_id or form_id not in form_pokemon:
        return 0
    f = form_pokemon[form_id]
    return int(f["pokemon_id"]) if int(f["pokemon_id"]) > MAX_ID else 0


def evo_from_row(r):
    to = int(r["evolved_species_id"])
    trig = TRIGGERS.get(r["evolution_trigger_id"], "")
    e = {"to": to}
    to_form = form_to_pokemon(r.get("evolved_pokemon_form_id"))
    if to_form:
        e["to_form"] = to_form
    if r.get("region_id"):
        e["region"] = REGION_IDENT.get(r["region_id"], "")
    if trig in ("level-up", "in-battle-level-up"):
        if r["minimum_level"]:
            e["level"] = int(r["minimum_level"])
    elif trig == "trade":
        e["trade"] = True
    elif trig == "use-item":
        e["item"] = items[r["trigger_item_id"]]["identifier"]
    elif trig == "shed":
        e["level"] = int(r["minimum_level"] or 20)
        e["special"] = "shed"
    else:
        e["special"] = trig
        if r["minimum_level"]:
            e["level"] = int(r["minimum_level"])
    if r["gender_id"]:
        e["gender"] = 1 if r["gender_id"] == "1" else 0  # PokeAPI : 1 = femelle, 2 = mâle
    if r["held_item_id"]:
        e["held"] = items[r["held_item_id"]]["identifier"]
    if r["time_of_day"]:
        e["time"] = r["time_of_day"]
    if r["known_move_id"]:
        e["move"] = int(r["known_move_id"])
    if r["known_move_type_id"]:
        e["move_type"] = types[r["known_move_type_id"]]
    if r["minimum_happiness"] or r["minimum_affection"] or r["minimum_beauty"]:
        e["happiness"] = 160
    if r["relative_physical_stats"]:
        e["stats"] = int(r["relative_physical_stats"])
    if r["party_species_id"]:
        e["party"] = int(r["party_species_id"])
    if r["party_type_id"]:
        e["party_type"] = types[r["party_type_id"]]
    if r["trade_species_id"]:
        e["trade_with"] = int(r["trade_species_id"])
    if r["needs_overworld_rain"] == "1":
        e["rain"] = True
    if r["turn_upside_down"] == "1":
        e["upside"] = True
    if r["location_id"]:
        e["location"] = loc_ident.get(r["location_id"], "")
    if r.get("used_move_id"):
        e["used_move"] = int(r["used_move_id"])
        e["count"] = int(r["minimum_move_count"] or 20)
    if r.get("minimum_steps"):
        e["steps"] = int(r["minimum_steps"])
    if r.get("needs_multiplayer") == "1":
        e["group"] = True
    if r.get("nature_bitmask"):
        mask = int(r["nature_bitmask"])
        e["natures"] = [n["identifier"] for n in NATURE_ROWS if mask >> (int(n["id"]) - 1) & 1]
    if r.get("percentage_chance") and int(r["percentage_chance"]) < 100:
        e["chance"] = int(r["percentage_chance"])
    if trig == "spin":
        e["special"] = "spin"
    return e


# Les évolutions sont rangées par Pokémon de départ (une forme régionale a les siennes).
groups = defaultdict(list)
for r in rows("pokemon_evolution"):
    to = r["evolved_species_id"]
    if to not in species:
        continue
    frm_sp = species[to]["evolves_from_species_id"]
    if not frm_sp or frm_sp not in species:
        continue
    frm = form_to_pokemon(r.get("required_pokemon_form_id")) or int(frm_sp)
    key = (frm, int(to), form_to_pokemon(r.get("evolved_pokemon_form_id")), r.get("region_id") or "")
    groups[key].append(r)
evos = defaultdict(list)
for (frm, to, to_form, region), lst in sorted(groups.items()):
    # Les jeux récents remplacent les lieux spéciaux (champ magnétique, rocher moussu...) par des pierres.
    pool = [r for r in lst if not r["location_id"]] or lst
    latest = max(int(r["version_group_id"] or 0) for r in pool)
    chosen = [r for r in pool if int(r["version_group_id"] or 0) == latest]
    seen = set()
    for r in chosen:
        e = evo_from_row(r)
        k = json.dumps(e, sort_keys=True)
        if k not in seen:
            seen.add(k)
            evos[frm].append(e)

learn = defaultdict(list)
tm = defaultdict(set)
egg = defaultdict(set)
tutor = defaultdict(set)
by_vg = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
for r in rows("pokemon_moves"):
    pid = r["pokemon_id"]
    if pid not in pokemon:
        continue
    meth = r["pokemon_move_method_id"]
    if meth == "4":
        tm[pid].add(int(r["move_id"]))
    elif meth in ("1", "2", "3"):
        by_vg[pid][r["version_group_id"]][meth].append(r)
best_vg = {}
for pid, vgs in by_vg.items():
    vg = next((v for v in VG_ORDER if "1" in vgs.get(v, {})), None)
    if vg is None:
        continue
    best_vg[pid] = vg
    seen = set()
    for r in vgs[vg]["1"]:
        k = (int(r["level"]), int(r["move_id"]))
        if k not in seen:
            seen.add(k)
            learn[pid].append([int(r["level"]), int(r["move_id"])])
    for r in vgs[vg].get("2", []):
        egg[pid].add(int(r["move_id"]))
    for v in VG_ORDER:
        for r in vgs.get(v, {}).get("3", []):
            tutor[pid].add(int(r["move_id"]))
        if vgs.get(v, {}).get("3"):
            break

egg_groups = defaultdict(list)
eg_names = {r["id"]: r["identifier"] for r in rows("egg_groups")}
for r in rows("pokemon_egg_groups"):
    if r["species_id"] in species:
        egg_groups[r["species_id"]].append(eg_names[r["egg_group_id"]])

# Objets tenus par les Pokémon sauvages (version la plus récente qui en donne).
wild_items = defaultdict(dict)
for r in rows("pokemon_items"):
    wild_items[r["pokemon_id"]].setdefault(int(r["version_id"]), []).append([items[r["item_id"]]["identifier"], int(r["rarity"])])

alt_by_species = defaultdict(list)
for pid, p in pokemon.items():
    if int(pid) > MAX_ID:
        alt_by_species[p["species_id"]].append(int(pid))

# Évolutions vers une forme écartée (Dudunsparce à trois segments...) : on garde la forme normale.
# Une règle propre à une région qui donne la même forme qu'ailleurs (Feurisson de Hisui) est inutile.
for frm in list(evos):
    lst = [e for e in evos[frm] if not e.get("to_form") or str(e["to_form"]) in pokemon]
    lst = [e for e in lst if not (e.get("region") and not e.get("to_form")
                                  and any(o["to"] == e["to"] and not o.get("region") for o in lst))]
    for e in lst:
        e.pop("chance", None) if e["to"] in (982, 925) else None
    evos[frm] = lst
# Crèmy : une seule règle par Sucrerie (les variantes d'heure ne changent que la couleur).
for frm in list(evos):
    out, seen = [], set()
    for e in evos[frm]:
        if e.get("special") == "spin":
            e.pop("time", None)
        k = json.dumps(e, sort_keys=True)
        if k not in seen:
            seen.add(k)
            out.append(e)
    evos[frm] = out
# Cheniti : sa cape dépend de l'endroit où il a combattu (herbe, grotte, bâtiment), comme dans les jeux.
for e in evos.get(412, []):
    if e.get("to_form") == 10004:
        e["terrain"] = "cave"
    elif e.get("to_form") == 10005:
        e["terrain"] = "building"
# Cosmovum : Solgaleo le jour, Lunala la nuit (au lieu de Soleil / Lune).
for e in evos.get(790, []):
    e["time"] = "day" if e["to"] == 791 else "night"
out_pkmn = {}
for pid, p in sorted(pokemon.items(), key=lambda kv: int(kv[0])):
    sid = p["species_id"]
    s = species[sid]
    base_id = sid
    ident = p["identifier"]
    is_form = int(pid) > MAX_ID
    fr = forms_by_pokemon.get(pid)
    lrn = learn.get(pid) or learn.get(base_id, [])
    wi = wild_items.get(pid, {})
    entry = {
        "id": int(pid),
        "species": int(sid),
        "name": names[sid],
        "genus": genus.get(sid, ""),
        "dex": dex_text.get(sid, ""),
        "types": ptypes[pid],
        "base": stats[pid],
        "ev": evs[pid],
        "catch": int(s["capture_rate"]),
        "exp": int(p["base_experience"] or 60),
        "growth": int(s["growth_rate_id"]),
        "gender": int(s["gender_rate"]),
        "happiness": int(s["base_happiness"] or 50),
        "legendary": s["is_legendary"] == "1" or s["is_mythical"] == "1",
        "mythical": s["is_mythical"] == "1",
        "baby": s["is_baby"] == "1",
        "gen": int(s["generation_id"]),
        "evolves_from": int(s["evolves_from_species_id"] or 0),
        "abilities": pabil[pid] or pabil.get(base_id, []),
        "ha": hidden.get(pid, hidden.get(base_id, 0)),
        "evos": evos.get(int(pid), []),
        "learn": sorted(lrn),
        "tm": sorted(tm.get(pid) or tm.get(base_id, set())),
        "egg": sorted(egg.get(pid) or egg.get(base_id, set())),
        "tutor": sorted(tutor.get(pid) or tutor.get(base_id, set())),
        "egg_groups": egg_groups[sid],
        "hatch": int(s["hatch_counter"] or 20),
        "baby_of": 0,
        "height": int(p["height"]),
        "weight": int(p["weight"]),
        "wild_items": wi[max(wi)] if wi else [],
    }
    if is_form:
        entry["form"] = ident[len(species[sid]["identifier"]) + 1:] if ident.startswith(species[sid]["identifier"] + "-") else ident
        entry["form_name"] = form_fr.get(fr["id"], "") if fr else ""
        entry["mega"] = "-mega" in ident or "-primal" in ident
        entry["regional"] = next((x[1:] for x in REGIONAL if x in ident), "")
        entry["battle_only"] = entry["mega"] or (fr is not None and fr["is_battle_only"] == "1")
    else:
        entry["forms"] = alt_by_species.get(sid, [])
    out_pkmn[pid] = entry

# --- Capacités -------------------------------------------------------------------
machines_frlg = [r for r in rows("machines") if r["version_group_id"] == FRLG]
machines_sv = [r for r in rows("machines") if r["version_group_id"] == "25"]
move_ids = set()
for p in out_pkmn.values():
    move_ids |= {m for _, m in p["learn"]}
    move_ids |= set(p["tm"]) | set(p["egg"]) | set(p["tutor"])
move_ids |= {int(r["move_id"]) for r in machines_frlg + machines_sv}
move_ids |= {165}  # Lutte

moves = {r["id"]: r for r in rows("moves")}
# On écarte les capacités Z et Dynamax (jamais apprises) et les capacités propres aux jeux Let's Go.
move_ids = {m for m in move_ids if str(m) in moves and int(m) < 10000 and not moves[str(m)]["identifier"].startswith("max-")
            and "--" not in moves[str(m)]["identifier"]}
meta = {r["move_id"]: r for r in rows("move_meta")}
ailments = {r["id"]: r["identifier"] for r in rows("move_meta_ailments")}
targets = {r["id"]: r["identifier"] for r in rows("move_targets")}
mnames = fr_names("move_names", "move_id")
mdesc = last_fr_flavor("move_flavor_text", "move_id", "version_group_id")
mstat = defaultdict(list)
for r in rows("move_meta_stat_changes"):
    mstat[r["move_id"]].append([int(r["stat_id"]), int(r["change"])])
CAT = {"1": "status", "2": "physical", "3": "special"}
FLAG_NAMES = {r["id"]: r["identifier"] for r in rows("move_flags")}
mflags = defaultdict(set)
for r in rows("move_flag_map"):
    mflags[r["move_id"]].add(FLAG_NAMES[r["move_flag_id"]])
# Drapeaux absents de PokeAPI pour la 9e génération, et catégories récentes (tranchant, vent).
G9 = {
    "contact": "dire-claw psyshield-bash stone-axe raging-fury wave-crash headlong-rush ceaseless-edge axe-kick jet-punch spin-out "
               "population-bomb ice-spinner glaive-rush triple-dive mortal-spin kowtow-cleave aqua-step raging-bull psyblade "
               "collision-course pounce trailblaze hyper-drill rage-fist bitter-blade double-shock comeuppance hard-press "
               "temper-flare supercell-slam upper-hand mighty-cleave",
    "punch": "jet-punch rage-fist headlong-rush surging-strikes wicked-blow",
    "sound": "torch-song alluring-voice psychic-noise clangorous-soul overdrive",
    "ballistics": "syrup-bomb pyro-ball",
    "dance": "aqua-step victory-dance",
    "slicing": "cut razor-leaf slash fury-cutter air-cutter leaf-blade night-slash air-slash x-scissor psycho-cut cross-poison "
               "sacred-sword razor-shell secret-sword solar-blade behemoth-blade stone-axe ceaseless-edge population-bomb "
               "kowtow-cleave psyblade bitter-blade aqua-cutter tachyon-cutter mighty-cleave aerial-ace",
    "wind": "aeroblast air-cutter bleakwind-storm blizzard fairy-wind gust heat-wave hurricane icy-wind petal-blizzard "
            "sandsear-storm sandstorm springtide-storm tailwind twister whirlwind wildbolt-storm",
}
for flag, idents in G9.items():
    for ident in idents.split():
        for mid, m in moves.items():
            if m["identifier"] == ident:
                mflags[mid].add(flag)

# Capacités des derniers jeux (Légendes Arceus, Écarlate / Violet) : PokeAPI n'a pas leurs effets.
# mcat : 0 dégâts, 1 statut, 2 stats, 4 dégâts+statut, 6 dégâts+baisse, 7 dégâts+hausse (lanceur), 8 dégâts+soin.
MANUAL_META = {
    "dire-claw": {"mcat": 4, "ail": "dire", "ail_ch": 50, "crit": 1},
    "psyshield-bash": {"mcat": 7, "stats": [[3, 1]], "stat_ch": 100},
    "stone-axe": {"crit": 1},
    "springtide-storm": {"mcat": 6, "stats": [[2, -1]], "stat_ch": 30},
    "mystical-power": {"mcat": 7, "stats": [[4, 1]], "stat_ch": 100},
    "raging-fury": {},
    "wave-crash": {"drain": -33},
    "chloroblast": {},
    "mountain-gale": {"flinch": 30},
    "victory-dance": {"mcat": 2, "stats": [[2, 1], [3, 1], [6, 1]]},
    "headlong-rush": {"mcat": 7, "stats": [[3, -1], [5, -1]], "stat_ch": 100},
    "barb-barrage": {"mcat": 4, "ail": "poison", "ail_ch": 50},
    "esper-wing": {"mcat": 7, "stats": [[6, 1]], "stat_ch": 100, "crit": 1},
    "bitter-malice": {"mcat": 6, "stats": [[2, -1]], "stat_ch": 100},
    "shelter": {"mcat": 2, "stats": [[3, 2]]},
    "triple-arrows": {"mcat": 6, "stats": [[3, -1]], "stat_ch": 50, "flinch": 30, "crit": 1},
    "infernal-parade": {"mcat": 4, "ail": "burn", "ail_ch": 30},
    "ceaseless-edge": {"crit": 1},
    "bleakwind-storm": {"mcat": 6, "stats": [[6, -1]], "stat_ch": 30},
    "wildbolt-storm": {"mcat": 4, "ail": "paralysis", "ail_ch": 20},
    "sandsear-storm": {"mcat": 4, "ail": "burn", "ail_ch": 20},
    "lunar-blessing": {"mcat": 13},
    "take-heart": {"mcat": 2, "stats": [[4, 1], [5, 1]]},
    "tera-blast": {},
    "silk-trap": {"mcat": 13},
    "axe-kick": {"mcat": 4, "ail": "confusion", "ail_ch": 30},
    "last-respects": {},
    "lumina-crash": {"mcat": 6, "stats": [[5, -2]], "stat_ch": 100},
    "order-up": {},
    "jet-punch": {},
    "spicy-extract": {"mcat": 2, "stats": [[2, 2], [3, -2]]},
    "spin-out": {"mcat": 7, "stats": [[6, -2]], "stat_ch": 100},
    "population-bomb": {"min_hits": 1, "max_hits": 10},
    "ice-spinner": {},
    "glaive-rush": {},
    "revival-blessing": {"mcat": 13},
    "salt-cure": {},
    "triple-dive": {"min_hits": 3, "max_hits": 3},
    "mortal-spin": {"mcat": 4, "ail": "poison", "ail_ch": 100},
    "doodle": {"mcat": 13},
    "fillet-away": {"mcat": 13},
    "kowtow-cleave": {},
    "flower-trick": {},
    "torch-song": {"mcat": 7, "stats": [[4, 1]], "stat_ch": 100},
    "aqua-step": {"mcat": 7, "stats": [[6, 1]], "stat_ch": 100},
    "raging-bull": {},
    "make-it-rain": {"mcat": 7, "stats": [[4, -1]], "stat_ch": 100},
    "psyblade": {},
    "hydro-steam": {},
    "ruination": {},
    "collision-course": {},
    "electro-drift": {},
    "shed-tail": {"mcat": 13},
    "chilly-reception": {"mcat": 13},
    "tidy-up": {"mcat": 13},
    "snowscape": {"mcat": 10},
    "pounce": {"mcat": 6, "stats": [[6, -1]], "stat_ch": 100},
    "trailblaze": {"mcat": 7, "stats": [[6, 1]], "stat_ch": 100},
    "chilling-water": {"mcat": 6, "stats": [[2, -1]], "stat_ch": 100},
    "hyper-drill": {},
    "twin-beam": {"min_hits": 2, "max_hits": 2},
    "rage-fist": {},
    "armor-cannon": {"mcat": 7, "stats": [[3, -1], [5, -1]], "stat_ch": 100},
    "bitter-blade": {"mcat": 8, "drain": 50},
    "double-shock": {},
    "gigaton-hammer": {},
    "comeuppance": {},
    "aqua-cutter": {"crit": 1},
    "blood-moon": {},
    "matcha-gotcha": {"mcat": 4, "ail": "burn", "ail_ch": 20, "drain": 50},
    "ivy-cudgel": {"crit": 1},
    "electro-shot": {},
    "tera-starstorm": {},
    "fickle-beam": {},
    "burning-bulwark": {"mcat": 13},
    "thunderclap": {},
    "mighty-cleave": {},
    "tachyon-cutter": {"min_hits": 2, "max_hits": 2},
    "hard-press": {},
    "dragon-cheer": {"mcat": 13},
    "alluring-voice": {},
    "temper-flare": {},
    "supercell-slam": {},
    "psychic-noise": {},
    "upper-hand": {"flinch": 100},
    "malignant-chain": {"mcat": 4, "ail": "poison", "ail_ch": 50},
}

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
        "flags": sorted(mflags.get(str(mid), set())),
        "gen": int(m["generation_id"]),
    }
    if m["identifier"] in MANUAL_META:
        out_moves[str(mid)].update(MANUAL_META[m["identifier"]])

# --- Talents --------------------------------------------------------------------
abil_ids = {a for p in out_pkmn.values() for a in p["abilities"]} | {p["ha"] for p in out_pkmn.values() if p["ha"]}
anames = fr_names("ability_names", "ability_id")
adesc = last_fr_flavor("ability_flavor_text", "ability_id", "version_group_id")
aident = {r["id"]: r["identifier"] for r in rows("abilities")}
out_abil = {
    str(a): {"ident": aident[str(a)], "name": anames.get(str(a), aident[str(a)].replace("-", " ").title()), "desc": adesc.get(str(a), "")}
    for a in sorted(abil_ids)
}

# --- Objets ---------------------------------------------------------------------
KEY_ITEMS = """oaks-parcel silph-scope poke-flute secret-key helix-fossil dome-fossil old-amber bicycle
card-key ss-ticket town-map gold-teeth exp-share old-rod good-rod super-rod mega-ring z-ring shiny-charm oval-charm
reveal-glass gracidea prison-bottle meteorite zygarde-cube scroll-of-darkness scroll-of-waters dna-splicers""".split()
ITEMS = """nugget big-nugget pearl big-pearl pearl-string stardust star-piece comet-shard rare-bone tiny-mushroom
big-mushroom balm-mushroom heart-scale bottle-cap gold-bottle-cap ability-capsule honey
poke-ball great-ball ultra-ball master-ball premier-ball net-ball nest-ball repeat-ball timer-ball luxury-ball dusk-ball
heal-ball quick-ball level-ball moon-ball heavy-ball fast-ball friend-ball love-ball lure-ball dream-ball beast-ball dive-ball
potion super-potion hyper-potion max-potion full-restore revive max-revive antidote paralyze-heal awakening burn-heal
ice-heal full-heal ether max-ether elixir max-elixir fresh-water soda-pop lemonade moomoo-milk rare-candy
hp-up protein iron calcium zinc carbos pp-up pp-max exp-candy-xs exp-candy-s exp-candy-m exp-candy-l exp-candy-xl
x-attack x-defense x-sp-atk x-sp-def x-speed x-accuracy dire-hit guard-spec
repel super-repel max-repel escape-rope poke-doll
root-fossil claw-fossil armor-fossil skull-fossil cover-fossil plume-fossil jaw-fossil sail-fossil
fossilized-bird fossilized-fish fossilized-drake fossilized-dino odd-keystone""".split()
# Catégories PokeAPI reprises en entier : objets tenus, baies, objets d'évolution, Méga-Gemmes...
HELD_CATS = {"held-items", "choice", "effort-training", "bad-held-items", "training", "plates", "species-specific",
             "type-enhancement", "jewels", "mega-stones", "memories", "z-crystals", "evolution", "in-a-pinch",
             "picky-healing", "type-protection", "medicine", "other", "effort-drop", "nature-mints"}
SKIP_ITEMS = {"exp-share", "red-nectar", "yellow-nectar", "pink-nectar", "purple-nectar", "black-augurite", "peat-block",
              "metal-alloy", "wellspring-mask", "hearthflame-mask", "cornerstone-mask"}
for r in items.values():
    if item_cats.get(r["category_id"]) in HELD_CATS and r["identifier"] not in SKIP_ITEMS and r["identifier"] not in ITEMS:
        ITEMS.append(r["identifier"])
ITEMS += ["red-orb", "blue-orb", "rusted-sword", "rusted-shield", "adamant-crystal", "lustrous-globe", "griseous-core",
          "wellspring-mask", "hearthflame-mask", "cornerstone-mask", "booster-energy"]
# Prix des objets tenus pour les boutiques de combat (PokeAPI en met souvent 0).
DEFAULT_HELD_PRICE = {"mega-stones": 0, "z-crystals": 0, "memories": 15000, "plates": 15000, "jewels": 3000,
                      "type-enhancement": 8000, "choice": 25000, "held-items": 15000, "in-a-pinch": 2000,
                      "picky-healing": 1500, "type-protection": 1500, "medicine": 800, "other": 2500,
                      "evolution": 3000, "species-specific": 8000, "effort-training": 10000, "training": 10000,
                      "bad-held-items": 5000, "nature-mints": 15000, "effort-drop": 500}
PRICES = {"ability-capsule": 30000, "bottle-cap": 25000, "gold-bottle-cap": 100000, "heart-scale": 500,
          "exp-candy-xs": 100, "exp-candy-s": 800, "exp-candy-m": 3000, "exp-candy-l": 10000, "exp-candy-xl": 30000}
berries = {r["item_id"]: r for r in rows("berries")}
out_items = {}
for ident in ITEMS:
    r = item_by_ident.get(ident)
    if r is None:
        print("objet introuvable :", ident)
        continue
    cat = item_cats.get(r["category_id"], "")
    price = PRICES.get(ident, int(r["cost"] or 0))
    if price == 0 and cat in DEFAULT_HELD_PRICE:
        price = DEFAULT_HELD_PRICE[cat]
    entry = {"name": item_names.get(r["id"], ident.replace("-", " ").title()), "desc": item_desc.get(r["id"], ""),
             "price": price, "cat": cat}
    if 5 in item_flags[r["id"]] or cat in HELD_CATS or ident in ("red-orb", "blue-orb", "rusted-sword", "rusted-shield",
                                                                  "adamant-crystal", "lustrous-globe", "griseous-core", "booster-energy"):
        entry["held"] = True
    if r["fling_power"]:
        entry["fling"] = int(r["fling_power"])
    if r["id"] in berries:
        b = berries[r["id"]]
        entry["berry"] = True
        entry["ng"] = [types.get(b["natural_gift_type_id"], "normal"), int(b["natural_gift_power"] or 80)]
    out_items[ident] = entry
# Objets absents de PokeAPI.
out_items["ability-patch"] = {"name": "Patch Talent", "desc": "Un patch qui donne à un Pokémon son talent caché.",
                              "price": 120000, "cat": "vitamins"}
out_items["meltan-candy"] = {"name": "Bonbon Meltan", "desc": "Un énorme bonbon. Fait évoluer Meltan en Melmetal.",
                             "price": 20000, "cat": "evolution"}
out_items["gimmighoul-coin"] = {"name": "Pièce de Mordudor", "desc": "999 pièces réunies. Fait évoluer Mordudor en Gromago.",
                                "price": 30000, "cat": "evolution"}
out_items["leaders-crest"] = {"name": "Emblème du Général", "desc": "Prouve que trois Scalproie ont été vaincus. Fait évoluer Scalproie en Scalpereur.",
                              "price": 20000, "cat": "evolution"}
for ident in KEY_ITEMS:
    r = item_by_ident.get(ident)
    if r is None:
        print("objet rare introuvable :", ident)
        continue
    out_items[ident] = {"name": item_names.get(r["id"], ident), "desc": item_desc.get(r["id"], ""), "price": 0, "key": True}
for r in sorted(machines_frlg, key=lambda r: int(r["machine_number"])):
    n = int(r["machine_number"])
    kind = "CT" if n <= 50 else "CS"
    num = n if n <= 50 else n - 50
    mid = r["move_id"]
    out_items[f"tm{n:02d}"] = {"name": f"{kind}{num:02d} {mnames.get(mid, '')}", "desc": mdesc.get(mid, ""),
                               "price": 3000 if kind == "CT" else 0, "move": int(mid)}
# CT modernes (Écarlate / Violet) : vendues dans les autres régions et en fin de jeu.
frlg_moves = {int(r["move_id"]) for r in machines_frlg}
for r in sorted(machines_sv, key=lambda r: int(r["machine_number"])):
    n = int(r["machine_number"])
    mid = r["move_id"]
    if int(mid) in frlg_moves:
        continue
    power = int(moves[mid]["power"] or 0)
    out_items[f"tmsv{n:03d}"] = {"name": f"CT{n:03d} {mnames.get(mid, '')}", "desc": mdesc.get(mid, ""),
                                 "price": 5000 if power < 80 else 10000 if power < 100 else 20000, "move": int(mid)}

# --- Méga-Gemmes et Cristaux Z -----------------------------------------------
# Méga-Gemme -> forme Méga : on rapproche le nom de la gemme de celui du Pokémon.
mega_forms = {p["identifier"]: int(pid) for pid, p in pokemon.items() if "-mega" in p["identifier"]}
MEGA_STONES = {}
for ident, it in out_items.items():
    if it.get("cat") != "mega-stones":
        continue
    suffix = ""
    stem = ident
    for sfx in ("-x", "-y", "-z"):
        if ident.endswith(sfx):
            suffix, stem = sfx, ident[:-2]
    best, best_len = None, 0
    for fid, pid in mega_forms.items():
        sp_ident = fid.split("-mega")[0]
        if not fid.endswith("-mega" + suffix):
            continue
        n = 0
        while n < min(len(stem), len(sp_ident)) and stem[n] == sp_ident[n]:
            n += 1
        if n > best_len:
            best, best_len = pid, n
    if best and best_len >= 4:
        MEGA_STONES[ident] = best
    else:
        print("Méga-Gemme sans forme :", ident)
# Cristaux Z : type ou capacité exclusive.
ZNAME = {r["identifier"]: mnames.get(r["id"], r["identifier"]) for r in moves.values() if 622 <= int(r["id"]) <= 728}
Z_TYPES = {"normal": "breakneck-blitz", "fighting": "all-out-pummeling", "flying": "supersonic-skystrike",
           "poison": "acid-downpour", "ground": "tectonic-rage", "rock": "continental-crush", "bug": "savage-spin-out",
           "ghost": "never-ending-nightmare", "steel": "corkscrew-crash", "fire": "inferno-overdrive",
           "water": "hydro-vortex", "grass": "bloom-doom", "electric": "gigavolt-havoc", "psychic": "shattered-psyche",
           "ice": "subzero-slammer", "dragon": "devastating-drake", "dark": "black-hole-eclipse", "fairy": "twinkle-tackle"}
Z_CRYSTALS = {}
for t, z in Z_TYPES.items():
    crystal = {"normal": "normalium", "fighting": "fightinium", "flying": "flyinium", "poison": "poisonium",
               "ground": "groundium", "rock": "rockium", "bug": "buginium", "ghost": "ghostium", "steel": "steelium",
               "fire": "firium", "water": "waterium", "grass": "grassium", "electric": "electrium", "psychic": "psychium",
               "ice": "icium", "dragon": "dragonium", "dark": "darkinium", "fairy": "fairium"}[t] + "-z--held"
    Z_CRYSTALS[crystal] = {"type": t, "name": ZNAME[z + "--physical"]}
# Capacités Z exclusives : [Pokémon, capacité de base, nom, puissance, effet]
Z_SPECIAL = {"pikanium-z--held": [25, "volt-tackle", "catastropika", 210],
             "decidium-z--held": [724, "spirit-shackle", "sinister-arrow-raid", 180],
             "incinium-z--held": [727, "darkest-lariat", "malicious-moonsault", 180],
             "primarium-z--held": [730, "sparkling-aria", "oceanic-operetta", 195],
             "tapunium-z--held": [0, "natures-madness", "guardian-of-alola", 0],
             "marshadium-z--held": [802, "spectral-thief", "soul-stealing-7-star-strike", 195],
             "aloraichium-z--held": [10100, "thunderbolt", "stoked-sparksurfer", 175],
             "snorlium-z--held": [143, "giga-impact", "pulverizing-pancake", 210],
             "eevium-z--held": [133, "last-resort", "extreme-evoboost", 0],
             "mewnium-z--held": [151, "psychic", "genesis-supernova", 185],
             "pikashunium-z--held": [25, "thunderbolt", "10-000-000-volt-thunderbolt", 195]}
for crystal, (sp, base, z, pw) in Z_SPECIAL.items():
    base_id = next((int(r["id"]) for r in moves.values() if r["identifier"] == base), 0)
    Z_CRYSTALS[crystal] = {"species": sp, "move": base_id, "name": ZNAME.get(z, z), "power": pw, "z": z}

# --- Natures, courbes d'expérience ---------------------------------------------
nat_names = fr_names("nature_names", "nature_id")
out_nat = []
for r in sorted(rows("natures"), key=lambda r: int(r["game_index"])):
    up, down = int(r["increased_stat_id"]), int(r["decreased_stat_id"])
    out_nat.append({"name": nat_names[r["id"]], "ident": r["identifier"], "up": up - 1 if up != down else -1, "down": down - 1 if up != down else -1})

# Caractère (« Il aime la vitesse »...) : dépend du meilleur IV et de sa valeur modulo 5.
char_text = {r["characteristic_id"]: r["message"] for r in rows("characteristic_text") if r["local_language_id"] == FR}
out_char = [{"stat": int(r["stat_id"]) - 1, "mod": int(r["gene_mod_5"]), "text": char_text[r["id"]]} for r in rows("characteristics")]

exp = defaultdict(lambda: [0] * 101)
for r in rows("experience"):
    if int(r["level"]) <= 100:
        exp[int(r["growth_rate_id"])][int(r["level"])] = int(r["experience"])

type_fr = {types[r["type_id"]]: r["name"] for r in rows("type_names") if r["local_language_id"] == FR and r["type_id"] in types}


# --- Rencontres sauvages -------------------------------------------------------
areas = {r["id"]: r for r in rows("location_areas")}
locs = {r["id"]: r["identifier"] for r in rows("locations")}
slots = {r["id"]: r for r in rows("encounter_slots")}
methods = {r["id"]: r["identifier"] for r in rows("encounter_methods")}
KIND = {"walk": "grass", "surf": "water", "old-rod": "water", "good-rod": "water", "super-rod": "water",
        "rock-smash": "rock", "headbutt": "tree", "dark-grass": "grass", "grass-spots": "grass", "cave-spots": "grass",
        "bridge-spots": "grass", "surf-spots": "water", "super-rod-spots": "water", "yellow-flowers": "grass",
        "red-flowers": "grass", "purple-flowers": "grass", "rough-terrain": "grass", "sos-encounter": "grass",
        "overworld": "grass", "overworld-water": "water", "overworld-flying": "grass", "gift": None}


def area_key(r):
    a = areas[r["location_area_id"]]
    return locs[a["location_id"]] + ("/" + a["identifier"] if a["identifier"] else "")


def merge_table(lst):
    merged = {}
    for sid, lo, hi, w in lst:
        if sid in merged:
            m = merged[sid]
            m[1] = min(m[1], lo); m[2] = max(m[2], hi); m[3] += w
        else:
            merged[sid] = [sid, lo, hi, w]
    return sorted(merged.values(), key=lambda x: -x[3])


# Kanto : Rouge Feu (version 10), utilisé tel quel par la région de départ.
enc = defaultdict(lambda: defaultdict(list))
all_enc = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
for r in rows("encounters"):
    if int(r["pokemon_id"]) > MAX_ID:
        continue
    m = methods[slots[r["encounter_slot_id"]]["encounter_method_id"]]
    entry = [int(r["pokemon_id"]), int(r["min_level"]), int(r["max_level"]), int(slots[r["encounter_slot_id"]]["rarity"] or 1)]
    if r["version_id"] == "10" and int(r["pokemon_id"]) <= 151:
        kind = "grass" if m == "walk" else "water" if m in ("surf", "super-rod", "good-rod", "old-rod") else None
        if kind is not None:
            enc[area_key(r)][kind].append(entry)
    kind2 = KIND.get(m, "grass" if "rod" not in m else "water")
    if kind2 is not None:
        all_enc[r["version_id"]][area_key(r)][kind2].append(entry)
        if m.endswith("-rod"):
            all_enc[r["version_id"]][area_key(r)][m].append(list(entry))
out_enc = {}
for key, kinds in enc.items():
    out_enc[key] = {kind: merge_table(lst) for kind, lst in kinds.items()}

# Pêche : une table par canne. Rouge Feu seul est très pauvre (la Canne ne donne que Magicarpe) :
# on la complète avec Cristal et HeartGold, qui ont les mêmes lieux de Kanto. Chaque jeu pèse autant.
ROD_VERSIONS = ("10", "6", "15")
rod_src = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
for r in rows("encounters"):
    if r["version_id"] not in ROD_VERSIONS or int(r["pokemon_id"]) > 251:
        continue
    m = methods[slots[r["encounter_slot_id"]]["encounter_method_id"]]
    if not m.endswith("-rod"):
        continue
    rod_src[area_key(r)][m][r["version_id"]].append((int(r["pokemon_id"]), int(r["min_level"]), int(r["max_level"]), int(slots[r["encounter_slot_id"]]["rarity"])))
for key, rods in rod_src.items():
    for rod, per_version in rods.items():
        merged = {}
        for lst in per_version.values():
            total = sum(e[3] for e in lst) or 1
            for sid, lo, hi, w in lst:
                m = merged.setdefault(sid, [sid, lo, hi, 0.0])
                m[1] = min(m[1], lo); m[2] = max(m[2], hi); m[3] += 100.0 * w / total
        table = [[sid, lo, hi, max(1, round(w))] for sid, lo, hi, w in merged.values()]
        out_enc.setdefault(key, {})[rod] = sorted(table, key=lambda x: -x[3])

# Toutes les autres versions : servent à construire les autres régions (tools/build_world.py).
out_all = {v: {k: {kind: merge_table(lst) for kind, lst in kinds.items()} for k, kinds in keys.items()} for v, keys in all_enc.items()}
loc_names_fr = {}
for r in rows("location_names"):
    if r["local_language_id"] == FR:
        loc_names_fr[loc_ident.get(r["location_id"], "")] = r["name"]
loc_region = {r["identifier"]: r["region_id"] for r in rows("locations")}


def dump(name, obj, folder=OUT):
    with open(f"{folder}/{name}.json", "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))


dump("encounters", out_enc)
dump("pokemon", out_pkmn)
dump("moves", out_moves)
dump("abilities", out_abil)
dump("items", out_items)
dump("misc", {"mega_stones": MEGA_STONES, "z_crystals": Z_CRYSTALS, "natures": out_nat, "characteristics": out_char, "exp": {str(k): v for k, v in exp.items()}, "types": type_fr})
TOOLS = os.path.dirname(os.path.abspath(__file__))
dump("encounters_all", {"versions": out_all, "names": loc_names_fr, "regions": loc_region}, TOOLS)
print(len([p for p in out_pkmn.values() if "form" not in p]), "espèces,", len(out_pkmn), "Pokémon avec les formes,",
      len(out_moves), "capacités,", len(out_abil), "talents,", len(out_items), "objets")
