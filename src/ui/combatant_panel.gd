class_name CombatantPanel
extends PanelContainer
## One combatant's card: name, suit, HP, Shield, statuses, and for the cat MP with its Gamble tick
## marks (PRD §13.3). It shows the values each BattleEvent carries and keeps no rules.

var _max_hp: int = 0
var _mp_max: int = 0
## Where each bar is heading. finish_animations snaps the bars here.
var _hp_target: float = 0.0
var _mp_target: float = 0.0
var _hp_tween: Tween
var _mp_tween: Tween
## Status id to turns left, from the STATUS_* events.
var _statuses: Dictionary[StringName, int] = {}

@onready var _name_label: Label = %NameLabel
@onready var _suit_label: Label = %SuitLabel
@onready var _intent_label: Label = %IntentLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _shield_label: Label = %ShieldLabel
@onready var _status_label: Label = %StatusLabel
@onready var _mp_row: HBoxContainer = %MpRow
@onready var _mp_bar: ProgressBar = %MpBar
@onready var _mp_label: Label = %MpLabel


## Sets the card for a fresh battle at full HP. [param show_mp] is true for the cat only; an enemy
## shows its intent instead.
func setup(
	display_name: String, suit: Suit.Type, max_hp: int, show_mp: bool, mp: int, mp_max: int
) -> void:
	_name_label.text = display_name
	_max_hp = max_hp
	_hp_bar.max_value = max_hp
	_set_hp(max_hp, 0.0)
	set_suit(suit)
	_intent_label.visible = not show_mp
	_mp_row.visible = show_mp
	_mp_max = mp_max
	_mp_bar.max_value = mp_max
	_set_mp(mp, 0.0)
	_refresh_status()


## Shows [param suit] as the badge, tinted with the suit colour.
func set_suit(suit: Suit.Type) -> void:
	_suit_label.text = Strings.suit_glyph(suit)
	_suit_label.add_theme_color_override(&"font_color", Strings.suit_color(suit))


## Shows the enemy's intent line, built by Strings.intent_text.
func set_intent(text: String) -> void:
	_intent_label.text = text


## Marks each cost on the MP bar as a 1 px line at cost / mp_max of its width (PRD §13.3).
func set_mp_ticks(costs: PackedInt32Array) -> void:
	for child: Node in _mp_bar.get_children():
		_mp_bar.remove_child(child)
		child.queue_free()
	for cost: int in costs:
		var tick := ColorRect.new()
		tick.color = Strings.TICK_COLOR
		# Anchors keep the tick on the bar at any width, so no layout pass is needed first.
		tick.anchor_top = 0.0
		tick.anchor_bottom = 1.0
		tick.anchor_left = float(cost) / float(_mp_max)
		tick.anchor_right = tick.anchor_left
		tick.offset_right = 1.0
		_mp_bar.add_child(tick)


## Applies the numbers one event carries. [param seconds] is how long the bar takes to reach its
## value; 0 sets it at once.
func apply_event(event: BattleEvent, seconds: float) -> void:
	match event.kind:
		BattleEvent.Kind.DAMAGE_DEALT:
			_set_hp(event.value_after, seconds)
			_set_shield(event.shield_after)
		BattleEvent.Kind.BACKFIRE, BattleEvent.Kind.HEALED:
			_set_hp(event.value_after, seconds)
		BattleEvent.Kind.SHIELD_GAINED:
			_set_shield(event.shield_after)
		BattleEvent.Kind.MP_CHANGED:
			_set_mp(event.value_after, seconds)
		BattleEvent.Kind.STATUS_APPLIED, BattleEvent.Kind.STATUS_TICKED:
			_statuses[event.status] = event.turns
			_refresh_status()
		BattleEvent.Kind.STATUS_EXPIRED:
			_statuses.erase(event.status)
			_refresh_status()


## Ends every running bar animation at its final value. Skip uses it so nothing animates after it.
func finish_animations() -> void:
	_hp_tween = _tween_bar(_hp_bar, _hp_tween, _hp_target, 0.0)
	_mp_tween = _tween_bar(_mp_bar, _mp_tween, _mp_target, 0.0)


func _set_hp(value: int, seconds: float) -> void:
	_hp_target = value
	_hp_label.text = "%d/%d" % [value, _max_hp]
	_hp_tween = _tween_bar(_hp_bar, _hp_tween, value, seconds)


func _set_mp(value: int, seconds: float) -> void:
	_mp_target = value
	_mp_label.text = "%d/%d" % [value, _mp_max]
	_mp_tween = _tween_bar(_mp_bar, _mp_tween, value, seconds)


func _set_shield(amount: int) -> void:
	_shield_label.text = "%s %d" % [Strings.SHIELD_GLYPH, amount]


func _refresh_status() -> void:
	_status_label.text = Strings.status_text(_statuses)


## Runs [param bar] to [param value] over [param seconds], stopping [param running] first. Returns
## the new tween, or null when the bar was set at once.
func _tween_bar(bar: ProgressBar, running: Tween, value: float, seconds: float) -> Tween:
	if running != null and running.is_running():
		running.kill()
	if seconds <= 0.0:
		bar.value = value
		return null
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "value", value, seconds)
	return tween
