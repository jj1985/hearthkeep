extends Node

# Class definitions. Each base class owns a stat profile, a set of skills,
# passives, a talent tree id, and tag affinities. Multiclass synergies are
# rolled by combining tag sets via class_synergies.gd.

const CLASSES := {
    "warrior": {
        "name": "Warrior",
        "blurb": "Plate-clad bulwark. Cleaves crowds, weathers blows.",
        "stat_profile": {"str":12,"agi":7,"int":4,"sta":11},
        "tags":["physical","melee","frontline"],
        "base_hp":160, "base_mp":40, "base_armor":8,
        "skills":["cleave","whirlwind","shield_charge","battlecry","execute","earthshatter"],
        "passives":["second_wind","unstoppable","ironhide","tactical_strikes"],
        "talent_tree":"warrior_tree",
    },
    "rogue": {
        "name": "Rogue",
        "blurb": "Daggers, shadows, and a smile in the dark.",
        "stat_profile": {"str":7,"agi":13,"int":7,"sta":7},
        "tags":["physical","melee","stealth","crit"],
        "base_hp":110, "base_mp":50, "base_armor":4,
        "skills":["backstab","shadow_step","poison_strike","fan_of_knives","smoke_bomb","death_mark"],
        "passives":["evasion","critical_focus","ambusher","quickdraw"],
        "talent_tree":"rogue_tree",
    },
    "wizard": {
        "name": "Wizard",
        "blurb": "Channeller of elements; minds the mana bar.",
        "stat_profile": {"str":4,"agi":6,"int":15,"sta":6},
        "tags":["caster","fire","frost","lightning","aoe"],
        "base_hp":85, "base_mp":120, "base_armor":2,
        "skills":["fireball","frost_nova","chain_lightning","arcane_orb","blink","meteor"],
        "passives":["mana_shield","elemental_mastery","arcane_focus","spell_pierce"],
        "talent_tree":"wizard_tree",
    },
    "necromancer": {
        "name": "Necromancer",
        "blurb": "Bones rise; ghosts whisper. Death obeys.",
        "stat_profile": {"str":5,"agi":6,"int":12,"sta":9},
        "tags":["caster","shadow","poison","summon","dot"],
        "base_hp":95, "base_mp":110, "base_armor":3,
        "skills":["raise_skeleton","corpse_explosion","bone_spear","life_tap","soul_drain","bone_prison"],
        "passives":["soul_collector","wraith_form","decaying_aura","grim_pact"],
        "talent_tree":"necromancer_tree",
    },
    "bard": {
        "name": "Bard",
        "blurb": "Songs that bolster, shouts that shatter.",
        "stat_profile": {"str":6,"agi":11,"int":9,"sta":7},
        "tags":["caster","ranged","support","aoe"],
        "base_hp":105, "base_mp":80, "base_armor":3,
        "skills":["dissonance","heroic_anthem","sonic_arrow","crescendo","mirror_image","encore"],
        "passives":["resonance","virtuoso","perfect_pitch","rallying_cry"],
        "talent_tree":"bard_tree",
    },
    "paladin": {
        "name": "Paladin",
        "blurb": "Holy steel. Smites and shields equally.",
        "stat_profile": {"str":11,"agi":5,"int":8,"sta":10},
        "tags":["physical","melee","holy","support"],
        "base_hp":150, "base_mp":70, "base_armor":7,
        "skills":["smite","consecrate","blessing_of_might","divine_shield","hammer_of_wrath","lay_on_hands"],
        "passives":["aura_of_devotion","righteous_fury","sacred_oath","retribution"],
        "talent_tree":"paladin_tree",
    },
    "ranger": {
        "name": "Ranger",
        "blurb": "Bow drawn, beast at heel, hunter in flesh.",
        "stat_profile": {"str":7,"agi":13,"int":6,"sta":8},
        "tags":["physical","ranged","beast","crit"],
        "base_hp":115, "base_mp":55, "base_armor":4,
        "skills":["volley","aimed_shot","beast_companion","hunters_mark","trap","explosive_arrow"],
        "passives":["eagle_eye","beast_bond","wilderness","precise_aim"],
        "talent_tree":"ranger_tree",
    },
}

# Multiclass synergies — tag intersections grant named hybrid prestiges.
const HYBRID_PRESTIGES := [
    {"id":"death_knight","require":["warrior","necromancer"],"name":"Death Knight",
     "perk":"Strikes drain souls. Killing an enemy heals 4% max HP and lasts 6s as a wraith aura."},
    {"id":"trickster","require":["rogue","bard"],"name":"Trickster",
     "perk":"Smoke bomb spawns mirror images. Crits silence enemies for 1.5s."},
    {"id":"spellbow","require":["wizard","ranger"],"name":"Spellbow",
     "perk":"Bow shots cycle elemental tags. Each shot benefits from highest elemental affix."},
    {"id":"templar","require":["paladin","wizard"],"name":"Templar",
     "perk":"Spells crit on holy-tagged enemies. Smite radius +50%."},
    {"id":"warden","require":["paladin","ranger"],"name":"Warden",
     "perk":"Beast companion gains thorns aura. Hunter's Mark heals allies."},
    {"id":"bonechant","require":["necromancer","bard"],"name":"Bonechanter",
     "perk":"Songs raise temporary bone minions on tempo. Crescendo explodes corpses."},
    {"id":"berserker","require":["warrior","ranger"],"name":"Berserker",
     "perk":"Below 50% HP: +30% atk speed and +40% crit chance."},
    {"id":"shadow_blade","require":["rogue","wizard"],"name":"Shadow Blade",
     "perk":"Backstab applies a random elemental DoT. Blink resets backstab."},
    {"id":"warpriest","require":["paladin","bard"],"name":"Warpriest",
     "perk":"Heroic Anthem heals on tempo. Smite triggers an AOE shockwave."},
    {"id":"plaguelord","require":["necromancer","ranger"],"name":"Plaguelord",
     "perk":"Arrows leave poison clouds. Corpses spawn poison wisps that seek enemies."},
]

func get_class(id: String) -> Dictionary:
    return CLASSES.get(id, {})

func names() -> Array:
    return CLASSES.keys()

func hybrid_for(primary: String, secondary: String) -> Dictionary:
    for h in HYBRID_PRESTIGES:
        var req: Array = h["require"]
        if (req[0] == primary and req[1] == secondary) or (req[0] == secondary and req[1] == primary):
            return h
    return {}

func combined_tags(primary: String, secondary: String = "") -> Array:
    var tags: Array = []
    for t in CLASSES.get(primary, {}).get("tags", []):
        if not tags.has(t): tags.append(t)
    if secondary != "":
        for t in CLASSES.get(secondary, {}).get("tags", []):
            if not tags.has(t): tags.append(t)
    return tags
