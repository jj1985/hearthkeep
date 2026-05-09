extends Node3D

# 3D run runner: spawns player + goblins, manages camera, dispatches HUD.

const PlayerScene := preload("res://scenes/player/player.tscn")
const GoblinScene := preload("res://scenes/enemies/goblin.tscn")
const LootScene := preload("res://scenes/fx/loot_drop.tscn")

@onready var player_layer: Node3D = $World/PlayerLayer
@onready var enemy_layer: Node3D = $World/EnemyLayer
@onready var loot_layer: Node3D = $World/LootLayer
@onready var camera: Camera3D = $World/Cam
@onready var sun: DirectionalLight3D = $World/Sun
@onready var torch_left: OmniLight3D = $World/TorchL
@onready var torch_right: OmniLight3D = $World/TorchR
@onready var hud_layer: CanvasLayer = $HUD
@onready var perk_overlay: CanvasLayer = $PerkOverlay
@onready var perk_root: Control = $PerkOverlay/Root

var player: CharacterBody3D
var room_index: int = 0
var camera_shake_t: float = 0.0
var camera_shake_strength: float = 0.0
var spawn_pacing_timer: float = 0.0
var floor_kill_target: int = 12
var pause_for_levelup: bool = false

func _ready() -> void:
    SaveSystem.load_save()
    Settings.load_settings()
    RunState.start_run(randi())
    BuffSystem.clear_run_buffs()
    Inventory.reset_for_run()
    WorldSim.enter_run()
    EventBus.player_died.connect(_on_player_died)
    EventBus.loot_dropped.connect(_on_loot_dropped)
    EventBus.screen_shake.connect(_on_screen_shake)
    EventBus.hit_stop.connect(_on_hit_stop)
    EventBus.day_night_phase_changed.connect(_on_phase_changed)
    RunState.level_up_pending.connect(_on_level_up_pending)
    QuestSystem.start("main_ch1_iron_tide")
    _spawn_player()
    _enter_room()
    MusicDirector.set_layer(MusicDirector.Layer.EXPLORATION)
    if not Settings.tutorial_seen:
        var tut_ps: PackedScene = load("res://scenes/ui/tutorial_overlay.tscn")
        if tut_ps != null:
            var tut := tut_ps.instantiate()
            var layer := CanvasLayer.new()
            layer.layer = 95
            layer.add_child(tut)
            add_child(layer)
            get_tree().paused = true
            tut.tree_exiting.connect(func():
                if is_instance_valid(layer):
                    layer.queue_free())
    # First-30-seconds hook: dragon roar + flyover-shadow-implied via SFX,
    # then a goblin charges. Real cinematic comes in a polish pass.
    SfxBus.play("dragon_roar", -4.0)
    EventBus.floating_text.emit("Dragon shadow over the keep!", Vector2(0, 0), Color(1, 0.6, 0.3))
    await get_tree().create_timer(1.5).timeout
    _spawn_goblin(_random_spawn_pos(), VariantType_SKIRMISHER)
    # Offer first perk shortly so the level-up loop teaches itself.
    await get_tree().create_timer(2.0).timeout
    if not pause_for_levelup:
        _on_level_up_pending(1)

const VariantType_SKIRMISHER := 0  # mirror of goblin VariantType.SKIRMISHER

func _process(delta: float) -> void:
    RunState.run_time += delta
    if Input.is_action_just_pressed("quest_log"):
        _open_journal_overlay()
        return
    if camera_shake_t > 0.0:
        camera_shake_t = max(0.0, camera_shake_t - delta)
        camera.h_offset = randf_range(-camera_shake_strength, camera_shake_strength) * 0.04
        camera.v_offset = randf_range(-camera_shake_strength, camera_shake_strength) * 0.04
        if camera_shake_t == 0.0:
            camera.h_offset = 0.0
            camera.v_offset = 0.0
    if player != null and is_instance_valid(player):
        var lookahead: Vector3 = (player.move_dir as Vector3).normalized() * 1.6
        var target: Vector3 = player.global_position + Vector3(lookahead.x, 0, lookahead.z)
        camera.position = camera.position.lerp(target + Vector3(8.0, 12.0, 8.0), 0.07)
        camera.look_at(target + Vector3.UP, Vector3.UP)
    spawn_pacing_timer -= delta
    if spawn_pacing_timer <= 0.0:
        spawn_pacing_timer = 1.6
        _maybe_spawn_wave()
    if RunState.run_kills - (room_index * floor_kill_target) >= floor_kill_target:
        _next_room()

func _spawn_player() -> void:
    player = PlayerScene.instantiate()
    player.class_primary = RunState.class_primary
    player.class_secondary = RunState.class_secondary
    player.position = Vector3(0, 0, 0)
    player_layer.add_child(player)
    var hybrid: Dictionary = RunState.hybrid_prestige()
    if not hybrid.is_empty():
        EventBus.floating_text.emit("✦ %s ✦" % hybrid.get("name", ""), Vector2(0, 0), Color(1, 0.7, 0.3))

func _enter_room() -> void:
    floor_kill_target = 10 + RunState.floor_index * 4
    if RunState.floor_index > 0:
        EventBus.floating_text.emit("FLOOR " + str(RunState.floor_index + 1), Vector2(player.global_position.x, player.global_position.z), Color(1, 0.8, 0.3))
    for i in range(5 + RunState.floor_index):
        _spawn_goblin(_random_spawn_pos(), randi() % 3)

func _maybe_spawn_wave() -> void:
    if player == null or not is_instance_valid(player):
        return
    var alive: int = enemy_layer.get_child_count()
    var cap: int = 8 + RunState.floor_index * 3 + RunState.player_level
    if alive >= cap:
        return
    var n: int = int(clamp(2 + RunState.floor_index, 1, 6))
    for i in range(n):
        var roll: int = randi() % 100
        var v: int = 0
        if roll > 95 and RunState.floor_index >= 2:
            v = 3
        elif roll > 78:
            v = 2
        elif roll > 55:
            v = 1
        else:
            v = 0
        _spawn_goblin(_random_spawn_pos(), v)
    if MusicDirector.current_layer < MusicDirector.Layer.COMBAT:
        MusicDirector.cue_combat(true)

func _spawn_goblin(pos: Vector3, v: int) -> void:
    var g = GoblinScene.instantiate()
    g.position = pos
    g.variant = v
    g.stats_scale = RunState.enemy_scaling()
    enemy_layer.add_child(g)

func _random_spawn_pos() -> Vector3:
    if player == null or not is_instance_valid(player):
        return Vector3(6, 0, 0)
    var ang: float = randf() * TAU
    var r: float = randf_range(8.0, 14.0)
    return player.global_position + Vector3(cos(ang) * r, 0, sin(ang) * r)

func _next_room() -> void:
    room_index += 1
    RunState.floor_index = room_index
    GameState.deepest_floor = max(GameState.deepest_floor, RunState.floor_index)
    # Boss floor every 5: switch to a dragon arena scene.
    if (RunState.floor_index + 1) % 5 == 0:
        var next_d: String = _next_dragon_to_fight()
        if next_d != "":
            RunState.boss_dragon_id = next_d
            EventBus.floating_text.emit("A SHADOW OVER THE WASTES…",
                Vector2(player.global_position.x, player.global_position.z), Color(1, 0.5, 0.3))
            await get_tree().create_timer(1.4).timeout
            get_tree().change_scene_to_file("res://scenes/boss/vyxhasis_arena.tscn")
            return
    _enter_room()

func _next_dragon_to_fight() -> String:
    for d in ["vyxhasis", "ourzhal", "aethyrnax"]:
        if not GameState.defeated_dragons.has(d):
            return d
    # All three defeated — cycle through repeatable replays
    var roster := ["vyxhasis", "ourzhal", "aethyrnax"]
    return roster[(RunState.floor_index / 5) % roster.size()]

func _on_loot_dropped(item: Dictionary, pos: Variant) -> void:
    var l = LootScene.instantiate()
    var p2: Vector2 = pos as Vector2
    l.position = Vector3(p2.x, 0, p2.y)
    l.item = item
    loot_layer.add_child(l)

func _on_screen_shake(strength: float, duration: float) -> void:
    camera_shake_strength = max(camera_shake_strength, strength)
    camera_shake_t = max(camera_shake_t, duration)

func _on_hit_stop(duration: float) -> void:
    Engine.time_scale = 0.05
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0

func _on_phase_changed(phase: int) -> void:
    var c: Color = WorldSim.phase_color()
    sun.light_color = c
    sun.light_energy = 0.4 if phase == WorldSim.Phase.NIGHT else 1.0
    # Sky + fog tint per phase + weather. Pulls the WorldEnv from the run scene.
    var world_env: WorldEnvironment = $World/WorldEnv if has_node("World/WorldEnv") else null
    if world_env == null or world_env.environment == null:
        return
    var env: Environment = world_env.environment
    var sky_top: Color
    var sky_horizon: Color
    var fog: Color
    match phase:
        WorldSim.Phase.DAWN:
            sky_top = Color(0.30, 0.20, 0.30)
            sky_horizon = Color(0.95, 0.55, 0.40)
            fog = Color(0.80, 0.50, 0.40)
        WorldSim.Phase.DUSK:
            sky_top = Color(0.20, 0.15, 0.25)
            sky_horizon = Color(0.75, 0.30, 0.20)
            fog = Color(0.55, 0.20, 0.18)
        WorldSim.Phase.NIGHT:
            sky_top = Color(0.04, 0.03, 0.10)
            sky_horizon = Color(0.10, 0.08, 0.18)
            fog = Color(0.12, 0.10, 0.20)
        _:    # DAY
            sky_top = Color(0.20, 0.30, 0.50)
            sky_horizon = Color(0.55, 0.65, 0.85)
            fog = Color(0.35, 0.30, 0.40)
    # Weather modifiers — fog density bumps in fog/storm/rain
    var fog_density: float = 0.012
    if Engine.has_singleton("WeatherSystem"):
        match WeatherSystem.current:
            WeatherSystem.Weather.FOG:    fog_density = 0.040
            WeatherSystem.Weather.STORM:  fog_density = 0.028
            WeatherSystem.Weather.RAIN:   fog_density = 0.020
            WeatherSystem.Weather.ASHFALL:
                fog_density = 0.035
                fog = fog.lerp(Color(0.30, 0.18, 0.12), 0.6)
            _: pass
    env.fog_density = fog_density
    env.fog_light_color = fog
    var sky_mat: Resource = env.sky.sky_material if env.sky != null else null
    if sky_mat is ProceduralSkyMaterial:
        var pm: ProceduralSkyMaterial = sky_mat
        pm.sky_top_color = sky_top
        pm.sky_horizon_color = sky_horizon

func _on_level_up_pending(_lvl: int) -> void:
    if pause_for_levelup:
        return
    pause_for_levelup = true
    get_tree().paused = true
    perk_overlay.visible = true
    SfxBus.play("levelup")
    if player != null:
        VFX.spawn_levelup_flare_3d(player.global_position)
    var ws_tags: Array = []
    if player != null:
        ws_tags = player.equipped_weapon_tags()
    var offers: Array = PerkPool.draw_offer(player.class_primary, player.class_secondary, 4, ws_tags)
    perk_root.show_offers(offers, _on_perk_picked)

func _on_perk_picked(perk: Dictionary) -> void:
    PerkPool.apply_perk(perk)
    perk_overlay.visible = false
    get_tree().paused = false
    pause_for_levelup = false
    if RunState.pending_level_ups > 0:
        RunState.pending_level_ups -= 1
        if RunState.pending_level_ups > 0:
            _on_level_up_pending(RunState.player_level)

var _journal_overlay: Node = null

func _open_journal_overlay() -> void:
    if _journal_overlay != null and is_instance_valid(_journal_overlay):
        return
    var ps: PackedScene = load("res://scenes/ui/journal.tscn")
    if ps == null:
        return
    _journal_overlay = ps.instantiate()
    _journal_overlay.process_mode = Node.PROCESS_MODE_ALWAYS    # tick while paused
    var close_btn := _journal_overlay.get_node_or_null("SafeArea/V/Footer/Close")
    if close_btn != null:
        # Disconnect default _on_close (scene-change) and replace with overlay-close.
        for c in (close_btn as Button).pressed.get_connections():
            (close_btn as Button).pressed.disconnect(c["callable"])
        (close_btn as Button).pressed.connect(_close_journal_overlay)
    add_child(_journal_overlay)
    get_tree().paused = true

func _close_journal_overlay() -> void:
    if _journal_overlay != null and is_instance_valid(_journal_overlay):
        _journal_overlay.queue_free()
    _journal_overlay = null
    get_tree().paused = false

func _on_player_died() -> void:
    GameState.run_count += 1
    var run_loot: Array = Inventory.bag.duplicate()
    if Settings.run_end_auto_return:
        ChestManager.auto_stow(run_loot)
        Inventory.bag.clear()
    SaveSystem.save()
    WorldSim.exit_run()
    var ps: PackedScene = load("res://scenes/ui/game_over.tscn")
    if ps == null:
        get_tree().change_scene_to_file("res://scenes/title.tscn")
        return
    var go = ps.instantiate()
    go.floors_cleared = RunState.floor_index
    go.kills = RunState.run_kills
    go.gold_earned = RunState.run_gold
    go.legendaries = RunState.run_legendaries
    var layer := CanvasLayer.new()
    layer.layer = 90
    layer.add_child(go)
    add_child(layer)
    get_tree().paused = true
