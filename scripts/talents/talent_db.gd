extends Node

# Per-class talent grids. Each tree is a list of nodes with prereq edges.
# Keystones (k=true) materially change a skill's behavior.

const TREES := {
    "warrior_tree": {
        "nodes":[
            {"id":"w1","name":"Iron Grip","stat":{"str":2}},
            {"id":"w2","name":"Hardened","stat":{"max_hp":15}},
            {"id":"w3","name":"Cleaving Blow","stat":{"cleave_arc":15}},
            {"id":"w4","name":"Bulwark","stat":{"armor":6}},
            {"id":"w5","name":"Bloodthirst","stat":{"lifesteal":0.03}},
            {"id":"w_key1","name":"Whirlwind: Tempest","k":true,"effect":"Whirlwind ticks twice and lifesteals."},
            {"id":"w_key2","name":"Execute: Ender","k":true,"effect":"Execute below 35% HP one-shots non-elites."},
            {"id":"w6","name":"Stalwart","stat":{"sta":3}},
            {"id":"w7","name":"Stagger","stat":{"stun_chance":0.05}},
            {"id":"w8","name":"Earthshatter","stat":{"aoe":0.10}},
        ],
        "edges":[["w1","w2"],["w2","w3"],["w3","w_key1"],["w2","w4"],["w4","w5"],["w5","w_key2"],["w4","w6"],["w6","w7"],["w7","w8"]],
    },
    "rogue_tree": {
        "nodes":[
            {"id":"r1","name":"Swift Hands","stat":{"agi":2}},
            {"id":"r2","name":"Critical Edge","stat":{"crit_chance":0.04}},
            {"id":"r3","name":"Vicious Strike","stat":{"crit_dmg":0.20}},
            {"id":"r4","name":"Backstab Mastery","stat":{"backstab_mult":0.25}},
            {"id":"r5","name":"Toxic Coating","stat":{"poison_dot":4}},
            {"id":"r_key1","name":"Shadow Step: Phase","k":true,"effect":"Shadow Step has no cooldown if it ends behind an enemy."},
            {"id":"r_key2","name":"Fan of Knives: Eviscerate","k":true,"effect":"Fan of Knives applies bleed and refunds 30% energy on crit."},
        ],
        "edges":[["r1","r2"],["r2","r3"],["r3","r4"],["r4","r_key1"],["r3","r5"],["r5","r_key2"]],
    },
    "wizard_tree": {
        "nodes":[
            {"id":"m1","name":"Arcane Tutelage","stat":{"int":2}},
            {"id":"m2","name":"Pyromancy","stat":{"fire_dmg":4}},
            {"id":"m3","name":"Cryomancy","stat":{"frost_dmg":4}},
            {"id":"m4","name":"Stormcalling","stat":{"lightning_dmg":4}},
            {"id":"m5","name":"Mana Wellspring","stat":{"max_mp":18}},
            {"id":"m_key1","name":"Fireball: Conflagration","k":true,"effect":"Fireball leaves a burning patch that ticks for 6s."},
            {"id":"m_key2","name":"Chain Lightning: Tempest","k":true,"effect":"Chain Lightning bounces +3 and forks on crit."},
            {"id":"m6","name":"Quickcast","stat":{"atk_speed":0.06}},
            {"id":"m7","name":"Spell Crit","stat":{"crit_chance":0.04}},
        ],
        "edges":[["m1","m2"],["m1","m3"],["m1","m4"],["m1","m5"],["m2","m_key1"],["m4","m_key2"],["m5","m6"],["m6","m7"]],
    },
    "necromancer_tree": {
        "nodes":[
            {"id":"n1","name":"Soul Tinkering","stat":{"int":2}},
            {"id":"n2","name":"Boneforge","stat":{"summon_hp":0.20}},
            {"id":"n3","name":"Plague","stat":{"poison_dot":4}},
            {"id":"n4","name":"Wraith's Step","stat":{"move_speed":0.06}},
            {"id":"n_key1","name":"Corpse Explosion: Chain","k":true,"effect":"Corpse Explosion can chain across nearby corpses."},
            {"id":"n_key2","name":"Raise Skeleton: Honor Guard","k":true,"effect":"Skeletons gain +50% HP and a guard stance that taunts."},
        ],
        "edges":[["n1","n2"],["n2","n_key2"],["n1","n3"],["n3","n_key1"],["n1","n4"]],
    },
    "bard_tree": {
        "nodes":[
            {"id":"b1","name":"Resonance","stat":{"int":2}},
            {"id":"b2","name":"Tempo","stat":{"atk_speed":0.06}},
            {"id":"b3","name":"Ensemble","stat":{"ally_dmg":0.10}},
            {"id":"b4","name":"Sonic Mastery","stat":{"sonic_dmg":4}},
            {"id":"b_key1","name":"Crescendo: Climax","k":true,"effect":"Crescendo's final note explodes for 2.5x damage."},
        ],
        "edges":[["b1","b2"],["b2","b3"],["b1","b4"],["b4","b_key1"]],
    },
    "paladin_tree": {
        "nodes":[
            {"id":"p1","name":"Devotion","stat":{"sta":2}},
            {"id":"p2","name":"Holy Edge","stat":{"holy_dmg":4}},
            {"id":"p3","name":"Aegis","stat":{"armor":6}},
            {"id":"p4","name":"Lightbearer","stat":{"healing":0.10}},
            {"id":"p_key1","name":"Smite: Judgement","k":true,"effect":"Smite chains to 2 nearby enemies for 60% damage."},
        ],
        "edges":[["p1","p2"],["p2","p_key1"],["p1","p3"],["p3","p4"]],
    },
    "ranger_tree": {
        "nodes":[
            {"id":"x1","name":"Eagle Eye","stat":{"crit_chance":0.04}},
            {"id":"x2","name":"Beastmaster","stat":{"pet_dmg":0.20}},
            {"id":"x3","name":"Trapcraft","stat":{"trap_dmg":0.20}},
            {"id":"x4","name":"Quickdraw","stat":{"atk_speed":0.06}},
            {"id":"x_key1","name":"Volley: Storm","k":true,"effect":"Volley arrows ricochet once on crit."},
        ],
        "edges":[["x1","x2"],["x1","x4"],["x2","x_key1"],["x1","x3"]],
    },
}

func get_tree_def(id: String) -> Dictionary:
    return TREES.get(id, {"nodes":[], "edges":[]})

func get_talent_node(tree_id: String, node_id: String) -> Dictionary:
    var t := get_tree_def(tree_id)
    for n in t.get("nodes", []):
        if n["id"] == node_id:
            return n
    return {}
