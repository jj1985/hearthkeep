extends Node

# Lightweight perk pool for the horde arena. Each pick adds a flat or
# multiplicative bonus to the run's combat math. Perks are NOT persistent
# across runs (use Upgrades for that) — they're the megabonk-style
# escalation pillar that makes each run shape itself differently.
#
# Tags align with `Classes.combined_tags()` so future content can extend
# the pool with class-specific perks without touching this autoload.

signal perk_taken(perk: Dictionary)

const ALL_PERKS := [
    {"id":"hot_steel",   "label":"Hot Steel",     "desc":"+25%% melee damage.",    "tags":["warrior","melee"], "kind":"dmg_mult", "value":0.25},
    {"id":"glass_bones", "label":"Glass Bones",   "desc":"+50%% damage to one foe at a time (crit).", "tags":["rogue","crit"], "kind":"crit", "value":0.10},
    {"id":"arcane_arc",  "label":"Arcane Arc",    "desc":"+1 hero range bonus tier.","tags":["wizard","arcane"], "kind":"range", "value":80.0},
    {"id":"reaping",     "label":"Reaping",       "desc":"+50%% gold per kill.",   "tags":["necromancer","death"], "kind":"gold_mult", "value":0.5},
    {"id":"tempo",       "label":"Tempo",         "desc":"+0.5 atk/sec.",          "tags":["bard","support"], "kind":"atk_speed", "value":0.5},
    {"id":"ember_in",    "label":"Ember Within",  "desc":"+15%% damage globally.", "tags":["any"], "kind":"dmg_mult", "value":0.15},
    {"id":"hoarder",     "label":"Hoarder",       "desc":"+30%% wave-clear bonus.","tags":["any"], "kind":"wave_bonus_mult", "value":0.3},
    {"id":"fleet_foot",  "label":"Fleet Foot",    "desc":"Spawn cadence -10%%.",   "tags":["any"], "kind":"spawn_slow", "value":0.10},
    {"id":"bloodlust",   "label":"Bloodlust",     "desc":"+0.4 atk/sec.",       "tags":["warrior","melee"], "kind":"atk_speed", "value":0.4},
    {"id":"phantom",     "label":"Phantom",       "desc":"+10%% crit + +50 range.", "tags":["rogue","crit"], "kind":"crit_range", "value":0.10},
    {"id":"frostbite",   "label":"Frostbite",     "desc":"-15%% spawn cadence + +20%% damage.", "tags":["wizard","arcane"], "kind":"frostbite", "value":0.15},
    {"id":"chime",       "label":"Resonant Chime","desc":"+30%% wave-clear + +20%% gold drops.", "tags":["bard","support"], "kind":"chime", "value":0.20},
]

# Run-scoped accumulators. Reset by reset_for_run().
var dmg_mult: float = 1.0
var atk_speed_bonus: float = 0.0
var range_bonus: float = 0.0
var gold_mult: float = 1.0
var wave_bonus_mult: float = 1.0
var crit_bonus: float = 0.0
var spawn_slow: float = 0.0
var taken_ids: Array[String] = []

func reset_for_run() -> void:
    dmg_mult = 1.0
    atk_speed_bonus = 0.0
    range_bonus = 0.0
    gold_mult = 1.0
    wave_bonus_mult = 1.0
    crit_bonus = 0.0
    spawn_slow = 0.0
    taken_ids.clear()

# Roll three perks weighted toward the active class trio's tags.
func roll(rng: RandomNumberGenerator, count: int = 3) -> Array:
    var classes: Array[String] = []
    for c in [HordeState.primary, HordeState.secondary, HordeState.tertiary]:
        if c != "" and not classes.has(c): classes.append(c)
    var weighted: Array = []
    for p in ALL_PERKS:
        var d: Dictionary = p
        if taken_ids.has(String(d["id"])): continue
        var w: int = 1
        for t in d["tags"]:
            if t == "any": w = max(w, 2)
            elif classes.has(String(t)): w += 4
        for i in w: weighted.append(d)
    var picks: Array = []
    while picks.size() < count and weighted.size() > 0:
        var idx := rng.randi_range(0, weighted.size() - 1)
        var pick: Dictionary = weighted[idx]
        if not picks.has(pick): picks.append(pick)
        weighted = weighted.filter(func(x): return x != pick)
    return picks

func apply(perk: Dictionary) -> void:
    taken_ids.append(String(perk["id"]))
    var kind: String = String(perk["kind"])
    var v: float = float(perk["value"])
    match kind:
        "dmg_mult": dmg_mult *= 1.0 + v
        "atk_speed": atk_speed_bonus += v
        "range": range_bonus += v
        "gold_mult": gold_mult *= 1.0 + v
        "wave_bonus_mult": wave_bonus_mult *= 1.0 + v
        "crit": crit_bonus += v
        "spawn_slow": spawn_slow = clamp(spawn_slow + v, 0.0, 0.6)
        "crit_range":
            crit_bonus += v
            range_bonus += 50.0
        "frostbite":
            spawn_slow = clamp(spawn_slow + v, 0.0, 0.6)
            dmg_mult *= 1.20
        "chime":
            wave_bonus_mult *= 1.30
            gold_mult *= 1.20
    perk_taken.emit(perk)
