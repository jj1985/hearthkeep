extends CharacterBody3D

# Drake — flying elite, mid-boss before dragon floors.
# Pattern: hovers above the player; periodically dives for a melee strike,
# then climbs back to hover height. ~8x goblin HP, drops a guaranteed
# high-rarity item on death.

const CharacterStats := preload("res://scripts/entities/character_stats.gd")
const T := preload("res://scripts/ui/ui_tokens.gd")

@export var stats_scale: float = 1.0

enum State { HOVER, DIVE, RECOVER }

var stats: CharacterStats
var state: int = State.HOVER
var hover_h: float = 6.0
var hover_t: float = 0.0
var dive_target: Vector3 = Vector3.ZERO
var dive_cd: float = 0.0
var monster_id_value: String = "drake"

@onready var body_mesh: MeshInstance3D = $Body if has_node("Body") else null

func _ready() -> void:
    stats = CharacterStats.new()
    stats.max_hp = 200.0 * stats_scale
    stats.hp = stats.max_hp
    stats.damage = 22.0 * stats_scale
    stats.move_speed = 5.5
    stats.armor = 4.0
    add_to_group("enemy")
    add_to_group("elite")
    if body_mesh != null and body_mesh.material_override == null:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.40, 0.20, 0.18)
        mat.emission_enabled = true
        mat.emission = Color(0.60, 0.20, 0.10)
        mat.emission_energy_multiplier = 0.3
        body_mesh.material_override = mat
    EventBus.floating_text.emit("A DRAKE CIRCLES",
        Vector2(global_position.x, global_position.z), Color(1, 0.5, 0.3))

func monster_id() -> String:
    return monster_id_value

func _physics_process(delta: float) -> void:
    if stats.is_dead(): return
    hover_t += delta
    dive_cd = max(0.0, dive_cd - delta)
    var arr := get_tree().get_nodes_in_group("player")
    if arr.is_empty(): return
    var p: Node3D = arr[0]
    match state:
        State.HOVER:
            # Orbit above the player; small bobbing
            var target: Vector3 = p.global_position + Vector3(cos(hover_t * 0.6) * 4.0, hover_h + sin(hover_t * 1.4) * 0.4, sin(hover_t * 0.6) * 4.0)
            global_position = global_position.lerp(target, 0.04)
            if dive_cd <= 0.0:
                _begin_dive(p)
        State.DIVE:
            # Lerp toward dive_target; on contact deal damage and switch to RECOVER
            global_position = global_position.lerp(dive_target, 0.18)
            if global_position.distance_to(dive_target) < 0.6:
                if p.has_method("take_damage") and global_position.distance_to(p.global_position) < 2.4:
                    p.take_damage(stats.damage, self)
                    EventBus.screen_shake.emit(0.6, 0.25)
                state = State.RECOVER
        State.RECOVER:
            var up: Vector3 = global_position + Vector3(0, hover_h, 0)
            global_position = global_position.lerp(up, 0.10)
            if global_position.y > hover_h - 0.5:
                state = State.HOVER
                dive_cd = 4.0

func _begin_dive(p: Node3D) -> void:
    state = State.DIVE
    dive_target = p.global_position + Vector3.UP * 0.5
    EventBus.floating_text.emit("DIVE!", Vector2(p.global_position.x, p.global_position.z), Color(1, 0.5, 0.2))
    SfxBus.play("dragon_phase_air", -4.0)

func take_damage(amount: float, source, is_crit: bool = false) -> void:
    if stats.is_dead(): return
    stats.hp -= amount
    var color: Color = Color(1, 0.85, 0.2) if is_crit else Color(1, 1, 1)
    EventBus.floating_text.emit(("CRIT " if is_crit else "") + str(int(amount)),
        Vector2(global_position.x, global_position.z), color)
    if is_crit:
        VFX.spawn_crit_burst_3d(global_position + Vector3.UP, Color(1, 0.85, 0.2))
    else:
        VFX.spawn_hit_burst_3d(global_position + Vector3.UP, Color(1, 1, 1), 1.0)
    SfxBus.play("crit" if is_crit else "hit", -2.0)
    EventBus.damage_dealt.emit(source, self, amount, is_crit)
    if stats.is_dead():
        _die(source)

func _die(source) -> void:
    EventBus.entity_killed.emit(self, source)
    EventBus.floating_text.emit("DRAKE FELLED",
        Vector2(global_position.x, global_position.z), Color(1, 0.7, 0.3))
    VFX.spawn_death_burst_3d(global_position, Color(0.9, 0.4, 0.2))
    VFX.screen_shake(1.0, 0.4)
    VFX.hit_stop(0.12)
    GameState.add_gold(80)
    RunState.run_kills += 1
    GameState.lifetime_kills += 1
    if source != null and source.has_method("_has_hybrid") and source._has_hybrid("death_knight"):
        var ss: Object = source.stats
        if ss != null:
            ss.hp = min(float(ss.max_hp), float(ss.hp) + float(ss.max_hp) * 0.04)
    var player := _find_player()
    if player != null and player.has_method("gain_xp"):
        player.gain_xp(60.0 * RunState.enemy_scaling())
    # Guaranteed Epic+ drop
    var item: Dictionary = LootSystem.roll_item(3, RunState.enemy_scaling() * 1.3)
    EventBus.loot_dropped.emit(item, Vector2(global_position.x, global_position.z))
    # Drakes drop a rare dye 25% of the time (filter to rarity >= 2 colors)
    if randf() < 0.25:
        var rare_drop: String = DyeSystem.random_drop_color()
        DyeSystem.unlock_color(rare_drop)
        GameState.add_dye(rare_drop, 2)
        EventBus.floating_text.emit("DYE: " + rare_drop + " ×2", Vector2(global_position.x, global_position.z), Color(1, 0.7, 1))
    queue_free()

func _find_player() -> Node3D:
    var arr := get_tree().get_nodes_in_group("player")
    return arr[0] if not arr.is_empty() else null
