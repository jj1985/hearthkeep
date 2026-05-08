extends Node

# HEARTHKEEP world bible (originally drafted with EQ-proximity terms; this
# revision scrubs all near-trademark vocabulary in line with the IP-distance
# mandate). Region IDs from the user-supplied GDD vocab where applicable.

const GAME_TITLE := "HEARTHKEEP"
const WORLD_NAME := "the Sundered Realms"
const WORLD_SUBTITLE := "of the Sundered Realms"
const TAGLINE := "An age of fractures. A world remade by dragonfire and goblin tide."

const REGIONS := {
    "coastreach": {
        "name": "the Coastreach",
        "blurb": "Coastal trading kingdom. Banners of trade-houses snap on stone keep walls. Kelp markets and lighthouse spires. Home of the player's Hearthkeep villa.",
        "vibe": "warm coastal medieval",
        "music_track": "coastreach_theme",
        "lighting_tint": Color(1.05, 0.97, 0.85),
    },
    "black_bastion": {
        "name": "the Black Bastion",
        "blurb": "Dark city-state of locked guild halls and gallows-shadow alleys. Coin still rules — the question is whose coin.",
        "vibe": "shadow noir medieval",
        "music_track": "bastion_theme",
        "lighting_tint": Color(0.7, 0.7, 0.95),
    },
    "canopyhall": {
        "name": "Canopyhall",
        "blurb": "Treetop city of the high-wood elves. Walkways braided with living vine, leaf-light filtered through gold.",
        "vibe": "elven canopy",
        "music_track": "canopyhall_theme",
        "lighting_tint": Color(0.85, 1.05, 0.85),
    },
    "kaeldur": {
        "name": "Kaeldur",
        "blurb": "Dwarven mountain stronghold. Forge-glow on basalt, runes pulsing along iron-banded gates.",
        "vibe": "dwarven mountain",
        "music_track": "kaeldur_theme",
        "lighting_tint": Color(1.05, 0.85, 0.6),
    },
    "cinderwastes": {
        "name": "the Cinderwastes",
        "blurb": "Volcanic waste. Black glass underfoot and hot wind that smells of iron and dragon. Where the elder wyrm Vyxhasis stalks.",
        "vibe": "volcanic dragon-touched",
        "music_track": "cinderwastes_theme",
        "lighting_tint": Color(1.2, 0.55, 0.4),
    },
    "veiled_plane": {
        "name": "the Veiled Plane",
        "blurb": "A wound between worlds. Where waking dreams crawl out at moonless tide.",
        "vibe": "planar fear realm",
        "music_track": "veiled_theme",
        "lighting_tint": Color(0.55, 1.10, 0.65),
    },
    "ruinmarch": {
        "name": "The Ruinmarch",
        "blurb": "Goblin warband front, where Krrik III's tribe pushes west each season. Burned villages. Smoke against the sky.",
        "vibe": "burned wilderness",
        "music_track": "ruinmarch_theme",
        "lighting_tint": Color(1.0, 0.75, 0.55),
    },
}

const DRAGONS := {
    "vyxhasis": {"name":"Vyxhasis the Unburned","region":"cinderwastes","element":"fire"},
    "ourzhal":  {"name":"Ourzhal of the Storm","region":"kaeldur","element":"lightning"},
    "aethyrnax":{"name":"Aethyrnax the Frost-Wyrm","region":"veiled_plane","element":"frost"},
}

const GOBLIN_KING := {"id":"krrik_iii","name":"Krrik the Third"}

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
    "coastreach_crown": {"name":"Coastreach Crown","blurb":"Trade-house knights and crown coin."},
    "bastion_consortium": {"name":"Black Bastion Consortium","blurb":"Guildmasters who lend a price for everything."},
    "canopyhall_council": {"name":"Canopyhall Council","blurb":"Elven keepers of the canopy and the long memory."},
    "kaeldur_clans": {"name":"Kaeldur Clans","blurb":"Dwarven smiths and rune-wardens of the deep stone."},
    "free_companies": {"name":"Free Companies","blurb":"Mercenary warbands. Gold first; questions later."},
}
