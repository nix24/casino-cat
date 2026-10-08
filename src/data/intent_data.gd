class_name IntentData
extends Resource
## One step of an enemy's pattern, shown to the player before it happens (PRD §9.1).

enum Kind { ATTACK, MULTI_ATTACK, GUARD, BUFF, DEBUFF, STEAL_MP, HEAL, SPECIAL }

## What the enemy does on this step.
@export var kind: Kind
## Damage per hit, shield points, or MP, depending on kind.
@export var amount: int = 0
## Number of hits for ATTACK intents.
@export var hits: int = 1
## Status id for DEBUFF intents.
@export var status: StringName = &""
## Duration in turns for DEBUFF intents.
@export var turns: int = 0
## Hook name for SPECIAL intents.
@export var special_id: StringName = &""
