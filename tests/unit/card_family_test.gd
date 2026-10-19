extends TestCase
## Cards family (PRD §6.3, gamble-math.md, decisions D19) through BattleRules with the shipped
## Cards content. Decks are set top-last on the state; values are scripted through state.deck.

const NINE_LIVES_PATH: String = "res://src/content/moves/nine_lives.tres"
const HIGH_CARD_PATH: String = "res://src/content/moves/high_card.tres"
const CARD_TRICK_PATH: String = "res://src/content/moves/card_trick.tres"

## Loadout slots of the test kit, in the order _context() adds them.
const SLOT_NINE_LIVES: int = 0
const SLOT_HIGH_CARD: int = 1
const SLOT_CARD_TRICK: int = 2
## Backfire cap at the starting 60 max HP: floor(60 × 12%) = 7, above the 5 bust backfire.
const CAP: int = 7


func test_deck_is_two_of_each_1_to_10() -> void:
	var deck: PackedInt32Array = CardFamily.new_shuffled_deck(SeededRng.new("test:deck"))
	deck.sort()
	assert_eq(
		deck,
		PackedInt32Array([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10]),
		"sorted deck"
	)


func test_shuffle_is_seeded() -> void:
	var first: PackedInt32Array = CardFamily.new_shuffled_deck(SeededRng.new("seed-a"))
	assert_eq(CardFamily.new_shuffled_deck(SeededRng.new("seed-a")), first, "same seed")
	assert_true(CardFamily.new_shuffled_deck(SeededRng.new("seed-b")) != first, "other seed")


func test_draw_pops_top() -> void:
	var state := BattleState.new()
	state.deck = _deck([4, 9, 2])
	var session := GambleSession.new()
	var events: Array[BattleEvent] = CardFamily.draw_top(session, state, SeededRng.new("t"))
	assert_eq(events.size(), 1, "no shuffle")
	assert_eq(events[0].kind, BattleEvent.Kind.CARD_DRAWN, "drawn")
	assert_eq(events[0].amount, 4, "top card")
	assert_eq(state.deck, _deck([9, 2]), "deck shrinks by one")
	assert_eq(events[0].gamble.counts[3], 0, "no 4s left")


func test_empty_deck_reshuffles_full_20() -> void:
	var state := BattleState.new()
	var session := GambleSession.new()
	var events: Array[BattleEvent] = CardFamily.draw_top(session, state, SeededRng.new("t"))
	assert_eq(events[0].kind, BattleEvent.Kind.DECK_SHUFFLED, "shuffle first")
	assert_eq(events[0].amount, 20, "fresh 20")
	assert_eq(events[1].kind, BattleEvent.Kind.CARD_DRAWN, "then the draw")
	assert_eq(state.deck.size(), 19, "19 left")


func test_nine_lives_stand_deals_total() -> void:
	var fight: Fight = _fight([10, 7, 5, 5])
	_apply(fight, _use(SLOT_NINE_LIVES))
	var events: Array[BattleEvent] = _apply(fight, _call(GambleChoice.CardCall.STAND))
	assert_eq(_resolved(events).gamble.payout, 17, "stand at 17")
	assert_eq(_resolved(events).gamble.tier, &"Total 17", "tier")
	assert_eq(_due(events), -1, "a plain stand leaves Due")


func test_nine_lives_exactly_21_deals_30() -> void:
	var fight: Fight = _fight([10, 10, 1, 5])
	fight.ctx.due[&"cards"] = 2
	_apply(fight, _use(SLOT_NINE_LIVES))
	var events: Array[BattleEvent] = _apply(fight, _call(GambleChoice.CardCall.HIT))
	assert_eq(_resolved(events).gamble.payout, 30, "21 deals 30")
	assert_eq(_due(events), 0, "21 empties Due")


func test_nine_lives_first_bust_forgiven_stands_previous() -> void:
	var fight: Fight = _fight([9, 8, 6, 5])
	var events: Array[BattleEvent] = _apply(fight, _use(SLOT_NINE_LIVES))
	var drawn: Array[int] = []
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.CARD_DRAWN:
			drawn.append(event.amount)
	assert_eq(drawn, [9, 8], "opening hand")
	assert_eq(events.back().kind, BattleEvent.Kind.GAMBLE_AWAITING_CHOICE, "waits")
	events = _apply(fight, _call(GambleChoice.CardCall.HIT))
	assert_eq(events[0].kind, BattleEvent.Kind.CARD_DRAWN, "hit draws")
	assert_eq(events[0].amount, 6, "the 6")
	var resolved: BattleEvent = _resolved(events)
	assert_eq(resolved.gamble.payout, 17, "stands on 17")
	assert_true(resolved.gamble.forgiven, "forgiven flag")
	assert_eq(_index(events, BattleEvent.Kind.BACKFIRE), -1, "no backfire")
	assert_true(fight.state.forgiveness_used, "used up")


func test_nine_lives_second_bust_backfires_5() -> void:
	var fight: Fight = _fight([9, 8, 6, 5])
	fight.state.forgiveness_used = true
	_apply(fight, _use(SLOT_NINE_LIVES))
	var events: Array[BattleEvent] = _apply(fight, _call(GambleChoice.CardCall.HIT))
	assert_eq(_resolved(events).gamble.payout, 0, "bust deals 0")
	assert_eq(_resolved(events).gamble.tier, &"Bust", "tier")
	assert_eq(events[_index(events, BattleEvent.Kind.BACKFIRE)].amount, 5, "backfire 5")
	assert_eq(_due(events), 1, "bust adds a pip")


func test_bust_pct_matches_visible_deck() -> void:
	var deck := PackedInt32Array([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 7, 8, 8, 9, 10, 10])
	assert_almost_eq(CardFamily.bust_chance(deck, 15), 7.0 / 18.0, 0.001, "7 of 18 bust 15")
	assert_almost_eq(CardFamily.bust_chance(PackedInt32Array(), 15), 0.4, 1e-9, "empty = fresh")


func test_luck_save_replaces_bust_card() -> void:
	var fight: Fight = _fight([10, 5, 10, 5])
	fight.ctx.luck_bonus = 100
	_apply(fight, _use(SLOT_NINE_LIVES))
	var events: Array[BattleEvent] = _apply(fight, _call(GambleChoice.CardCall.HIT))
	var saved: BattleEvent = events[_index(events, BattleEvent.Kind.CARD_SAVED)]
	assert_eq(saved.amount, 6, "the 10 becomes a 6")
	assert_eq(saved.gamble.cards, PackedInt32Array([10, 5, 6]), "hand after the save")
	assert_eq(_resolved(events).gamble.payout, 30, "saved to 21")


func test_high_card_doubles_value() -> void:
	for value: int in [7, 1, 10]:
		var fight: Fight = _fight([value, 5])
		var events: Array[BattleEvent] = _apply(fight, _use(SLOT_HIGH_CARD))
		assert_eq(_resolved(events).gamble.payout, value * 2, "value %d" % value)
		assert_true(fight.state.pending == null, "no choice")


func test_card_trick_half_up() -> void:
	var picks: Dictionary[int, int] = {0: 18, 1: 13, 2: 10}
	for pick: int in picks:
		var fight: Fight = _fight([7, 5, 4, 3])
		_apply(fight, _use(SLOT_CARD_TRICK))
		var events: Array[BattleEvent] = _apply(fight, _trick(pick, _others(pick)))
		assert_eq(_resolved(events).gamble.payout, picks[pick], "pick %d" % pick)
	var card: CardGambleData = (load(CARD_TRICK_PATH) as MoveData).gamble as CardGambleData
	var ones: Array[GambleOddsRow] = CardFamily.odds(card, _deck([1, 1]), true, 0, 1.0, CAP)
	assert_eq(ones[0].payout, 3, "1 × 2.5 rounds half up to 3")


func test_card_trick_reorder_top_two() -> void:
	var fight: Fight = _fight([7, 5, 4, 3])
	_apply(fight, _use(SLOT_CARD_TRICK))
	var events: Array[BattleEvent] = _apply(fight, _trick(0, PackedInt32Array([1, 2])))
	var reordered: BattleEvent = events[_index(events, BattleEvent.Kind.CARDS_REORDERED)]
	assert_eq(reordered.gamble.cards, PackedInt32Array([5, 4]), "put back, top first")
	assert_eq(fight.state.deck, _deck([5, 4, 3]), "5 on top, then 4")


func test_card_trick_choice_must_cover_the_other_two() -> void:
	var fight: Fight = _fight([7, 5, 4, 3])
	_apply(fight, _use(SLOT_CARD_TRICK))
	for order: PackedInt32Array in [
		PackedInt32Array([0, 2]), PackedInt32Array([2, 2]), PackedInt32Array([1])
	]:
		var events: Array[BattleEvent] = _apply(fight, _trick(0, order))
		assert_eq(events[0].reason, &"invalid_choice", "order %s" % order)
	assert_true(fight.state.pending != null, "still waiting")


func test_odds_ev_match_gamble_math() -> void:
	var high: CardGambleData = (load(HIGH_CARD_PATH) as MoveData).gamble as CardGambleData
	var trick: CardGambleData = (load(CARD_TRICK_PATH) as MoveData).gamble as CardGambleData
	var nine: CardGambleData = (load(NINE_LIVES_PATH) as MoveData).gamble as CardGambleData
	var fresh := PackedInt32Array()
	assert_almost_eq(_ev(GambleRules.odds(high, 0, 1.0, CAP, fresh)), 11.0, 0.005, "high card")
	# gamble-math.md's 20.26 is before rounding; half-up per card (PRD §6.3) gives 389/19.
	assert_almost_eq(_ev(GambleRules.odds(trick, 0, 1.0, CAP, fresh)), 389.0 / 19.0, 1e-6, "trick")
	var strict: GambleOdds = GambleRules.odds(nine, 0, 1.0, CAP, fresh, false)
	assert_almost_eq(_ev(strict), 15.59, 0.01, "nine lives, no forgiveness")
	var backfire: float = 0.0
	for row: GambleOddsRow in strict.rows:
		backfire += row.probability * row.backfire
	assert_almost_eq(backfire, 0.91, 0.01, "backfire EV")
	var kind: GambleOdds = GambleRules.odds(nine, 0, 1.0, CAP, fresh, true)
	assert_almost_eq(_ev(kind), 18.14, 0.01, "nine lives with forgiveness")
	assert_eq(kind.stand_at, 16, "policy shown")
	assert_true(kind.is_forgiveness_ready, "forgiveness line shown")


func test_lucky_charm_takes_the_best_card_left() -> void:
	var fight: Fight = _fight([2, 9, 3, 1])
	fight.state.guarantee_top_tier = true
	var odds: GambleOdds = BattleRules.preview_move(fight.state, SLOT_HIGH_CARD, fight.ctx).odds
	var top: GambleOddsRow = odds.rows.back()
	assert_eq(top.label, &"9", "best card left is a 9")
	assert_almost_eq(top.probability, 1.0, 1e-9, "shown as certain")
	var events: Array[BattleEvent] = _apply(fight, _use(SLOT_HIGH_CARD))
	assert_eq(_resolved(events).gamble.payout, 18, "draws the 9")
	assert_eq(fight.state.deck, _deck([2, 3, 1]), "the 9 left the deck")


class Fight:
	extends RefCounted
	var ctx: BattleContext
	var state: BattleState


## A battle against a 200 HP enemy that attacks for 1, with the three card moves, MP topped up,
## and the deck set to [param top_first].
func _fight(top_first: Array[int]) -> Fight:
	var fight := Fight.new()
	fight.ctx = BattleContext.new()
	for path: String in [NINE_LIVES_PATH, HIGH_CARD_PATH, CARD_TRICK_PATH]:
		var move: MoveData = load(path) as MoveData
		fight.ctx.moves[move.id] = move
		var instance := MoveInstance.new()
		instance.move_id = move.id
		fight.ctx.loadout.append(instance)
	var intent := IntentData.new()
	intent.kind = IntentData.Kind.ATTACK
	intent.amount = 1
	var enemy := EnemyData.new()
	enemy.max_hp = 200
	enemy.suit = Suit.Type.CLUBS
	enemy.pattern.append(intent)
	fight.state = BattleRules.start(enemy, fight.ctx, RngSet.for_seed("test").battle).state
	fight.state.mp = 100
	fight.state.deck = _deck(top_first)
	return fight


## A deck from cards listed top first (the state keeps the top last).
func _deck(top_first: Array[int]) -> PackedInt32Array:
	var deck := PackedInt32Array(top_first)
	deck.reverse()
	return deck


func _apply(fight: Fight, action: PlayerAction) -> Array[BattleEvent]:
	return BattleRules.apply(fight.state, action, fight.ctx, RngSet.for_seed("test:cards"))


func _use(slot: int) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.USE_MOVE
	action.slot = slot
	return action


func _call(card_call: GambleChoice.CardCall) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.GAMBLE_CHOICE
	action.gamble_choice.cards = card_call
	return action


func _trick(pick: int, order: PackedInt32Array) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.GAMBLE_CHOICE
	action.gamble_choice.trick_pick = pick
	action.gamble_choice.trick_order = order
	return action


func _others(pick: int) -> PackedInt32Array:
	var others := PackedInt32Array()
	for index: int in 3:
		if index != pick:
			others.append(index)
	return others


func _ev(table: GambleOdds) -> float:
	return table.expected_damage()


func _resolved(events: Array[BattleEvent]) -> BattleEvent:
	return events[_index(events, BattleEvent.Kind.GAMBLE_RESOLVED)]


## The new Due pips of the first DUE_CHANGED, or -1 when Due didn't change.
func _due(events: Array[BattleEvent]) -> int:
	var index: int = _index(events, BattleEvent.Kind.DUE_CHANGED)
	return events[index].amount if index >= 0 else -1


func _index(events: Array[BattleEvent], kind: BattleEvent.Kind) -> int:
	for index: int in events.size():
		if events[index].kind == kind:
			return index
	return -1
