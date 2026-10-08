# Pokémon Kanto (Godot 4)

Fan-game Pokémon pour jouer à deux à la maison. Usage privé uniquement : les sprites et les noms Pokémon appartiennent à Nintendo / Game Freak.

## Lancer le jeu

1. Récupère le projet :
   - soit en ZIP : https://github.com/bodji27200-web/projet-actuelle-octobre./archive/refs/heads/claude/godot-game-desktop-folder-yfw8m3.zip (clic droit → Extraire tout) ;
   - soit avec git : `git clone -b claude/godot-game-desktop-folder-yfw8m3 https://github.com/bodji27200-web/projet-actuelle-octobre..git`
2. Ouvre **Godot 4.3 ou plus récent** → **Importer** → choisis `jeu/project.godot` → **Importer et modifier**.
3. Appuie sur **F5**.

**Internet est nécessaire au premier lancement** : les sprites officiels des Pokémon (faces, dos, chromatiques, icônes, objets) sont téléchargés depuis PokeAPI, puis gardés sur ton PC. Tant qu'un sprite n'est pas arrivé, une silhouette grise s'affiche.

## Touches

| Action | Touche |
|---|---|
| Se déplacer | Flèches ou ZQSD |
| A (valider, parler) | Entrée, Espace ou E |
| B (retour) | Échap, Retour arrière ou X |
| Menu (Pokédex, Pokémon, Sac, Sauver…) | Tab ou M |
| Courir | Maj |

## Contenu

- **Les 151 Pokémon de Kanto**, avec leurs vraies stats, types, talents, apprentissages par niveau, CT et évolutions (niveau, pierres, Fil de Liaison pour les évolutions par échange).
- **303 capacités** avec leurs effets : statuts, changements de stats, météo, attaques en deux tours, multi-coups, Vampigraine, Clonage, Abri, Morphing, Métronome…
- **IV (0-31), EV (252/510), 25 natures, talents, shiny (1/4096), sexe, bonheur.** Tout est visible dans le résumé (page STATS).
- **Vraie formule de capture** (PV restants, statut, taux de l'espèce) et **20 types de Balls** avec leurs effets (Filet, Faiblo, Chrono, Sombre, Rapide, Bis, Niveau, Lune, Masse, Speed, Love, Soin, Copain, Luxe, Honor, Master…).
- Combats sauvages et contre des dresseurs (IA qui choisit ses attaques), expérience, montée de niveau, apprentissage de capacités, évolution (annulable avec B).
- Début de l'aventure : intro du Prof. Chen, choix du starter, combat contre le rival, Pokédex. Ensuite : Route 1, Jadielle (Centre Pokémon, Boutique), Route 22, Route 2, Forêt de Jade, **Plaine Sauvage** (toutes les formes de base sauvages, marais pour les Pokémon Eau, dresseurs forts) et **Grotte Céleste** (Artikodin, Électhor, Sulfura, Mewtwo, Mew, fossiles, Master Ball).
- PC de stockage, boutiques (Balls, soins, pierres, vitamines, CT), sauvegarde.

## Pour les développeurs

- `jeu/tools/build_data.py` régénère `jeu/data/*.json` depuis les CSV de PokeAPI ; `jeu/tools/build_maps.py` régénère les cartes et vérifie qu'elles sont toutes accessibles.
- `jeu/tests/smoke_test.tscn` (combats et écrans) et `jeu/tests/play_test.tscn` (robot qui joue le début du jeu) se lancent avec `godot --headless`.
