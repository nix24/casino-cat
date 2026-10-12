extends TestCase
## Run flow through nodes and battle rewards (T011, PRD §4.5, §9.2, §10.6, D15, D30, D31).

const FIRST_POOL: Array[StringName] = [&"sewer_rat", &"pickpocket_pigeon", &"junkyard_pup"]


func test_heal_10_percent_capped() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	RunRules.finish_battle(run, _won(db, 41), db, [], SeededRng.new("r"))
	assert_eq(run.hp, 47, "41 + 6")
	RunRules.finish_battle(run, _won(db, 58), db, [], SeededRng.new("r"))
	assert_eq(run.hp, 60, "58 + 6 capped at 60")


func test_heal_rounds_half_up() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	run.max_hp = 65
	RunRules.finish_battle(run, _won(db, 30), db, [], SeededRng.new("r"))
	assert_eq(run.hp, 37, "6.5 rounds to 7 (D15)")


func test_finish_battle_worked_example() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	var reward: RunRules.Reward = RunRules.finish_battle(
		run, _won(db, 41), db, [], SeededRng.new("r")
	)
	assert_eq(run.node_state, RunState.NodeState.REWARD)
	assert_true(reward.purrls >= 12 and reward.purrls <= 18, "act 1 Purrls")
	assert_eq(run.purrls, 50, "Purrls wait for take_reward")
	assert_true(not reward.elite)
	assert_eq(run.node_payload, reward.to_payload(), "the reward is saved for a reload")
	var back: RunRules.Reward = RunRules.Reward.from_payload(run.node_payload, db)
	assert_true(back != null and back.to_payload() == reward.to_payload(), "payload round trip")
	assert_eq(run.stats.damage_taken, 19, "60 - 41")


func test_take_move_fills_equipped_then_bag() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	var reward: RunRules.Reward = _reward(db, 15)
	assert_true(RunRules.take_reward(run, reward, RunRules.RewardChoice.move(0), db.tuning()))
	assert_eq(run.equipped.size(), 4)
	assert_eq(run.bag.size(), 1)
	assert_eq(run.bag[0].move_id, &"loaded_paws")
	assert_eq(run.purrls, 65, "50 + 15")
	assert_eq(run.node_state, RunState.NodeState.MAP)
	run.equipped.remove_at(3)
	assert_true(RunRules.take_reward(run, reward, RunRules.RewardChoice.move(0), db.tuning()))
	assert_eq(run.equipped.size(), 4, "a free equipped slot fills first")


func test_take_move_fills_an_empty_slot() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	run.equipped[2].move_id = &""
	assert_true(
		RunRules.take_reward(run, _reward(db, 0), RunRules.RewardChoice.move(0), db.tuning())
	)
	assert_eq(run.equipped[2].move_id, &"loaded_paws", "the released slot (D33)")
	assert_eq(run.bag.size(), 0)


func test_take_move_rejects_when_full() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	for _slot: int in 4:
		var move := MoveInstance.new()
		move.move_id = &"swipe"
		run.bag.append(move)
	run.node_state = RunState.NodeState.REWARD
	var before: Dictionary = run.to_dict()
	assert_true(
		not RunRules.take_reward(run, _reward(db, 15), RunRules.RewardChoice.move(0), db.tuning())
	)
	assert_eq(run.to_dict(), before, "nothing changes on reject")


func test_skip_gives_10_purrls() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	assert_true(
		RunRules.take_reward(run, _reward(db, 16), RunRules.RewardChoice.skip(), db.tuning())
	)
	assert_eq(run.purrls, 50 + 16 + 10)
	assert_eq(run.equipped.size(), 4)
	assert_eq(run.bag.size(), 0)


func test_enter_node_first_battle_pool_at_row1() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	var rng := SeededRng.new("first")
	for _try: int in 50:
		var entry: RunRules.NodeEntry = RunRules.enter_node(
			run, MapNode.new(1, 3, MapNode.Type.BATTLE), db, rng
		)
		assert_true(FIRST_POOL.has(entry.enemy_id), "first battle %s" % entry.enemy_id)
		assert_eq(entry.position, Vector2i(1, 3))


func test_enter_node_types_map_to_node_state() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	var expected: Dictionary[MapNode.Type, RunState.NodeState] = {
		MapNode.Type.BATTLE: RunState.NodeState.BATTLE,
		MapNode.Type.ELITE: RunState.NodeState.BATTLE,
		MapNode.Type.BOSS: RunState.NodeState.BATTLE,
		MapNode.Type.SHOP: RunState.NodeState.SHOP,
		MapNode.Type.REST: RunState.NodeState.REST,
		MapNode.Type.EVENT: RunState.NodeState.EVENT,
		MapNode.Type.TREASURE: RunState.NodeState.TREASURE,
	}
	for node_type: MapNode.Type in expected:
		var node := MapNode.new(5, 2, node_type)
		node.payload["elite_id"] = "bouncer_bulldog"
		var entry: RunRules.NodeEntry = RunRules.enter_node(run, node, db, SeededRng.new("t"))
		assert_eq(entry.node_state, expected[node_type], MapNode.type_name(node_type))
		if node_type == MapNode.Type.ELITE:
			assert_eq(entry.enemy_id, &"bouncer_bulldog", "elite from the payload (D31)")
		if node_type in [MapNode.Type.SHOP, MapNode.Type.REST, MapNode.Type.EVENT]:
			assert_eq(entry.enemy_id, &"", "no enemy")


func test_battle_starts_at_run_hp() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("RUN-1", db.tuning())
	run.hp = 41
	var ctx: BattleContext = BattleContext.from_run(run, db)
	var opening: BattleStart = BattleRules.start(db.enemy(&"sewer_rat"), ctx, SeededRng.new("b"))
	assert_eq(opening.state.cat.hp, 41)
	assert_eq(opening.state.cat.max_hp, 60)


func _won(db: ContentDb, cat_hp: int) -> BattleState:
	var state := BattleState.new()
	state.enemy_data = db.enemy(&"sewer_rat")
	state.enemy.max_hp = state.enemy_data.max_hp
	state.enemy.hp = 0
	state.cat.max_hp = 60
	state.cat.hp = cat_hp
	state.outcome = BattleState.Outcome.WON
	return state


func _reward(db: ContentDb, purrls: int) -> RunRules.Reward:
	var reward := RunRules.Reward.new()
	reward.purrls = purrls
	reward.move_offers = [db.move(&"loaded_paws")]
	return reward
