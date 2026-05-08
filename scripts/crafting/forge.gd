extends Node

# Forge — Phase A data layer + craft() entrypoint.
# Spec: docs/crafting_design.md Phase A.
# Phase A scope (this file): forms, primary materials, secondary materials,
# embellishments, the multi-step session API + quality roll. The full wizard
# UI is layered on top in scenes/crafting/forge_ui.tscn.

# ---- Forms (weapon shapes) ------------------------------------------------

const FORMS := [
    {"id": "sword",    "name": "Sword",    "slot": "main_hand",
     "base_dmg": [8, 14], "speed": 1.00, "tags": ["physical", "slash"]},
    {"id": "axe",      "name": "Axe",      "slot": "main_hand",
     "base_dmg": [10, 18], "speed": 0.85, "tags": ["physical", "cleave", "bleed"]},
    {"id": "mace",     "name": "Mace",     "slot": "main_hand",
     "base_dmg": [9, 15], "speed": 0.90, "tags": ["physical", "blunt"]},
    {"id": "dagger",   "name": "Dagger",   "slot": "main_hand",
     "base_dmg": [5, 9],  "speed": 1.40, "tags": ["physical", "stealth", "crit"]},
    {"id": "polearm",  "name": "Polearm",  "slot": "main_hand",
     "base_dmg": [11, 17], "speed": 0.80, "tags": ["physical", "reach"]},
]

# ---- Primary materials (blade/head) ---------------------------------------

const PRIMARY_MATS := [
    {"id": "iron",       "name": "Iron",          "dmg_mult": 1.00, "durability": 60,  "tags": []},
    {"id": "steel",      "name": "Steel",         "dmg_mult": 1.20, "durability": 80,  "tags": []},
    {"id": "silvered",   "name": "Silvered Steel","dmg_mult": 1.15, "durability": 75,
     "tags": ["holy"], "flavor": "Bites the unliving."},
    {"id": "mithril",    "name": "Mithril",       "dmg_mult": 1.45, "durability": 95,
     "tags": ["light", "crit"], "flavor": "Light. Hungry. Sings the strike."},
    {"id": "adamant",    "name": "Adamant",       "dmg_mult": 1.55, "durability": 130, "tags": ["heavy"]},
    {"id": "dragonbone", "name": "Dragonbone",    "dmg_mult": 1.65, "durability": 110,
     "tags": ["fire", "rare"], "flavor": "Still warm to the touch."},
]

# ---- Secondary materials (grip/handle) ------------------------------------

const SECONDARY_MATS := [
    {"id": "oak",      "name": "Oak Grip",       "speed_mult": 1.00, "tags": []},
    {"id": "ironwood", "name": "Ironwood Grip",  "speed_mult": 0.95, "tags": ["heavy"]},
    {"id": "leather",  "name": "Leather-Wrapped","speed_mult": 1.05, "tags": []},
    {"id": "silk",     "name": "Silk-Wrapped",   "speed_mult": 1.12, "tags": ["finesse"]},
    {"id": "drake_hide","name": "Drake-hide",    "speed_mult": 1.08, "tags": ["fire_res"]},
]

# ---- Embellishments (gem inlay / glyph etch) ------------------------------

const EMBELLISHMENTS := [
    {"id": "none",       "name": "Plain",          "affixes": []},
    {"id": "fire_gem",   "name": "Ember Gem",      "affixes": [{"id": "fire_dmg", "min": 4, "max": 9}]},
    {"id": "frost_gem",  "name": "Frost Gem",      "affixes": [{"id": "frost_slow_chance", "min": 0.05, "max": 0.12}]},
    {"id": "blood_glyph","name": "Blood Glyph",    "affixes": [{"id": "lifesteal_pct", "min": 0.02, "max": 0.06}]},
    {"id": "rune_str",   "name": "Rune of Bear",   "affixes": [{"id": "str", "min": 2, "max": 5}]},
]

# ---- Quality tiers --------------------------------------------------------

const QUALITY_TIERS := ["Crude", "Worn", "Fine", "Exquisite", "Masterwork"]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

# ---- Lookup helpers (used by the wizard UI) -------------------------------

func get_form(id: String) -> Dictionary:
    for f in FORMS:
        if f["id"] == id: return f
    return {}

func get_primary_material(id: String) -> Dictionary:
    for m in PRIMARY_MATS:
        if m["id"] == id: return m
    return {}

func get_secondary_material(id: String) -> Dictionary:
    for m in SECONDARY_MATS:
        if m["id"] == id: return m
    return {}

func get_embellishment(id: String) -> Dictionary:
    for e in EMBELLISHMENTS:
        if e["id"] == id: return e
    return {}

# ---- Craft entry-point ----------------------------------------------------
# Selections shape (any field optional):
#   { "form": "sword", "primary": "steel", "secondary": "leather",
#     "embellishment": "fire_gem", "engraving": "Mhera's Promise",
#     "dye": {...}, "skill_level": 1 }

func craft(selections: Dictionary) -> Dictionary:
    var form: Dictionary = get_form(selections.get("form", ""))
    var primary: Dictionary = get_primary_material(selections.get("primary", ""))
    var secondary: Dictionary = get_secondary_material(selections.get("secondary", ""))
    var embell: Dictionary = get_embellishment(selections.get("embellishment", "none"))
    if form.is_empty() or primary.is_empty():
        return {}    # form + primary material are required for a valid craft
    var dmg_min: int = int(form["base_dmg"][0] * float(primary["dmg_mult"]))
    var dmg_max: int = int(form["base_dmg"][1] * float(primary["dmg_mult"]))
    var speed_mult: float = float(secondary.get("speed_mult", 1.0))
    var quality: int = _roll_quality(int(selections.get("skill_level", 1)))
    var quality_dmg_bonus: float = 1.0 + 0.05 * float(quality)
    dmg_min = int(dmg_min * quality_dmg_bonus)
    dmg_max = int(dmg_max * quality_dmg_bonus)
    var tags: Array = []
    for t in form.get("tags", []):
        if not tags.has(t): tags.append(t)
    for t in primary.get("tags", []):
        if not tags.has(t): tags.append(t)
    for t in secondary.get("tags", []):
        if not tags.has(t): tags.append(t)
    var name_parts: Array = []
    if quality >= 4: name_parts.append("Masterwork")
    elif quality >= 2: name_parts.append("Fine")
    name_parts.append(String(primary["name"]))
    name_parts.append(String(form["name"]))
    var name: String = " ".join(name_parts)
    var engraving: String = selections.get("engraving", "")
    if engraving != "":
        name = "%s — \"%s\"" % [name, engraving]
    var item: Dictionary = {
        "name": name,
        "slot": String(form["slot"]),
        "form": String(form["id"]),
        "primary_material": String(primary["id"]),
        "secondary_material": String(secondary.get("id", "oak")),
        "embellishment": String(embell.get("id", "none")),
        "engraving": engraving,
        "tags": tags,
        "stats": {
            "dmg_min": dmg_min,
            "dmg_max": dmg_max,
            "atk_speed_mult": speed_mult,
        },
        "rarity": _rarity_for_quality(quality, embell),
        "quality": quality,
        "quality_label": QUALITY_TIERS[quality],
        "ilvl": 1 + (quality * 4),
        "crafted": true,
    }
    # Apply embellishment affixes
    for affix in embell.get("affixes", []):
        var v: float = rng.randf_range(float(affix["min"]), float(affix["max"]))
        item["stats"][String(affix["id"])] = v
    return item

# ---- Quality roll ----------------------------------------------------------

func _roll_quality(skill_level: int) -> int:
    # Skill-driven distribution: low skill weights toward Crude/Worn, high
    # skill toward Exquisite/Masterwork. Sums to 100 each row.
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

func _rarity_for_quality(quality: int, embell: Dictionary) -> int:
    # 0 Common .. 5 Mythic; embellished items climb a tier.
    var base: int = clampi(quality, 0, 4)
    if embell.get("id", "none") != "none":
        base = min(base + 1, 5)
    return base
