extends Node

# Arcane Atelier — scrolls / runes / enchantments / foci. 4th station.

const FORMS := [
    {"id":"scroll", "name":"Scroll", "kind":"buff_scroll", "tags":["scroll"]},
    {"id":"rune",   "name":"Rune",   "kind":"rune",        "tags":["rune","passive"]},
    {"id":"focus",  "name":"Focus",  "kind":"trinket",     "tags":["focus","passive"]},
]

const SIGILS := [
    {"id":"haste",        "name":"Sigil of Haste",      "buff_id":"haste"},
    {"id":"might",        "name":"Sigil of Might",      "buff_id":"blessing_might"},
    {"id":"warding",      "name":"Sigil of Warding",    "buff_id":"stoneskin"},
    {"id":"insight",      "name":"Sigil of Insight",    "buff_id":"bardic_inspiration"},
    {"id":"thornveil",    "name":"Sigil of Thornveil",  "buff_id":"thorns"},
]

const INKS := [
    {"id":"ash_ink",      "name":"Ash-ink",       "potency_mult": 1.0},
    {"id":"silver_ink",   "name":"Silver-ink",    "potency_mult": 1.3},
    {"id":"dragon_ink",   "name":"Dragon-ink",    "potency_mult": 1.7},
]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func craft(selections: Dictionary) -> Dictionary:
    var form: Dictionary = _find(FORMS, selections.get("form", ""))
    var sigil: Dictionary = _find(SIGILS, selections.get("sigil", ""))
    var ink: Dictionary = _find(INKS, selections.get("ink", "ash_ink"))
    if form.is_empty() or sigil.is_empty():
        return {}
    var quality: int = _roll_quality(int(selections.get("skill_level", 1)))
    var quality_mult: float = 1.0 + 0.10 * float(quality)
    var potency: float = float(ink.get("potency_mult", 1.0)) * quality_mult
    var name: String = "%s of %s" % [String(form["name"]), String(sigil["name"]).replace("Sigil of ", "")]
    return {
        "name": name,
        "kind": String(form["kind"]),
        "id": String(sigil["buff_id"]),
        "form": String(form["id"]),
        "sigil": String(sigil["id"]),
        "ink": String(ink["id"]),
        "tags": form.get("tags", []).duplicate(),
        "stats": {"potency": potency},
        "rarity": clampi(quality, 0, 4),
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
