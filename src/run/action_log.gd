class_name ActionLog
extends RefCounted
## The player's inputs for each finished battle, saved in the run so Replay can rebuild it
## (decisions D38). Plain JSON-safe dictionaries: JSON loads numbers as floats, so from_dict
## converts with int().


## A new log entry for a battle on [param position] against [param enemy_id], with no actions yet.
static func battle_entry(position: Vector2i, enemy_id: StringName) -> Dictionary:
	return {
		"node": [position.x, position.y],
		"type": "battle",
		"enemy": String(enemy_id),
		"actions": [],
	}


## Appends [param action] to the actions of [param entry].
static func record(entry: Dictionary, action: PlayerAction) -> void:
	var actions: Array = entry["actions"]
	actions.append(to_dict(action))


## The JSON-safe form of [param action].
static func to_dict(action: PlayerAction) -> Dictionary:
	match action.kind:
		PlayerAction.Kind.USE_MOVE:
			return {"kind": "move", "slot": action.slot}
		PlayerAction.Kind.USE_ITEM:
			return {"kind": "item", "slot": action.pouch_slot, "choice": action.choice}
		_:
			return {"kind": "choice", "reroll_dice": Array(action.gamble_choice.reroll_dice)}


## Rebuilds the action that [method to_dict] wrote. Returns null for an unknown kind; the caller
## reports it with the entry's position in the log.
static func from_dict(entry: Dictionary) -> PlayerAction:
	var action := PlayerAction.new()
	var kind_name: String = str(entry.get("kind", ""))
	match kind_name:
		"move":
			action.kind = PlayerAction.Kind.USE_MOVE
			var move_slot: float = entry.get("slot", 0)
			action.slot = int(move_slot)
		"item":
			action.kind = PlayerAction.Kind.USE_ITEM
			var item_slot: float = entry.get("slot", 0)
			var item_choice: float = entry.get("choice", 0)
			action.pouch_slot = int(item_slot)
			action.choice = int(item_choice)
		"choice":
			action.kind = PlayerAction.Kind.GAMBLE_CHOICE
			var dice: Array = entry.get("reroll_dice", [])
			for value: Variant in dice:
				var face: float = value
				action.gamble_choice.reroll_dice.append(int(face))
		_:
			return null
	return action
