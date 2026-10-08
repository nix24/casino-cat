class_name EventPlayer
extends Node
## Plays BattleEvents one step at a time (PRD §13.5, decisions D43). It owns the queue and the clock
## only and knows nothing about panels: BattleScene decides what each event looks like.

## Emitted when a step starts. [param seconds] is how long the step waits before the next one.
signal event_played(event: BattleEvent, seconds: float)
## Emitted once when skip_to_end() starts. The rest of the queue then plays with no wait.
signal skipped
## Emitted once when the queue empties and the last step's wait has run out.
signal queue_finished

const SPEED_NORMAL: int = 0
const SPEED_DOUBLE: int = 1
const SPEED_INSTANT: int = 2

## Seconds per event kind at 1× (decisions D43). Double speed halves them and instant waits for
## nothing. A kind missing here fails a test, so a new kind can't ship without a duration.
const DURATIONS: Dictionary[BattleEvent.Kind, float] = {
	BattleEvent.Kind.BATTLE_STARTED: 0.0,
	BattleEvent.Kind.TURN_STARTED: 0.0,
	BattleEvent.Kind.INTENT_SHOWN: 0.2,
	BattleEvent.Kind.MOVE_USED: 0.2,
	BattleEvent.Kind.ACTION_REJECTED: 0.0,
	BattleEvent.Kind.DAMAGE_DEALT: 0.4,
	BattleEvent.Kind.SHIELD_GAINED: 0.3,
	BattleEvent.Kind.HEALED: 0.3,
	BattleEvent.Kind.MP_CHANGED: 0.2,
	BattleEvent.Kind.SUIT_SHIFTED: 0.2,
	BattleEvent.Kind.STATUS_APPLIED: 0.25,
	BattleEvent.Kind.STATUS_TICKED: 0.25,
	BattleEvent.Kind.STATUS_EXPIRED: 0.25,
	BattleEvent.Kind.ENEMY_ACTED: 0.35,
	BattleEvent.Kind.BATTLE_WON: 0.6,
	BattleEvent.Kind.BATTLE_LOST: 0.6,
	BattleEvent.Kind.GAMBLE_STARTED: 0.2,
	BattleEvent.Kind.GAMBLE_AWAITING_CHOICE: 0.0,
	BattleEvent.Kind.DICE_ROLLED: 0.5,
	BattleEvent.Kind.DICE_REROLLED: 0.5,
	BattleEvent.Kind.LUCK_TRIGGERED: 0.35,
	BattleEvent.Kind.GAMBLE_RESOLVED: 0.4,
	BattleEvent.Kind.BACKFIRE: 0.4,
	BattleEvent.Kind.DUE_CHANGED: 0.2,
	BattleEvent.Kind.REROLLS_CHANGED: 0.0,
}

## 0 = 1×, 1 = 2×, 2 = instant. BattleScene sets it before the first enqueue.
var speed: int = SPEED_NORMAL

var _queue: Array[BattleEvent] = []
## Seconds until the next step may start. It can go negative: the overshoot carries into the next
## step, so a frame that runs past a step's end doesn't stretch the timing.
var _wait_left: float = 0.0
var _is_playing: bool = false


func _process(delta: float) -> void:
	advance(delta)


## Appends [param events] and starts playing if the player is idle.
func enqueue(events: Array[BattleEvent]) -> void:
	if events.is_empty():
		return
	_queue.append_array(events)
	_is_playing = true
	_play_ready_steps()


## Whether nothing is queued and no step is waiting.
func is_idle() -> bool:
	return not _is_playing


## Moves the clock forward. BattleScene calls it each frame; tests call it directly.
func advance(delta: float) -> void:
	if not _is_playing:
		return
	_wait_left -= delta
	_play_ready_steps()


## Finishes the current step at once and plays the rest of the queue with no wait (Confirm).
func skip_to_end() -> void:
	if not _is_playing:
		return
	skipped.emit()
	while not _queue.is_empty():
		var event: BattleEvent = _queue.pop_front()
		event_played.emit(event, 0.0)
	_finish()


## Seconds one step waits at [param at_speed] (R7). Double speed halves the 1× time; instant is 0.
static func step_seconds(kind: BattleEvent.Kind, at_speed: int) -> float:
	if at_speed == SPEED_INSTANT:
		return 0.0
	var seconds: float = DURATIONS[kind]
	if at_speed == SPEED_DOUBLE:
		return seconds * 0.5
	return seconds


## Starts queued steps until one has a wait left, then finishes if nothing is left.
func _play_ready_steps() -> void:
	while _wait_left <= 0.0 and not _queue.is_empty():
		var event: BattleEvent = _queue.pop_front()
		var seconds: float = step_seconds(event.kind, speed)
		event_played.emit(event, seconds)
		_wait_left += seconds
	if _wait_left <= 0.0 and _queue.is_empty():
		_finish()


func _finish() -> void:
	_is_playing = false
	_wait_left = 0.0
	queue_finished.emit()
