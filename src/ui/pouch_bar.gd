class_name PouchBar
extends PanelContainer
## The pouch bar (PRD §8.3, §13.3, T014): the cat's three pouch slots in battle. It shows which item
## sits in each slot and reports a press as item_chosen. The Laser Pointer first asks for a suit.
## It never decides whether an item can be used; the rules reject a use that isn't allowed.

## Emitted when the player uses the item in [param slot]. [param choice] is a Suit.Type for the
## Laser Pointer and 0 for every other item.
signal item_chosen(slot: int, choice: int)

var _pouch: Array[StringName] = []
var _items: Dictionary[StringName, ItemData] = {}
var _is_enabled: bool = true
## Pouch slot the suit picker is open for, or -1 when it is closed.
var _picking_slot: int = -1
var _slot_buttons: Array[Button] = []
var _suit_buttons: Array[Button] = []

@onready var _title: Label = %Title
@onready var _slots: HBoxContainer = %Slots
@onready var _pick_label: Label = %PickLabel
@onready var _suit_picker: HBoxContainer = %SuitPicker


func _ready() -> void:
	_title.text = Strings.POUCH_TITLE
	_pick_label.text = Strings.POUCH_PICK_SUIT
	for index: int in _slots.get_child_count():
		var slot_button: Button = _slots.get_child(index) as Button
		slot_button.pressed.connect(_on_slot_pressed.bind(index))
		_slot_buttons.append(slot_button)
	for index: int in _suit_picker.get_child_count():
		var suit_button: Button = _suit_picker.get_child(index) as Button
		suit_button.text = Strings.suit_glyph(index as Suit.Type)
		suit_button.pressed.connect(_on_suit_pressed.bind(index))
		_suit_buttons.append(suit_button)
	_close_picker()


func _unhandled_input(event: InputEvent) -> void:
	if _picking_slot < 0 or not event.is_action_pressed(&"ui_cancel"):
		return
	var slot: int = _picking_slot
	_close_picker()
	_slot_buttons[slot].grab_focus()
	get_viewport().set_input_as_handled()


## Redraws the three slots from [param pouch]. "" marks an empty slot.
func show_pouch(pouch: Array[StringName], items: Dictionary[StringName, ItemData]) -> void:
	_pouch = pouch
	_items = items
	_close_picker()
	_refresh_slots()


## Focuses the first filled slot. False when the pouch is empty.
func focus_first_item() -> bool:
	for index: int in _slot_buttons.size():
		if _holds_item(index):
			_slot_buttons[index].grab_focus()
			return true
	return false


## Turns every slot off or on. An empty slot stays disabled either way.
func set_enabled(on: bool) -> void:
	_is_enabled = on
	if not on:
		_close_picker()
	_refresh_slots()


func _refresh_slots() -> void:
	for index: int in _slot_buttons.size():
		var button: Button = _slot_buttons[index]
		if _holds_item(index):
			var item: ItemData = _items[_pouch[index]]
			button.text = _initials(item.display_name)
			button.tooltip_text = "%s: %s" % [item.display_name, item.description]
			button.disabled = not _is_enabled
		else:
			button.text = Strings.POUCH_EMPTY
			button.tooltip_text = ""
			button.disabled = true


func _holds_item(slot: int) -> bool:
	return slot < _pouch.size() and _pouch[slot] != &""


## First letter of each word: "Fish Snack" is "FS".
func _initials(display_name: String) -> String:
	var initials := ""
	for word: String in display_name.split(" ", false):
		initials += word[0].to_upper()
	return initials


func _on_slot_pressed(slot: int) -> void:
	if _sets_enemy_suit(_items[_pouch[slot]]):
		_picking_slot = slot
		_pick_label.visible = true
		_suit_picker.visible = true
		_suit_buttons[0].grab_focus()
		return
	item_chosen.emit(slot, 0)


func _on_suit_pressed(suit: int) -> void:
	var slot: int = _picking_slot
	_close_picker()
	item_chosen.emit(slot, suit)


func _close_picker() -> void:
	_picking_slot = -1
	_pick_label.visible = false
	_suit_picker.visible = false


func _sets_enemy_suit(item: ItemData) -> bool:
	for effect: EffectData in item.effects:
		if effect.kind == EffectData.Kind.SET_ENEMY_SUIT:
			return true
	return false
