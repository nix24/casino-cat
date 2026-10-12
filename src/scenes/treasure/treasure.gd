class_name TreasureScene
extends Control
## The treasure chest (PRD §10.4): one button opens it, then the relic inside is shown. Game rolls
## the relic; this scene only asks and displays.

## Emitted when the player opens the chest, so Game can roll the relic.
signal open_requested
## Emitted when the player leaves the chest, so Game can return to the map.
signal finished

var _act: int = 1
var _rarity: String = "common"
var _relic: RelicData
var _is_opened: bool = false
var _has_chest: bool = false

@onready var _title: Label = %Title
@onready var _rarity_label: Label = %Rarity
@onready var _relic_name: Label = %RelicName
@onready var _relic_description: Label = %RelicDescription
@onready var _open_button: Button = %OpenButton
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_open_button.text = Strings.TREASURE_OPEN
	_continue_button.text = Strings.EVENT_CONTINUE
	_open_button.pressed.connect(open_requested.emit)
	_continue_button.pressed.connect(finished.emit)
	if _has_chest:
		_render()


## Shows the chest for [param act]. If [param is_opened], the relic (or null for an empty chest) is
## shown straight away, so a reload never offers the chest twice.
func show_chest(act: int, rarity: String, relic: RelicData, is_opened: bool) -> void:
	_act = act
	_rarity = rarity
	_relic = relic
	_is_opened = is_opened
	_has_chest = true
	if is_node_ready():
		_render()


## Reveals what was inside the chest; null means the cat already owned everything.
func show_relic(relic: RelicData) -> void:
	_relic = relic
	_is_opened = true
	if is_node_ready():
		_render()


func _render() -> void:
	_title.text = Strings.TREASURE_TITLES[clampi(_act - 1, 0, 2)]
	_rarity_label.text = Strings.TREASURE_RARITY_FORMAT % _rarity
	_open_button.visible = not _is_opened
	_relic_name.visible = _is_opened
	_relic_description.visible = _is_opened
	_continue_button.visible = _is_opened
	if not _is_opened:
		_open_button.grab_focus.call_deferred()
		return
	if _relic != null:
		_relic_name.text = _relic.display_name
		_relic_description.text = _relic.description
	else:
		_relic_name.text = Strings.TREASURE_EMPTY
		_relic_description.text = ""
	_relic_description.visible = _relic != null
	_continue_button.grab_focus.call_deferred()
