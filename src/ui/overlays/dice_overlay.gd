class_name DiceOverlay
extends PanelContainer
## The dice gamble window (PRD §6.1, §13.4). It shows what BattleScene gives it: faces, rerolls
## left, the odds table, and the result text. It rolls and scores nothing. Confirm emits the dice
## the player marked; an empty list keeps the faces.

## Emitted once per choice. The indices are the dice to reroll; an empty list keeps them.
signal confirmed(reroll_dice: PackedInt32Array)

## Most dice a Dice move rolls. The overlay has one toggle per die.
const MAX_DICE: int = 3

## True between begin_choice and Confirm. Dice can only be marked and confirmed then.
var _is_choosing: bool = false

@onready var _dice: Array[Button] = [%Die0 as Button, %Die1 as Button, %Die2 as Button]
@onready var _rerolls_label: Label = %RerollsLabel
@onready var _result_label: Label = %ResultLabel
@onready var _confirm: Button = %Confirm
@onready var _odds: OddsTable = %Odds


func _ready() -> void:
	for die: Button in _dice:
		die.toggled.connect(_on_die_toggled)
	_confirm.pressed.connect(_on_confirm_pressed)


## Opens the window with the odds for the gamble. The dice and Confirm stay off until begin_choice.
func open(odds: GambleOdds) -> void:
	_odds.set_odds(odds)
	_result_label.text = ""
	# The count arrives with begin_choice or REROLLS_CHANGED; no stale number until then.
	_rerolls_label.text = ""
	for die: Button in _dice:
		die.visible = false
	_lock_choice()
	visible = true


## Shows [param faces] on the dice and unmarks them all.
func set_faces(faces: PackedInt32Array) -> void:
	assert(faces.size() <= MAX_DICE, "a dice gamble rolls at most %d dice" % MAX_DICE)
	for index: int in MAX_DICE:
		var die: Button = _dice[index]
		var shown: bool = index < faces.size()
		die.visible = shown
		die.button_pressed = false
		if shown:
			die.text = str(faces[index])
	_link_focus(faces.size())
	_refresh_confirm_text()


func set_rerolls(count: int) -> void:
	_rerolls_label.text = "rerolls: %d" % count


## Lets the player choose. Dice can be marked only while [param rerolls_left] is above zero.
## Focus goes to Confirm.
func begin_choice(rerolls_left: int) -> void:
	set_rerolls(rerolls_left)
	_is_choosing = true
	_confirm.disabled = false
	for die: Button in _dice:
		die.disabled = rerolls_left <= 0
	_refresh_confirm_text()
	_confirm.grab_focus()


func show_result(text: String) -> void:
	_result_label.text = text


## Hides the window and ends any choice.
func close() -> void:
	_lock_choice()
	visible = false


func _lock_choice() -> void:
	_is_choosing = false
	_confirm.disabled = true
	for die: Button in _dice:
		die.disabled = true


func _on_confirm_pressed() -> void:
	if not _is_choosing:
		return
	var reroll_dice := _marked_dice()
	_lock_choice()
	confirmed.emit(reroll_dice)


func _on_die_toggled(_toggled_on: bool) -> void:
	_refresh_confirm_text()


func _marked_dice() -> PackedInt32Array:
	var marked := PackedInt32Array()
	for index: int in MAX_DICE:
		if _dice[index].visible and _dice[index].button_pressed:
			marked.append(index)
	return marked


## "Keep" with nothing marked, "Reroll" with any die marked.
func _refresh_confirm_text() -> void:
	_confirm.text = "Reroll" if not _marked_dice().is_empty() else "Keep"


## Left and right run across the dice shown, down goes to Confirm, and Confirm goes back up to the
## first die. Set in code because the die count changes per gamble.
func _link_focus(count: int) -> void:
	for index: int in count:
		var die: Button = _dice[index]
		die.focus_neighbor_left = die.get_path_to(_dice[maxi(index - 1, 0)])
		die.focus_neighbor_right = die.get_path_to(_dice[mini(index + 1, count - 1)])
		die.focus_neighbor_bottom = die.get_path_to(_confirm)
	if count > 0:
		_confirm.focus_neighbor_top = _confirm.get_path_to(_dice[0])
