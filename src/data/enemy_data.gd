class_name EnemyData
extends Resource
## One enemy (PRD §9.2). T001 covers the pattern and the first-battle pool; overrides and boss
## phases arrive with T018 and T019.

enum Tier { NORMAL, ELITE, BOSS }

## Permanent id. Saves store it, so it never changes after release.
@export var id: StringName
## Name shown to the player.
@export var display_name: String
## Act the enemy appears in, 1 to 3 (PRD §9).
@export var act: int
## Normal, elite, or boss.
@export var tier: Tier
## Suit used for the triangle.
@export var suit: Suit.Type
## Starting HP.
@export var max_hp: int
## Intents in order. The pattern loops.
@export var pattern: Array[IntentData] = []
## True if the enemy can be drawn for the first battle of a run (PRD §9.2).
@export var first_battle_pool: bool = false
## Sprite shown in battle.
@export var sprite: Texture2D
