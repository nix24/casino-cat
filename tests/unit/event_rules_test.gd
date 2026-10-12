extends TestCase
## The events engine (T017, PRD §10.3, D18, D35). Rolls are forced through roll_outcome or a
## fixed seed so failures replay.


func test_e02_forced_roll_gives_20_purrls() -> void:
	var event: EventData = _db().event(&"e02_dumpster_dice")
	assert_eq(EventRules.roll_outcome(event.choices[1], 0.5), 1)
	assert_eq(EventRules.roll_outcome(event.choices[1], 0.4166), 0)
	assert_eq(EventRules.roll_outcome(event.choices[1], 0.99), 2)
	var run: RunState = _run()
	var result: EventRules.EventResult = _choose_until(run, event, 1, 1)
	assert_eq(run.purrls, 70)
	assert_true(not result.result_text.is_empty())


func test_e01_empty_cup_loses_6_hp() -> void:
	var event: EventData = _db().event(&"e01_sals_shell_game")
	assert_eq(EventRules.roll_outcome(event.choices[1], 0.9), 2)
	var run: RunState = _run()
	run.hp = 50
	_choose_until(run, event, 1, 2)
	assert_eq(run.hp, 44)


func test_events_cannot_kill() -> void:
	var event: EventData = _db().event(&"e01_sals_shell_game")
	var run: RunState = _run()
	run.hp = 4
	_choose_until(run, event, 1, 2)
	assert_eq(run.hp, 1, "D18: stops at 1 HP")
	assert_eq(EventRules.hp_after(run, -6), 1)


func test_walk_away_changes_nothing() -> void:
	var run: RunState = _run()
	var before: Dictionary = run.to_dict()
	var result: EventRules.EventResult = EventRules.choose(
		run, _db().event(&"e01_sals_shell_game"), 0, _db(), SeededRng.new("e")
	)
	assert_true(result.ok)
	assert_eq(run.to_dict(), before)


func test_pay_choice_disabled_when_short() -> void:
	var db: ContentDb = _db()
	var event: EventData = db.event(&"e03_chalk_artist")
	var run: RunState = _run()
	run.purrls = 24
	assert_eq(EventRules.disabled_reason(run, event.choices[0], db), &"purrls")
	var result: EventRules.EventResult = EventRules.choose(run, event, 0, db, SeededRng.new("e"))
	assert_true(not result.ok)
	assert_eq(run.purrls, 24)
	run.purrls = 25
	result = EventRules.choose(run, event, 0, db, SeededRng.new("e"))
	assert_true(result.ok)
	assert_eq(run.purrls, 0)
	assert_eq(result.modifier_id, &"thorny", "the scene asks for the target")


func test_full_pouch_disables_the_item_choice() -> void:
	var db: ContentDb = _db()
	var run: RunState = _run()
	run.pouch = [&"spare_die", &"spare_die", &"spare_die"]
	var choice: EventChoiceData = db.event(&"e01_sals_shell_game").choices[1]
	assert_eq(EventRules.disabled_reason(run, choice, db), &"pouch_full", "D35")


func test_learn_move_goes_to_bag_when_equipped_full() -> void:
	var db: ContentDb = _db()
	var run: RunState = _run()
	var result: EventRules.EventResult = EventRules.choose(
		run, db.event(&"e06_the_sleeping_tabby"), 1, db, SeededRng.new("e")
	)
	assert_true(result.ok)
	assert_eq(run.bag.size(), 1)
	assert_eq(run.bag[0].move_id, &"pounce")


func test_choice_index_out_of_range_rejected() -> void:
	var run: RunState = _run()
	var before: Dictionary = run.to_dict()
	var result: EventRules.EventResult = EventRules.choose(
		run, _db().event(&"e02_dumpster_dice"), 3, _db(), SeededRng.new("e")
	)
	assert_true(not result.ok)
	assert_eq(run.to_dict(), before)


func test_modifier_targets_respect_fit() -> void:
	var db: ContentDb = _db()
	var run: RunState = _run()
	assert_eq(EventRules.modifier_targets(run, &"sharpened", db), [0, 1], "basic moves only")
	assert_eq(EventRules.modifier_targets(run, &"thorny", db), [0, 1, 2, 3])


func test_start_battle_fixture() -> void:
	var db: ContentDb = _db()
	var effect := RunEffectData.new()
	effect.kind = RunEffectData.Kind.START_BATTLE
	effect.id = &"sewer_rat"
	var outcome := EventOutcomeData.new()
	outcome.effects = [effect]
	outcome.result_text = "A rat jumps you."
	var choice := EventChoiceData.new()
	choice.is_safe = true
	choice.outcomes = [outcome]
	var event := EventData.new()
	event.choices = [choice]
	var result: EventRules.EventResult = EventRules.choose(_run(), event, 0, db, SeededRng.new("e"))
	assert_eq(result.battle_enemy_id, &"sewer_rat")


func test_pick_event_avoids_repeats() -> void:
	var db: ContentDb = _db()
	var run: RunState = _run()
	var rng := SeededRng.new("PICK")
	var picked: Array[StringName] = []
	for _node: int in 6:
		var event: EventData = EventRules.pick_event(run, db, rng)
		picked.append(event.id)
		run.seen_events.append(event.id)
	for id: StringName in picked:
		assert_eq(picked.count(id), 1, "no repeat before all six are seen: %s" % id)
	assert_true(EventRules.pick_event(run, db, rng) != null, "then any event again")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(run.to_dict()))
	assert_eq(RunState.from_dict(parsed).seen_events, run.seen_events, "saved")
	parsed.erase("seen_events")
	assert_eq(RunState.from_dict(parsed).seen_events, [], "older saves read")


## Picks [param choice] with seeds until [param outcome] lands, so the effect itself is tested.
func _choose_until(
	run: RunState, event: EventData, choice: int, outcome: int
) -> EventRules.EventResult:
	for attempt: int in 200:
		var trial: RunState = RunState.from_dict(run.to_dict())
		var result: EventRules.EventResult = EventRules.choose(
			trial, event, choice, _db(), SeededRng.new("EV-%d" % attempt)
		)
		if result.outcome_index == outcome:
			EventRules.choose(run, event, choice, _db(), SeededRng.new("EV-%d" % attempt))
			return result
	assert_true(false, "outcome %d never rolled" % outcome)
	return null


func _db() -> ContentDb:
	return ContentDb.load_all()


func _run() -> RunState:
	return RunState.start("EVENTS", _db().tuning())
