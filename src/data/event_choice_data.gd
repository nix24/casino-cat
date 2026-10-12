class_name EventChoiceData
extends Resource
## One button of an event (PRD §10.3). Its odds are shown before the player picks.

## Unique within its event.
@export var id: StringName
## Button text, e.g. "Roll the 2d6".
@export var label: String
## True when the choice has exactly one outcome (no randomness).
@export var is_safe: bool = false
## Purrls the choice costs up front; the button is disabled below this (D35).
@export var min_purrls: int = 0
## True when the choice needs a gamble move in the loadout or bag (D35).
@export var requires_gamble: bool = false
## Possible results; probabilities sum to 1.0.
@export var outcomes: Array[EventOutcomeData] = []
