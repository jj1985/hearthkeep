extends Node3D
class_name DragonBoss

# Base class for the three named dragons (Vyxhasis, Ourzhal, Aethyrnax).
# Owns the phase state machine + ability cooldown registry. Subclasses
# implement the per-phase telegraphs / hitboxes / VFX.

enum Phase { GROUND, AIR, ENRAGED }

signal phase_entered(phase)
signal died

@export var dragon_id: String = "vyxhasis"
@export var max_hp: float = 1000.0
@export var contact_damage: float = 16.0

var hp: float = 1000.0
var phase: int = Phase.GROUND
var _abilities: Dictionary = {}    # id -> {cd: float, remaining: float}
var _dead: bool = false

func _ready() -> void:
    hp = max_hp
    add_to_group("boss")
    add_to_group("dragon")

# ---- Damage model -----------------------------------------------------------

func take_damage(amount: float) -> void:
    if _dead:
        return
    hp = max(0.0, hp - amount)
    var pct: float = hp / max(1.0, max_hp)
    var new_phase: int = phase
    if pct <= 0.33:
        new_phase = Phase.ENRAGED
    elif pct <= 0.70:
        new_phase = Phase.AIR
    else:
        new_phase = Phase.GROUND
    if new_phase > phase:    # one-way only — phases never revert
        phase = new_phase
        _reset_cooldowns()
        phase_entered.emit(phase)
    if hp <= 0.0:
        _dead = true
        died.emit()

func heal(amount: float) -> void:
    if _dead:
        return
    hp = min(max_hp, hp + amount)
    # Phases are one-way; do NOT recompute phase on heal.

func is_dead() -> bool:
    return _dead

# ---- Ability registry -------------------------------------------------------

func register_ability(id: String, cooldown_s: float) -> void:
    _abilities[id] = {"cd": cooldown_s, "remaining": 0.0}

func is_ability_ready(id: String) -> bool:
    if not _abilities.has(id):
        return false
    return float(_abilities[id]["remaining"]) <= 0.0

func consume_ability(id: String) -> bool:
    if not is_ability_ready(id):
        return false
    _abilities[id]["remaining"] = _abilities[id]["cd"]
    return true

func tick(delta: float) -> void:
    for id in _abilities.keys():
        var rem: float = float(_abilities[id]["remaining"])
        _abilities[id]["remaining"] = max(0.0, rem - delta)

func _reset_cooldowns() -> void:
    for id in _abilities.keys():
        _abilities[id]["remaining"] = 0.0
