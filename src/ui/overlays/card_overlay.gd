class_name CardOverlay
extends PanelContainer
## The cards gamble window (PRD §6.3, §13.4): the hand, the total, the live bust chance, and
## [Hit] [Stand] for Nine Lives, or a pick and a put-back order for Card Trick. It shows what the
## card events carry and computes nothing. The odds and the deck counts sit beside it.

## Emitted once per choice: Hit or Stand, or a Card Trick pick with its put-back order.
signal chose(choice: GambleChoice)

## True between begin_choice and a press.
var _is_choosing: bool = false
var _mode: CardGambleData.Mode = CardGambleData.Mode.HIGH_CARD
## Card Trick: the picked hand index, and the other two, new top first.
var _pick: int = -1
var _order: PackedInt32Array = PackedInt32Array()
var _hand: PackedInt32Array = PackedInt32Array()

@onready var _cards: Array[Button] = [
	%Hand.get_child(0) as Button,
	%Hand.get_child(1) as Button,
	%Hand.get_child(2) as Button,
	%Hand.get_child(3) as Button,
	%Hand.get_child(4) as Button,
]
@onready var _total_label: Label = %TotalLabel
@onready var _status_label: Label = %StatusLabel
@onready var _hit: Button = %Hit
@onready var _stand: Button = %Stand
@onready var _swap: Button = %Swap
@onready var _confirm: Button = %Confirm


func _ready() -> void:
	_hit.text = Strings.CARDS_HIT
	_stand.text = Strings.CARDS_STAND
	_swap.text = Strings.CARDS_SWAP
	_confirm.text = Strings.CARDS_CONFIRM
	for index: int in _cards.size():
		_cards[index].pressed.connect(_on_card_pressed.bind(index))
	_hit.pressed.connect(_on_call.bind(GambleChoice.CardCall.HIT))
	_stand.pressed.connect(_on_call.bind(GambleChoice.CardCall.STAND))
	_swap.pressed.connect(_on_swap)
	_confirm.pressed.connect(_on_confirm)


## Opens the window for a new [param mode] gamble with an empty hand.
func open(mode: CardGambleData.Mode) -> void:
	_mode = mode
	_hand = PackedInt32Array()
	_total_label.text = ""
	_status_label.text = ""
	_show_hand()
	_lock_choice()
	_hit.visible = mode == CardGambleData.Mode.BLACKJACK
	_stand.visible = _hit.visible
	_swap.visible = mode == CardGambleData.Mode.TRICK
	_confirm.visible = _swap.visible
	visible = true


## Shows the hand a card event carries, the moment the card lands (PRD §6.0 rule 4). Nine Lives
## also shows its total and the bust chance of the next hit.
func show_cards(event: BattleEvent) -> void:
	if event.kind == BattleEvent.Kind.CARDS_REORDERED:
		return
	_hand = event.gamble.cards
	_show_hand()
	if _mode != CardGambleData.Mode.BLACKJACK:
		return
	var total: int = 0
	for value: int in _hand:
		total += value
	_total_label.text = Strings.cards_total_text(total, event.gamble.bust_chance)
	if event.kind == BattleEvent.Kind.CARD_SAVED:
		_status_label.text = Strings.CARDS_SAVED_FORMAT % event.amount


## Shows the result line; a forgiven bust says so in words, not colour alone.
func show_result(event: BattleEvent) -> void:
	if event.gamble.forgiven:
		_status_label.text = Strings.NINE_LIVES_FORGIVEN
	_total_label.text = Strings.GAMBLE_RESULT_FORMAT % [event.gamble.tier, event.gamble.payout]


## Lets the player choose. Nine Lives focuses Stand, the safe call; Card Trick focuses the first
## card and waits for a pick before Confirm works.
func begin_choice() -> void:
	_is_choosing = true
	if _mode == CardGambleData.Mode.TRICK:
		_pick = -1
		for index: int in _hand.size():
			_set_pickable(_cards[index], true)
		_swap.disabled = true
		_confirm.disabled = true
		_status_label.text = Strings.CARDS_PICK
		_cards[0].grab_focus()
		return
	_hit.disabled = false
	_stand.disabled = false
	_stand.grab_focus()


func close() -> void:
	_lock_choice()
	visible = false


func _show_hand() -> void:
	for index: int in _cards.size():
		var card: Button = _cards[index]
		card.visible = index < _hand.size()
		card.button_pressed = false
		if card.visible:
			card.text = str(_hand[index])
	_link_focus()


## Left and right run across the cards shown, down reaches the buttons, and up goes back to the
## first card. Set in code because the hand size changes.
func _link_focus() -> void:
	var count: int = _hand.size()
	var first_button: Button = _swap if _mode == CardGambleData.Mode.TRICK else _stand
	for index: int in count:
		var card: Button = _cards[index]
		card.focus_neighbor_left = card.get_path_to(_cards[(index - 1 + count) % count])
		card.focus_neighbor_right = card.get_path_to(_cards[(index + 1) % count])
		card.focus_neighbor_bottom = card.get_path_to(first_button)
	if count > 0:
		for button: Button in [_swap, _confirm, _hit, _stand]:
			button.focus_neighbor_top = button.get_path_to(_cards[0])


func _lock_choice() -> void:
	_is_choosing = false
	for card: Button in _cards:
		_set_pickable(card, false)
	for button: Button in [_hit, _stand, _swap, _confirm]:
		button.disabled = true


## Cards are buttons only while Card Trick waits for a pick; otherwise they are plain faces.
func _set_pickable(card: Button, is_pickable: bool) -> void:
	card.focus_mode = Control.FOCUS_ALL if is_pickable else Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_STOP if is_pickable else Control.MOUSE_FILTER_IGNORE
	card.toggle_mode = is_pickable


func _on_card_pressed(index: int) -> void:
	if not _is_choosing or _mode != CardGambleData.Mode.TRICK:
		return
	_pick = index
	_order = PackedInt32Array()
	for other: int in _hand.size():
		if other != index:
			_order.append(other)
	_swap.disabled = false
	_confirm.disabled = false
	_show_order()


func _on_swap() -> void:
	_order.reverse()
	_show_order()


func _show_order() -> void:
	_status_label.text = Strings.CARDS_ORDER_FORMAT % [_hand[_order[0]], _hand[_order[1]]]


func _on_confirm() -> void:
	if not _is_choosing or _pick < 0:
		return
	var choice := GambleChoice.new()
	choice.trick_pick = _pick
	choice.trick_order = _order.duplicate()
	_lock_choice()
	chose.emit(choice)


func _on_call(card_call: GambleChoice.CardCall) -> void:
	if not _is_choosing:
		return
	var choice := GambleChoice.new()
	choice.cards = card_call
	_lock_choice()
	chose.emit(choice)
