class_name ShopRules
extends RefCounted
## Shop stock, prices, rerolls, and the fairness rule (PRD §10.2, D30, D31). Pure: every draw comes
## from the run's shop stream. Stock is a JSON-safe Dictionary so it rides in run.node_payload.
##
## Stock shape: {"entries": [{"kind": "move"|"relic"|"modifier"|"item", "id": String,
## "price": int, "sold": bool}, …], "rerolls": int}. Entry order: up to 3 moves (the first a
## gamble), the relic, 2 modifiers, 2 items.

const KIND_MOVE: String = "move"
const KIND_RELIC: String = "relic"
const KIND_MODIFIER: String = "modifier"
const KIND_ITEM: String = "item"

const BASIC_MOVE_PRICE: int = 45
const GAMBLE_MOVE_PRICE: int = 65
## Relic prices by RelicData.Rarity: common, uncommon, rare.
const RELIC_PRICES: Array[int] = [120, 160, 210]
const MODIFIER_PRICE: int = 55
const MOVE_SLOTS: int = 3
const MODIFIER_COUNT: int = 2
const ITEM_COUNT: int = 2
## The fairness rule applies from this many Purrls (PRD §10.2).
const FAIRNESS_PURRLS: int = 25
const FAIRNESS_ITEM: StringName = &"spare_die"
const HEAL_PRICE: int = 40
## Rarity words used in the map payload (MapGen.RARITIES) by RelicData.Rarity.
const RARITY_NAMES: Array[String] = ["common", "uncommon", "rare"]


## A fresh stock for the shop at [param relic_rarity] (the map payload, D31).
static func generate(
	act: int,
	run: RunState,
	db: ContentDb,
	relic_rarity: String,
	unlocked_signatures: Array[StringName],
	rng: SeededRng
) -> Dictionary:
	var scale: float = db.tuning().shop_price_scale[act - 1]
	var entries: Array[Dictionary] = []
	var pool: Array[MoveData] = RewardRules.reward_pool(db.all_moves(), unlocked_signatures)
	var gambles: Array[MoveData] = pool.filter(
		func(move: MoveData) -> bool: return move.category == MoveData.Category.GAMBLE
	)
	var others: Array[MoveData] = pool.filter(
		func(move: MoveData) -> bool:
			return (
				move.category == MoveData.Category.BASIC
				or move.category == MoveData.Category.UTILITY
			)
	)
	# Shops don't halve owned moves (D30), so nothing counts as owned here.
	for move: MoveData in RewardRules.offer_moves(gambles, [], rng, 1):
		entries.append(_entry(KIND_MOVE, move.id, price(GAMBLE_MOVE_PRICE, scale)))
	for move: MoveData in RewardRules.offer_moves(others, [], rng, MOVE_SLOTS - 1):
		entries.append(_entry(KIND_MOVE, move.id, price(BASIC_MOVE_PRICE, scale)))
	var relic: RelicData = pick_relic(db.all_relics(), run.relics, relic_rarity, rng)
	if relic != null:
		entries.append(_entry(KIND_RELIC, relic.id, price(RELIC_PRICES[relic.rarity], scale)))
	for modifier_id: StringName in _distinct_ids(_modifier_ids(db), MODIFIER_COUNT, rng):
		entries.append(_entry(KIND_MODIFIER, modifier_id, price(MODIFIER_PRICE, scale)))
	for item_id: StringName in _distinct_ids(_item_ids(db), ITEM_COUNT, rng):
		entries.append(_entry(KIND_ITEM, item_id, price(db.item(item_id).price, scale)))
	var stock: Dictionary = {"entries": entries, "rerolls": 0}
	return ensure_affordable(stock, run.purrls, db, act)


## Reads a stock saved in run.node_payload, converting JSON numbers back to ints. Returns {}
## (after a warning) on a bad shape or an id the content no longer has.
static func stock_from_payload(payload: Dictionary, db: ContentDb) -> Dictionary:
	var reader := SaveReader.new(payload, "run.json shop")
	var rerolls: int = reader.int_at("rerolls")
	var raw_entries: Array[Dictionary] = reader.dicts_at("entries")
	if not reader.ok():
		reader.warn()
		return {}
	var entries: Array[Dictionary] = []
	for raw: Dictionary in raw_entries:
		var entry_reader := SaveReader.new(raw, "run.json shop entry")
		var kind: String = entry_reader.string_at("kind")
		var id: String = entry_reader.string_at("id")
		var cost: int = entry_reader.int_at("price")
		var sold: Variant = raw.get("sold")
		if not entry_reader.ok() or not sold is bool or not _content_exists(kind, id, db):
			push_warning("run.json shop entry: bad entry %s" % raw)
			return {}
		var entry: Dictionary = _entry(kind, StringName(id), cost)
		entry["sold"] = sold
		entries.append(entry)
	return {"entries": entries, "rerolls": rerolls}


## A shop price: [param base] times the act scale, rounded to the nearest 5 (halves up, D15).
static func price(base: int, scale: float) -> int:
	return floori(base * scale / 5.0 + 0.5) * 5


## The fairness guarantee (PRD §10.2): with at least 25 Purrls, something must be affordable. If
## nothing is, the last item becomes a Spare Die, which costs at most 25 in every act.
static func ensure_affordable(
	stock: Dictionary, purrls: int, db: ContentDb, act: int
) -> Dictionary:
	if purrls < FAIRNESS_PURRLS:
		return stock
	var entries: Array = stock["entries"]
	for entry: Dictionary in entries:
		var cost: int = entry["price"]
		if not entry["sold"] and cost <= purrls:
			return stock
	var spare: ItemData = db.item(FAIRNESS_ITEM)
	assert(spare != null, "the fairness item is missing from content")
	var fair_price: int = price(spare.price, db.tuning().shop_price_scale[act - 1])
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		if entry["kind"] == KIND_ITEM:
			entries[index] = _entry(KIND_ITEM, FAIRNESS_ITEM, fair_price)
			return stock
	entries.append(_entry(KIND_ITEM, FAIRNESS_ITEM, fair_price))
	return stock


## Cost of the next reroll: 15, then +10 per reroll already done in this visit (PRD §10.2).
static func reroll_cost(rerolls_done: int, tuning: TuningData) -> int:
	return tuning.shop_reroll_cost + tuning.shop_reroll_step * rerolls_done


## HP the heal service restores: 30% of max HP, round half up (D15), capped at max.
static func heal_amount(run: RunState, tuning: TuningData) -> int:
	var heal: int = floori(run.max_hp * tuning.rest_heal_pct / 100.0 + 0.5)
	return mini(heal, run.max_hp - run.hp)


## An unowned relic of [param rarity_name]; an empty rarity falls back up, then down (D30).
static func pick_relic(
	relics: Array[RelicData], owned: Array[StringName], rarity_name: String, rng: SeededRng
) -> RelicData:
	var start: int = maxi(RARITY_NAMES.find(rarity_name), 0)
	var order: Array[int] = []
	for rarity: int in range(start, RARITY_NAMES.size()):
		order.append(rarity)
	for rarity: int in range(start - 1, -1, -1):
		order.append(rarity)
	for rarity: int in order:
		var pool: Array[RelicData] = relics.filter(
			func(relic: RelicData) -> bool:
				return relic.rarity == rarity and not owned.has(relic.id)
		)
		if not pool.is_empty():
			return pool[rng.range_int(0, pool.size() - 1)]
	return null


static func _entry(kind: String, id: StringName, cost: int) -> Dictionary:
	return {"kind": kind, "id": String(id), "price": cost, "sold": false}


## Up to [param count] distinct ids, uniform without replacement.
static func _distinct_ids(ids: Array[StringName], count: int, rng: SeededRng) -> Array[StringName]:
	var left: Array[StringName] = ids.duplicate()
	var picked: Array[StringName] = []
	while picked.size() < count and not left.is_empty():
		picked.append(left.pop_at(rng.range_int(0, left.size() - 1)))
	return picked


static func _modifier_ids(db: ContentDb) -> Array[StringName]:
	var ids: Array[StringName] = []
	for modifier: ModifierData in db.all_modifiers():
		ids.append(modifier.id)
	return ids


static func _item_ids(db: ContentDb) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: ItemData in db.all_items():
		ids.append(item.id)
	return ids


static func _content_exists(kind: String, id: String, db: ContentDb) -> bool:
	match kind:
		KIND_MOVE:
			return db.move(StringName(id)) != null
		KIND_RELIC:
			return db.relic(StringName(id)) != null
		KIND_MODIFIER:
			return db.modifier(StringName(id)) != null
		KIND_ITEM:
			return db.item(StringName(id)) != null
	return false
