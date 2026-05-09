extends Node

# Owns the player's collection of trophies, which slots they're placed in,
# which buffs are active, and the active-buff cap.

const TrophyDB := preload("res://scripts/hall/trophy_db.gd")

var collected: Dictionary = {}                 # trophy_id -> count (>=1 owned)
var placed: Dictionary = {}                    # slot_id -> trophy_id
var active_buff_ids: Array[String] = []        # selected for active bonus
var active_cap: int = 4                        # tier 1 hall
var target_slot_id: String = ""                # set by villa pedestal interact, read by trophy_picker

signal trophies_changed
signal active_buffs_changed

func _ready() -> void:
    EventBus.boss_defeated.connect(_on_boss_defeated)

const BOSS_TROPHY := {
    "vyxhasis": "vyxhasis_horn",
    "ourzhal":  "ourzhal_scale",
    "aethyrnax": "aethyrnax_fang",
}

func _on_boss_defeated(boss_id: String) -> void:
    var first_kill: bool = not GameState.defeated_dragons.has(boss_id)
    if first_kill:
        GameState.defeated_dragons.append(boss_id)
    var trophy_id: String = String(BOSS_TROPHY.get(boss_id, "%s_horn" % boss_id))
    if TrophyDB.find(trophy_id).is_empty():
        return
    if first_kill or int(collected.get(trophy_id, 0)) == 0:
        award(trophy_id)

func award(trophy_id: String) -> bool:
    var def := TrophyDB.find(trophy_id)
    if def.is_empty():
        return false
    collected[trophy_id] = int(collected.get(trophy_id, 0)) + 1
    EventBus.floating_text.emit("TROPHY: " + str(def["name"]), Vector2.ZERO, Color(1, 0.7, 1))
    trophies_changed.emit()
    return true

func place(slot_id: String, trophy_id: String) -> bool:
    var def := TrophyDB.find(trophy_id)
    if def.is_empty():
        return false
    if int(collected.get(trophy_id, 0)) <= 0:
        return false
    placed[slot_id] = trophy_id
    trophies_changed.emit()
    return true

func unplace(slot_id: String) -> void:
    placed.erase(slot_id)
    trophies_changed.emit()

func placed_trophy_ids() -> Array:
    var out: Array = []
    for slot in placed.keys():
        var tid: String = placed[slot]
        if not out.has(tid):
            out.append(tid)
    return out

func set_active_cap(cap: int) -> void:
    active_cap = cap
    while active_buff_ids.size() > active_cap:
        active_buff_ids.pop_back()
    active_buffs_changed.emit()

func set_active(trophy_id: String, active: bool) -> bool:
    if active:
        if active_buff_ids.size() >= active_cap:
            return false
        if not active_buff_ids.has(trophy_id):
            active_buff_ids.append(trophy_id)
    else:
        active_buff_ids.erase(trophy_id)
    active_buffs_changed.emit()
    return true

func aggregate_buffs() -> Dictionary:
    var out: Dictionary = {}
    for tid in active_buff_ids:
        var def := TrophyDB.find(tid)
        if def.is_empty(): continue
        for k in (def.get("buff", {}) as Dictionary).keys():
            out[k] = float(out.get(k, 0)) + float((def["buff"] as Dictionary)[k])
    for set_id in TrophyDB.SETS.keys():
        var members: Array = TrophyDB.members_of(set_id)
        var all_placed: bool = true
        for m in members:
            if not placed_trophy_ids().has(m):
                all_placed = false
                break
        if all_placed:
            for k in ((TrophyDB.SETS[set_id])["set_buff"] as Dictionary).keys():
                out[k] = float(out.get(k, 0)) + float(((TrophyDB.SETS[set_id])["set_buff"] as Dictionary)[k])
    return out

func set_progress() -> Array:
    var out: Array = []
    for set_id in TrophyDB.SETS.keys():
        var members: Array = TrophyDB.members_of(set_id)
        var have: int = 0
        for m in members:
            if int(collected.get(m, 0)) > 0:
                have += 1
        out.append({
            "set_id": set_id,
            "name": TrophyDB.SETS[set_id]["name"],
            "have": have,
            "needed": members.size(),
            "complete": have == members.size(),
            "buff_label": TrophyDB.SETS[set_id]["set_buff_label"],
        })
    return out

func reset() -> void:
    collected.clear()
    placed.clear()
    active_buff_ids.clear()
