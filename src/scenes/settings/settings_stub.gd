extends Control
## Placeholder until the settings screen lands in M3. It only offers a way back to the title.

const TITLE_SCENE: String = "res://src/scenes/title/title.tscn"

@onready var _back: Button = %Back


func _ready() -> void:
	_back.pressed.connect(_on_back_pressed)
	_back.grab_focus()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
