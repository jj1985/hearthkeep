extends CharacterBody2D

const CharacterStats := preload("res://scripts/entities/character_stats.gd")

@export var class_primary: String = "warrior"
@export var class_secondary: String = ""

var stats: CharacterStats
var attack_cooldown: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_timer: float = 0.0
var dodging: bool = false
var facing: Vector2 = Vector2.RIGHT
var equipped: Dictionary = {}                 # slot -> item dict
var dye_overlay: Dictionary = {}              # slot -> Color (visible armor tint)

@onready var sprite: Polygon2D = $Body
@onready var weapon: Polygon2D = $WeaponHand
@onready var hp_bar: ColorRect = $HpBar
@onready var dye_chest: ColorRect = $ArmorOverlay/Chest
@onready var dye_helm: ColorRect = $ArmorOverlay/Helm
@onready var dye_cloak: ColorRect = $ArmorOverlay/Cloak
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/Shape
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/Shape

signal player_attacked(direction)
signal player_picked(item)

func _ready() -> void:
    stats = CharacterStats.new()
    _apply_class_base()
    _refresh_dye_overlay()
    EventBus.perk_chosen.connect(_on_perk_chosen)
    EventBus.weapon_evolved.connect(_on_weapon_evolved)
    add_to_group("player")
    z_index = 5

func _apply_class_base() -> void:
    var c := ClassDB.get_class(class_primary)
    if c.is_empty():
        return
    stats.max_hp = float(c["base_hp"]) * RunState.max_hp_mult
    stats.hp = stats.max_hp
    stats.max_mp = float(c["base_mp"])
    stats.mp = stats.max_mp
    stats.armor = float(c["base_armor"])
    var profile: Dictionary = c["stat_profile"]
    stats.damage = 6.0 + float(profile.get("str", 5)) * 0.5 + float(profile.get("int", 5)) * 0.4
    stats.crit_chance = 0.05 + float(profile.get("agi", 5)) * 0.005

func equipped_weapon_tags() -> Array:
    var tags: Array = []
    var mh: Variant = equipped.get("main_hand", null)
    if typeof(mh) == TYPE_DICTIONARY:
        for t in (mh as Dictionary).get("tags", []):
            tags.append(t)
    return tags

func current_damage() -> float:
    var d := stats.damage * RunState.damage_mult
    var weapon_dmg := 0.0
    var mh: Variant = equipped.get("main_hand", null)
    if typeof(mh) == TYPE_DICTIONARY:
        var s: Dictionary = (mh as Dictionary).get("stats", {})
        weapon_dmg = (float(s.get("dmg_min", 0)) + float(s.get("dmg_max", 0))) * 0.5
    return d + weapon_dmg

func current_attack_speed() -> float:
    return stats.attack_speed * RunState.atk_speed_mult

func current_move_speed() -> float:
    return stats.move_speed * RunState.move_speed_mult

func _physics_process(delta: float) -> void:
    if stats.is_dead():
        return
    attack_cooldown = max(0.0, attack_cooldown - delta)
    dodge_cooldown = max(0.0, dodge_cooldown - delta)
    dodge_timer = max(0.0, dodge_timer - delta)
    dodging = dodge_timer > 0.0

    var input := Vector2(
        Input.get_axis("move_left","move_right"),
        Input.get_axis("move_up","move_down"))
    if input.length() > 1.0:
        input = input.normalized()
    if input.length() > 0.1:
        facing = input.normalized()

    var speed_mult: float = 1.7 if dodging else 1.0
    velocity = input * current_move_speed() * speed_mult
    move_and_slide()

    if Input.is_action_just_pressed("attack"):
        _attack()
    if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0:
        dodge_cooldown = 0.6
        dodge_timer = 0.18
    if Input.is_action_just_pressed("potion_hp"):
        _use_potion("hp")
    if Input.is_action_just_pressed("potion_mp"):
        _use_potion("mp")

    weapon.rotation = facing.angle()
    _update_hp_bar()

func _attack() -> void:
    if attack_cooldown > 0.0:
        return
    attack_cooldown = 0.55 / max(0.1, current_attack_speed())
    player_attacked.emit(facing)
    attack_area.position = facing * 30.0
    attack_area.rotation = facing.angle()
    attack_area.monitoring = true
    var hits: Array[Node2D] = attack_area.get_overlapping_bodies()
    var damage_dealt := false
    for body in hits:
        if body.is_in_group("enemy") and body.has_method("take_damage"):
            var roll_crit: bool = randf() < (stats.crit_chance + RunState.crit_chance_bonus)
            var dmg: float = current_damage() * (stats.crit_damage + RunState.crit_damage_bonus if roll_crit else 1.0)
            (body as Object).call("take_damage", dmg, self, roll_crit)
            damage_dealt = true
    if damage_dealt:
        VFX.hit_stop(0.04)
        VFX.spawn_hit_burst(global_position + facing * 30.0, Color(1, 1, 1))
    # Sword evolution: emit fire ring damage on each swing
    if RunState.weapon_evolutions.has("sunfire_reaver"):
        for body in get_tree().get_nodes_in_group("enemy"):
            if not is_instance_valid(body): continue
            var n2d: Node2D = body as Node2D
            if n2d == null: continue
            if global_position.distance_to(n2d.global_position) < 96.0:
                if body.has_method("take_damage"):
                    (body as Object).call("take_damage", current_damage() * 0.25, self, false)

func take_damage(amount: float, _src: Object) -> void:
    if dodging:
        return
    var mitigated: float = stats.mitigate(amount)
    stats.hp = max(0.0, stats.hp - mitigated)
    EventBus.damage_dealt.emit(_src, self, mitigated, false)
    EventBus.floating_text.emit(str(int(mitigated)), global_position + Vector2(0, -32), Color(1, 0.4, 0.4))
    VFX.spawn_hit_burst(global_position, Color(1, 0.3, 0.3), 0.7)
    VFX.screen_shake(3.0, 0.1)
    if stats.is_dead():
        EventBus.player_died.emit()
    if RunState.thorns_pct > 0.0 and _src is Node2D and (_src as Node).is_in_group("enemy"):
        if (_src as Object).has_method("take_damage"):
            (_src as Object).call("take_damage", mitigated * RunState.thorns_pct, self, false)

func _use_potion(kind: String) -> void:
    EventBus.potion_used.emit(kind)
    SfxBus.play("potion")
    if kind == "hp":
        stats.hp = min(stats.max_hp, stats.hp + stats.max_hp * 0.45)
        VFX.spawn_hit_burst(global_position, Color(0.95, 0.2, 0.4), 1.2)
        EventBus.floating_text.emit("+HEAL", global_position + Vector2(0, -36), Color(1, 0.4, 0.5))
    elif kind == "mp":
        stats.mp = min(stats.max_mp, stats.mp + stats.max_mp * 0.5)
        VFX.spawn_hit_burst(global_position, Color(0.3, 0.5, 1.0), 1.2)
        EventBus.floating_text.emit("+MP", global_position + Vector2(0, -36), Color(0.5, 0.7, 1.0))

func _update_hp_bar() -> void:
    var pct: float = stats.hp / stats.max_hp
    hp_bar.scale.x = clamp(pct, 0.0, 1.0)
    hp_bar.color = Color(1.0 - pct, pct, 0.1)

func _refresh_dye_overlay() -> void:
    dye_chest.color = DyeSystem.dye_for("chest")
    dye_helm.color = DyeSystem.dye_for("head")
    dye_cloak.color = DyeSystem.dye_for("cloak")

func gain_xp(amount: float) -> void:
    RunState.add_xp(amount * RunState.wager_multiplier)

func _on_perk_chosen(_id: String) -> void:
    var new_max: float = stats.max_hp
    var c := ClassDB.get_class(class_primary)
    if not c.is_empty():
        new_max = float(c["base_hp"]) * RunState.max_hp_mult
    var hp_ratio: float = stats.hp / max(1.0, stats.max_hp)
    stats.max_hp = new_max
    stats.hp = clamp(new_max * hp_ratio, 0.0, new_max)

func _on_weapon_evolved(_from, evo_id: String) -> void:
    EventBus.floating_text.emit("EVOLVED!", global_position + Vector2(0, -48), Color(1, 0.6, 1))
    VFX.spawn_levelup_flare(global_position)
    if evo_id == "sunfire_reaver":
        VFX.spawn_fire_ring(self, 96.0)
