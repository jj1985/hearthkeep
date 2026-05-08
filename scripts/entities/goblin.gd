extends CharacterBody2D

const CharacterStats := preload("res://scripts/entities/character_stats.gd")

enum Variant { SKIRMISHER, SAPPER, SHAMAN, WARCHIEF }

@export var variant: int = Variant.SKIRMISHER
@export var stats_scale: float = 1.0

var stats: CharacterStats
var attack_cooldown: float = 0.0
var leash_distance: float = 480.0
var attack_range: float = 28.0
var sight_radius: float = 320.0
var aggro: bool = false
var hit_flash: float = 0.0
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var dot_timer: float = 0.0
var dot_dps: float = 0.0
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var death_xp: float = 6.0
var gold_min: int = 1
var gold_max: int = 6
var loot_chance: float = 0.55
var dye_drop_chance: float = 0.05

@onready var sprite: Polygon2D = $Body
@onready var hp_bar: ColorRect = $HpBar

func _ready() -> void:
    stats = CharacterStats.new()
    _config_for_variant()
    add_to_group("enemy")
    z_index = 4

func _config_for_variant() -> void:
    match variant:
        Variant.SKIRMISHER:
            stats.max_hp = 22.0 * stats_scale
            stats.damage = 6.0 * stats_scale
            stats.move_speed = 130.0
            attack_range = 30.0
            sprite.color = Color(0.30, 0.55, 0.20)
            death_xp = 5.0
            gold_min = 1
            gold_max = 5
        Variant.SAPPER:
            stats.max_hp = 18.0 * stats_scale
            stats.damage = 14.0 * stats_scale
            stats.move_speed = 170.0
            attack_range = 22.0
            sprite.color = Color(0.65, 0.50, 0.10)
            death_xp = 7.0
            gold_min = 2
            gold_max = 7
        Variant.SHAMAN:
            stats.max_hp = 30.0 * stats_scale
            stats.damage = 5.0 * stats_scale
            stats.move_speed = 110.0
            attack_range = 240.0
            sprite.color = Color(0.45, 0.20, 0.55)
            death_xp = 9.0
            gold_min = 3
            gold_max = 9
            loot_chance = 0.7
        Variant.WARCHIEF:
            stats.max_hp = 220.0 * stats_scale
            stats.damage = 18.0 * stats_scale
            stats.move_speed = 100.0
            attack_range = 38.0
            sprite.color = Color(0.55, 0.10, 0.10)
            sprite.scale = Vector2(1.6, 1.6)
            death_xp = 35.0
            gold_min = 18
            gold_max = 45
            loot_chance = 1.0
            dye_drop_chance = 0.35
    stats.hp = stats.max_hp

func _physics_process(delta: float) -> void:
    if stats.is_dead():
        return
    attack_cooldown = max(0.0, attack_cooldown - delta)
    hit_flash = max(0.0, hit_flash - delta)
    stun_timer = max(0.0, stun_timer - delta)
    slow_timer = max(0.0, slow_timer - delta)
    if burn_timer > 0.0:
        burn_timer -= delta
        stats.hp -= burn_dps * delta
        if int(burn_timer * 6.0) % 2 == 0:
            EventBus.floating_text.emit(str(int(burn_dps * 0.3)), global_position + Vector2(randf_range(-12,12), -28), Color(1, 0.45, 0.1))
        if stats.is_dead():
            _die(null)
            return
    if dot_timer > 0.0:
        dot_timer -= delta
        stats.hp -= dot_dps * delta
        if stats.is_dead():
            _die(null)
            return

    if stun_timer > 0.0:
        velocity = Vector2.ZERO
        sprite.modulate = Color(0.7, 0.7, 1.0)
        move_and_slide()
        return

    var player := _find_player()
    if player == null:
        return
    var to_player: Vector2 = player.global_position - global_position
    var dist: float = to_player.length()
    if dist < sight_radius:
        aggro = true
    if not aggro:
        return

    var move_speed: float = stats.move_speed * (0.5 if slow_timer > 0.0 else 1.0)
    if variant == Variant.SHAMAN:
        if dist < 200.0:
            velocity = -to_player.normalized() * move_speed
        elif dist > 260.0:
            velocity = to_player.normalized() * move_speed * 0.6
        else:
            velocity = Vector2.ZERO
        if attack_cooldown <= 0.0 and dist < attack_range:
            _shaman_cast(player)
            attack_cooldown = 2.4
    elif variant == Variant.SAPPER:
        velocity = to_player.normalized() * move_speed
        if dist < attack_range and attack_cooldown <= 0.0:
            _explode(player)
    else:
        if dist > attack_range * 0.85:
            velocity = to_player.normalized() * move_speed
        else:
            velocity = Vector2.ZERO
            if attack_cooldown <= 0.0:
                _melee_attack(player)
                attack_cooldown = 1.0

    if hit_flash > 0.0:
        sprite.modulate = Color(1.5, 1.5, 1.5)
    elif slow_timer > 0.0:
        sprite.modulate = Color(0.5, 0.7, 1.2)
    else:
        sprite.modulate = Color.WHITE

    move_and_slide()
    _update_hp_bar()

func _melee_attack(player) -> void:
    if global_position.distance_to(player.global_position) <= attack_range + 6.0:
        if player.has_method("take_damage"):
            player.take_damage(stats.damage, self)

func _shaman_cast(player) -> void:
    EventBus.floating_text.emit("BOLT", global_position + Vector2(0, -28), Color(0.7, 0.4, 1.0))
    VFX.spawn_hit_burst(global_position, Color(0.65, 0.25, 0.85), 1.0)
    if global_position.distance_to(player.global_position) < 320.0:
        if player.has_method("take_damage"):
            player.take_damage(stats.damage * 0.9, self)

func _explode(player) -> void:
    EventBus.floating_text.emit("BOOM", global_position + Vector2(0, -28), Color(1, 0.5, 0))
    VFX.spawn_death_burst(global_position, Color(1, 0.5, 0.1))
    VFX.screen_shake(8.0, 0.25)
    if global_position.distance_to(player.global_position) < 64.0:
        if player.has_method("take_damage"):
            player.take_damage(stats.damage * 1.4, self)
    stats.hp = 0.0
    _die(player)

func take_damage(amount: float, source, is_crit: bool = false) -> void:
    if stats.is_dead():
        return
    stats.hp -= amount
    hit_flash = 0.08
    var color: Color = Color(1, 0.85, 0.2) if is_crit else Color(1, 1, 1)
    EventBus.floating_text.emit(("CRIT " if is_crit else "") + str(int(amount)), global_position + Vector2(randf_range(-10,10), -28), color)
    if is_crit:
        VFX.spawn_crit_burst(global_position, Color(1, 0.85, 0.2))
    else:
        VFX.spawn_hit_burst(global_position, Color(1, 1, 1), 0.8)
    SfxBus.play("crit" if is_crit else "hit")
    EventBus.damage_dealt.emit(source, self, amount, is_crit)
    if RunState.fire_dot_chance > 0.0 and randf() < RunState.fire_dot_chance:
        burn_timer = 3.0
        burn_dps = max(burn_dps, amount * 0.20)
    if RunState.frost_slow_chance > 0.0 and randf() < RunState.frost_slow_chance:
        slow_timer = 2.0
    if RunState.lightning_chain_chance > 0.0 and randf() < RunState.lightning_chain_chance:
        _lightning_chain()
    var player_obj := _find_player()
    if player_obj != null and RunState.lifesteal_pct > 0.0 and source == player_obj:
        if player_obj.has_method("get") and player_obj.stats != null:
            player_obj.stats.hp = min(player_obj.stats.max_hp, player_obj.stats.hp + amount * RunState.lifesteal_pct)
    if stats.is_dead():
        _die(source)

func _lightning_chain() -> void:
    var enemies: Array = get_tree().get_nodes_in_group("enemy")
    var nearest = null
    var best := 220.0
    for e in enemies:
        if e == self or not is_instance_valid(e): continue
        var d: float = global_position.distance_to(e.global_position)
        if d < best:
            best = d
            nearest = e
    if nearest != null:
        VFX.spawn_arc_discharge(global_position, nearest.global_position)
        if nearest.has_method("take_damage"):
            nearest.take_damage(8.0 + 4.0 * RunState.enemy_scaling(), self, false)

func _die(source) -> void:
    if not is_instance_valid(self): return
    EventBus.entity_killed.emit(self, source)
    VFX.spawn_death_burst(global_position, Color(0.7, 0.2, 0.2))
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
        EventBus.loot_dropped.emit(item, global_position)
        if item["rarity"] >= LootSystem.Rarity.LEGENDARY:
            RunState.run_legendaries += 1
            GameState.lifetime_legendaries += 1
    if randf() < dye_drop_chance:
        var color_id: String = DyeSystem.random_drop_color()
        DyeSystem.unlock_color(color_id)
        GameState.add_dye(color_id, 1)
        EventBus.floating_text.emit("DYE: " + color_id, global_position + Vector2(0, -52), Color(1, 0.7, 1))
    queue_free()

func _update_hp_bar() -> void:
    var pct: float = stats.hp / max(1.0, stats.max_hp)
    hp_bar.scale.x = clamp(pct, 0.0, 1.0)
    hp_bar.color = Color(1.0 - pct, pct, 0.1)

func _find_player() -> Node2D:
    var nodes := get_tree().get_nodes_in_group("player")
    if nodes.is_empty():
        return null
    return nodes[0] as Node2D
