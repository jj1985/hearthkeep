extends Node2D

# Top-level runner: spawns player, manages camera, dispatches HUD signals,
# loads dungeon rooms, hosts the level-up perk picker.

const PlayerScene := preload("res://scenes/player/player.tscn")
const GoblinScene := preload("res://scenes/enemies/goblin.tscn")
const LootScene := preload("res://scenes/fx/loot_drop.tscn")

@onready var player_layer: Node2D = $World/PlayerLayer
@onready var enemy_layer: Node2D = $World/EnemyLayer
@onready var loot_layer: Node2D = $World/LootLayer
@onready var fx_layer: Node2D = $World/FxLayer
@onready var room_layer: Node2D = $World/RoomLayer
@onready var camera: Camera2D = $World/Camera
@onready var hud: CanvasLayer = $HUD
@onready var hud_script: Control = $HUD/Root
@onready var perk_overlay: CanvasLayer = $PerkOverlay
@onready var perk_root: Control = $PerkOverlay/Root
@onready var floating_text_layer: CanvasLayer = $FloatingText

var player: CharacterBody2D
var room_index: int = 0
var current_room_seed: int = 0
var camera_shake_t: float = 0.0
var camera_shake_strength: float = 0.0
var spawn_pacing_timer: float = 0.0
var floor_kill_target: int = 12
var pending_perk_offer: bool = false
var pause_for_levelup: bool = false

func _ready() -> void:
    SaveSystem.load_save()
    RunState.start_run(randi())
    EventBus.player_died.connect(_on_player_died)
    EventBus.loot_dropped.connect(_on_loot_dropped)
    EventBus.screen_shake.connect(_on_screen_shake)
    EventBus.hit_stop.connect(_on_hit_stop)
    EventBus.floating_text.connect(_on_floating_text)
    RunState.level_up_pending.connect(_on_level_up_pending)
    _spawn_player()
    _enter_room()
    _on_level_up_pending(1)   # offer first perk immediately to teach the loop

func _process(delta: float) -> void:
    RunState.run_time += delta
    if camera_shake_t > 0.0:
        camera_shake_t = max(0.0, camera_shake_t - delta)
        camera.offset = Vector2(
            randf_range(-camera_shake_strength, camera_shake_strength),
            randf_range(-camera_shake_strength, camera_shake_strength))
        if camera_shake_t == 0.0:
            camera.offset = Vector2.ZERO
    if player != null and is_instance_valid(player):
        camera.position = player.global_position
    spawn_pacing_timer -= delta
    if spawn_pacing_timer <= 0.0:
        spawn_pacing_timer = 1.6
        _maybe_spawn_wave()
    if RunState.run_kills - (room_index * floor_kill_target) >= floor_kill_target:
        _next_room()

func _spawn_player() -> void:
    player = PlayerScene.instantiate()
    player.class_primary = "warrior"
    player.position = Vector2(640, 360)
    player_layer.add_child(player)

func _enter_room() -> void:
    for c in room_layer.get_children():
        c.queue_free()
    for e in enemy_layer.get_children():
        e.queue_free()
    var bg := ColorRect.new()
    bg.size = Vector2(1600, 1000)
    bg.position = Vector2(-160, -140)
    bg.color = Color(0.10 + 0.02 * RunState.floor_index, 0.08, 0.14, 1.0)
    room_layer.add_child(bg)
    # Walls
    for i in range(8):
        var t := ColorRect.new()
        t.size = Vector2(64, 64)
        t.position = Vector2(120 + i * 160.0, 80)
        t.color = Color(0.20, 0.16, 0.22)
        room_layer.add_child(t)
    floor_kill_target = 10 + RunState.floor_index * 4
    _spawn_starter_pack()

func _spawn_starter_pack() -> void:
    for i in range(5 + RunState.floor_index):
        _spawn_goblin(_random_spawn_pos(), randi() % 3)

func _maybe_spawn_wave() -> void:
    if player == null or not is_instance_valid(player):
        return
    var alive: int = enemy_layer.get_child_count()
    var cap: int = 8 + RunState.floor_index * 3 + RunState.player_level
    if alive >= cap:
        return
    var to_spawn: int = clamp(2 + RunState.floor_index, 1, 6)
    for i in range(to_spawn):
        var roll: int = randi() % 100
        var v: int = 0
        if roll > 95 and RunState.floor_index >= 2:
            v = 3              # warchief mini-boss
        elif roll > 78:
            v = 2              # shaman
        elif roll > 55:
            v = 1              # sapper
        else:
            v = 0              # skirmisher
        _spawn_goblin(_random_spawn_pos(), v)

func _spawn_goblin(pos: Vector2, variant: int) -> void:
    var g = GoblinScene.instantiate()
    g.position = pos
    g.variant = variant
    g.stats_scale = RunState.enemy_scaling()
    enemy_layer.add_child(g)

func _random_spawn_pos() -> Vector2:
    if player == null or not is_instance_valid(player):
        return Vector2(640, 360)
    var ang: float = randf() * TAU
    var r: float = randf_range(360.0, 520.0)
    return player.global_position + Vector2(cos(ang), sin(ang)) * r

func _next_room() -> void:
    room_index += 1
    RunState.floor_index = room_index
    GameState.deepest_floor = max(GameState.deepest_floor, RunState.floor_index)
    EventBus.floating_text.emit("FLOOR " + str(room_index + 1), player.global_position + Vector2(0, -64), Color(1, 0.8, 0.3))
    _enter_room()

func _on_loot_dropped(item: Dictionary, pos: Vector2) -> void:
    var l = LootScene.instantiate()
    l.position = pos
    l.item = item
    loot_layer.add_child(l)
    VFX.spawn_coin_spray(pos, 6 + item.get("rarity", 0) * 4)

func _on_screen_shake(strength: float, duration: float) -> void:
    camera_shake_strength = max(camera_shake_strength, strength)
    camera_shake_t = max(camera_shake_t, duration)

func _on_hit_stop(duration: float) -> void:
    Engine.time_scale = 0.05
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0

func _on_floating_text(text: String, pos: Vector2, color: Color) -> void:
    var lbl := Label.new()
    lbl.text = text
    lbl.modulate = color
    lbl.position = pos - Vector2(20, 0)
    lbl.z_index = 100
    lbl.add_theme_font_size_override("font_size", 18)
    fx_layer.add_child(lbl)
    var tween := lbl.create_tween()
    tween.tween_property(lbl, "position:y", pos.y - 64.0, 0.7)
    tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
    tween.tween_callback(lbl.queue_free)

func _on_level_up_pending(_lvl: int) -> void:
    if pause_for_levelup:
        return
    pause_for_levelup = true
    get_tree().paused = true
    perk_overlay.visible = true
    SfxBus.play("levelup")
    if player != null:
        VFX.spawn_levelup_flare(player.global_position)
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

func _on_player_died() -> void:
    EventBus.floating_text.emit("YOU DIED", player.global_position, Color(1, 0.2, 0.2))
    GameState.run_count += 1
    SaveSystem.save()
    await get_tree().create_timer(1.5).timeout
    get_tree().reload_current_scene()
