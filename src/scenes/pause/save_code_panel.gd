class_name SaveCodePanel
extends PanelContainer
## The save code panel (D55, PRD §17.4): shows both saves as one code to copy and, when no run is
## active, takes a pasted code to load. Game builds and reads the code; this only shows it.

@onready var _export_hint: Label = %ExportHint
@onready var _code_field: LineEdit = %CodeField
@onready var _copy: Button = %Copy
@onready var _copy_status: Label = %CopyStatus
@onready var _import: VBoxContainer = %Import
@onready var _import_hint: Label = %ImportHint
@onready var _import_box: LineEdit = %ImportBox
@onready var _load: Button = %Load
@onready var _load_status: Label = %LoadStatus


func _ready() -> void:
	_export_hint.text = Strings.SAVE_CODE_EXPORT_HINT
	_copy.text = Strings.SAVE_CODE_COPY
	_import_hint.text = Strings.SAVE_CODE_IMPORT_HINT
	_load.text = Strings.SAVE_CODE_LOAD
	_copy.pressed.connect(_on_copy_pressed)
	_load.pressed.connect(_on_load_pressed)
	# Import replaces saves, so it is only offered when no run is in play.
	_import.visible = Game.run == null
	# One line, so arrows and Tab leave the box; Enter loads the code.
	_import_box.text_submitted.connect(func(_text: String) -> void: _on_load_pressed())
	_refresh_code()


## Focuses the Copy button, so a keyboard or controller can reach the panel.
func focus_first() -> void:
	_copy.grab_focus()


func _refresh_code() -> void:
	_code_field.text = Game.save_code()


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_code_field.text)
	_copy_status.text = Strings.SAVE_CODE_COPIED


func _on_load_pressed() -> void:
	var error: SaveCode.Error = Game.import_save_code(_import_box.text)
	match error:
		SaveCode.Error.NONE:
			_load_status.text = Strings.SAVE_CODE_LOADED
			_refresh_code()
		SaveCode.Error.TOO_NEW:
			_load_status.text = Strings.SAVE_CODE_TOO_NEW
		_:
			_load_status.text = Strings.SAVE_CODE_BAD
