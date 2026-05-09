extends Node

# Alchemy — second crafting station. Brews potions / elixirs / oils.
# Mirrors Forge architecture: data tables + craft(selections) entry point.
# Spec: docs/crafting_design.md.

# ---- Vessels (the form a brew takes) ------------------------------------

const VESSELS := [
    {"id":"flask",   "name":"Glass Flask",     "kind":"consumable", "tags":["potion"]},
    {"id":"vial",    "name":"Crystal Vial",    "kind":"consumable", "tags":["potion","throwable"]},
    {"id":"bottle",  "name":"Sealed Bottle",   "kind":"consumable", "tags":["elixir","duration"]},
    {"id":"oil_jar", "name":"Oil Jar",         "kind":"weapon_buff","tags":["oil"]},
    {"id":"phial",   "name":"Silvered Phial",  "kind":"buff_scroll","tags":["scroll","blessing"]},
]

# ---- Reagents (primary potency) -----------------------------------------

const REAGENTS := [
    {"id":"red_mossroot",  "name":"Red Mossroot",  "potency": 1.0, "school":"heal",     "flavor":"Coastreach moor herb."},
    {"id":"blue_lichen",   "name":"Blue Lichen",   "potency": 1.0, "school":"mana",     "flavor":"Graymarrow caves."},
    {"id":"sulfur_petal",  "name":"Sulfur Petal",  "potency": 1.4, "school":"fire",     "flavor":"Cinderwastes only."},
    {"id":"frostmint",     "name":"Frostmint",     "potency": 1.3, "school":"frost",    "flavor":"Aethyrnax's roost."},
    {"id":"drake_blood",   "name":"Drake Blood",   "potency": 1.7, "school":"power",    "flavor":"Costly. Breaks the rules."},
    {"id":"dragons_tear",  "name":"Dragon's Tear", "potency": 2.5, "school":"renewal",  "flavor":"Salt of a wyrm. Worth a kingdom."},
]

# ---- Catalysts (modifiers) ----------------------------------------------

const CATALYSTS := [
    {"id":"none",         "name":"Plain",            "duration_mult": 1.0, "potency_mult": 1.0},
    {"id":"silver_dust",  "name":"Silver Dust",      "duration_mult": 1.0, "potency_mult": 1.30},
    {"id":"gold_leaf",    "name":"Gold Leaf",        "duration_mult": 1.50, "potency_mult": 1.10, "tags":["lasting"]},
    {"id":"ember_pearl",  "name":"Ember Pearl",      "duration_mult": 1.0, "potency_mult": 1.50, "tags":["volatile"]},
    {"id":"void_salt",    "name":"Void Salt",        "duration_mult": 0.7, "potency_mult": 2.20, "tags":["risky"]},
]

# ---- Quality tiers (alchemy uses its own scale; plain → masterpiece) -----

const QUALITY_TIERS := ["Bitter", "Plain", "Pungent", "Aromatic", "Masterpiece"]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

# ---- Lookup helpers -----------------------------------------------------

func get_vessel(id: String) -> Dictionary:
    for v in VESSELS:
        if v["id"] == id: return v
    return {}

func get_reagent(id: String) -> Dictionary:
    for r in REAGENTS:
        if r["id"] == id: return r
    return {}

func get_catalyst(id: String) -> Dictionary:
    for c in CATALYSTS:
        if c["id"] == id: return c
    return {}

# ---- Craft entrypoint ---------------------------------------------------
#  selections shape:
#    { "vessel": "flask", "reagent": "red_mossroot", "catalyst": "silver_dust",
#      "label": "...", "skill_level": 1 }

func craft(selections: Dictionary) -> Dictionary:
    var vessel: Dictionary = get_vessel(selections.get("vessel", ""))
    var reagent: Dictionary = get_reagent(selections.get("reagent", ""))
    var catalyst: Dictionary = get_catalyst(selections.get("catalyst", "none"))
    if vessel.is_empty() or reagent.is_empty():
        return {}
    var quality: int = _roll_quality(int(selections.get("skill_level", 1)))
    var quality_mult: float = 1.0 + 0.10 * float(quality)
    var potency: float = float(reagent["potency"]) * float(catalyst.get("potency_mult", 1.0)) * quality_mult
    var duration: float = 12.0 * float(catalyst.get("duration_mult", 1.0)) * (1.0 + 0.05 * float(quality))
    var school: String = String(reagent["school"])
    var tags: Array = []
    for t in vessel.get("tags", []):
        if not tags.has(t): tags.append(t)
    tags.append(school)
    for t in catalyst.get("tags", []):
        if not tags.has(t): tags.append(t)
    var name_parts: Array = []
    if quality >= 4: name_parts.append("Masterpiece")
    elif quality >= 2: name_parts.append("Pungent")
    name_parts.append(String(reagent["name"]))
    name_parts.append(String(vessel["name"]))
    var name: String = " ".join(name_parts)
    var label: String = String(selections.get("label", ""))
    if label != "":
        name = "%s — \"%s\"" % [name, label]
    return {
        "name": name,
        "kind": String(vessel["kind"]),
        "vessel": String(vessel["id"]),
        "reagent": String(reagent["id"]),
        "catalyst": String(catalyst.get("id", "none")),
        "school": school,
        "tags": tags,
        "stats": {
            "potency": potency,
            "duration": duration,
        },
        "rarity": _rarity_for_quality(quality, reagent),
        "quality": quality,
        "quality_label": QUALITY_TIERS[quality],
        "ilvl": 1 + (quality * 3),
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

func _rarity_for_quality(quality: int, reagent: Dictionary) -> int:
    var base: int = clampi(quality, 0, 4)
    if String(reagent.get("school", "")) == "renewal":
        base = min(base + 2, 5)    # dragon's tear → bumps two tiers
    elif float(reagent.get("potency", 1.0)) >= 1.7:
        base = min(base + 1, 5)    # drake blood et al
    return base
