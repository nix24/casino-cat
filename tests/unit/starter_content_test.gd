extends TestCase
## The starter moves and first-battle enemies load from src/content with the content-registry
## values (T001 R10, R11).

const SCRATCH_PATH: String = "res://src/content/moves/scratch.tres"
const SWIPE_PATH: String = "res://src/content/moves/swipe.tres"
const CURL_UP_PATH: String = "res://src/content/moves/curl_up.tres"
const SEWER_RAT_PATH: String = "res://src/content/enemies/sewer_rat.tres"
const PIGEON_PATH: String = "res://src/content/enemies/pickpocket_pigeon.tres"
const PUP_PATH: String = "res://src/content/enemies/junkyard_pup.tres"


func test_starter_content_loads() -> void:
	var scratch: MoveData = _load_move(SCRATCH_PATH)
	assert_true(scratch != null, "scratch loads")
	if scratch != null:
		assert_eq(scratch.id, &"scratch", "scratch id")
		assert_eq(scratch.display_name, "Scratch", "scratch name")
		assert_eq(scratch.suit, Suit.Type.SPADES, "scratch suit")
		assert_eq(scratch.category, MoveData.Category.BASIC, "scratch category")
		assert_eq(scratch.base_damage, 6, "scratch damage")
		assert_eq(scratch.effects.size(), 0, "scratch has no effects")

	var swipe: MoveData = _load_move(SWIPE_PATH)
	assert_true(swipe != null, "swipe loads")
	if swipe != null:
		assert_eq(swipe.suit, Suit.Type.DIAMONDS, "swipe suit")
		assert_eq(swipe.base_damage, 7, "swipe damage")
		assert_eq(swipe.effects.size(), 1, "swipe effect count")
		assert_eq(swipe.effects[0].kind, EffectData.Kind.MP_GAIN, "swipe effect kind")
		assert_eq(swipe.effects[0].amount, 6, "swipe mp gain")

	var curl_up: MoveData = _load_move(CURL_UP_PATH)
	assert_true(curl_up != null, "curl up loads")
	if curl_up != null:
		assert_eq(curl_up.category, MoveData.Category.UTILITY, "curl up category")
		assert_eq(curl_up.suit, Suit.Type.CLUBS, "curl up suit")
		assert_eq(curl_up.effects.size(), 1, "curl up effect count")
		assert_eq(curl_up.effects[0].kind, EffectData.Kind.SHIELD, "curl up effect kind")
		assert_eq(curl_up.effects[0].amount, 10, "curl up shield")

	var rat: EnemyData = _load_enemy(SEWER_RAT_PATH)
	assert_true(rat != null, "sewer rat loads")
	if rat != null:
		assert_eq(rat.display_name, "Sewer Rat", "rat name")
		assert_eq(rat.suit, Suit.Type.SPADES, "rat suit")
		assert_eq(rat.max_hp, 22, "rat hp")
		assert_true(rat.first_battle_pool, "rat in first-battle pool")
		assert_eq(_intent_amounts(rat), [5, 5, 8], "rat attacks")

	var pigeon: EnemyData = _load_enemy(PIGEON_PATH)
	assert_true(pigeon != null, "pigeon loads")
	if pigeon != null:
		assert_eq(pigeon.display_name, "Pickpocket Pigeon", "pigeon name")
		assert_eq(pigeon.suit, Suit.Type.HEARTS, "pigeon suit")
		assert_eq(pigeon.max_hp, 20, "pigeon hp")
		assert_eq(pigeon.pattern[1].kind, IntentData.Kind.STEAL_MP, "pigeon middle intent")
		assert_eq(pigeon.pattern[1].amount, 10, "pigeon steal amount")

	var pup: EnemyData = _load_enemy(PUP_PATH)
	assert_true(pup != null, "pup loads")
	if pup != null:
		assert_eq(pup.display_name, "Junkyard Pup", "pup name")
		assert_eq(pup.suit, Suit.Type.SPADES, "pup suit")
		assert_eq(pup.max_hp, 28, "pup hp")
		assert_eq(pup.pattern[0].kind, IntentData.Kind.DEBUFF, "pup opens with a debuff")
		assert_eq(pup.pattern[0].status, &"weak", "pup debuff status")
		assert_eq(pup.pattern[0].turns, 2, "pup debuff turns")


func _load_move(path: String) -> MoveData:
	return load(path) as MoveData


func _load_enemy(path: String) -> EnemyData:
	return load(path) as EnemyData


func _intent_amounts(enemy: EnemyData) -> Array[int]:
	var amounts: Array[int] = []
	for intent: IntentData in enemy.pattern:
		amounts.append(intent.amount)
	return amounts
