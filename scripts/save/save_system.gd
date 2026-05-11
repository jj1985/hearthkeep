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
        "run_wave": HordeState.wave,
        "run_perks": HordePerks.taken_ids,
        "run_primary": HordeState.primary,
        "run_secondary": HordeState.secondary,
        "run_tertiary": HordeState.tertiary,
        "rebirths": GameState.rebirths,
        "daily_curse": GameState.daily_curse,
        "challenge_active": GameState.challenge_active,
        "curses_cleared": GameState.curses_cleared,
        "challenge_claimed_today": GameState.challenge_claimed_today,
        "login_streak": GameState.login_streak,
        "last_login_day": GameState.last_login_day,
        "best_run_wave": GameState.best_run_wave,
        "best_run_kills": GameState.best_run_kills,
        "best_wave_by_class": GameState.best_wave_by_class,
        "run_history": GameState.run_history,
        "daily_quest": GameState.daily_quest,
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
    HordeState.wave = int(d.get("run_wave", 1))
    HordeState.primary = String(d.get("run_primary", "warrior"))
    HordeState.secondary = String(d.get("run_secondary", ""))
    HordeState.tertiary = String(d.get("run_tertiary", ""))
    GameState.rebirths = int(d.get("rebirths", 0))
    GameState.daily_curse = String(d.get("daily_curse", ""))
    GameState.challenge_active = bool(d.get("challenge_active", false))
    GameState.curses_cleared = int(d.get("curses_cleared", 0))
    GameState.challenge_claimed_today = bool(d.get("challenge_claimed_today", false))
    GameState.login_streak = int(d.get("login_streak", 0))
    GameState.last_login_day = int(d.get("last_login_day", 0))
    GameState.best_run_wave = int(d.get("best_run_wave", 0))
    GameState.best_run_kills = int(d.get("best_run_kills", 0))
    GameState.best_wave_by_class = d.get("best_wave_by_class", {})
    var rh: Array = d.get("run_history", [])
    GameState.run_history = rh if typeof(rh) == TYPE_ARRAY else []
    GameState.daily_quest = d.get("daily_quest", {})
    HordePerks.reset_for_run()
    var perks: Array = d.get("run_perks", [])
    for pid in perks:
        for p in HordePerks.ALL_PERKS:
            if String((p as Dictionary)["id"]) == String(pid):
                HordePerks.apply(p)
                break
    return true

# Returns the amount of seconds elapsed since last save, capped to 8h.
# Used to award offline idle gold without letting AFK weeks be a thing.
const OFFLINE_CAP_SECONDS := 28800   # 8 hours

func seconds_since_last_save() -> int:
    if GameState.last_save_unix <= 0: return 0
    var now: int = int(Time.get_unix_time_from_system())
    return clamp(now - GameState.last_save_unix, 0, OFFLINE_CAP_SECONDS)

# Returns the embers awarded if this session is a new login day, plus the
# new streak length. Resets streak to 1 if more than one day has passed.
func process_daily_login() -> Dictionary:
    var day: int = int(Time.get_unix_time_from_system() / 86400)
    if day == GameState.last_login_day:
        return {"ember": 0, "streak": GameState.login_streak}
    if GameState.last_login_day == 0 or day - GameState.last_login_day > 1:
        GameState.login_streak = 1
    else:
        GameState.login_streak += 1
    GameState.last_login_day = day
    var bonus: int = 1 + min(6, GameState.login_streak / 2)  # caps at 7 ember/day
    GameState.add_embers(bonus)
    var curses: Array = ["bare_hands", "glass_cannon", "spendthrift", "steady_pace", "no_strike"]
    var rng := RandomNumberGenerator.new()
    rng.seed = day
    GameState.daily_curse = String(curses[rng.randi_range(0, curses.size() - 1)])
    GameState.challenge_active = false  # require explicit opt-in each day
    GameState.challenge_claimed_today = false
    # Roll the daily kill quest. Picks one of the normal enemy types
    # (excluding bosses) and sets a small count + matched reward.
    var targets: Array = ["skeleton", "goblin", "skel_brute", "ghoul",
        "drake", "wraith", "ogre", "sapper", "shaman", "archer"]
    var t_id: String = String(targets[rng.randi_range(0, targets.size() - 1)])
    var count: int = 10 + rng.randi_range(0, 20)
    GameState.daily_quest = {
        "target_id": t_id,
        "target_count": count,
        "progress": 0,
        "reward_gold": 50 + count * 5,
        "reward_ember": 2 + count / 10,
        "claimed": false,
    }
    save()
    return {"ember": bonus, "streak": GameState.login_streak,
        "curse": GameState.daily_curse}

func _to_str_array(v: Variant) -> Array[String]:
    var out: Array[String] = []
    if typeof(v) == TYPE_ARRAY:
        for x in v:
            out.append(str(x))
    return out
