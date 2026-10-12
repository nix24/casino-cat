class_name RewardRules
extends RefCounted
## Battle reward rolls (PRD §5.1, §10.6, decisions D30). Pure: every draw comes from the run's
## reward stream, in this order: Purrls, the item roll, the item (when one drops), then the move
## offer.

## Normal-battle Purrls per act, inclusive. Elites pay twice both ends (PRD §10.6).
const PURRLS_RANGES: Dictionary[int, Vector2i] = {
	1: Vector2i(12, 18),
	2: Vector2i(16, 24),
	3: Vector2i(20, 30),
}
const ELITE_PURRLS_MULT: int = 2
const ITEM_DROP_CHANCE: float = 0.20
## Extra Purrls for skipping the move offer (PRD §10.6).
const SKIP_BONUS: int = 10
const OFFER_COUNT: int = 3
## Offer weights by rarity (PRD §5.1). Signatures are offered at Rare weight once unlocked.
const RARITY_WEIGHTS: Dictionary[MoveData.Rarity, int] = {
	MoveData.Rarity.COMMON: 60,
	MoveData.Rarity.UNCOMMON: 30,
	MoveData.Rarity.RARE: 10,
	MoveData.Rarity.SIGNATURE: 10,
}


## Purrls for a won battle in [param act]: a uniform draw from the act's range (doubled for an
## elite).
static func purrls(act: int, is_elite: bool, rng: SeededRng) -> int:
	var span: Vector2i = PURRLS_RANGES[act]
	if is_elite:
		span *= ELITE_PURRLS_MULT
	return rng.range_int(span.x, span.y)


## Whether a pouch item drops: always from an elite (no draw), 20% from a normal battle.
static func item_drops(is_elite: bool, rng: SeededRng) -> bool:
	if is_elite:
		return true
	return rng.chance(ITEM_DROP_CHANCE)


## A dropped pouch item, uniform over every item (D30). Empty when there are none.
static func drop_item(items: Array[ItemData], rng: SeededRng) -> StringName:
	if items.is_empty():
		return &""
	return items[rng.range_int(0, items.size() - 1)].id


## The moves a battle can offer (D30): every non-starter move, with signatures only once
## unlocked.
static func reward_pool(
	moves: Array[MoveData], unlocked_signatures: Array[StringName]
) -> Array[MoveData]:
	var pool: Array[MoveData] = []
	for move_data: MoveData in moves:
		if move_data.rarity == MoveData.Rarity.STARTER:
			continue
		if (
			move_data.rarity == MoveData.Rarity.SIGNATURE
			and not unlocked_signatures.has(move_data.id)
		):
			continue
		pool.append(move_data)
	return pool


## Up to [param count] distinct moves from [param pool], weighted by rarity; owned moves count
## half (D30). A pool smaller than [param count] offers what it has.
static func offer_moves(
	pool: Array[MoveData], owned_ids: Array[StringName], rng: SeededRng, count: int = OFFER_COUNT
) -> Array[MoveData]:
	var left: Array[MoveData] = pool.duplicate()
	var offer: Array[MoveData] = []
	while offer.size() < count and not left.is_empty():
		var total: int = 0
		for move_data: MoveData in left:
			total += weight(move_data, owned_ids)
		var roll: int = rng.range_int(1, total)
		for i: int in left.size():
			roll -= weight(left[i], owned_ids)
			if roll <= 0:
				offer.append(left[i])
				left.remove_at(i)
				break
	return offer


## The offer weight of [param move_data]: its rarity weight, halved when the cat owns it.
static func weight(move_data: MoveData, owned_ids: Array[StringName]) -> int:
	var base: int = RARITY_WEIGHTS[move_data.rarity]
	return base / 2 if owned_ids.has(move_data.id) else base
