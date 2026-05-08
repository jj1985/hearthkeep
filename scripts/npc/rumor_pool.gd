extends Node

# Tavernkeeper rumor pool — 25+ entries, some tied to world state.

const RUMORS := [
    "Heard a wing-shadow over Ashfen at sundown. Torath's stretching.",
    "Master Vrak's forge has had three travelers ask about Crown blades this week.",
    "Snikkit's lost his thumb again. Or never had it. Don't ask.",
    "Carriage came in from Duskport with the curtains drawn the whole way.",
    "Goblin drums in the Ruinmarch — three days running.",
    "Wood-elves have stopped sending caravans west. Word is they're closing the canopy.",
    "Someone at Graymarrow's outer gate carved a new rune last week. The dwarves won't say what it does.",
    "The lighthouse keeper at Valehome saw something in the fog. He says it didn't have legs.",
    "Brought the carnival back. Bring me coin and I'll bring you a rumor about the dice.",
    "A merchant came through with a stone that hummed. Sold for two hundred. He'd taken it from a goblin oil-drum.",
    "Old Bren says Sennari's altars in Duskport are seeing more visitors. That, or more thieves.",
    "Kid in the back swears he saw a knight ride through with no helm. Smiling.",
    "Whetstones running short. Forge can't say why. Sappers are buying them.",
    "Three caravan guards walked into Fearhollow. One came back. He doesn't sleep.",
    "Bards' Hall in Thalanore is auditioning for a Seven-Stringer. Last one who tried it lost his hands.",
    "Goblin warband came up to the river last full moon and just stood there. Just stood there.",
    "A Drake circled the ridge at first light. Did not stoop. Studying us, I think.",
    "Crown's posted a bounty list at the gate this morning. The numbers are bigger than usual.",
    "Tavern's running low on the cold-cellar barrels. They blame the goblins. They blame the goblins for everything.",
    "Wandering merchant should be back in three days. Saw his cart on the south road.",
    "Snikkit's selling 'dragon blood' again. It's beet juice and prayer.",
    "There's a hunter at the bar who says the deer in the high wood are running south. All of them.",
    "Plague Doctor came through asking after Drake Scales. Paid in coin that wasn't ours.",
    "I dreamt a rune. I don't know runes. The forge master says it was a real one.",
    "Sir Alric's blade — the Crown is paying for any sighting. Any sighting.",
    "A goblin defector turned up at the south gate at dawn. He's eating bread in the tavern's kitchen.",
    "Storm coming in from the east. The fishermen pulled in early. Read your runes.",
    "There's a new song in the Bards' Hall: 'The Hollow Pact.' Don't sing it after dark.",
    "Old Bren's tabby has stopped going outside. That cat goes outside. Something's off.",
    "Forgot what I was going to say. The drums, maybe. Always the drums.",
]

var rng := RandomNumberGenerator.new()
var seen: Array[int] = []

func _ready() -> void:
    rng.randomize()

func roll() -> String:
    if seen.size() >= RUMORS.size():
        seen.clear()
    var attempts := 0
    while attempts < 50:
        var i := rng.randi_range(0, RUMORS.size() - 1)
        if not seen.has(i):
            seen.append(i)
            return RUMORS[i]
        attempts += 1
    return RUMORS[0]
