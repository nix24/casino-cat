extends TestCase
## SeedWords: the 32 D42 words in order, and seeds that read "WORD-NNNN" with a number from 1000 to
## 9999. Draws only come from SeededRng, so the same seed text always gives the same seeds (T006).

const DRAWS: int = 500


func test_words_are_the_32_d42_words() -> void:
	assert_eq(
		SeedWords.WORDS,
		PackedStringArray(
			[
				"KITTY",
				"PAWS",
				"WHISKER",
				"PURR",
				"MEOW",
				"TUXEDO",
				"FELINE",
				"CATNIP",
				"YARN",
				"MOUSE",
				"SARDINE",
				"TABBY",
				"CALICO",
				"MITTENS",
				"ALLEY",
				"NEON",
				"VELVET",
				"JACKPOT",
				"LUCKY",
				"ACES",
				"DICE",
				"SPADES",
				"HEARTS",
				"DIAMONDS",
				"CLUBS",
				"FORTUNE",
				"MOONLIT",
				"MIDNIGHT",
				"ROOFTOP",
				"LOUNGE",
				"PEARL",
				"BOWTIE",
			]
		),
		"word list"
	)


func test_generate_format_and_range() -> void:
	var rng := SeededRng.new("seed-words-format")
	var pattern := RegEx.create_from_string("^([A-Z]+)-(\\d{4})$")
	for draw: int in DRAWS:
		var seed_text: String = SeedWords.generate(rng)
		var found: RegExMatch = pattern.search(seed_text)
		assert_true(found != null, "format: %s" % seed_text)
		if found == null:
			return
		assert_true(SeedWords.WORDS.has(found.get_string(1)), "known word: %s" % seed_text)
		var number: int = found.get_string(2).to_int()
		assert_true(number >= 1000 and number <= 9999, "number range: %s" % seed_text)


func test_generate_is_deterministic() -> void:
	var first := SeededRng.new("seed-words-repeat")
	var second := SeededRng.new("seed-words-repeat")
	for draw: int in DRAWS:
		assert_eq(SeedWords.generate(first), SeedWords.generate(second), "draw %d" % draw)
