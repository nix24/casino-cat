extends TestCase
## RngSet stream independence and save-state restore (T004 R6). Uses fixed seeds so failures replay.


func test_streams_are_independent() -> void:
	var rngs := RngSet.for_seed("KITTY-7731")
	for i: int in 100:
		rngs.shop.next_u32()
	var fresh := RngSet.for_seed("KITTY-7731")
	assert_eq(rngs.gamble.next_u32(), fresh.gamble.next_u32(), "gamble after shop draws")


func test_to_states_apply_states_round_trip() -> void:
	var rngs := RngSet.for_seed("KITTY-7731")
	for i: int in 3:
		rngs.map.next_u32()
		rngs.battle.next_u32()
		rngs.gamble.next_u32()
		rngs.reward.next_u32()
		rngs.shop.next_u32()
		rngs.event.next_u32()
	var saved: Dictionary[StringName, int] = rngs.to_states()
	var expected: Dictionary[StringName, Array] = _draw_all(rngs, 10)

	var restored := RngSet.for_seed("KITTY-7731")
	restored.apply_states(saved)
	var actual: Dictionary[StringName, Array] = _draw_all(restored, 10)

	assert_eq(saved.size(), 6, "saved stream count")
	for stream_name: StringName in expected:
		assert_eq(actual[stream_name], expected[stream_name], String(stream_name))


func test_apply_states_unknown_key_ignored() -> void:
	var rngs := RngSet.for_seed("KITTY-7731")
	var states: Dictionary[StringName, int] = rngs.to_states()
	states[&"casino"] = 5
	var restored := RngSet.for_seed("KITTY-7731")
	restored.apply_states(states)
	var twin: Dictionary[StringName, int] = rngs.to_states()
	assert_eq(restored.to_states(), twin, "unknown key leaves streams unchanged")


func test_apply_states_missing_or_zero_keeps_derived() -> void:
	var source := RngSet.for_seed("KITTY-7731")
	for i: int in 50:
		source.gamble.next_u32()
		source.shop.next_u32()
	var states: Dictionary[StringName, int] = source.to_states()
	states.erase(&"gamble")
	states[&"shop"] = 0
	var restored := RngSet.for_seed("KITTY-7731")
	restored.apply_states(states)
	var fresh := RngSet.for_seed("KITTY-7731")
	assert_eq(restored.gamble.next_u32(), fresh.gamble.next_u32(), "missing key keeps derived")
	assert_eq(restored.shop.next_u32(), fresh.shop.next_u32(), "zero state keeps derived")


func _draw_all(rngs: RngSet, count: int) -> Dictionary[StringName, Array]:
	var streams: Dictionary[StringName, SeededRng] = {
		&"map": rngs.map,
		&"battle": rngs.battle,
		&"gamble": rngs.gamble,
		&"reward": rngs.reward,
		&"shop": rngs.shop,
		&"event": rngs.event,
	}
	var draws: Dictionary[StringName, Array] = {}
	for stream_name: StringName in streams:
		var values: Array[int] = []
		for i: int in count:
			values.append(streams[stream_name].next_u32())
		draws[stream_name] = values
	return draws
