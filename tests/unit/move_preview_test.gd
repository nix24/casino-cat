extends TestCase
## The battle screen's numbers (PRD §4.3, §13.3, decisions D10): MovePreview against Sewer Rat with
## the shipped starter kit, and the `target` field the UI uses to pick a panel (T003).

const MOVE_IDS: Array[StringName] = [&"scratch", &"swipe", &"paw_roll", &"curl_up"]
const SLOT_SCRATCH: int = 0
const SLOT_SWIPE: int = 1
const SLOT_PAW_ROLL: int = 2
const SLOT_CURL_UP: int = 3


func test_sewer_rat_opening_previews() -> void:
	var ctx := _starter_context()
	var state: BattleState = BattleRules.start(_rat(), ctx, RngSet.for_seed("test").battle).state

	var scratch: MovePreview = BattleRules.preview_move(state, SLOT_SCRATCH, ctx)
	assert_eq(scratch.damage, 6, "scratch ♠ vs ♠ rat is neutral")
	assert_eq(scratch.hits, 1, "scratch hits")
	assert_eq(scratch.triangle_mult, 1.0, "scratch triangle")
	assert_eq(scratch.incoming_mult, 1.0, "♠ rat into ♠ cat")

	var swipe: MovePreview = BattleRules.preview_move(state, SLOT_SWIPE, ctx)
	assert_eq(swipe.damage, 11, "swipe ♦ beats ♠: 7 × 1.5 = 10.5 → 11")
	assert_eq(swipe.triangle_mult, 1.5, "swipe triangle")
	assert_eq(swipe.incoming_mult, 0.75, "♠ rat into ♦ cat")

	var paw_roll: MovePreview = BattleRules.preview_move(state, SLOT_PAW_ROLL, ctx)
	assert_eq(paw_roll.damage, 0, "gambles preview odds, not damage")
	assert_eq(paw_roll.hits, 0, "gambles don't hit directly")
	assert_eq(paw_roll.triangle_mult, 1.0, "gamble triangle")
	assert_eq(paw_roll.mp_cost, 30, "paw roll cost")
	assert_true(not paw_roll.affordable, "20 MP can't pay 30")
	assert_eq(paw_roll.missing_mp, 10, "need 10 more MP")
	assert_eq(paw_roll.odds.rows.size(), 6, "paw roll odds rows")

	var curl_up: MovePreview = BattleRules.preview_move(state, SLOT_CURL_UP, ctx)
	assert_eq(curl_up.damage, 0, "curl up deals nothing")
	assert_eq(curl_up.incoming_mult, 1.0, "♣ cat takes ×1.0")
	assert_eq(curl_up.missing_mp, 0, "free move")


func test_events_name_their_target() -> void:
	var ctx := _starter_context()
	var rngs := RngSet.for_seed("test")
	var state: BattleState = BattleRules.start(_rat(), ctx, rngs.battle).state
	var action := PlayerAction.new()
	action.slot = SLOT_CURL_UP
	var events: Array[BattleEvent] = BattleRules.apply(state, action, ctx, rngs)

	var shield: BattleEvent = _first(events, BattleEvent.Kind.SHIELD_GAINED)
	assert_eq(shield.target, BattleEvent.Actor.CAT, "curl up shields the cat")
	var hit: BattleEvent = _first(events, BattleEvent.Kind.DAMAGE_DEALT)
	assert_eq(hit.actor, BattleEvent.Actor.ENEMY, "the rat attacks")
	assert_eq(hit.target, BattleEvent.Actor.CAT, "the rat hits the cat")

	action.slot = SLOT_SWIPE
	events = BattleRules.apply(state, action, ctx, rngs)
	hit = _first(events, BattleEvent.Kind.DAMAGE_DEALT)
	assert_eq(hit.target, BattleEvent.Actor.ENEMY, "swipe hits the rat")


# --- helpers ---------------------------------------------------------------------------------


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


func _first(events: Array[BattleEvent], kind: BattleEvent.Kind) -> BattleEvent:
	for event: BattleEvent in events:
		if event.kind == kind:
			return event
	assert_true(false, "no %s event" % BattleEvent.Kind.keys()[kind])
	return BattleEvent.new(kind)
