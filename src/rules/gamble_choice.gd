class_name GambleChoice
extends RefCounted
## What the player picked at a gamble's choice point. An empty reroll_dice means keep (Confirm).

## Dice indices to roll again. One reroll costs one reroll, however many indices (decisions D21).
var reroll_dice: PackedInt32Array = PackedInt32Array()
