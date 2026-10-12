class_name MoveInstance
extends RefCounted
## One move the cat owns, plus the modifiers attached to it (RunRules.attach_modifier, T013).

## Content id of the move (MoveData.id).
var move_id: StringName = &""
## Modifier ids attached to this copy of the move, in attach order.
var modifier_ids: Array[StringName] = []
## The suit Re-suited set when it was attached (a Suit.Type), or -1 for the move's own suit.
var suit_override: int = -1
