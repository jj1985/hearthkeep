extends Node

# Persistent meta state outside an active run. Saved by save_system.

var gold: int = 0
var gems: int = 0
var dye_pots: Dictionary = {}                # color_id -> count
var unlocked_classes: Array[String] = ["warrior"]
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
var lifetime_kills_by_type: Dictionary = {}    # monster_id -> count
var embers: int = 0                              # prestige currency from boss kills
var bosses_felled: int = 0
var last_save_unix: int = 0                      # used to award offline idle gold
var rebirths: int = 0                            # permanent prestige stack
var daily_curse: String = ""                     # picked on each new login day
var challenge_active: bool = false               # opt-in run modifier
var login_streak: int = 0
var last_login_day: int = 0                      # unix-day of last daily reward
var best_run_wave: int = 0
var best_run_kills: int = 0

func tally_kill(monster_id: String) -> void:
    lifetime_kills_by_type[monster_id] = int(lifetime_kills_by_type.get(monster_id, 0)) + 1

func _ready() -> void:
    EventBus.entity_killed.connect(_on_entity_killed)

func _on_entity_killed(entity, _killer) -> void:
    var id_hint: String = "unknown"
    if entity != null and entity.has_method("monster_id"):
        id_hint = String((entity as Object).call("monster_id"))
    tally_kill(id_hint)

func add_gold(amount: int) -> void:
    gold = max(0, gold + amount)
    EventBus.currency_changed.emit("gold", amount, gold)

func add_gems(amount: int) -> void:
    gems = max(0, gems + amount)
    EventBus.currency_changed.emit("gems", amount, gems)

func add_embers(amount: int) -> void:
    embers = max(0, embers + amount)
    EventBus.currency_changed.emit("embers", amount, embers)

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
