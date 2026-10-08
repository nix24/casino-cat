class_name BattleContext
extends RefCounted
## What a battle resolves against: the tuning numbers, the move content, and the cat's loadout.
## Read-only for the rules; the run builds it from ContentDb.

var tuning: TuningData = TuningData.new()
## Move content by id, for every move in the loadout.
var moves: Dictionary[StringName, MoveData] = {}
var loadout: Array[MoveInstance] = []
