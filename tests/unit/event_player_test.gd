extends TestCase
## EventPlayer's clock and queue (T003, R7, R8): seconds per kind and speed, step order, skip, and
## the instant path.


func test_step_seconds_1x() -> void:
	var normal: int = EventPlayer.SPEED_NORMAL
	assert_eq(EventPlayer.step_seconds(BattleEvent.Kind.DAMAGE_DEALT, normal), 0.4, "damage")
	assert_eq(EventPlayer.step_seconds(BattleEvent.Kind.MP_CHANGED, normal), 0.2, "mp")
	assert_eq(EventPlayer.step_seconds(BattleEvent.Kind.STATUS_APPLIED, normal), 0.25, "status")
	assert_eq(EventPlayer.step_seconds(BattleEvent.Kind.BATTLE_WON, normal), 0.6, "won")


func test_step_seconds_2x_halves() -> void:
	var double: int = EventPlayer.SPEED_DOUBLE
	assert_eq(EventPlayer.step_seconds(BattleEvent.Kind.DAMAGE_DEALT, double), 0.2, "damage")


func test_instant_is_zero() -> void:
	for kind: BattleEvent.Kind in BattleEvent.Kind.values():
		var seconds: float = EventPlayer.step_seconds(kind, EventPlayer.SPEED_INSTANT)
		assert_eq(seconds, 0.0, str(BattleEvent.Kind.keys()[kind]))


func test_every_kind_has_a_duration() -> void:
	for kind: BattleEvent.Kind in BattleEvent.Kind.values():
		var kind_name: String = str(BattleEvent.Kind.keys()[kind])
		assert_true(EventPlayer.DURATIONS.has(kind), "%s has no duration" % kind_name)
		if EventPlayer.DURATIONS.has(kind):
			assert_true(EventPlayer.DURATIONS[kind] >= 0.0, "%s duration is negative" % kind_name)


func test_plays_in_order_and_waits() -> void:
	var player := EventPlayer.new()
	var played: Array[BattleEvent.Kind] = []
	var finished: Array[int] = []
	player.event_played.connect(
		func(event: BattleEvent, _seconds: float) -> void: played.append(event.kind)
	)
	player.queue_finished.connect(func() -> void: finished.append(0))
	player.speed = EventPlayer.SPEED_NORMAL

	(
		player
		. enqueue(
			_events(
				[
					BattleEvent.Kind.MOVE_USED,
					BattleEvent.Kind.DAMAGE_DEALT,
					BattleEvent.Kind.MP_CHANGED,
				]
			)
		)
	)
	assert_eq(played, [BattleEvent.Kind.MOVE_USED], "only the first step plays at once")
	player.advance(0.1)
	assert_eq(played.size(), 1, "still waiting on MOVE_USED")
	player.advance(0.15)
	assert_eq(played.back(), BattleEvent.Kind.DAMAGE_DEALT, "damage after 0.2 s")
	player.advance(0.45)
	assert_eq(played.back(), BattleEvent.Kind.MP_CHANGED, "mp after the damage wait")
	player.advance(0.25)
	assert_eq(finished.size(), 1, "queue_finished once")
	assert_true(player.is_idle(), "idle after the queue empties")
	player.free()


func test_zero_second_steps_chain() -> void:
	var player := EventPlayer.new()
	var played: Array[BattleEvent.Kind] = []
	var finished: Array[int] = []
	player.event_played.connect(
		func(event: BattleEvent, _seconds: float) -> void: played.append(event.kind)
	)
	player.queue_finished.connect(func() -> void: finished.append(0))
	player.speed = EventPlayer.SPEED_NORMAL

	player.enqueue(_events([BattleEvent.Kind.TURN_STARTED, BattleEvent.Kind.INTENT_SHOWN]))
	assert_eq(played.size(), 2, "the zero-wait step doesn't hold up the next one")
	player.advance(0.19)
	assert_eq(finished.size(), 0, "INTENT_SHOWN waits 0.2 s")
	player.advance(0.02)
	assert_eq(finished.size(), 1, "queue finishes after the wait")
	player.free()


func test_skip_to_end_drains() -> void:
	var player := EventPlayer.new()
	var played: Array[BattleEvent.Kind] = []
	var seconds_seen: Array[float] = []
	var skips: Array[int] = []
	var finished: Array[int] = []
	player.event_played.connect(
		func(event: BattleEvent, seconds: float) -> void:
			played.append(event.kind)
			seconds_seen.append(seconds)
	)
	player.skipped.connect(func() -> void: skips.append(0))
	player.queue_finished.connect(func() -> void: finished.append(0))
	player.speed = EventPlayer.SPEED_NORMAL

	(
		player
		. enqueue(
			_events(
				[
					BattleEvent.Kind.MOVE_USED,
					BattleEvent.Kind.DAMAGE_DEALT,
					BattleEvent.Kind.MP_CHANGED,
				]
			)
		)
	)
	player.skip_to_end()
	assert_eq(skips.size(), 1, "skipped once")
	assert_eq(played.size(), 3, "every event played")
	assert_eq(seconds_seen[1], 0.0, "damage plays with no wait")
	assert_eq(seconds_seen[2], 0.0, "mp plays with no wait")
	assert_eq(finished.size(), 1, "queue_finished once")
	assert_true(player.is_idle(), "idle after the skip")
	player.free()


func test_instant_speed_is_synchronous() -> void:
	var player := EventPlayer.new()
	var played: Array[BattleEvent.Kind] = []
	var finished: Array[int] = []
	player.event_played.connect(
		func(event: BattleEvent, _seconds: float) -> void: played.append(event.kind)
	)
	player.queue_finished.connect(func() -> void: finished.append(0))
	player.speed = EventPlayer.SPEED_INSTANT

	(
		player
		. enqueue(
			_events(
				[
					BattleEvent.Kind.MOVE_USED,
					BattleEvent.Kind.DAMAGE_DEALT,
					BattleEvent.Kind.MP_CHANGED,
				]
			)
		)
	)
	assert_eq(played.size(), 3, "all three played inside enqueue")
	assert_eq(finished.size(), 1, "finished inside enqueue")
	player.free()


func test_enqueue_while_playing_appends() -> void:
	var player := EventPlayer.new()
	var played: Array[BattleEvent.Kind] = []
	player.event_played.connect(
		func(event: BattleEvent, _seconds: float) -> void: played.append(event.kind)
	)
	player.speed = EventPlayer.SPEED_NORMAL

	player.enqueue(_events([BattleEvent.Kind.MOVE_USED]))
	player.enqueue(_events([BattleEvent.Kind.DAMAGE_DEALT]))
	assert_eq(played.size(), 1, "the second batch waits behind the first")
	player.advance(0.2)
	assert_eq(played, [BattleEvent.Kind.MOVE_USED, BattleEvent.Kind.DAMAGE_DEALT], "in order")
	player.free()


# --- helpers ---------------------------------------------------------------------------------


func _events(kinds: Array[BattleEvent.Kind]) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for kind: BattleEvent.Kind in kinds:
		events.append(BattleEvent.new(kind))
	return events
