extends Control
## The title screen. It starts or continues a run, opens settings, and quits. A save that will not
## load is offered as an explicit choice (Continue opens the panel), so a player never loses a run
## by accident.

const SETTINGS_SCENE: String = "res://src/scenes/settings/settings_stub.tscn"

@onready var _continue: Button = %Continue
@onready var _seed_input: LineEdit = %SeedInput
@onready var _new_run: Button = %NewRun
@onready var _settings: Button = %Settings
@onready var _quit: Button = %Quit
@onready var _save_warning: Label = %SaveWarning
@onready var _unreadable: PanelContainer = %Unreadable
@onready var _unreadable_message: Label = %UnreadableMessage
@onready var _unreadable_new_run: Button = %UnreadableNewRun
@onready var _unreadable_back: Button = %UnreadableBack


func _ready() -> void:
	var can_continue: bool = Game.continue_run()
	_continue.visible = can_continue or _is_save_unreadable()
	_quit.visible = not OS.has_feature("web")
	_save_warning.text = Strings.SAVE_UNAVAILABLE
	_save_warning.visible = Game.save_store.last_result == SaveStore.Result.WRITE_FAILED
	_unreadable_message.text = Strings.TITLE_UNREADABLE

	_continue.pressed.connect(_on_continue_pressed)
	_new_run.pressed.connect(_on_new_run_pressed)
	_seed_input.text_submitted.connect(_on_seed_submitted)
	_settings.pressed.connect(_on_settings_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_unreadable_new_run.pressed.connect(_on_new_run_pressed)
	_unreadable_back.pressed.connect(_on_unreadable_back_pressed)

	_focus_first_visible_button()


func _on_continue_pressed() -> void:
	if _is_save_unreadable():
		_unreadable.visible = true
		_unreadable_new_run.grab_focus()
		return
	Game.goto(Game.run.node_state)


func _on_new_run_pressed() -> void:
	Game.new_run(_seed_input.text.strip_edges())


func _on_seed_submitted(_seed_text: String) -> void:
	_on_new_run_pressed()


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_unreadable_back_pressed() -> void:
	_unreadable.visible = false
	_continue.grab_focus()


func _is_save_unreadable() -> bool:
	var result: SaveStore.Result = Game.save_store.last_result
	return result == SaveStore.Result.UNREADABLE or result == SaveStore.Result.TOO_NEW


func _focus_first_visible_button() -> void:
	for button: Button in [_continue, _new_run, _settings, _quit]:
		if button.visible:
			button.grab_focus()
			return
