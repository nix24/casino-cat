class_name RewardScene
extends Control
## The battle reward (PRD §10.6, §13.8): Purrls, a 1-of-3 move offer, a dropped pouch item, and
## Skip. It shows what RunRules rolled and reports the pick; Game applies it and moves on.

## Emitted when the player learns an offer or skips. The choice carries the pouch slot picked for
## the dropped item, or -1 to leave it.
signal choice_made(choice: RunRules.RewardChoice)

var _reward: RunRules.Reward
var _owned_ids: Array[StringName] = []
var _pouch: Array[StringName] = []
## Pouch slot the dropped item goes into, or -1 to leave it.
var _item_slot: int = -1
## Offer being learned in the loadout editor, or -1.
var _learning_index: int = -1

@onready var _layout: VBoxContainer = %Layout
@onready var _title: Label = %Title
@onready var _purrls: Label = %Purrls
@onready var _item_row: VBoxContainer = %ItemRow
@onready var _offers: VBoxContainer = %Offers
@onready var _skip: Button = %Skip
@onready var _loadout: LoadoutEditor = %Loadout


func _ready() -> void:
	_title.text = Strings.REWARD_TITLE
	_skip.pressed.connect(_on_skip_pressed)
	_loadout.learn_resolved.connect(_on_learn_resolved)
	_loadout.learn_skipped.connect(_on_skip_pressed)
	if _reward != null:
		_render()


## Shows [param reward]. [param owned_ids] marks offers the cat already has. [param pouch] is the
## run's pouch, where a dropped item goes.
func show_reward(
	reward: RunRules.Reward, owned_ids: Array[StringName], pouch: Array[StringName]
) -> void:
	_reward = reward
	_owned_ids = owned_ids
	_pouch = pouch
	if is_node_ready():
		_render()


## Swaps the offers for the loadout editor (PRD §4.2) when offer [param offer_index] didn't fit:
## both equipped and bag are full. Releasing a move there picks the offer; skipping skips it.
func begin_learn(run: RunState, db: ContentDb, offer_index: int) -> void:
	_learning_index = offer_index
	_layout.visible = false
	_loadout.visible = true
	_loadout.begin_learn(run, db, _reward.move_offers[offer_index])


func _render() -> void:
	_purrls.text = Strings.REWARD_PURRLS_FORMAT % _reward.purrls
	_render_item_row()
	_skip.text = Strings.REWARD_SKIP_FORMAT % RewardRules.SKIP_BONUS
	for child: Node in _offers.get_children():
		child.queue_free()
	for index: int in _reward.move_offers.size():
		var move_data: MoveData = _reward.move_offers[index]
		var button := Button.new()
		button.text = Strings.reward_offer(move_data, _owned_ids.has(move_data.id))
		button.pressed.connect(_on_offer_pressed.bind(index))
		_offers.add_child(button)
	var first: Control = _offers.get_child(0) as Control if _offers.get_child_count() > 0 else _skip
	first.grab_focus.call_deferred()


## Shows the dropped item and where it goes: the first empty slot, or a Replace button per slot
## plus Leave when the pouch is full. Leave is the default, so nothing is replaced by accident.
func _render_item_row() -> void:
	for child: Node in _item_row.get_children():
		child.queue_free()
	_item_slot = -1
	_item_row.visible = _reward.item_id != &""
	if not _item_row.visible:
		return
	var item_label := Label.new()
	item_label.text = Strings.REWARD_ITEM_FORMAT % _item_name(_reward.item_id)
	_item_row.add_child(item_label)
	var empty_slot: int = _pouch.find(&"")
	if empty_slot >= 0:
		_item_slot = empty_slot
		var into_label := Label.new()
		into_label.text = Strings.REWARD_ITEM_INTO_FORMAT % (empty_slot + 1)
		_item_row.add_child(into_label)
		return
	var group := ButtonGroup.new()
	for slot: int in _pouch.size():
		var replace_text: String = Strings.REWARD_ITEM_REPLACE_FORMAT % _item_name(_pouch[slot])
		_add_item_toggle(replace_text, group, slot)
	_add_item_toggle(Strings.REWARD_ITEM_LEAVE, group, -1).button_pressed = true


func _add_item_toggle(text: String, group: ButtonGroup, slot: int) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.pressed.connect(_on_item_toggle_pressed.bind(slot))
	_item_row.add_child(button)
	return button


func _item_name(item_id: StringName) -> String:
	var item: ItemData = Game.db.item(item_id)
	return item.display_name if item != null else String(item_id)


func _on_item_toggle_pressed(slot: int) -> void:
	_item_slot = slot


func _on_offer_pressed(index: int) -> void:
	_emit_choice(RunRules.RewardChoice.move(index))


func _on_learn_resolved(_move_id: StringName) -> void:
	_emit_choice(RunRules.RewardChoice.move(_learning_index))


func _on_skip_pressed() -> void:
	_emit_choice(RunRules.RewardChoice.skip())


func _emit_choice(choice: RunRules.RewardChoice) -> void:
	choice.item_slot = _item_slot
	choice_made.emit(choice)
