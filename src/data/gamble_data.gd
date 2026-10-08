class_name GambleData
extends Resource
## Outcome data of one gamble move (architecture §2). Abstract: each family has a subclass that
## holds its own numbers. The base holds what every family shares.

## Which Due step an outcome takes (PRD §6.0 rule 7, decisions D19). NONE leaves the meter alone,
## BOTTOM adds a pip, TOP empties it.
enum DueStep { NONE, BOTTOM, TOP }

## Gamble family id, e.g. dice. Keys the family's Due meter and its Luck (PRD §6.0).
@export var family: StringName
