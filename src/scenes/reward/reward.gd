class_name RewardScene
extends Control
## The battle reward (PRD §10.6, §13.8): Purrls, a 1-of-3 move offer, and Skip. It shows what
## RunRules rolled and reports the pick; Game applies it and moves on.

## Emitted when the player learns an offer or skips.
signal choice_made(choice: RunRules.RewardChoice)

var _reward: RunRules.Reward
var _owned_ids: Array[StringName] = []
## Offer being learned in the loadout editor, or -1.
var _learning_index: int = -1

@onready var _layout: VBoxContainer = %Layout
@onready var _title: Label = %Title
@onready var _purrls: Label = %Purrls
@onready var _item: Label = %Item
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


## Shows [param reward]. [param owned_ids] marks offers the cat already has.
func show_reward(reward: RunRules.Reward, owned_ids: Array[StringName]) -> void:
	_reward = reward
	_owned_ids = owned_ids
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
	_item.text = Strings.REWARD_ITEM_DROP
	_item.visible = _reward.item_drop
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


func _on_offer_pressed(index: int) -> void:
	choice_made.emit(RunRules.RewardChoice.move(index))


func _on_learn_resolved(_move_id: StringName) -> void:
	choice_made.emit(RunRules.RewardChoice.move(_learning_index))


func _on_skip_pressed() -> void:
	choice_made.emit(RunRules.RewardChoice.skip())
