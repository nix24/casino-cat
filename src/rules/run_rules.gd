class_name RunRules
extends RefCounted
## Moves a run between map nodes (arch §5 state machine). Pure: the caller passes the content
## and the right RNG stream, and Game swaps scenes and saves.

## The first battle of every run comes from this pool's enemies (PRD §9.2): act 1, row 1.
const FIRST_BATTLE_ACT: int = 1
const FIRST_BATTLE_ROW: int = 1


## Where entering a node leads: the screen state, the enemy to fight (empty when none), and the
## cat's new map position.
class NodeEntry:
	extends RefCounted
	var node_state: RunState.NodeState = RunState.NodeState.MAP
	var enemy_id: StringName = &""
	var position: Vector2i = Vector2i.ZERO


## What a won battle pays. Purrls join the run only when the reward is taken, so a reload on the
## reward screen never pays twice. Saved in run.node_payload while the screen is open.
class Reward:
	extends RefCounted
	var purrls: int = 0
	var move_offers: Array[MoveData] = []
	var item_drop: bool = false
	var elite: bool = false

	func to_payload() -> Dictionary:
		var offer_ids: Array[String] = []
		for move_data: MoveData in move_offers:
			offer_ids.append(String(move_data.id))
		return {"purrls": purrls, "offers": offer_ids, "item_drop": item_drop, "elite": elite}

	## Rebuilds a reward saved with to_payload. Null (after a warning) on a bad shape or an
	## offer id the content no longer has.
	static func from_payload(payload: Dictionary, db: ContentDb) -> Reward:
		var reader := SaveReader.new(payload, "run.json node_payload")
		var reward := Reward.new()
		reward.purrls = reader.int_at("purrls")
		var offer_ids: Array[StringName] = reader.ids_at("offers")
		var drop_value: Variant = payload.get("item_drop")
		var elite_value: Variant = payload.get("elite")
		if not reader.ok() or not drop_value is bool or not elite_value is bool:
			push_warning("run.json node_payload: not a reward")
			return null
		reward.item_drop = drop_value
		reward.elite = elite_value
		for move_id: StringName in offer_ids:
			var move_data: MoveData = db.move(move_id)
			if move_data == null:
				push_warning("run.json node_payload: unknown offer %s" % move_id)
				return null
			reward.move_offers.append(move_data)
		return reward


## The player's answer to a Reward: learn one offered move, or skip for Purrls.
class RewardChoice:
	extends RefCounted
	enum Kind { MOVE, SKIP }
	var kind: Kind = Kind.SKIP
	## Index into Reward.move_offers when kind is MOVE.
	var index: int = -1

	static func move(offer_index: int) -> RewardChoice:
		var choice := RewardChoice.new()
		choice.kind = Kind.MOVE
		choice.index = offer_index
		return choice

	static func skip() -> RewardChoice:
		return RewardChoice.new()


## Where [param node] leads. Battle enemies are drawn from [param rng] (the battle stream); an
## elite comes from the map's pre-rolled payload (D31).
static func enter_node(run: RunState, node: MapNode, db: ContentDb, rng: SeededRng) -> NodeEntry:
	var entry := NodeEntry.new()
	entry.position = node.cell()
	match node.type:
		MapNode.Type.BATTLE:
			entry.node_state = RunState.NodeState.BATTLE
			entry.enemy_id = _pick_enemy(_normal_pool(run.act, node.row, db), rng)
		MapNode.Type.ELITE:
			entry.node_state = RunState.NodeState.BATTLE
			var elite_id: String = node.payload.get("elite_id", "")
			entry.enemy_id = StringName(elite_id)
		MapNode.Type.BOSS:
			entry.node_state = RunState.NodeState.BATTLE
			entry.enemy_id = _pick_enemy(db.enemies_for(run.act, EnemyData.Tier.BOSS), rng)
		MapNode.Type.SHOP:
			entry.node_state = RunState.NodeState.SHOP
		MapNode.Type.REST:
			entry.node_state = RunState.NodeState.REST
		MapNode.Type.EVENT:
			entry.node_state = RunState.NodeState.EVENT
		MapNode.Type.TREASURE:
			entry.node_state = RunState.NodeState.TREASURE
	return entry


## Closes a won battle: the cat keeps its HP and heals 10% of max HP (PRD §4.5, round half up per
## D15), the stats grow, and the reward is rolled from [param rng] (the reward stream). Leaves
## the run on REWARD with the reward in node_payload.
static func finish_battle(
	run: RunState,
	state: BattleState,
	db: ContentDb,
	unlocked_signatures: Array[StringName],
	rng: SeededRng
) -> Reward:
	assert(state.outcome == BattleState.Outcome.WON, "finish_battle is for won battles only")
	run.stats.turns += state.turn
	run.stats.damage_dealt += state.enemy.max_hp - state.enemy.hp
	run.stats.damage_taken += maxi(0, run.hp - state.cat.hp)
	var heal: int = floori(run.max_hp * db.tuning().post_battle_heal_pct / 100.0 + 0.5)
	run.hp = mini(run.max_hp, state.cat.hp + heal)

	var reward := Reward.new()
	reward.elite = state.enemy_data.tier == EnemyData.Tier.ELITE
	reward.purrls = RewardRules.purrls(run.act, reward.elite, rng)
	reward.item_drop = RewardRules.item_drops(reward.elite, rng)
	reward.move_offers = RewardRules.offer_moves(
		RewardRules.reward_pool(db.all_moves(), unlocked_signatures), owned_ids(run), rng
	)
	run.node_state = RunState.NodeState.REWARD
	run.node_payload = reward.to_payload()
	return reward


## Applies [param choice]. A move goes to the first free equipped slot, else the bag. Returns
## false and changes nothing when both are full (the player releases a move first, T012).
static func take_reward(
	run: RunState, reward: Reward, choice: RewardChoice, tuning: TuningData
) -> bool:
	if choice.kind == RewardChoice.Kind.MOVE:
		assert(choice.index >= 0 and choice.index < reward.move_offers.size(), "bad offer index")
		if not learn_move(run, reward.move_offers[choice.index].id, tuning):
			return false
	else:
		run.purrls += RewardRules.SKIP_BONUS
	run.purrls += reward.purrls
	run.node_state = RunState.NodeState.MAP
	run.node_payload = {}
	return true


## Adds [param move_id] to the first free equipped slot (a released slot has an empty id, D33),
## else the bag (PRD §4.2). False when both are full.
static func learn_move(run: RunState, move_id: StringName, tuning: TuningData) -> bool:
	var instance := MoveInstance.new()
	instance.move_id = move_id
	for slot: int in run.equipped.size():
		if run.equipped[slot].move_id == &"":
			run.equipped[slot] = instance
			return true
	if run.equipped.size() < tuning.equipped_moves:
		run.equipped.append(instance)
	elif run.bag.size() < tuning.bag_size:
		run.bag.append(instance)
	else:
		return false
	return true


## Ids of every move the cat owns, equipped or in the bag.
static func owned_ids(run: RunState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for instance: MoveInstance in run.equipped + run.bag:
		if instance.move_id != &"":
			ids.append(instance.move_id)
	return ids


static func _normal_pool(act: int, row: int, db: ContentDb) -> Array[EnemyData]:
	if act == FIRST_BATTLE_ACT and row == FIRST_BATTLE_ROW:
		var pool: Array[EnemyData] = []
		for enemy_data: EnemyData in db.enemies_for(act, EnemyData.Tier.NORMAL):
			if enemy_data.first_battle_pool:
				pool.append(enemy_data)
		return pool
	return db.enemies_for(act, EnemyData.Tier.NORMAL)


static func _pick_enemy(pool: Array[EnemyData], rng: SeededRng) -> StringName:
	if pool.is_empty():
		return &""
	return pool[rng.range_int(0, pool.size() - 1)].id
