class_name PlayerAction
extends RefCounted
## What the player asked for this turn. BattleRules.apply() validates it; it never mutates it.

enum Kind { USE_MOVE, USE_ITEM, GAMBLE_CHOICE }

var kind: Kind = Kind.USE_MOVE
## Loadout slot for USE_MOVE.
var slot: int = 0
## Pouch slot for USE_ITEM. Unused until T014.
var pouch_slot: int = 0
## Option picked for GAMBLE_CHOICE. Unused until T002.
var choice: int = 0
