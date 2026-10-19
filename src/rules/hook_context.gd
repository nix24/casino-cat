class_name HookContext
extends RefCounted
## What a hook needs to know about the moment it fires (T013). Fields a trigger doesn't use stay
## at their defaults.

## The move being used, or null outside a move.
var move: MoveData
## The cat's copy of that move, with its modifiers. Null outside a move.
var move_instance: MoveInstance
## Gamble family of the move (&"dice", &"coin", …), or empty.
var family: StringName = &""
## HP damage the move dealt, for ON_DAMAGE_DEALT.
var damage: int = 0
## Coin heads in a row this battle that a coin payout counts, for PER_STREAK (Gold Tooth, D22).
var consecutive_heads: int = 0
