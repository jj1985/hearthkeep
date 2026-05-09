extends Node

# Engraving Bench — cosmetic engraving + small stat tweaks. 7th and final
# crafting station.
#
# Unique: takes an EXISTING item and modifies it in-place rather than
# producing a new one. Returns the same item dict with engraving / cosmetic
# stat tweak applied. Cost = gold.

const SCRIPTS := [
    {"id":"plain",      "name":"Plain Etch",          "cost": 200, "tweak":""},
    {"id":"cinder",     "name":"Cinder Script",       "cost": 400, "tweak":"fire_dmg"},
    {"id":"frost",      "name":"Frostline Script",    "cost": 400, "tweak":"frost_dmg"},
    {"id":"holy",       "name":"Aurate Script",       "cost": 600, "tweak":"holy_dmg"},
    {"id":"shadow",     "name":"Shadowline",          "cost": 600, "tweak":"crit_dmg"},
    {"id":"draconic",   "name":"Draconic Engraving",  "cost":1200, "tweak":"all_dmg"},
]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func cost_for(script_id: String) -> int:
    var s: Dictionary = _find(SCRIPTS, script_id)
    return int(s.get("cost", 0))

func engrave(item: Dictionary, script_id: String, label: String = "") -> Dictionary:
    if item.is_empty(): return item
    var s: Dictionary = _find(SCRIPTS, script_id)
    if s.is_empty(): return item
    var cost: int = int(s.get("cost", 0))
    if GameState.gold < cost:
        return {}
    GameState.add_gold(-cost)
    item["engraving"] = label
    item["engraving_script"] = script_id
    if label != "":
        item["name"] = "%s — \"%s\"" % [String(item.get("name", "?")), label]
    var tweak: String = String(s.get("tweak", ""))
    if tweak != "":
        var stats: Dictionary = item.get("stats", {})
        var bump: float = 1.0 + rng.randf_range(0.5, 2.5)
        match tweak:
            "fire_dmg", "frost_dmg", "holy_dmg":
                stats[tweak] = float(stats.get(tweak, 0)) + bump * 2.0
            "crit_dmg":
                stats["crit_damage"] = float(stats.get("crit_damage", 0)) + bump * 0.05
            "all_dmg":
                stats["dmg_min"] = int(float(stats.get("dmg_min", 0)) + bump)
                stats["dmg_max"] = int(float(stats.get("dmg_max", 0)) + bump * 2.0)
        item["stats"] = stats
    # Bump rarity by 1 if scripts apply a tweak
    if tweak != "":
        item["rarity"] = clampi(int(item.get("rarity", 0)) + 1, 0, 5)
    return item

func _find(arr: Array, id: String) -> Dictionary:
    for x in arr:
        if x["id"] == id: return x
    return {}
