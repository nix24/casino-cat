extends TestCase


func test_each_suit_beats_the_next() -> void:
	assert_eq(Suit.damage_multiplier(Suit.Type.SPADES, Suit.Type.HEARTS), 1.5)
	assert_eq(Suit.damage_multiplier(Suit.Type.HEARTS, Suit.Type.DIAMONDS), 1.5)
	assert_eq(Suit.damage_multiplier(Suit.Type.DIAMONDS, Suit.Type.SPADES), 1.5)


func test_disadvantage_is_the_reverse() -> void:
	assert_eq(Suit.damage_multiplier(Suit.Type.HEARTS, Suit.Type.SPADES), 0.75)
	assert_eq(Suit.damage_multiplier(Suit.Type.DIAMONDS, Suit.Type.HEARTS), 0.75)
	assert_eq(Suit.damage_multiplier(Suit.Type.SPADES, Suit.Type.DIAMONDS), 0.75)


func test_same_suit_and_clubs_are_neutral() -> void:
	for suit: Suit.Type in Suit.Type.values():
		assert_eq(Suit.damage_multiplier(suit, suit), 1.0, "same suit %s" % suit)
		assert_eq(Suit.damage_multiplier(Suit.Type.CLUBS, suit), 1.0, "clubs attacking %s" % suit)
		assert_eq(Suit.damage_multiplier(suit, Suit.Type.CLUBS), 1.0, "%s attacking clubs" % suit)
