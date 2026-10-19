class_name CoinFamily
extends RefCounted
## The Coin family (PRD §6.2): flip a coin; Double or Nothing lets the player cash out or flip
## again after each head. Pure: every flip comes from session.forced (1 heads, 0 tails) or the
## gamble stream (decisions §D), at the Heads row's chance from the odds snapshot.

## Heads chance at Luck 0 (PRD §6.2).
## ponytail: mirrors TuningData.coin_heads_base like GambleRules.PROBABILITY_CAP; ContentDb fails on
## drift until T036 wires tuning through the context.
const HEADS_BASE: float = 0.55
## Lowest heads chance negative Luck can reach (decisions D20).
const HEADS_FLOOR: float = 0.05
## Flat damage per Hot Streak stack on every coin payout, added after the table (D22).
const STREAK_DAMAGE_PER_STACK: int = 2
## Cashing out at, or a Hot Streak reaching, this many heads is the top tier (decisions D19).
const TOP_TIER_HEADS: int = 3
## A forced flip of 1 lands heads, 0 lands tails (decisions D37).
const FORCED_HEADS: int = 1
## Odds rows, in table order. The Heads row's probability is the chance every flip rolls.
const HEADS_ROW: int = 0
const TAILS_ROW: int = 1
const LABEL_HEADS: StringName = &"Heads"
const LABEL_TAILS: StringName = &"Tails"


## The Coin data of [param session]'s move. Only Coin moves reach this family.
static func gamble_of(session: GambleSession, ctx: BattleContext) -> CoinGambleData:
	var move: MoveData = ctx.moves[session.move_id]
	var coin: CoinGambleData = move.gamble as CoinGambleData
	assert(coin != null, "move %s has no CoinGambleData" % session.move_id)
	return coin


## Chance one flip lands heads at [param luck]: base plus Luck, from 5% to the 95% cap (PRD §6.2,
## gamble-math.md, D20). Negative Luck lowers it instead of cutting the payout (PRD §6.0 rule 6).
static func heads_chance(luck: int) -> float:
	return clampf(HEADS_BASE + float(luck) / 100.0, HEADS_FLOOR, GambleRules.PROBABILITY_CAP)


## Damage of the first head: the start of the ladder, Heads Up's payout, or one Hot Streak head.
static func first_head_damage(coin: CoinGambleData) -> int:
	return coin.start_damage if coin.mode != CoinGambleData.Mode.STREAK else coin.per_head_damage


## Table damage after [param heads] heads, before Streak and relic bonuses (PRD §6.2).
static func pending_damage(coin: CoinGambleData, heads: int) -> int:
	if heads <= 0:
		return 0
	match coin.mode:
		CoinGambleData.Mode.DOUBLE:
			return coin.start_damage * (1 << (heads - 1))
		CoinGambleData.Mode.STREAK:
			return coin.per_head_damage * heads
	return coin.start_damage


## The odds of one flip: Heads, then Tails (PRD §6.0 rule 2). Tails shows the backfire and Heads
## Up's MP. Payouts ignore Luck because Coin takes Luck as heads chance.
static func odds(
	coin: CoinGambleData, luck: int, payout_mult: float, backfire_cap: int
) -> Array[GambleOddsRow]:
	var chance: float = heads_chance(luck)
	var heads: GambleOddsRow = GambleRules.outcome_row(
		LABEL_HEADS,
		first_head_damage(coin),
		1.0,
		0,
		GambleData.DueStep.NONE,
		0,
		payout_mult,
		backfire_cap
	)
	heads.probability = chance
	var tails: GambleOddsRow = GambleRules.outcome_row(
		LABEL_TAILS, 0, 1.0, coin.backfire, GambleData.DueStep.BOTTOM, 0, payout_mult, backfire_cap
	)
	tails.mp_gain = coin.tails_mp
	tails.probability = 1.0 - chance
	return [heads, tails]


## Flips until the move needs a choice (Double or Nothing after a head) or is finished.
static func start(
	session: GambleSession, state: BattleState, ctx: BattleContext, rng: SeededRng
) -> Array[BattleEvent]:
	var coin: CoinGambleData = gamble_of(session, ctx)
	var events: Array[BattleEvent] = []
	match coin.mode:
		CoinGambleData.Mode.DOUBLE:
			_flip_ladder(session, state, ctx, coin, rng, events)
		CoinGambleData.Mode.SINGLE:
			var is_heads: bool = _flip(session, state, ctx, coin, rng, events)
			_finish(session, state, ctx, coin, not is_heads, events)
		CoinGambleData.Mode.STREAK:
			var is_tails: bool = false
			while session.heads < coin.max_heads and not is_tails:
				is_tails = not _flip(session, state, ctx, coin, rng, events)
			_finish(session, state, ctx, coin, is_tails, events)
	return events


## Cash out deals the pending damage; Flip flips again. The caller has run choice_rejection first.
static func choose(
	session: GambleSession,
	choice: GambleChoice,
	state: BattleState,
	ctx: BattleContext,
	rng: SeededRng
) -> Array[BattleEvent]:
	var coin: CoinGambleData = gamble_of(session, ctx)
	var events: Array[BattleEvent] = []
	if choice.coin == GambleChoice.CoinCall.CASH_OUT:
		_finish(session, state, ctx, coin, false, events)
	else:
		_flip_ladder(session, state, ctx, coin, rng, events)
	return events


## Why [param choice] cannot run on a pending coin gamble, or &"" if it can.
static func choice_rejection(choice: GambleChoice) -> StringName:
	if choice.coin == GambleChoice.CoinCall.NONE:
		return &"invalid_choice"
	return &""


## Double or Nothing: one flip, then tails finishes, the last rung cashes out, and any other head
## waits for Cash out or Flip.
static func _flip_ladder(
	session: GambleSession,
	state: BattleState,
	ctx: BattleContext,
	coin: CoinGambleData,
	rng: SeededRng,
	events: Array[BattleEvent]
) -> void:
	var is_heads: bool = _flip(session, state, ctx, coin, rng, events)
	if not is_heads or session.heads >= coin.max_heads:
		_finish(session, state, ctx, coin, not is_heads, events)
		return
	var awaiting := BattleEvent.new(BattleEvent.Kind.GAMBLE_AWAITING_CHOICE)
	awaiting.reason = session.family
	events.append(awaiting)


## What cashing out at 1 to max_heads heads of this use pays, from the same rows _finish uses, so
## the ladder on screen is the payout (PRD §6.0 rule 2).
static func ladder(
	session: GambleSession, state: BattleState, ctx: BattleContext, coin: CoinGambleData
) -> PackedInt32Array:
	var payouts := PackedInt32Array()
	for heads: int in range(1, coin.max_heads + 1):
		payouts.append(_cash_row(session, state, ctx, coin, heads).row.payout)
	return payouts


## One flip: COIN_FLIPPED with the pending payout and the ladder. A head counts toward this use and
## the battle's heads in a row. Tails resets are left to _finish, after the payout reads them.
static func _flip(
	session: GambleSession,
	state: BattleState,
	ctx: BattleContext,
	coin: CoinGambleData,
	rng: SeededRng,
	events: Array[BattleEvent]
) -> bool:
	var is_heads: bool = _draw_heads(session, rng)
	if is_heads:
		session.heads += 1
		state.consecutive_heads += 1
	var flipped := BattleEvent.new(BattleEvent.Kind.COIN_FLIPPED)
	flipped.gamble = GambleEventData.new()
	flipped.gamble.is_heads = is_heads
	flipped.gamble.heads = session.heads
	flipped.gamble.ladder = ladder(session, state, ctx, coin)
	if is_heads:
		flipped.amount = flipped.gamble.ladder[session.heads - 1]
	events.append(flipped)
	return is_heads


## The next forced side if one is queued, otherwise a flip from the gamble stream at the snapshot's
## Heads chance, so the odds shown are the odds rolled (PRD §6.0 rule 2).
static func _draw_heads(session: GambleSession, rng: SeededRng) -> bool:
	if not session.forced.is_empty():
		var side: int = session.forced.pop_front()
		assert(side == 0 or side == FORCED_HEADS, "forced coin side %d is not 0 or 1" % side)
		return side == FORCED_HEADS
	var heads_row: GambleOddsRow = session.odds.rows[HEADS_ROW]
	assert(heads_row.label == LABEL_HEADS, "coin odds must list Heads first")
	return rng.chance(heads_row.probability)


## Settles the payout on [param session]: a miss (Double or Nothing or Heads Up tails, a Hot
## Streak with no heads) pays nothing and backfires; anything else cashes out its heads. Then Hot
## Streak adds its heads to Streak, and a tails resets Streak and the heads in a row (D22).
static func _finish(
	session: GambleSession,
	state: BattleState,
	ctx: BattleContext,
	coin: CoinGambleData,
	is_tails: bool,
	events: Array[BattleEvent]
) -> void:
	var is_miss: bool = session.heads == 0 or (is_tails and coin.mode != CoinGambleData.Mode.STREAK)
	var row: GambleOddsRow
	if is_miss:
		row = GambleRules.outcome_row(
			LABEL_TAILS,
			0,
			1.0,
			coin.backfire,
			GambleData.DueStep.BOTTOM,
			0,
			1.0,
			GambleRules.backfire_cap(state, ctx)
		)
	else:
		var cash: CashOut = _cash_row(session, state, ctx, coin, session.heads)
		row = cash.row
		events.append_array(cash.relic_events)
	session.damage = row.payout
	session.backfire = row.backfire
	session.mp_gain = coin.tails_mp if is_tails else 0
	session.tier = row.label
	session.due_step = row.due_step
	session.finished = true
	_settle_streak(state, coin, session.heads, is_tails, events)


## The payout row for cashing out at [param heads] heads of this use, and the RELIC_TRIGGERED
## events it fires. Streak (+2 per stack) and Gold Tooth (+3 per head in a row, counting these
## heads) add flat damage after the table, then statuses multiply and it rounds once (D22).
static func _cash_row(
	session: GambleSession, state: BattleState, ctx: BattleContext, coin: CoinGambleData, heads: int
) -> CashOut:
	var hook_ctx := HookContext.new()
	hook_ctx.move = ctx.moves[session.move_id]
	hook_ctx.move_instance = state.equipped[state.acting_slot]
	hook_ctx.family = session.family
	hook_ctx.consecutive_heads = state.consecutive_heads - session.heads + heads
	var hooks: HookResult = Hooks.collect(HookData.Trigger.BEFORE_MOVE, state, ctx, hook_ctx)
	var cash := CashOut.new()
	cash.row = GambleRules.outcome_row(
		_tier_label(heads),
		pending_damage(coin, heads) + STREAK_DAMAGE_PER_STACK * state.streak + hooks.flat_damage,
		1.0,
		0,
		_due_step(heads),
		0,
		GambleRules.status_mult(state),
		GambleRules.backfire_cap(state, ctx)
	)
	cash.relic_events = hooks.events
	return cash


static func _settle_streak(
	state: BattleState, coin: CoinGambleData, heads: int, is_tails: bool, events: Array[BattleEvent]
) -> void:
	var streak_before: int = state.streak
	if coin.mode == CoinGambleData.Mode.STREAK:
		state.streak += heads
	if is_tails:
		state.streak = 0
		state.consecutive_heads = 0
	if state.streak == streak_before:
		return
	var changed := BattleEvent.new(BattleEvent.Kind.STREAK_CHANGED)
	changed.amount = state.streak
	events.append(changed)


## Due step of a cash-out (decisions D19): three or more heads empty the meter, fewer leave it.
## A miss is BOTTOM, set by _finish.
static func _due_step(heads: int) -> GambleData.DueStep:
	if heads >= TOP_TIER_HEADS:
		return GambleData.DueStep.TOP
	return GambleData.DueStep.NONE


static func _tier_label(heads: int) -> StringName:
	if heads == 1:
		return &"1 head"
	return StringName("%d heads" % heads)


## One cash-out row and the relic events its bonuses fire.
class CashOut:
	extends RefCounted
	var row: GambleOddsRow
	var relic_events: Array[BattleEvent] = []
