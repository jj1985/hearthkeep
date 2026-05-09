extends Node

# Tailoring Loom — cloth armor, capes, banners, bags. 5th station.

const PIECES := [
    {"id":"robe",   "name":"Robe",     "slot":"chest",     "tags":["cloth","armor"]},
    {"id":"hood",   "name":"Hood",     "slot":"head",      "tags":["cloth","armor"]},
    {"id":"cloak",  "name":"Cloak",    "slot":"cloak",     "tags":["cloth","cloak"]},
    {"id":"gloves", "name":"Gloves",   "slot":"hands",     "tags":["cloth"]},
    {"id":"banner", "name":"Banner",   "slot":"display",   "tags":["banner","display"]},
]

const FABRICS := [
    {"id":"linen",     "name":"Linen",      "armor": 2,  "tags":[]},
    {"id":"silk",      "name":"Silk",       "armor": 3,  "tags":["finesse"]},
    {"id":"shadowsilk","name":"Shadowsilk", "armor": 4,  "tags":["stealth","cool"]},
    {"id":"runeweave", "name":"Runeweave",  "armor": 6,  "tags":["caster_focus"]},
    {"id":"dragonsilk","name":"Dragonsilk", "armor": 9,  "tags":["fire_res","rare"]},
]

const TRIM := [
    {"id":"none",        "name":"Plain",         "stat_bonus": ""},
    {"id":"gold_thread", "name":"Gold Thread",   "stat_bonus": "magic_find", "bonus": 0.05},
    {"id":"silver_braid","name":"Silver Braid",  "stat_bonus": "armor",      "bonus": 2},
    {"id":"ember_brocade","name":"Ember Brocade","stat_bonus": "fire_dmg",   "bonus": 3},
]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func craft(selections: Dictionary) -> Dictionary:
    var piece: Dictionary = _find(PIECES, selections.get("piece", ""))
    var fabric: Dictionary = _find(FABRICS, selections.get("fabric", ""))
    var trim: Dictionary = _find(TRIM, selections.get("trim", "none"))
    if piece.is_empty() or fabric.is_empty():
        return {}
    var quality: int = _roll_quality(int(selections.get("skill_level", 1)))
    var quality_mult: float = 1.0 + 0.10 * float(quality)
    var stats: Dictionary = {"armor": float(fabric["armor"]) * quality_mult}
    if String(trim.get("stat_bonus", "")) != "":
        stats[String(trim["stat_bonus"])] = float(trim.get("bonus", 0.0)) * quality_mult
    var tags: Array = []
    for src in [piece, fabric]:
        for t in src.get("tags", []):
            if not tags.has(t): tags.append(t)
    var name_parts: Array = []
    if quality >= 4: name_parts.append("Masterwork")
    name_parts.append(String(fabric["name"]))
    name_parts.append(String(piece["name"]))
    var name: String = " ".join(name_parts)
    return {
        "name": name,
        "slot": String(piece["slot"]),
        "kind": "armor",
        "piece": String(piece["id"]),
        "fabric": String(fabric["id"]),
        "trim": String(trim.get("id", "none")),
        "tags": tags,
        "stats": stats,
        "rarity": clampi(quality + (1 if String(trim.get("id", "")) != "none" else 0), 0, 5),
        "quality": quality,
        "ilvl": 1 + (quality * 3),
        "crafted": true,
    }

func _find(arr: Array, id: String) -> Dictionary:
    for x in arr:
        if x["id"] == id: return x
    return {}

func _roll_quality(skill_level: int) -> int:
    var weights := [40, 35, 18, 6, 1] if skill_level <= 1 else [12, 28, 32, 21, 7]
    var total: float = 0.0
    for w in weights: total += float(w)
    var pick: float = rng.randf() * total
    var acc: float = 0.0
    for i in range(weights.size()):
        acc += float(weights[i])
        if pick <= acc: return i
    return weights.size() - 1
