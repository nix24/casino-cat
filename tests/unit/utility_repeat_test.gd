extends TestCase
## The utility repeat penalty (PRD §5.1, T051): the same utility move on consecutive turns halves
## its shield, heal, and MP each time (10 → 5 → 2 → 1 → 0). Lives apart from battle_rules_test
## because that file is at gdlint's 20-public-method limit.

const SCRATCH_PATH: String = "res://src/content/moves/scratch.tres"
const CURL_UP_PATH: String = "res://src/content/moves/curl_up.tres"
const THORNY_PATH: String = "res://src/content/modifiers/thorny.tres"
const FISH_SNACK_PATH: String = "res://src/content/items/fish_snack.tres"

const SLOT_SCRATCH: int = 0
const SLOT_CURL_UP: int = 1
const SLOT_TEST_MOVE: int = 2


func test_curl_up_halves_each_repeat() -> void:
	var fight := Fight.new(0)
	var gains: Array[int] = []
	for _turn: int in 5:
		gains.append_array(_shield_gains(fight.use(SLOT_CURL_UP)))
	var expected: Array[int] = [10, 5, 2, 1, 0]
	assert_eq(gains, expected, "10 → 5 → 2 → 1 → 0")


func test_other_move_resets_the_halving() -> void:
	var fight := Fight.new(0)
	var gains: Array[int] = []
	gains.append_array(_shield_gains(fight.use(SLOT_CURL_UP)))
	gains.append_array(_shield_gains(fight.use(SLOT_CURL_UP)))
	fight.use(SLOT_SCRATCH)
	gains.append_array(_shield_gains(fight.use(SLOT_CURL_UP)))
	var expected: Array[int] = [10, 5, 10]
	assert_eq(gains, expected, "Scratch in between restores the full 10")


func test_new_battle_resets_the_halving() -> void:
	var fight := Fight.new(0)
	fight.use(SLOT_CURL_UP)
	fight.use(SLOT_CURL_UP)
	var next_battle := Fight.new(0)
	assert_eq(_shield_gains(next_battle.use(SLOT_CURL_UP)), [10], "fresh battle, full shield")


func test_pouch_item_does_not_reset_the_halving() -> void:
	var fight := Fight.new(0)
	fight.ctx.pouch = [&"fish_snack", &"", &""]
	fight.ctx.items[&"fish_snack"] = load(FISH_SNACK_PATH) as ItemData
	fight.use(SLOT_CURL_UP)
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.USE_ITEM
	action.pouch_slot = 0
	BattleRules.apply(fight.state, action, fight.ctx, fight.rngs)
	assert_eq(_shield_gains(fight.use(SLOT_CURL_UP)), [5], "the item doesn't break the streak")


func test_status_and_turns_are_not_halved() -> void:
	var regen := EffectData.new()
	regen.kind = EffectData.Kind.STATUS
	regen.status = &"regen"
	regen.turns = 3
	var fight := Fight.new(0, _utility(&"test_shell", [_effect(EffectData.Kind.SHIELD, 8), regen]))
	fight.use(SLOT_TEST_MOVE)
	var events: Array[BattleEvent] = fight.use(SLOT_TEST_MOVE)
	assert_eq(_shield_gains(events), [4], "shield halves")
	var applied: Array[int] = []
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.STATUS_APPLIED:
			applied.append(event.turns)
	assert_eq(applied, [3], "regen keeps its 3 turns")


func test_heal_and_mp_gain_halve() -> void:
	var psych := _utility(&"test_psych", [_effect(EffectData.Kind.MP_GAIN, 25)])
	var fight := Fight.new(0, psych)
	assert_eq(_mp_from_move(fight.use(SLOT_TEST_MOVE)), 25, "first use")
	assert_eq(_mp_from_move(fight.use(SLOT_TEST_MOVE)), 12, "25 >> 1")

	var nap := _utility(&"test_nap", [_effect(EffectData.Kind.HEAL, 6)])
	var napping := Fight.new(0, nap)
	napping.state.cat.hp = 30
	napping.use(SLOT_TEST_MOVE)
	napping.use(SLOT_TEST_MOVE)
	assert_eq(napping.state.cat.hp, 39, "6 then 3")


func test_modifier_shield_is_not_halved() -> void:
	var fight := Fight.new(0)
	var thorny: ModifierData = load(THORNY_PATH) as ModifierData
	fight.ctx.modifiers[thorny.id] = thorny
	fight.state.equipped[SLOT_CURL_UP].modifier_ids.append(thorny.id)
	fight.use(SLOT_CURL_UP)
	var expected: Array[int] = [5, 4]
	assert_eq(_shield_gains(fight.use(SLOT_CURL_UP)), expected, "Curl Up halves, Thorny's 4 stays")


func test_preview_shows_the_halved_amount() -> void:
	var fight := Fight.new(0)
	var move: MoveData = fight.ctx.moves[&"curl_up"]
	var first: MovePreview = BattleRules.preview_move(fight.state, SLOT_CURL_UP, fight.ctx)
	assert_eq(first.effect_amounts, [10], "first use previews 10")
	assert_eq(MoveButton.preview_lines(move, first)[1], "+10 shield", "no repeat tag")
	fight.use(SLOT_CURL_UP)
	var second: MovePreview = BattleRules.preview_move(fight.state, SLOT_CURL_UP, fight.ctx)
	assert_eq(second.repeat_halvings, 1, "one halving")
	assert_eq(MoveButton.preview_lines(move, second)[1], "+5 shield (repeat ½)", "button text")
	fight.use(SLOT_CURL_UP)
	var third: MovePreview = BattleRules.preview_move(fight.state, SLOT_CURL_UP, fight.ctx)
	assert_eq(MoveButton.preview_lines(move, third)[1], "+2 shield (repeat 1/4)", "third use")


## T051's worked example: a 6-damage enemy, Curl Up every turn.
func test_worked_example_curl_up_stall() -> void:
	var fight := Fight.new(6)
	var shield_after: Array[int] = []
	var hp_lost: Array[int] = []
	for _turn: int in 6:
		var hp_before: int = fight.state.cat.hp
		fight.use(SLOT_CURL_UP)
		shield_after.append(fight.state.cat.shield)
		hp_lost.append(hp_before - fight.state.cat.hp)
	var expected_shield: Array[int] = [4, 3, 0, 0, 0, 0]
	var expected_lost: Array[int] = [0, 0, 1, 5, 6, 6]
	assert_eq(shield_after, expected_shield, "shield after the hit")
	assert_eq(hp_lost, expected_lost, "HP lost per turn")


func test_alternating_keeps_the_full_shield() -> void:
	var fight := Fight.new(6)
	var gains: Array[int] = []
	for _round: int in 3:
		gains.append_array(_shield_gains(fight.use(SLOT_CURL_UP)))
		fight.use(SLOT_SCRATCH)
	var expected: Array[int] = [10, 10, 10]
	assert_eq(gains, expected, "Curl Up between attacks stays at 10")


# --- helpers ---------------------------------------------------------------------------------


func _utility(id: StringName, effects: Array[EffectData]) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.suit = Suit.Type.CLUBS
	move.category = MoveData.Category.UTILITY
	move.effects = effects
	return move


func _effect(kind: EffectData.Kind, amount: int) -> EffectData:
	var effect := EffectData.new()
	effect.kind = kind
	effect.amount = amount
	return effect


func _shield_gains(events: Array[BattleEvent]) -> Array[int]:
	var gains: Array[int] = []
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.SHIELD_GAINED and event.actor == BattleEvent.Actor.CAT:
			gains.append(event.amount)
	return gains


func _mp_from_move(events: Array[BattleEvent]) -> int:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.MP_CHANGED and event.reason == &"move":
			return event.amount
	return 0


## A ♣ 999-HP dummy that attacks for [param attack] every turn, against Scratch, Curl Up, and
## an optional test move in slot 2.
class Fight:
	extends RefCounted
	var ctx := BattleContext.new()
	var state: BattleState
	var rngs: RngSet = RngSet.for_seed("UTILITY")

	func _init(attack: int, extra: MoveData = null) -> void:
		var moves: Array[MoveData] = [load(SCRATCH_PATH), load(CURL_UP_PATH)]
		if extra != null:
			moves.append(extra)
		for move: MoveData in moves:
			ctx.moves[move.id] = move
			var instance := MoveInstance.new()
			instance.move_id = move.id
			ctx.loadout.append(instance)
		var intent := IntentData.new()
		intent.kind = IntentData.Kind.ATTACK
		intent.amount = attack
		var enemy := EnemyData.new()
		enemy.max_hp = 999
		enemy.suit = Suit.Type.CLUBS
		enemy.pattern = [intent]
		state = BattleRules.start(enemy, ctx, rngs.battle).state

	func use(slot: int) -> Array[BattleEvent]:
		var action := PlayerAction.new()
		action.kind = PlayerAction.Kind.USE_MOVE
		action.slot = slot
		return BattleRules.apply(state, action, ctx, rngs)
