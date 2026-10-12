class_name EventScene
extends Control
## A map event (PRD §10.3): the text, up to three choices with their odds shown, then the result.
## It asks EventRules to pick and apply the choice; Game saves and moves on.

## Emitted when the player leaves the result. [param battle_enemy_id] is the enemy the outcome
## starts a fight with, or empty.
signal finished(battle_enemy_id: StringName)
## Emitted once the choice, and any modifier it hands out, is applied to the run, so Game can save.
signal changed

var _run: RunState
var _db: ContentDb
var _event: EventData
var _rng: SeededRng
var _result: EventRules.EventResult

@onready var _title: Label = %Title
@onready var _text: Label = %Text
@onready var _choices: VBoxContainer = %Choices
@onready var _result_box: VBoxContainer = %Result
@onready var _result_text: Label = %ResultText
@onready var _continue: Button = %Continue
@onready var _picker: PanelContainer = %Picker
@onready var _picker_text: Label = %PickerText
@onready var _picker_options: VBoxContainer = %PickerOptions


func _ready() -> void:
	_continue.text = Strings.EVENT_CONTINUE
	_continue.pressed.connect(_on_continue_pressed)
	if _event != null:
		_render()


## Shows [param event] for [param run]. The scene edits the run in place through EventRules, drawing
## from [param rng] (the event stream).
func show_event(run: RunState, db: ContentDb, event: EventData, rng: SeededRng) -> void:
	_run = run
	_db = db
	_event = event
	_rng = rng
	_result = null
	if is_node_ready():
		_render()


func _render() -> void:
	_title.text = _event.title
	_text.text = _event.text
	_result_box.visible = false
	_picker.visible = false
	_clear_children(_choices)
	var first_enabled: Button = null
	for index: int in _event.choices.size():
		var choice: EventChoiceData = _event.choices[index]
		var reason: StringName = EventRules.disabled_reason(_run, choice, _db)
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size = Vector2(360, 0)
		button.text = choice.label + "\n" + Strings.event_odds(choice, _run, _db)
		if reason != &"":
			button.disabled = true
			button.text += "\n" + Strings.event_disabled(reason, choice, _run, _db)
		elif first_enabled == null:
			first_enabled = button
		button.pressed.connect(_on_choice_pressed.bind(index))
		_choices.add_child(button)
	_choices.visible = true
	if first_enabled != null:
		first_enabled.grab_focus.call_deferred()


func _on_choice_pressed(index: int) -> void:
	_result = EventRules.choose(_run, _event, index, _db, _rng)
	if not _result.ok:
		return
	_choices.visible = false
	_result_text.text = _result.result_text
	_result_box.visible = true
	if _result.modifier_id == &"":
		changed.emit()
		_continue.grab_focus.call_deferred()
		return
	# Saved only once the modifier is attached: a reload mid-pick replays the same roll.
	_continue.visible = false
	_open_picker()


## Opens the picker: one button per move the outcome's modifier can go on.
func _open_picker() -> void:
	var modifier: ModifierData = _db.modifier(_result.modifier_id)
	_picker_text.text = Strings.EVENT_PICK_MOVE_FORMAT % modifier.display_name
	_clear_children(_picker_options)
	var owned: Array[MoveInstance] = _run.equipped + _run.bag
	for index: int in EventRules.modifier_targets(_run, _result.modifier_id, _db):
		var move: MoveData = _db.move(owned[index].move_id)
		var button := Button.new()
		button.text = "%s %s" % [move.display_name, Strings.suit_glyph(move.suit)]
		button.tooltip_text = modifier.description
		button.pressed.connect(_on_target_chosen.bind(index))
		_picker_options.add_child(button)
	_picker.visible = true
	if _picker_options.get_child_count() > 0:
		(_picker_options.get_child(0) as Button).grab_focus.call_deferred()


func _on_target_chosen(move_index: int) -> void:
	if (
		RunRules.attach_modifier(_run, move_index, _result.modifier_id, _db)
		!= RunRules.AttachResult.OK
	):
		return
	changed.emit()
	_picker.visible = false
	_continue.visible = true
	_continue.grab_focus.call_deferred()


func _on_continue_pressed() -> void:
	finished.emit(_result.battle_enemy_id)


## Frees [param parent]'s children now out of the layout, so a container never counts a button only
## queued for deletion.
func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
