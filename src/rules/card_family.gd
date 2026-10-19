class_name CardFamily
extends RefCounted
## The Cards family (PRD §6.3): one 20-card battle deck (1-10, two of each), counts always
## visible. Nine Lives hits or stands, High Card draws one, Card Trick keeps one of three and puts
## the other two back in the player's order. Pure: cards come from session.forced or the deck, and
## the deck is shuffled on the gamble stream (decisions §D).

const CARD_VALUE_MAX: int = 10
const COPIES_PER_VALUE: int = 2
const DECK_SIZE: int = 20
const BLACKJACK_TOTAL: int = 21
## Nine Lives odds assume the player hits while the total is below this (gamble-math.md, D39).
const STAND_AT: int = 16
## High Card and Card Trick values at or below this add a Due pip; a 10 empties it (D19).
const BOTTOM_TIER_MAX_VALUE: int = 3
const TRICK_DRAWS: int = 3
const LABEL_BUST: StringName = &"Bust"
const LABEL_BLACKJACK: StringName = &"21"
## Nine Lives outcome codes in the odds: a bust, 21, a stand total (≥ STAND_AT), or the total a
## forgiven bust stands on (< STAND_AT).
const CODE_BUST: int = -1
## Base for packing per-value counts (0-2 each) into one memo key.
const COUNT_BASE: int = COPIES_PER_VALUE + 1


## The Cards data of [param session]'s move. Only Cards moves reach this family.
static func gamble_of(session: GambleSession, ctx: BattleContext) -> CardGambleData:
	var move: MoveData = ctx.moves[session.move_id]
	var card: CardGambleData = move.gamble as CardGambleData
	assert(card != null, "move %s has no CardGambleData" % session.move_id)
	return card


## A fresh deck, 1-10 twice, Fisher-Yates shuffled on [param rng] (PRD §6.3). Top = last element.
static func new_shuffled_deck(rng: SeededRng) -> PackedInt32Array:
	var deck := PackedInt32Array()
	for value: int in range(1, CARD_VALUE_MAX + 1):
		for _copy: int in COPIES_PER_VALUE:
			deck.append(value)
	for index: int in range(deck.size() - 1, 0, -1):
		var other: int = rng.range_int(0, index)
		var held: int = deck[index]
		deck[index] = deck[other]
		deck[other] = held
	return deck


## Cards left of each value (index 0 = value 1) as the player counts them. An empty deck shows a
## full one, because the next draw shuffles a fresh 20.
static func visible_counts(deck: PackedInt32Array) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(CARD_VALUE_MAX)
	counts.fill(COPIES_PER_VALUE if deck.is_empty() else 0)
	for value: int in deck:
		counts[value - 1] += 1
	return counts


## Chance the next hit busts a hand of [param total]: visible cards above 21 − total over all
## visible cards (PRD §6.3).
static func bust_chance(deck: PackedInt32Array, total: int) -> float:
	if total >= BLACKJACK_TOTAL:
		return 0.0
	var counts: PackedInt32Array = visible_counts(deck)
	var busting: int = 0
	for value: int in range(BLACKJACK_TOTAL - total + 1, CARD_VALUE_MAX + 1):
		busting += counts[value - 1]
	return float(busting) / float(_sum(counts))


static func hand_total(hand: PackedInt32Array) -> int:
	return _sum(hand)


## Draws the top card into the hand: CARD_DRAWN. An empty deck first shuffles a fresh 20
## (DECK_SHUFFLED). A forced value is pulled from the deck when it's there, so counts stay true.
static func draw_top(
	session: GambleSession, state: BattleState, rng: SeededRng
) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if state.deck.is_empty():
		state.deck = new_shuffled_deck(rng)
		var shuffled: BattleEvent = _card_event(BattleEvent.Kind.DECK_SHUFFLED, session, state)
		shuffled.amount = DECK_SIZE
		events.append(shuffled)
	var value: int = state.deck[state.deck.size() - 1]
	if not session.forced.is_empty():
		value = session.forced.pop_front()
		assert(value >= 1 and value <= CARD_VALUE_MAX, "forced card %d is not 1-10" % value)
	var index: int = state.deck.rfind(value)
	if index >= 0:
		state.deck.remove_at(index)
	session.hand.append(value)
	var drawn: BattleEvent = _card_event(BattleEvent.Kind.CARD_DRAWN, session, state)
	drawn.amount = value
	events.append(drawn)
	return events


## Draws the opening hand. High Card finishes at once; Nine Lives and Card Trick wait.
static func start(
	session: GambleSession, state: BattleState, ctx: BattleContext, rng: SeededRng
) -> Array[BattleEvent]:
	var card: CardGambleData = gamble_of(session, ctx)
	var events: Array[BattleEvent] = []
	match card.mode:
		CardGambleData.Mode.HIGH_CARD:
			events.append_array(draw_top(session, state, rng))
			_finish(session, _value_row(card, session.hand[0], session.odds.luck, state, ctx))
			return events
		CardGambleData.Mode.TRICK:
			for _draw: int in TRICK_DRAWS:
				events.append_array(draw_top(session, state, rng))
		CardGambleData.Mode.BLACKJACK:
			for _draw: int in 2:
				events.append_array(draw_top(session, state, rng))
	events.append(_awaiting_event(session, state))
	return events


## Continues Nine Lives (Hit or Stand) or settles Card Trick (pick and order). The caller has run
## choice_rejection first.
static func choose(
	session: GambleSession,
	choice: GambleChoice,
	state: BattleState,
	ctx: BattleContext,
	rng: SeededRng
) -> Array[BattleEvent]:
	var card: CardGambleData = gamble_of(session, ctx)
	if card.mode == CardGambleData.Mode.TRICK:
		return _trick(session, choice, state, ctx, card)
	if choice.cards == GambleChoice.CardCall.STAND:
		var total: int = hand_total(session.hand)
		_finish(session, _stand_row(total, false, session.odds.luck, state, ctx))
		return []
	return _hit(session, state, ctx, card, rng)


## Why [param choice] cannot run on a pending cards gamble, or &"" if it can.
static func choice_rejection(
	session: GambleSession, choice: GambleChoice, ctx: BattleContext
) -> StringName:
	if gamble_of(session, ctx).mode != CardGambleData.Mode.TRICK:
		return &"invalid_choice" if choice.cards == GambleChoice.CardCall.NONE else &""
	var order: PackedInt32Array = choice.trick_order
	var hand_size: int = session.hand.size()
	if choice.trick_pick < 0 or choice.trick_pick >= hand_size or order.size() != hand_size - 1:
		return &"invalid_choice"
	for index: int in order:
		if index < 0 or index >= hand_size or index == choice.trick_pick or order.count(index) > 1:
			return &"invalid_choice"
	return &""


## Cards that land the guaranteed row of a Lucky Charm table (PRD §8.3): the certain value for High
## Card and Card Trick. Nine Lives' 21 comes from 10, 1, then a hit on 11.
## ponytail: Nine Lives forces 10, 1, 10 even when those cards are gone; fine for a one-use item.
static func top_tier_cards(card: CardGambleData, table: GambleOdds) -> Array[int]:
	if card.mode == CardGambleData.Mode.BLACKJACK:
		return [CARD_VALUE_MAX, 1, CARD_VALUE_MAX]
	for row: GambleOddsRow in table.rows:
		if row.probability >= 1.0:
			return [String(row.label).to_int()]
	assert(false, "a guaranteed table has a certain row")
	return []


## The exact odds of [param card] from the visible [param deck] (PRD §6.0 rule 2). High Card: each
## value. Card Trick: the best of three. Nine Lives: every result when the player hits below
## STAND_AT, with Luck saves and forgiveness (gamble-math.md). Zero-chance rows are left out.
static func odds(
	card: CardGambleData,
	deck: PackedInt32Array,
	is_forgiveness_ready: bool,
	luck: int,
	payout_mult: float,
	backfire_cap: int
) -> Array[GambleOddsRow]:
	var chances: Dictionary[int, float]
	match card.mode:
		CardGambleData.Mode.HIGH_CARD:
			chances = _single_draw_chances(deck)
		CardGambleData.Mode.TRICK:
			chances = _best_of_three_chances(deck)
		CardGambleData.Mode.BLACKJACK:
			chances = _policy_chances(deck, is_forgiveness_ready, luck)
	var codes: Array[int] = chances.keys()
	codes.sort()
	var rows: Array[GambleOddsRow] = []
	for code: int in codes:
		if chances[code] <= 0.0:
			continue
		var row: GambleOddsRow
		if card.mode == CardGambleData.Mode.BLACKJACK:
			row = _policy_row(card, code, luck, payout_mult, backfire_cap)
		else:
			row = _row_for_value(card, code, luck, payout_mult, backfire_cap)
		row.probability = chances[code]
		rows.append(row)
	return rows


## One Nine Lives hit: Luck may save a bust card into the highest card that fits, then 21 pays,
## the first bust of the battle is forgiven, a second bust backfires, and anything else waits.
static func _hit(
	session: GambleSession,
	state: BattleState,
	ctx: BattleContext,
	card: CardGambleData,
	rng: SeededRng
) -> Array[BattleEvent]:
	var before: int = hand_total(session.hand)
	var events: Array[BattleEvent] = draw_top(session, state, rng)
	var luck: int = session.odds.luck
	if hand_total(session.hand) > BLACKJACK_TOTAL and luck > 0:
		if rng.chance(GambleRules.luck_chance(luck)):
			var saved: int = mini(CARD_VALUE_MAX, BLACKJACK_TOTAL - before)
			session.hand[session.hand.size() - 1] = saved
			var save_event: BattleEvent = _card_event(BattleEvent.Kind.CARD_SAVED, session, state)
			save_event.amount = saved
			events.append(save_event)
	var total: int = hand_total(session.hand)
	if total == BLACKJACK_TOTAL:
		_finish(session, _policy_row(card, BLACKJACK_TOTAL, luck, _mult(state), _cap(state, ctx)))
	elif total > BLACKJACK_TOTAL and not state.forgiveness_used:
		state.forgiveness_used = true
		session.forgiven = true
		_finish(session, _stand_row(before, true, luck, state, ctx))
	elif total > BLACKJACK_TOTAL:
		_finish(session, _policy_row(card, CODE_BUST, luck, _mult(state), _cap(state, ctx)))
	else:
		events.append(_awaiting_event(session, state))
	return events


## Card Trick: the picked card pays; the other two go back on top in the chosen order, the first
## listed ending on top (CARDS_REORDERED).
static func _trick(
	session: GambleSession,
	choice: GambleChoice,
	state: BattleState,
	ctx: BattleContext,
	card: CardGambleData
) -> Array[BattleEvent]:
	var put_back := PackedInt32Array()
	for index: int in choice.trick_order:
		put_back.append(session.hand[index])
	for position: int in range(put_back.size() - 1, -1, -1):
		state.deck.append(put_back[position])
	var reordered: BattleEvent = _card_event(BattleEvent.Kind.CARDS_REORDERED, session, state)
	reordered.gamble.cards = put_back
	var value: int = session.hand[choice.trick_pick]
	_finish(session, _value_row(card, value, session.odds.luck, state, ctx))
	return [reordered]


static func _finish(session: GambleSession, row: GambleOddsRow) -> void:
	session.damage = row.payout
	session.backfire = row.backfire
	session.tier = row.label
	session.due_step = row.due_step
	session.finished = true


## High Card or Card Trick paying on [param value] (value × multiplier, half up).
static func _value_row(
	card: CardGambleData, value: int, luck: int, state: BattleState, ctx: BattleContext
) -> GambleOddsRow:
	return _row_for_value(card, value, luck, _mult(state), _cap(state, ctx))


static func _row_for_value(
	card: CardGambleData, value: int, luck: int, payout_mult: float, backfire_cap: int
) -> GambleOddsRow:
	var due_step := GambleData.DueStep.NONE
	if value <= BOTTOM_TIER_MAX_VALUE:
		due_step = GambleData.DueStep.BOTTOM
	elif value == CARD_VALUE_MAX:
		due_step = GambleData.DueStep.TOP
	return GambleRules.outcome_row(
		StringName(str(value)), value, card.multiplier, 0, due_step, luck, payout_mult, backfire_cap
	)


## Nine Lives standing on [param total], or a forgiven bust standing on the previous total.
static func _stand_row(
	total: int, is_forgiven: bool, luck: int, state: BattleState, ctx: BattleContext
) -> GambleOddsRow:
	var label: StringName = StringName(("Forgiven %d" if is_forgiven else "Total %d") % total)
	return GambleRules.outcome_row(
		label, total, 1.0, 0, GambleData.DueStep.NONE, luck, _mult(state), _cap(state, ctx)
	)


## The row of one Nine Lives outcome code: bust, 21, a stand, or a forgiven stand (D19 Due).
static func _policy_row(
	card: CardGambleData, code: int, luck: int, payout_mult: float, backfire_cap: int
) -> GambleOddsRow:
	if code == CODE_BUST:
		return GambleRules.outcome_row(
			LABEL_BUST,
			0,
			1.0,
			card.bust_backfire,
			GambleData.DueStep.BOTTOM,
			luck,
			payout_mult,
			backfire_cap
		)
	if code == BLACKJACK_TOTAL:
		return GambleRules.outcome_row(
			LABEL_BLACKJACK,
			card.blackjack_damage,
			1.0,
			0,
			GambleData.DueStep.TOP,
			luck,
			payout_mult,
			backfire_cap
		)
	var label: StringName = StringName(("Total %d" if code >= STAND_AT else "Forgiven %d") % code)
	return GambleRules.outcome_row(
		label, code, 1.0, 0, GambleData.DueStep.NONE, luck, payout_mult, backfire_cap
	)


static func _single_draw_chances(deck: PackedInt32Array) -> Dictionary[int, float]:
	var counts: PackedInt32Array = visible_counts(deck)
	var total: float = float(_sum(counts))
	var chances: Dictionary[int, float] = {}
	for value: int in range(1, CARD_VALUE_MAX + 1):
		chances[value] = counts[value - 1] / total
	return chances


## Chance the best of three draws is each value. With fewer than three cards left, those cards come
## first and the rest from a fresh 20 (gap 2: the deck reshuffles all 20).
static func _best_of_three_chances(deck: PackedInt32Array) -> Dictionary[int, float]:
	var chances: Dictionary[int, float] = {}
	var below: float = 0.0
	for value: int in range(1, CARD_VALUE_MAX + 1):
		var at_most: float = _best_at_most(deck, value)
		chances[value] = at_most - below
		below = at_most
	return chances


static func _best_at_most(deck: PackedInt32Array, value: int) -> float:
	if deck.size() >= TRICK_DRAWS:
		var low: int = 0
		for card_value: int in deck:
			if card_value <= value:
				low += 1
		return _choose(low, TRICK_DRAWS) / _choose(deck.size(), TRICK_DRAWS)
	for card_value: int in deck:
		if card_value > value:
			return 0.0
	var fresh_draws: int = TRICK_DRAWS - deck.size()
	return _choose(COPIES_PER_VALUE * value, fresh_draws) / _choose(DECK_SIZE, fresh_draws)


## Nine Lives result chances when the player hits below STAND_AT (gamble-math.md).
static func _policy_chances(
	deck: PackedInt32Array, is_forgiveness_ready: bool, luck: int
) -> Dictionary[int, float]:
	var save: float = GambleRules.luck_chance(luck) if luck > 0 else 0.0
	var memo: Dictionary[int, Dictionary] = {}
	return _policy_from(0, visible_counts(deck), is_forgiveness_ready, save, memo)


static func _policy_from(
	total: int,
	counts: PackedInt32Array,
	is_forgiveness_ready: bool,
	save: float,
	memo: Dictionary[int, Dictionary]
) -> Dictionary[int, float]:
	var result: Dictionary[int, float] = {}
	if total >= STAND_AT:
		result[total] = 1.0
		return result
	var key: int = total
	for count: int in counts:
		key = key * COUNT_BASE + count
	if memo.has(key):
		result.assign(memo[key])
		return result
	var left: int = _sum(counts)
	var drawable: PackedInt32Array = counts if left > 0 else visible_counts(PackedInt32Array())
	left = _sum(drawable)
	for value: int in range(1, CARD_VALUE_MAX + 1):
		if drawable[value - 1] == 0:
			continue
		var chance: float = float(drawable[value - 1]) / left
		var next_total: int = total + value
		if next_total == BLACKJACK_TOTAL:
			_add(result, BLACKJACK_TOTAL, chance)
		elif next_total > BLACKJACK_TOTAL:
			_add(result, BLACKJACK_TOTAL, chance * save)
			_add(result, total if is_forgiveness_ready else CODE_BUST, chance * (1.0 - save))
		else:
			var rest: PackedInt32Array = drawable.duplicate()
			rest[value - 1] -= 1
			var after: Dictionary[int, float] = _policy_from(
				next_total, rest, is_forgiveness_ready, save, memo
			)
			for code: int in after:
				_add(result, code, chance * after[code])
	memo[key] = result
	return result


static func _add(chances: Dictionary[int, float], code: int, chance: float) -> void:
	chances[code] = chances.get(code, 0.0) + chance


static func _choose(n: int, k: int) -> float:
	if k < 0 or k > n:
		return 0.0
	var result: float = 1.0
	for index: int in k:
		result = result * (n - index) / (index + 1)
	return result


static func _sum(values: PackedInt32Array) -> int:
	var total: int = 0
	for value: int in values:
		total += value
	return total


static func _mult(state: BattleState) -> float:
	return GambleRules.status_mult(state)


static func _cap(state: BattleState, ctx: BattleContext) -> int:
	return GambleRules.backfire_cap(state, ctx)


## A card event with the hand, the visible counts, and the bust chance of the next hit.
static func _card_event(
	kind: BattleEvent.Kind, session: GambleSession, state: BattleState
) -> BattleEvent:
	var event := BattleEvent.new(kind)
	event.reason = session.family
	event.gamble = GambleEventData.new()
	event.gamble.cards = session.hand.duplicate()
	event.gamble.counts = visible_counts(state.deck)
	event.gamble.bust_chance = bust_chance(state.deck, hand_total(session.hand))
	return event


static func _awaiting_event(session: GambleSession, state: BattleState) -> BattleEvent:
	return _card_event(BattleEvent.Kind.GAMBLE_AWAITING_CHOICE, session, state)
