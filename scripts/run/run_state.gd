extends Node

# Per-run mutable state. Reset at run start. Megabonk-style escalation lives here.

signal level_up_pending(level)

var active: bool = false
var seed: int = 0
var floor_index: int = 0
var class_primary: String = "warrior"
var class_secondary: String = ""
var boss_dragon_id: String = ""
var talent_points: int = 0
var allocated_talents: Dictionary = {}    # node_id -> true
var run_time: float = 0.0
var player_level: int = 1
var xp: float = 0.0
var xp_to_next: float = 8.0
var xp_curve_factor: float = 1.30          # snowballing run cadence
var pending_level_ups: int = 0
var perks_taken: Array[String] = []
var weapon_evolutions: Array[String] = []
var damage_mult: float = 1.0
var atk_speed_mult: float = 1.0
var move_speed_mult: float = 1.0
var max_hp_mult: float = 1.0
var crit_chance_bonus: float = 0.0
var crit_damage_bonus: float = 0.0
var pickup_radius_mult: float = 1.0
var aoe_mult: float = 1.0
var lifesteal_pct: float = 0.0
var thorns_pct: float = 0.0
var fire_dot_chance: float = 0.0
var frost_slow_chance: float = 0.0
var lightning_chain_chance: float = 0.0
var elemental_tags: Array[String] = []      # for evolution prereqs
var run_kills: int = 0
var run_gold: int = 0
var run_legendaries: int = 0
var wager_multiplier: float = 1.0           # gambling den wager-the-run

func start_run(s: int) -> void:
    active = true
    seed = s
    floor_index = 0
    run_time = 0.0
    player_level = 1
    xp = 0.0
    xp_to_next = 8.0
    pending_level_ups = 0
    perks_taken.clear()
    weapon_evolutions.clear()
    damage_mult = 1.0
    atk_speed_mult = 1.0
    move_speed_mult = 1.0
    max_hp_mult = 1.0
    crit_chance_bonus = 0.0
    crit_damage_bonus = 0.0
    pickup_radius_mult = 1.0
    aoe_mult = 1.0
    lifesteal_pct = 0.0
    thorns_pct = 0.0
    fire_dot_chance = 0.0
    frost_slow_chance = 0.0
    lightning_chain_chance = 0.0
    elemental_tags.clear()
    run_kills = 0
    run_gold = 0
    run_legendaries = 0
    wager_multiplier = 1.0

func add_xp(amount: float) -> void:
    if not active:
        return
    xp += amount
    while xp >= xp_to_next:
        xp -= xp_to_next
        player_level += 1
        xp_to_next = xp_to_next * xp_curve_factor
        pending_level_ups += 1
        talent_points += 1
        EventBus.player_leveled_up.emit(player_level)
        level_up_pending.emit(player_level)

func register_perk(perk_id: String, tags: Array) -> void:
    perks_taken.append(perk_id)
    for t in tags:
        if not elemental_tags.has(t):
            elemental_tags.append(t)
    EventBus.perk_chosen.emit(perk_id)

func register_evolution(evo_id: String) -> void:
    weapon_evolutions.append(evo_id)
    EventBus.weapon_evolved.emit("base", evo_id)

func has_perk(id: String) -> bool:
    return perks_taken.has(id)

func has_tag(tag: String) -> bool:
    return elemental_tags.has(tag)

func enemy_scaling() -> float:
    # Smooth crescendo curve: at 0 floor -> 1.0, at floor 5 -> ~2.5
    return 1.0 + 0.30 * float(floor_index) + 0.05 * float(player_level)

func set_classes(primary: String, secondary: String) -> bool:
    if not Classes.CLASSES.has(primary):
        return false
    if secondary != "" and not Classes.CLASSES.has(secondary):
        return false
    if secondary == primary:
        secondary = ""
    class_primary = primary
    class_secondary = secondary
    return true

func hybrid_prestige() -> Dictionary:
    if class_secondary == "":
        return {}
    return Classes.hybrid_for(class_primary, class_secondary)
