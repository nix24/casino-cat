extends TestCase
## Replay rebuilds a battle from the run seed and its action log (T007 R5, decisions D38). Each test
## plays a short battle the way Game does, then replays the recorded log and compares the two.

const RUN_SEED: String = "KITTY-7731"
const SLOT_SWIPE: int = 1
const SLOT_PAW_ROLL: int = 2


func test_replay_reproduces_events() -> void:
	var db := ContentDb.load_all()
	var entry: Dictionary = ActionLog.battle_entry(Vector2i(1, 2), &"sewer_rat")
	var run := RunState.start(RUN_SEED, db.tuning())
	var rngs := RngSet.for_seed(RUN_SEED)
	rngs.apply_states(run.rng_states)
	var original: Array[BattleEvent] = _play_original(run, db, entry, _paw_roll_actions(), rngs)

	var replay: Replay = Replay.play(RUN_SEED, [entry], db)
	assert_eq(replay.error, "", "replay ran to the end")
	assert_true(_has_kind(original, BattleEvent.Kind.GAMBLE_STARTED), "paw roll opened a gamble")
	assert_true(not _has_kind(original, BattleEvent.Kind.ACTION_REJECTED), "no action rejected")

	var original_lines: PackedStringArray = _event_lines(original)
	var replayed_lines: PackedStringArray = _event_lines(replay.events)
	assert_eq(replayed_lines.size(), original_lines.size(), "same event count")
	for index: int in original_lines.size():
		assert_eq(replayed_lines[index], original_lines[index], "event %d" % index)


func test_replay_end_rng_matches_original() -> void:
	var db := ContentDb.load_all()
	var entry: Dictionary = ActionLog.battle_entry(Vector2i(1, 2), &"sewer_rat")
	var run := RunState.start(RUN_SEED, db.tuning())
	var rngs := RngSet.for_seed(RUN_SEED)
	rngs.apply_states(run.rng_states)
	_play_original(run, db, entry, _paw_roll_actions(), rngs)

	var replay: Replay = Replay.play(RUN_SEED, [entry], db)
	assert_eq(replay.rng_states, rngs.to_states(), "rng positions after the replay")


func test_replay_reports_rejected_action() -> void:
	var db := ContentDb.load_all()
	var entry: Dictionary = ActionLog.battle_entry(Vector2i(1, 2), &"sewer_rat")
	var paw_roll: PlayerAction = _move_action(SLOT_PAW_ROLL)
	ActionLog.record(entry, paw_roll)

	var replay: Replay = Replay.play(RUN_SEED, [entry], db)
	assert_true(not replay.error.is_empty(), "paw roll at 20 MP is rejected")
	assert_true(
		replay.error.begins_with("action rejected at entry 0 index 0"), "error names the action"
	)


func test_replay_unknown_enemy_errors() -> void:
	var db := ContentDb.load_all()
	var entry: Dictionary = ActionLog.battle_entry(Vector2i(1, 2), &"no_such_enemy")

	var replay: Replay = Replay.play(RUN_SEED, [entry], db)
	assert_eq(replay.error, "unknown enemy: no_such_enemy", "error names the enemy")
	assert_eq(replay.events.size(), 0, "no events after an unknown enemy")


## Swipe first so the cat has the MP for Paw Roll, then Paw Roll, then keep the gamble's faces.
func _paw_roll_actions() -> Array[PlayerAction]:
	return [_move_action(SLOT_SWIPE), _move_action(SLOT_PAW_ROLL), _choice_action([])]


## Plays [param actions] against the sewer rat the way Game does, records each one in [param entry],
## and returns every event in order. [param rngs] ends in the state the run would save.
func _play_original(
	run: RunState, db: ContentDb, entry: Dictionary, actions: Array[PlayerAction], rngs: RngSet
) -> Array[BattleEvent]:
	var ctx: BattleContext = BattleContext.from_run(run, db)
	var start: BattleStart = BattleRules.start(db.enemy(&"sewer_rat"), ctx, rngs.battle)
	var events: Array[BattleEvent] = []
	events.append_array(start.events)
	for action: PlayerAction in actions:
		ActionLog.record(entry, action)
		events.append_array(BattleRules.apply(start.state, action, ctx, rngs))
	return events


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


func _has_kind(events: Array[BattleEvent], kind: BattleEvent.Kind) -> bool:
	for event: BattleEvent in events:
		if event.kind == kind:
			return true
	return false


func _event_lines(events: Array[BattleEvent]) -> PackedStringArray:
	var lines := PackedStringArray()
	for event: BattleEvent in events:
		lines.append(DebugCommands.event_line(event))
	return lines
