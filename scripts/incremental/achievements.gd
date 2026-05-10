extends Node

# Read-only achievements registry. Each entry is a {label, progress() -> [cur, target]}
# pair so the upgrade-screen panel can render them uniformly. Values pull
# from GameState live, so there's no separate persistence layer.
#
# Keeping this in its own file (not autoloaded) so test cost stays low —
# upgrade_screen.gd can preload it directly.

const ROWS := [
    {"id":"unlock_rogue",     "label":"Unlock Rogue (100 kills)"},
    {"id":"unlock_wizard",    "label":"Unlock Wizard (500 kills)"},
    {"id":"unlock_necro",     "label":"Unlock Necromancer (1500 kills)"},
    {"id":"unlock_bard",      "label":"Unlock Bard (5000 kills)"},
    {"id":"slot_dual",        "label":"Dual-class slot (wave 10)"},
    {"id":"slot_triple",      "label":"Triple-class slot (wave 25)"},
    {"id":"endless",          "label":"Reach wave 50"},
    {"id":"first_boss",       "label":"Fell your first boss"},
    {"id":"five_bosses",      "label":"Fell 5 bosses"},
    {"id":"curse_first",      "label":"Clear a curse"},
    {"id":"first_rebirth",    "label":"First Mark of Rebirth"},
    {"id":"streak_seven",     "label":"7-day login streak"},
]

static func progress(id: String) -> Array:
    # returns [current, target] suitable for "n / m" display.
    match id:
        "unlock_rogue":  return [min(100, GameState.lifetime_kills), 100]
        "unlock_wizard": return [min(500, GameState.lifetime_kills), 500]
        "unlock_necro":  return [min(1500, GameState.lifetime_kills), 1500]
        "unlock_bard":   return [min(5000, GameState.lifetime_kills), 5000]
        "slot_dual":     return [min(10, GameState.deepest_floor), 10]
        "slot_triple":   return [min(25, GameState.deepest_floor), 25]
        "endless":       return [min(50, GameState.deepest_floor), 50]
        "first_boss":    return [min(1, GameState.bosses_felled), 1]
        "five_bosses":   return [min(5, GameState.bosses_felled), 5]
        "curse_first":   return [min(1, GameState.curses_cleared), 1]
        "first_rebirth": return [min(1, GameState.rebirths), 1]
        "streak_seven":  return [min(7, GameState.login_streak), 7]
    return [0, 1]

static func is_done(id: String) -> bool:
    var p := progress(id)
    return int(p[0]) >= int(p[1])
