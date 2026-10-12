class_name PauseMenu
extends Control
## The pause menu (D55, PRD §13.1): Resume, Settings, Save & Quit, and Abandon run behind a
## confirm row. It only asks; Game pauses the tree, saves, and ends the run.

## Emitted for Resume, and for Esc or Start while the menu is open.
signal resume_requested
signal settings_requested
signal save_quit_requested
## Emitted once the player confirms Abandon run.
signal abandon_confirmed

@onready var _title: Label = %Title
@onready var _buttons: VBoxContainer = %Buttons
@onready var _resume: Button = %Resume
@onready var _settings: Button = %Settings
@onready var _save_quit: Button = %SaveQuit
@onready var _abandon: Button = %Abandon
@onready var _confirm: VBoxContainer = %Confirm
@onready var _confirm_text: Label = %ConfirmText
@onready var _confirm_yes: Button = %ConfirmYes
@onready var _confirm_no: Button = %ConfirmNo


func _ready() -> void:
	_title.text = Strings.PAUSE_TITLE
	_resume.text = Strings.PAUSE_RESUME
	_settings.text = Strings.PAUSE_SETTINGS
	_save_quit.text = Strings.PAUSE_SAVE_QUIT
	_abandon.text = Strings.PAUSE_ABANDON
	_confirm_text.text = Strings.ABANDON_CONFIRM
	_confirm_yes.text = Strings.ABANDON_YES
	_confirm_no.text = Strings.ABANDON_NO
	_resume.pressed.connect(resume_requested.emit)
	_settings.pressed.connect(settings_requested.emit)
	_save_quit.pressed.connect(save_quit_requested.emit)
	_abandon.pressed.connect(_show_confirm)
	_confirm_yes.pressed.connect(abandon_confirmed.emit)
	_confirm_no.pressed.connect(_hide_confirm)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if _confirm.visible:
		_hide_confirm()
	else:
		resume_requested.emit()


## Shows the button row with focus on Resume.
func open() -> void:
	_buttons.visible = true
	_confirm.visible = false
	visible = true
	_resume.grab_focus()


func close() -> void:
	visible = false


func _show_confirm() -> void:
	_buttons.visible = false
	_confirm.visible = true
	_confirm_no.grab_focus()


func _hide_confirm() -> void:
	_confirm.visible = false
	_buttons.visible = true
	_abandon.grab_focus()
