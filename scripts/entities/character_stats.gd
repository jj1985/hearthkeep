extends RefCounted
class_name CharacterStats

var max_hp: float = 100.0
var hp: float = 100.0
var max_mp: float = 50.0
var mp: float = 50.0
var armor: float = 0.0
var move_speed: float = 220.0
var attack_speed: float = 1.0
var damage: float = 10.0
var crit_chance: float = 0.05
var crit_damage: float = 1.5
var lifesteal: float = 0.0
var thorns: float = 0.0

func is_dead() -> bool:
    return hp <= 0.0

func mitigate(amount: float) -> float:
    var reduction: float = armor / (armor + 100.0)
    return max(1.0, amount * (1.0 - reduction))
