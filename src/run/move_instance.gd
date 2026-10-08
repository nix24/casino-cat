class_name MoveInstance
extends RefCounted
## One move the cat owns, plus the modifiers attached to it. Modifiers stay empty until T013.

## Content id of the move (MoveData.id).
var move_id: StringName = &""
## Modifier ids attached to this copy of the move, in attach order.
var modifier_ids: Array[StringName] = []
