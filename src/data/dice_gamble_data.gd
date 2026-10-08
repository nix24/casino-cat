class_name DiceGambleData
extends GambleData
## Outcome data of a Dice move (PRD §6.1). Paw Roll and Loaded Paws use the tier table; Snake Eyes
## has no tiers and pays out on one face.

## Dice rolled per use.
@export var dice_count: int = 1
## How many of the highest faces count toward the tier.
@export var keep_best: int = 1
## Payout before the tier multiplier, per hit. Snake Eyes pays this on every face but the jackpot.
@export var base_damage: int = 0
## Face that pays the jackpot. 0 means the move uses tiers instead. A non-zero face also makes
## Luck reroll the other faces (PRD §6.1).
@export var jackpot_face: int = 0
## Payout when the jackpot face lands.
@export var jackpot_damage: int = 0
## Tier table over the kept sum, in order. Empty for jackpot moves.
@export var tiers: Array[DiceTierData] = []
