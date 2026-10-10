class_name BattleScene
extends Control
## Grey-box battle screen (T003, PRD §4, §13.3). The cat fights one enemy from the keyboard or a
## controller. The rules decide every number. This scene asks for previews, sends actions, and
## plays the returned BattleEvents through EventPlayer, so every number on screen comes from an
## event.

## Emitted after BATTLE_WON or BATTLE_LOST has played. Game listens and moves the run on.
signal battle_finished(outcome: BattleState.Outcome)
## Emitted with the events of each action the player sends, before they play (decisions D36).
signal events_applied(events: Array[BattleEvent])
## Emitted for each action the rules accepted, so Game can log it for replay (decisions D38).
signal action_sent(action: PlayerAction)
## Emitted when the player cycles the battle speed, so Game can save it to Settings.
signal speed_changed(speed: int)

## Action names for the move keys, one per loadout slot.
const MOVE_ACTIONS: Array[StringName] = [&"move_1", &"move_2", &"move_3", &"move_4"]
## Fixed seed so the grey-box battle plays the same dice each launch.
const GREYBOX_SEED: String = "casino-cat-greybox"

## Enemy the cat fights. battle.tscn sets it to Sewer Rat.
@export var enemy_data: EnemyData
## The cat's loadout, slots 0 to 3. battle.tscn sets it to the starter kit.
@export var equipped_moves: Array[MoveData] = []

## 0 = 1×, 1 = 2×, 2 = instant (EventPlayer.SPEED_*). Game sets it from Settings before the battle.
var speed: int = EventPlayer.SPEED_NORMAL

var _state: BattleState
var _ctx: BattleContext
var _rngs: RngSet
var _is_input_on: bool = false
var _last_slot: int = 0
## Suit of the last move the cat used. The cat's damage popups take this suit's glyph and colour.
var _cat_attack_suit: Suit.Type = Suit.Type.CLUBS

@onready var _event_player: EventPlayer = %EventPlayer
@onready var _enemy_panel: CombatantPanel = %EnemyPanel
@onready var _cat_panel: CombatantPanel = %CatPanel
@onready var _enemy_token: ColorRect = %EnemyToken
@onready var _cat_token: ColorRect = %CatToken
@onready var _action_label: Label = %ActionLabel
@onready var _banner: Label = %Banner
@onready var _due_label: Label = %DueLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _move_odds: OddsTable = %MoveOdds
@onready var _dice_overlay: DiceOverlay = %DiceOverlay
@onready var _popups: Control = %Popups
@onready var _move_buttons: Array[MoveButton] = [
	%Move1 as MoveButton, %Move2 as MoveButton, %Move3 as MoveButton, %Move4 as MoveButton
]


## Sets the enemy, context, and RNG streams before the battle enters the tree. Game uses this for
## a run's battle. A battle opened on its own skips it and gets the greybox defaults in _ready.
func setup(enemy: EnemyData, ctx: BattleContext, rngs: RngSet) -> void:
	enemy_data = enemy
	_ctx = ctx
	_rngs = rngs


func _ready() -> void:
	if _ctx == null:
		_ctx = _build_context()
	if _rngs == null:
		_rngs = RngSet.for_seed(GREYBOX_SEED)
	assert(
		_ctx.loadout.size() == _move_buttons.size(),
		"the battle needs one move button per loadout slot"
	)
	var start: BattleStart = BattleRules.start(enemy_data, _ctx, _rngs.battle)
	_state = start.state
	_setup_panels()
	_setup_move_buttons()
	_event_player.event_played.connect(_on_event_played)
	_event_player.skipped.connect(_on_skipped)
	_event_player.queue_finished.connect(_on_queue_finished)
	_dice_overlay.confirmed.connect(_on_dice_confirmed)
	_apply_speed()
	_set_input_on(false)
	_event_player.enqueue(start.events)


## Sends USE_MOVE for [param slot]. Ignored while the queue plays, while a gamble waits for its
## choice, or when the cat can't pay (the button is disabled then).
func use_move(slot: int) -> void:
	if not _is_input_on or _move_buttons[slot].disabled:
		return
	_last_slot = slot
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.USE_MOVE
	action.slot = slot
	_send(action)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_speed"):
		speed = (speed + 1) % (EventPlayer.SPEED_INSTANT + 1)
		_apply_speed()
		speed_changed.emit(speed)
		get_viewport().set_input_as_handled()
		return
	if not _event_player.is_idle() and _is_skip_press(event):
		_event_player.skip_to_end()
		get_viewport().set_input_as_handled()
		return
	if _is_input_on:
		for slot: int in MOVE_ACTIONS.size():
			if event.is_action_pressed(MOVE_ACTIONS[slot]):
				use_move(slot)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed(&"open_info"):
		_toggle_odds()
		get_viewport().set_input_as_handled()


func _is_skip_press(event: InputEvent) -> bool:
	return event.is_action_pressed(&"confirm") or event.is_action_pressed(&"ui_accept")


## ponytail: a battle opened without Game builds its context from the scene's own loadout. Game
## passes BattleContext.from_run through setup() instead, so this path only serves the greybox.
func _build_context() -> BattleContext:
	var ctx := BattleContext.new()
	for move: MoveData in equipped_moves:
		ctx.moves[move.id] = move
		var instance := MoveInstance.new()
		instance.move_id = move.id
		ctx.loadout.append(instance)
	return ctx


func _setup_panels() -> void:
	_enemy_panel.setup(enemy_data.display_name, enemy_data.suit, enemy_data.max_hp, false, 0, 0)
	_cat_panel.setup("Cat", _state.cat.suit, _state.cat.max_hp, true, _state.mp, _ctx.tuning.mp_max)
	_cat_panel.set_mp_ticks(_gamble_costs())
	_enemy_token.color = Strings.suit_color(enemy_data.suit)
	_cat_token.color = Strings.suit_color(_state.cat.suit)
	_due_label.text = Strings.due_text(0, _ctx.tuning.due_pips_max)


## MP cost of each equipped gamble move, for the tick marks on the MP bar.
func _gamble_costs() -> PackedInt32Array:
	var costs := PackedInt32Array()
	for instance: MoveInstance in _ctx.loadout:
		var move: MoveData = _ctx.moves[instance.move_id]
		if move.category == MoveData.Category.GAMBLE:
			costs.append(move.mp_cost)
	return costs


func _setup_move_buttons() -> void:
	for slot: int in _move_buttons.size():
		var button: MoveButton = _move_buttons[slot]
		button.setup(slot, _ctx.moves[_ctx.loadout[slot].move_id])
		button.pressed.connect(use_move.bind(slot))
		button.focus_entered.connect(_show_odds_for.bind(button))
		button.mouse_entered.connect(_show_odds_for.bind(button))
		button.focus_exited.connect(_hide_odds)
		button.mouse_exited.connect(_hide_odds)


## Applies [param action] to the rules and queues the events it returns. A lone ACTION_REJECTED
## only warns and turns input back on, because the UI should never send one.
func _send(action: PlayerAction) -> void:
	_set_input_on(false)
	var events: Array[BattleEvent] = BattleRules.apply(_state, action, _ctx, _rngs)
	events_applied.emit(events)
	if events.size() == 1 and events[0].kind == BattleEvent.Kind.ACTION_REJECTED:
		push_warning("action rejected: %s" % events[0].reason)
		_set_input_on(true)
		return
	action_sent.emit(action)
	_event_player.enqueue(events)


## Dev console only (D36): the live battle state, so commands can edit it.
func debug_state() -> BattleState:
	return _state


## Dev console only (D36): the live battle context, so the console can set god mode and force dice.
func debug_context() -> BattleContext:
	return _ctx


## Dev console only (D36): the live RNG streams, so the overlay can show their states.
func debug_rngs() -> RngSet:
	return _rngs


## Dev console only (D36): shows the cat's current HP and MP after a console edit. It goes through
## events like every other number on screen.
func debug_sync() -> void:
	var healed := BattleEvent.new(BattleEvent.Kind.HEALED)
	healed.target = BattleEvent.Actor.CAT
	healed.value_after = _state.cat.hp
	_cat_panel.apply_event(healed, 0.0)
	var mp_changed := BattleEvent.new(BattleEvent.Kind.MP_CHANGED)
	mp_changed.value_after = _state.mp
	_cat_panel.apply_event(mp_changed, 0.0)
	_refresh_previews()
	_set_input_on(_is_input_on)


func _set_input_on(is_on: bool) -> void:
	_is_input_on = is_on
	if not is_on:
		_hide_odds()
	for button: MoveButton in _move_buttons:
		button.disabled = not is_on or not button.can_pay()


func _refresh_previews() -> void:
	for slot: int in _move_buttons.size():
		_move_buttons[slot].set_preview(BattleRules.preview_move(_state, slot, _ctx))


func _apply_speed() -> void:
	_event_player.speed = speed
	_speed_label.text = Strings.speed_text(speed)


func _on_dice_confirmed(reroll_dice: PackedInt32Array) -> void:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.GAMBLE_CHOICE
	action.gamble_choice.reroll_dice = reroll_dice
	_send(action)


## Runs when the queue empties. Nothing is animating now, so reading the state is safe.
func _on_queue_finished() -> void:
	if _state.outcome != BattleState.Outcome.ONGOING:
		_dice_overlay.close()
		battle_finished.emit(_state.outcome)
		return
	if _state.pending != null:
		_dice_overlay.begin_choice(_state.rerolls)
		return
	_dice_overlay.close()
	_refresh_previews()
	_set_input_on(true)
	_move_buttons[_last_slot].grab_focus()


func _on_skipped() -> void:
	_enemy_panel.finish_animations()
	_cat_panel.finish_animations()
	for popup: Node in _popups.get_children():
		_popups.remove_child(popup)
		popup.queue_free()


## Routes one event to the widget that shows it. A step with [param seconds] of 0 sets values at
## once; any other step tweens and pops numbers over that many seconds.
func _on_event_played(event: BattleEvent, seconds: float) -> void:
	match event.kind:
		BattleEvent.Kind.INTENT_SHOWN:
			_enemy_panel.set_intent(Strings.intent_text(event, enemy_data.suit))
		BattleEvent.Kind.MOVE_USED:
			_show_move_used(event)
		BattleEvent.Kind.ENEMY_ACTED:
			_action_label.text = "%s: %s" % [enemy_data.display_name, event.reason]
		BattleEvent.Kind.DAMAGE_DEALT:
			_show_damage(event, seconds)
		BattleEvent.Kind.HEALED:
			_show_heal(event, seconds)
		BattleEvent.Kind.BACKFIRE:
			_show_backfire(event, seconds)
		BattleEvent.Kind.SHIELD_GAINED, BattleEvent.Kind.STATUS_APPLIED:
			_panel_for(event.target).apply_event(event, seconds)
		BattleEvent.Kind.STATUS_TICKED, BattleEvent.Kind.STATUS_EXPIRED:
			_panel_for(event.target).apply_event(event, seconds)
		BattleEvent.Kind.MP_CHANGED:
			_cat_panel.apply_event(event, seconds)
		BattleEvent.Kind.SUIT_SHIFTED:
			_cat_panel.set_suit(event.suit_to)
			_cat_token.color = Strings.suit_color(event.suit_to)
		BattleEvent.Kind.DUE_CHANGED:
			_due_label.text = Strings.due_text(event.amount, _ctx.tuning.due_pips_max)
		BattleEvent.Kind.BATTLE_WON, BattleEvent.Kind.BATTLE_LOST:
			_show_banner(event)
		# BATTLE_STARTED, TURN_STARTED, GAMBLE_AWAITING_CHOICE, and ACTION_REJECTED show nothing.
		_:
			_on_gamble_event(event)


func _on_gamble_event(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.GAMBLE_STARTED:
			_dice_overlay.open(event.gamble.odds)
		BattleEvent.Kind.DICE_ROLLED, BattleEvent.Kind.DICE_REROLLED:
			_dice_overlay.set_faces(event.gamble.faces)
		BattleEvent.Kind.LUCK_TRIGGERED:
			_action_label.text = "Luck!"
			_dice_overlay.set_faces(event.gamble.faces)
		BattleEvent.Kind.REROLLS_CHANGED:
			_dice_overlay.set_rerolls(event.amount)
		BattleEvent.Kind.GAMBLE_RESOLVED:
			_dice_overlay.show_result("%s → %d" % [event.gamble.tier, event.gamble.payout])


func _show_move_used(event: BattleEvent) -> void:
	var move: MoveData = _ctx.moves[event.move_id]
	_cat_attack_suit = move.suit
	_action_label.text = move.display_name


func _show_damage(event: BattleEvent, seconds: float) -> void:
	var panel: CombatantPanel = _panel_for(event.target)
	panel.apply_event(event, seconds)
	var attacker_suit: Suit.Type = enemy_data.suit
	if event.actor == BattleEvent.Actor.CAT:
		attacker_suit = _cat_attack_suit
	var hit_text: String = (
		"%s %d" % [Strings.suit_glyph(attacker_suit), event.amount - event.absorbed]
	)
	_popup_on(panel, hit_text, Strings.suit_color(attacker_suit), seconds)
	if event.absorbed > 0:
		var shield_text: String = "%s −%d" % [Strings.SHIELD_GLYPH, event.absorbed]
		_popup_on(panel, shield_text, Strings.SHIELD_COLOR, seconds, 1)


func _show_heal(event: BattleEvent, seconds: float) -> void:
	var panel: CombatantPanel = _panel_for(event.target)
	panel.apply_event(event, seconds)
	_popup_on(panel, "+%d" % event.amount, Strings.HEAL_COLOR, seconds)


func _show_backfire(event: BattleEvent, seconds: float) -> void:
	_cat_panel.apply_event(event, seconds)
	_popup_on(_cat_panel, "−%d" % event.amount, Strings.BACKFIRE_COLOR, seconds)


func _show_banner(event: BattleEvent) -> void:
	_banner.text = "Won" if event.kind == BattleEvent.Kind.BATTLE_WON else "Lost"
	_banner.visible = true
	# The battle is over, so the enemy no longer has a next action to show.
	_enemy_panel.set_intent("")


func _panel_for(side: BattleEvent.Actor) -> CombatantPanel:
	return _cat_panel if side == BattleEvent.Actor.CAT else _enemy_panel


## Pops [param message] over [param panel]. Instant steps show no popup: the value is already set.
## [param lane] stacks a second popup below the first.
func _popup_on(
	panel: CombatantPanel, message: String, color: Color, seconds: float, lane: int = 0
) -> void:
	if seconds <= 0.0:
		return
	var popup := NumberPopup.new()
	_popups.add_child(popup)
	popup.position = panel.position + Vector2(panel.size.x * 0.5, 4.0 + lane * 12.0)
	popup.play(message, color, seconds)


## Shows the odds of a gamble button in the shared table. Other buttons hide it.
func _show_odds_for(button: MoveButton) -> void:
	var preview: MovePreview = button.preview
	if preview == null or preview.odds == null:
		_hide_odds()
		return
	_move_odds.set_odds(preview.odds)
	_move_odds.visible = true


func _hide_odds() -> void:
	_move_odds.visible = false


## Open Info (I, Y) toggles the odds of the gamble button that has focus.
func _toggle_odds() -> void:
	var button: MoveButton = get_viewport().gui_get_focus_owner() as MoveButton
	if button == null or button.move.category != MoveData.Category.GAMBLE:
		return
	if _move_odds.visible:
		_hide_odds()
	else:
		_show_odds_for(button)
