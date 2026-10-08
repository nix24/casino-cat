class_name MovePreview
extends RefCounted
## What a move would do right now, for the UI to show before the player commits. Computed by the
## rules so the UI never does its own math (PRD §4.4).

## Damage the move deals this turn, summed over hits, before the enemy's shield.
var damage: int = 0
## Multiplier on the enemy's next attack if this move's suit becomes the cat's suit. 1.0 when the
## next intent is not an attack.
var incoming_mult: float = 1.0
var mp_cost: int = 0
var affordable: bool = false
