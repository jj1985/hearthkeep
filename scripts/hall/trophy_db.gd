extends RefCounted
class_name TrophyDB

# Trophy definitions and named sets. Loaded as a static class.

const TROPHIES := [
    # Goblin warband set
    {"id":"goblin_skirmisher_horn","name":"Goblin Skirmisher Horn","slot_kind":"wall_mount","set":"goblin_slayers_hall",
     "buff":{"dmg_vs_goblin":0.05},"buff_label":"+5% damage vs goblins"},
    {"id":"goblin_sapper_drum","name":"Goblin Sapper's Drum","slot_kind":"floor_display","set":"goblin_slayers_hall",
     "buff":{"explosion_resist":0.10},"buff_label":"+10% explosion resistance"},
    {"id":"warchief_crown","name":"Warchief's Iron Crown","slot_kind":"pedestal","set":"goblin_slayers_hall",
     "buff":{"crit_chance_vs_goblin":0.05},"buff_label":"+5% crit chance vs goblins"},

    # Dragon set
    {"id":"vyxhasis_horn","name":"Horn of Vyxhasis","slot_kind":"wall_mount","set":"dragonsworn_sanctum",
     "buff":{"fire_resist":0.05},"buff_label":"+5% fire resistance"},
    {"id":"ourzhal_scale","name":"Ourzhal's Stormscale","slot_kind":"pedestal","set":"dragonsworn_sanctum",
     "buff":{"lightning_dmg":0.05},"buff_label":"+5% lightning damage"},
    {"id":"aethyrnax_fang","name":"Fang of Aethyrnax","slot_kind":"pedestal","set":"dragonsworn_sanctum",
     "buff":{"frost_resist":0.05},"buff_label":"+5% frost resistance"},
    {"id":"dragon_eye_pendant","name":"Dragon-Eye Pendant","slot_kind":"case","set":"dragonsworn_sanctum",
     "buff":{"crit_dmg":0.10},"buff_label":"+10% crit damage"},
    {"id":"primal_wing","name":"Primal Wing Mantle","slot_kind":"floor_display","set":"dragonsworn_sanctum",
     "buff":{"move_speed":0.04},"buff_label":"+4% move speed"},

    # Faction banners
    {"id":"coastreach_banner","name":"Coastreach Crown Banner","slot_kind":"banner","set":"diplomats_keep",
     "buff":{"rep_gain_coastreach":0.15},"buff_label":"+15% Coastreach reputation gain"},
    {"id":"bastion_banner","name":"Black Bastion Banner","slot_kind":"banner","set":"diplomats_keep",
     "buff":{"vendor_buyback_discount":0.10},"buff_label":"-10% buyback price"},
    {"id":"canopyhall_banner","name":"Canopyhall Council Banner","slot_kind":"banner","set":"diplomats_keep",
     "buff":{"rep_gain_canopyhall":0.15},"buff_label":"+15% Canopyhall reputation gain"},
    {"id":"kaeldur_banner","name":"Kaeldur Clans Banner","slot_kind":"banner","set":"diplomats_keep",
     "buff":{"forge_discount":0.10},"buff_label":"-10% forge cost"},

    # Tomes / journals
    {"id":"sundering_tome","name":"Tome of the Sundering","slot_kind":"bookshelf","set":"sage_archive",
     "buff":{"xp_gain":0.05},"buff_label":"+5% XP gain"},
    {"id":"forge_oath_tome","name":"The Forge Oath","slot_kind":"bookshelf","set":"sage_archive",
     "buff":{"identification_speed":0.50},"buff_label":"Items auto-identify 50% of the time"},
    {"id":"hunters_codex","name":"Hunter's Codex","slot_kind":"bookshelf","set":"sage_archive",
     "buff":{"trap_dmg":0.10},"buff_label":"+10% trap damage"},

    # Special / unique
    {"id":"phoenix_plume","name":"Phoenix Plume","slot_kind":"case","set":"",
     "buff":{"once_per_run_revive":1},"buff_label":"Once per run: revive at 30% HP on death",
     "active_ability":true},
    {"id":"ironheart_chalice","name":"Ironheart Chalice","slot_kind":"pedestal","set":"",
     "buff":{"max_hp_pct":0.05},"buff_label":"+5% max HP"},
    {"id":"sennari_dice","name":"Sennari's Dice","slot_kind":"case","set":"",
     "buff":{"gambling_house_edge_reduction":0.10},"buff_label":"-10% gambling den house edge"},
]

const SETS := {
    "goblin_slayers_hall": {
        "name":"Goblin Slayer's Hall",
        "members":["goblin_skirmisher_horn","goblin_sapper_drum","warchief_crown"],
        "set_buff":{"dmg_vs_goblin":0.10,"gold_drop_vs_goblin":0.15},
        "set_buff_label":"+10% damage and +15% gold drops vs goblins",
    },
    "dragonsworn_sanctum": {
        "name":"Dragonsworn Sanctum",
        "members":["vyxhasis_horn","ourzhal_scale","aethyrnax_fang","dragon_eye_pendant","primal_wing"],
        "set_buff":{"fire_resist":0.08,"frost_resist":0.08,"lightning_resist":0.08,"once_per_run_lethal_save":1},
        "set_buff_label":"+8% all elemental resists; once per run, negate a fatal blow",
    },
    "diplomats_keep": {
        "name":"Diplomat's Keep",
        "members":["coastreach_banner","bastion_banner","canopyhall_banner","kaeldur_banner"],
        "set_buff":{"rep_gain_all":0.25},
        "set_buff_label":"+25% reputation gain across all factions",
    },
    "sage_archive": {
        "name":"Sage's Archive",
        "members":["sundering_tome","forge_oath_tome","hunters_codex"],
        "set_buff":{"xp_gain":0.10,"lore_unlock_rate":2.0},
        "set_buff_label":"+10% XP gain; lore drops twice as often",
    },
}

static func find(id: String) -> Dictionary:
    for t in TROPHIES:
        if (t as Dictionary)["id"] == id:
            return t
    return {}

static func members_of(set_id: String) -> Array:
    if SETS.has(set_id):
        return SETS[set_id]["members"]
    return []
