extends Control
## Interim map (T006), replaced by the real map at T010. It shows the run's seed, HP, and Purrls and
## offers the one fight this placeholder knows. Game owns the run; this screen only asks for moves.

const TITLE_SCENE: String = "res://src/scenes/title/title.tscn"
const FIGHT_ENEMY_ID: String = "sewer_rat"

@onready var _run_info: Label = %RunInfo
@onready var _save_warning: Label = %SaveWarning
@onready var _fight: Button = %Fight
@onready var _to_title: Button = %ToTitle


func _ready() -> void:
	var run: RunState = Game.run
	_run_info.text = Strings.RUN_INFO_FORMAT % [run.run_seed, run.hp, run.max_hp, run.purrls]
	_save_warning.text = Strings.SAVE_UNAVAILABLE
	_save_warning.visible = Game.save_store.last_result == SaveStore.Result.WRITE_FAILED
	_fight.pressed.connect(_on_fight_pressed)
	_to_title.pressed.connect(_on_to_title_pressed)
	_fight.grab_focus()


func _on_fight_pressed() -> void:
	Game.run.node_payload = {"enemy": FIGHT_ENEMY_ID}
	Game.goto(RunState.NodeState.BATTLE)


func _on_to_title_pressed() -> void:
	Game.save_now()
	get_tree().change_scene_to_file(TITLE_SCENE)
