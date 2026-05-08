extends Node

# Affix-and-rarity loot system. Tables can be re-tuned via data/balance/loot.json.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC, ARTIFACT }

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Artifact"]
const RARITY_COLORS := [
    Color(0.85, 0.85, 0.85),
    Color(0.30, 0.90, 0.45),
    Color(0.30, 0.55, 1.00),
    Color(0.80, 0.30, 1.00),
    Color(1.00, 0.65, 0.10),
    Color(1.00, 0.20, 0.50),
    Color(0.95, 0.10, 0.10),
]

# Default base weights. enemy_scaling tilts toward higher rarities at depth.
const BASE_WEIGHTS := [600, 250, 95, 40, 12, 2, 0.5]

const SLOTS := ["main_hand","off_hand","head","shoulders","chest","hands","legs","feet","ring","ring2","neck","cloak","belt"]
const WEAPON_BASES := [
    {"id":"longsword","name":"Longsword","slot":"main_hand","dmg":[6,9],"speed":1.0,"tags":["sword","melee"]},
    {"id":"greataxe","name":"Greataxe","slot":"main_hand","dmg":[10,16],"speed":0.65,"tags":["axe","melee","heavy"]},
    {"id":"dagger","name":"Dagger","slot":"main_hand","dmg":[3,5],"speed":1.7,"tags":["dagger","melee","fast"]},
    {"id":"warstaff","name":"Warstaff","slot":"main_hand","dmg":[5,8],"speed":1.1,"tags":["staff","caster"]},
    {"id":"longbow","name":"Longbow","slot":"main_hand","dmg":[7,11],"speed":0.9,"tags":["bow","ranged"]},
    {"id":"warmace","name":"Warmace","slot":"main_hand","dmg":[8,13],"speed":0.85,"tags":["mace","melee"]},
    {"id":"runeblade","name":"Runeblade","slot":"main_hand","dmg":[7,10],"speed":1.0,"tags":["sword","caster"]},
]
const ARMOR_BASES := [
    {"id":"chainmail","name":"Chainmail","slot":"chest","armor":[8,14],"tags":["mail"]},
    {"id":"plate_chest","name":"Plate Cuirass","slot":"chest","armor":[14,22],"tags":["plate"]},
    {"id":"leather_chest","name":"Leather Jerkin","slot":"chest","armor":[5,9],"tags":["leather"]},
    {"id":"helm","name":"Helm","slot":"head","armor":[3,6],"tags":["plate"]},
    {"id":"hood","name":"Hood","slot":"head","armor":[2,4],"tags":["cloth"]},
    {"id":"pauldrons","name":"Pauldrons","slot":"shoulders","armor":[2,5],"tags":["plate"]},
    {"id":"gauntlets","name":"Gauntlets","slot":"hands","armor":[2,4],"tags":["plate"]},
    {"id":"greaves","name":"Greaves","slot":"legs","armor":[4,8],"tags":["plate"]},
    {"id":"sabatons","name":"Sabatons","slot":"feet","armor":[2,4],"tags":["plate"]},
    {"id":"signet","name":"Signet Ring","slot":"ring","armor":[0,0],"tags":["jewelry"]},
    {"id":"amulet","name":"Amulet","slot":"neck","armor":[0,0],"tags":["jewelry"]},
    {"id":"cloak","name":"Cloak","slot":"cloak","armor":[1,3],"tags":["cloth"]},
    {"id":"belt","name":"Belt","slot":"belt","armor":[1,2],"tags":["leather"]},
]

const PREFIXES := [
    {"id":"flaming","name":"Flaming","grants":{"fire_dmg":[3,7]},"tags":["fire"]},
    {"id":"frostbound","name":"Frostbound","grants":{"frost_dmg":[3,7],"slow_chance":[0.10,0.20]},"tags":["frost"]},
    {"id":"thundering","name":"Thundering","grants":{"lightning_dmg":[3,7],"chain_chance":[0.05,0.15]},"tags":["lightning"]},
    {"id":"venomous","name":"Venomous","grants":{"poison_dot":[2,5]},"tags":["poison"]},
    {"id":"shadowed","name":"Shadowed","grants":{"shadow_dmg":[2,6],"crit_chance":[0.02,0.05]},"tags":["shadow"]},
    {"id":"hallowed","name":"Hallowed","grants":{"holy_dmg":[2,6],"undead_bonus":[0.10,0.25]},"tags":["holy"]},
    {"id":"savage","name":"Savage","grants":{"phys_dmg":[3,8],"crit_dmg":[0.10,0.25]},"tags":[]},
    {"id":"swift","name":"Swift","grants":{"atk_speed":[0.05,0.12],"move_speed":[0.05,0.10]},"tags":[]},
    {"id":"vampiric","name":"Vampiric","grants":{"lifesteal":[0.02,0.06]},"tags":[]},
    {"id":"runed","name":"Runed","grants":{"spell_power":[3,9]},"tags":["caster"]},
]
const SUFFIXES := [
    {"id":"of_the_bear","name":"of the Bear","grants":{"stamina":[3,8]}},
    {"id":"of_the_eagle","name":"of the Eagle","grants":{"agility":[3,8]}},
    {"id":"of_the_owl","name":"of the Owl","grants":{"intellect":[3,8]}},
    {"id":"of_the_lion","name":"of the Lion","grants":{"strength":[3,8]}},
    {"id":"of_grit","name":"of Grit","grants":{"max_hp":[10,30]}},
    {"id":"of_focus","name":"of Focus","grants":{"max_mp":[8,20]}},
    {"id":"of_the_phoenix","name":"of the Phoenix","grants":{"on_low_hp_burst":[1,1]}},
    {"id":"of_the_drake","name":"of the Drake","grants":{"fire_resist":[0.05,0.15]}},
    {"id":"of_the_kraken","name":"of the Kraken","grants":{"frost_resist":[0.05,0.15]}},
    {"id":"of_the_basilisk","name":"of the Basilisk","grants":{"poison_resist":[0.05,0.15]}},
]

var rng := RandomNumberGenerator.new()
var unidentified_chance: float = 0.18

func _ready() -> void:
    rng.randomize()

func roll_rarity(scaling: float = 1.0, magic_find: float = 0.0) -> int:
    var weights := BASE_WEIGHTS.duplicate()
    # tilt with depth + magic find
    for i in range(weights.size()):
        var tier_factor: float = 1.0 + (float(i) * 0.20 * (scaling - 1.0)) + (float(i) * 0.30 * magic_find)
        weights[i] = weights[i] * tier_factor
    var total := 0.0
    for w in weights:
        total += float(w)
    var r := rng.randf() * total
    var acc := 0.0
    for i in range(weights.size()):
        acc += float(weights[i])
        if r <= acc:
            return i
    return Rarity.COMMON

func roll_item(rarity: int = -1, scaling: float = 1.0, slot_filter: String = "") -> Dictionary:
    if rarity < 0:
        rarity = roll_rarity(scaling)
    var pool := WEAPON_BASES + ARMOR_BASES
    if slot_filter != "":
        pool = pool.filter(func(b): return b["slot"] == slot_filter)
    var base: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
    var item := {
        "id": base["id"] + "_" + str(rng.randi()),
        "base": base["id"],
        "name": _name_for(base, rarity),
        "slot": base["slot"],
        "rarity": rarity,
        "tags": base.get("tags", []).duplicate(),
        "affixes": [],
        "stats": {},
        "identified": rng.randf() > unidentified_chance,
        "ilvl": int(scaling * 10.0) + rng.randi_range(0, 4),
    }
    if base.has("dmg"):
        var dmg: Array = base["dmg"]
        var bonus: float = pow(1.18, float(rarity))
        var d_low: int = int(round(float(dmg[0]) * bonus))
        var d_high: int = int(round(float(dmg[1]) * bonus))
        item["stats"]["dmg_min"] = d_low
        item["stats"]["dmg_max"] = d_high
        item["stats"]["speed"] = base.get("speed", 1.0)
    if base.has("armor"):
        var a: Array = base["armor"]
        var bonus_a: float = pow(1.20, float(rarity))
        item["stats"]["armor"] = int(round(rng.randf_range(float(a[0]), float(a[1])) * bonus_a))
    var n_prefix := 0
    var n_suffix := 0
    match rarity:
        Rarity.COMMON: pass
        Rarity.UNCOMMON: n_prefix = 1
        Rarity.RARE: n_prefix = 1; n_suffix = 1
        Rarity.EPIC: n_prefix = 2; n_suffix = 1
        Rarity.LEGENDARY: n_prefix = 2; n_suffix = 2
        Rarity.MYTHIC: n_prefix = 3; n_suffix = 2
        Rarity.ARTIFACT: n_prefix = 3; n_suffix = 3
    var taken_p := []
    var taken_s := []
    for i in range(n_prefix):
        var p: Dictionary = PREFIXES[rng.randi_range(0, PREFIXES.size() - 1)]
        if taken_p.has(p["id"]): continue
        taken_p.append(p["id"])
        item["affixes"].append({"kind":"prefix","id":p["id"],"name":p["name"],"grants":_roll_grants(p["grants"]),"tags":p.get("tags", [])})
        for t in p.get("tags", []):
            if not item["tags"].has(t): item["tags"].append(t)
    for i in range(n_suffix):
        var s: Dictionary = SUFFIXES[rng.randi_range(0, SUFFIXES.size() - 1)]
        if taken_s.has(s["id"]): continue
        taken_s.append(s["id"])
        item["affixes"].append({"kind":"suffix","id":s["id"],"name":s["name"],"grants":_roll_grants(s["grants"]),"tags":[]})
    item["name"] = _full_name(base, item)
    return item

func _name_for(base: Dictionary, rarity: int) -> String:
    return base["name"]

func _full_name(base: Dictionary, item: Dictionary) -> String:
    var prefix := ""
    var suffix := ""
    for a in item["affixes"]:
        if a["kind"] == "prefix" and prefix == "":
            prefix = a["name"] + " "
        elif a["kind"] == "suffix" and suffix == "":
            suffix = " " + a["name"]
    return prefix + base["name"] + suffix

func _roll_grants(g: Dictionary) -> Dictionary:
    var out := {}
    for k in g.keys():
        var v: Array = g[k]
        if v[0] is float or v[1] is float:
            out[k] = snapped(rng.randf_range(float(v[0]), float(v[1])), 0.01)
        else:
            out[k] = rng.randi_range(int(v[0]), int(v[1]))
    return out

func gold_drop(scaling: float = 1.0) -> int:
    return int(rng.randi_range(2, 12) * scaling)

func aggregate_stats(equipped: Dictionary) -> Dictionary:
    # equipped: slot -> item
    var s := {}
    for slot in equipped.keys():
        var it: Variant = equipped[slot]
        if typeof(it) != TYPE_DICTIONARY: continue
        for k in (it as Dictionary).get("stats", {}).keys():
            s[k] = float(s.get(k, 0)) + float((it as Dictionary)["stats"][k])
        for a in (it as Dictionary).get("affixes", []):
            for k in (a as Dictionary).get("grants", {}).keys():
                s[k] = float(s.get(k, 0)) + float((a as Dictionary)["grants"][k])
    return s
