extends TestCase
## Equipped and bag rules outside battle (T012, PRD §4.2, D33).


func test_swap_exchanges_and_keeps_counts() -> void:
	var run: RunState = _run([&"pounce"])
	assert_true(RunRules.swap_equipped_with_bag(run, 2, 0))
	assert_eq(_ids(run.equipped), [&"scratch", &"swipe", &"pounce", &"curl_up"])
	assert_eq(_ids(run.bag), [&"paw_roll"])


func test_swap_rejects_out_of_range() -> void:
	var run: RunState = _run([&"pounce"])
	var before: Dictionary = run.to_dict()
	assert_true(not RunRules.swap_equipped_with_bag(run, 0, 1))
	assert_true(not RunRules.swap_equipped_with_bag(run, 4, 0))
	assert_eq(run.to_dict(), before)


func test_release_from_bag_and_equipped() -> void:
	var run: RunState = _run([&"pounce"])
	assert_true(RunRules.release_move(run, true, 0))
	assert_eq(run.bag.size(), 0)
	assert_true(RunRules.release_move(run, false, 1))
	assert_eq(_ids(run.equipped), [&"scratch", &"paw_roll", &"curl_up"], "no auto-promotion")
	assert_true(not RunRules.release_move(run, true, 0), "empty bag")


func test_last_equipped_move_cannot_be_released() -> void:
	var run: RunState = _run([])
	for _release: int in 3:
		assert_true(RunRules.release_move(run, false, 0))
	assert_true(not RunRules.release_move(run, false, 0), "D33: keep at least one")
	assert_eq(run.equipped.size(), 1)


func test_move_to_bag_and_equip_from_bag_limits() -> void:
	var run: RunState = _run([&"a", &"b", &"c", &"d"])
	assert_true(not RunRules.move_to_bag(run, 0, _tuning()), "bag full")
	assert_true(not RunRules.equip_from_bag(run, 0, _tuning()), "equipped full")
	var empty: RunState = _run([])
	assert_true(not RunRules.equip_from_bag(empty, 0, _tuning()), "nothing in the bag")
	assert_true(RunRules.move_to_bag(empty, 3, _tuning()))
	assert_eq(_ids(empty.bag), [&"curl_up"])
	assert_true(RunRules.equip_from_bag(empty, 0, _tuning()))
	assert_eq(_ids(empty.equipped), [&"scratch", &"swipe", &"paw_roll", &"curl_up"])


func test_last_equipped_move_cannot_go_to_bag() -> void:
	var run: RunState = _run([])
	for _move: int in 3:
		assert_true(RunRules.move_to_bag(run, 0, _tuning()))
	assert_true(not RunRules.move_to_bag(run, 0, _tuning()), "the cat needs one equipped move")


func test_full_loadout_swap_still_allowed() -> void:
	var run: RunState = _run([&"a", &"b", &"c", &"d"])
	assert_true(RunRules.swap_equipped_with_bag(run, 0, 3))
	assert_eq(run.equipped[0].move_id, &"d")
	assert_eq(run.bag[3].move_id, &"scratch")


func test_no_move_id_duplicated_by_swap() -> void:
	var run: RunState = _run([&"a", &"b"])
	RunRules.swap_equipped_with_bag(run, 0, 1)
	RunRules.move_to_bag(run, 2, _tuning())
	RunRules.equip_from_bag(run, 0, _tuning())
	RunRules.swap_equipped_with_bag(run, 3, 2)
	RunRules.release_move(run, true, 0)
	var ids: Array[StringName] = _ids(run.equipped) + _ids(run.bag)
	for id: StringName in ids:
		assert_eq(ids.count(id), 1, "%s once" % id)
	assert_eq(ids.size(), 5, "6 moves minus one released")


func _run(bag_ids: Array[StringName]) -> RunState:
	var run: RunState = RunState.start("LOADOUT", _tuning())
	for id: StringName in bag_ids:
		var move := MoveInstance.new()
		move.move_id = id
		run.bag.append(move)
	return run


func _tuning() -> TuningData:
	return TuningData.new()


func _ids(moves: Array[MoveInstance]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for move: MoveInstance in moves:
		ids.append(move.move_id)
	return ids
