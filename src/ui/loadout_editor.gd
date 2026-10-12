class_name LoadoutEditor
extends PanelContainer
## The loadout editor (PRD §4.2, T012): the equipped row and the bag, with swap, move, and release.
## It edits the bound RunState through RunRules and reports what happened; it never decides what a
## legal change is. In learn mode (a reward the cat had no room for) releasing a move resolves the
## offer.

## Emitted after any change to the equipped row or the bag, so the owner can save.
signal changed
## Emitted when the player presses Done.
signal done
## Emitted when the player skips the offered move in learn mode.
signal learn_skipped
## Emitted when a release made room in learn mode. The owner learns [param move_id] then.
signal learn_resolved(move_id: StringName)

const ROW_EQUIPPED: int = 0
const ROW_BAG: int = 1
## Nothing picked, or no slot. Slots are (row, index).
const NO_SLOT := Vector2i(-1, -1)
const SLOT_MIN_WIDTH: float = 96.0
const BORDER_COLOR: Color = Color("#f2e7b2")
const PICKED_FILL_COLOR: Color = Color(0.16, 0.17, 0.38)

var _run: RunState
var _db: ContentDb
## The move picked up for a swap or a move, or NO_SLOT.
var _picked: Vector2i = NO_SLOT
## The move the release confirmation is asking about, or NO_SLOT.
var _confirm_target: Vector2i = NO_SLOT
## The reward offer in learn mode. Null outside learn mode.
var _offered: MoveData
var _equipped_buttons: Array[Button] = []
var _bag_buttons: Array[Button] = []
var _picked_style: StyleBoxFlat

@onready var _equipped_label: Label = %EquippedLabel
@onready var _equipped_row: HBoxContainer = %EquippedRow
@onready var _bag_label: Label = %BagLabel
@onready var _bag_row: HBoxContainer = %BagRow
@onready var _learn_label: Label = %LearnLabel
@onready var _message: Label = %Message
@onready var _confirm: HBoxContainer = %Confirm
@onready var _confirm_text: Label = %ConfirmText
@onready var _confirm_release: Button = %ConfirmRelease
@onready var _confirm_keep: Button = %ConfirmKeep
@onready var _release: Button = %Release
@onready var _done: Button = %Done
@onready var _skip: Button = %Skip


func _ready() -> void:
	_picked_style = StyleBoxFlat.new()
	_picked_style.bg_color = PICKED_FILL_COLOR
	_picked_style.set_border_width_all(2)
	_picked_style.border_color = BORDER_COLOR
	_equipped_label.text = Strings.LOADOUT_EQUIPPED
	_bag_label.text = Strings.LOADOUT_BAG
	_message.text = Strings.LOADOUT_LAST_MOVE
	_release.text = Strings.LOADOUT_RELEASE
	_done.text = Strings.LOADOUT_DONE
	_skip.text = Strings.LOADOUT_SKIP
	_confirm_release.text = Strings.LOADOUT_RELEASE
	_confirm_keep.text = Strings.LOADOUT_KEEP
	_release.pressed.connect(_begin_release)
	_done.pressed.connect(done.emit)
	_skip.pressed.connect(learn_skipped.emit)
	_confirm_release.pressed.connect(_on_confirm_release_pressed)
	_confirm_keep.pressed.connect(_close_confirm)
	if _run == null and get_tree().current_scene == self:
		_bind_fixture()
	elif _run != null:
		_redraw()


## Shows [param run]'s loadout. The editor edits [param run] in place; it keeps no copy.
func bind(run: RunState, db: ContentDb) -> void:
	_start(run, db, null)


## Like [method bind], for a reward the cat has no room for: releasing a move resolves the offer.
func begin_learn(run: RunState, db: ContentDb, offered: MoveData) -> void:
	_start(run, db, offered)


func _start(run: RunState, db: ContentDb, offered: MoveData) -> void:
	_run = run
	_db = db
	_offered = offered
	_picked = NO_SLOT
	_confirm_target = NO_SLOT
	if is_node_ready():
		_message.visible = false
		_confirm.visible = false
		_redraw()


## Manual-check fixture (T012): a scene run on its own gets a fresh run with two bagged moves,
## centred in the window.
func _bind_fixture() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("LOADOUT-FIXTURE", db.tuning())
	for move_id: StringName in [&"loaded_paws", &"snake_eyes"]:
		var instance := MoveInstance.new()
		instance.move_id = move_id
		run.bag.append(instance)
	bind(run, db)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _confirm.visible:
			_close_confirm()
		elif _picked != NO_SLOT:
			_picked = NO_SLOT
			_redraw()
		else:
			return
		get_viewport().set_input_as_handled()
	elif _is_release_press(event):
		_begin_release()
		get_viewport().set_input_as_handled()


static func _is_release_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.echo and key.keycode == KEY_DELETE
	var pad := event as InputEventJoypadButton
	return pad != null and pad.pressed and pad.button_index == JOY_BUTTON_X


func _redraw() -> void:
	_ensure_slot_buttons()
	_fill_row(_equipped_buttons, _run.equipped, ROW_EQUIPPED, Strings.LOADOUT_EMPTY_EQUIPPED)
	_fill_row(_bag_buttons, _run.bag, ROW_BAG, Strings.LOADOUT_EMPTY_BAG)
	_learn_label.visible = _offered != null
	if _offered != null:
		_learn_label.text = Strings.LOADOUT_LEARN_FORMAT % _offered.display_name
	_skip.visible = _offered != null
	_done.visible = _offered == null
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null or not is_ancestor_of(focus_owner):
		_equipped_buttons[0].grab_focus.call_deferred()


## Builds the slot buttons once, on the first redraw, because the row sizes come from the tuning.
func _ensure_slot_buttons() -> void:
	if not _equipped_buttons.is_empty():
		return
	var tuning: TuningData = _db.tuning()
	_equipped_buttons = _build_row(_equipped_row, tuning.equipped_moves, ROW_EQUIPPED)
	_bag_buttons = _build_row(_bag_row, tuning.bag_size, ROW_BAG)
	_link_focus()


func _build_row(row_node: HBoxContainer, count: int, row: int) -> Array[Button]:
	var buttons: Array[Button] = []
	for index: int in count:
		var button := Button.new()
		button.custom_minimum_size = Vector2(SLOT_MIN_WIDTH, 0.0)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_slot_pressed.bind(Vector2i(row, index)))
		row_node.add_child(button)
		buttons.append(button)
	return buttons


## Left and right wrap inside a row; up and down step between the rows and the action buttons.
func _link_focus() -> void:
	for buttons: Array[Button] in [_equipped_buttons, _bag_buttons]:
		for index: int in buttons.size():
			var button: Button = buttons[index]
			button.focus_neighbor_left = button.get_path_to(
				buttons[posmod(index - 1, buttons.size())]
			)
			button.focus_neighbor_right = button.get_path_to(buttons[(index + 1) % buttons.size()])
	for index: int in _equipped_buttons.size():
		var equipped_button: Button = _equipped_buttons[index]
		var bag_button: Button = _bag_buttons[mini(index, _bag_buttons.size() - 1)]
		equipped_button.focus_neighbor_top = equipped_button.get_path_to(equipped_button)
		equipped_button.focus_neighbor_bottom = equipped_button.get_path_to(bag_button)
	for index: int in _bag_buttons.size():
		var bag_button: Button = _bag_buttons[index]
		var equipped_button: Button = _equipped_buttons[mini(index, _equipped_buttons.size() - 1)]
		bag_button.focus_neighbor_top = bag_button.get_path_to(equipped_button)
		bag_button.focus_neighbor_bottom = bag_button.get_path_to(_release)
	for action_button: Button in [_release, _done, _skip]:
		action_button.focus_neighbor_top = action_button.get_path_to(_bag_buttons[0])


func _fill_row(buttons: Array[Button], moves: Array[MoveInstance], row: int, empty: String) -> void:
	for index: int in buttons.size():
		var button: Button = buttons[index]
		if index < moves.size():
			var instance: MoveInstance = moves[index]
			button.text = Strings.loadout_move(_db.move(instance.move_id), instance.modifier_ids)
		else:
			button.text = empty
		if _picked == Vector2i(row, index):
			button.text += Strings.LOADOUT_PICKED
			button.add_theme_stylebox_override(&"normal", _picked_style)
		else:
			button.remove_theme_stylebox_override(&"normal")


func _on_slot_pressed(slot: Vector2i) -> void:
	_message.visible = false
	_confirm.visible = false
	if _picked == NO_SLOT:
		_pick(slot)
	elif slot == _picked:
		_picked = NO_SLOT
		_redraw()
	elif slot.x == _picked.x:
		_pick(slot)
	else:
		_trade_with_picked(slot)


## Picks the move at [param slot]. An empty slot can't be picked.
func _pick(slot: Vector2i) -> void:
	if not _holds_move(slot):
		return
	_picked = slot
	_redraw()


## Swaps with, moves to, or equips from the other row, depending on which slots hold a move.
func _trade_with_picked(slot: Vector2i) -> void:
	var equipped_index: int = slot.y if slot.x == ROW_EQUIPPED else _picked.y
	var bag_index: int = slot.y if slot.x == ROW_BAG else _picked.y
	var has_equipped: bool = equipped_index < _run.equipped.size()
	var has_bag: bool = bag_index < _run.bag.size()
	var is_done: bool
	if has_equipped and has_bag:
		is_done = RunRules.swap_equipped_with_bag(_run, equipped_index, bag_index)
	elif has_equipped:
		is_done = RunRules.move_to_bag(_run, equipped_index, _db.tuning())
	else:
		is_done = RunRules.equip_from_bag(_run, bag_index, _db.tuning())
	if not is_done:
		_message.visible = true
		return
	_picked = NO_SLOT
	changed.emit()
	_redraw()


## Asks before releasing the picked move, else the move under focus. Releasing is for the rest of
## the run, so the player confirms first.
func _begin_release() -> void:
	if _confirm.visible:
		return
	var target: Vector2i = _picked if _picked != NO_SLOT else _focused_slot()
	if not _holds_move(target):
		return
	_confirm_target = target
	_message.visible = false
	_confirm_text.text = Strings.LOADOUT_RELEASE_CONFIRM_FORMAT % _move_at(target).display_name
	_confirm.visible = true
	_confirm_keep.grab_focus()


func _on_confirm_release_pressed() -> void:
	if not RunRules.release_move(_run, _confirm_target.x == ROW_BAG, _confirm_target.y):
		_message.visible = true
		return
	var released_slot: Vector2i = _confirm_target
	_confirm.visible = false
	_picked = NO_SLOT
	_confirm_target = NO_SLOT
	_slot_button(released_slot).grab_focus()
	changed.emit()
	_redraw()
	if _offered != null:
		learn_resolved.emit(_offered.id)


func _close_confirm() -> void:
	_confirm.visible = false
	_slot_button(_confirm_target).grab_focus()
	_confirm_target = NO_SLOT


func _holds_move(slot: Vector2i) -> bool:
	if slot == NO_SLOT:
		return false
	var moves: Array[MoveInstance] = _run.bag if slot.x == ROW_BAG else _run.equipped
	return slot.y < moves.size()


func _move_at(slot: Vector2i) -> MoveData:
	var moves: Array[MoveInstance] = _run.bag if slot.x == ROW_BAG else _run.equipped
	return _db.move(moves[slot.y].move_id)


func _slot_button(slot: Vector2i) -> Button:
	return _bag_buttons[slot.y] if slot.x == ROW_BAG else _equipped_buttons[slot.y]


## The slot whose button has focus, or NO_SLOT when focus is elsewhere.
func _focused_slot() -> Vector2i:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var index: int = _equipped_buttons.find(focus_owner)
	if index >= 0:
		return Vector2i(ROW_EQUIPPED, index)
	index = _bag_buttons.find(focus_owner)
	if index >= 0:
		return Vector2i(ROW_BAG, index)
	return NO_SLOT
