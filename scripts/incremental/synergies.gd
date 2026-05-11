extends Node

# Named synergy buffs that fire when a specific class combo is on the
# active loadout. Pure data; computed per frame via for_loadout().

const PAIRS := [
    {"a":"warrior",     "b":"rogue",       "label":"Vanguard",   "dmg":0.0,  "atk_speed":0.15, "gold":0.0},
    {"a":"warrior",     "b":"wizard",      "label":"Spellblade", "dmg":0.10, "atk_speed":0.0,  "gold":0.0},
    {"a":"warrior",     "b":"necromancer", "label":"Death Knight","dmg":0.10, "atk_speed":0.0, "gold":0.0},
    {"a":"warrior",     "b":"bard",        "label":"Warden",     "dmg":0.0,  "atk_speed":0.0,  "gold":0.20},
    {"a":"rogue",       "b":"wizard",      "label":"Arcanist",   "dmg":0.0,  "atk_speed":0.0,  "gold":0.0},
    {"a":"rogue",       "b":"necromancer", "label":"Shadowstep", "dmg":0.0,  "atk_speed":0.10, "gold":0.10},
    {"a":"rogue",       "b":"bard",        "label":"Trickster",  "dmg":0.0,  "atk_speed":0.10, "gold":0.0},
    {"a":"wizard",      "b":"necromancer", "label":"Lich",       "dmg":0.15, "atk_speed":0.0,  "gold":0.0},
    {"a":"wizard",      "b":"bard",        "label":"Loremaster", "dmg":0.05, "atk_speed":0.0,  "gold":0.15},
    {"a":"necromancer", "b":"bard",        "label":"Soulsinger", "dmg":0.0,  "atk_speed":0.0,  "gold":0.20},
]

const TRIOS := [
    {"a":"warrior", "b":"rogue",  "c":"wizard", "label":"Triumvirate", "dmg":0.25, "atk_speed":0.0,  "gold":0.0},
    {"a":"warrior", "b":"wizard", "c":"bard",   "label":"Concordat",   "dmg":0.10, "atk_speed":0.10, "gold":0.10},
    {"a":"warrior", "b":"rogue",  "c":"necromancer","label":"Reapers", "dmg":0.20, "atk_speed":0.05, "gold":0.0},
]

# Returns {label, dmg_mult, atk_speed_bonus, gold_mult} for the active loadout,
# or {} if no synergy matches.
static func for_loadout(primary: String, secondary: String, tertiary: String) -> Dictionary:
    if primary == "" or secondary == "":
        return {}
    var set := [primary, secondary]
    if tertiary != "": set.append(tertiary)
    # Try trios first (only when all three slots filled).
    if tertiary != "":
        for t in TRIOS:
            var d: Dictionary = t
            if _has(set, [String(d["a"]), String(d["b"]), String(d["c"])]):
                return {"label": String(d["label"]), "dmg_mult": float(d["dmg"]),
                    "atk_speed_bonus": float(d["atk_speed"]),
                    "gold_mult": float(d["gold"])}
    for p in PAIRS:
        var d: Dictionary = p
        if _has(set, [String(d["a"]), String(d["b"])]):
            return {"label": String(d["label"]), "dmg_mult": float(d["dmg"]),
                "atk_speed_bonus": float(d["atk_speed"]),
                "gold_mult": float(d["gold"])}
    return {}

static func _has(have: Array, want: Array) -> bool:
    for w in want:
        if not have.has(w): return false
    return true
