# DeckHex

A Godot 4.4 turn-based PvE card game prototype built with GDScript.

## Project Structure

- `project.godot` - main Godot project file with `GameManager` and `TurnManager` autoloads.
- `scenes/MainGame.tscn` - main playable scene. The UI is assembled by `scripts/game/MainGame.gd`.
- `scenes/CardView.tscn` - clickable hand card scene.
- `scenes/Creature.tscn` - board creature token scene.
- `scripts/card/CardData.gd` - card `Resource` model for lands, creatures, and spells.
- `scripts/card/CardView.gd` - hand card rendering, hover, selection highlight, and click signals.
- `scripts/board/GridManager.gd` - pointy-top hex battlefield using a `TileMap`, hex math, `AStarGrid2D` path checks, movement ranges, and highlights.
- `scripts/board/Creature.gd` - Hero/creature stats, summoning sickness, movement/attack flags, and damage state.
- `scripts/game/MainGame.gd` - game UI, card play validation, combat, win/loss, and restart.
- `scripts/game/EnemyAI.gd` - simple PvE enemy that plays affordable cards, moves creatures, and attacks.
- `scripts/players/Player.gd` and `scripts/players/Enemy.gd` - hand/deck/life/mana state. Enemy life is used as Nexus health.
- `resources/cards/*.tres` - starter card definitions.

## Implemented Cards

- `Hero` - starts on the left-center hex with 4 attack, 25 health, 3 movement, and no summoning sickness.
- `Basic Land`, `Forest Land`, and `Mountain Land` - implemented but not included in the current starter decks.
- `Knight` - 3 mana, 4 attack, 5 health, 3 movement, adjacent melee.
- `Archer` - 2 mana, 3 attack, 3 health, 2 movement, range 3.
- `Goblin` - 2 mana, 3 attack, 2 health, 3 movement.
- `Defender` - 2 mana, 1 attack, 7 health, 1 movement.
- `Firebolt` - 2 mana, 4 damage to an enemy creature or enemy Nexus.
- `Zombie` - enemy-only 1 mana, 1 attack, 1 health, 1 movement. The enemy deck is all Zombies.
  The current encounter starts with two right-side columns of Zombies already on the board and no reinforcements after that.

## Controls

- Click a card in hand to select it. The card border brightens and valid targets are highlighted.
- Click a highlighted hex to play the selected card.
- Summon creatures on your left two board columns.
- Cast `Firebolt` on an enemy token, a highlighted right-edge Nexus hex, or the enemy status panel.
- Select a land card, then click any board hex to play it.
- Click your Hero or one of your creatures to show move and attack highlights.
- Click a green hex to move. Click a red enemy hex/token to attack.
- Click the enemy status panel with a selected creature when it is in range for a direct attack.
- Invalid plays show a warning banner, including not enough mana and out-of-range targets.
- Soft red tiles around enemies show where those enemies can move on their next turn.
- Protect your Hero. You lose immediately when the Hero reaches 0 health.

## Visual Assets

The prototype uses colored card panels and rectangle creature tokens. To add real art later, add textures under `assets/`, then extend `CardData.gd` with exported texture fields and update `CardView.gd` and `Creature.gd` to render those textures.
