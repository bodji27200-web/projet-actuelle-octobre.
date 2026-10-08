# Pokémon Kanto (Godot 4)

Fan-game Pokémon pour jouer seul ou à deux, en coop. Usage privé uniquement : les sprites, les cris et les noms Pokémon appartiennent à Nintendo / Game Freak.

## Lancer le jeu

1. Récupère le projet :
   - en ZIP : https://github.com/bodji27200-web/projet-actuelle-octobre./archive/refs/heads/claude/godot-game-desktop-folder-yfw8m3.zip (clic droit → Extraire tout) ;
   - ou avec git : `git clone -b claude/godot-game-desktop-folder-yfw8m3 https://github.com/bodji27200-web/projet-actuelle-octobre..git`
2. Ouvre **Godot 4.3 ou plus récent** → **Importer** → `jeu/project.godot` → **Importer et modifier**.
3. Appuie sur **F5**.

**Internet est nécessaire au premier lancement** : les sprites officiels et les cris des Pokémon sont téléchargés depuis PokeAPI, puis gardés sur le PC.

Les sauvegardes déjà commencées restent valables. Si une carte a changé sous tes pieds, tu réapparais sur la case libre la plus proche.

## Touches (modifiables dans PARAMÈTRES → Touches)

| Action | Touche par défaut |
|---|---|
| Se déplacer | Flèches ou ZQSD |
| A (valider, parler, pêcher face à l'eau) | Entrée ou Espace |
| B (retour) | Échap ou Retour arrière |
| Menu | Tab ou M |
| Courir | Maj |
| Vélo | V |
| Carte de la région | C |
| Discussion (chat) | T |

## Jouer à deux (multijoueur et coop)

1. Les deux lancent le jeu et chargent leur propre partie (chacun garde sa sauvegarde).
2. Le premier ouvre **Menu → MULTIJOUEUR → HÉBERGER**. Le jeu affiche son adresse (ex. `192.168.1.20`).
3. Le second fait **MULTIJOUEUR → REJOINDRE** et tape cette adresse.
4. Vous vous voyez sur la carte. Pour faire équipe : **MULTIJOUEUR → INVITER DANS LE GROUPE** (ou parle à l'autre joueur).

**En groupe et sur la même carte, tous les combats deviennent des 2 contre 2** :
- dans les hautes herbes, **deux Pokémon sauvages** apparaissent ;
- chaque Dresseur appelle **un camarade de la même catégorie** (un Sbire Rocket appelle un autre Sbire Rocket, un Champion appelle son Disciple) ;
- les **Arènes** se font aussi en duo, et les deux joueurs gagnent le Badge ;
- les **boss** se combattent à deux contre un.

Si vous n'êtes pas dans le même groupe, chacun joue normalement, même sur la même carte.

**Connexion :**
- **Même Wi-Fi / même box** : ça marche directement.
- **À distance** : installez tous les deux un VPN gratuit comme **Radmin VPN** ou **ZeroTier**, rejoignez le même réseau, puis utilisez l'adresse affichée par le VPN. Sinon, l'hôte doit ouvrir le port **24680 (UDP)** sur sa box.

## En ligne : échanges, Hôtel des Ventes, guildes, combats classés

Dans chaque **Centre Pokémon**, quatre guichets :
- **Hôtel des Ventes** : mets en vente un Pokémon ou un objet, achète ceux des autres joueurs (le vendeur est payé automatiquement, même s'il n'était pas connecté au moment de la vente) ;
- **Guildes** : fonde ou rejoins une guilde, gagne des points de guilde en jouant, classement des guildes ;
- **Arène Classée** : combats contre l'autre joueur, **classement Elo** par format, avec les vraies règles de Smogon (tiers OU, Ubers, UU, RU, Little Cup, Double style VGC). Clauses Sommeil, Espèce, OHKO, Esquive, Lunatique, match nul au 300e tour. Le joueur adverse est un vrai joueur : chacun voit le combat de son côté ;
- **Bases Secrètes** : une base à décorer avec meubles, peluches, plantes et **trophées des boss vaincus**, partagée avec ton groupe.

Et partout :
- **Échange direct** : parle à l'autre joueur → ÉCHANGER (les évolutions par échange se déclenchent) ;
- **Discussion à canaux** (touche T) : Commerce, Aide, Guilde, Langues ;
- **Carte de profil** (parle à un joueur → PROFIL, ou menu CARTE) : heures de jeu, chromatiques, plus gros dégâts infligés, Pokédex, victoires, Elo… et ton **titre** affiché sous ton nom (27 titres à débloquer).

## Contenu

### Kanto, puis neuf autres régions
- **Tout Kanto** : 11 villes, 25 routes, tous les donjons, 8 Arènes, Conseil 4, Maître de la Ligue, Panthéon. Histoire complète avec ton rival **Régis**, la Team Rocket et Giovanni. Le **JOURNAL** indique toujours la prochaine étape.
- **Après la Ligue, la grande suite** : la **Team Rainbow Rocket** de Giovanni a recruté les chefs des équipes criminelles de toutes les régions. Le Prof. Chen te donne le **Passe Croisière** : le capitaine du port de Carmin-sur-Mer t'emmène, région par région :
  **Îles Sevii → Johto → Hoenn → Sinnoh (et Hisui, dans le passé) → Unys → Kalos → Alola → Galar → Paldea**.
- Chaque région a ses **villes et lieux officiels** (noms français officiels), ses **vraies listes de Pokémon sauvages** (écrites à la main pour Paldea), son professeur et ses **trois starters**, son repaire de la Team Rainbow Rocket à démanteler, son **Maître** à battre (qui rend un **Fragment Arc-en-Ciel**), ses boutiques et ses quêtes : Bracelet Z et Pokémon Dominants à Alola, Méga-Anneau et Méga-Gemmes à Kalos, Dojo de la Maîtrise à Galar, Pokémon Titans et Septentria à Paldea…
- **Légendaires rares et cachés dans des endroits dangereux** : au fond des grottes, derrière des sceaux qui ne cèdent qu'au Maître de la région, ou errants (une chance sur plusieurs centaines par pas). Un légendaire mis K.O. n'est pas perdu : il revient.
- **Boss et mini-boss à aura** (feu, acier, électrique, spectre, dragon, plante, ténèbres, eau, glace, psy, fée, combat, roche, sol, vol) : chaque aura donne un vrai avantage au boss. Les boss vaincus donnent un trophée pour ta Base Secrète.
- **Fin de jeu** : les huit Fragments ouvrent le **Château Rocket** et le combat final contre Giovanni (niveau 90, aura). Puis **l'Abîme** : dix étages de dresseurs du niveau 91 au niveau 100, aux équipes compétitives (IV parfaits, EV optimisés, IA maximale), le **Gardien de l'Abîme** (six légendaires niveau 100 à aura : même une équipe parfaite perd souvent)… et **Arceus**.
- **Entraînement** : Centre d'Entraînement EV des Îles Sevii (six salles, une par statistique), Boutique de l'Élite (Capsules d'Argent et d'Or pour les IV, Aromates, objets Pouvoir, Bracelet Macho), **Maître des Capacités** dans chaque Centre Pokémon (réapprendre gratuitement une capacité, y compris les capacités Œuf).

### Pokémon et combats
- **Les 1025 Pokémon**, tous obtenables (sauvages, légendaires, dons, starters, fossiles, évolutions), avec leurs formes régionales (Alola, Galar, Hisui, Paldea), Méga-Évolutions et Primo-Résurgences. Vérifié par deux outils indépendants.
- **797 capacités** et **313 talents** de toutes les générations, capacités Z, Méga-Évolutions.
- **482 objets tenus**, tous actifs en combat (Restes, Mouchoir Choix, Orbe Vie, Ceinture Force, Baies, Gemmes, Plaques, Casque Brut, Pare-Effet…), et hors combat (Grelot Zen, Rune Purifiante, Poké Poupée…).
- **Animations de combat** pour chaque capacité (mise en scène selon la capacité, couleurs de son type), et affichage des **buffs/debuffs** (flèches de stats) sur chaque Pokémon.
- **Pokémon suiveur** : ton premier Pokémon te suit sur la carte (désactivable dans les Paramètres). Parle-lui !
- IV, EV, 25 natures, **chromatiques (1/4096)**, formule de capture officielle et **toutes les Balls**, niveau maximum 100, évolutions de toutes sortes (niveau, objets, échange ou Fil de Liaison, bonheur, capacités, lieux…).
- **Pêche** (trois cannes), **Œufs** et Pension, **15 tenues**, **mini-carte** et **carte de chaque région** (touche C) avec ta position et celle de ton partenaire.
- **Paramètres** : vitesse du texte, volumes, cris, animations, mini-carte, Pokémon suiveur, noms au-dessus des joueurs, taille de la fenêtre, **difficulté** (Normale / Difficile / Extrême) et **touches modifiables**.
- **Sons** : cris officiels des Pokémon (téléchargés) ; musiques et jingles **originaux** dans le style 8 bits. Les musiques officielles de Nintendo ne sont pas incluses.

## Pour les développeurs

- `jeu/tools/build_data.py` : données Pokémon depuis les CSV de PokeAPI.
- `jeu/tools/build_world.py` : génère et vérifie tout le monde (Kanto + `regions.py` / `region_data.py` pour les autres régions). Il signale les PNJ, portes et sorties inaccessibles, les objets inconnus, les tables de rencontre impossibles à déclencher, et calcule la couverture du Pokédex.
- `jeu/tools/check_dex.py` : seconde vérification du Pokédex, indépendante, à partir des fichiers du jeu (évolutions faisables par le moteur, objets réellement obtenables, capacités apprenables).
- `jeu/tools/build_audio.py` : compose et synthétise la musique. `jeu/tools/patch_font.py` : ajoute à la police les symboles qui lui manquent.
- Tests (`godot --headless --fixed-fps 60 res://tests/...`) :
  - `systems_test.tscn` : plus de 15 000 vérifications (Balls, capture, évolutions, expérience, rythme, PP, effet de chaque capacité, K.O., œufs, données du monde, pêche, builds, profil, Elo, campagne, Abîme, Maître des Capacités…) ;
  - `smoke_test.tscn` : combats aléatoires simples, doubles, coop et boss, et tous les écrans ;
  - `stress_test.tscn -- 2000` : des milliers de combats au hasard (talents, objets, Méga, Z, auras) sans erreur ;
  - `play_test.tscn` : un robot joue le début du jeu, puis va pêcher à Carmin ;
  - `campaign_test.tscn` : un robot joue la fin de la campagne (bateau, Giovanni, Gardien de l'Abîme, Arceus, Titan, starter de Paldea, Maître des Capacités) ;
  - `balance_test.tscn -- 20` : une IA joue une équipe de fin de jeu contre Giovanni, l'Abîme et le Gardien, et donne le taux de victoire (le Gardien doit rester dur mais battable) ;
  - `region_shots.tscn -- all` : charge les 1090 cartes ; avec des identifiants de cartes, prend des captures d'écran ;
  - `net_test.tscn` et `social_test.tscn` : à lancer deux fois (sans `--fixed-fps`, `-- host` puis `-- client`), coop, échanges, Hôtel des Ventes, guildes, combats classés.
