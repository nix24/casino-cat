extends TestCase
## ContentDb lookups and validate() messages (T004). Fixtures are copies of the real content or
## fresh resources, so the cached resources ResourceLoader hands out are never changed.

const TUNING_PATH: String = "res://src/content/tuning.tres"


func test_load_all_finds_starter_content() -> void:
	var db: ContentDb = ContentDb.load_all()
	assert_eq(
		_ids_of_moves(db.all_moves()),
		[&"curl_up", &"loaded_paws", &"paw_roll", &"scratch", &"snake_eyes", &"swipe"],
		"move ids"
	)
	assert_eq(
		_ids_of_enemies(db.all_enemies()),
		[&"junkyard_pup", &"pickpocket_pigeon", &"sewer_rat"],
		"enemy ids"
	)
	assert_eq(db.tuning().resource_path, TUNING_PATH, "tuning path")


func test_real_content_validates_empty() -> void:
	var messages: PackedStringArray = ContentDb.load_all().validate()
	assert_eq(messages.size(), 0, "; ".join(messages))


func test_lookup_missing_id_returns_null() -> void:
	var db: ContentDb = ContentDb.load_all()
	assert_true(db.move(&"nope") == null, "missing move")
	assert_true(db.enemy(&"nope") == null, "missing enemy")
	assert_eq(db.move(&"swipe").id, &"swipe", "swipe lookup")


func test_validate_catches_duplicate_move_id() -> void:
	var db: ContentDb = ContentDb.load_all()
	var moves: Array[MoveData] = db.all_moves()
	moves.append(_copy_move(db.move(&"scratch")))
	var messages: PackedStringArray = _validate(moves, db.all_enemies(), db.tuning())
	assert_eq(_count_containing(messages, "duplicate"), 1, "duplicate message count")
	assert_true(messages.has("duplicate move id: scratch"), "; ".join(messages))


func test_validate_catches_bad_move_status() -> void:
	var db: ContentDb = ContentDb.load_all()
	var move := MoveData.new()
	move.id = &"bad_status_move"
	var effect := EffectData.new()
	effect.kind = EffectData.Kind.STATUS
	effect.status = &"bogus"
	move.effects.append(effect)
	var moves: Array[MoveData] = db.all_moves()
	moves.append(move)
	var messages: PackedStringArray = _validate(moves, db.all_enemies(), db.tuning())
	assert_true(messages.has("move bad_status_move: unknown status bogus"), "; ".join(messages))


func test_validate_catches_bad_intents() -> void:
	var db: ContentDb = ContentDb.load_all()
	var debuff := IntentData.new()
	debuff.kind = IntentData.Kind.DEBUFF
	debuff.status = &"bogus"
	debuff.turns = 0
	var steal := IntentData.new()
	steal.kind = IntentData.Kind.STEAL_MP
	steal.amount = 0
	var enemy := EnemyData.new()
	enemy.id = &"bad_enemy"
	enemy.act = 1
	enemy.tier = EnemyData.Tier.NORMAL
	enemy.pattern.append(debuff)
	enemy.pattern.append(steal)
	var enemies: Array[EnemyData] = db.all_enemies()
	enemies.append(enemy)
	var messages: PackedStringArray = _validate(db.all_moves(), enemies, db.tuning())
	assert_true(messages.has("enemy bad_enemy: unknown status bogus"), "; ".join(messages))
	assert_true(messages.has("enemy bad_enemy: DEBUFF intent needs turns > 0"), "; ".join(messages))
	assert_true(
		messages.has("enemy bad_enemy: STEAL_MP intent needs amount > 0"), "; ".join(messages)
	)


func test_validate_catches_triangle_above_cap() -> void:
	var db: ContentDb = ContentDb.load_all()
	var tuning: TuningData = _tuning_copy(db)
	tuning.triangle_advantage = 1.6
	var messages: PackedStringArray = _validate(db.all_moves(), db.all_enemies(), tuning)
	assert_true(
		messages.has("triangle_advantage 1.6 exceeds cap 1.5 (PRD §4.3)"), "; ".join(messages)
	)


func test_validate_catches_probability_cap_and_repeat_penalty() -> void:
	var db: ContentDb = ContentDb.load_all()
	var tuning: TuningData = _tuning_copy(db)
	tuning.probability_cap = 0.97
	tuning.repeat_penalty = PackedFloat32Array([1.0, 1.0, 0.75])
	var messages: PackedStringArray = _validate(db.all_moves(), db.all_enemies(), tuning)
	assert_true(
		messages.has("probability_cap 0.97 is outside (0, 0.95] (PRD §6.0)"), "; ".join(messages)
	)
	assert_true(
		messages.has("repeat_penalty has 3 entries, needs 4 (PRD §4.4)"), "; ".join(messages)
	)


func test_validate_flags_unwired_tuning() -> void:
	var db: ContentDb = ContentDb.load_all()
	var tuning: TuningData = _tuning_copy(db)
	tuning.triangle_disadvantage = 0.8
	var messages: PackedStringArray = _validate(db.all_moves(), db.all_enemies(), tuning)
	assert_eq(
		_count_containing(messages, "triangle_disadvantage 0.8 differs from"),
		1,
		"; ".join(messages)
	)
	assert_eq(_count_containing(messages, "exceeds cap"), 0, "; ".join(messages))


func test_validate_catches_gamble_base_damage_mismatch() -> void:
	var db: ContentDb = ContentDb.load_all()
	var copy: MoveData = _copy_move(db.move(&"paw_roll"))
	copy.id = &"paw_roll_copy"
	copy.base_damage = 12
	var bare := MoveData.new()
	bare.id = &"bare_gamble"
	bare.category = MoveData.Category.GAMBLE
	var moves: Array[MoveData] = db.all_moves()
	moves.append(copy)
	moves.append(bare)
	var messages: PackedStringArray = _validate(moves, db.all_enemies(), db.tuning())
	assert_true(
		messages.has("move paw_roll_copy: base_damage 12 differs from gamble base_damage 10"),
		"; ".join(messages)
	)
	assert_true(
		messages.has("move bare_gamble: GAMBLE move has no gamble data"), "; ".join(messages)
	)


func test_validate_catches_basic_move_ceiling() -> void:
	var db: ContentDb = ContentDb.load_all()
	var moves: Array[MoveData] = db.all_moves()
	# The starter pool already has two basic moves (scratch, swipe); 11 more makes 13.
	for index: int in 11:
		var basic := MoveData.new()
		basic.id = StringName("basic_test_%d" % index)
		basic.category = MoveData.Category.BASIC
		moves.append(basic)
	var messages: PackedStringArray = _validate(moves, db.all_enemies(), db.tuning())
	assert_true(messages.has("basic moves: 13 exceeds ceiling 12 (PRD §2.1)"), "; ".join(messages))


func test_first_battle_pool_reports_missing_and_wrong_act() -> void:
	var db: ContentDb = ContentDb.load_all()
	var rat: EnemyData = _copy_enemy(db.enemy(&"sewer_rat"))
	var pigeon: EnemyData = _copy_enemy(db.enemy(&"pickpocket_pigeon"))
	pigeon.act = 2
	var enemies: Array[EnemyData] = [rat, pigeon]
	var messages: PackedStringArray = _validate(db.all_moves(), enemies, db.tuning())
	assert_true(messages.has("first-battle pool is missing junkyard_pup"), "; ".join(messages))
	assert_true(
		messages.has("first-battle enemy pickpocket_pigeon is act 2, not act 1"),
		"; ".join(messages)
	)


func test_first_battle_pool_check_passes_at_m1() -> void:
	var messages: PackedStringArray = ContentDb.load_all().validate()
	assert_eq(_count_containing(messages, "first-battle"), 0, "; ".join(messages))


func test_tuning_tres_equals_defaults() -> void:
	var defaults := TuningData.new()
	var loaded: TuningData = ContentDb.load_all().tuning()
	var compared: int = 0
	for info: Dictionary in defaults.get_property_list():
		var usage: int = info["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var property_name: String = info["name"]
		var expected: Variant = defaults.get(property_name)
		var actual: Variant = loaded.get(property_name)
		assert_eq(actual, expected, property_name)
		compared += 1
	assert_true(compared >= 30, "compared %d tuning fields" % compared)


func test_moves_by_rarity_category() -> void:
	var db: ContentDb = ContentDb.load_all()
	assert_eq(
		_ids_of_moves(db.moves_by(MoveData.Rarity.STARTER, MoveData.Category.BASIC)),
		[&"scratch", &"swipe"],
		"starter basic"
	)
	assert_eq(
		_ids_of_moves(db.moves_by(MoveData.Rarity.STARTER, MoveData.Category.UTILITY)),
		[&"curl_up"],
		"starter utility"
	)
	assert_eq(
		_ids_of_moves(db.moves_by(MoveData.Rarity.RARE, MoveData.Category.GAMBLE)),
		[&"snake_eyes"],
		"rare gamble"
	)
	assert_eq(
		db.moves_by(MoveData.Rarity.COMMON, MoveData.Category.BASIC).size(), 0, "common basic"
	)


func test_enemies_for_act1_normal() -> void:
	var db: ContentDb = ContentDb.load_all()
	assert_eq(
		_ids_of_enemies(db.enemies_for(1, EnemyData.Tier.NORMAL)),
		[&"junkyard_pup", &"pickpocket_pigeon", &"sewer_rat"],
		"act 1 normal"
	)
	assert_eq(db.enemies_for(2, EnemyData.Tier.NORMAL).size(), 0, "act 2 normal")
	assert_eq(db.enemies_for(1, EnemyData.Tier.BOSS).size(), 0, "act 1 boss")


func _validate(
	moves: Array[MoveData], enemies: Array[EnemyData], tuning_data: TuningData
) -> PackedStringArray:
	return ContentDb.from_parts(moves, enemies, tuning_data).validate()


func _tuning_copy(db: ContentDb) -> TuningData:
	return db.tuning().duplicate(true) as TuningData


func _copy_move(source: MoveData) -> MoveData:
	return source.duplicate(true) as MoveData


func _copy_enemy(source: EnemyData) -> EnemyData:
	return source.duplicate(true) as EnemyData


func _ids_of_moves(moves: Array[MoveData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for move_data: MoveData in moves:
		ids.append(move_data.id)
	return ids


func _ids_of_enemies(enemies: Array[EnemyData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for enemy_data: EnemyData in enemies:
		ids.append(enemy_data.id)
	return ids


func _count_containing(messages: PackedStringArray, needle: String) -> int:
	var count: int = 0
	for message: String in messages:
		if message.contains(needle):
			count += 1
	return count
