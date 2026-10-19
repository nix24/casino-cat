class_name GambleChoice
extends RefCounted
## What the player picked at a gamble's choice point. Each family reads only its own field. For dice
## an empty reroll_dice means keep (Confirm).

## Coin choice after a head (PRD §6.2). NONE on every other family's choice.
enum CoinCall { NONE, CASH_OUT, FLIP }
## Nine Lives choice (PRD §6.3). NONE on every other family's choice.
enum CardCall { NONE, HIT, STAND }

## Dice indices to roll again. One reroll costs one reroll, however many indices (decisions D21).
var reroll_dice: PackedInt32Array = PackedInt32Array()
var coin: CoinCall = CoinCall.NONE
var cards: CardCall = CardCall.NONE
## Card Trick: the hand index to keep, and the other two hand indices, new top first.
var trick_pick: int = -1
var trick_order: PackedInt32Array = PackedInt32Array()
