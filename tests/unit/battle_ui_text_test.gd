extends TestCase
## Text the battle UI shows, checked against the R1 opening screen with Sewer Rat (T003, R1, R11).

const MOVE_IDS: Array[StringName] = [&"scratch", &"swipe", &"paw_roll", &"curl_up"]
const SLOT_SCRATCH: int = 0
const SLOT_SWIPE: int = 1
const SLOT_PAW_ROLL: int = 2
const SLOT_CURL_UP: int = 3


func test_move_button_lines_vs_sewer_rat() -> void:
	var ctx := _starter_context()
	var state: BattleState = BattleRules.start(_rat(), ctx, RngSet.for_seed("test").battle).state

	assert_eq(
		_lines(state, ctx, SLOT_SCRATCH),
		PackedStringArray(["Scratch ♠", "6 → 6 (×1.0)", "their hit ×1.0"]),
		"scratch"
	)
	assert_eq(
		_lines(state, ctx, SLOT_SWIPE),
		PackedStringArray(["Swipe ♦", "7 → 11 (×1.5)", "their hit ×0.75"]),
		"swipe"
	)
	assert_eq(
		_lines(state, ctx, SLOT_PAW_ROLL),
		PackedStringArray(["Paw Roll ♣", "30 MP · odds", "their hit ×1.0"]),
		"paw roll"
	)
	assert_eq(
		_lines(state, ctx, SLOT_CURL_UP),
		PackedStringArray(["Curl Up ♣", "+10 shield", "their hit ×1.0"]),
		"curl up"
	)

	var button := MoveButton.new()
	button.setup(SLOT_PAW_ROLL, ctx.moves[&"paw_roll"])
	button.set_preview(BattleRules.preview_move(state, SLOT_PAW_ROLL, ctx))
	assert_eq(button.tooltip_text, "need 10 more MP", "paw roll tooltip")
	assert_true(not button.can_pay(), "20 MP can't pay 30")
	button.free()


func test_odds_row_text() -> void:
	var ctx := _starter_context()
	var state: BattleState = BattleRules.start(_rat(), ctx, RngSet.for_seed("test").battle).state
	var odds: GambleOdds = BattleRules.preview_move(state, SLOT_PAW_ROLL, ctx).odds

	assert_eq(
		OddsTable.row_text(_row(odds, &"Snake eyes")),
		"Snake eyes  2.8%  0  −4 HP",
		"snake eyes row"
	)
	assert_eq(OddsTable.row_text(_row(odds, &"Fair")), "Fair  44.4%  10", "fair row")


func test_strings_mult() -> void:
	assert_eq(Strings.mult(1.0), "×1.0", "neutral")
	assert_eq(Strings.mult(0.75), "×0.75", "disadvantage")
	assert_eq(Strings.mult(1.5), "×1.5", "advantage")


func test_intent_text() -> void:
	var attack := BattleEvent.new(BattleEvent.Kind.INTENT_SHOWN, BattleEvent.Actor.ENEMY)
	attack.reason = &"attack"
	attack.amount = 5
	assert_eq(Strings.intent_text(attack, Suit.Type.SPADES), "⚔ ♠ 5", "attack")

	var guard := BattleEvent.new(BattleEvent.Kind.INTENT_SHOWN, BattleEvent.Actor.ENEMY)
	guard.reason = &"guard"
	guard.amount = 6
	assert_eq(Strings.intent_text(guard, Suit.Type.SPADES), "🛡 6", "guard")


func test_status_and_due_text() -> void:
	var no_statuses: Dictionary[StringName, int] = {}
	assert_eq(Strings.status_text(no_statuses), "—", "no statuses")
	var statuses: Dictionary[StringName, int] = {&"weak": 2, &"regen": 1}
	assert_eq(Strings.status_text(statuses), "weak 2 · regen 1", "two statuses")
	assert_eq(Strings.due_text(2, 4), "Due ●●○○", "due 2 of 4")


# --- helpers ---------------------------------------------------------------------------------


func _lines(state: BattleState, ctx: BattleContext, slot: int) -> PackedStringArray:
	var move: MoveData = ctx.moves[ctx.loadout[slot].move_id]
	return MoveButton.preview_lines(move, BattleRules.preview_move(state, slot, ctx))


func _row(odds: GambleOdds, label: StringName) -> GambleOddsRow:
	for row: GambleOddsRow in odds.rows:
		if row.label == label:
			return row
	assert_true(false, "no odds row named %s" % label)
	return GambleOddsRow.new()


func _starter_context() -> BattleContext:
	var ctx := BattleContext.new()
	for id: StringName in MOVE_IDS:
		var move: MoveData = load("res://src/content/moves/%s.tres" % id)
		ctx.moves[id] = move
		var instance := MoveInstance.new()
		instance.move_id = id
		ctx.loadout.append(instance)
	return ctx


func _rat() -> EnemyData:
	return load("res://src/content/enemies/sewer_rat.tres")
