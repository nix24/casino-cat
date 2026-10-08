class_name GambleEventData
extends RefCounted
## Gamble detail carried by the GAMBLE_*, DICE_*, and LUCK_TRIGGERED events (decisions §C, R7).
## A field the event kind doesn't use keeps its default.

## Faces showing after the event.
var faces: PackedInt32Array = PackedInt32Array()
## Dice the event is about: rerolled dice, or the die Luck rerolled.
var indices: PackedInt32Array = PackedInt32Array()
## Label of the resolved tier or outcome.
var tier: StringName = &""
## Final payout of the resolved gamble.
var payout: int = 0
## Odds snapshot, set on GAMBLE_STARTED.
var odds: GambleOdds
