extends Node

# Lore codex: 30+ snippets seeded at boot. Player unlocks entries by reading
# items, talking to NPCs, finding journals.

var unlocked: Dictionary = {}      # entry_id -> true

const ENTRIES := [
    {"id":"sundering_intro","title":"The Age of Fractures","cat":"cosmology",
     "text":"Before the Sundering, the elder dragons slept beneath the stone. After it, they rose. The world is now a quilt of broken kingdoms stitched together by trade roads, signal fires, and stubborn knights."},
    {"id":"valehome","title":"Valehome by the Sea","cat":"region",
     "text":"Valehome stands on a chalk-cliff coast. The crown's lighthouse keeps shipping lanes open between the trade-houses. From its keep, every adventurer in the Sundered Realms eventually departs."},
    {"id":"duskport","title":"Duskport's Coin","cat":"region",
     "text":"In Duskport, every door is owned. Even the moonlight pays rent. The Consortium will lend you anything for a price, including your own death warrant."},
    {"id":"thalanore","title":"Thalanore Canopy","cat":"region",
     "text":"The wood-elves do not go down. The roots of Thalanore are sacred ground. Walkways braid the high boughs; a child of the canopy might never feel earth in their lifetime."},
    {"id":"graymarrow","title":"Graymarrow Hold","cat":"region",
     "text":"The dwarves carved Graymarrow before the Sundering. Now they argue, generation by generation, whether the rune-wards on the deepest gates still hold."},
    {"id":"ashfen","title":"Ashfen Caldera","cat":"region",
     "text":"Where the dragon Torath roosts, the air tastes of iron. The black-glass plain glints with the bones of older hunts."},
    {"id":"fearhollow","title":"Fearhollow","cat":"region",
     "text":"The locals keep a candle in every window. Fearhollow is not a place. It is a wound."},
    {"id":"ruinmarch","title":"The Ruinmarch","cat":"region",
     "text":"Once a chain of farming villages. Now smoke and burned barns. The goblin warbands push west each season. The line is currently held — barely — at the river."},
    {"id":"goblin_origins","title":"Of Goblins","cat":"creatures",
     "text":"Goblins were not always so many. The Sundering opened the underdeep; the warrens emptied. Their drumming begins at dusk and only stops to cry retreat."},
    {"id":"goblin_warchiefs","title":"Of Warchiefs","cat":"creatures",
     "text":"A warchief earns the title by eating a rival's heart in front of the tribe. The crown's spies report there are at least seven warchiefs presently in the Ruinmarch alone."},
    {"id":"drakes","title":"Drakes","cat":"creatures",
     "text":"Drakes are dragons that have not yet eaten enough kingdoms. They circle low. They prefer the slow."},
    {"id":"torath","title":"Torath the Unburned","cat":"dragons",
     "text":"Eldest of the Ashfen wyrms. Said to have stalked across the smoking land before there were kingdoms to count. His scales drink fire."},
    {"id":"cinderwyrm","title":"The Cinderwyrm","cat":"dragons",
     "text":"A creature half made of slag. Where it walks, lava follows."},
    {"id":"old_storm","title":"Old Storm","cat":"dragons",
     "text":"The dragon of the high cold. Its breath is not fire. Its breath is winter."},
    {"id":"hearthstone","title":"On the Bond Stone","cat":"items",
     "text":"Set your bond at any safe-shrine. The stone will sing you home. It will not sing you away from a fight."},
    {"id":"forge_master","title":"The Forge","cat":"npc",
     "text":"Master Vrak — half her family went to Graymarrow's deep gates. The other half stayed at her shoulder, hammer in hand."},
    {"id":"tavern_keeper","title":"The Tavernkeeper","cat":"npc",
     "text":"Old Bren keeps her ear close to the road. There is no rumor she has not heard. There are several she invented."},
    {"id":"snikkit","title":"Snikkit the Lucky","cat":"npc",
     "text":"A goblin defector who runs the gambling den. Has lost three fingers to the dice. Will tell you he won them back."},
    {"id":"sennari","title":"Sennari, of the Dice","cat":"pantheon",
     "text":"There is no temple to Sennari. Only altars where coin has changed hands."},
    {"id":"thaen","title":"Thaen of the Hearth","cat":"pantheon",
     "text":"Thaen's prayers are short. Each is a hammer-fall."},
    {"id":"ysmir","title":"Ysmir of the Tide","cat":"pantheon",
     "text":"Sailors carry his sigil in three pieces. If they make the journey, they reunite the pieces and tip them into the sea."},
    {"id":"velis","title":"Velis Brightleaf","cat":"pantheon",
     "text":"Velis grew from the first canopy seed. Where her songs are sung, broken bone knits."},
    {"id":"morrun","title":"Morrun Blackveil","cat":"pantheon",
     "text":"Speak Morrun's name only at need, only into a cupped hand."},
    {"id":"torath_pantheon","title":"Torath the Unburned (god?)","cat":"pantheon",
     "text":"Some call Torath a god. Most who say so have never met him."},
    {"id":"first_keep","title":"On the First Keep","cat":"history",
     "text":"The Crown's keep was raised on bedrock that did not crack during the Sundering. They chose well. They built well."},
    {"id":"warbands","title":"On the Warbands","cat":"history",
     "text":"The first warbands came at the spring rains, three years after the Sundering. They have not stopped."},
    {"id":"runes","title":"Of Runes","cat":"magic",
     "text":"A rune is a promise written in pressure. Press too hard and it cracks. Press too soft and the world forgets it."},
    {"id":"weave","title":"Of the Weave","cat":"magic",
     "text":"The Weave runs everywhere. After the Sundering, in some places, it runs the wrong way."},
    {"id":"oaths","title":"Of Oaths","cat":"magic",
     "text":"Paladins swear oaths to gods. The gods, mostly, listen. Mostly."},
    {"id":"bond_song","title":"The Bond Song","cat":"magic",
     "text":"Bards' songs hold a piece of every place they've passed through. Cut a string of the right bard's lute and you might hear a whole road."},
    {"id":"dragon_shards","title":"Dragon Shards","cat":"items",
     "text":"A piece of a dragon hardens in the air. Saved properly, the piece becomes a key. Saved badly, it becomes a curse."},
    {"id":"goblin_oil","title":"Goblin Oil","cat":"items",
     "text":"Sappers carry it. When it spills, it does not stop spilling. Light a torch downwind. Always."},
    {"id":"warband_drums","title":"On the Drums","cat":"history",
     "text":"You hear them before you see the warband. The drums are warning. Sometimes they are also a question."},
    {"id":"forge_oath","title":"The Forge Oath","cat":"history",
     "text":"At Vrak's forge, there is an oath cut into the stone. Translated: 'Strike true. Strike now. The world will not.'"},
    {"id":"crown_blade","title":"The Crown Blade","cat":"history",
     "text":"Sir Alric carried a Crown blade at the Iron Tide. It was lost. It is not, the Crown insists, lost forever."},
]

func _ready() -> void:
    pass

func unlock_entry(entry_id: String) -> bool:
    if unlocked.has(entry_id):
        return false
    unlocked[entry_id] = true
    EventBus.lore_unlocked.emit(entry_id)
    QuestSystem.mark_lore_read(entry_id)
    return true

func unlock_random_dragon() -> String:
    var pool := ENTRIES.filter(func(e): return (e as Dictionary)["cat"] == "dragons" and not unlocked.has((e as Dictionary)["id"]))
    if pool.is_empty():
        return ""
    var pick: Dictionary = pool[randi() % pool.size()]
    unlock_entry(pick["id"])
    return pick["id"]

func get_entry(entry_id: String) -> Dictionary:
    for e in ENTRIES:
        if (e as Dictionary)["id"] == entry_id:
            return e
    return {}

func unlocked_count() -> int:
    return unlocked.size()

func by_category(cat: String) -> Array:
    return ENTRIES.filter(func(e): return (e as Dictionary)["cat"] == cat)
