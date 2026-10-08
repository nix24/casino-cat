class_name MoveData
extends Resource
## One player move (PRD §5.2). T001 covers basic and utility moves; gamble data arrives with T002.

enum Category { BASIC, UTILITY, GAMBLE, SIGNATURE }
enum Rarity { STARTER, COMMON, UNCOMMON, RARE, SIGNATURE }

## Permanent id. Saves store it, so it never changes after release.
@export var id: StringName
## Name shown to the player.
@export var display_name: String
## Suit used for the triangle and for type-shift.
@export var suit: Suit.Type
## Basic moves are the free, repeatable attacks. Utility moves do something else.
@export var category: Category
## How often the move is offered.
@export var rarity: Rarity
## Damage per hit before modifiers. Zero for moves that don't hit.
@export var base_damage: int = 0
## Number of damage hits. Shield absorbs each hit separately (PRD §4.4).
@export var hits: int = 1
## MP paid to use the move (PRD §7).
@export var mp_cost: int = 0
## Effects resolved in order after the damage hits.
@export var effects: Array[EffectData] = []
## Number of modifier slots the move starts with (PRD §5.2).
@export var modifier_slots: int = 2
## One plain line with {placeholders} filled from the fields above.
@export_multiline var description: String
## Short flavor line, at most 8 words.
@export var flavor: String
## Icon shown on the move card.
@export var icon: Texture2D
