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
		"Swipe ♦\n7 → 11 (×1.5)\ntheir hit ×0.75",
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


func test_confirm_skips_and_tab_cycles_speed() -> void:
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
	assert_eq((scene.get_node("%SpeedLabel") as Label).text, "speed: 2×", "speed label")
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
