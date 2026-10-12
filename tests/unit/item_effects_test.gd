extends TestCase
## Pouch items in battle (T014, PRD §8.3, D34). Each test fights the ♠ Sewer Rat unless it says
## otherwise.

const SLOT_SCRATCH: int = 0
const SLOT_PAW_ROLL: int = 2


func test_fish_snack_heals_15() -> void:
	var fight: Fight = _fight([&"fish_snack"])
	fight.state.cat.hp = 40
	var events: Array[BattleEvent] = fight.item(0)
	assert_eq(fight.state.cat.hp, 55)
	assert_eq(_amounts(events, BattleEvent.Kind.HEALED), [15])
	assert_eq(events[0].kind, BattleEvent.Kind.ITEM_USED)
	assert_eq(events[0].reason, &"fish_snack")
	assert_eq(fight.ctx.pouch[0], &"", "the slot empties")


func test_fish_snack_heal_clipped_at_max() -> void:
	var fight: Fight = _fight([&"fish_snack"])
	fight.state.cat.hp = 58
	assert_eq(_amounts(fight.item(0), BattleEvent.Kind.HEALED), [2])
	assert_eq(fight.state.cat.hp, 60)


func test_catnip_tea_gives_40_mp_capped_at_100() -> void:
	var fight: Fight = _fight([&"catnip_tea"])
	fight.state.mp = 80
	assert_eq(_amounts(fight.item(0), BattleEvent.Kind.MP_CHANGED), [20])
	assert_eq(fight.state.mp, 100)


func test_milk_saucer_heals_8_and_gives_15_mp() -> void:
	var fight: Fight = _fight([&"milk_saucer"])
	fight.state.cat.hp = 52
	fight.state.mp = 30
	var events: Array[BattleEvent] = fight.item(0)
	var kinds: Array[BattleEvent.Kind] = []
	for event: BattleEvent in events:
		kinds.append(event.kind)
	assert_eq(
		kinds, [BattleEvent.Kind.ITEM_USED, BattleEvent.Kind.HEALED, BattleEvent.Kind.MP_CHANGED]
	)
	assert_eq(events[1].value_after, 60)
	assert_eq(events[2].amount, 15)
	assert_eq(events[2].value_after, 45)
	assert_eq(events[2].reason, &"item")


func test_lucky_charm_sets_guarantee_flag() -> void:
	var fight: Fight = _fight([&"lucky_charm"])
	fight.item(0)
	assert_true(fight.state.guarantee_top_tier)
	var odds: GambleOdds = BattleRules.preview_move(fight.state, SLOT_PAW_ROLL, fight.ctx).odds
	assert_eq(
		odds.rows.filter(func(row: GambleOddsRow) -> bool: return row.probability > 0).size(), 1
	)
	fight.state.mp = 100
	fight.move(SLOT_PAW_ROLL)
	var events: Array[BattleEvent] = fight.keep()
	var tiers: Array[StringName] = []
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.GAMBLE_RESOLVED:
			tiers.append(event.gamble.tier)
	assert_eq(tiers, [&"Boxcars"], "Paw Roll's top tier")
	assert_true(not fight.state.guarantee_top_tier, "used up")


func test_hairball_remedy_cleanses_and_shields_5() -> void:
	var fight: Fight = _fight([&"hairball_remedy"])
	fight.state.cat.statuses = {&"weak": 2, &"rattled": 1}
	var events: Array[BattleEvent] = fight.item(0)
	assert_eq(_count(events, BattleEvent.Kind.STATUS_CLEANSED), 2)
	assert_eq(fight.state.cat.statuses.size(), 0)
	assert_eq(fight.state.cat.shield, 5)


func test_spare_die_adds_one_reroll() -> void:
	var fight: Fight = _fight([&"spare_die"])
	var before: int = fight.state.rerolls
	assert_eq(_amounts(fight.item(0), BattleEvent.Kind.REROLLS_CHANGED), [before + 1])
	assert_eq(fight.state.rerolls, before + 1)


func test_sardine_tin_adds_8_to_next_move_only() -> void:
	var fight: Fight = _fight([&"sardine_tin"])
	fight.state.enemy.suit = Suit.Type.CLUBS
	fight.state.enemy.hp = 999
	fight.item(0)
	assert_eq(BattleRules.preview_move(fight.state, SLOT_SCRATCH, fight.ctx).damage, 14)
	assert_eq(_cat_hits(fight.move(SLOT_SCRATCH)), [14], "6 + 8 into neutral ♣")
	assert_eq(_cat_hits(fight.move(SLOT_SCRATCH)), [6], "gone after one move")


func test_ball_of_yarn_halves_next_attack_rounded_down() -> void:
	var fight: Fight = _fight([&"ball_of_yarn"])
	var attack := IntentData.new()
	attack.kind = IntentData.Kind.ATTACK
	attack.amount = 15
	attack.hits = 1
	fight.state.next_intent = attack
	fight.state.enemy.suit = Suit.Type.CLUBS
	fight.item(0)
	var hits: Array[int] = []
	for event: BattleEvent in fight.move(SLOT_SCRATCH):
		if event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == BattleEvent.Actor.ENEMY:
			hits.append(event.amount)
	assert_eq(hits, [7], "15 × 50% = 7.5 → 7")


func test_laser_pointer_sets_suit_for_two_turns() -> void:
	var fight: Fight = _fight([&"laser_pointer"])
	fight.state.enemy.hp = 999
	var events: Array[BattleEvent] = fight.item(0, Suit.Type.HEARTS)
	var shifted: Array[BattleEvent] = events.filter(
		func(event: BattleEvent) -> bool: return event.kind == BattleEvent.Kind.SUIT_SHIFTED
	)
	assert_eq(shifted.size(), 1)
	assert_eq(shifted[0].actor, BattleEvent.Actor.ENEMY)
	assert_eq(shifted[0].suit_to, Suit.Type.HEARTS)
	assert_eq(fight.state.enemy.suit, Suit.Type.HEARTS)
	assert_eq(_count(fight.move(SLOT_SCRATCH), BattleEvent.Kind.SUIT_OVERRIDE_EXPIRED), 0)
	assert_eq(fight.state.enemy.suit, Suit.Type.HEARTS, "still turn 2")
	assert_eq(_count(fight.move(SLOT_SCRATCH), BattleEvent.Kind.SUIT_OVERRIDE_EXPIRED), 1)
	assert_eq(fight.state.enemy.suit, Suit.Type.SPADES, "back to ♠ after 2 turns")


func test_laser_pointer_rejects_a_bad_suit() -> void:
	var fight: Fight = _fight([&"laser_pointer"])
	assert_eq(_rejection(fight.item(0, 7)), &"bad_suit")


func test_smoke_bomb_flees_normal_battle() -> void:
	var fight: Fight = _fight([&"smoke_bomb"])
	var events: Array[BattleEvent] = fight.item(0)
	assert_eq(fight.state.outcome, BattleState.Outcome.FLED)
	assert_eq(_count(events, BattleEvent.Kind.FLED), 1)
	assert_eq(_count(events, BattleEvent.Kind.BATTLE_WON), 0)


func test_smoke_bomb_rejected_on_elite_and_boss() -> void:
	for tier: EnemyData.Tier in [EnemyData.Tier.ELITE, EnemyData.Tier.BOSS]:
		var fight: Fight = _fight([&"smoke_bomb"])
		var enemy: EnemyData = fight.state.enemy_data.duplicate()
		enemy.tier = tier
		fight.state.enemy_data = enemy
		assert_eq(_rejection(fight.item(0)), &"smoke_bomb_not_normal")
		assert_eq(fight.ctx.pouch[0], &"smoke_bomb", "kept")


func test_one_item_per_turn() -> void:
	var fight: Fight = _fight([&"fish_snack", &"catnip_tea"])
	fight.item(0)
	var second: Array[BattleEvent] = fight.item(1)
	assert_eq(second.size(), 1)
	assert_eq(_rejection(second), &"item_already_used")
	fight.move(SLOT_SCRATCH)
	assert_eq(fight.item(1)[0].kind, BattleEvent.Kind.ITEM_USED, "allowed next turn")


func test_empty_slot_and_pending_gamble_rejected() -> void:
	var fight: Fight = _fight([&"fish_snack"])
	assert_eq(_rejection(fight.item(1)), &"empty_slot")
	fight.state.mp = 100
	fight.move(SLOT_PAW_ROLL)
	assert_eq(_rejection(fight.item(0)), &"pending")


func test_item_does_not_end_turn() -> void:
	var fight: Fight = _fight([&"fish_snack"])
	var turn: int = fight.state.turn
	var events: Array[BattleEvent] = fight.item(0)
	assert_eq(_count(events, BattleEvent.Kind.TURN_STARTED), 0)
	assert_eq(_count(events, BattleEvent.Kind.ENEMY_ACTED), 0)
	assert_eq(fight.state.turn, turn)


func test_item_drop_picks_uniformly_and_fills_the_pouch() -> void:
	var db: ContentDb = ContentDb.load_all()
	var rng := SeededRng.new("ITEMS")
	var counts: Dictionary[StringName, int] = {}
	for _draw: int in 10_000:
		var item_id: StringName = RewardRules.drop_item(db.all_items(), rng)
		counts[item_id] = counts.get(item_id, 0) + 1
	assert_eq(counts.size(), 10)
	for item_id: StringName in counts:
		assert_almost_eq(counts[item_id] / 10_000.0, 0.1, 0.02, String(item_id))
	var run: RunState = RunState.start("ITEMS", db.tuning())
	var reward := RunRules.Reward.new()
	reward.item_id = &"fish_snack"
	var choice: RunRules.RewardChoice = RunRules.RewardChoice.skip()
	choice.item_slot = 0
	assert_true(RunRules.take_reward(run, reward, choice, db.tuning()))
	assert_eq(run.pouch, [&"fish_snack", &"", &""])
	run.pouch = [&"spare_die", &"spare_die", &"spare_die"]
	choice.item_slot = 1
	RunRules.take_reward(run, reward, choice, db.tuning())
	assert_eq(run.pouch, [&"spare_die", &"fish_snack", &"spare_die"], "replaced slot 1")
	choice.item_slot = -1
	RunRules.take_reward(run, reward, choice, db.tuning())
	assert_eq(run.pouch, [&"spare_die", &"fish_snack", &"spare_die"], "left behind")


func _fight(pouch: Array[StringName]) -> Fight:
	return Fight.new(pouch)


func _amounts(events: Array[BattleEvent], kind: BattleEvent.Kind) -> Array[int]:
	var amounts: Array[int] = []
	for event: BattleEvent in events:
		if event.kind == kind:
			amounts.append(event.amount)
	return amounts


func _count(events: Array[BattleEvent], kind: BattleEvent.Kind) -> int:
	return _amounts(events, kind).size()


func _rejection(events: Array[BattleEvent]) -> StringName:
	if events.size() == 1 and events[0].kind == BattleEvent.Kind.ACTION_REJECTED:
		return events[0].reason
	return &""


func _cat_hits(events: Array[BattleEvent]) -> Array[int]:
	var hits: Array[int] = []
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == BattleEvent.Actor.CAT:
			hits.append(event.amount)
	return hits


## A battle against the Sewer Rat with [param pouch] in the first slots.
class Fight:
	extends RefCounted
	var ctx: BattleContext
	var state: BattleState
	var rngs: RngSet = RngSet.for_seed("ITEMS")

	func _init(pouch: Array[StringName]) -> void:
		var db: ContentDb = ContentDb.load_all()
		var run: RunState = RunState.start("ITEMS", db.tuning())
		for slot: int in pouch.size():
			run.pouch[slot] = pouch[slot]
		ctx = BattleContext.from_run(run, db)
		state = BattleRules.start(db.enemy(&"sewer_rat"), ctx, rngs.battle).state

	func item(slot: int, suit: int = 0) -> Array[BattleEvent]:
		var action := PlayerAction.new()
		action.kind = PlayerAction.Kind.USE_ITEM
		action.pouch_slot = slot
		action.choice = suit
		return BattleRules.apply(state, action, ctx, rngs)

	func move(slot: int) -> Array[BattleEvent]:
		var action := PlayerAction.new()
		action.kind = PlayerAction.Kind.USE_MOVE
		action.slot = slot
		return BattleRules.apply(state, action, ctx, rngs)

	func keep() -> Array[BattleEvent]:
		var action := PlayerAction.new()
		action.kind = PlayerAction.Kind.GAMBLE_CHOICE
		return BattleRules.apply(state, action, ctx, rngs)
