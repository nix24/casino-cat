class_name IntentOverrideData
extends Resource
## Replaces an enemy's next intent when a condition is met (decision D8). Data only;
## nothing reads it until the enemy-override work lands (T018).

enum Condition { HP_BELOW_PCT }

## When the override applies.
@export var condition: Condition
## Threshold for HP_BELOW_PCT, as a percent of max HP.
@export var threshold_pct: int = 50
## True if the override fires once per battle.
@export var once: bool = true
## The intent that replaces the pattern step.
@export var intent: IntentData
