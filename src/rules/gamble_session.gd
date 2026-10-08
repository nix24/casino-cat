class_name GambleSession
extends RefCounted
## One open gamble, from its first roll until it resolves. BattleState.pending holds it between
## player choices. Field list is decisions §D.

var move_id: StringName = &""
var family: StringName = &""
## Odds snapshot taken when the move was used. Its Luck is the Luck the gamble resolves at.
var odds: GambleOdds
## Dice faces as they stand now, after any reroll.
var faces: PackedInt32Array = PackedInt32Array()
## Stage counter for families that take more than one choice (T027). Dice stays at 0.
var step: int = 0
## Resolved payout, set when the gamble resolves.
var damage: int = 0
## Resolved backfire, set when the gamble resolves.
var backfire: int = 0
## MP the outcome grants. Set by families that pay MP (T014 onward), 0 for dice.
var mp_gain: int = 0
## Shield the outcome grants. Set by families that shield (T014 onward), 0 for dice.
var shield_gain: int = 0
## Label of the resolved tier, set when the gamble resolves.
var tier: StringName = &""
var finished: bool = false
## Faces the next draws take, in order, before the RNG (decisions §D). Copied from ctx.forced.
var forced: Array[int] = []
