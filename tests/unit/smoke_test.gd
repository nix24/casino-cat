extends TestCase
## The main scene must load and carry the "no real money" notice (PRD: Responsible theming).


func test_main_scene_loads_with_notice() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var scene: PackedScene = load(main_path)
	assert_true(scene != null, "main scene %s failed to load" % main_path)
	if scene == null:
		return
	var root: Node = scene.instantiate()
	var notice: Label = root.get_node_or_null("%NoRealMoney")
	assert_true(notice != null and notice.text.contains("No real money"))
	root.free()
