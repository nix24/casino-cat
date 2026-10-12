extends TestCase
## The rest screen naps and practices through RunRules, and disables Practice with no free slot
## (T016).

const REST_PATH: String = "res://src/scenes/rest/rest.tscn"


func test_nap_button_heals_and_finishes() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("REST-1", db.tuning())
	run.hp = 41
	run.node_state = RunState.NodeState.REST
	var scene := _scene(run, db)
	var finishes: Array[int] = []
	scene.finished.connect(func() -> void: finishes.append(1))
	var nap: Button = scene.get_node("%Nap")
	assert_eq(nap.text, "Nap · heal 18 HP", "nap label")

	nap.pressed.emit()
	assert_eq(run.hp, 59, "healed 18")
	assert_eq(run.node_state, RunState.NodeState.MAP, "rest ends")
	assert_eq(finishes.size(), 1, "finished emitted once")
	_free(scene)


func test_practice_disabled_when_every_move_is_full() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("REST-2", db.tuning())
	run.node_state = RunState.NodeState.REST
	for instance: MoveInstance in run.equipped:
		instance.modifier_ids = [&"thorny", &"quick_draw"]
	var scene := _scene(run, db)
	var practice: Button = scene.get_node("%Practice")
	assert_true(practice.disabled, "practice disabled")
	assert_eq(practice.tooltip_text, Strings.REST_NO_FREE_SLOT, "says why")
	_free(scene)


func _scene(run: RunState, db: ContentDb) -> RestScene:
	var scene := (load(REST_PATH) as PackedScene).instantiate() as RestScene
	scene.show_rest(run, db)
	_root().add_child(scene)
	return scene


func _free(scene: RestScene) -> void:
	_root().remove_child(scene)
	scene.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
