class_name SeedWords
extends RefCounted
## Readable run seeds, "WORD-NNNN" (PRD §17.3, decisions D42). The word list is cat and casino
## vocabulary so a seed reads like a name on a card. Drawn from a SeededRng, never a global RNG.

const WORDS: PackedStringArray = [
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


## Returns one seed such as "KITTY-7731": a word, a dash, and a number from 1000 to 9999.
static func generate(rng: SeededRng) -> String:
	var word: String = WORDS[rng.range_int(0, WORDS.size() - 1)]
	return "%s-%d" % [word, rng.range_int(1000, 9999)]
