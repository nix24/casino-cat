class_name GambleOdds
extends RefCounted
## The exact outcome table of one gamble at one Luck (PRD §6.0 rule 2). Rows sum to 1.

var rows: Array[GambleOddsRow] = []
## The Luck the rows were computed at, shown on the preview.
var luck: int = 0
## Nine Lives: the rows assume the player hits below this total (gamble-math.md). 0 otherwise.
var stand_at: int = 0
## Nine Lives: the next bust this battle would be forgiven (gamble-math.md).
var is_forgiveness_ready: bool = false


## Expected payout over all rows, before backfire.
func expected_damage() -> float:
	var total: float = 0.0
	for row: GambleOddsRow in rows:
		total += row.probability * row.payout
	return total
