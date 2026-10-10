extends TestCase
## Turn resolution (PRD §4, §7, §9.2) from the T001 worked examples. Battles are built in code;
## the three starter moves load from src/content so the tests use the shipped numbers.

const SCRATCH_PATH: String = "res://src/content/moves/scratch.tres"
const SWIPE_PATH: String = "res://src/content/moves/swipe.tres"
const CURL_UP_PATH: String = "res://src/content/moves/curl_up.tres"

## Loadout slots of the starter kit.
const SLOT_SCRATCH: int = 0
const SLOT_SWIPE: int = 1
const SLOT_CURL_UP: int = 2


func test_start_state_and_events() -> void:
	var start: BattleStart = BattleRules.start(
		_pigeon(), _starter_context(), RngSet.for_seed("test").battle
	)
	var state: BattleState = start.state
	assert_eq(state.cat.hp, 60, "cat hp")
	assert_eq(state.cat.max_hp, 60, "cat max hp")
	assert_eq(state.cat.suit, Suit.Type.CLUBS, "cat suit")
	assert_eq(state.mp, 20, "mp")
	assert_eq(state.turn, 1, "turn")
	assert_eq(state.enemy.hp, 20, "enemy hp")
	assert_eq(state.enemy.suit, Suit.Type.HEARTS, "enemy suit")

	var expected: Array[BattleEvent.Kind] = [
		BattleEvent.Kind.BATTLE_STARTED,
		BattleEvent.Kind.TURN_STARTED,
		BattleEvent.Kind.INTENT_SHOWN,
	]
	assert_eq(_kinds(start.events), expected, "start events")
	assert_eq(start.events[1].amount, 1, "turn 1 announced")
	assert_eq(start.events[2].reason, &"attack", "first intent kind")
	assert_eq(start.events[2].amount, 4, "first intent amount")


func test_worked_example_turn_one() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 2, ctx, rngs)
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)

	var expected: Array[BattleEvent.Kind] = [
		BattleEvent.Kind.MOVE_USED,
		BattleEvent.Kind.DAMAGE_DEALT,
		BattleEvent.Kind.SUIT_SHIFTED,
		BattleEvent.Kind.ENEMY_ACTED,
		BattleEvent.Kind.DAMAGE_DEALT,
		BattleEvent.Kind.MP_CHANGED,
		BattleEvent.Kind.MP_CHANGED,
		BattleEvent.Kind.TURN_STARTED,
		BattleEvent.Kind.INTENT_SHOWN,
	]
	assert_eq(_kinds(events), expected, "event order")
	assert_eq(events[0].move_id, &"scratch", "move used")
	assert_eq(events[1].actor, BattleEvent.Actor.CAT, "cat hits")
	assert_eq(events[1].amount, 9, "scratch hit")
	assert_eq(events[1].absorbed, 0, "no shield on pigeon")
	assert_eq(events[1].value_after, 11, "pigeon hp after")
	assert_eq(events[2].suit_from, Suit.Type.CLUBS, "shift from")
	assert_eq(events[2].suit_to, Suit.Type.SPADES, "shift to")
	assert_eq(events[3].actor, BattleEvent.Actor.ENEMY, "enemy acts")
	assert_eq(events[3].reason, &"attack", "enemy intent")
	assert_eq(events[4].amount, 5, "pigeon counter-hit")
	assert_eq(events[4].value_after, 55, "cat hp after")
	assert_eq(events[5].reason, &"dealt", "dealt charge")
	assert_eq(events[5].amount, 4, "dealt charge amount")
	assert_eq(events[5].value_after, 24, "mp after dealt")
	assert_eq(events[6].reason, &"taken", "taken charge")
	assert_eq(events[6].amount, 5, "taken charge amount")
	assert_eq(events[6].value_after, 29, "mp after taken")
	assert_eq(events[7].amount, 2, "turn 2 announced")
	assert_eq(events[8].reason, &"attack", "next intent kind")
	assert_eq(events[8].amount, 4, "next intent amount")

	assert_eq(state.cat.hp, 55, "end cat hp")
	assert_eq(state.cat.suit, Suit.Type.SPADES, "end cat suit")
	assert_eq(state.mp, 29, "end mp")
	assert_eq(state.enemy.hp, 11, "end enemy hp")


func test_curl_up_shield_absorbs_hit() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 2, ctx, rngs)
	state.cat.hp = 55
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)

	var expected: Array[BattleEvent.Kind] = [
		BattleEvent.Kind.MOVE_USED,
		BattleEvent.Kind.SHIELD_GAINED,
		BattleEvent.Kind.ENEMY_ACTED,
		BattleEvent.Kind.DAMAGE_DEALT,
		BattleEvent.Kind.TURN_STARTED,
		BattleEvent.Kind.INTENT_SHOWN,
	]
	assert_eq(_kinds(events), expected, "event order, no MP_CHANGED(taken)")
	assert_eq(events[1].amount, 10, "shield gained")
	assert_eq(events[1].value_after, 10, "shield after gain")
	assert_eq(events[1].shield_after, 10, "shield after gain")
	assert_eq(events[3].amount, 6, "pigeon hit")
	assert_eq(events[3].absorbed, 6, "shield took the whole hit")
	assert_eq(events[3].value_after, 55, "cat hp unchanged")
	assert_eq(events[3].shield_after, 4, "shield left")
	assert_eq(state.cat.hp, 55, "end cat hp")
	assert_eq(state.cat.shield, 4, "end shield")


func test_shield_caps_at_30() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 2, ctx, rngs)
	state.cat.shield = 25
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)
	var gained: BattleEvent = events[_first_index(events, BattleEvent.Kind.SHIELD_GAINED)]
	assert_eq(gained.amount, 5, "only the 5 that fit under the cap")
	assert_eq(gained.shield_after, 30, "shield after gain")


func test_repeat_penalty_scratch_four_times() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_dummy(100, Suit.Type.CLUBS, 0), 0, ctx, rngs)
	var amounts: Array[int] = []
	for _use_index: int in 4:
		var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
		amounts.append_array(_damage_by(events, BattleEvent.Actor.CAT))
	var expected: Array[int] = [6, 6, 5, 3]
	assert_eq(amounts, expected, "repeat penalty by use")
	assert_eq(state.enemy.hp, 80, "enemy hp after 20 damage")


func test_repeat_resets_after_other_move() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_dummy(100, Suit.Type.CLUBS, 0), 0, ctx, rngs)
	var amounts: Array[int] = []
	var scratch_once: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	amounts.append_array(_damage_by(scratch_once, BattleEvent.Actor.CAT))
	var curl_up: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)
	assert_eq(curl_up[0].kind, BattleEvent.Kind.MOVE_USED, "curl up resolves")
	var scratch_again: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	amounts.append_array(_damage_by(scratch_again, BattleEvent.Actor.CAT))
	var expected: Array[int] = [6, 6]
	assert_eq(amounts, expected, "third use after Curl Up is a fresh streak")


## Merged from two tests to stay under gdlint's max-public-methods (20 per class).
func test_type_shift_on_change_and_disabled_keeps_clubs() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 2, ctx, rngs)
	var curl_events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)
	assert_eq(_first_index(curl_events, BattleEvent.Kind.SUIT_SHIFTED), -1, "clubs to clubs")

	ctx.tuning.type_shift_enabled = false
	var disabled_state := _battle_at(_pigeon(), 2, ctx, rngs)
	var events: Array[BattleEvent] = BattleRules.apply(
		disabled_state, _use(SLOT_SCRATCH), ctx, rngs
	)
	assert_eq(_first_index(events, BattleEvent.Kind.SUIT_SHIFTED), -1, "no shift when disabled")
	assert_eq(disabled_state.cat.suit, Suit.Type.CLUBS, "cat stays clubs")


func test_win_stops_before_enemy_acts() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(6), 0, ctx, rngs)
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	var last: BattleEvent = events.back()
	assert_eq(last.kind, BattleEvent.Kind.BATTLE_WON, "last event")
	assert_eq(_first_index(events, BattleEvent.Kind.ENEMY_ACTED), -1, "enemy never acts")
	assert_eq(_first_index(events, BattleEvent.Kind.MP_CHANGED), -1, "no end-of-turn MP")
	assert_eq(state.outcome, BattleState.Outcome.WON, "outcome")


func test_lose_when_cat_hits_zero() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_dummy(20, Suit.Type.CLUBS, 5), 0, ctx, rngs)
	state.cat.hp = 5
	# Scratch turns the cat ♠, which is neutral to the ♣ attacker, so the 5 lands in full.
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	var last: BattleEvent = events.back()
	assert_eq(last.kind, BattleEvent.Kind.BATTLE_LOST, "last event")
	assert_eq(state.outcome, BattleState.Outcome.LOST, "outcome")
	assert_eq(state.cat.hp, 0, "cat hp floors at zero")
	_check_god_mode_floors_cat_hp_at_1()


## Runs from test_lose_when_cat_hits_zero: gdlint caps public test methods per file at 20.
func _check_god_mode_floors_cat_hp_at_1() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	ctx.god_mode = true
	var state := _battle_at(_dummy(20, Suit.Type.CLUBS, 5), 0, ctx, rngs)
	state.cat.hp = 5
	# The same hit as the loss test above, but god mode keeps the cat at 1 HP and the battle going.
	BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	assert_eq(state.cat.hp, 1, "god mode cat hp")
	assert_eq(state.outcome, BattleState.Outcome.ONGOING, "god mode outcome")

	ctx.god_mode = false
	var lost_state := _battle_at(_dummy(20, Suit.Type.CLUBS, 5), 0, ctx, rngs)
	lost_state.cat.hp = 5
	BattleRules.apply(lost_state, _use(SLOT_SCRATCH), ctx, rngs)
	assert_eq(lost_state.outcome, BattleState.Outcome.LOST, "without god mode the hit loses")


func test_mp_charge_is_end_of_turn() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 2, ctx, rngs)
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	var enemy_index: int = _first_index(events, BattleEvent.Kind.ENEMY_ACTED)
	var mp_index: int = _first_index(events, BattleEvent.Kind.MP_CHANGED)
	assert_true(mp_index > enemy_index, "MP charge comes after the enemy acts")


func test_mp_dealt_ignores_enemy_shield() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_dummy(100, Suit.Type.CLUBS, 0), 0, ctx, rngs)
	state.enemy.shield = 4
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	var hit: BattleEvent = events[_first_index(events, BattleEvent.Kind.DAMAGE_DEALT)]
	assert_eq(hit.amount, 6, "hit before shield")
	assert_eq(hit.absorbed, 4, "enemy shield absorbed")
	var dealt: BattleEvent = events[_first_index(events, BattleEvent.Kind.MP_CHANGED)]
	assert_eq(dealt.reason, &"dealt", "charge reason")
	assert_eq(dealt.amount, 1, "only the 2 HP that got through, halved")


func test_swipe_mp_gain_reason_move() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 0, ctx, rngs)
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SWIPE), ctx, rngs)

	var expected: Array[BattleEvent.Kind] = [
		BattleEvent.Kind.MOVE_USED,
		BattleEvent.Kind.DAMAGE_DEALT,
		BattleEvent.Kind.SUIT_SHIFTED,
		BattleEvent.Kind.ENEMY_ACTED,
		BattleEvent.Kind.DAMAGE_DEALT,
		BattleEvent.Kind.MP_CHANGED,
		BattleEvent.Kind.MP_CHANGED,
		BattleEvent.Kind.MP_CHANGED,
		BattleEvent.Kind.TURN_STARTED,
		BattleEvent.Kind.INTENT_SHOWN,
	]
	assert_eq(_kinds(events), expected, "event order")
	assert_eq(events[1].amount, 5, "7 x 0.75 = 5.25 rounds to 5")
	assert_eq(events[4].amount, 6, "4 x 1.5 counter-hit")
	assert_eq(events[5].reason, &"dealt", "dealt first")
	assert_eq(events[5].amount, 2, "floor(5 / 2)")
	assert_eq(events[6].reason, &"taken", "taken second")
	assert_eq(events[6].amount, 6, "taken")
	assert_eq(events[7].reason, &"move", "move gain last")
	assert_eq(events[7].amount, 6, "swipe gains 6 MP")
	assert_eq(events[7].value_after, 34, "mp after all three charges")


func test_mp_clamped_to_100() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 2, ctx, rngs)
	state.mp = 98
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	var dealt: BattleEvent = events[_first_index(events, BattleEvent.Kind.MP_CHANGED)]
	assert_eq(dealt.value_after, 100, "dealt clamped")
	var taken: BattleEvent = events[_last_index(events, BattleEvent.Kind.MP_CHANGED)]
	assert_eq(taken.value_after, 100, "taken clamped")
	assert_eq(state.mp, 100, "end mp")


func test_steal_mp_floors_at_zero() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 1, ctx, rngs)
	state.mp = 3
	var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)
	var steal: BattleEvent = events[_first_index(events, BattleEvent.Kind.MP_CHANGED)]
	assert_eq(steal.reason, &"steal", "reason")
	assert_eq(steal.amount, -3, "only the 3 MP the cat had")
	assert_eq(steal.value_after, 0, "mp after")
	assert_eq(state.mp, 0, "end mp")


func test_weak_fresh_then_ticks_and_expires() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pup(), 0, ctx, rngs)

	var turn_one: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)
	var applied: BattleEvent = turn_one[_first_index(turn_one, BattleEvent.Kind.STATUS_APPLIED)]
	assert_eq(applied.status, &"weak", "status applied")
	assert_eq(applied.turns, 2, "turns applied")
	assert_eq(_first_index(turn_one, BattleEvent.Kind.STATUS_TICKED), -1, "fresh: no tick")
	assert_eq(state.cat.statuses[&"weak"], 2, "weak still 2 after turn one")

	var turn_two: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	assert_eq(_damage_by(turn_two, BattleEvent.Actor.CAT), [5], "weakened scratch: 6 x 0.75")
	var ticked: BattleEvent = turn_two[_first_index(turn_two, BattleEvent.Kind.STATUS_TICKED)]
	assert_eq(ticked.status, &"weak", "tick status")
	assert_eq(ticked.turns, 1, "turns left")

	var turn_three: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)
	var expired: BattleEvent = turn_three[_first_index(turn_three, BattleEvent.Kind.STATUS_EXPIRED)]
	assert_eq(expired.status, &"weak", "expired status")
	assert_true(not state.cat.statuses.has(&"weak"), "weak removed")


func test_regen_heals_three_times() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_dummy(100, Suit.Type.CLUBS, 0), 0, ctx, rngs)
	state.cat.hp = 40
	state.cat.statuses[&"regen"] = 3
	var healed: Array[int] = []
	var expired_count: int = 0
	for _turn: int in 3:
		var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)
		for event: BattleEvent in events:
			if event.kind == BattleEvent.Kind.HEALED and event.reason == &"regen":
				healed.append(event.amount)
			if event.kind == BattleEvent.Kind.STATUS_EXPIRED:
				expired_count += 1
	var expected: Array[int] = [3, 3, 3]
	assert_eq(healed, expected, "regen heals 3 each turn")
	assert_eq(expired_count, 1, "regen expires once, after its last heal")
	assert_eq(state.cat.hp, 49, "end hp")


func test_pattern_loops() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 0, ctx, rngs)
	var reasons: Array[StringName] = []
	for _turn: int in 4:
		var events: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_CURL_UP), ctx, rngs)
		var acted: BattleEvent = events[_first_index(events, BattleEvent.Kind.ENEMY_ACTED)]
		reasons.append(acted.reason)
	var expected: Array[StringName] = [&"attack", &"steal_mp", &"attack", &"attack"]
	assert_eq(reasons, expected, "enemy intents over four turns")


func test_rejects_bad_slot_and_unaffordable() -> void:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var costly := MoveData.new()
	costly.id = &"costly"
	costly.suit = Suit.Type.SPADES
	costly.category = MoveData.Category.BASIC
	costly.base_damage = 6
	costly.mp_cost = 30
	_add_move(ctx, costly)
	var state := _battle_at(_pigeon(), 0, ctx, rngs)

	var bad_slot: Array[BattleEvent] = BattleRules.apply(state, _use(9), ctx, rngs)
	assert_eq(_kinds(bad_slot), [BattleEvent.Kind.ACTION_REJECTED], "bad slot is one rejection")
	assert_eq(bad_slot[0].reason, &"invalid_slot", "bad slot reason")

	var unaffordable: Array[BattleEvent] = BattleRules.apply(
		state, _use(SLOT_CURL_UP + 1), ctx, rngs
	)
	assert_eq(unaffordable[0].reason, &"not_affordable", "cost 30 with 20 MP")
	assert_eq(state.mp, 20, "rejected action spends nothing")
	assert_eq(state.turn, 1, "rejected action does not end the turn")

	state.outcome = BattleState.Outcome.WON
	var after_win: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	assert_eq(after_win[0].reason, &"battle_over", "no actions after the battle ends")


func test_preview_matches_apply() -> void:
	var expected_incoming: Array[float] = [0.75, 1.5, 1.0]
	for slot: int in 3:
		var ctx := _starter_context()
		var rngs := RngSet.for_seed("test")
		var preview: MovePreview = BattleRules.preview_move(
			_battle_at(_pigeon(), 0, ctx, rngs), slot, ctx
		)
		var events: Array[BattleEvent] = BattleRules.apply(
			_battle_at(_pigeon(), 0, ctx, rngs), _use(slot), ctx, rngs
		)
		var dealt: int = _sum(_damage_by(events, BattleEvent.Actor.CAT))
		assert_eq(preview.damage, dealt, "slot %d damage" % slot)
		assert_eq(preview.incoming_mult, expected_incoming[slot], "slot %d incoming" % slot)
		assert_true(preview.affordable, "slot %d affordable" % slot)


func test_same_inputs_same_events() -> void:
	assert_eq(_run_fixed_turns(), _run_fixed_turns(), "identical inputs, identical events")


# --- helpers ---------------------------------------------------------------------------------


func _load_move(path: String) -> MoveData:
	return load(path) as MoveData


func _starter_context() -> BattleContext:
	var ctx := BattleContext.new()
	for path: String in [SCRATCH_PATH, SWIPE_PATH, CURL_UP_PATH]:
		_add_move(ctx, _load_move(path))
	return ctx


func _add_move(ctx: BattleContext, move: MoveData) -> void:
	ctx.moves[move.id] = move
	var instance := MoveInstance.new()
	instance.move_id = move.id
	ctx.loadout.append(instance)


func _use(slot: int) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.USE_MOVE
	action.slot = slot
	return action


func _intent(
	kind: IntentData.Kind, amount: int, status: StringName = &"", turns: int = 0
) -> IntentData:
	var intent := IntentData.new()
	intent.kind = kind
	intent.amount = amount
	intent.status = status
	intent.turns = turns
	return intent


func _enemy(max_hp: int, suit: Suit.Type, pattern: Array[IntentData]) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.max_hp = max_hp
	enemy.suit = suit
	enemy.pattern = pattern
	return enemy


## Pickpocket Pigeon from content: ⚔4, ✋-10 MP, ⚔6, ♥ 20 HP.
func _pigeon(max_hp: int = 20) -> EnemyData:
	var pattern: Array[IntentData] = [
		_intent(IntentData.Kind.ATTACK, 4),
		_intent(IntentData.Kind.STEAL_MP, 10),
		_intent(IntentData.Kind.ATTACK, 6),
	]
	return _enemy(max_hp, Suit.Type.HEARTS, pattern)


## Junkyard Pup from content: ▼Weak 2, ⚔7, ⚔7, ♠ 28 HP.
func _pup() -> EnemyData:
	var pattern: Array[IntentData] = [
		_intent(IntentData.Kind.DEBUFF, 0, &"weak", 2),
		_intent(IntentData.Kind.ATTACK, 7),
		_intent(IntentData.Kind.ATTACK, 7),
	]
	return _enemy(28, Suit.Type.SPADES, pattern)


## A one-intent enemy that repeats the same attack forever.
func _dummy(max_hp: int, suit: Suit.Type, attack: int) -> EnemyData:
	var pattern: Array[IntentData] = [_intent(IntentData.Kind.ATTACK, attack)]
	return _enemy(max_hp, suit, pattern)


## Starts a battle, then moves the enemy's shown intent to [param intent_index].
func _battle_at(
	enemy: EnemyData, intent_index: int, ctx: BattleContext, rngs: RngSet
) -> BattleState:
	var state: BattleState = BattleRules.start(enemy, ctx, rngs.battle).state
	state.intent_index = intent_index
	state.next_intent = enemy.pattern[intent_index]
	return state


func _run_fixed_turns() -> Array[String]:
	var rngs := RngSet.for_seed("test")
	var ctx := _starter_context()
	var state := _battle_at(_pigeon(), 0, ctx, rngs)
	var described: Array[String] = []
	for slot: int in [SLOT_SCRATCH, SLOT_SWIPE, SLOT_CURL_UP]:
		for event: BattleEvent in BattleRules.apply(state, _use(slot), ctx, rngs):
			described.append(_describe(event))
	return described


func _describe(event: BattleEvent) -> String:
	return (
		"%d|%d|%d|%d|%d|%d|%d|%d|%s|%d|%s|%s"
		% [
			event.kind,
			event.actor,
			event.amount,
			event.value_after,
			event.shield_after,
			event.absorbed,
			event.suit_from,
			event.suit_to,
			event.status,
			event.turns,
			event.move_id,
			event.reason,
		]
	)


func _kinds(events: Array[BattleEvent]) -> Array[BattleEvent.Kind]:
	var kinds: Array[BattleEvent.Kind] = []
	for event: BattleEvent in events:
		kinds.append(event.kind)
	return kinds


func _damage_by(events: Array[BattleEvent], attacker: BattleEvent.Actor) -> Array[int]:
	var amounts: Array[int] = []
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == attacker:
			amounts.append(event.amount)
	return amounts


func _sum(amounts: Array[int]) -> int:
	var total: int = 0
	for amount: int in amounts:
		total += amount
	return total


func _first_index(events: Array[BattleEvent], kind: BattleEvent.Kind) -> int:
	for index: int in events.size():
		if events[index].kind == kind:
			return index
	return -1


func _last_index(events: Array[BattleEvent], kind: BattleEvent.Kind) -> int:
	for index: int in range(events.size() - 1, -1, -1):
		if events[index].kind == kind:
			return index
	return -1
