extends Node

# Persistent meta state outside an active run. Saved by save_system.

var gold: int = 0
var gems: int = 0
var dye_pots: Dictionary = {}                # color_id -> count
var unlocked_classes: Array[String] = ["warrior", "rogue", "wizard", "necromancer", "bard"]
var unlocked_dual_classes: Array[String] = []
var unlocked_dye_colors: Array[String] = ["red","blue","green","gray","white","black","gold","purple","teal","orange","crimson","ivory"]
var saved_dye_sets: Dictionary = {}          # set_name -> { slot -> color_id }
var stash: Array[Dictionary] = []
var meta_perk_points: int = 0
var defeated_dragons: Array[String] = []
var buildings: Dictionary = {                # building_id -> tier (0..3)
    "stash": 1,
    "forge": 1,
    "tavern": 1,
    "wizard_tower": 0,
    "shrine": 0,
    "gambling_den": 1,
    "dye_vendor": 1,
}
var meta_unlocks: Dictionary = {
    "triple_class": false,
    "weapon_evolutions": true,                # always on; prestige unlocks more recipes
}
var run_count: int = 0
var deepest_floor: int = 0
var lifetime_kills: int = 0
var lifetime_legendaries: int = 0
var krrik_defeated: bool = false

func add_gold(amount: int) -> void:
    gold = max(0, gold + amount)
    EventBus.currency_changed.emit("gold", amount, gold)

func add_gems(amount: int) -> void:
    gems = max(0, gems + amount)
    EventBus.currency_changed.emit("gems", amount, gems)

func add_dye(color_id: String, amount: int = 1) -> void:
    dye_pots[color_id] = dye_pots.get(color_id, 0) + amount

func consume_dye(color_id: String) -> bool:
    if dye_pots.get(color_id, 0) > 0:
        dye_pots[color_id] -= 1
        return true
    return false

func building_tier(id: String) -> int:
    return int(buildings.get(id, 0))

func upgrade_building(id: String) -> bool:
    var t := building_tier(id)
    if t >= 3:
        return false
    buildings[id] = t + 1
    return true
