extends TestCase
## The action log's JSON shapes and round trip (T007 R4, decisions D38). Pure dictionaries, so the
## tests need no scene or save.


func test_battle_entry_shape() -> void:
	var entry: Dictionary = ActionLog.battle_entry(Vector2i(1, 2), &"sewer_rat")
	assert_eq(entry["node"], [1, 2], "node position")
	assert_eq(entry["type"], "battle", "node type")
	assert_eq(entry["enemy"], "sewer_rat", "enemy id")
	assert_eq(entry["actions"], [], "no actions yet")


func test_record_keeps_order() -> void:
	var entry: Dictionary = ActionLog.battle_entry(Vector2i.ZERO, &"sewer_rat")
	ActionLog.record(entry, _move_action(0))
	ActionLog.record(entry, _move_action(1))
	var actions: Array = entry["actions"]
	assert_eq(actions.size(), 2, "two actions recorded")
	assert_eq(actions[0], {"kind": "move", "slot": 0}, "first action")
	assert_eq(actions[1], {"kind": "move", "slot": 1}, "second action")


func test_round_trip_move_item_choice() -> void:
	var move: PlayerAction = ActionLog.from_dict(ActionLog.to_dict(_move_action(2)))
	assert_eq(move.kind, PlayerAction.Kind.USE_MOVE, "move kind")
	assert_eq(move.slot, 2, "move slot")

	var item := PlayerAction.new()
	item.kind = PlayerAction.Kind.USE_ITEM
	item.pouch_slot = 1
	item.choice = 3
	var item_back: PlayerAction = ActionLog.from_dict(ActionLog.to_dict(item))
	assert_eq(item_back.kind, PlayerAction.Kind.USE_ITEM, "item kind")
	assert_eq(item_back.pouch_slot, 1, "item slot")
	assert_eq(item_back.choice, 3, "item choice")

	var keep: PlayerAction = ActionLog.from_dict(ActionLog.to_dict(_choice_action([1, 3])))
	assert_eq(keep.kind, PlayerAction.Kind.GAMBLE_CHOICE, "choice kind")
	assert_eq(Array(keep.gamble_choice.reroll_dice), [1, 3], "rerolled dice")


func test_from_dict_after_json() -> void:
	var entry: Dictionary = ActionLog.battle_entry(Vector2i(1, 2), &"sewer_rat")
	ActionLog.record(entry, _move_action(2))
	ActionLog.record(entry, _choice_action([1, 3]))
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(entry))
	var actions: Array = parsed["actions"]
	var first: Dictionary = actions[0]
	var second: Dictionary = actions[1]
	# JSON loads every number as a float, so from_dict must convert them back to ints.
	var move: PlayerAction = ActionLog.from_dict(first)
	assert_eq(move.kind, PlayerAction.Kind.USE_MOVE, "move kind after JSON")
	assert_eq(move.slot, 2, "move slot after JSON")
	var choice: PlayerAction = ActionLog.from_dict(second)
	assert_eq(choice.kind, PlayerAction.Kind.GAMBLE_CHOICE, "choice kind after JSON")
	assert_eq(Array(choice.gamble_choice.reroll_dice), [1, 3], "dice after JSON")


func test_unknown_kind_returns_null() -> void:
	var unknown: Dictionary = {"kind": "buy"}
	assert_true(ActionLog.from_dict(unknown) == null, "unknown kind gives null")


func _move_action(slot: int) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.USE_MOVE
	action.slot = slot
	return action


func _choice_action(dice: Array[int]) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.GAMBLE_CHOICE
	action.gamble_choice.reroll_dice = PackedInt32Array(dice)
	return action
