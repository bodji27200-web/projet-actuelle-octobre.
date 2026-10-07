# Mon Jeu (Godot 4)

Jeu d'arcade : ramasse les pièces jaunes, évite les boules rouges (une de plus toutes les 5 s, de plus en plus rapides).
Flèches / ZQSD / WASD pour bouger, Entrée ou R pour rejouer.

## Mettre le projet sur ton Bureau

```bash
cd ~/Desktop        # Windows : cd %USERPROFILE%\Desktop
git clone -b claude/godot-game-desktop-folder-yfw8m3 https://github.com/bodji27200-web/projet-actuelle-octobre..git mon-jeu
```

Ensuite dans Godot : **Importer** → `Bureau/mon-jeu/jeu/project.godot` → F5.

Pour récupérer ce que je code dans le cloud : `git pull` dans le dossier.

## MCP Godot (Claude Code en local)

1. Installe Node.js (https://nodejs.org).
2. Dans `.mcp.json`, remplace `GODOT_PATH` par le vrai chemin de ton exécutable Godot.
3. Lance `claude` depuis le dossier `mon-jeu` → le serveur MCP `godot` se charge (accepte-le quand il le demande).
