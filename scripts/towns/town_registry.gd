extends Node

# Town registry — autoload that owns the canonical list of towns and
# their state. Phase A: 3 stub towns (Coastreach, Black Bastion, Canopyhall),
# 5 named NPCs each, no politics simulation.
# Spec: docs/towns_design.md.

const Town := preload("res://scripts/towns/town.gd")

var towns: Dictionary = {}    # town_id -> Town

func _ready() -> void:
    _seed()
    if Engine.has_singleton("WorldSim"):
        # 10 in-game-minute tick (Phase B) — for now, no-op.
        pass

func _seed() -> void:
    _make_town({
        "id": "coastreach",
        "name": "Coastreach",
        "region": "the Coastreach",
        "population": 4200,
        "mood": 0.62,
        "ruler": {"name": "Lady Mhera Vance", "title": "Marshal of the Lighthouse"},
        "faction_lean": "crown",
        "npcs": [
            {"name": "Bren Goldhand", "role": "tavernkeeper", "trust": 0.7,
             "blurb": "Keeps her ear close to the road. Knows every rumor — invented half of them."},
            {"name": "Master Vrak", "role": "blacksmith", "trust": 0.6,
             "blurb": "Half her family went to Graymarrow. The other half stayed at her shoulder."},
            {"name": "Elder Caisen", "role": "harbormaster", "trust": 0.5,
             "blurb": "Counts ships and silences. Says little, signs everything."},
            {"name": "Silver Wren", "role": "bard", "trust": 0.55,
             "blurb": "Sings of the Sundering for free. Pays for stories."},
            {"name": "Old Tobh", "role": "lighthouse keeper", "trust": 0.65,
             "blurb": "Hasn't missed a sunset in forty winters. Thinks the dark watches him back."},
        ],
        "recent_events": ["A Duskport caravan limped in three days ago, lighter than it left."],
    })
    _make_town({
        "id": "black_bastion",
        "name": "Black Bastion",
        "region": "the Black Bastion",
        "population": 1800,
        "mood": 0.38,
        "ruler": {"name": "Warden-Captain Ohran Reyse", "title": "Warden of the Bastion"},
        "faction_lean": "wardens",
        "npcs": [
            {"name": "Cohrt the Quartermaster", "role": "quartermaster", "trust": 0.7,
             "blurb": "Counts arrows like he counts grandchildren — slowly, suspiciously."},
            {"name": "Sister Devra", "role": "war-priestess of Thaen", "trust": 0.6,
             "blurb": "Blesses every hammer. Her sermons are eight words long."},
            {"name": "Iren Rook", "role": "scout", "trust": 0.55,
             "blurb": "Just came back from the Ruinmarch. Will not say what he saw."},
            {"name": "Old Ash", "role": "dog-handler", "trust": 0.5,
             "blurb": "Three dogs. Two with names. One eats only at midnight."},
            {"name": "Marra Stormrun", "role": "stable-master", "trust": 0.6,
             "blurb": "Gentles horses no one else can. Will not gentle people."},
        ],
        "recent_events": ["Smoke seen east of the river last night — third time this month."],
    })
    _make_town({
        "id": "canopyhall",
        "name": "Canopyhall",
        "region": "Canopyhall",
        "population": 2600,
        "mood": 0.74,
        "ruler": {"name": "Speaker Yelvi Brightleaf", "title": "Voice of the Canopy"},
        "faction_lean": "elves_canopy",
        "npcs": [
            {"name": "Rooth-of-the-Bough", "role": "ranger-master", "trust": 0.7,
             "blurb": "Knows every drake roost within a day's flight."},
            {"name": "Aelwen Verdant", "role": "alchemist", "trust": 0.65,
             "blurb": "Brews potions from sap. Three of them are illegal in the Coastreach."},
            {"name": "Tsiri Gladesinger", "role": "bard", "trust": 0.6,
             "blurb": "Sings to seedlings. The seedlings sing back."},
            {"name": "Old Gron-the-Grafted", "role": "master-grafter", "trust": 0.55,
             "blurb": "Half his arm is wood. He grew it himself."},
            {"name": "Liss Quietleaf", "role": "watchwarden", "trust": 0.55,
             "blurb": "Speaks to no one. Smiles at the youngest children."},
        ],
        "recent_events": ["A drake circled the upper boughs at dawn — the first in a year."],
    })

func _make_town(p: Dictionary) -> void:
    towns[p["id"]] = Town.new(p)

func get_town(id: String) -> Town:
    return towns.get(id, null)

func all_towns() -> Array:
    return towns.values()

func count() -> int:
    return towns.size()
