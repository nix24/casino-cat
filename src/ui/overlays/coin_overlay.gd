class_name CoinOverlay
extends PanelContainer
## The coin gamble window (PRD §6.2, §13.4): the coin, the pending payout, the cash-out ladder with
## the current rung outlined, and [Cash out] [Flip again]. It shows what COIN_FLIPPED carries and
## computes nothing. The odds table is pinned beside it by BattleScene.

## Emitted once per choice: CASH_OUT or FLIP.
signal called(coin_call: GambleChoice.CoinCall)

const FOCUS_FRAME: StyleBox = preload("res://src/ui/focus_frame.tres")

## True between begin_choice and a press. The buttons only send a call then.
var _is_choosing: bool = false

@onready var _face: Label = %Face
@onready var _pending_label: Label = %PendingLabel
@onready var _rungs: HBoxContainer = %Rungs
@onready var _result_label: Label = %ResultLabel
@onready var _cash_out: Button = %CashOut
@onready var _flip: Button = %Flip


func _ready() -> void:
	_cash_out.text = Strings.COIN_CASH_OUT
	_flip.text = Strings.COIN_FLIP_AGAIN
	_cash_out.pressed.connect(_on_pressed.bind(GambleChoice.CoinCall.CASH_OUT))
	_flip.pressed.connect(_on_pressed.bind(GambleChoice.CoinCall.FLIP))


## Opens the window for a new coin gamble: no flip yet, no ladder, buttons off.
func open() -> void:
	_face.text = Strings.COIN_UNFLIPPED
	_pending_label.text = ""
	_result_label.text = ""
	_show_ladder(PackedInt32Array(), 0)
	_lock_choice()
	visible = true


## Shows one landed flip at once, tails included (PRD §6.0 rule 4: no staged near-miss).
func show_flip(event: BattleEvent) -> void:
	_face.text = Strings.COIN_HEADS if event.gamble.is_heads else Strings.COIN_TAILS
	_pending_label.text = Strings.COIN_PENDING_FORMAT % event.amount
	_show_ladder(event.gamble.ladder, event.gamble.heads if event.gamble.is_heads else 0)


## Lets the player call it. Focus starts on Cash out, the safe choice (decisions D44).
func begin_choice() -> void:
	_is_choosing = true
	_cash_out.disabled = false
	_flip.disabled = false
	_cash_out.grab_focus()


func show_result(text: String) -> void:
	_result_label.text = text


func close() -> void:
	_lock_choice()
	visible = false


## One label per rung; the rung of [param heads] heads gets the focus frame as its outline.
func _show_ladder(ladder: PackedInt32Array, heads: int) -> void:
	for child: Node in _rungs.get_children():
		_rungs.remove_child(child)
		child.queue_free()
	for index: int in ladder.size():
		var rung := Label.new()
		rung.text = str(ladder[index])
		if index == heads - 1:
			rung.add_theme_stylebox_override(&"normal", FOCUS_FRAME)
		_rungs.add_child(rung)


func _lock_choice() -> void:
	_is_choosing = false
	_cash_out.disabled = true
	_flip.disabled = true


func _on_pressed(coin_call: GambleChoice.CoinCall) -> void:
	if not _is_choosing:
		return
	_lock_choice()
	called.emit(coin_call)
