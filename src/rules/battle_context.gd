class_name BattleContext
extends RefCounted
## What a battle resolves against: the tuning numbers, the move content, and the cat's loadout.
## Read-only for the rules except `due` and `forced`, which gamble moves update. The run builds it
## from ContentDb.

var tuning: TuningData = TuningData.new()
## Move content by id, for every move in the loadout.
var moves: Dictionary[StringName, MoveData] = {}
var loadout: Array[MoveInstance] = []
## Due pips per gamble family, kept across battles by the run (PRD §6.0 rule 7). Rules update it.
var due: Dictionary[StringName, int] = {}
## Luck from relics and other sources, added to every gamble's Luck. 0 until T013.
var luck_bonus: int = 0
## Faces the next gamble's dice draw before the RNG, in order. Consumed when that gamble opens.
var forced: Array[int] = []
