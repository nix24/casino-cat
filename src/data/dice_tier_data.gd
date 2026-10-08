class_name DiceTierData
extends Resource
## One row of a Dice tier table (PRD §6.1): a range of kept-dice sums and what it pays.

## Lowest kept sum in this tier, inclusive.
@export var min_sum: int = 0
## Highest kept sum in this tier, inclusive.
@export var max_sum: int = 0
## Payout multiplier applied to the move's base damage.
@export var multiplier: float = 1.0
## HP the cat loses on this tier. Never reduced by Luck, and skips the shield (decisions D17).
@export var backfire: int = 0
## Name shown in the odds table and the resolve overlay.
@export var label: StringName
## What this tier does to the family's Due meter (PRD §6.0 rule 7).
@export var due_step: GambleData.DueStep = GambleData.DueStep.NONE
