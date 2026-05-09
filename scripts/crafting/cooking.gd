extends Node

# Cooking Hearth — food + feast items. 6th station.

const DISHES := [
    {"id":"hot_stew",   "name":"Hot Stew",       "duration": 600, "buff_id":"haste",         "tier":1},
    {"id":"hearth_pie", "name":"Hearth Pie",     "duration": 600, "buff_id":"blessing_might","tier":1},
    {"id":"venison_roast","name":"Venison Roast","duration":1200, "buff_id":"stoneskin",     "tier":2},
    {"id":"feast",      "name":"Wayfarer's Feast","duration":1800,"buff_id":"bardic_inspiration","tier":3},
]

const STAPLES := [
    {"id":"bread",       "name":"Bread",       "potency_mult":1.0},
    {"id":"hearth_bread","name":"Hearth Bread","potency_mult":1.2},
    {"id":"trail_oats",  "name":"Trail Oats",  "potency_mult":1.1},
]

const SPICES := [
    {"id":"salt",       "name":"Salt",          "potency_mult":1.0},
    {"id":"firepepper", "name":"Firepepper",    "potency_mult":1.3, "tags":["fire"]},
    {"id":"frostmint",  "name":"Frostmint",     "potency_mult":1.2, "tags":["frost"]},
    {"id":"saffron",    "name":"Saffron",       "potency_mult":1.5, "tags":["rare"]},
]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func craft(selections: Dictionary) -> Dictionary:
    var dish: Dictionary = _find(DISHES, selections.get("dish", ""))
    var staple: Dictionary = _find(STAPLES, selections.get("staple", ""))
    var spice: Dictionary = _find(SPICES, selections.get("spice", "salt"))
    if dish.is_empty() or staple.is_empty():
        return {}
    var quality: int = _roll_quality(int(selections.get("skill_level", 1)))
    var quality_mult: float = 1.0 + 0.10 * float(quality)
    var potency: float = float(staple.get("potency_mult", 1.0)) * float(spice.get("potency_mult", 1.0)) * quality_mult
    var duration: float = float(dish["duration"]) * quality_mult
    var name: String = "%s with %s" % [String(dish["name"]), String(spice["name"])]
    var tags: Array = ["food", "consumable"]
    for t in spice.get("tags", []): tags.append(t)
    return {
        "name": name,
        "kind": "consumable",
        "id": String(dish["buff_id"]),
        "dish": String(dish["id"]),
        "staple": String(staple["id"]),
        "spice": String(spice["id"]),
        "tags": tags,
        "stats": {"potency": potency, "duration": duration},
        "rarity": clampi(int(dish.get("tier", 1)) + (quality / 2), 0, 5),
        "quality": quality,
        "ilvl": 1 + (quality * 2),
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
