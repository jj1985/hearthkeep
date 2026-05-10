extends Node

const SAVE_PATH := "user://norrath_save.json"

func save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        return
    var payload := {
        "version": 1,
        "gold": GameState.gold,
        "gems": GameState.gems,
        "dye_pots": GameState.dye_pots,
        "unlocked_classes": GameState.unlocked_classes,
        "unlocked_dual_classes": GameState.unlocked_dual_classes,
        "unlocked_dye_colors": GameState.unlocked_dye_colors,
        "saved_dye_sets": GameState.saved_dye_sets,
        "stash": GameState.stash,
        "meta_perk_points": GameState.meta_perk_points,
        "defeated_dragons": GameState.defeated_dragons,
        "buildings": GameState.buildings,
        "meta_unlocks": GameState.meta_unlocks,
        "run_count": GameState.run_count,
        "deepest_floor": GameState.deepest_floor,
        "lifetime_kills": GameState.lifetime_kills,
        "lifetime_legendaries": GameState.lifetime_legendaries,
        "krrik_defeated": GameState.krrik_defeated,
        "lifetime_kills_by_type": GameState.lifetime_kills_by_type,
        "embers": GameState.embers,
        "bosses_felled": GameState.bosses_felled,
        "last_save_unix": int(Time.get_unix_time_from_system()),
    }
    GameState.last_save_unix = int(payload["last_save_unix"])
    f.store_string(JSON.stringify(payload))

func load_save() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return false
    var raw := f.get_as_text()
    var data: Variant = JSON.parse_string(raw)
    if typeof(data) != TYPE_DICTIONARY:
        return false
    var d: Dictionary = data
    GameState.gold = int(d.get("gold", 0))
    GameState.gems = int(d.get("gems", 0))
    GameState.dye_pots = d.get("dye_pots", {})
    GameState.unlocked_classes = _to_str_array(d.get("unlocked_classes", GameState.unlocked_classes))
    GameState.unlocked_dual_classes = _to_str_array(d.get("unlocked_dual_classes", []))
    GameState.unlocked_dye_colors = _to_str_array(d.get("unlocked_dye_colors", GameState.unlocked_dye_colors))
    GameState.saved_dye_sets = d.get("saved_dye_sets", {})
    var raw_stash: Array = d.get("stash", [])
    GameState.stash.clear()
    for it in raw_stash:
        if typeof(it) == TYPE_DICTIONARY:
            GameState.stash.append(it)
    GameState.meta_perk_points = int(d.get("meta_perk_points", 0))
    GameState.defeated_dragons = _to_str_array(d.get("defeated_dragons", []))
    GameState.buildings = d.get("buildings", GameState.buildings)
    GameState.meta_unlocks = d.get("meta_unlocks", GameState.meta_unlocks)
    GameState.run_count = int(d.get("run_count", 0))
    GameState.deepest_floor = int(d.get("deepest_floor", 0))
    GameState.lifetime_kills = int(d.get("lifetime_kills", 0))
    GameState.lifetime_legendaries = int(d.get("lifetime_legendaries", 0))
    GameState.krrik_defeated = bool(d.get("krrik_defeated", false))
    GameState.lifetime_kills_by_type = d.get("lifetime_kills_by_type", {})
    GameState.embers = int(d.get("embers", 0))
    GameState.bosses_felled = int(d.get("bosses_felled", 0))
    GameState.last_save_unix = int(d.get("last_save_unix", 0))
    return true

# Returns the amount of seconds elapsed since last save, capped to 8h.
# Used to award offline idle gold without letting AFK weeks be a thing.
const OFFLINE_CAP_SECONDS := 28800   # 8 hours

func seconds_since_last_save() -> int:
    if GameState.last_save_unix <= 0: return 0
    var now: int = int(Time.get_unix_time_from_system())
    return clamp(now - GameState.last_save_unix, 0, OFFLINE_CAP_SECONDS)

func _to_str_array(v: Variant) -> Array[String]:
    var out: Array[String] = []
    if typeof(v) == TYPE_ARRAY:
        for x in v:
            out.append(str(x))
    return out
