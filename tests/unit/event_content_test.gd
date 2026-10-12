extends TestCase
## Act 1 events E01-E06 follow PRD §10.3 and D35 (T017).


func test_act1_events_validate() -> void:
	var db: ContentDb = ContentDb.load_all()
	var events: Array[EventData] = db.events_for(1)
	assert_eq(events.size(), 6)
	for event: EventData in events:
		assert_eq(EventRules.validate_event(event, db), PackedStringArray(), String(event.id))


func test_outcome_probabilities_sum_to_one() -> void:
	for event: EventData in ContentDb.load_all().events_for(1):
		for choice: EventChoiceData in event.choices:
			var total: float = 0.0
			for outcome: EventOutcomeData in choice.outcomes:
				total += outcome.probability
			assert_almost_eq(total, 1.0, 0.001, "%s/%s" % [event.id, choice.id])


func test_every_event_has_safe_and_gamble_choice() -> void:
	for event: EventData in ContentDb.load_all().events_for(1):
		var safe: int = (
			event
			. choices
			. filter(func(choice: EventChoiceData) -> bool: return choice.is_safe)
			. size()
		)
		assert_true(safe >= 1 and safe < event.choices.size(), String(event.id))


func test_validate_catches_broken_events() -> void:
	var db: ContentDb = ContentDb.load_all()
	var event: EventData = db.event(&"e02_dumpster_dice").duplicate(true)
	event.choices[1].outcomes[0].probability = 0.5
	event.choices[0].outcomes[0].result_text = ""
	var hp_cost := RunEffectData.new()
	hp_cost.kind = RunEffectData.Kind.HP
	hp_cost.amount = -13
	event.choices[1].outcomes[1].effects.append(hp_cost)
	var problems: String = " | ".join(EventRules.validate_event(event, db))
	assert_true(problems.contains("probabilities sum"), problems)
	assert_true(problems.contains("result_text"), problems)
	assert_true(problems.contains("more than 12 HP"), problems)
