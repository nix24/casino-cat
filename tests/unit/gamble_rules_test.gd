extends TestCase
## Gamble engine (PRD §6.0, §6.1) from the T002 worked examples and the gamble-math tables. Odds
## come from GambleRules; battles run through BattleRules with the shipped Dice content. Faces are
## scripted through ctx.forced (decisions §D), so no test needs a special RNG.

const PAW_ROLL_PATH: String = "res://src/content/moves/paw_roll.tres"
const LOADED_PAWS_PATH: String = "res://src/content/moves/loaded_paws.tres"
const SNAKE_EYES_PATH: String = "res://src/content/moves/snake_eyes.tres"
const SCRATCH_PATH: String = "res://src/content/moves/scratch.tres"

## Loadout slots of the test kit, in the order _context() adds them.
const SLOT_PAW_ROLL: int = 0
const SLOT_SCRATCH: int = 1
const SLOT_LOADED_PAWS: int = 2
const SLOT_SNAKE_EYES: int = 3

## Backfire cap at the starting 60 max HP (PRD §6.0 rule 8): floor(60 × 12%) = 7.
const CAP_AT_60_HP: int = 7


func test_paw_roll_luck0_odds_match_gamble_math() -> void:
	var table: GambleOdds = GambleRules.odds(_paw_roll(), 0, 1.0, CAP_AT_60_HP)
	var labels: Array[StringName] = [&"Snake eyes", &"Cold", &"Fair", &"Hot", &"Lucky", &"Boxcars"]
	var probabilities: Array[float] = [
		1.0 / 36.0, 9.0 / 36.0, 16.0 / 36.0, 7.0 / 36.0, 2.0 / 36.0, 1.0 / 36.0
	]
	var payouts: Array[int] = [0, 5, 10, 20, 30, 40]
	assert_eq(table.rows.size(), 6, "row count")
	var total: float = 0.0
	for index: int in table.rows.size():
		var row: GambleOddsRow = table.rows[index]
		assert_eq(row.label, labels[index], "label %d" % index)
		assert_almost_eq(row.probability, probabilities[index], 1e-9, "probability %d" % index)
		assert_eq(row.payout, payouts[index], "payout %d" % index)
		total += row.probability
	assert_almost_eq(total, 1.0, 1e-9, "sum of rows")
	assert_eq(table.rows[0].backfire, 4, "snake eyes backfire")


func test_expected_damage_paw_roll_is_12_36() -> void:
	var table: GambleOdds = GambleRules.odds(_paw_roll(), 0, 1.0, CAP_AT_60_HP)
	assert_almost_eq(table.expected_damage(), 445.0 / 36.0, 0.005)


func test_probabilities_sum_to_one_at_any_luck() -> void:
	var gambles: Array[GambleData] = [_paw_roll(), _loaded_paws(), _snake_eyes()]
	for luck: int in [-20, 0, 10, 20, 200]:
		for gamble: GambleData in gambles:
			var total: float = 0.0
			for row: GambleOddsRow in GambleRules.odds(gamble, luck, 1.0, CAP_AT_60_HP).rows:
				total += row.probability
			assert_almost_eq(total, 1.0, 1e-9, "luck %d" % luck)


func test_snake_eyes_luck10_p1() -> void:
	var table: GambleOdds = GambleRules.odds(_snake_eyes(), 10, 1.0, CAP_AT_60_HP)
	assert_eq(table.rows[0].label, &"Jackpot", "jackpot row first")
	assert_almost_eq(table.rows[0].probability, 13.0 / 72.0, 1e-6, "P(1) at luck 10")
	assert_almost_eq(table.expected_damage(), 11.42, 0.01, "EV at luck 10")


func test_probability_cap_95() -> void:
	var gambles: Array[GambleData] = [_paw_roll(), _loaded_paws(), _snake_eyes()]
	for gamble: GambleData in gambles:
		var capped: Array[GambleOddsRow] = GambleRules.odds(gamble, 95, 1.0, CAP_AT_60_HP).rows
		var over: Array[GambleOddsRow] = GambleRules.odds(gamble, 200, 1.0, CAP_AT_60_HP).rows
		for index: int in capped.size():
			assert_almost_eq(
				over[index].probability, capped[index].probability, 1e-12, "row %d" % index
			)


func test_final_payout_round_half_up() -> void:
	assert_eq(GambleRules.final_payout(10, 0.5, 0), 5, "half of 10")
	assert_eq(GambleRules.final_payout(10, 1.0, -10), 9, "10 at luck -10")
	assert_eq(GambleRules.final_payout(6, 1.0, -10), 5, "5.4 rounds down")
	assert_eq(GambleRules.final_payout(10, 2.0, 0, 0.75), 15, "payout multiplier")


func test_negative_luck_cuts_payout_never_backfire() -> void:
	var table: GambleOdds = GambleRules.odds(_paw_roll(), -20, 1.0, CAP_AT_60_HP)
	assert_eq(table.rows[3].label, &"Hot", "hot row")
	assert_eq(table.rows[3].payout, 16, "hot payout at luck -20")
	assert_eq(table.rows[0].backfire, 4, "snake eyes backfire unchanged")
	assert_almost_eq(table.rows[3].probability, 7.0 / 36.0, 1e-9, "negative luck adds no rerolls")


func test_backfire_cap() -> void:
	var table: GambleOdds = GambleRules.odds(_paw_roll(), 0, 1.0, 3)
	assert_eq(table.rows[0].backfire, 3, "backfire capped at 3")
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	assert_eq(GambleRules.backfire_cap(state, ctx), CAP_AT_60_HP, "cap at 60 max HP")


func test_luck_from_due_and_rattled() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	ctx.due[&"dice"] = 2
	assert_eq(GambleRules.luck(&"dice", state, ctx), 10, "two pips")
	state.cat.statuses[&"rattled"] = 2
	assert_eq(GambleRules.luck(&"dice", state, ctx), 0, "two pips and rattled")


func test_preview_and_resolve_use_same_rows() -> void:
	var paw: DiceGambleData = _paw_roll()
	var loaded: DiceGambleData = _loaded_paws()
	var snake: DiceGambleData = _snake_eyes()
	for luck: int in [0, -10]:
		var paw_table: GambleOdds = GambleRules.odds(paw, luck, 1.0, CAP_AT_60_HP)
		var loaded_table: GambleOdds = GambleRules.odds(loaded, luck, 1.0, CAP_AT_60_HP)
		var snake_table: GambleOdds = GambleRules.odds(snake, luck, 1.0, CAP_AT_60_HP)
		for first: int in range(1, 7):
			for second: int in range(1, 7):
				var faces := PackedInt32Array([first, second])
				var row: GambleOddsRow = DiceFamily.score(paw, faces, luck, 1.0, CAP_AT_60_HP)
				_assert_row_in(paw_table, row, "paw %s luck %d" % [faces, luck])
				for third: int in range(1, 7):
					var triple := PackedInt32Array([first, second, third])
					var loaded_row: GambleOddsRow = DiceFamily.score(
						loaded, triple, luck, 1.0, CAP_AT_60_HP
					)
					_assert_row_in(loaded_table, loaded_row, "loaded %s luck %d" % [triple, luck])
		for face: int in range(1, 7):
			var snake_row: GambleOddsRow = DiceFamily.score(
				snake, PackedInt32Array([face]), luck, 1.0, CAP_AT_60_HP
			)
			_assert_row_in(snake_table, snake_row, "snake %d luck %d" % [face, luck])


func test_worked_example_1_events() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 4)
	var rngs := RngSet.for_seed("test")
	ctx.forced = [4, 5]

	var opening: Array[BattleEvent] = BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	var opening_kinds: Array[BattleEvent.Kind] = [
		BattleEvent.Kind.MOVE_USED,
		BattleEvent.Kind.MP_CHANGED,
		BattleEvent.Kind.GAMBLE_STARTED,
		BattleEvent.Kind.DICE_ROLLED,
		BattleEvent.Kind.GAMBLE_AWAITING_CHOICE,
	]
	assert_eq(_kinds(opening), opening_kinds, "opening events")
	assert_eq(opening[0].move_id, &"paw_roll", "move used")
	assert_eq(opening[1].reason, &"cost", "cost reason")
	assert_eq(opening[1].amount, -30, "cost amount")
	assert_eq(opening[3].gamble.faces, PackedInt32Array([4, 5]), "first roll")
	assert_true(state.pending != null, "gamble waits for a choice")

	var keep: Array[BattleEvent] = BattleRules.apply(state, _choose(PackedInt32Array()), ctx, rngs)
	var resolved: BattleEvent = keep[0]
	assert_eq(resolved.kind, BattleEvent.Kind.GAMBLE_RESOLVED, "resolved first")
	assert_eq(resolved.gamble.tier, &"Hot", "tier")
	assert_eq(resolved.gamble.payout, 20, "payout")
	assert_eq(keep[1].kind, BattleEvent.Kind.DAMAGE_DEALT, "payout hits the enemy")
	assert_eq(keep[1].amount, 20, "payout amount")
	assert_eq(_first_index(keep, BattleEvent.Kind.SUIT_SHIFTED), -1, "cat already clubs")
	assert_true(_first_index(keep, BattleEvent.Kind.ENEMY_ACTED) > 1, "enemy acts after")
	assert_true(state.pending == null, "gamble cleared")


func test_worked_example_2_reroll() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	var rngs := RngSet.for_seed("test")
	ctx.forced = [6, 1, 5]

	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	var reroll: Array[BattleEvent] = BattleRules.apply(
		state, _choose(PackedInt32Array([1])), ctx, rngs
	)
	assert_eq(reroll[0].kind, BattleEvent.Kind.REROLLS_CHANGED, "rerolls changed first")
	assert_eq(reroll[0].amount, 0, "no rerolls left")
	assert_eq(reroll[1].kind, BattleEvent.Kind.DICE_REROLLED, "dice rerolled")
	assert_eq(reroll[1].gamble.indices, PackedInt32Array([1]), "rerolled index")
	assert_eq(reroll[1].gamble.faces, PackedInt32Array([6, 5]), "new faces")
	assert_eq(reroll[2].kind, BattleEvent.Kind.GAMBLE_AWAITING_CHOICE, "asks again")

	var keep: Array[BattleEvent] = BattleRules.apply(state, _choose(PackedInt32Array()), ctx, rngs)
	assert_eq(keep[0].gamble.tier, &"Lucky", "tier after reroll")
	assert_eq(keep[0].gamble.payout, 30, "payout after reroll")


func test_reroll_rejected_at_zero() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	var rngs := RngSet.for_seed("test")
	ctx.forced = [6, 1, 5]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	BattleRules.apply(state, _choose(PackedInt32Array([1])), ctx, rngs)

	var rejected: Array[BattleEvent] = BattleRules.apply(
		state, _choose(PackedInt32Array([0])), ctx, rngs
	)
	assert_eq(rejected.size(), 1, "single rejection")
	assert_eq(rejected[0].kind, BattleEvent.Kind.ACTION_REJECTED, "rejected kind")
	assert_eq(rejected[0].reason, &"no_rerolls", "rejection reason")
	assert_eq(state.rerolls, 0, "rerolls unchanged")
	assert_eq(state.pending.faces, PackedInt32Array([6, 5]), "faces unchanged")


func test_snake_eyes_backfire_skips_shield() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	var rngs := RngSet.for_seed("test")
	state.cat.shield = 10
	ctx.forced = [1, 1]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)

	var keep: Array[BattleEvent] = BattleRules.apply(state, _choose(PackedInt32Array()), ctx, rngs)
	var backfire_index: int = _first_index(keep, BattleEvent.Kind.BACKFIRE)
	assert_true(backfire_index >= 0, "backfire emitted")
	assert_eq(keep[backfire_index].amount, 4, "backfire amount")
	assert_eq(keep[backfire_index].value_after, 56, "hp after backfire")
	assert_eq(state.cat.shield, 10, "shield untouched")
	assert_eq(state.cat.hp, 56, "hp lost")
	for event: BattleEvent in keep:
		assert_true(
			not (
				event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == BattleEvent.Actor.CAT
			),
			"no payout hit on the enemy"
		)
	assert_eq(_taken_amount(keep), 4, "backfire counts as damage taken")


func test_backfire_can_lose_before_enemy_acts() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 4)
	var rngs := RngSet.for_seed("test")
	state.cat.hp = 3
	ctx.forced = [1, 1]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)

	var keep: Array[BattleEvent] = BattleRules.apply(state, _choose(PackedInt32Array()), ctx, rngs)
	assert_eq(_first_index(keep, BattleEvent.Kind.ENEMY_ACTED), -1, "enemy never acts")
	assert_eq(keep[keep.size() - 1].kind, BattleEvent.Kind.BATTLE_LOST, "battle lost")
	assert_eq(state.outcome, BattleState.Outcome.LOST, "outcome lost")


func test_due_steps() -> void:
	# Cold: bottom tier, adds a pip.
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	var rngs := RngSet.for_seed("test")
	ctx.forced = [1, 2]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	var cold: Array[BattleEvent] = BattleRules.apply(state, _choose(PackedInt32Array()), ctx, rngs)
	assert_eq(_due_event_amount(cold), 1, "cold adds a pip")
	assert_eq(ctx.due[&"dice"], 1, "pip stored")

	# Fair: middle tier, the meter does not move.
	ctx = _context()
	state = _battle(ctx, 0)
	ctx.forced = [3, 4]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	var fair: Array[BattleEvent] = BattleRules.apply(state, _choose(PackedInt32Array()), ctx, rngs)
	assert_eq(_first_index(fair, BattleEvent.Kind.DUE_CHANGED), -1, "fair leaves due alone")

	# Lucky: top tier, empties the meter.
	ctx = _context()
	state = _battle(ctx, 0)
	ctx.due[&"dice"] = 2
	ctx.forced = [5, 6]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	var lucky: Array[BattleEvent] = BattleRules.apply(state, _choose(PackedInt32Array()), ctx, rngs)
	assert_eq(_due_event_amount(lucky), 0, "lucky empties due")
	assert_eq(ctx.due[&"dice"], 0, "meter empty")

	# Cap: four pips stay at four. Luck bonus -20 cancels the Due luck so the 1s and 2s
	# cannot auto-reroll.
	ctx = _context()
	state = _battle(ctx, 0)
	ctx.due[&"dice"] = 4
	ctx.luck_bonus = -20
	ctx.forced = [1, 2]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	var capped: Array[BattleEvent] = BattleRules.apply(
		state, _choose(PackedInt32Array()), ctx, rngs
	)
	assert_eq(_first_index(capped, BattleEvent.Kind.DUE_CHANGED), -1, "no event at cap")
	assert_eq(ctx.due[&"dice"], 4, "pips capped at 4")


func test_rejections_while_pending() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	var rngs := RngSet.for_seed("test")
	ctx.forced = [3, 4]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	var mp_before: int = state.mp

	var use_while_pending: Array[BattleEvent] = BattleRules.apply(
		state, _use(SLOT_SCRATCH), ctx, rngs
	)
	assert_eq(use_while_pending[0].reason, &"gamble_pending", "move blocked while pending")
	assert_eq(state.mp, mp_before, "mp unchanged on rejection")

	var invalid: Array[BattleEvent] = BattleRules.apply(
		state, _choose(PackedInt32Array([0, 0])), ctx, rngs
	)
	assert_eq(invalid[0].reason, &"invalid_choice", "duplicate index rejected")
	assert_eq(state.rerolls, 1, "reroll not spent")

	var idle_state: BattleState = _battle(ctx, 0)
	var no_gamble: Array[BattleEvent] = BattleRules.apply(
		idle_state, _choose(PackedInt32Array()), ctx, rngs
	)
	assert_eq(no_gamble[0].reason, &"no_gamble_pending", "no gamble to choose for")


func test_gamble_resets_suit_and_repeat() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	var rngs := RngSet.for_seed("test")
	BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	assert_eq(state.cat.suit, Suit.Type.SPADES, "scratch shifts to spades")

	ctx.forced = [3, 4]
	BattleRules.apply(state, _use(SLOT_PAW_ROLL), ctx, rngs)
	var keep: Array[BattleEvent] = BattleRules.apply(state, _choose(PackedInt32Array()), ctx, rngs)
	var shift_index: int = _first_index(keep, BattleEvent.Kind.SUIT_SHIFTED)
	assert_true(shift_index >= 0, "gamble shifts the suit")
	assert_eq(keep[shift_index].suit_from, Suit.Type.SPADES, "shift from")
	assert_eq(keep[shift_index].suit_to, Suit.Type.CLUBS, "shift to")
	assert_eq(state.cat.suit, Suit.Type.CLUBS, "cat is clubs")

	BattleRules.apply(state, _use(SLOT_SCRATCH), ctx, rngs)
	assert_eq(state.repeat_count, 1, "streak restarted by the gamble")


func test_move_preview_has_odds() -> void:
	var ctx: BattleContext = _context()
	var state: BattleState = _battle(ctx, 0)
	var preview: MovePreview = BattleRules.preview_move(state, SLOT_PAW_ROLL, ctx)
	assert_eq(preview.damage, 0, "gambles show odds, not damage")
	assert_eq(preview.mp_cost, 30, "cost")
	assert_true(preview.odds != null, "odds attached")
	assert_eq(preview.odds.rows.size(), 6, "odds rows")


func _assert_row_in(table: GambleOdds, row: GambleOddsRow, message: String) -> void:
	for expected: GambleOddsRow in table.rows:
		if expected.label == row.label:
			assert_eq(row.payout, expected.payout, "payout " + message)
			assert_eq(row.backfire, expected.backfire, "backfire " + message)
			assert_eq(row.due_step, expected.due_step, "due step " + message)
			return
	assert_true(false, "no odds row labelled %s. %s" % [row.label, message])


func _taken_amount(events: Array[BattleEvent]) -> int:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.MP_CHANGED and event.reason == &"taken":
			return event.amount
	return 0


func _due_event_amount(events: Array[BattleEvent]) -> int:
	var index: int = _first_index(events, BattleEvent.Kind.DUE_CHANGED)
	assert_true(index >= 0, "DUE_CHANGED emitted")
	return events[index].amount if index >= 0 else -1


func _paw_roll() -> DiceGambleData:
	return (load(PAW_ROLL_PATH) as MoveData).gamble as DiceGambleData


func _loaded_paws() -> DiceGambleData:
	return (load(LOADED_PAWS_PATH) as MoveData).gamble as DiceGambleData


func _snake_eyes() -> DiceGambleData:
	return (load(SNAKE_EYES_PATH) as MoveData).gamble as DiceGambleData


## Starter kit plus the three dice moves, in slot order.
func _context() -> BattleContext:
	var ctx := BattleContext.new()
	for path: String in [PAW_ROLL_PATH, SCRATCH_PATH, LOADED_PAWS_PATH, SNAKE_EYES_PATH]:
		var move: MoveData = load(path) as MoveData
		ctx.moves[move.id] = move
		var instance := MoveInstance.new()
		instance.move_id = move.id
		ctx.loadout.append(instance)
	return ctx


## A battle against a 100 HP enemy that always attacks for [param attack], with MP topped up.
func _battle(ctx: BattleContext, attack: int) -> BattleState:
	var pattern: Array[IntentData] = []
	var intent := IntentData.new()
	intent.kind = IntentData.Kind.ATTACK
	intent.amount = attack
	pattern.append(intent)
	var enemy := EnemyData.new()
	enemy.max_hp = 100
	enemy.suit = Suit.Type.CLUBS
	enemy.pattern = pattern
	var state: BattleState = BattleRules.start(enemy, ctx, RngSet.for_seed("test").battle).state
	state.mp = 100
	return state


func _use(slot: int) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.USE_MOVE
	action.slot = slot
	return action


func _choose(indices: PackedInt32Array) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.GAMBLE_CHOICE
	action.gamble_choice.reroll_dice = indices
	return action


func _kinds(events: Array[BattleEvent]) -> Array[BattleEvent.Kind]:
	var kinds: Array[BattleEvent.Kind] = []
	for event: BattleEvent in events:
		kinds.append(event.kind)
	return kinds


func _first_index(events: Array[BattleEvent], kind: BattleEvent.Kind) -> int:
	for index: int in events.size():
		if events[index].kind == kind:
			return index
	return -1
