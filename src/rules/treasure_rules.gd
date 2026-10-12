class_name TreasureRules
extends RefCounted
## Treasure chests (PRD §10.4): 1 relic of the rarity rolled with the map (D31). Pure.


## The chest rarity for a 1-100 roll: common 50%, uncommon 35%, rare 15% (PRD §10.4).
static func rarity_for_roll(roll: int) -> String:
	var cumulative: int = 0
	for index: int in MapGen.TREASURE_RARITY_ODDS.size():
		cumulative += MapGen.TREASURE_RARITY_ODDS[index]
		if roll <= cumulative:
			return MapGen.RARITIES[index]
	return MapGen.RARITIES[MapGen.RARITIES.size() - 1]


## A chest rarity drawn from [param rng]. MapGen pre-rolls these onto treasure nodes (D31).
static func roll_rarity(rng: SeededRng) -> String:
	return rarity_for_roll(rng.range_int(1, 100))


## Opens a chest of [param rarity]: an unowned relic of that rarity from [param rng] (the reward
## stream), falling back up then down when none is left (D30). Gains it and returns it, or null
## when every relic is owned.
static func open_chest(run: RunState, rarity: String, db: ContentDb, rng: SeededRng) -> RelicData:
	var relic: RelicData = ShopRules.pick_relic(db.all_relics(), run.relics, rarity, rng)
	if relic != null:
		RunRules.gain_relic(run, relic)
	return relic
