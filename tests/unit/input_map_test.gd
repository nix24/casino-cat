extends TestCase
## Controller bindings (PRD §13, §17.1). A gamepad must work whatever its device number, and A / B
## must drive focused buttons, because Godot's default ui_accept and ui_cancel have no gamepad.

## Godot's InputMap value for "any device".
const ALL_DEVICES: int = -1


func test_every_gamepad_binding_matches_any_device() -> void:
	for action: StringName in _project_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				assert_eq(event.device, ALL_DEVICES, "%s binds one pad only" % action)


func test_accept_and_cancel_have_a_and_b() -> void:
	assert_true(_has_button(&"ui_accept", JOY_BUTTON_A), "ui_accept needs A")
	assert_true(_has_button(&"ui_cancel", JOY_BUTTON_B), "ui_cancel needs B")
	assert_true(_has_button(&"confirm", JOY_BUTTON_A), "confirm needs A")
	assert_true(_has_button(&"cancel", JOY_BUTTON_B), "cancel needs B")


# --- helpers ---------------------------------------------------------------------------------


## Actions written in project.godot, including the ui_* ones it overrides.
func _project_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var name: String = property["name"]
		if name.begins_with("input/"):
			actions.append(StringName(name.trim_prefix("input/")))
	return actions


func _has_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var pad_button := event as InputEventJoypadButton
		if pad_button != null and pad_button.button_index == button:
			return true
	return false
