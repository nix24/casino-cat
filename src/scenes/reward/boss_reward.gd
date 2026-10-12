class_name BossRewardScene
extends Control
## The boss reward (PRD §3.2, §10.6): Purrls, the signature on a first kill, and 1 of 3 relics or
## skip. Game takes the pick, heals, and starts the next act.

## Emitted with the relic index taken, or -1 for skip.
signal relic_chosen(index: int)

var _reward: RunRules.BossReward
var _signature_name: String = ""

@onready var _title: Label = %Title
@onready var _purrls: Label = %Purrls
@onready var _signature: Label = %Signature
@onready var _relics: VBoxContainer = %Relics
@onready var _skip: Button = %Skip
@onready var _next_act: Label = %NextAct


func _ready() -> void:
	_title.text = Strings.BOSS_REWARD_TITLE
	_next_act.text = Strings.BOSS_REWARD_NEXT_ACT
	_skip.text = Strings.BOSS_REWARD_SKIP_FORMAT % RunRules.BOSS_SKIP_PURRLS
	_skip.pressed.connect(relic_chosen.emit.bind(-1))
	if _reward != null:
		_render()


## Shows [param reward]; [param db] names the signature move.
func show_reward(reward: RunRules.BossReward, db: ContentDb) -> void:
	_reward = reward
	if reward.signature_id != &"":
		_signature_name = db.move(reward.signature_id).display_name
	if is_node_ready():
		_render()


func _render() -> void:
	_purrls.text = Strings.REWARD_PURRLS_FORMAT % _reward.purrls
	_signature.text = Strings.BOSS_REWARD_SIGNATURE_FORMAT % _signature_name
	_signature.visible = _signature_name != ""
	for child: Node in _relics.get_children():
		child.queue_free()
	for index: int in _reward.relic_offers.size():
		var relic: RelicData = _reward.relic_offers[index]
		var rarity: String = RelicData.Rarity.keys()[relic.rarity]
		var button := Button.new()
		button.text = Strings.BOSS_REWARD_TAKE_FORMAT % [relic.display_name, rarity.to_lower()]
		button.tooltip_text = relic.description
		button.pressed.connect(relic_chosen.emit.bind(index))
		_relics.add_child(button)
	var first: Control = _relics.get_child(0) as Control if _relics.get_child_count() > 0 else _skip
	first.grab_focus.call_deferred()
