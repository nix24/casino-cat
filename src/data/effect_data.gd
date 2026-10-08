class_name EffectData
extends Resource
## One immediate effect of a move or pouch item (architecture §2). T001 resolves SHIELD, HEAL,
## MP_GAIN, and STATUS; the other kinds are listed so saved content keeps its numbers.

enum Kind {
	SHIELD,
	HEAL,
	HEAL_PCT_MAX,
	HEAL_PCT_OF_DAMAGE,
	MP_GAIN,
	STATUS,
	CLEANSE,
	REVEAL_INTENTS,
	ADD_REROLLS,
	LUCK_NEXT_GAMBLE,
	FLAT_DAMAGE_NEXT_MOVE,
	WEAKEN_NEXT_INTENT,
	SET_ENEMY_SUIT,
	FLEE,
	GUARANTEE_TOP_TIER,
	FIND_ITEM_CHANCE,
	SPECIAL,
}
enum Target { SELF, ENEMY }

## What the effect does.
@export var kind: Kind
## Who receives the effect.
@export var target: Target = Target.SELF
## Points, percent, or count, depending on kind.
@export var amount: int = 0
## Status id for STATUS effects: weak, exposed, rattled, or regen.
@export var status: StringName = &""
## Duration in turns for STATUS effects.
@export var turns: int = 0
## Hook name for SPECIAL effects. Dispatched by the hooks layer (T013).
@export var special_id: StringName = &""
