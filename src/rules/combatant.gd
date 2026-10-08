class_name Combatant
extends RefCounted
## One side of a battle, the cat or an enemy. Plain state; the rules live in BattleRules and Damage.

## Which side this combatant is. Events copy it into `target` so the UI knows whose panel changes.
var side: BattleEvent.Actor = BattleEvent.Actor.CAT
var max_hp: int = 0
var hp: int = 0
var shield: int = 0
var suit: Suit.Type = Suit.Type.CLUBS
## Status id to turns left. Dictionary order is the order ticks resolve in.
var statuses: Dictionary[StringName, int] = {}
## Statuses applied this turn. They take effect now but skip this turn's tick (decision D14).
var statuses_fresh: Array[StringName] = []
## Flat damage added to every hit this combatant deals. Always 0 in T001.
var flat_damage_bonus: int = 0


func _init(combatant_side: BattleEvent.Actor = BattleEvent.Actor.CAT) -> void:
	side = combatant_side
