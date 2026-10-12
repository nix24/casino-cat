class_name EventOutcomeData
extends Resource
## One possible result of an event choice (PRD §10.3).

## Chance of this outcome. A choice's outcomes sum to 1.0.
@export var probability: float = 1.0
## What happens to the run, in order.
@export var effects: Array[RunEffectData] = []
## Shown after the roll, at most 25 words (D35).
@export var result_text: String
