extends TestCase
## Coin family (PRD §6.2, gamble-math.md, decisions D19, D22) through BattleRules with the shipped
## Coin content. Flips are scripted through ctx.forced: 1 heads, 0 tails (decisions §D, D37).

const DOUBLE_OR_NOTHING_PATH: String = "res://src/content/moves/double_or_nothing.tres"
const HEADS_UP_PATH: String = "res://src/content/moves/heads_up.tres"
const HOT_STREAK_PATH: String = "res://src/content/moves/hot_streak.tres"
const GOLD_TOOTH_PATH: String = "res://src/content/relics/gold_tooth.tres"

## Loadout slots of the test kit, in the order _context() adds them.
const SLOT_DOUBLE: int = 0
const SLOT_HEADS_UP: int = 1
const SLOT_HOT_STREAK: int = 2

## Backfire cap is not under test here; the starting cap (7) keeps every coin row intact.
const CAP: int = 7
const H: int = 1
const T: int = 0


func test_heads_chance_base_55() -> void:
	var rows: Array[GambleOddsRow] = CoinFamily.odds(_coin(DOUBLE_OR_NOTHING_PATH), 0, 1.0, CAP)
	assert_eq(rows[CoinFamily.HEADS_ROW].label, &"Heads", "heads row first")
	assert_almost_eq(rows[CoinFamily.HEADS_ROW].probability, 0.55, 1e-9, "heads")
	assert_almost_eq(rows[CoinFamily.TAILS_ROW].probability, 0.45, 1e-9, "tails")
	assert_eq(rows[CoinFamily.TAILS_ROW].backfire, 3, "tails backfire")


func test_heads_chance_capped_at_95() -> void:
	assert_almost_eq(CoinFamily.heads_chance(40), 0.95, 1e-9, "luck 40")
	assert_almost_eq(CoinFamily.heads_chance(50), 0.95, 1e-9, "luck 50")


func test_negative_luck_lowers_heads() -> void:
	assert_almost_eq(CoinFamily.heads_chance(-10), 0.45, 1e-9, "luck -10")
	assert_almost_eq(CoinFamily.heads_chance(-60), 0.05, 1e-9, "luck -60 floors at 5%")
	var rows: Array[GambleOddsRow] = CoinFamily.odds(_coin(HEADS_UP_PATH), -10, 1.0, CAP)
	assert_eq(rows[CoinFamily.HEADS_ROW].payout, 14, "negative luck never cuts a coin payout")
	assert_eq(rows[CoinFamily.TAILS_ROW].mp_gain, 15, "heads up tails row shows its MP")


func test_dn_first_flip_is_automatic() -> void:
	var ctx: BattleContext = _context([H])
	var state: BattleState = _battle(ctx)
	var events: Array[BattleEvent] = _apply(state, _use(SLOT_DOUBLE), ctx)
	var flip: int = _first_index(events, BattleEvent.Kind.COIN_FLIPPED)
	assert_true(flip > _first_index(events, BattleEvent.Kind.GAMBLE_STARTED), "flip after start")
	assert_eq(events[flip].amount, 16, "pending 16")
	assert_true(events[flip].gamble.is_heads, "heads")
	assert_eq(events.back().kind, BattleEvent.Kind.GAMBLE_AWAITING_CHOICE, "waits after heads")
	assert_eq(events.back().reason, &"coin", "awaiting coin")
	assert_true(state.pending != null, "pending")


func test_dn_doubles_16_32_64_128() -> void:
	var ctx: BattleContext = _context([H, H, H, H])
	ctx.due[&"coin"] = 2
	var state: BattleState = _battle(ctx)
	var events: Array[BattleEvent] = _apply(state, _use(SLOT_DOUBLE), ctx)
	for _flip: int in 3:
		events.append_array(_apply(state, _coin_call(GambleChoice.CoinCall.FLIP), ctx))
	var pending: Array[int] = []
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.COIN_FLIPPED:
			pending.append(event.amount)
	assert_eq(pending, [16, 32, 64, 128], "ladder")
	assert_eq(
		events[_first_index(events, BattleEvent.Kind.COIN_FLIPPED)].gamble.ladder,
		PackedInt32Array([16, 32, 64, 128]),
		"ladder shown on the first flip"
	)
	assert_true(state.pending == null, "fourth head cashes out")
	var resolved: BattleEvent = events[_first_index(events, BattleEvent.Kind.GAMBLE_RESOLVED)]
	assert_eq(resolved.gamble.payout, 128, "payout")
	assert_eq(resolved.gamble.tier, &"4 heads", "tier")
	assert_eq(_due_amount(events), 0, "top tier empties Due")


func test_dn_tails_zero_and_backfire_3() -> void:
	var ctx: BattleContext = _context([H, T])
	var state: BattleState = _battle(ctx)
	_apply(state, _use(SLOT_DOUBLE), ctx)
	var mp_before: int = state.mp
	var events: Array[BattleEvent] = _apply(state, _coin_call(GambleChoice.CoinCall.FLIP), ctx)
	var kinds: Array[BattleEvent.Kind] = _kinds(events)
	var expected: Array[BattleEvent.Kind] = [
		BattleEvent.Kind.COIN_FLIPPED,
		BattleEvent.Kind.GAMBLE_RESOLVED,
		BattleEvent.Kind.BACKFIRE,
		BattleEvent.Kind.DUE_CHANGED,
	]
	assert_eq(kinds.slice(0, 4), expected, "event order")
	assert_true(not events[0].gamble.is_heads, "tails")
	assert_eq(events[1].gamble.payout, 0, "payout 0")
	assert_eq(events[1].gamble.tier, &"Tails", "tier")
	assert_eq(events[2].amount, 3, "backfire 3")
	assert_eq(_due_amount(events), 1, "Due +1")
	assert_eq(_gamble_mp(events), 0, "no MP from the gamble")
	assert_true(state.mp >= mp_before, "tails costs no MP")


func test_dn_cash_out_deals_pending() -> void:
	var ctx: BattleContext = _context([H, H])
	var state: BattleState = _battle(ctx)
	_apply(state, _use(SLOT_DOUBLE), ctx)
	var events: Array[BattleEvent] = _apply(state, _coin_call(GambleChoice.CoinCall.FLIP), ctx)
	assert_eq(events[0].amount, 32, "pending 32")
	events = _apply(state, _coin_call(GambleChoice.CoinCall.CASH_OUT), ctx)
	assert_eq(events[0].kind, BattleEvent.Kind.GAMBLE_RESOLVED, "cash out resolves")
	assert_eq(events[0].gamble.tier, &"2 heads", "tier")
	assert_eq(events[1].kind, BattleEvent.Kind.DAMAGE_DEALT, "then damage")
	assert_eq(events[1].amount, 32, "damage 32")
	assert_eq(_first_index(events, BattleEvent.Kind.BACKFIRE), -1, "no backfire")
	assert_eq(_due_amount(events), -1, "middle tier leaves Due")


func test_heads_up_heads_14_tails_15_mp() -> void:
	var ctx: BattleContext = _context([H])
	var state: BattleState = _battle(ctx)
	var events: Array[BattleEvent] = _apply(state, _use(SLOT_HEADS_UP), ctx)
	assert_true(state.pending == null, "no choice")
	assert_eq(_payout(events), 14, "heads deals 14")
	assert_eq(_due_amount(events), -1, "one head leaves Due (D19)")

	ctx = _context([T])
	state = _battle(ctx)
	state.mp = 50
	events = _apply(state, _use(SLOT_HEADS_UP), ctx)
	assert_eq(_payout(events), 0, "tails deals 0")
	assert_eq(_gamble_mp(events), 15, "tails gains 15 MP")
	assert_eq(_first_index(events, BattleEvent.Kind.BACKFIRE), -1, "no backfire")
	assert_eq(_due_amount(events), 1, "tails adds a pip")


func test_hot_streak_stops_at_5_flips() -> void:
	var ctx: BattleContext = _context([H, H, H, H, H, T])
	var state: BattleState = _battle(ctx)
	var events: Array[BattleEvent] = _apply(state, _use(SLOT_HOT_STREAK), ctx)
	assert_eq(_count(events, BattleEvent.Kind.COIN_FLIPPED), 5, "five flips")
	var resolved: BattleEvent = events[_first_index(events, BattleEvent.Kind.GAMBLE_RESOLVED)]
	assert_eq(resolved.gamble.tier, &"5 heads", "tier")
	assert_eq(resolved.gamble.payout, 45, "9 per head")
	assert_eq(state.streak, 5, "five stacks")
	assert_eq(_due_amount(events), -1, "Due already empty")


func test_streak_bonus_2_per_stack_then_reset() -> void:
	var ctx: BattleContext = _context([H, H, T])
	var state: BattleState = _battle(ctx)
	state.streak = 1
	var events: Array[BattleEvent] = _apply(state, _use(SLOT_HOT_STREAK), ctx)
	assert_eq(_payout(events), 20, "9 + 9 + 2 × 1")
	assert_eq(events[_first_index(events, BattleEvent.Kind.COIN_FLIPPED) + 1].amount, 20, "pending")
	var streak: BattleEvent = events[_first_index(events, BattleEvent.Kind.STREAK_CHANGED)]
	assert_eq(streak.amount, 0, "tails resets Streak")
	assert_eq(state.streak, 0, "state reset")
	assert_eq(state.consecutive_heads, 0, "heads in a row reset")


func test_gold_tooth_adds_3_per_streak() -> void:
	var tooth: RelicData = load(GOLD_TOOTH_PATH) as RelicData
	var ctx: BattleContext = _context([H, H, H])
	ctx.relics.append(tooth)
	var hook_ctx := HookContext.new()
	hook_ctx.family = &"coin"
	hook_ctx.consecutive_heads = 4
	var state: BattleState = _battle(ctx)
	var flat: int = Hooks.collect(HookData.Trigger.BEFORE_MOVE, state, ctx, hook_ctx).flat_damage
	assert_eq(flat, 12, "3 × 4 heads in a row")
	hook_ctx.family = &"dice"
	assert_eq(
		Hooks.collect(HookData.Trigger.BEFORE_MOVE, state, ctx, hook_ctx).flat_damage,
		0,
		"coin moves only"
	)

	_apply(state, _use(SLOT_DOUBLE), ctx)
	var events: Array[BattleEvent] = _apply(state, _coin_call(GambleChoice.CoinCall.FLIP), ctx)
	events.append_array(_apply(state, _coin_call(GambleChoice.CoinCall.CASH_OUT), ctx))
	assert_eq(_payout(events), 38, "32 + 3 × 2")
	assert_true(_first_index(events, BattleEvent.Kind.RELIC_TRIGGERED) >= 0, "relic flashes")
	state.mp = 100
	events = _apply(state, _use(SLOT_HEADS_UP), ctx)
	assert_eq(_payout(events), 23, "heads carry across coin moves: 14 + 3 × 3")


func test_due_pip_bottom_tier_and_empty_at_top() -> void:
	var ctx: BattleContext = _context([T])
	var state: BattleState = _battle(ctx)
	assert_eq(_due_amount(_apply(state, _use(SLOT_DOUBLE), ctx)), 1, "tails +1")
	ctx.forced.assign([H, H, H, T])
	state.mp = 100
	var events: Array[BattleEvent] = _apply(state, _use(SLOT_HOT_STREAK), ctx)
	assert_eq(_due_amount(events), 0, "three heads empty Due")


func test_preview_rows_match_resolve_probabilities() -> void:
	var ctx: BattleContext = _context([])
	ctx.luck_bonus = 20
	var state: BattleState = _battle(ctx)
	var odds: GambleOdds = BattleRules.preview_move(state, SLOT_DOUBLE, ctx).odds
	assert_almost_eq(odds.rows[CoinFamily.HEADS_ROW].probability, 0.75, 1e-9, "luck 20")
	# Lucky Charm puts Heads at 100% in the snapshot; the flips read that same row.
	state.guarantee_top_tier = true
	var events: Array[BattleEvent] = _apply(state, _use(SLOT_HOT_STREAK), ctx)
	assert_eq(_count(events, BattleEvent.Kind.COIN_FLIPPED), 5, "every flip lands heads")
	assert_eq(_payout(events), 45, "top tier")


func test_coin_choice_needs_a_call() -> void:
	var ctx: BattleContext = _context([H])
	var state: BattleState = _battle(ctx)
	_apply(state, _use(SLOT_DOUBLE), ctx)
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.GAMBLE_CHOICE
	var events: Array[BattleEvent] = _apply(state, action, ctx)
	assert_eq(events.size(), 1, "rejected alone")
	assert_eq(events[0].reason, &"invalid_choice", "reason")
	assert_true(state.pending != null, "still waiting")


func _coin(path: String) -> CoinGambleData:
	return (load(path) as MoveData).gamble as CoinGambleData


## The three coin moves, with [param forced] queued for the next gamble.
func _context(forced: Array[int]) -> BattleContext:
	var ctx := BattleContext.new()
	for path: String in [DOUBLE_OR_NOTHING_PATH, HEADS_UP_PATH, HOT_STREAK_PATH]:
		var move: MoveData = load(path) as MoveData
		ctx.moves[move.id] = move
		var instance := MoveInstance.new()
		instance.move_id = move.id
		ctx.loadout.append(instance)
	ctx.forced = forced
	return ctx


## A battle against a 200 HP enemy that attacks for 1, with MP topped up.
func _battle(ctx: BattleContext) -> BattleState:
	var intent := IntentData.new()
	intent.kind = IntentData.Kind.ATTACK
	intent.amount = 1
	var enemy := EnemyData.new()
	enemy.max_hp = 200
	enemy.suit = Suit.Type.CLUBS
	enemy.pattern.append(intent)
	var state: BattleState = BattleRules.start(enemy, ctx, RngSet.for_seed("test").battle).state
	state.mp = 100
	return state


func _apply(state: BattleState, action: PlayerAction, ctx: BattleContext) -> Array[BattleEvent]:
	return BattleRules.apply(state, action, ctx, RngSet.for_seed("test:coin"))


func _use(slot: int) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.USE_MOVE
	action.slot = slot
	return action


func _coin_call(coin_call: GambleChoice.CoinCall) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.GAMBLE_CHOICE
	action.gamble_choice.coin = coin_call
	return action


func _payout(events: Array[BattleEvent]) -> int:
	return events[_first_index(events, BattleEvent.Kind.GAMBLE_RESOLVED)].gamble.payout


## The new Due pips of the first DUE_CHANGED, or -1 when Due didn't change.
func _due_amount(events: Array[BattleEvent]) -> int:
	var index: int = _first_index(events, BattleEvent.Kind.DUE_CHANGED)
	return events[index].amount if index >= 0 else -1


func _gamble_mp(events: Array[BattleEvent]) -> int:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.MP_CHANGED and event.reason == &"gamble":
			return event.amount
	return 0


func _count(events: Array[BattleEvent], kind: BattleEvent.Kind) -> int:
	return _kinds(events).count(kind)


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
