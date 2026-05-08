extends Node

# Megabonk-style level-up perk-card pool.
# - Universal perks (drawn for any class)
# - Class perks (drawn only if player has tag)
# - Weapon evolution perks: appear as offers when prerequisites met
#
# RunState consumes the chosen perk and applies it; certain perk + weapon
# combinations register a "weapon evolution" event that swaps the player's
# main-hand to a named upgraded version with extra VFX.

const UNIVERSAL := [
    {"id":"u_dmg_1","name":"Sharper Edge","desc":"+12% damage.","tags":["dmg"],
     "apply":"damage_mult+0.12","weight":12,"max_stacks":5},
    {"id":"u_atkspd_1","name":"Quickened","desc":"+10% attack speed.","tags":["speed"],
     "apply":"atk_speed_mult+0.10","weight":10,"max_stacks":4},
    {"id":"u_hp_1","name":"Iron Heart","desc":"+15% max HP.","tags":["defense"],
     "apply":"max_hp_mult+0.15","weight":10,"max_stacks":4},
    {"id":"u_move_1","name":"Wind-Swift","desc":"+8% move speed.","tags":["mobility"],
     "apply":"move_speed_mult+0.08","weight":9,"max_stacks":3},
    {"id":"u_crit_1","name":"Eagle's Focus","desc":"+5% crit chance.","tags":["crit"],
     "apply":"crit_chance_bonus+0.05","weight":8,"max_stacks":4},
    {"id":"u_critdmg_1","name":"Savagery","desc":"+25% crit damage.","tags":["crit"],
     "apply":"crit_damage_bonus+0.25","weight":7,"max_stacks":4},
    {"id":"u_aoe_1","name":"Wider Wake","desc":"+15% area of effect.","tags":["aoe"],
     "apply":"aoe_mult+0.15","weight":7,"max_stacks":4},
    {"id":"u_pickup_1","name":"Magnetic Soul","desc":"+40% pickup radius.","tags":["qol"],
     "apply":"pickup_radius_mult+0.40","weight":6,"max_stacks":3},
    {"id":"u_lifesteal_1","name":"Crimson Drinker","desc":"+3% lifesteal.","tags":["sustain"],
     "apply":"lifesteal_pct+0.03","weight":5,"max_stacks":4},
    {"id":"u_thorns_1","name":"Thorns","desc":"+8% reflected damage.","tags":["defense"],
     "apply":"thorns_pct+0.08","weight":5,"max_stacks":3},
    # Elemental seeds — these add tags that unlock evolutions
    {"id":"u_fire_1","name":"Inferno Aura","desc":"15% on-hit fire DoT.","tags":["fire","element"],
     "apply":"fire_dot_chance+0.15","weight":7,"max_stacks":3},
    {"id":"u_frost_1","name":"Frostbite","desc":"15% on-hit frost slow.","tags":["frost","element"],
     "apply":"frost_slow_chance+0.15","weight":7,"max_stacks":3},
    {"id":"u_storm_1","name":"Stormcaller","desc":"15% on-hit lightning chain.","tags":["lightning","element"],
     "apply":"lightning_chain_chance+0.15","weight":7,"max_stacks":3},
]

const CLASS_PERKS := {
    "warrior": [
        {"id":"w_p1","name":"Whirlwind: Maelstrom","desc":"Whirlwind ticks twice.","tags":["whirlwind"],"apply":"flag:whirlwind_tempest","weight":4,"max_stacks":1},
        {"id":"w_p2","name":"Cleaver","desc":"+25% cleave damage.","tags":["cleave"],"apply":"damage_mult+0.10","weight":6,"max_stacks":3},
    ],
    "rogue": [
        {"id":"r_p1","name":"Daggerstorm","desc":"+30% atk speed for daggers.","tags":["dagger"],"apply":"atk_speed_mult+0.15","weight":6,"max_stacks":2},
        {"id":"r_p2","name":"Coup de Grace","desc":"+50% crit damage on bleeding targets.","tags":["crit","bleed"],"apply":"crit_damage_bonus+0.30","weight":5,"max_stacks":2},
    ],
    "wizard": [
        {"id":"m_p1","name":"Arcane Surge","desc":"+20% spell damage.","tags":["spell"],"apply":"damage_mult+0.20","weight":6,"max_stacks":3},
        {"id":"m_p2","name":"Conflagration","desc":"Fire spells leave burning ground.","tags":["fire"],"apply":"flag:conflagration","weight":4,"max_stacks":1},
    ],
    "necromancer": [
        {"id":"n_p1","name":"Boneharvest","desc":"+1 skeleton on summon.","tags":["summon"],"apply":"flag:boneharvest","weight":4,"max_stacks":2},
        {"id":"n_p2","name":"Plague Doctor","desc":"+25% poison DoT.","tags":["poison"],"apply":"damage_mult+0.10","weight":5,"max_stacks":2},
    ],
    "bard": [
        {"id":"b_p1","name":"Crescendo Climax","desc":"Crescendo's final note: 2.5x.","tags":["song"],"apply":"flag:crescendo_climax","weight":4,"max_stacks":1},
    ],
    "paladin": [
        {"id":"p_p1","name":"Judgement","desc":"Smite chains to 2 nearby enemies.","tags":["smite"],"apply":"flag:judgement","weight":4,"max_stacks":1},
    ],
    "ranger": [
        {"id":"x_p1","name":"Volley Storm","desc":"Volley ricochets on crit.","tags":["volley"],"apply":"flag:volley_storm","weight":4,"max_stacks":1},
    ],
}

# Weapon evolutions: when conditions met, OFFER an evolution card.
# requires: weapon_tag (must have weapon w/ tag), perk_id (must have perk).
const WEAPON_EVOLUTIONS := [
    {"id":"sunfire_reaver","name":"Sunfire Reaver","desc":"Flaming Sword + Inferno Aura: emits a constant fire ring.",
     "weapon_tag":"sword","perk_id":"u_fire_1","fx":"fire_ring","weight":40},
    {"id":"glaciate","name":"Glaciate","desc":"Frostbound Mace + Frostbite: freezes on every 5th hit.",
     "weapon_tag":"mace","perk_id":"u_frost_1","fx":"glacial_burst","weight":40},
    {"id":"thunderfang","name":"Thunderfang","desc":"Thundering Dagger + Stormcaller: arcs on crit.",
     "weapon_tag":"dagger","perk_id":"u_storm_1","fx":"arc_discharge","weight":40},
    {"id":"draconic_pierce","name":"Draconic Pierce","desc":"Bow + Inferno Aura: arrows pierce and ignite.",
     "weapon_tag":"bow","perk_id":"u_fire_1","fx":"flame_arrow_trail","weight":40},
    {"id":"oblivion_orb","name":"Oblivion Orb","desc":"Staff + Stormcaller: orbiting arc orbs follow you.",
     "weapon_tag":"staff","perk_id":"u_storm_1","fx":"orbit_orbs","weight":40},
]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func draw_offer(class_primary: String, class_secondary: String, count: int = 4, equipped_weapon_tags: Array = []) -> Array:
    var pool: Array = []
    pool.append_array(UNIVERSAL)
    if CLASS_PERKS.has(class_primary):
        pool.append_array(CLASS_PERKS[class_primary])
    if class_secondary != "" and CLASS_PERKS.has(class_secondary):
        pool.append_array(CLASS_PERKS[class_secondary])

    # Filter perks at max stacks already
    var perk_count := {}
    for id in RunState.perks_taken:
        perk_count[id] = perk_count.get(id, 0) + 1
    pool = pool.filter(func(p):
        var stacks: int = perk_count.get(p["id"], 0)
        return stacks < int(p.get("max_stacks", 99)))

    # Inject weapon evolutions when prerequisites met (and not yet evolved)
    for ev in WEAPON_EVOLUTIONS:
        if RunState.weapon_evolutions.has(ev["id"]):
            continue
        if not equipped_weapon_tags.has(ev["weapon_tag"]):
            continue
        if not RunState.has_perk(ev["perk_id"]):
            continue
        var entry: Dictionary = (ev as Dictionary).duplicate(true)
        entry["evolution"] = true
        pool.append(entry)

    # Weighted draw
    var offers: Array = []
    var pool_copy := pool.duplicate()
    for i in range(count):
        if pool_copy.is_empty():
            break
        var total := 0
        for p in pool_copy:
            total += int(p.get("weight", 1))
        var r := rng.randi_range(0, max(0, total - 1))
        var acc := 0
        for j in range(pool_copy.size()):
            acc += int(pool_copy[j].get("weight", 1))
            if r < acc:
                offers.append(pool_copy[j])
                pool_copy.remove_at(j)
                break
    return offers

# Apply an "apply" string to RunState. Format: "field+value" or "flag:name".
func apply_perk(perk: Dictionary) -> void:
    var apply: String = perk.get("apply", "")
    if perk.get("evolution", false):
        RunState.register_evolution(perk["id"])
        EventBus.weapon_evolved.emit(perk.get("weapon_tag",""), perk["id"])
        return
    if apply.begins_with("flag:"):
        var flag: String = apply.substr(5)
        RunState.register_perk(perk["id"], perk.get("tags", []))
        # Caller can read flags via has_perk + tags; flag:* perks rely on perks_taken contains.
        return
    var plus: int = apply.find("+")
    if plus < 0:
        RunState.register_perk(perk["id"], perk.get("tags", []))
        return
    var field: String = apply.substr(0, plus)
    var value: float = float(apply.substr(plus + 1))
    if field in RunState:
        RunState.set(field, RunState.get(field) + value)
    RunState.register_perk(perk["id"], perk.get("tags", []))
