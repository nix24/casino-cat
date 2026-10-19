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
## The side a COIN_FLIPPED landed on.
var is_heads: bool = false
## Heads this coin use has landed so far.
var heads: int = 0
## What cashing out at 1, 2, … heads pays, after Streak, relics, and statuses (COIN_FLIPPED).
var ladder: PackedInt32Array = PackedInt32Array()
## The hand after a card event, or the cards put back on CARDS_REORDERED (top first).
var cards: PackedInt32Array = PackedInt32Array()
## Cards left of each value 1-10 (index 0 = value 1), as the player can count them.
var counts: PackedInt32Array = PackedInt32Array()
## Chance the next Nine Lives hit busts, from the visible deck (PRD §6.3).
var bust_chance: float = 0.0
## Nine Lives forgave this bust (GAMBLE_RESOLVED, decisions §C).
var forgiven: bool = false
