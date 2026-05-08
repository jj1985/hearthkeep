extends Node

# IP-distance pass: renamed from "Norrath" (Daybreak Game Co. trademark).
# This world is "Aerathis — the Sundered Realms" — original setting.
# All in-game text, dialogue, lore, and place names use this naming.

const WORLD_NAME := "Aerathis"
const WORLD_SUBTITLE := "the Sundered Realms"
const TAGLINE := "An age of fractures. A world remade by dragonfire and goblin tide."

const REGIONS := {
    "valehome": {
        "name": "Valehome",
        "blurb": "Coastal trading kingdom. Banners of trade-houses snap on stone keep walls. Kelp markets and lighthouse spires.",
        "vibe": "warm coastal medieval",
        "music_track": "valehome_theme",
        "lighting_tint": Color(1.05, 0.97, 0.85),
    },
    "duskport": {
        "name": "Duskport",
        "blurb": "Dark city-state of locked guild halls and gallows-shadow alleys. Coin still rules — the question is whose coin.",
        "vibe": "shadow noir medieval",
        "music_track": "duskport_theme",
        "lighting_tint": Color(0.7, 0.7, 0.95),
    },
    "thalanore": {
        "name": "Thalanore Canopy",
        "blurb": "Treetop city of the high-wood elves. Walkways braided with living vine, leaf-light filtered through gold.",
        "vibe": "elven canopy",
        "music_track": "thalanore_theme",
        "lighting_tint": Color(0.85, 1.05, 0.85),
    },
    "graymarrow": {
        "name": "Graymarrow Hold",
        "blurb": "Dwarven mountain stronghold. Forge-glow on basalt, runes pulsing along iron-banded gates.",
        "vibe": "dwarven mountain",
        "music_track": "graymarrow_theme",
        "lighting_tint": Color(1.05, 0.85, 0.6),
    },
    "ashfen": {
        "name": "Ashfen Caldera",
        "blurb": "Volcanic waste. Black glass underfoot and hot wind that smells of iron and dragon.",
        "vibe": "volcanic dragon-touched",
        "music_track": "ashfen_theme",
        "lighting_tint": Color(1.2, 0.55, 0.4),
    },
    "fearhollow": {
        "name": "Fearhollow",
        "blurb": "A wound between worlds. Where waking dreams crawl out at moonless tide.",
        "vibe": "planar fear realm",
        "music_track": "fearhollow_theme",
        "lighting_tint": Color(0.55, 1.10, 0.65),
    },
    "ruinmarch": {
        "name": "The Ruinmarch",
        "blurb": "Goblin warband front. Burned villages. Iron-banded oak doors splintered. Smoke against the sky.",
        "vibe": "burned wilderness",
        "music_track": "ruinmarch_theme",
        "lighting_tint": Color(1.0, 0.75, 0.55),
    },
}

const PANTHEON := [
    {"id":"thaen","name":"Thaen the Forge","domain":"craft, oath, hearth"},
    {"id":"ysmir","name":"Ysmir of the Tide","domain":"voyage, fortune, the deep"},
    {"id":"velis","name":"Velis Brightleaf","domain":"growth, song, healing"},
    {"id":"morrun","name":"Morrun Blackveil","domain":"shadow, secrets, the long path"},
    {"id":"torath","name":"Torath the Unburned","domain":"dragonfire, ash, war"},
    {"id":"sennari","name":"Sennari","domain":"chance, gambling, the dice's edge"},
]

# AGE OF FRACTURES — opening cosmology.
# The Sundering split the world's bedrock and uncaged the elder dragons.
# Goblin tribes — once chained beneath dwarven holds — poured up. The kingdoms
# fell back to their stone keeps. From these keeps, the new generation of
# adventurers carries gold and steel out into the dark to set things right,
# or die richer.

const FACTIONS := {
    "valehome_crown": {"name":"Valehome Crown","blurb":"Trade-house knights and crown coin."},
    "duskport_consortium": {"name":"Duskport Consortium","blurb":"Guildmasters who lend a price for everything."},
    "thalanore_council": {"name":"Thalanore Council","blurb":"Elven keepers of the canopy and the long memory."},
    "graymarrow_clans": {"name":"Graymarrow Clans","blurb":"Dwarven smiths and rune-wardens of the deep stone."},
    "free_companies": {"name":"Free Companies","blurb":"Mercenary warbands. Gold first; questions later."},
}
