extends TestCase
## Big Lou's phases and Dumpster Dive (T019, PRD §9.4, D25).

const SLOT_SCRATCH: int = 0
const SLOT_CURL_UP: int = 3


func test_big_lou_matches_prd() -> void:
	var lou: EnemyData = ContentDb.load_all().enemy(&"big_lou")
	assert_eq(
		[lou.act, lou.tier, lou.max_hp, lou.suit], [1, EnemyData.Tier.BOSS, 120, Suit.Type.SPADES]
	)
	assert_eq(lou.phases.size(), 2)
	assert_eq(lou.phases[1].suit, Suit.Type.HEARTS)
	assert_eq(lou.phases[1].hp_at_or_below_pct, 50)
	assert_eq(
		_kinds(lou.phases[0].pattern), ["ATTACK 10", "GUARD 12", "MULTI_ATTACK 6", "STEAL_MP 15"]
	)
	assert_eq(_kinds(lou.phases[1].pattern), ["HEAL 10", "ATTACK 14", "DEBUFF 0", "ATTACK 14"])


func test_phase_two_at_exactly_50_percent() -> void:
	var fight: Fight = Fight.new()
	fight.state.enemy.hp = 60
	fight.move(SLOT_CURL_UP)
	assert_eq(fight.state.phase, 1)
	var other: Fight = Fight.new()
	other.state.enemy.hp = 61
	other.move(SLOT_CURL_UP)
	assert_eq(other.state.phase, 0)


func test_phase_change_before_enemy_acts() -> void:
	var fight: Fight = Fight.new()
	fight.state.enemy.hp = 65
	var kinds: Array[BattleEvent.Kind] = []
	var heal_after: int = -1
	for event: BattleEvent in fight.move(SLOT_SCRATCH):
		kinds.append(event.kind)
		if event.kind == BattleEvent.Kind.HEALED and event.target == BattleEvent.Actor.ENEMY:
			heal_after = event.value_after
	var phase_at: int = kinds.find(BattleEvent.Kind.PHASE_CHANGED)
	assert_true(phase_at >= 0, "phase changed")
	assert_true(phase_at < kinds.find(BattleEvent.Kind.ENEMY_ACTED), "before the enemy acts")
	assert_eq(fight.state.enemy.suit, Suit.Type.HEARTS)
	assert_eq(heal_after, 59 + 10, "Scratch 6 → 59, then HEAL 10")


func test_phase_two_pattern_starts_with_heal_then_continues() -> void:
	var fight: Fight = Fight.new()
	fight.state.enemy.hp = 60
	fight.move(SLOT_CURL_UP)
	assert_eq(fight.state.next_intent.kind, IntentData.Kind.ATTACK, "after HEAL 10 comes ATTACK 14")
	assert_eq(fight.state.next_intent.amount, 14)


func test_phase_never_reverts() -> void:
	var fight: Fight = Fight.new()
	fight.state.enemy.hp = 60
	fight.move(SLOT_CURL_UP)
	fight.state.enemy.hp = 120
	fight.move(SLOT_CURL_UP)
	assert_eq(fight.state.phase, 1)


func test_no_phase_change_when_move_wins() -> void:
	var fight: Fight = Fight.new()
	fight.state.enemy.hp = 3
	var events: Array[BattleEvent] = fight.move(SLOT_SCRATCH)
	var kinds: Array[BattleEvent.Kind] = []
	for event: BattleEvent in events:
		kinds.append(event.kind)
	assert_true(kinds.has(BattleEvent.Kind.BATTLE_WON))
	assert_true(not kinds.has(BattleEvent.Kind.PHASE_CHANGED))


func test_dumpster_dive_find_chance_30_percent_when_slot_free() -> void:
	var db: ContentDb = ContentDb.load_all()
	var dive: MoveData = db.move(&"dumpster_dive")
	assert_eq(
		[dive.rarity, dive.suit, dive.base_damage, dive.mp_cost],
		[MoveData.Rarity.SIGNATURE, Suit.Type.SPADES, 12, 0]
	)
	var found: int = 0
	var rngs := RngSet.for_seed("DIVE")
	for trial: int in 10_000:
		var fight: Fight = Fight.new([&"dumpster_dive"], rngs)
		fight.state.enemy.hp = 999
		for event: BattleEvent in fight.move(0):
			if event.kind == BattleEvent.Kind.ITEM_FOUND:
				found += 1
				assert_true(db.item(event.reason) != null, "a real item")
				assert_eq(fight.ctx.pouch[event.amount], event.reason, "into the free slot")
	assert_almost_eq(found / 10_000.0, 0.30, 0.01, "30% find")


func test_dumpster_dive_no_find_when_pouch_full() -> void:
	var rngs := RngSet.for_seed("DIVE")
	var fight: Fight = Fight.new([&"dumpster_dive"], rngs)
	fight.ctx.pouch = [&"spare_die", &"spare_die", &"spare_die"]
	fight.state.enemy.hp = 999
	var before: int = rngs.battle.get_state()
	for event: BattleEvent in fight.move(0):
		assert_true(event.kind != BattleEvent.Kind.ITEM_FOUND)
	assert_eq(rngs.battle.get_state(), before, "no roll consumed")


func test_dumpster_dive_hits_for_12() -> void:
	var fight: Fight = Fight.new([&"dumpster_dive"])
	var hits: Array[int] = []
	for event: BattleEvent in fight.move(0):
		if event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == BattleEvent.Actor.CAT:
			hits.append(event.amount)
	assert_eq(hits, [12], "♠ into ♠ Lou is neutral")


func _kinds(pattern: Array[IntentData]) -> Array[String]:
	var out: Array[String] = []
	for intent: IntentData in pattern:
		out.append("%s %d" % [IntentData.Kind.keys()[intent.kind], intent.amount])
	return out


## Big Lou against the starter kit (or [param equipped]); the cat can't die.
class Fight:
	extends RefCounted
	var ctx: BattleContext
	var state: BattleState
	var rngs: RngSet

	func _init(equipped: Array[StringName] = [], with_rngs: RngSet = null) -> void:
		rngs = with_rngs if with_rngs != null else RngSet.for_seed("LOU")
		var db: ContentDb = ContentDb.load_all()
		var run: RunState = RunState.start("LOU", db.tuning())
		if not equipped.is_empty():
			run.equipped.clear()
			for move_id: StringName in equipped:
				var instance := MoveInstance.new()
				instance.move_id = move_id
				run.equipped.append(instance)
		ctx = BattleContext.from_run(run, db)
		ctx.god_mode = true
		state = BattleRules.start(db.enemy(&"big_lou"), ctx, rngs.battle).state

	func move(slot: int) -> Array[BattleEvent]:
		var action := PlayerAction.new()
		action.slot = slot
		return BattleRules.apply(state, action, ctx, rngs)
