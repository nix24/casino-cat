class_name GambleOddsRow
extends RefCounted
## One line of an odds table or one resolved outcome: what it pays, what it costs, and what it does
## to the Due meter. Built only by GambleRules.outcome_row, so preview and resolve share one format.

var label: StringName = &""
## Chance of this row, 0.0 to 1.0. Always 0 on a row returned by DiceFamily.score.
var probability: float = 0.0
## Final payout after Luck, status multipliers, and the move's payout multiplier.
var payout: int = 0
## HP the cat loses on this row, after the backfire cap.
var backfire: int = 0
var due_step: GambleData.DueStep = GambleData.DueStep.NONE
