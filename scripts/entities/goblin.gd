extends CharacterBody3D

const CharacterStats := preload("res://scripts/entities/character_stats.gd")

enum VariantType { SKIRMISHER, SAPPER, SHAMAN, WARCHIEF }

const BARKS_AGGRO := {
    VariantType.SKIRMISHER: ["Yer guts is mine!", "RAAARGH!", "Push 'em down, cut 'em up!", "Smash you flat!"],
    VariantType.SAPPER: ["BOOM TIME!", "Tick tick BOOM!", "Hold the powder, lads!", "Light it!"],
    VariantType.SHAMAN: ["The drums tell us...", "Your bones will sing.", "Fall, soft-skin!", "Mine to the dirt!"],
    VariantType.WARCHIEF: ["I HAVE EATEN HEARTS LIKE YOURS.", "STAND AND DIE!", "The drums are for ME.", "BREAK 'IM."],
}
const BARKS_FLEE := ["Mercy! Mercy!", "Nope nope nope!", "Run! RUN!", "Not today!"]
const BARKS_RALLY := ["The shaman blesses us!", "STAND, BROTHERS!", "Drums tell us — STAND!"]

@export var variant: int = VariantType.SKIRMISHER
@export var stats_scale: float = 1.0

var stats: CharacterStats
var attack_cooldown: float = 0.0
var leash_distance: float = 24.0
var attack_range: float = 1.4
var sight_radius: float = 14.0
var aggro: bool = false
var hit_flash: float = 0.0
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var death_xp: float = 6.0
var gold_min: int = 1
var gold_max: int = 6
var loot_chance: float = 0.55
var dye_drop_chance: float = 0.05
var fleeing: bool = false
var rallied: bool = false
var bark_cooldown: float = 0.0
var environmental_oil: bool = false  # SAPPERs leave oil patches
var monster_id_value: String = "goblin"
var shaman_heal_cd: float = 0.0
var sapper_fuse_t: float = 0.0    # > 0 while fuse is lit but not yet detonated
var warchief_reinforced: bool = false

@onready var body_mesh: MeshInstance3D = $Body
@onready var head_mesh: MeshInstance3D = $Body/Head

func _ready() -> void:
    stats = CharacterStats.new()
    _config_for_variant()
    add_to_group("enemy")

func monster_id() -> String:
    return monster_id_value

func _config_for_variant() -> void:
    var hp_mod: float = WeatherSystem.enemy_aggro_mult()
    match variant:
        VariantType.SKIRMISHER:
            stats.max_hp = 22.0 * stats_scale
            stats.damage = 6.0 * stats_scale
            stats.move_speed = 4.0
            attack_range = 1.4
            _tint(Color(0.30, 0.55, 0.20))
            death_xp = 5.0
            gold_min = 1; gold_max = 5
            monster_id_value = "goblin"
        VariantType.SAPPER:
            stats.max_hp = 18.0 * stats_scale
            stats.damage = 14.0 * stats_scale
            stats.move_speed = 5.5
            attack_range = 1.0
            _tint(Color(0.65, 0.50, 0.10))
            death_xp = 7.0
            gold_min = 2; gold_max = 7
            environmental_oil = true
            monster_id_value = "goblin_sapper"
        VariantType.SHAMAN:
            stats.max_hp = 30.0 * stats_scale
            stats.damage = 5.0 * stats_scale
            stats.move_speed = 3.5
            attack_range = 8.0
            _tint(Color(0.45, 0.20, 0.55))
            death_xp = 9.0
            gold_min = 3; gold_max = 9
            loot_chance = 0.7
            monster_id_value = "goblin_shaman"
        VariantType.WARCHIEF:
            stats.max_hp = 220.0 * stats_scale
            stats.damage = 18.0 * stats_scale
            stats.move_speed = 3.0
            attack_range = 1.8
            _tint(Color(0.55, 0.10, 0.10))
            scale = Vector3(1.4, 1.4, 1.4)
            death_xp = 35.0
            gold_min = 18; gold_max = 45
            loot_chance = 1.0
            dye_drop_chance = 0.35
            monster_id_value = "goblin_warchief"
    stats.hp = stats.max_hp * hp_mod

func _tint(c: Color) -> void:
    if body_mesh != null:
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        m.roughness = 0.85
        body_mesh.material_override = m
    if head_mesh != null:
        var hm := StandardMaterial3D.new()
        hm.albedo_color = c.lightened(0.15)
        head_mesh.material_override = hm

func _physics_process(delta: float) -> void:
    if stats.is_dead():
        return
    attack_cooldown = max(0.0, attack_cooldown - delta)
    hit_flash = max(0.0, hit_flash - delta)
    stun_timer = max(0.0, stun_timer - delta)
    slow_timer = max(0.0, slow_timer - delta)
    bark_cooldown = max(0.0, bark_cooldown - delta)
    if burn_timer > 0.0:
        burn_timer -= delta
        stats.hp -= burn_dps * delta
        if stats.is_dead():
            _die(null); return
    if stun_timer > 0.0:
        velocity = Vector3.ZERO
        move_and_slide()
        return

    var player := _find_player()
    if player == null:
        return
    var to_player: Vector3 = player.global_position - global_position
    to_player.y = 0
    var dist: float = to_player.length()

    if dist < sight_radius * WeatherSystem.enemy_aggro_mult():
        if not aggro:
            aggro = true
            _bark(BARKS_AGGRO[variant])

    if not aggro:
        return

    # Flee at low HP unless rallied or warchief.
    var hp_pct: float = stats.hp / max(1.0, stats.max_hp)
    if hp_pct < 0.25 and variant != VariantType.WARCHIEF and not rallied:
        if not fleeing:
            fleeing = true
            _bark(BARKS_FLEE)
    elif fleeing and hp_pct > 0.45:
        fleeing = false

    # Shaman: rallies fleeing allies AND heals wounded allies on a cooldown.
    if variant == VariantType.SHAMAN:
        shaman_heal_cd = max(0.0, shaman_heal_cd - delta)
        for e in get_tree().get_nodes_in_group("enemy"):
            if e == self or not is_instance_valid(e): continue
            var n: Node3D = e as Node3D
            if n == null: continue
            if global_position.distance_to(n.global_position) < 6.0:
                if (e as Object).has_method("rally"):
                    (e as Object).call("rally")
                if shaman_heal_cd <= 0.0:
                    var ally_stats: Variant = (e as Object).get("stats")
                    if ally_stats != null and float(ally_stats.hp) < float(ally_stats.max_hp):
                        ally_stats.hp = min(float(ally_stats.max_hp), float(ally_stats.hp) + 12.0)
                        EventBus.floating_text.emit("+12", n.global_position, Color(0.55, 0.85, 0.55))
                        shaman_heal_cd = 4.0
        # Heal self last
        if shaman_heal_cd <= 0.0 and stats.hp < stats.max_hp:
            stats.hp = min(stats.max_hp, stats.hp + 8.0)
            EventBus.floating_text.emit("+8", global_position, Color(0.55, 0.85, 0.55))
            shaman_heal_cd = 4.0

    # Warchief: at <50% HP, calls reinforcements once.
    if variant == VariantType.WARCHIEF and not warchief_reinforced:
        if stats.hp < stats.max_hp * 0.5:
            _warchief_call_reinforcements()
            warchief_reinforced = true

    var move_speed: float = stats.move_speed * (0.5 if slow_timer > 0.0 else 1.0)
    if fleeing:
        velocity = -to_player.normalized() * move_speed * 1.1
    elif variant == VariantType.SHAMAN:
        if dist < 6.0:
            velocity = -to_player.normalized() * move_speed
        elif dist > 9.0:
            velocity = to_player.normalized() * move_speed * 0.7
        else:
            velocity = Vector3.ZERO
        if attack_cooldown <= 0.0 and dist < attack_range:
            _shaman_cast(player); attack_cooldown = 2.4
    elif variant == VariantType.SAPPER:
        velocity = to_player.normalized() * move_speed
        # Visible fuse telegraph: when player is in detonation range,
        # start a 1.0s fuse that visually blinks before _explode fires.
        if dist < attack_range + 0.6 and sapper_fuse_t <= 0.0 and attack_cooldown <= 0.0:
            sapper_fuse_t = 1.0
            EventBus.floating_text.emit("FUSE!", global_position, Color(1, 0.5, 0))
        if sapper_fuse_t > 0.0:
            sapper_fuse_t -= delta
            # Blink the body's emission as the fuse counts down
            if body_mesh != null and body_mesh.material_override != null:
                var blink: float = 0.5 + 0.5 * sin(sapper_fuse_t * 32.0)
                var m := body_mesh.material_override as StandardMaterial3D
                m.emission_enabled = true
                m.emission = Color(1.0, 0.5 * blink, 0.1)
                m.emission_energy_multiplier = 1.5 + 2.0 * (1.0 - sapper_fuse_t)
            if sapper_fuse_t <= 0.0:
                _explode(player)
    else:
        if dist > attack_range * 0.85:
            velocity = to_player.normalized() * move_speed
        else:
            velocity = Vector3.ZERO
            if attack_cooldown <= 0.0:
                _melee_attack(player)
                attack_cooldown = 1.0

    move_and_slide()
    if facing_dir().length() > 0.01:
        rotation.y = atan2(velocity.x, velocity.z)
    if hit_flash > 0.0 and body_mesh != null and body_mesh.material_override != null:
        (body_mesh.material_override as StandardMaterial3D).emission_enabled = true
        (body_mesh.material_override as StandardMaterial3D).emission = Color.WHITE
        (body_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 1.5
    elif body_mesh != null and body_mesh.material_override != null:
        (body_mesh.material_override as StandardMaterial3D).emission_enabled = false

func facing_dir() -> Vector3:
    return velocity

func rally() -> void:
    if not rallied:
        rallied = true
        fleeing = false
        _bark(BARKS_RALLY)

func _bark(pool: Array) -> void:
    if bark_cooldown > 0.0 or pool.is_empty(): return
    if not Settings.subtitle_barks: return
    bark_cooldown = 4.0
    var line: String = pool[randi() % pool.size()]
    EventBus.floating_text.emit(line, Vector2(global_position.x, global_position.z), Color(1, 0.85, 0.6))

func _melee_attack(player) -> void:
    if global_position.distance_to(player.global_position) <= attack_range + 0.5:
        if player.has_method("take_damage"):
            player.take_damage(stats.damage, self)

func _shaman_cast(player) -> void:
    EventBus.floating_text.emit("BOLT", Vector2(global_position.x, global_position.z), Color(0.7, 0.4, 1.0))
    VFX.spawn_hit_burst_3d(global_position + Vector3.UP * 1.0, Color(0.65, 0.25, 0.85), 1.0)
    if global_position.distance_to(player.global_position) < 10.0:
        if player.has_method("take_damage"):
            player.take_damage(stats.damage * 0.9, self)

func _warchief_call_reinforcements() -> void:
    EventBus.floating_text.emit("REINFORCE!", global_position, Color(1, 0.4, 0.3))
    SfxBus.play("dragon_roar", -8.0)
    var spawned := 0
    for arr in [VariantType.SKIRMISHER, VariantType.SAPPER, VariantType.SKIRMISHER]:
        var ang: float = randf() * TAU
        var spawn_pos: Vector3 = global_position + Vector3(cos(ang) * 6.0, 0, sin(ang) * 6.0)
        var g := load("res://scenes/enemies/goblin.tscn") as PackedScene
        if g == null: break
        var inst := g.instantiate()
        inst.position = spawn_pos
        inst.variant = arr
        inst.stats_scale = stats_scale
        get_parent().add_child(inst)
        spawned += 1
    EventBus.floating_text.emit("+%d  reinforcements" % spawned, global_position, Color(1, 0.6, 0.3))

func _explode(player) -> void:
    EventBus.floating_text.emit("BOOM", Vector2(global_position.x, global_position.z), Color(1, 0.5, 0))
    VFX.spawn_death_burst_3d(global_position, Color(1, 0.5, 0.1))
    VFX.screen_shake(8.0, 0.25)
    if global_position.distance_to(player.global_position) < 2.5:
        if player.has_method("take_damage"):
            player.take_damage(stats.damage * 1.4, self)
    stats.hp = 0.0
    _die(player)

func take_damage(amount: float, source, is_crit: bool = false) -> void:
    if stats.is_dead(): return
    stats.hp -= amount
    hit_flash = 0.08
    var color: Color = Color(1, 0.85, 0.2) if is_crit else Color(1, 1, 1)
    EventBus.floating_text.emit(("CRIT " if is_crit else "") + str(int(amount)), Vector2(global_position.x, global_position.z), color)
    # Damage-scaled hit-stop: bigger hits freeze longer; crits get the
    # spec'd 80 ms freeze. Per design pillars: every hit feels chunky,
    # crits feel ceremonial.
    var dmg_mag: float = clampf(amount / max(1.0, stats.max_hp), 0.0, 1.0)
    if is_crit:
        VFX.spawn_crit_burst_3d(global_position + Vector3.UP, Color(1, 0.85, 0.2))
        VFX.hit_stop(0.08)
        VFX.screen_shake(0.6 + dmg_mag * 0.4, 0.18)
        SfxBus.play("crit", -2.0)
    else:
        VFX.spawn_hit_burst_3d(global_position + Vector3.UP, Color(1, 1, 1), 0.8)
        # Light hit-stop scales with damage magnitude (capped at 50 ms)
        VFX.hit_stop(min(0.05, 0.02 + dmg_mag * 0.06))
        VFX.screen_shake(0.18 + dmg_mag * 0.2, 0.08 + dmg_mag * 0.06)
        SfxBus.play("hit_heavy" if dmg_mag > 0.20 else "hit", -4.0)
    EventBus.damage_dealt.emit(source, self, amount, is_crit)
    if RunState.fire_dot_chance > 0.0 and randf() < RunState.fire_dot_chance:
        burn_timer = 3.0
        burn_dps = max(burn_dps, amount * 0.20)
    if RunState.frost_slow_chance > 0.0 and randf() < RunState.frost_slow_chance:
        slow_timer = 2.0
    if RunState.lightning_chain_chance > 0.0 and randf() < RunState.lightning_chain_chance:
        _lightning_chain()
    if BuffSystem.has_weapon_element("fire"):
        burn_timer = 2.0
        burn_dps = max(burn_dps, amount * 0.15)
    if BuffSystem.has_weapon_element("frost"):
        slow_timer = 1.5
    var player_obj := _find_player()
    if player_obj != null and RunState.lifesteal_pct > 0.0 and source == player_obj:
        if "stats" in player_obj:
            var heal_amt: float = amount * RunState.lifesteal_pct
            var p_stats: Object = (player_obj as Object).stats
            var prev_hp: float = float(p_stats.hp)
            p_stats.hp = min(float(p_stats.max_hp), prev_hp + heal_amt)
            var actual_heal: float = float(p_stats.hp) - prev_hp
            if actual_heal > 0.5:
                EventBus.floating_text.emit("+%d" % int(round(actual_heal)),
                    Vector2((player_obj as Node3D).global_position.x, (player_obj as Node3D).global_position.z),
                    Color(0.55, 0.85, 0.55))
    if stats.is_dead():
        _die(source)

func _lightning_chain() -> void:
    var enemies: Array = get_tree().get_nodes_in_group("enemy")
    var nearest = null
    var best := 6.0
    for e in enemies:
        if e == self or not is_instance_valid(e): continue
        var d: float = global_position.distance_to((e as Node3D).global_position)
        if d < best:
            best = d
            nearest = e
    if nearest != null:
        VFX.spawn_arc_3d(global_position, (nearest as Node3D).global_position)
        if nearest.has_method("take_damage"):
            nearest.take_damage(8.0 + 4.0 * RunState.enemy_scaling(), self, false)

func _die(source) -> void:
    if not is_instance_valid(self): return
    EventBus.entity_killed.emit(self, source)
    # Death Knight hybrid: killing an enemy heals 4% max HP.
    if source != null and source.has_method("_has_hybrid") and source._has_hybrid("death_knight"):
        var ss: Object = source.stats
        if ss != null:
            var heal: float = float(ss.max_hp) * 0.04
            ss.hp = min(float(ss.max_hp), float(ss.hp) + heal)
            EventBus.floating_text.emit("+%d (Death Knight)" % int(round(heal)),
                Vector2((source as Node3D).global_position.x, (source as Node3D).global_position.z),
                Color(0.6, 0.4, 0.85))
    VFX.spawn_death_burst_3d(global_position + Vector3.UP * 0.5, Color(0.7, 0.2, 0.2))
    # Death feels chunky regardless of variant. Warchief gets a longer
    # ceremonial freeze + roar.
    if variant == VariantType.WARCHIEF:
        VFX.hit_stop(0.18)
        VFX.screen_shake(1.4, 0.55)
        SfxBus.play("dragon_roar", -4.0)
    else:
        VFX.hit_stop(0.06)
        VFX.screen_shake(0.45, 0.18)
    var gold := randi_range(gold_min, gold_max)
    GameState.add_gold(gold)
    RunState.run_gold += gold
    RunState.run_kills += 1
    GameState.lifetime_kills += 1
    var player := _find_player()
    if player != null and player.has_method("gain_xp"):
        player.gain_xp(death_xp * RunState.enemy_scaling())
    if randf() < loot_chance:
        var item: Dictionary = LootSystem.roll_item(-1, RunState.enemy_scaling())
        EventBus.loot_dropped.emit(item, Vector2(global_position.x, global_position.z))
        if item["rarity"] >= LootSystem.Rarity.LEGENDARY:
            RunState.run_legendaries += 1
            GameState.lifetime_legendaries += 1
    if randf() < 0.4:
        # Vendor trash drop
        var trash: Dictionary = VendorSystem.roll_vendor_trash(RunState.enemy_scaling(), RunState.floor_index)
        if not trash.is_empty():
            EventBus.loot_dropped.emit(trash, Vector2(global_position.x, global_position.z))
    if randf() < dye_drop_chance:
        var color_id: String = DyeSystem.random_drop_color()
        DyeSystem.unlock_color(color_id)
        GameState.add_dye(color_id, 1)
        EventBus.floating_text.emit("DYE: " + color_id, Vector2(global_position.x, global_position.z), Color(1, 0.7, 1))
    queue_free()

func _find_player() -> Node3D:
    var nodes := get_tree().get_nodes_in_group("player")
    if nodes.is_empty():
        return null
    return nodes[0] as Node3D
