# Pokémon Kanto (Godot 4)

Fan-game Pokémon pour jouer seul ou à deux, en coop. Usage privé uniquement : les sprites, les cris et les noms Pokémon appartiennent à Nintendo / Game Freak.

## Lancer le jeu

1. Récupère le projet :
   - en ZIP : https://github.com/bodji27200-web/projet-actuelle-octobre./archive/refs/heads/claude/godot-game-desktop-folder-yfw8m3.zip (clic droit → Extraire tout) ;
   - ou avec git : `git clone -b claude/godot-game-desktop-folder-yfw8m3 https://github.com/bodji27200-web/projet-actuelle-octobre..git`
2. Ouvre **Godot 4.3 ou plus récent** → **Importer** → `jeu/project.godot` → **Importer et modifier**.
3. Appuie sur **F5**.

**Internet est nécessaire au premier lancement** : les sprites officiels et les cris des Pokémon sont téléchargés depuis PokeAPI, puis gardés sur le PC.

> Ancienne sauvegarde : le monde a été entièrement refait, il faut commencer une **nouvelle partie**.

## Touches (modifiables dans PARAMÈTRES → Touches)

| Action | Touche par défaut |
|---|---|
| Se déplacer | Flèches ou ZQSD |
| A (valider, parler, pêcher face à l'eau) | Entrée ou Espace |
| B (retour) | Échap ou Retour arrière |
| Menu | Tab ou M |
| Courir | Maj |
| Vélo | V |
| Carte de Kanto | C |
| Message aux autres joueurs | T |

## Jouer à deux (multijoueur et coop)

1. Les deux lancent le jeu et chargent leur propre partie (chacun garde sa sauvegarde).
2. Le premier ouvre **Menu → MULTIJOUEUR → HÉBERGER**. Le jeu affiche son adresse (ex. `192.168.1.20`).
3. Le second fait **MULTIJOUEUR → REJOINDRE** et tape cette adresse.
4. Vous vous voyez sur la carte. Pour faire équipe : **MULTIJOUEUR → INVITER DANS LE GROUPE** (ou parle à l'autre joueur).

**En groupe et sur la même carte, tous les combats deviennent des 2 contre 2** :
- dans les hautes herbes, **deux Pokémon sauvages** apparaissent ;
- chaque Dresseur appelle **un camarade de la même catégorie** (un Sbire Rocket appelle un autre Sbire Rocket, un Champion appelle son Disciple) ;
- les **Arènes** se font aussi en duo, et les deux joueurs gagnent le Badge ;
- les **boss** des donjons (Antres, Tour Pokémon, Manoir) se combattent à deux contre un.

Si vous n'êtes pas dans le même groupe, chacun joue normalement, même sur la même carte.

**Connexion :**
- **Même Wi-Fi / même box** : ça marche directement.
- **À distance** : installez tous les deux un VPN gratuit comme **Radmin VPN** ou **ZeroTier**, rejoignez le même réseau, puis utilisez l'adresse affichée par le VPN. Sinon, l'hôte doit ouvrir le port **24680 (UDP)** sur sa box.

## Contenu

- **Tout Kanto** : 11 villes, 25 routes, Forêt de Jade, Mont Sélénite, Tour Pokémon, Repaire Rocket, Sylphe SARL, Parc Safari, Îles Écume, Manoir Pokémon, Centrale, Route Victoire, Grotte Azurée, Cave Taupiqueur, 3 Antres à boss (112 cartes).
- **Histoire complète** : Prof. Chen, ton rival **Régis** (7 combats, son équipe évolue avec lui), la Team Rocket et son Admin Corbeau, Giovanni, M. Fuji, Léo, les Jumelles Lila et Lou… Le **JOURNAL** indique toujours la prochaine étape.
- **8 Arènes et 8 Badges**, **Conseil 4** et Maître de la Ligue, Panthéon.
- **Quêtes secondaires** courtes : le Rattata perdu, le Défi du Pont Pépite, le dentier du Gardien, la Pension, les fossiles, les récompenses du Pokédex…
- **Légendaires en fin de jeu** : Artikodin, Électhor, Sulfura, Ronflex, Mewtwo (après la Ligue), Mew (Pokédex à 150).
- **Les 151 Pokémon**, tous obtenables, avec les vraies listes de Pokémon sauvages de Rouge Feu.
- **303 capacités**, talents, IV, EV, 25 natures, shiny (1/4096), formule de capture officielle et **20 types de Balls**, **niveau maximum 100**.
- **Pêche** : trois cannes (Canne à Carmin-sur-Mer, Super Canne à Parmanie, Méga Canne sur la Route 12, quête « Les frères pêcheurs »). Face à l'eau, appuie sur A (ou utilise la canne depuis le Sac). Tables de Rouge Feu complétées par celles de Cristal et HeartGold, plus quelques Pokémon Eau rares selon le lieu (étang, côte, mer : Stari, Otaria, Lokhlass…). Toutes les routes de pêche ont un étang. La Scuba Ball est plus efficace sur un Pokémon pêché.
- **Builds** : 25 natures, IV (0-31) et EV (252 par stat, 510 au total) avec la formule officielle, tous visibles dans le résumé (page STATS, avec le caractère du Pokémon). Vitamines (+10 EV), Baies anti-EV (-10), **Aromates** pour changer de nature (herboriste du Magasin de Céladopole), talent **Synchro** en tête d'équipe (1 chance sur 2 de copier la nature d'un Pokémon sauvage) et **Joliesse**.
- **Œufs** : Pension de la Route 5 (groupes d'œufs, IV hérités), Œuf de Léo. Ils éclosent en marchant, comme dans les jeux.
- **15 tenues** : garçon ou fille au choix, tenues en boutique (Céladopole), en récompense de quêtes et de boss. Changement depuis le menu TENUES ou la penderie de ta chambre.
- **Mini-carte** en haut à droite et **carte de Kanto** (touche C) avec ta position et celle de ton partenaire.
- **Paramètres** : vitesse du texte, volumes, cris, animations, mini-carte, taille de la fenêtre, **difficulté** (Normale / Difficile / Extrême : Champions avec IV parfaits et EV optimisés) et **touches modifiables**.
- **Expérience des jeux récents** : moins d'expérience quand ton Pokémon est déjà plus fort. **Multi Exp** offert par l'assistant du Prof. Chen.
- **Sons** : cris officiels des Pokémon (téléchargés) ; musiques et jingles **originaux** dans le style 8 bits (soin, capture, badge, évolution…). Les musiques officielles de Nintendo ne sont pas incluses.

## Pour les développeurs

- `jeu/tools/build_data.py` : données Pokémon depuis les CSV de PokeAPI. `jeu/tools/build_world.py` : génère et vérifie toute la région. `jeu/tools/build_audio.py` : compose et synthétise la musique. `jeu/tools/patch_font.py` : ajoute à la police Jersey 10 les symboles qui lui manquent (♂ ♀ ★ ▶ ₽…).
- Tests (`godot --headless res://tests/...`) :
  - `systems_test.tscn` : plus de 1 000 vérifications (Balls, capture, évolutions, expérience, rythme de progression, PP, effet de chaque capacité, K.O., tenues, œufs, rival, données du monde, pêche, natures/IV/EV, affichage) ;
  - `smoke_test.tscn` : combats aléatoires simples, doubles, coop et boss, et tous les écrans ;
  - `play_test.tscn` : un robot joue le début du jeu, puis va pêcher à Carmin ;
  - `net_test.tscn` : lancer deux fois (`-- host` puis `-- client`), un combat coop sauvage, dresseurs et boss.
