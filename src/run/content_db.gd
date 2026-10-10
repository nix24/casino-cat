class_name ContentDb
extends RefCounted
## Every content resource the game loads, looked up by id (arch §2). Only moves, enemies, and
## tuning load here; relics, items, events, and modifiers join with their classes (T013, T014,
## T017). Pools are copies sorted by id, so callers never see directory order or the store.

const MOVES_DIR: String = "res://src/content/moves"
const ENEMIES_DIR: String = "res://src/content/enemies"
const TUNING_PATH: String = "res://src/content/tuning.tres"

## Statuses from PRD §4.7. Any other status on an effect or intent is a content typo.
const ALLOWED_STATUSES: Array[StringName] = [&"weak", &"exposed", &"rattled", &"regen"]
## The first-battle pool is exactly these three (PRD §9.2). Every member must be in act 1.
const FIRST_BATTLE_POOL: Array[StringName] = [&"sewer_rat", &"pickpocket_pigeon", &"junkyard_pup"]
const FIRST_BATTLE_ACT: int = 1

## PRD §4.3: the triangle multiplier never exceeds this.
const TRIANGLE_ADVANTAGE_CAP: float = 1.5
## PRD §6.0: a gamble never shows a chance above this, and the chance must be positive.
const PROBABILITY_CAP_MAX: float = 0.95
## PRD §4.4: the repeat penalty has one entry per use from 1 to 4.
const REPEAT_PENALTY_COUNT: int = 4

## Ceilings from PRD §2.1. Checked as ceilings only (PRD §2.3 item 2); exact counts are a
## milestone exit check, not a validation rule.
const MOVE_CEILING: int = 40
const BASIC_MOVE_CEILING: int = 12
const UTILITY_MOVE_CEILING: int = 4
const GAMBLE_MOVE_CEILING: int = 21
const SIGNATURE_MOVE_CEILING: int = 3
const NORMAL_ENEMY_CEILING: int = 21
const ELITE_ENEMY_CEILING: int = 6
const BOSS_ENEMY_CEILING: int = 3

var _moves: Array[MoveData] = []
var _enemies: Array[EnemyData] = []
var _tuning: TuningData


## Copies the pools so later changes to the caller's arrays cannot reorder or edit this database.
func _init(moves: Array[MoveData], enemies: Array[EnemyData], tuning_data: TuningData) -> void:
	_moves = moves.duplicate()
	_enemies = enemies.duplicate()
	_tuning = tuning_data
	_moves.sort_custom(_is_move_id_before)
	_enemies.sort_custom(_is_enemy_id_before)


## Loads every move and enemy under src/content and the one tuning resource. A missing folder
## is an empty list; a file of the wrong type is reported and skipped.
static func load_all() -> ContentDb:
	return from_parts(_load_moves(), _load_enemies(), _load_tuning())


## Builds a database from resources already in memory. load_all uses it, and tests use it to
## check fixtures.
static func from_parts(
	moves: Array[MoveData], enemies: Array[EnemyData], tuning_data: TuningData
) -> ContentDb:
	return ContentDb.new(moves, enemies, tuning_data)


## The move with this id, or null if none exists.
func move(id: StringName) -> MoveData:
	for move_data: MoveData in _moves:
		if move_data.id == id:
			return move_data
	return null


## The enemy with this id, or null if none exists.
func enemy(id: StringName) -> EnemyData:
	for enemy_data: EnemyData in _enemies:
		if enemy_data.id == id:
			return enemy_data
	return null


## The one tuning resource (PRD §23).
func tuning() -> TuningData:
	return _tuning


## Every move, sorted by id.
func all_moves() -> Array[MoveData]:
	return _moves.duplicate()


## Every enemy, sorted by id.
func all_enemies() -> Array[EnemyData]:
	return _enemies.duplicate()


## Moves with this rarity and category, sorted by id.
func moves_by(rarity: MoveData.Rarity, category: MoveData.Category) -> Array[MoveData]:
	var matches: Array[MoveData] = []
	for move_data: MoveData in _moves:
		if move_data.rarity == rarity and move_data.category == category:
			matches.append(move_data)
	return matches


## Enemies that appear in this act at this tier, sorted by id.
func enemies_for(act: int, tier: EnemyData.Tier) -> Array[EnemyData]:
	var matches: Array[EnemyData] = []
	for enemy_data: EnemyData in _enemies:
		if enemy_data.act == act and enemy_data.tier == tier:
			matches.append(enemy_data)
	return matches


## Every problem in the loaded content, one message each. Empty means the content is valid.
## Messages name the file id so a designer can find the bad resource.
func validate() -> PackedStringArray:
	var messages: Array[String] = []
	var move_ids: Array[StringName] = _ids_of_moves()
	var enemy_ids: Array[StringName] = _ids_of_enemies()
	_report_duplicate_ids(move_ids, "move", messages)
	_report_duplicate_ids(enemy_ids, "enemy", messages)
	_report_empty_ids(move_ids, "move", messages)
	_report_empty_ids(enemy_ids, "enemy", messages)
	for move_data: MoveData in _moves:
		_check_move_statuses(move_data, messages)
	for enemy_data: EnemyData in _enemies:
		_check_enemy_statuses(enemy_data, messages)
	for enemy_data: EnemyData in _enemies:
		_check_enemy_intent_numbers(enemy_data, messages)
	_check_first_battle_pool(messages)
	_check_tuning_caps(messages)
	_check_tuning_wiring(messages)
	for move_data: MoveData in _moves:
		_check_gamble_base_damage(move_data, messages)
	_check_ceilings(messages)
	return PackedStringArray(messages)


static func _load_moves() -> Array[MoveData]:
	var moves: Array[MoveData] = []
	for path: String in _tres_paths(MOVES_DIR):
		var move_data: MoveData = load(path) as MoveData
		if move_data == null:
			push_error("%s is not a MoveData; skipped" % path)
		else:
			moves.append(move_data)
	return moves


static func _load_enemies() -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	for path: String in _tres_paths(ENEMIES_DIR):
		var enemy_data: EnemyData = load(path) as EnemyData
		if enemy_data == null:
			push_error("%s is not an EnemyData; skipped" % path)
		else:
			enemies.append(enemy_data)
	return enemies


## Tuning is required. A missing or wrong file falls back to the PRD defaults, with an error.
static func _load_tuning() -> TuningData:
	var tuning_data: TuningData = load(TUNING_PATH) as TuningData
	if tuning_data == null:
		push_error("%s is not a TuningData; using PRD defaults" % TUNING_PATH)
		return TuningData.new()
	return tuning_data


## Lists the .tres files in a folder. ResourceLoader also lists remapped resources in exported
## builds, where DirAccess would show *.tres.remap instead.
static func _tres_paths(folder: String) -> PackedStringArray:
	var paths := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return paths
	for file_name: String in ResourceLoader.list_directory(folder):
		if file_name.ends_with(".tres"):
			paths.append(folder.path_join(file_name))
	return paths


static func _is_move_id_before(a: MoveData, b: MoveData) -> bool:
	return String(a.id) < String(b.id)


static func _is_enemy_id_before(a: EnemyData, b: EnemyData) -> bool:
	return String(a.id) < String(b.id)


func _ids_of_moves() -> Array[StringName]:
	var ids: Array[StringName] = []
	for move_data: MoveData in _moves:
		ids.append(move_data.id)
	return ids


func _ids_of_enemies() -> Array[StringName]:
	var ids: Array[StringName] = []
	for enemy_data: EnemyData in _enemies:
		ids.append(enemy_data.id)
	return ids


static func _report_duplicate_ids(
	ids: Array[StringName], kind: String, messages: Array[String]
) -> void:
	var seen: Array[StringName] = []
	for id: StringName in ids:
		if seen.has(id):
			messages.append("duplicate %s id: %s" % [kind, id])
		else:
			seen.append(id)


static func _report_empty_ids(
	ids: Array[StringName], kind: String, messages: Array[String]
) -> void:
	for id: StringName in ids:
		if id.is_empty():
			messages.append("%s has an empty id" % kind)


static func _check_move_statuses(move_data: MoveData, messages: Array[String]) -> void:
	for effect: EffectData in move_data.effects:
		if effect.kind == EffectData.Kind.STATUS and not ALLOWED_STATUSES.has(effect.status):
			messages.append("move %s: unknown status %s" % [move_data.id, effect.status])


static func _check_enemy_statuses(enemy_data: EnemyData, messages: Array[String]) -> void:
	for intent: IntentData in enemy_data.pattern:
		if not intent.status.is_empty() and not ALLOWED_STATUSES.has(intent.status):
			messages.append("enemy %s: unknown status %s" % [enemy_data.id, intent.status])


static func _check_enemy_intent_numbers(enemy_data: EnemyData, messages: Array[String]) -> void:
	for intent: IntentData in enemy_data.pattern:
		if intent.kind == IntentData.Kind.DEBUFF and intent.turns <= 0:
			messages.append("enemy %s: DEBUFF intent needs turns > 0" % enemy_data.id)
		if intent.kind == IntentData.Kind.STEAL_MP and intent.amount <= 0:
			messages.append("enemy %s: STEAL_MP intent needs amount > 0" % enemy_data.id)


func _check_first_battle_pool(messages: Array[String]) -> void:
	var pool_ids: Array[StringName] = []
	for enemy_data: EnemyData in _enemies:
		if enemy_data.first_battle_pool:
			pool_ids.append(enemy_data.id)
	for pool_id: StringName in FIRST_BATTLE_POOL:
		if not pool_ids.has(pool_id):
			messages.append("first-battle pool is missing %s" % pool_id)
	for enemy_data: EnemyData in _enemies:
		if not enemy_data.first_battle_pool:
			continue
		if not FIRST_BATTLE_POOL.has(enemy_data.id):
			messages.append("first-battle pool has extra enemy %s" % enemy_data.id)
		if enemy_data.act != FIRST_BATTLE_ACT:
			messages.append(
				(
					"first-battle enemy %s is act %d, not act %d"
					% [enemy_data.id, enemy_data.act, FIRST_BATTLE_ACT]
				)
			)


func _check_tuning_caps(messages: Array[String]) -> void:
	var advantage: float = _tuning.triangle_advantage
	var advantage_over_cap: bool = advantage > TRIANGLE_ADVANTAGE_CAP
	if advantage_over_cap and not is_equal_approx(advantage, TRIANGLE_ADVANTAGE_CAP):
		messages.append(
			"triangle_advantage %s exceeds cap %s (PRD §4.3)" % [advantage, TRIANGLE_ADVANTAGE_CAP]
		)
	var probability: float = _tuning.probability_cap
	var probability_at_or_below_cap: bool = (
		probability < PROBABILITY_CAP_MAX or is_equal_approx(probability, PROBABILITY_CAP_MAX)
	)
	if probability <= 0.0 or not probability_at_or_below_cap:
		messages.append("probability_cap %s is outside (0, 0.95] (PRD §6.0)" % probability)
	var penalty_count: int = _tuning.repeat_penalty.size()
	if penalty_count != REPEAT_PENALTY_COUNT:
		messages.append(
			(
				"repeat_penalty has %d entries, needs %d (PRD §4.4)"
				% [penalty_count, REPEAT_PENALTY_COUNT]
			)
		)


## Suit and GambleRules still use their own constants (R7). Until tuning is wired through
## BattleContext, a tuned value that differs from its rules constant would silently do nothing.
func _check_tuning_wiring(messages: Array[String]) -> void:
	_check_wired(
		_tuning.triangle_advantage,
		Suit.ADVANTAGE_MULTIPLIER,
		"triangle_advantage",
		"Suit.ADVANTAGE_MULTIPLIER",
		messages
	)
	_check_wired(
		_tuning.triangle_disadvantage,
		Suit.DISADVANTAGE_MULTIPLIER,
		"triangle_disadvantage",
		"Suit.DISADVANTAGE_MULTIPLIER",
		messages
	)
	_check_wired(
		_tuning.probability_cap,
		GambleRules.PROBABILITY_CAP,
		"probability_cap",
		"GambleRules.PROBABILITY_CAP",
		messages
	)


static func _check_wired(
	tuned: float, rules_value: float, field: String, constant: String, messages: Array[String]
) -> void:
	if not is_equal_approx(tuned, rules_value):
		messages.append(
			(
				"%s %s differs from %s %s; tuning is not wired yet"
				% [field, tuned, constant, rules_value]
			)
		)


## GAMBLE moves need gamble data (R8). A dice gamble's base damage must match the move's.
static func _check_gamble_base_damage(move_data: MoveData, messages: Array[String]) -> void:
	if move_data.category != MoveData.Category.GAMBLE:
		return
	if move_data.gamble == null:
		messages.append("move %s: GAMBLE move has no gamble data" % move_data.id)
		return
	var dice: DiceGambleData = move_data.gamble as DiceGambleData
	if dice != null and dice.base_damage != move_data.base_damage:
		messages.append(
			(
				"move %s: base_damage %d differs from gamble base_damage %d"
				% [move_data.id, move_data.base_damage, dice.base_damage]
			)
		)


func _check_ceilings(messages: Array[String]) -> void:
	_check_ceiling("moves", _moves.size(), MOVE_CEILING, messages)
	_check_ceiling(
		"basic moves", _count_moves(MoveData.Category.BASIC), BASIC_MOVE_CEILING, messages
	)
	_check_ceiling(
		"utility moves", _count_moves(MoveData.Category.UTILITY), UTILITY_MOVE_CEILING, messages
	)
	_check_ceiling(
		"gamble moves", _count_moves(MoveData.Category.GAMBLE), GAMBLE_MOVE_CEILING, messages
	)
	_check_ceiling(
		"signature moves",
		_count_moves(MoveData.Category.SIGNATURE),
		SIGNATURE_MOVE_CEILING,
		messages
	)
	_check_ceiling(
		"normal enemies", _count_enemies(EnemyData.Tier.NORMAL), NORMAL_ENEMY_CEILING, messages
	)
	_check_ceiling(
		"elite enemies", _count_enemies(EnemyData.Tier.ELITE), ELITE_ENEMY_CEILING, messages
	)
	_check_ceiling(
		"boss enemies", _count_enemies(EnemyData.Tier.BOSS), BOSS_ENEMY_CEILING, messages
	)


static func _check_ceiling(
	label: String, count: int, ceiling: int, messages: Array[String]
) -> void:
	if count > ceiling:
		messages.append("%s: %d exceeds ceiling %d (PRD §2.1)" % [label, count, ceiling])


func _count_moves(category: MoveData.Category) -> int:
	var count: int = 0
	for move_data: MoveData in _moves:
		if move_data.category == category:
			count += 1
	return count


func _count_enemies(tier: EnemyData.Tier) -> int:
	var count: int = 0
	for enemy_data: EnemyData in _enemies:
		if enemy_data.tier == tier:
			count += 1
	return count
