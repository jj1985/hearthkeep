extends CharacterBody3D

# Bandit — fast melee with parry chance. Mid-floor enemy; bridges
# the gap between goblin trash and warchief elites.

const CharacterStats := preload("res://scripts/entities/character_stats.gd")

@export var stats_scale: float = 1.0

var stats: CharacterStats
var attack_cooldown: float = 0.0
var attack_range: float = 1.6
var sight_radius: float = 16.0
var aggro: bool = false
var hit_flash: float = 0.0
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var parry_chance: float = 0.20
var monster_id_value: String = "bandit"

@onready var body_mesh: MeshInstance3D = $Body if has_node("Body") else null

func _ready() -> void:
    stats = CharacterStats.new()
    stats.max_hp = 36.0 * stats_scale
    stats.hp = stats.max_hp
    stats.damage = 9.0 * stats_scale
    stats.move_speed = 5.5
    stats.armor = 2.0
    add_to_group("enemy")
    monster_id_value = "bandit"
    if body_mesh != null and body_mesh.material_override == null:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.30, 0.22, 0.18)
        body_mesh.material_override = mat

func monster_id() -> String:
    return monster_id_value

func _physics_process(delta: float) -> void:
    if stats.is_dead():
        return
    attack_cooldown = max(0.0, attack_cooldown - delta)
    hit_flash = max(0.0, hit_flash - delta)
    stun_timer = max(0.0, stun_timer - delta)
    slow_timer = max(0.0, slow_timer - delta)
    if stun_timer > 0.0:
        velocity = Vector3.ZERO
        move_and_slide()
        return
    var player := _find_player()
    if player == null: return
    var to_player: Vector3 = player.global_position - global_position
    to_player.y = 0
    var dist: float = to_player.length()
    if dist < sight_radius and not aggro:
        aggro = true
        EventBus.floating_text.emit("Coin or blood!", Vector2(global_position.x, global_position.z), Color(0.9, 0.7, 0.4))
    if not aggro: return
    var move_speed: float = stats.move_speed * (0.5 if slow_timer > 0.0 else 1.0)
    if dist > attack_range * 0.85:
        velocity = to_player.normalized() * move_speed
    else:
        velocity = Vector3.ZERO
        if attack_cooldown <= 0.0:
            _melee_attack(player)
            attack_cooldown = 0.7
    move_and_slide()
    if velocity.length() > 0.01:
        rotation.y = atan2(velocity.x, velocity.z)

func _melee_attack(player) -> void:
    if global_position.distance_to(player.global_position) < attack_range and player.has_method("take_damage"):
        player.take_damage(stats.damage, self)

func take_damage(amount: float, source, is_crit: bool = false) -> void:
    if stats.is_dead(): return
    # Parry: 20% chance to negate any non-crit hit
    if not is_crit and randf() < parry_chance:
        EventBus.floating_text.emit("PARRY", Vector2(global_position.x, global_position.z), Color(0.85, 0.85, 0.35))
        SfxBus.play("parry", -3.0)
        return
    stats.hp -= amount
    hit_flash = 0.08
    var color: Color = Color(1, 0.85, 0.2) if is_crit else Color(1, 1, 1)
    EventBus.floating_text.emit(("CRIT " if is_crit else "") + str(int(amount)),
        Vector2(global_position.x, global_position.z), color)
    if is_crit:
        VFX.spawn_crit_burst_3d(global_position + Vector3.UP, Color(1, 0.85, 0.2))
    else:
        VFX.spawn_hit_burst_3d(global_position + Vector3.UP, Color(1, 1, 1), 0.8)
    SfxBus.play("crit" if is_crit else "hit")
    EventBus.damage_dealt.emit(source, self, amount, is_crit)
    if stats.is_dead():
        _die(source)

func _die(source) -> void:
    EventBus.entity_killed.emit(self, source)
    if source != null and source.has_method("_has_hybrid") and source._has_hybrid("death_knight"):
        var ss: Object = source.stats
        if ss != null:
            ss.hp = min(float(ss.max_hp), float(ss.hp) + float(ss.max_hp) * 0.04)
    VFX.spawn_death_burst_3d(global_position + Vector3.UP * 0.5, Color(0.5, 0.3, 0.2))
    GameState.add_gold(randi_range(4, 14))
    RunState.run_kills += 1
    GameState.lifetime_kills += 1
    var player := _find_player()
    if player != null and player.has_method("gain_xp"):
        player.gain_xp(10.0 * RunState.enemy_scaling())
    if randf() < 0.65:
        var item: Dictionary = LootSystem.roll_item(-1, RunState.enemy_scaling() * 1.1)
        EventBus.loot_dropped.emit(item, Vector2(global_position.x, global_position.z))
    queue_free()

func _find_player() -> Node3D:
    var arr := get_tree().get_nodes_in_group("player")
    return arr[0] if not arr.is_empty() else null
