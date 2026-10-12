extends TestCase
## Reward rates over many seeded draws (T011, PRD §10.6, §5.1).


func test_item_drop_rate() -> void:
	var rng := SeededRng.new("SIM-ITEM")
	var drops: int = 0
	for _roll: int in 100_000:
		if RewardRules.item_drops(false, rng):
			drops += 1
	var share: float = drops / 100_000.0
	print("item drop share: %.4f (0.20)" % share)
	assert_almost_eq(share, 0.2, 0.01, "normal battle item drop")


func test_offer_rarity_mix() -> void:
	var rng := SeededRng.new("SIM-OFFER")
	var pool: Array[MoveData] = []
	for rarity: MoveData.Rarity in [
		MoveData.Rarity.COMMON, MoveData.Rarity.UNCOMMON, MoveData.Rarity.RARE
	]:
		var move_data := MoveData.new()
		var rarity_name: String = MoveData.Rarity.keys()[rarity]
		move_data.id = StringName(rarity_name)
		move_data.rarity = rarity
		pool.append(move_data)
	var first_picks: Dictionary[MoveData.Rarity, int] = {}
	for _offer: int in 20_000:
		var first: MoveData = RewardRules.offer_moves(pool, [], rng)[0]
		first_picks[first.rarity] = first_picks.get(first.rarity, 0) + 1
	var common: float = first_picks[MoveData.Rarity.COMMON] / 20_000.0
	var uncommon: float = first_picks[MoveData.Rarity.UNCOMMON] / 20_000.0
	var rare: float = first_picks[MoveData.Rarity.RARE] / 20_000.0
	print("first-pick shares: common %.4f uncommon %.4f rare %.4f" % [common, uncommon, rare])
	assert_almost_eq(common, 0.6, 0.02, "common")
	assert_almost_eq(uncommon, 0.3, 0.02, "uncommon")
	assert_almost_eq(rare, 0.1, 0.02, "rare")
