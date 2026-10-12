class_name RunEffectData
extends Resource
## One effect of an event outcome on the run (arch §2, PRD §10.3).

enum Kind {
	PURRLS,
	HP,
	HP_PCT,
	MAX_HP,
	GAIN_RELIC,
	GAIN_ITEM,
	LEARN_MOVE,
	ADD_MODIFIER,
	START_BATTLE,
	START_NEXT_BATTLE_MP,
	NOTHING,
}

## What the effect does.
@export var kind: Kind = Kind.NOTHING
## Purrls, HP, percent, or MP, depending on kind. Negative is a cost.
@export var amount: int = 0
## Content id: the relic, item, move, modifier, or enemy. Empty means a random pick.
@export var id: StringName = &""
## RelicData.Rarity or MoveData.Rarity for a random GAIN_RELIC or LEARN_MOVE; -1 when unused.
@export var rarity: int = -1
