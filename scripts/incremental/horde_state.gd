extends Node

# Horde Arena state.
#
# Holds all numbers-go-up state for the incremental pivot:
# kill counts, wave, gold/sec, class milestones. Designed to be
# autoloaded so any UI / scene can read or react via EventBus.
#
# Saving piggybacks on GameState (which save_system already persists).

signal milestone_reached(id: String, label: String)
signal class_unlocked(class_id: String)
signal slot_unlocked(slot: String)         # "secondary" | "tertiary"
signal wave_changed(wave: int)
signal kills_changed(total: int)

# --- Active class loadout for the run -----------------------------------
var primary: String = "warrior"
var secondary: String = ""
var tertiary: String = ""

# --- Live counters ------------------------------------------------------
var wave: int = 1
var kills_this_run: int = 0
var dps: float = 0.0          # smoothed
var gold_per_sec: float = 0.0 # idle gold yield (lifetime)

# --- Milestones ---------------------------------------------------------
# kills: cumulative across runs (uses GameState.lifetime_kills)
# A milestone fires once. Achieved IDs are persisted via GameState.meta_unlocks.
const KILL_UNLOCKS := [
    {"id":"unlock_rogue",       "kills": 100,   "class":"rogue",       "label":"Rogue path opens"},
    {"id":"unlock_wizard",      "kills": 500,   "class":"wizard",      "label":"Wizard path opens"},
    {"id":"unlock_necromancer", "kills": 1500,  "class":"necromancer", "label":"Necromancer path opens"},
    {"id":"unlock_bard",        "kills": 5000,  "class":"bard",        "label":"Bard path opens"},
]
const WAVE_UNLOCKS := [
    {"id":"unlock_dual",   "wave": 10, "slot":"secondary", "label":"Dual-class slot unlocked"},
    {"id":"unlock_triple", "wave": 25, "slot":"tertiary",  "label":"Triple-class slot unlocked"},
]

func _ready() -> void:
    # Make sure GameState starts with only warrior unlocked the first time
    # the player opens the new build. We respect anything already unlocked
    # (so existing saves keep their classes).
    if GameState.unlocked_classes.is_empty():
        GameState.unlocked_classes = ["warrior"] as Array[String]
    if "milestones" not in GameState.meta_unlocks:
        GameState.meta_unlocks["milestones"] = {}

func reset_run() -> void:
    wave = 1
    kills_this_run = 0
    dps = 0.0
    secondary = ""
    tertiary = ""
    primary = "warrior"
    wave_changed.emit(wave)
    kills_changed.emit(0)

func record_kill(monster_id: String = "skeleton", gold_value: int = 1) -> void:
    kills_this_run += 1
    GameState.lifetime_kills += 1
    GameState.tally_kill(monster_id)
    GameState.add_gold(gold_value)
    kills_changed.emit(kills_this_run)
    _check_kill_milestones()

func advance_wave() -> void:
    wave += 1
    if wave > GameState.deepest_floor:
        GameState.deepest_floor = wave
    wave_changed.emit(wave)
    _check_wave_milestones()

func can_pick_secondary() -> bool:
    return _milestone_done("unlock_dual")

func can_pick_tertiary() -> bool:
    return _milestone_done("unlock_triple")

func available_classes_for_extra_slot() -> Array[String]:
    var out: Array[String] = []
    for c in GameState.unlocked_classes:
        var s := String(c)
        if s == primary or s == secondary or s == tertiary:
            continue
        out.append(s)
    return out

func _check_kill_milestones() -> void:
    var total: int = GameState.lifetime_kills
    for m in KILL_UNLOCKS:
        var d: Dictionary = m
        var id: String = String(d["id"])
        if _milestone_done(id):
            continue
        if total >= int(d["kills"]):
            _mark_milestone(id)
            var cls: String = String(d["class"])
            if cls != "" and not GameState.unlocked_classes.has(cls):
                GameState.unlocked_classes.append(cls)
                class_unlocked.emit(cls)
            milestone_reached.emit(id, String(d["label"]))

func _check_wave_milestones() -> void:
    for m in WAVE_UNLOCKS:
        var d: Dictionary = m
        var id: String = String(d["id"])
        if _milestone_done(id):
            continue
        if wave >= int(d["wave"]):
            _mark_milestone(id)
            var slot: String = String(d.get("slot", ""))
            if slot != "":
                slot_unlocked.emit(slot)
            milestone_reached.emit(id, String(d["label"]))

func _milestone_done(id: String) -> bool:
    var ms: Dictionary = GameState.meta_unlocks.get("milestones", {})
    return bool(ms.get(id, false))

# Returns the next pending kill milestone, or {} if all are claimed.
func next_kill_milestone() -> Dictionary:
    for m in KILL_UNLOCKS:
        if not _milestone_done(String(m["id"])):
            return m
    return {}

# Returns the next pending wave milestone, or {} if all claimed.
func next_wave_milestone() -> Dictionary:
    for m in WAVE_UNLOCKS:
        if not _milestone_done(String(m["id"])):
            return m
    return {}

# Idle gold accrual rate exposed for the title screen offline-reward popup.
func idle_gold_per_sec() -> float:
    var base: float = 0.4 + GameState.deepest_floor * 0.15
    base += float(GameState.lifetime_kills) / 1000.0
    if secondary != "": base *= 1.4
    if tertiary != "": base *= 1.5
    base *= Upgrades.idle_multiplier()
    return base

func _mark_milestone(id: String) -> void:
    var ms: Dictionary = GameState.meta_unlocks.get("milestones", {})
    ms[id] = true
    GameState.meta_unlocks["milestones"] = ms
