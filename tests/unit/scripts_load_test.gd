extends TestCase
## Every script under src/ must compile, including ones no other test loads. Warnings the project
## treats as errors (untyped declarations, unsafe access, shadowing) fail here.


func test_every_src_script_compiles() -> void:
	for path: String in _scripts_under("res://src"):
		var script: GDScript = load(path)
		assert_true(script != null and script.can_instantiate(), "%s does not compile" % path)


func _scripts_under(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts_under(dir_path.path_join(sub_dir)))
	return found
