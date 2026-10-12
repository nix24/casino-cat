class_name RestScene
extends Control
## The rest site (PRD §10.1): Nap, Practice, or a free loadout Rearrange. Nap and Practice end the
## node; Rearrange does not. It asks RunRules to rest; Game saves and moves on.

## Emitted after a Nap or Practice, so Game can move on to the map.
signal finished
## Emitted after Rearrange changes the loadout, so Game can save.
signal changed

var _run: RunState
var _db: ContentDb

@onready var _layout: VBoxContainer = %Layout
@onready var _title: Label = %Title
@onready var _hud: Label = %Hud
@onready var _nap: Button = %Nap
@onready var _practice: Button = %Practice
@onready var _rearrange: Button = %Rearrange
@onready var _picker: PanelContainer = %Picker
@onready var _picker_text: Label = %PickerText
@onready var _picker_options: VBoxContainer = %PickerOptions
@onready var _picker_cancel: Button = %PickerCancel
@onready var _loadout: LoadoutEditor = %Loadout


func _ready() -> void:
	_title.text = Strings.REST_TITLE
	_practice.text = Strings.REST_PRACTICE
	_rearrange.text = Strings.REST_REARRANGE
	_picker_text.text = Strings.REST_PICK_MOVE
	_picker_cancel.text = Strings.SHOP_CANCEL
	_nap.pressed.connect(_on_nap_pressed)
	_practice.pressed.connect(_open_picker)
	_rearrange.pressed.connect(_on_rearrange_pressed)
	_picker_cancel.pressed.connect(_close_picker)
	_loadout.changed.connect(_on_loadout_changed)
	_loadout.done.connect(_close_loadout)
	if _run != null:
		_render()
		_nap.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _loadout.visible or not _picker.visible:
		return
	# Handled first: closing the picker must not run after the scene is gone.
	get_viewport().set_input_as_handled()
	_close_picker()


## Shows the rest site for [param run]. The scene edits the run in place through RunRules.
func show_rest(run: RunState, db: ContentDb) -> void:
	_run = run
	_db = db
	if is_node_ready():
		_render()
		_nap.grab_focus.call_deferred()


func _render() -> void:
	_hud.text = Strings.SHOP_HUD_FORMAT % [_run.hp, _run.max_hp, _run.purrls]
	_nap.text = Strings.REST_NAP_FORMAT % RestRules.nap_amount(_run, _db.tuning())
	var has_target: bool = not RestRules.practice_targets(_run, _db).is_empty()
	_practice.disabled = not has_target
	_practice.tooltip_text = "" if has_target else Strings.REST_NO_FREE_SLOT


func _on_nap_pressed() -> void:
	if RunRules.rest(_run, true, -1, _db):
		finished.emit()


func _on_rearrange_pressed() -> void:
	_layout.visible = false
	_loadout.visible = true
	_loadout.bind(_run, _db)


func _on_loadout_changed() -> void:
	changed.emit()
	_render()


func _close_loadout() -> void:
	_loadout.visible = false
	_layout.visible = true
	_render()
	_rearrange.grab_focus()


## Opens the picker: one button per equipped move Practice can improve.
func _open_picker() -> void:
	_clear_children(_picker_options)
	for slot: int in RestRules.practice_targets(_run, _db):
		var move: MoveData = _db.move(_run.equipped[slot].move_id)
		var modifier: ModifierData = _db.modifier(RestRules.practice_modifier(move))
		var button := Button.new()
		button.text = (
			Strings.REST_PRACTICE_OPTION_FORMAT
			% [move.display_name, Strings.suit_glyph(move.suit), modifier.display_name]
		)
		button.tooltip_text = modifier.description
		button.pressed.connect(_on_practice_chosen.bind(slot))
		_picker_options.add_child(button)
	_layout.visible = false
	_picker.visible = true
	_focus_picker.call_deferred()


func _on_practice_chosen(slot: int) -> void:
	if RunRules.rest(_run, false, slot, _db):
		finished.emit()


func _close_picker() -> void:
	_picker.visible = false
	_layout.visible = true
	_practice.grab_focus()


func _focus_picker() -> void:
	if _picker_options.get_child_count() > 0:
		(_picker_options.get_child(0) as Button).grab_focus()
	else:
		_picker_cancel.grab_focus()


## Frees [param parent]'s children now out of the layout, so a container never counts a button only
## queued for deletion.
func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
