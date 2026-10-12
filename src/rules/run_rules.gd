class_name RunRules
extends RefCounted
## Moves a run between map nodes (arch §5 state machine). Pure: the caller passes the content
## and the right RNG stream, and Game swaps scenes and saves.

## Why attach_modifier refused, or OK (D3).
enum AttachResult {
	OK, NO_SUCH_MOVE, UNKNOWN_MODIFIER, DOES_NOT_FIT, ALREADY_ATTACHED, SLOTS_FULL, NEEDS_SUIT
}

## The first battle of every run comes from this pool's enemies (PRD §9.2): act 1, row 1.
const FIRST_BATTLE_ACT: int = 1
const FIRST_BATTLE_ROW: int = 1
## Modifier slots per move (PRD §8.1).
const MODIFIER_SLOTS: int = 2
## Suits Re-suited can choose (PRD §8.1: ♠/♥/♦; utility ♣ is not offered).
const RE_SUIT_CHOICES: Array[Suit.Type] = [Suit.Type.SPADES, Suit.Type.HEARTS, Suit.Type.DIAMONDS]
const RE_SUITED_ID: StringName = &"re_suited"


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


## Adds [param move_id] to a free equipped slot (a released slot leaves the row short, D33),
## else the bag (PRD §4.2). False when both are full.
static func learn_move(run: RunState, move_id: StringName, tuning: TuningData) -> bool:
	var instance := MoveInstance.new()
	instance.move_id = move_id
	if run.equipped.size() < tuning.equipped_moves:
		run.equipped.append(instance)
	elif run.bag.size() < tuning.bag_size:
		run.bag.append(instance)
	else:
		return false
	return true


## Swaps equipped [param equipped_index] with bag [param bag_index] (PRD §4.2). Counts stay.
static func swap_equipped_with_bag(run: RunState, equipped_index: int, bag_index: int) -> bool:
	assert(run.node_state != RunState.NodeState.BATTLE, "loadout changes never happen in battle")
	if not _in_range(run.equipped, equipped_index) or not _in_range(run.bag, bag_index):
		return false
	var equipped_move: MoveInstance = run.equipped[equipped_index]
	run.equipped[equipped_index] = run.bag[bag_index]
	run.bag[bag_index] = equipped_move
	return true


## Releases a move for the rest of the run. An equipped release leaves the row one shorter (no
## bag move moves up), and the last equipped move can't be released (D33).
static func release_move(run: RunState, from_bag: bool, index: int) -> bool:
	assert(run.node_state != RunState.NodeState.BATTLE, "loadout changes never happen in battle")
	var moves: Array[MoveInstance] = run.bag if from_bag else run.equipped
	if not _in_range(moves, index) or (not from_bag and moves.size() == 1):
		return false
	moves.remove_at(index)
	return true


## Moves an equipped move into the bag when it has room. The last equipped move stays (D33).
static func move_to_bag(run: RunState, equipped_index: int, tuning: TuningData) -> bool:
	assert(run.node_state != RunState.NodeState.BATTLE, "loadout changes never happen in battle")
	if not _in_range(run.equipped, equipped_index) or run.equipped.size() == 1:
		return false
	if run.bag.size() >= tuning.bag_size:
		return false
	run.bag.append(run.equipped[equipped_index])
	run.equipped.remove_at(equipped_index)
	return true


## Moves a bagged move into the equipped row when it has room.
static func equip_from_bag(run: RunState, bag_index: int, tuning: TuningData) -> bool:
	assert(run.node_state != RunState.NodeState.BATTLE, "loadout changes never happen in battle")
	if not _in_range(run.bag, bag_index) or run.equipped.size() >= tuning.equipped_moves:
		return false
	run.equipped.append(run.bag[bag_index])
	run.bag.remove_at(bag_index)
	return true


## Adds [param relic] to the run (no duplicates, PRD §8.2) and applies its RUN_START hooks once:
## max HP gains raise current HP by the same amount (D16). False when already owned.
static func gain_relic(run: RunState, relic: RelicData) -> bool:
	if run.relics.has(relic.id):
		return false
	run.relics.append(relic.id)
	for hook: HookData in relic.hooks:
		if hook.trigger == HookData.Trigger.RUN_START and hook.op == HookData.Op.ADD_MAX_HP:
			run.max_hp += hook.amount
			run.hp += hook.amount
	return true


## Attaches [param modifier_id] to a move. [param move_index] counts the equipped row first, then
## the bag. Re-suited needs [param suit_choice] (♠/♥/♦). [param replace_slot] overwrites that
## modifier slot (PRD §8.1: the old one is lost); otherwise a free slot is used (D3).
static func attach_modifier(
	run: RunState,
	move_index: int,
	modifier_id: StringName,
	db: ContentDb,
	suit_choice: int = -1,
	replace_slot: int = -1
) -> AttachResult:
	var instance: MoveInstance = _owned_move_at(run, move_index)
	if instance == null:
		return AttachResult.NO_SUCH_MOVE
	var modifier: ModifierData = db.modifier(modifier_id)
	if modifier == null:
		return AttachResult.UNKNOWN_MODIFIER
	if not fits(modifier, db.move(instance.move_id)):
		return AttachResult.DOES_NOT_FIT
	if instance.modifier_ids.has(modifier_id):
		return AttachResult.ALREADY_ATTACHED
	var is_replacing: bool = replace_slot >= 0 and replace_slot < instance.modifier_ids.size()
	if not is_replacing and instance.modifier_ids.size() >= MODIFIER_SLOTS:
		return AttachResult.SLOTS_FULL
	if modifier_id == RE_SUITED_ID and not RE_SUIT_CHOICES.has(suit_choice):
		return AttachResult.NEEDS_SUIT
	if is_replacing:
		if instance.modifier_ids[replace_slot] == RE_SUITED_ID:
			instance.suit_override = -1
		instance.modifier_ids[replace_slot] = modifier_id
	else:
		instance.modifier_ids.append(modifier_id)
	if modifier_id == RE_SUITED_ID:
		instance.suit_override = suit_choice
	return AttachResult.OK


## Whether [param modifier] fits [param move] (PRD §8.1 "Fits").
static func fits(modifier: ModifierData, move: MoveData) -> bool:
	var family: StringName = move.gamble.family if move.gamble != null else &""
	match modifier.fit:
		ModifierData.Fit.BASIC:
			return move.category == MoveData.Category.BASIC
		ModifierData.Fit.ANY:
			return true
		ModifierData.Fit.GAMBLE:
			return move.category == MoveData.Category.GAMBLE
		ModifierData.Fit.DICE_NOT_SNAKE_EYES:
			return family == &"dice" and move.id != &"snake_eyes"
		ModifierData.Fit.COIN:
			return family == &"coin"
		ModifierData.Fit.CARDS:
			return family == &"cards"
	return false


## Ids of every move the cat owns, equipped or in the bag.
static func owned_ids(run: RunState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for instance: MoveInstance in run.equipped + run.bag:
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


static func _in_range(moves: Array[MoveInstance], index: int) -> bool:
	return index >= 0 and index < moves.size()


## The owned move at [param index] counting equipped then bag, or null.
static func _owned_move_at(run: RunState, index: int) -> MoveInstance:
	if index >= 0 and index < run.equipped.size():
		return run.equipped[index]
	var bag_index: int = index - run.equipped.size()
	if bag_index >= 0 and bag_index < run.bag.size():
		return run.bag[bag_index]
	return null
