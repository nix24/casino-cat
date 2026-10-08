extends TestCase


func test_same_seed_gives_same_stream() -> void:
	var a := SeededRng.new("lucky-7")
	var b := SeededRng.new("lucky-7")
	for i: int in 50:
		assert_eq(a.next_u32(), b.next_u32(), "value %d" % i)


func test_sub_streams_are_independent() -> void:
	var battle := SeededRng.derive("lucky-7", "battle")
	var shop := SeededRng.derive("lucky-7", "shop")
	assert_true(battle.next_u32() != shop.next_u32())


func test_hash_is_fnv1a() -> void:
	# Published FNV-1a 32-bit vectors; if these change, every saved seed breaks.
	assert_eq(SeededRng.hash_text(""), 0x811C9DC5)
	assert_eq(SeededRng.hash_text("a"), 0xE40C292C)
	assert_eq(SeededRng.hash_text("foobar"), 0xBF9CF968)


func test_range_int_stays_in_bounds() -> void:
	var rng := SeededRng.new("bounds")
	for i: int in 1000:
		var roll: int = rng.range_int(1, 6)
		assert_true(roll >= 1 and roll <= 6, "roll %d out of range" % roll)
