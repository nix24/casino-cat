class_name HookData
extends Resource
## One passive effect of a relic or modifier (arch §4). Hooks.collect sums them per trigger.

enum Trigger {
	RUN_START,
	BATTLE_START,
	BEFORE_MOVE,
	AFTER_MOVE,
	ON_DAMAGE_DEALT,
	ON_DAMAGE_TAKEN,
	GAMBLE_PREVIEW,
	ON_GAMBLE_RESOLVED,
	ON_BACKFIRE,
	ON_TICKET_MATURED,
	ON_HEADS,
	BATTLE_END,
	REST,
}
enum Op {
	ADD_MAX_HP,
	ADD_SHIELD,
	HEAL,
	GAIN_MP,
	ADD_FLAT_DAMAGE,
	MULT_DAMAGE,
	ADD_LUCK,
	ADD_REROLLS,
	ADD_DUE_PIPS,
	MP_COST_DELTA,
	PAYOUT_MULT,
	BACKFIRE_MULT,
	ENCORE,
	FREE_PEEK,
	SEE_TOP_CARDS,
	SET_NEXT_CARD,
	TICKET_SPEED,
	REPEAT_PENALTY_SHIFT,
	DICE_NO_ONES,
	REROLL_PLUS_ONE,
	SEVEN_IS_HOT,
	CHANGE_SUIT,
	SPECIAL,
}
enum Condition { NONE, FIRST_TURN, FIRST_GAMBLE_THIS_BATTLE, HAS_SUIT_ADVANTAGE, PER_STREAK }

## When the hook fires.
@export var trigger: Trigger
## What it does.
@export var op: Op
## Size of the effect. Percent ops (MULT_DAMAGE, PAYOUT_MULT, BACKFIRE_MULT, HEAL on
## ON_DAMAGE_DEALT) use 100 = ×1.0.
@export var amount: int = 0
## Gamble family the hook is limited to (dice, coin, …). Empty means every family.
@export var family: StringName = &""
## Extra requirement for the hook to fire.
@export var condition: Condition = Condition.NONE
## Names the custom behaviour of a SPECIAL op. Empty otherwise.
@export var special_id: StringName = &""
