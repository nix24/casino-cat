class_name SettingsStub
extends Control
## Placeholder until the settings screen lands in M3. It offers the save code panel and a way back.

## Emitted by Back when [member is_overlay] is set; Game then frees the stub (D55).
signal closed

const TITLE_SCENE: String = "res://src/scenes/title/title.tscn"

## True when Game opened this stub over the pause menu, so Back closes it instead of going to the
## title.
var is_overlay: bool = false

@onready var _save_code_button: Button = %SaveCodeButton
@onready var _save_code_panel: SaveCodePanel = %SaveCodePanel
@onready var _back: Button = %Back


func _ready() -> void:
	_save_code_button.text = Strings.SAVE_CODE_BUTTON
	_save_code_button.pressed.connect(_on_save_code_pressed)
	_back.pressed.connect(_on_back_pressed)
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_on_back_pressed()


func _on_save_code_pressed() -> void:
	_save_code_panel.visible = not _save_code_panel.visible
	if _save_code_panel.visible:
		_save_code_panel.focus_first()


func _on_back_pressed() -> void:
	if is_overlay:
		closed.emit()
		return
	get_tree().change_scene_to_file(TITLE_SCENE)
