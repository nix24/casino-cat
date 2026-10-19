class_name ActionLog
extends RefCounted
## The player's inputs for each finished battle, saved in the run so Replay can rebuild it
## (decisions D38). Plain JSON-safe dictionaries: JSON loads numbers as floats, so from_dict
## converts with int().


## A new log entry for a battle on [param position] against [param enemy_id], with no actions yet.
## [param entered] is true when the battle came from entering a map node (RunRules.enter_node drew
## the enemy), false for a dev-console battle.
static func battle_entry(
	position: Vector2i, enemy_id: StringName, entered: bool = false
) -> Dictionary:
	return {
		"node": [position.x, position.y],
		"type": "battle",
		"enemy": String(enemy_id),
		"entered": entered,
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
			return _choice_dict(action.gamble_choice)


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
			var coin: float = entry.get("coin", GambleChoice.CoinCall.NONE)
			action.gamble_choice.coin = int(coin) as GambleChoice.CoinCall
			var cards: float = entry.get("cards", GambleChoice.CardCall.NONE)
			action.gamble_choice.cards = int(cards) as GambleChoice.CardCall
			var pick: float = entry.get("trick_pick", -1)
			action.gamble_choice.trick_pick = int(pick)
			var order: Array = entry.get("trick_order", [])
			for value: Variant in order:
				var index: float = value
				action.gamble_choice.trick_order.append(int(index))
		_:
			return null
	return action


## A gamble choice keeps only the fields its family uses, so dice entries stay as they were.
static func _choice_dict(choice: GambleChoice) -> Dictionary:
	var entry: Dictionary = {"kind": "choice", "reroll_dice": Array(choice.reroll_dice)}
	if choice.coin != GambleChoice.CoinCall.NONE:
		entry["coin"] = choice.coin
	if choice.cards != GambleChoice.CardCall.NONE:
		entry["cards"] = choice.cards
	if choice.trick_pick >= 0:
		entry["trick_pick"] = choice.trick_pick
		entry["trick_order"] = Array(choice.trick_order)
	return entry
