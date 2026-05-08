extends Node

# Buff system. Self-buffs, weapon buffs, and aura visuals.
#
# Buff record: { id, name, icon_color, duration, expires_at, stacks, source,
#   exclusive_group, mods: { stat_field: delta }, weapon_element: "fire"|"frost"|...,
#   aura_color }
#
# Source priority (higher wins on conflict):
#   1 = consumable scroll/potion
#   2 = class skill self-buff
#   3 = boss aura granting buff
#   4 = legendary item proc

const SOURCE_CONSUMABLE := 1
const SOURCE_CLASS_SKILL := 2
const SOURCE_BOSS_AURA := 3
const SOURCE_LEGENDARY := 4

const CATALOG := {
    "stoneskin": {
        "name":"Scroll of Stoneskin", "duration": 60.0, "icon_color": Color(0.65,0.65,0.7),
        "mods": {"damage_reduction": 0.20}, "exclusive_group": "skin",
        "aura_color": Color(0.55, 0.55, 0.65, 0.4),
    },
    "haste": {
        "name":"Elixir of Haste", "duration": 30.0, "icon_color": Color(0.45,0.85,1.0),
        "mods": {"atk_speed_mult": 0.25}, "exclusive_group": "speed",
        "aura_color": Color(0.5, 0.85, 1.0, 0.4),
    },
    "inspiration": {
        "name":"Bardic Inspiration", "duration": 20.0, "icon_color": Color(0.95,0.85,0.4),
        "mods": {"damage_mult": 0.15}, "exclusive_group": "inspiration",
        "aura_color": Color(1.0, 0.85, 0.3, 0.5),
    },
    "mind_focus": {
        "name":"Wizard's Mind Focus", "duration": 45.0, "icon_color": Color(0.65,0.45,1.0),
        "mods": {"cast_speed_mult": 0.20}, "exclusive_group": "focus",
        "aura_color": Color(0.65, 0.45, 1.0, 0.45),
    },
    "blessing_might": {
        "name":"Blessing of Might", "duration": 90.0, "icon_color": Color(1.0,0.75,0.3),
        "mods": {"damage_mult": 0.10}, "exclusive_group": "blessing",
        "aura_color": Color(1.0, 0.75, 0.3, 0.45),
    },
    "regen": {
        "name":"Regeneration", "duration": 25.0, "icon_color": Color(0.30,0.85,0.30),
        "mods": {"hp_regen_per_s": 6.0}, "exclusive_group": "regen",
        "aura_color": Color(0.3, 0.95, 0.3, 0.4),
    },
}

const WEAPON_BUFFS := {
    "whetstone_flame": {"name":"Whetstone of Flame","duration":120.0,"element":"fire","aura_color":Color(1.0,0.5,0.1,0.7),"on_hit_dmg":4},
    "frost_oil":      {"name":"Frost Oil","duration":120.0,"element":"frost","aura_color":Color(0.5,0.85,1.0,0.7),"on_hit_dmg":3,"on_hit_slow":0.20},
    "lightning_coat": {"name":"Lightning Coating","duration":90.0,"element":"lightning","aura_color":Color(0.9,0.9,1.0,0.7),"on_hit_dmg":3,"on_hit_chain":0.15},
    "poison_vial":    {"name":"Poison Vial","duration":150.0,"element":"poison","aura_color":Color(0.55,1.0,0.4,0.7),"on_hit_dmg":2,"on_hit_dot":3},
    "holy_oil":       {"name":"Holy Oil","duration":120.0,"element":"holy","aura_color":Color(1.0,0.95,0.5,0.7),"on_hit_dmg":4,"on_hit_undead_bonus":0.25},
}

var active: Array = []                 # array of buff records
var weapon_active: Dictionary = {}     # element -> buff record
var hp_regen_accum: float = 0.0

signal buffs_changed

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    if active.is_empty() and weapon_active.is_empty():
        return
    var t: float = Time.get_ticks_msec() / 1000.0
    var changed := false
    for i in range(active.size() - 1, -1, -1):
        var b: Dictionary = active[i]
        if t >= float(b["expires_at"]):
            EventBus.buff_expired.emit(b["id"])
            active.remove_at(i)
            changed = true
    for k in weapon_active.keys():
        var w: Dictionary = weapon_active[k]
        if t >= float(w["expires_at"]):
            weapon_active.erase(k)
            changed = true
    # HP regen aggregate
    var regen: float = aggregate_mod("hp_regen_per_s")
    if regen > 0.0:
        hp_regen_accum += regen * delta
        if hp_regen_accum >= 1.0:
            var amt := int(hp_regen_accum)
            hp_regen_accum -= float(amt)
            EventBus.floating_text.emit("+" + str(amt), Vector2.ZERO, Color(0.4, 1.0, 0.4))
    if changed:
        buffs_changed.emit()

func apply(buff_id: String, source_kind: int = SOURCE_CONSUMABLE) -> bool:
    if not CATALOG.has(buff_id):
        return false
    var def: Dictionary = CATALOG[buff_id]
    var t: float = Time.get_ticks_msec() / 1000.0
    var record := {
        "id": buff_id,
        "name": def["name"],
        "icon_color": def["icon_color"],
        "duration": def["duration"],
        "expires_at": t + float(def["duration"]),
        "exclusive_group": def.get("exclusive_group", ""),
        "source": source_kind,
        "mods": def.get("mods", {}),
        "aura_color": def.get("aura_color", Color(1,1,1,0.3)),
    }
    var grp: String = record["exclusive_group"]
    if grp != "":
        for i in range(active.size() - 1, -1, -1):
            var b: Dictionary = active[i]
            if b.get("exclusive_group", "") == grp:
                if int(b.get("source", 0)) > source_kind:
                    return false
                active.remove_at(i)
    active.append(record)
    EventBus.buff_applied.emit(buff_id, source_kind)
    buffs_changed.emit()
    return true

func apply_weapon_buff(buff_id: String) -> bool:
    if not WEAPON_BUFFS.has(buff_id):
        return false
    var def: Dictionary = WEAPON_BUFFS[buff_id]
    var t: float = Time.get_ticks_msec() / 1000.0
    var record := def.duplicate()
    record["id"] = buff_id
    record["expires_at"] = t + float(def["duration"])
    weapon_active[def["element"]] = record
    EventBus.weapon_buff_applied.emit(buff_id)
    buffs_changed.emit()
    return true

func aggregate_mod(field: String) -> float:
    var total := 0.0
    for b in active:
        var m: Dictionary = (b as Dictionary).get("mods", {})
        if m.has(field):
            total += float(m[field])
    return total

func has_weapon_element(elem: String) -> bool:
    return weapon_active.has(elem)

func active_aura_colors() -> Array:
    var out: Array = []
    for b in active:
        out.append(b.get("aura_color", Color.WHITE))
    for k in weapon_active.keys():
        out.append(weapon_active[k].get("aura_color", Color.WHITE))
    return out

func clear_run_buffs() -> void:
    active.clear()
    weapon_active.clear()
    buffs_changed.emit()

func active_count() -> int:
    return active.size() + weapon_active.size()
