extends CharacterBody3D

# Krrik III — goblin warband king. One-shot floor-7 encounter (per run);
# tougher than a warchief, taller HP pool, telegraphed roar smash that
# AOEs around him, summons reinforcements at thresholds. Drop:
# warchief_crown trophy + ceremonial loot rain.

const CharacterStats := preload("res://scripts/entities/character_stats.gd")
const T := preload("res://scripts/ui/ui_tokens.gd")

@export var stats_scale: float = 1.0

var stats: CharacterStats
var attack_cooldown: float = 0.0
var roar_cooldown: float = 5.0
var summon_thresholds: Array[float] = [0.66, 0.33]
var thresholds_hit: int = 0
var aggro: bool = false
var monster_id_value: String = "krrik_iii"

@onready var body_mesh: MeshInstance3D = $Body if has_node("Body") else null

func _ready() -> void:
    stats = CharacterStats.new()
    stats.max_hp = 600.0 * stats_scale
    stats.hp = stats.max_hp
    stats.damage = 28.0 * stats_scale
    stats.move_speed = 4.5
    stats.armor = 6.0
    add_to_group("enemy")
    add_to_group("boss")
    EventBus.floating_text.emit("KRRIK  III  HEARS  YOU",
        Vector2(global_position.x, global_position.z), Color(1, 0.4, 0.3))
    SfxBus.play("dragon_roar", -2.0)

func monster_id() -> String:
    return monster_id_value

func _physics_process(delta: float) -> void:
    if stats.is_dead(): return
    attack_cooldown = max(0.0, attack_cooldown - delta)
    roar_cooldown = max(0.0, roar_cooldown - delta)
    var arr := get_tree().get_nodes_in_group("player")
    if arr.is_empty(): return
    var p: Node3D = arr[0]
    var to_player: Vector3 = p.global_position - global_position
    to_player.y = 0
    var dist: float = to_player.length()
    # HP-threshold reinforcement summons
    var hp_pct: float = stats.hp / max(1.0, stats.max_hp)
    while thresholds_hit < summon_thresholds.size() and hp_pct < summon_thresholds[thresholds_hit]:
        thresholds_hit += 1
        _summon_reinforcements()
    if dist > 16.0:
        velocity = to_player.normalized() * stats.move_speed
        move_and_slide()
        return
    if dist < 2.0 and attack_cooldown <= 0.0:
        _melee(p)
        attack_cooldown = 1.2
    if roar_cooldown <= 0.0 and dist < 14.0:
        _roar(p)
        roar_cooldown = 5.5
    velocity = to_player.normalized() * stats.move_speed * (0.6 if dist < 4.0 else 1.0)
    move_and_slide()
    if velocity.length() > 0.01:
        rotation.y = atan2(velocity.x, velocity.z)

func _melee(p: Node) -> void:
    if global_position.distance_to(p.global_position) < 2.4 and p.has_method("take_damage"):
        p.take_damage(stats.damage, self)
        EventBus.screen_shake.emit(0.5, 0.2)

func _roar(p: Node) -> void:
    EventBus.floating_text.emit("ROAR", global_position, Color(1, 0.4, 0.2))
    SfxBus.play("dragon_phase_enraged", -4.0)
    EventBus.screen_shake.emit(0.8, 0.4)
    if global_position.distance_to((p as Node3D).global_position) < 7.0 and p.has_method("take_damage"):
        p.take_damage(stats.damage * 0.8, self)

func _summon_reinforcements() -> void:
    EventBus.floating_text.emit("KRRIK CALLS HIS WARBAND",
        Vector2(global_position.x, global_position.z), Color(1, 0.7, 0.3))
    var goblin_scene := load("res://scenes/enemies/goblin.tscn") as PackedScene
    if goblin_scene == null: return
    for i in range(4):
        var ang: float = float(i) * TAU / 4.0
        var spawn_pos: Vector3 = global_position + Vector3(cos(ang) * 6.0, 0, sin(ang) * 6.0)
        var g := goblin_scene.instantiate()
        g.position = spawn_pos
        g.variant = i % 3    # mix skirmisher / sapper / shaman
        g.stats_scale = stats_scale * 0.8
        get_parent().add_child(g)

func take_damage(amount: float, source, is_crit: bool = false) -> void:
    if stats.is_dead(): return
    stats.hp -= amount
    var color: Color = Color(1, 0.85, 0.2) if is_crit else Color(1, 1, 1)
    EventBus.floating_text.emit(("CRIT " if is_crit else "") + str(int(amount)),
        Vector2(global_position.x, global_position.z), color)
    if is_crit:
        VFX.spawn_crit_burst_3d(global_position + Vector3.UP * 1.4, Color(1, 0.85, 0.2))
    else:
        VFX.spawn_hit_burst_3d(global_position + Vector3.UP * 1.4, Color(1, 1, 1), 1.4)
    SfxBus.play("crit" if is_crit else "hit_heavy", -2.0)
    EventBus.damage_dealt.emit(source, self, amount, is_crit)
    if stats.is_dead():
        _die(source)

func _die(source) -> void:
    EventBus.entity_killed.emit(self, source)
    EventBus.floating_text.emit("KRRIK  III  IS  DEAD",
        Vector2(global_position.x, global_position.z), Color(1, 0.85, 0.4))
    VFX.spawn_death_burst_3d(global_position, Color(0.85, 0.4, 0.2))
    VFX.screen_shake(1.4, 0.8)
    VFX.hit_stop(0.3)
    SfxBus.play("dragon_roar", 0.0)
    GameState.krrik_defeated = true
    GameState.add_gold(300)
    if source != null and source.has_method("_has_hybrid") and source._has_hybrid("death_knight"):
        var ss: Object = source.stats
        if ss != null:
            ss.hp = min(float(ss.max_hp), float(ss.hp) + float(ss.max_hp) * 0.04)
    # Award the warchief crown + ceremonial loot rain
    TrophyManager.award("warchief_crown")
    var player := _find_player()
    if player != null and player.has_method("gain_xp"):
        player.gain_xp(120.0 * RunState.enemy_scaling())
    for i in range(5):
        var ang: float = float(i) * TAU / 5.0
        var pos: Vector2 = Vector2(global_position.x + cos(ang) * 3.0, global_position.z + sin(ang) * 3.0)
        var item: Dictionary = LootSystem.roll_item(3 + (i % 2), RunState.enemy_scaling() * 1.4)
        EventBus.loot_dropped.emit(item, pos)
    SaveSystem.save()
    queue_free()

func _find_player() -> Node3D:
    var arr := get_tree().get_nodes_in_group("player")
    return arr[0] if not arr.is_empty() else null
