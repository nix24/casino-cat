extends TestCase
## The battle screen opens and plays out with its own scene defaults (T003, R1, R10). Instant speed
## keeps every step synchronous, so no frames need to run.

const BATTLE_PATH: String = "res://src/scenes/battle/battle.tscn"
const SLOT_SWIPE: int = 1
const SLOT_PAW_ROLL: int = 2


func test_opening_screen() -> void:
	var scene: BattleScene = _open_battle()
	assert_eq(_intent_text(scene), "⚔ ♠ 5", "opening intent")
	assert_eq(
		_move_button(scene, SLOT_SWIPE).text,
		"Swipe ♦\n7 → 11 (♦ beats ♠ ×1.5)\ntheir hit ♦ resists ♠ ×0.75",
		"swipe lines"
	)
	assert_true(_move_button(scene, SLOT_PAW_ROLL).disabled, "paw roll needs 10 more MP")
	_close_battle(scene)


func test_two_swipes_win() -> void:
	var scene: BattleScene = _open_battle()
	var outcomes: Array[BattleState.Outcome] = []
	scene.battle_finished.connect(
		func(outcome: BattleState.Outcome) -> void: outcomes.append(outcome)
	)
	scene.use_move(SLOT_SWIPE)
	scene.use_move(SLOT_SWIPE)
	assert_eq(outcomes, [BattleState.Outcome.WON], "battle_finished(WON) once")
	assert_eq((scene.get_node("%Banner") as Label).text, "Won", "banner")
	assert_eq(_intent_text(scene), "", "no intent after the battle ends")
	assert_eq(_enemy_hp_text(scene), "0/22", "enemy hp")
	_close_battle(scene)


func test_confirm_skips_and_toggle_speed_cycles() -> void:
	var scene: BattleScene = _open_battle(EventPlayer.SPEED_NORMAL)
	var player := scene.get_node("%EventPlayer") as EventPlayer
	assert_true(not player.is_idle(), "the opening plays at 1x")
	_press(&"confirm")
	assert_true(player.is_idle(), "confirm skips the opening")
	assert_eq(_intent_text(scene), "⚔ ♠ 5", "skipped opening still shows the intent")

	scene.use_move(SLOT_SWIPE)
	assert_true(not player.is_idle(), "the swipe turn plays at 1x")
	_press(&"confirm")
	assert_true(player.is_idle(), "confirm skips the turn")
	assert_eq(_enemy_hp_text(scene), "11/22", "skip lands on the final values")
	assert_true(not _move_button(scene, SLOT_SWIPE).disabled, "input is back on")

	_press(&"toggle_speed")
	assert_eq(scene.speed, EventPlayer.SPEED_DOUBLE, "toggle_speed cycles 1x to 2x")
	assert_eq((scene.get_node("%SpeedButton") as Button).text, "speed: 2× [F]", "speed button")
	_close_battle(scene)


func test_speed_button_cycles_back_to_1x() -> void:
	var scene: BattleScene = _open_battle(EventPlayer.SPEED_NORMAL)
	var button := scene.get_node("%SpeedButton") as Button
	for press: int in 3:
		button.pressed.emit()
	assert_eq(scene.speed, EventPlayer.SPEED_NORMAL, "three presses come back to 1x")
	assert_eq(button.text, "speed: 1× [F]", "button text")
	_close_battle(scene)


func test_setup_uses_given_context() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("KITTY-7731", db.tuning())
	run.equipped.reverse()
	var scene := (load(BATTLE_PATH) as PackedScene).instantiate() as BattleScene
	scene.speed = EventPlayer.SPEED_INSTANT
	var ctx := BattleContext.from_run(run, db)
	scene.setup(db.enemy(&"sewer_rat"), ctx, RngSet.for_seed("KITTY-7731"))
	var speeds: Array[int] = []
	scene.speed_changed.connect(func(new_speed: int) -> void: speeds.append(new_speed))
	_root().add_child(scene)

	assert_true(
		_move_button(scene, 0).text.begins_with("Curl Up"), "slot 1 shows the given loadout"
	)
	_press(&"toggle_speed")
	assert_eq(speeds, [EventPlayer.SPEED_NORMAL], "speed_changed emits the new speed")
	_close_battle(scene)


func test_short_loadout_hides_spare_buttons() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("KITTY-7731", db.tuning())
	run.equipped.remove_at(3)
	var scene := (load(BATTLE_PATH) as PackedScene).instantiate() as BattleScene
	scene.speed = EventPlayer.SPEED_INSTANT
	scene.setup(
		db.enemy(&"sewer_rat"), BattleContext.from_run(run, db), RngSet.for_seed("KITTY-7731")
	)
	_root().add_child(scene)

	assert_true(not _move_button(scene, 3).visible, "the 4th button is hidden")
	assert_true(_move_button(scene, 3).disabled, "the 4th button is disabled")
	assert_true(_move_button(scene, 2).visible, "the 3rd button stays")
	assert_eq(
		_move_button(scene, 2).find_valid_focus_neighbor(SIDE_RIGHT),
		_move_button(scene, 0),
		"right from the 3rd button wraps to the 1st"
	)
	assert_eq(
		_move_button(scene, 0).find_valid_focus_neighbor(SIDE_LEFT),
		_move_button(scene, 2),
		"left from the 1st button wraps to the 3rd"
	)
	scene.use_move(3)
	scene.use_move(SLOT_SWIPE)
	assert_eq(_enemy_hp_text(scene), "11/22", "a swipe still lands with 3 moves")
	_close_battle(scene)


func test_action_sent_once_per_accepted_move() -> void:
	var scene: BattleScene = _open_battle()
	var sent: Array[PlayerAction] = []
	scene.action_sent.connect(func(action: PlayerAction) -> void: sent.append(action))
	scene.use_move(SLOT_SWIPE)
	assert_eq(sent.size(), 1, "one accepted move, one action_sent")
	assert_eq(sent[0].kind, PlayerAction.Kind.USE_MOVE, "action kind")
	assert_eq(sent[0].slot, SLOT_SWIPE, "action slot")
	_close_battle(scene)


func test_pouch_item_use_empties_the_slot() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("KITTY-7731", db.tuning())
	run.pouch[0] = &"fish_snack"
	var scene := (load(BATTLE_PATH) as PackedScene).instantiate() as BattleScene
	scene.speed = EventPlayer.SPEED_INSTANT
	var ctx := BattleContext.from_run(run, db)
	scene.setup(db.enemy(&"sewer_rat"), ctx, RngSet.for_seed("KITTY-7731"))
	_root().add_child(scene)
	var bar := scene.get_node("%Pouch") as PouchBar
	var slot_button := bar.find_child("Slot1", true, false) as Button

	assert_true(not slot_button.disabled, "a filled slot is enabled")
	assert_eq(slot_button.text, "FS", "the slot shows the item's initials")
	bar.item_chosen.emit(0, 0)
	assert_eq(ctx.pouch[0], &"", "the slot empties")
	assert_eq(slot_button.text, Strings.POUCH_EMPTY, "the bar redraws the empty slot")
	assert_true(slot_button.disabled, "an empty slot is disabled")
	_close_battle(scene)


# --- helpers ---------------------------------------------------------------------------------


func _open_battle(at_speed: int = EventPlayer.SPEED_INSTANT) -> BattleScene:
	var scene := (load(BATTLE_PATH) as PackedScene).instantiate() as BattleScene
	scene.speed = at_speed
	_root().add_child(scene)
	return scene


func _close_battle(scene: BattleScene) -> void:
	_root().remove_child(scene)
	scene.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _move_button(scene: BattleScene, slot: int) -> MoveButton:
	return scene.get_node("%%Move%d" % (slot + 1)) as MoveButton


func _intent_text(scene: BattleScene) -> String:
	var panel := scene.get_node("%EnemyPanel") as CombatantPanel
	return (panel.find_child("IntentLabel", true, false) as Label).text


func _enemy_hp_text(scene: BattleScene) -> String:
	var panel := scene.get_node("%EnemyPanel") as CombatantPanel
	return (panel.find_child("HpLabel", true, false) as Label).text


## Sends [param action] through the viewport, so it reaches BattleScene._input like a real press.
func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_root().push_input(event)
