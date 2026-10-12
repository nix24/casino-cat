extends TestCase
## The event screen shows true odds, flags choices the cat can't take, and prints HP losses with the
## 1 HP floor (T017, PRD §10.3, D18, D35).

const EVENT_PATH: String = "res://src/scenes/event/event.tscn"


func test_odds_text_lists_every_outcome() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("EVENT-1", db.tuning())
	var event: EventData = db.event(&"e02_dumpster_dice")
	assert_eq(
		Strings.event_odds(event.choices[1], run, db),
		"41.7% −5 HP · 41.7% +20 Purrls · 16.7% +30 Purrls",
		"gamble odds"
	)
	assert_eq(Strings.event_odds(event.choices[0], run, db), "+6 HP", "safe choice")


func test_hp_loss_shows_the_floor() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("EVENT-2", db.tuning())
	run.hp = 3
	var choice: EventChoiceData = db.event(&"e01_sals_shell_game").choices[1]
	assert_true(Strings.event_odds(choice, run, db).contains("−6 HP (→ 1 HP)"), "floor shown")


func test_unaffordable_choice_is_disabled_with_a_reason() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("EVENT-3", db.tuning())
	run.purrls = 10
	run.node_state = RunState.NodeState.EVENT
	var scene := (load(EVENT_PATH) as PackedScene).instantiate() as EventScene
	scene.show_event(run, db, db.event(&"e03_chalk_artist"), SeededRng.new("EVENT-3"))
	_root().add_child(scene)
	var choices: VBoxContainer = scene.get_node("%Choices")
	var pay: Button = choices.get_child(0)
	assert_true(pay.text.begins_with("Pay 25 Purrls"), "first choice is Pay")
	assert_true(pay.disabled, "pay disabled")
	assert_true(pay.text.contains("Need 15 more Purrls."), "says why")
	_root().remove_child(scene)
	scene.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
