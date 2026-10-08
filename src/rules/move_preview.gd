class_name MovePreview
extends RefCounted
## What a move would do right now, for the UI to show before the player commits. Computed by the
## rules so the UI never does its own math (PRD §4.4).

## Damage the move deals this turn, summed over hits, before the enemy's shield.
var damage: int = 0
## Hits the move lands. 0 for moves that don't hit.
var hits: int = 0
## Triangle multiplier of the move's suit against the enemy (PRD §4.3). 1.0 for non-basic moves.
var triangle_mult: float = 1.0
## Multiplier on the enemy's next attack if this move's suit becomes the cat's suit. 1.0 when the
## next intent is not an attack.
var incoming_mult: float = 1.0
var mp_cost: int = 0
var affordable: bool = false
## MP still needed to afford the move. 0 when affordable.
var missing_mp: int = 0
## Exact outcome table for a GAMBLE move, shown before the player commits. Null for other moves.
var odds: GambleOdds
