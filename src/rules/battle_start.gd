class_name BattleStart
extends RefCounted
## Result of BattleRules.start: the new battle and the events that open it.

var state: BattleState
var events: Array[BattleEvent] = []
