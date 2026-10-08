# Pokémon Revolution — Route 1 (copie privée)

Jeu à part, dans le style de Pokémon Revolution Online : la Route 1 avec Reptincel qui te suit,
et toute l'interface de PRO (équipe, heure locale / heure Poké, lieu, menu en arc, argent, raccourcis, discussion à onglets).

**Lancer :** Godot 4.3 → Importer → `pro/project.godot` → F5.

| Touche | Action |
|---|---|
| Flèches ou ZQSD | Se déplacer (appui bref : se tourner) |
| Maj | Courir |
| Espace ou E | Parler / lire le panneau |
| Entrée | Écrire dans la discussion (Échap pour annuler) |
| F2 | Avancer l'heure Poké de 3 heures (voir le jour, le soir, la nuit) |

L'heure Poké défile 4 fois plus vite que l'heure réelle : la nuit, la route devient bleu sombre comme dans PRO.

Tous les graphismes sont dessinés par programme (`tools/make_art.py`, `tools/make_hud.py`, `tools/make_map.py`) ;
seules les icônes de l'équipe viennent de PokeAPI. Polices : Arimo et Pixelify Sans (licence OFL).
