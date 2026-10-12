extends TestCase
## Battle reward rolls against PRD §10.6 and §5.1 (T011, D30). Seeded, so a failure replays.


func test_purrls_ranges_act1_to_3() -> void:
	var rng := SeededRng.new("REWARD-1")
	var ranges: Dictionary[int, Vector2i] = {
		1: Vector2i(12, 18), 2: Vector2i(16, 24), 3: Vector2i(20, 30)
	}
	for act: int in ranges:
		var seen_low: bool = false
		var seen_high: bool = false
		for _draw: int in 500:
			var purrls: int = RewardRules.purrls(act, false, rng)
			assert_true(purrls >= ranges[act].x and purrls <= ranges[act].y, "act %d" % act)
			seen_low = seen_low or purrls == ranges[act].x
			seen_high = seen_high or purrls == ranges[act].y
		assert_true(seen_low and seen_high, "act %d reaches both ends" % act)


func test_elite_purrls_double() -> void:
	var rng := SeededRng.new("REWARD-2")
	for _draw: int in 500:
		var purrls: int = RewardRules.purrls(1, true, rng)
		assert_true(purrls >= 24 and purrls <= 36, "elite act 1: %d" % purrls)


func test_offer_has_no_duplicates() -> void:
	var rng := SeededRng.new("REWARD-3")
	var pool: Array[MoveData] = [
		_move(&"a", MoveData.Rarity.COMMON),
		_move(&"b", MoveData.Rarity.COMMON),
		_move(&"c", MoveData.Rarity.UNCOMMON),
		_move(&"d", MoveData.Rarity.RARE),
	]
	for _offer: int in 200:
		var ids: Array[StringName] = _ids(RewardRules.offer_moves(pool, [], rng))
		assert_eq(ids.size(), 3)
		for id: StringName in ids:
			assert_eq(ids.count(id), 1, "duplicate %s" % id)


func test_small_pool_offers_what_exists() -> void:
	var pool: Array[MoveData] = [_move(&"a", MoveData.Rarity.UNCOMMON)]
	assert_eq(_ids(RewardRules.offer_moves(pool, [], SeededRng.new("x"))), [&"a"])


func test_owned_move_weight_halved() -> void:
	var rng := SeededRng.new("REWARD-4")
	var pool: Array[MoveData] = [
		_move(&"fresh", MoveData.Rarity.COMMON), _move(&"owned", MoveData.Rarity.COMMON)
	]
	var owned_picks: int = 0
	for _draw: int in 10_000:
		if RewardRules.offer_moves(pool, [&"owned"], rng, 1)[0].id == &"owned":
			owned_picks += 1
	assert_almost_eq(owned_picks / 10_000.0, 1.0 / 3.0, 0.03, "owned share")


func test_rarity_weights_60_30_10() -> void:
	var rng := SeededRng.new("REWARD-5")
	var pool: Array[MoveData] = [
		_move(&"common", MoveData.Rarity.COMMON),
		_move(&"uncommon", MoveData.Rarity.UNCOMMON),
		_move(&"rare", MoveData.Rarity.RARE),
	]
	var counts: Dictionary[StringName, int] = {}
	for _draw: int in 10_000:
		var id: StringName = RewardRules.offer_moves(pool, [], rng, 1)[0].id
		counts[id] = counts.get(id, 0) + 1
	assert_almost_eq(counts[&"common"] / 10_000.0, 0.6, 0.02, "common")
	assert_almost_eq(counts[&"uncommon"] / 10_000.0, 0.3, 0.02, "uncommon")
	assert_almost_eq(counts[&"rare"] / 10_000.0, 0.1, 0.02, "rare")


func test_item_drop_20_percent() -> void:
	var rng := SeededRng.new("REWARD-6")
	var drops: int = 0
	for _roll: int in 10_000:
		if RewardRules.item_drops(false, rng):
			drops += 1
	assert_almost_eq(drops / 10_000.0, 0.2, 0.02, "normal drop rate")
	for _roll: int in 100:
		assert_true(RewardRules.item_drops(true, rng), "elites always drop")


func test_starter_never_offered() -> void:
	var moves: Array[MoveData] = [
		_move(&"starter", MoveData.Rarity.STARTER),
		_move(&"common", MoveData.Rarity.COMMON),
		_move(&"locked_sig", MoveData.Rarity.SIGNATURE),
		_move(&"open_sig", MoveData.Rarity.SIGNATURE),
	]
	var pool: Array[MoveData] = RewardRules.reward_pool(moves, [&"open_sig"])
	assert_eq(_ids(pool), [&"common", &"open_sig"])


func _move(id: StringName, rarity: MoveData.Rarity) -> MoveData:
	var move_data := MoveData.new()
	move_data.id = id
	move_data.rarity = rarity
	return move_data


func _ids(moves: Array[MoveData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for move_data: MoveData in moves:
		ids.append(move_data.id)
	return ids
