extends TestCase
## Act 1 enemies and elites (T018, PRD §9.1-9.3, content-registry).

const EXPECTED: Dictionary[StringName, Array] = {
	&"alley_possum": [EnemyData.Tier.NORMAL, Suit.Type.HEARTS, 26],
	&"traffic_cone_crow": [EnemyData.Tier.NORMAL, Suit.Type.DIAMONDS, 24],
	&"raccoon_lookout": [EnemyData.Tier.NORMAL, Suit.Type.DIAMONDS, 25],
	&"gutter_slug": [EnemyData.Tier.NORMAL, Suit.Type.CLUBS, 30],
	&"bouncer_bulldog": [EnemyData.Tier.ELITE, Suit.Type.SPADES, 60],
	&"card_sharp_weasel": [EnemyData.Tier.ELITE, Suit.Type.DIAMONDS, 55],
}
const SLOT_SCRATCH: int = 0
const SLOT_CURL_UP: int = 3


func test_six_enemies_match_registry() -> void:
	var db: ContentDb = ContentDb.load_all()
	for id: StringName in EXPECTED:
		var enemy: EnemyData = db.enemy(id)
		assert_true(enemy != null, String(id))
		if enemy == null:
			continue
		assert_eq([enemy.tier, enemy.suit, enemy.max_hp], EXPECTED[id], String(id))
		assert_eq(enemy.act, 1, String(id))
		assert_true(not enemy.first_battle_pool, String(id))
	assert_eq(db.enemies_for(1, EnemyData.Tier.NORMAL).size(), 7)
	assert_eq(db.enemies_for(1, EnemyData.Tier.ELITE).size(), 2)


func test_bulldog_loop_12_12_7x2() -> void:
	var fight: Fight = Fight.new(&"bouncer_bulldog")
	var seen: Array[String] = []
	for _turn: int in 5:
		var intent: IntentData = fight.state.next_intent
		seen.append("%s %d×%d" % [IntentData.Kind.keys()[intent.kind], intent.amount, intent.hits])
		fight.move(SLOT_CURL_UP)
	assert_eq(seen, ["ATTACK 12×1", "GUARD 15×1", "ATTACK 12×1", "MULTI_ATTACK 7×2", "ATTACK 12×1"])


func test_bulldog_multi_attack_hits_twice_7() -> void:
	var fight: Fight = Fight.new(&"bouncer_bulldog")
	fight.state.intent_index = 3
	fight.state.next_intent = fight.state.enemy_data.pattern[3]
	fight.state.cat.suit = Suit.Type.CLUBS
	fight.state.cat.shield = 0
	var hits: Array[Array] = []
	var events: Array[BattleEvent] = fight.move(SLOT_CURL_UP)
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == BattleEvent.Actor.ENEMY:
			hits.append([event.amount, event.absorbed])
	# Curl Up gives 10 shield first; ♣ cat vs ♠ dog is neutral.
	assert_eq(hits, [[7, 7], [7, 3]])


func test_possum_override_fires_once_below_50() -> void:
	var fight: Fight = Fight.new(&"alley_possum")
	fight.state.enemy.hp = 12
	var events: Array[BattleEvent] = fight.move(SLOT_CURL_UP)
	assert_eq(_enemy_heals(events), [8], "HEAL 8 at 12/26")
	assert_eq(fight.state.enemy.hp, 20)
	fight.state.enemy.hp = 10
	assert_eq(_enemy_heals(fight.move(SLOT_CURL_UP)), [], "once")


func test_possum_no_override_at_exactly_50_percent() -> void:
	var fight: Fight = Fight.new(&"alley_possum")
	fight.state.enemy.hp = 13
	assert_eq(_enemy_heals(fight.move(SLOT_CURL_UP)), [])


func test_possum_pattern_index_unchanged_by_override() -> void:
	var fight: Fight = Fight.new(&"alley_possum")
	fight.state.enemy.hp = 12
	fight.move(SLOT_CURL_UP)
	assert_eq(fight.state.next_intent.kind, IntentData.Kind.GUARD)
	assert_eq(fight.state.next_intent.amount, 10)


func test_card_sharp_cheat_sets_counter_suit_for_one_turn() -> void:
	var fight: Fight = Fight.new(&"card_sharp_weasel")
	fight.state.enemy.hp = 999
	fight.state.intent_index = 2
	fight.state.next_intent = fight.state.enemy_data.pattern[2]
	fight.state.cat.suit = Suit.Type.HEARTS
	fight.ctx.tuning = fight.ctx.tuning.duplicate()
	fight.ctx.tuning.type_shift_enabled = false
	var events: Array[BattleEvent] = fight.move(SLOT_CURL_UP)
	var shifts: Array[BattleEvent] = events.filter(
		func(event: BattleEvent) -> bool:
			return (
				event.kind == BattleEvent.Kind.SUIT_SHIFTED
				and event.actor == BattleEvent.Actor.ENEMY
			)
	)
	assert_eq(shifts.size(), 1)
	assert_eq([shifts[0].suit_from, shifts[0].suit_to], [Suit.Type.DIAMONDS, Suit.Type.SPADES])
	assert_eq(fight.state.enemy.suit, Suit.Type.SPADES, "♠ beats the ♥ cat for a turn")
	fight.move(SLOT_CURL_UP)
	assert_eq(fight.state.enemy.suit, Suit.Type.DIAMONDS, "back after one turn")


func test_card_sharp_cheat_does_nothing_against_clubs() -> void:
	var fight: Fight = Fight.new(&"card_sharp_weasel")
	fight.state.next_intent = fight.state.enemy_data.pattern[2]
	fight.state.cat.suit = Suit.Type.CLUBS
	fight.move(SLOT_CURL_UP)
	assert_eq(fight.state.enemy.suit, Suit.Type.DIAMONDS, "nothing beats ♣")


func test_card_sharp_pattern_loop_three() -> void:
	var fight: Fight = Fight.new(&"card_sharp_weasel")
	fight.state.enemy.hp = 999
	var kinds: Array[IntentData.Kind] = []
	for _turn: int in 4:
		kinds.append(fight.state.next_intent.kind)
		fight.move(SLOT_CURL_UP)
	assert_eq(
		kinds,
		[
			IntentData.Kind.DEBUFF,
			IntentData.Kind.ATTACK,
			IntentData.Kind.SPECIAL,
			IntentData.Kind.DEBUFF,
		]
	)


func test_crow_buff_adds_flat_damage() -> void:
	var fight: Fight = Fight.new(&"traffic_cone_crow")
	fight.state.next_intent = fight.state.enemy_data.pattern[1]
	fight.state.intent_index = 1
	fight.move(SLOT_CURL_UP)
	assert_eq(fight.state.enemy.flat_damage_bonus, 2)


func test_first_battle_pool_only_three_starters() -> void:
	var ids: Array[StringName] = []
	for enemy: EnemyData in ContentDb.load_all().enemies_for(1, EnemyData.Tier.NORMAL):
		if enemy.first_battle_pool:
			ids.append(enemy.id)
	assert_eq(ids, [&"junkyard_pup", &"pickpocket_pigeon", &"sewer_rat"])


func _enemy_heals(events: Array[BattleEvent]) -> Array[int]:
	var heals: Array[int] = []
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.HEALED and event.target == BattleEvent.Actor.ENEMY:
			heals.append(event.amount)
	return heals


## A battle against [param enemy_id] with the starter kit; the cat can't die.
class Fight:
	extends RefCounted
	var ctx: BattleContext
	var state: BattleState
	var rngs: RngSet = RngSet.for_seed("ENEMIES")

	func _init(enemy_id: StringName) -> void:
		var db: ContentDb = ContentDb.load_all()
		ctx = BattleContext.from_run(RunState.start("ENEMIES", db.tuning()), db)
		ctx.god_mode = true
		state = BattleRules.start(db.enemy(enemy_id), ctx, rngs.battle).state

	func move(slot: int) -> Array[BattleEvent]:
		var action := PlayerAction.new()
		action.slot = slot
		return BattleRules.apply(state, action, ctx, rngs)
