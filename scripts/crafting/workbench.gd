extends Node

# Workbench — third crafting station. Produces accessories: rings,
# amulets, charms, belts. Mirrors Forge / Alchemy architecture.

const MOUNTS := [
    {"id":"ring",   "name":"Ring",      "slot":"ring",  "stat_mult":1.0,  "tags":["jewelry"]},
    {"id":"amulet", "name":"Amulet",    "slot":"neck",  "stat_mult":1.4,  "tags":["jewelry"]},
    {"id":"charm",  "name":"Charm",     "slot":"trinket","stat_mult":1.0, "tags":["jewelry","passive"]},
    {"id":"belt",   "name":"Belt",      "slot":"belt",  "stat_mult":0.85, "tags":["belt"]},
]

const STONES := [
    {"id":"agate",      "name":"Agate",      "stat":"crit_chance", "min":0.02, "max":0.05},
    {"id":"sapphire",   "name":"Sapphire",   "stat":"max_mp",      "min":8,    "max":18},
    {"id":"ruby",       "name":"Ruby",       "stat":"fire_dmg",    "min":3,    "max":7},
    {"id":"opal",       "name":"Opal",       "stat":"max_hp",      "min":12,   "max":24},
    {"id":"dragonglass","name":"Dragonglass","stat":"crit_damage", "min":0.10, "max":0.20},
]

const INSCRIPTIONS := [
    {"id":"none",       "name":"Plain",          "bonus_stat":""},
    {"id":"rune_str",   "name":"Rune of Bear",   "bonus_stat":"str",  "bonus":3},
    {"id":"rune_agi",   "name":"Rune of Hare",   "bonus_stat":"agi",  "bonus":3},
    {"id":"rune_int",   "name":"Rune of Owl",    "bonus_stat":"int",  "bonus":3},
    {"id":"rune_sta",   "name":"Rune of Stone",  "bonus_stat":"sta",  "bonus":3},
]

const QUALITY_TIERS := ["Crude", "Worn", "Fine", "Exquisite", "Masterwork"]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func get_mount(id: String) -> Dictionary:
    for m in MOUNTS:
        if m["id"] == id: return m
    return {}

func get_stone(id: String) -> Dictionary:
    for s in STONES:
        if s["id"] == id: return s
    return {}

func get_inscription(id: String) -> Dictionary:
    for i in INSCRIPTIONS:
        if i["id"] == id: return i
    return {}

func craft(selections: Dictionary) -> Dictionary:
    var mount: Dictionary = get_mount(selections.get("mount", ""))
    var stone: Dictionary = get_stone(selections.get("stone", ""))
    var inscription: Dictionary = get_inscription(selections.get("inscription", "none"))
    if mount.is_empty() or stone.is_empty():
        return {}
    var quality: int = _roll_quality(int(selections.get("skill_level", 1)))
    var quality_mult: float = 1.0 + 0.10 * float(quality)
    var stat_value: float = rng.randf_range(float(stone["min"]), float(stone["max"])) * \
        float(mount["stat_mult"]) * quality_mult
    var stats: Dictionary = {}
    stats[String(stone["stat"])] = stat_value
    if inscription.has("bonus_stat") and String(inscription["bonus_stat"]) != "":
        stats[String(inscription["bonus_stat"])] = float(inscription["bonus"]) * quality_mult
    var tags: Array = []
    for src in [mount, stone, inscription]:
        for t in src.get("tags", []):
            if not tags.has(t): tags.append(t)
    var name_parts: Array = []
    if quality >= 4: name_parts.append("Masterwork")
    elif quality >= 2: name_parts.append("Fine")
    name_parts.append(String(stone["name"]))
    name_parts.append(String(mount["name"]))
    var name: String = " ".join(name_parts)
    return {
        "name": name,
        "slot": String(mount["slot"]),
        "kind": "accessory",
        "mount": String(mount["id"]),
        "stone": String(stone["id"]),
        "inscription": String(inscription.get("id", "none")),
        "tags": tags,
        "stats": stats,
        "rarity": _rarity_for_quality(quality, inscription),
        "quality": quality,
        "quality_label": QUALITY_TIERS[quality],
        "ilvl": 1 + (quality * 4),
        "crafted": true,
    }

func _roll_quality(skill_level: int) -> int:
    var weights_by_skill := {
        1: [40, 35, 18, 6, 1],
        2: [25, 35, 25, 12, 3],
        3: [12, 28, 32, 21, 7],
        4: [5,  18, 30, 30, 17],
        5: [2,   8, 22, 35, 33],
    }
    var weights: Array = weights_by_skill.get(clampi(skill_level, 1, 5), weights_by_skill[1])
    var total: float = 0.0
    for w in weights: total += float(w)
    var pick: float = rng.randf() * total
    var acc: float = 0.0
    for i in range(weights.size()):
        acc += float(weights[i])
        if pick <= acc:
            return i
    return weights.size() - 1

func _rarity_for_quality(quality: int, inscription: Dictionary) -> int:
    var base: int = clampi(quality, 0, 4)
    if String(inscription.get("id", "none")) != "none":
        base = min(base + 1, 5)
    return base
